"use strict";

const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");

const REGION = "us-central1";
const ACTIVE_DEPOSIT = "holding";

function callable(handler) {
  return onCall({region: REGION, maxInstances: 20}, async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Vui lòng đăng nhập.");
    }
    return handler(request, getFirestore());
  });
}

function text(value) {
  return typeof value === "string" ? value.trim() : "";
}

function number(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : NaN;
}

async function profile(db, uid) {
  const snapshot = await db.collection("users").doc(uid).get();
  return snapshot.exists ? snapshot.data() : null;
}

async function requireRole(db, uid, roles) {
  const user = await profile(db, uid);
  if (!user || !roles.includes(user.role)) {
    throw new HttpsError("permission-denied", "Bạn không có quyền thực hiện thao tác này.");
  }
  return user;
}

async function config(db) {
  const snapshot = await db.collection("auction_configs")
      .where("isDeleted", "==", false).limit(1).get();
  const data = snapshot.empty ? {} : snapshot.docs[0].data();
  return {
    bidPercent: number(data.bidIncrementConfig) || 5,
    depositPercent: number(data.depositAmountConfig) || 120,
    buyMultiplier: number(data.maxPriceConfig) || 20,
    paymentDays: number(data.paymentDays) || 7,
  };
}

function roundToNearestThousand(value) {
  return Math.round(value / 1000) * 1000;
}

function notification(db, batch, uid, type, title, message, auctionId) {
  if (!uid) return;
  batch.set(db.collection("notifications").doc(), {
    userId: uid,
    type,
    title,
    message,
    auctionId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function walletTransaction(db, transaction, data) {
  transaction.set(db.collection("wallet_transactions").doc(), {
    ...data,
    status: "SUCCESSFUL",
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function refundDeposits(db, transaction, auctionId, exceptUid = "") {
  const deposits = await transaction.get(
      db.collection("auction_deposits")
          .where("auctionId", "==", auctionId)
          .where("status", "==", ACTIVE_DEPOSIT),
  );
  const refundable = deposits.docs.filter((deposit) => {
    const uid = deposit.data().userId;
    return uid && uid !== exceptUid;
  });
  const wallets = await Promise.all(refundable.map((deposit) =>
    transaction.get(db.collection("wallets").doc(deposit.data().userId)),
  ));
  for (let index = 0; index < refundable.length; index++) {
    const deposit = refundable[index];
    const data = deposit.data();
    const uid = data.userId;
    const amount = number(data.amount) || 0;
    const walletRef = db.collection("wallets").doc(uid);
    const wallet = wallets[index];
    if (!wallet.exists) continue;
    const walletData = wallet.data();
    transaction.update(walletRef, {
      balance: (number(walletData.balance) || 0) + amount,
      heldBalance: Math.max(0, (number(walletData.heldBalance) || 0) - amount),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(deposit.ref, {
      status: "refunded",
      refundedAt: FieldValue.serverTimestamp(),
    });
    walletTransaction(db, transaction, {
      userId: uid,
      auctionId,
      amount,
      type: "ADD",
      note: "Hoàn tiền cọc đấu giá",
    });
  }
  return deposits.docs;
}

exports.createAuctionRequest = callable(async (request, db) => {
  const uid = request.auth.uid;
  await requireRole(db, uid, ["seller"]);
  const comicId = text(request.data?.comicId);
  const durationDays = number(request.data?.durationDays);
  const requestedBuyNow = request.data?.buyNowPrice == null ? null :
    number(request.data.buyNowPrice);
  if (!comicId || !Number.isInteger(durationDays) || durationDays < 1 || durationDays > 7) {
    throw new HttpsError("invalid-argument", "Thời lượng đấu giá phải từ 1 đến 7 ngày.");
  }

  const comicRef = db.collection("comics").doc(comicId);
  const auctionConfig = await config(db);
  const duplicateRequests = await db.collection("auction_requests")
      .where("comicId", "==", comicId).where("status", "==", "pending").limit(1).get();
  const duplicateAuctions = await db.collection("auctions")
      .where("comicId", "==", comicId)
      .where("status", "in", ["upcoming", "active", "successful"])
      .limit(1).get();
  if (!duplicateRequests.empty || !duplicateAuctions.empty) {
    throw new HttpsError("already-exists", "Truyện đã có yêu cầu hoặc phiên đấu giá đang xử lý.");
  }

  const requestRef = db.collection("auction_requests").doc();
  await db.runTransaction(async (transaction) => {
    const comic = await transaction.get(comicRef);
    if (!comic.exists) throw new HttpsError("not-found", "Không tìm thấy truyện.");
    const data = comic.data();
    const startingBid = number(data.price);
    if (data.sellerUid !== uid || data.status !== "active" ||
        (number(data.stock) || 0) < 1 || !Number.isFinite(startingBid) || startingBid <= 0) {
      throw new HttpsError("failed-precondition", "Truyện không còn đủ điều kiện đấu giá.");
    }
    const maxBuyNow = startingBid * auctionConfig.buyMultiplier;
    if (requestedBuyNow !== null &&
        (!Number.isFinite(requestedBuyNow) || requestedBuyNow <= startingBid ||
         requestedBuyNow > maxBuyNow)) {
      throw new HttpsError(
          "invalid-argument",
          `Giá mua ngay phải lớn hơn giá khởi điểm và không vượt quá ${maxBuyNow}.`,
      );
    }
    transaction.set(requestRef, {
      sellerUid: uid,
      comicId,
      title: text(data.title) || "Phiên đấu giá",
      coverImage: text(data.coverImage) || text(data.image),
      startingBid,
      bidIncrement: roundToNearestThousand(startingBid * auctionConfig.bidPercent / 100),
      depositAmount: roundToNearestThousand(startingBid * auctionConfig.depositPercent / 100),
      buyNowPrice: requestedBuyNow,
      durationDays,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(comicRef, {
      status: "unavailable",
      auctionRequestId: requestRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {requestId: requestRef.id};
});

exports.reviewAuctionRequest = callable(async (request, db) => {
  const moderatorUid = request.auth.uid;
  await requireRole(db, moderatorUid, ["admin", "moderator"]);
  const requestId = text(request.data?.requestId);
  const approved = request.data?.approved === true;
  const rejectionReason = text(request.data?.rejectionReason);
  const startDate = approved ? new Date(text(request.data?.startAt)) : null;
  if (!requestId || (approved && (!startDate || Number.isNaN(startDate.getTime()))) ||
      (!approved && !rejectionReason)) {
    throw new HttpsError("invalid-argument", approved ?
      "Vui lòng chọn thời gian bắt đầu." : "Vui lòng nhập lý do từ chối.");
  }
  if (approved && startDate.getTime() < Date.now() - 60000) {
    throw new HttpsError("invalid-argument", "Thời gian bắt đầu không được ở quá khứ.");
  }

  const requestRef = db.collection("auction_requests").doc(requestId);
  const auctionRef = db.collection("auctions").doc();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    if (!snapshot.exists || snapshot.data().status !== "pending") {
      throw new HttpsError("failed-precondition", "Yêu cầu đã được xử lý.");
    }
    const data = snapshot.data();
    const comicRef = db.collection("comics").doc(data.comicId);
    if (!approved) {
      transaction.update(requestRef, {
        status: "rejected",
        rejectionReason,
        reviewedBy: moderatorUid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(comicRef, {
        status: "active",
        auctionRequestId: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      notification(db, transaction, data.sellerUid, "AUCTION_REJECTED",
          "Yêu cầu đấu giá bị từ chối", rejectionReason, "");
      return;
    }

    const startAt = Timestamp.fromDate(startDate);
    const endAt = Timestamp.fromMillis(
        startDate.getTime() + Number(data.durationDays) * 86400000,
    );
    transaction.set(auctionRef, {
      sellerUid: data.sellerUid,
      comicId: data.comicId,
      requestId,
      title: data.title,
      coverImage: data.coverImage || "",
      startingBid: data.startingBid,
      currentBid: data.startingBid,
      bidIncrement: data.bidIncrement,
      depositAmount: data.depositAmount,
      buyNowPrice: data.buyNowPrice || null,
      startAt,
      endAt,
      status: startDate.getTime() <= Date.now() ? "active" : "upcoming",
      bidCount: 0,
      isPaid: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(requestRef, {
      status: "approved",
      auctionId: auctionRef.id,
      startAt,
      endAt,
      reviewedBy: moderatorUid,
      reviewedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(comicRef, {
      status: "unavailable",
      auctionId: auctionRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    notification(db, transaction, data.sellerUid, "AUCTION_APPROVED",
        "Yêu cầu đấu giá đã được duyệt", "Phiên đấu giá đã được lên lịch.", auctionRef.id);
  });
  return {auctionId: approved ? auctionRef.id : null};
});

exports.placeAuctionDeposit = callable(async (request, db) => {
  const uid = request.auth.uid;
  const auctionId = text(request.data?.auctionId);
  if (!auctionId) throw new HttpsError("invalid-argument", "Thiếu phiên đấu giá.");
  const auctionRef = db.collection("auctions").doc(auctionId);
  const walletRef = db.collection("wallets").doc(uid);
  const depositRef = db.collection("auction_deposits").doc(`${auctionId}_${uid}`);
  await db.runTransaction(async (transaction) => {
    const [auction, wallet, oldDeposit] = await Promise.all([
      transaction.get(auctionRef), transaction.get(walletRef), transaction.get(depositRef),
    ]);
    if (!auction.exists) throw new HttpsError("not-found", "Phiên đấu giá không tồn tại.");
    const data = auction.data();
    const now = Date.now();
    if (data.status !== "active" || data.startAt.toMillis() > now || data.endAt.toMillis() <= now) {
      throw new HttpsError("failed-precondition", "Phiên đấu giá chưa hoạt động hoặc đã kết thúc.");
    }
    if (data.sellerUid === uid) {
      throw new HttpsError("permission-denied", "Người bán không thể tham gia phiên của mình.");
    }
    if (oldDeposit.exists && oldDeposit.data().status === ACTIVE_DEPOSIT) return;
    if (!wallet.exists) throw new HttpsError("not-found", "Không tìm thấy ví.");
    const amount = number(data.depositAmount) || 0;
    const walletData = wallet.data();
    const balance = number(walletData.balance) || 0;
    if (amount <= 0 || balance < amount) {
      throw new HttpsError("failed-precondition", "Số dư ví không đủ để đặt cọc.");
    }
    transaction.set(depositRef, {
      auctionId, userId: uid, amount, status: ACTIVE_DEPOSIT,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(walletRef, {
      balance: balance - amount,
      heldBalance: (number(walletData.heldBalance) || 0) + amount,
      updatedAt: FieldValue.serverTimestamp(),
    });
    walletTransaction(db, transaction, {
      userId: uid, auctionId, amount, type: "HOLD", note: "Đặt cọc đấu giá",
    });
  });
  return {success: true};
});

exports.placeAuctionBid = callable(async (request, db) => {
  const uid = request.auth.uid;
  const auctionId = text(request.data?.auctionId);
  const amount = number(request.data?.amount);
  if (!auctionId || !Number.isFinite(amount)) {
    throw new HttpsError("invalid-argument", "Giá đặt không hợp lệ.");
  }
  const auctionRef = db.collection("auctions").doc(auctionId);
  const depositRef = db.collection("auction_deposits").doc(`${auctionId}_${uid}`);
  const bidRef = db.collection("auction_bids").doc();
  await db.runTransaction(async (transaction) => {
    const [auction, deposit] = await Promise.all([
      transaction.get(auctionRef), transaction.get(depositRef),
    ]);
    if (!auction.exists) throw new HttpsError("not-found", "Phiên đấu giá không tồn tại.");
    const data = auction.data();
    const now = Date.now();
    if (data.status !== "active" || data.startAt.toMillis() > now || data.endAt.toMillis() <= now) {
      throw new HttpsError("failed-precondition", "Phiên đấu giá đã kết thúc.");
    }
    if (data.sellerUid === uid) {
      throw new HttpsError("permission-denied", "Người bán không thể tự đặt giá.");
    }
    if (!deposit.exists || deposit.data().status !== ACTIVE_DEPOSIT) {
      throw new HttpsError("failed-precondition", "Bạn cần đặt cọc trước khi ra giá.");
    }
    const minimum = (number(data.currentBid) || 0) + (number(data.bidIncrement) || 0);
    const buyNow = number(data.buyNowPrice);
    if (amount < minimum) {
      throw new HttpsError("invalid-argument", `Giá tối thiểu là ${minimum}.`);
    }
    if (Number.isFinite(buyNow) && amount >= buyNow) {
      throw new HttpsError("invalid-argument", "Mức giá này phải thực hiện bằng Mua ngay.");
    }
    transaction.set(bidRef, {
      auctionId, auctionTitle: data.title, userId: uid, amount,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.update(auctionRef, {
      currentBid: amount,
      bidCount: (number(data.bidCount) || 0) + 1,
      highestBidderUid: uid,
      lastBidId: bidRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (data.highestBidderUid && data.highestBidderUid !== uid) {
      notification(db, transaction, data.highestBidderUid, "AUCTION_OUTBID",
          "Bạn đã bị vượt giá", `Phiên ${data.title} vừa có mức giá cao hơn.`, auctionId);
    }
  });
  return {bidId: bidRef.id};
});

async function concludeAuction(db, auctionId, expectedStatus) {
  const auctionRef = db.collection("auctions").doc(auctionId);
  const cfg = await config(db);
  return db.runTransaction(async (transaction) => {
    const auction = await transaction.get(auctionRef);
    if (!auction.exists) return false;
    const data = auction.data();
    if (expectedStatus && data.status !== expectedStatus) return false;
    if (data.status === "upcoming" && data.startAt.toMillis() <= Date.now() &&
        data.endAt.toMillis() > Date.now()) {
      transaction.update(auctionRef, {
        status: "active", updatedAt: FieldValue.serverTimestamp(),
      });
      return true;
    }
    if (data.status !== "active" || data.endAt.toMillis() > Date.now()) return false;
    const winnerUid = text(data.highestBidderUid);
    const comicRef = db.collection("comics").doc(data.comicId);
    if (!winnerUid) {
      await refundDeposits(db, transaction, auctionId);
      transaction.update(auctionRef, {
        status: "cancelled", outcome: "no_bids", updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(comicRef, {
        status: "active", auctionId: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp(),
      });
      notification(db, transaction, data.sellerUid, "AUCTION_CANCELLED",
          "Đấu giá không có người trả giá", data.title, auctionId);
      return true;
    }
    const refunded = await refundDeposits(db, transaction, auctionId, winnerUid);
    const deadline = Timestamp.fromMillis(Date.now() + cfg.paymentDays * 86400000);
    transaction.update(auctionRef, {
      status: "successful", winnerUid, winningPrice: data.currentBid,
      paymentDeadline: deadline, updatedAt: FieldValue.serverTimestamp(),
    });
    notification(db, transaction, winnerUid, "AUCTION_WON", "Bạn đã thắng đấu giá",
        `Vui lòng thanh toán phiên ${data.title} trước hạn.`, auctionId);
    notification(db, transaction, data.sellerUid, "AUCTION_SUCCESSFUL",
        "Đấu giá đã có người thắng", data.title, auctionId);
    for (const deposit of refunded) {
      if (deposit.data().userId !== winnerUid) {
        notification(db, transaction, deposit.data().userId, "AUCTION_LOST",
            "Phiên đấu giá đã kết thúc", `Bạn không thắng phiên ${data.title}.`, auctionId);
      }
    }
    return true;
  });
}

exports.buyNowAuction = callable(async (request, db) => {
  const uid = request.auth.uid;
  const auctionId = text(request.data?.auctionId);
  const auctionRef = db.collection("auctions").doc(auctionId);
  const depositRef = db.collection("auction_deposits").doc(`${auctionId}_${uid}`);
  const cfg = await config(db);
  await db.runTransaction(async (transaction) => {
    const [auction, deposit] = await Promise.all([
      transaction.get(auctionRef), transaction.get(depositRef),
    ]);
    if (!auction.exists) throw new HttpsError("not-found", "Phiên đấu giá không tồn tại.");
    const data = auction.data();
    const buyNow = number(data.buyNowPrice);
    const now = Date.now();
    if (data.status !== "active" || data.endAt.toMillis() <= now || !Number.isFinite(buyNow)) {
      throw new HttpsError("failed-precondition", "Không thể mua ngay phiên này.");
    }
    if (data.sellerUid === uid || !deposit.exists || deposit.data().status !== ACTIVE_DEPOSIT) {
      throw new HttpsError("failed-precondition", "Bạn cần đặt cọc hợp lệ trước khi mua ngay.");
    }
    const refunded = await refundDeposits(db, transaction, auctionId, uid);
    transaction.update(auctionRef, {
      currentBid: buyNow, winningPrice: buyNow, winnerUid: uid,
      status: "successful", outcome: "buy_now",
      paymentDeadline: Timestamp.fromMillis(now + cfg.paymentDays * 86400000),
      updatedAt: FieldValue.serverTimestamp(),
    });
    notification(db, transaction, uid, "AUCTION_WON", "Mua ngay thành công",
        `Vui lòng thanh toán phiên ${data.title} trước hạn.`, auctionId);
    for (const otherDeposit of refunded) {
      if (otherDeposit.data().userId !== uid) {
        notification(db, transaction, otherDeposit.data().userId, "AUCTION_LOST",
            "Phiên đấu giá đã kết thúc bằng Mua ngay", data.title, auctionId);
      }
    }
  });
  return {success: true};
});

exports.payAuction = callable(async (request, db) => {
  const uid = request.auth.uid;
  const auctionId = text(request.data?.auctionId);
  const auctionRef = db.collection("auctions").doc(auctionId);
  const depositRef = db.collection("auction_deposits").doc(`${auctionId}_${uid}`);
  const buyerWalletRef = db.collection("wallets").doc(uid);
  const orderRef = db.collection("orders").doc();
  await db.runTransaction(async (transaction) => {
    const [auction, deposit, buyerWalletSnapshot] = await Promise.all([
      transaction.get(auctionRef), transaction.get(depositRef), transaction.get(buyerWalletRef),
    ]);
    if (!auction.exists || auction.data().status !== "successful" ||
        auction.data().winnerUid !== uid) {
      throw new HttpsError("failed-precondition", "Bạn không phải người thắng cần thanh toán.");
    }
    const data = auction.data();
    if (data.paymentDeadline.toMillis() <= Date.now()) {
      throw new HttpsError("deadline-exceeded", "Đã quá hạn thanh toán.");
    }
    if (!deposit.exists || deposit.data().status !== ACTIVE_DEPOSIT || !buyerWalletSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Khoản cọc hoặc ví không hợp lệ.");
    }
    const price = number(data.winningPrice) || number(data.currentBid) || 0;
    const depositAmount = number(deposit.data().amount) || 0;
    const appliedDeposit = Math.min(price, depositAmount);
    const refund = Math.max(0, depositAmount - price);
    const due = price - appliedDeposit;
    const buyerWallet = buyerWalletSnapshot.data();
    const balance = number(buyerWallet.balance) || 0;
    if (balance < due) throw new HttpsError("failed-precondition", "Số dư ví không đủ thanh toán.");
    const sellerWalletRef = db.collection("wallets").doc(data.sellerUid);
    const sellerWalletSnapshot = await transaction.get(sellerWalletRef);
    const sellerWallet = sellerWalletSnapshot.exists ? sellerWalletSnapshot.data() : {};
    transaction.update(buyerWalletRef, {
      balance: balance - due + refund,
      heldBalance: Math.max(0, (number(buyerWallet.heldBalance) || 0) - depositAmount),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(sellerWalletRef, {
      userId: data.sellerUid,
      balance: (number(sellerWallet.balance) || 0) + price,
      withdrawableBalance: (number(sellerWallet.withdrawableBalance) || 0) + price,
      heldBalance: number(sellerWallet.heldBalance) || 0,
      updatedAt: FieldValue.serverTimestamp(),
      ...(!sellerWalletSnapshot.exists ? {createdAt: FieldValue.serverTimestamp()} : {}),
    }, {merge: true});
    transaction.update(depositRef, {
      status: "used", usedAmount: appliedDeposit, refundAmount: refund,
      usedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(auctionRef, {
      status: "completed", isPaid: true, paidAt: FieldValue.serverTimestamp(),
      orderId: orderRef.id, updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(db.collection("comics").doc(data.comicId), {
      status: "unavailable", stock: 0, lastOrderId: orderRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(orderRef, {
      userId: uid, sellerUid: data.sellerUid, comicId: data.comicId,
      comicTitle: data.title, price, auctionId, depositAmount: appliedDeposit,
      paymentMethod: "Ví ComZone", status: "Chờ xác nhận",
      classification: "Đấu giá", buyerEmail: request.auth.token.email || "",
      createdAt: FieldValue.serverTimestamp(),
    });
    walletTransaction(db, transaction, {
      userId: uid, auctionId, amount: due, type: "SUBTRACT", note: "Thanh toán đấu giá",
    });
    walletTransaction(db, transaction, {
      userId: data.sellerUid, auctionId, amount: price, type: "ADD",
      note: "Doanh thu đấu giá",
    });
    notification(db, transaction, data.sellerUid, "AUCTION_PAID",
        "Người thắng đã thanh toán", data.title, auctionId);
  });
  return {orderId: orderRef.id};
});

exports.cancelAuction = callable(async (request, db) => {
  const uid = request.auth.uid;
  const auctionId = text(request.data?.auctionId);
  const auctionRef = db.collection("auctions").doc(auctionId);
  await db.runTransaction(async (transaction) => {
    const auction = await transaction.get(auctionRef);
    if (!auction.exists) throw new HttpsError("not-found", "Phiên đấu giá không tồn tại.");
    const data = auction.data();
    const user = await profile(db, uid);
    if (data.sellerUid !== uid && !["admin", "moderator"].includes(user?.role)) {
      throw new HttpsError("permission-denied", "Bạn không có quyền dừng phiên này.");
    }
    if (!["upcoming", "active"].includes(data.status)) {
      throw new HttpsError("failed-precondition", "Phiên đấu giá không thể dừng ở trạng thái hiện tại.");
    }
    const deposits = await refundDeposits(db, transaction, auctionId);
    transaction.update(auctionRef, {
      status: (number(data.bidCount) || 0) > 0 ? "stopped" : "cancelled",
      cancelledBy: uid, cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(db.collection("comics").doc(data.comicId), {
      status: "active", auctionId: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp(),
    });
    for (const deposit of deposits) {
      notification(db, transaction, deposit.data().userId, "AUCTION_STOPPED",
          "Phiên đấu giá đã dừng", data.title, auctionId);
    }
  });
  return {success: true};
});

async function failOverdueAuction(db, auctionId) {
  const auctionRef = db.collection("auctions").doc(auctionId);
  return db.runTransaction(async (transaction) => {
    const auction = await transaction.get(auctionRef);
    if (!auction.exists || auction.data().status !== "successful" ||
        auction.data().paymentDeadline.toMillis() > Date.now()) return false;
    const data = auction.data();
    const winnerUid = data.winnerUid;
    const depositRef = db.collection("auction_deposits").doc(`${auctionId}_${winnerUid}`);
    const deposit = await transaction.get(depositRef);
    if (deposit.exists && deposit.data().status === ACTIVE_DEPOSIT) {
      const amount = number(deposit.data().amount) || 0;
      const winnerWalletRef = db.collection("wallets").doc(winnerUid);
      const sellerWalletRef = db.collection("wallets").doc(data.sellerUid);
      const [winnerWallet, sellerWallet] = await Promise.all([
        transaction.get(winnerWalletRef), transaction.get(sellerWalletRef),
      ]);
      if (winnerWallet.exists) transaction.update(winnerWalletRef, {
        heldBalance: Math.max(0, (number(winnerWallet.data().heldBalance) || 0) - amount),
        updatedAt: FieldValue.serverTimestamp(),
      });
      const seller = sellerWallet.exists ? sellerWallet.data() : {};
      transaction.set(sellerWalletRef, {
        userId: data.sellerUid,
        balance: (number(seller.balance) || 0) + amount,
        withdrawableBalance: (number(seller.withdrawableBalance) || 0) + amount,
        heldBalance: number(seller.heldBalance) || 0,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.update(depositRef, {
        status: "seized", seizedReason: "Quá hạn thanh toán",
        seizedAt: FieldValue.serverTimestamp(),
      });
      walletTransaction(db, transaction, {
        userId: data.sellerUid, auctionId, amount, type: "ADD",
        note: "Nhận cọc do người thắng quá hạn",
      });
    }
    transaction.update(auctionRef, {
      status: "failed", outcome: "payment_overdue", updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(db.collection("comics").doc(data.comicId), {
      status: "active", auctionId: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp(),
    });
    notification(db, transaction, winnerUid, "AUCTION_PAYMENT_OVERDUE",
        "Bạn đã quá hạn thanh toán", data.title, auctionId);
    return true;
  });
}

exports.syncAuction = callable(async (request, db) => {
  const auctionId = text(request.data?.auctionId);
  if (!auctionId) throw new HttpsError("invalid-argument", "Thiếu phiên đấu giá.");
  await concludeAuction(db, auctionId);
  await failOverdueAuction(db, auctionId);
  return {success: true};
});

exports.processAuctions = onSchedule(
    {region: REGION, schedule: "every 1 minutes", timeZone: "Asia/Ho_Chi_Minh"},
    async () => {
      const db = getFirestore();
      const now = Timestamp.now();
      const [upcoming, ended, overdue] = await Promise.all([
        db.collection("auctions").where("status", "==", "upcoming")
            .where("startAt", "<=", now).limit(100).get(),
        db.collection("auctions").where("status", "==", "active")
            .where("endAt", "<=", now).limit(100).get(),
        db.collection("auctions").where("status", "==", "successful")
            .where("paymentDeadline", "<=", now).limit(100).get(),
      ]);
      await Promise.all([
        ...upcoming.docs.map((doc) => concludeAuction(db, doc.id, "upcoming")),
        ...ended.docs.map((doc) => concludeAuction(db, doc.id, "active")),
        ...overdue.docs.map((doc) => failOverdueAuction(db, doc.id)),
      ]);
    },
);
