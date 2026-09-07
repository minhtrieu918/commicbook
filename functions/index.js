"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {passwordErrors} = require("./password_policy");
const auction = require("./auction");

initializeApp();

exports.setUserPassword = onCall(
  {region: "us-central1", maxInstances: 10},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Vui lòng đăng nhập.");
    }

    const db = getFirestore();
    const adminUid = request.auth.uid;
    const adminProfile = await db.collection("users").doc(adminUid).get();
    if (!adminProfile.exists || adminProfile.data()?.role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Chỉ quản trị viên mới được đặt mật khẩu cho người dùng.",
      );
    }

    const targetUid = typeof request.data?.targetUid === "string" ?
      request.data.targetUid.trim() : "";
    const newPassword = request.data?.newPassword;
    if (!targetUid) {
      throw new HttpsError("invalid-argument", "Thiếu người dùng cần cập nhật.");
    }

    const errors = passwordErrors(newPassword);
    if (errors.length > 0) {
      throw new HttpsError(
        "invalid-argument",
        `Mật khẩu cần có ${errors.join(", ")}.`,
      );
    }

    try {
      await getAuth().updateUser(targetUid, {password: newPassword});
    } catch (error) {
      if (error?.code === "auth/user-not-found") {
        throw new HttpsError("not-found", "Không tìm thấy tài khoản xác thực.");
      }
      throw new HttpsError("internal", "Không thể cập nhật mật khẩu lúc này.");
    }

    await db.collection("admin_audit_logs").add({
      action: "set_user_password",
      adminUid,
      targetUid,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {success: true};
  },
);

exports.createAuctionRequest = auction.createAuctionRequest;
exports.reviewAuctionRequest = auction.reviewAuctionRequest;
exports.placeAuctionDeposit = auction.placeAuctionDeposit;
exports.placeAuctionBid = auction.placeAuctionBid;
exports.buyNowAuction = auction.buyNowAuction;
exports.payAuction = auction.payAuction;
exports.cancelAuction = auction.cancelAuction;
exports.syncAuction = auction.syncAuction;
exports.processAuctions = auction.processAuctions;
