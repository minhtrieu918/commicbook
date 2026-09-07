# Đối chiếu và triển khai use case đấu giá

## Nguồn đối chiếu

- Báo cáo `Report7_FinalProjectReport_FA24SE025.docx`: mục 3.4, 3.8.4,
  3.8.5, 3.8.13 và các business rule BR-008, BR-009, BR-012, BR-015,
  BR-026, BR-032 đến BR-036.
- FE gốc `ComZone_Client`: màn chi tiết, lịch sử, quản lý yêu cầu và quản lý
  phiên đấu giá.
- BE gốc `ComZone-Server`: `Auction`, `AuctionRequest`, `Bid`, `Deposit`,
  `AuctionConfig` và các service tương ứng.

## Luồng đã triển khai

1. Seller chọn một truyện đang hoạt động, còn hàng; chọn thời lượng 1–7 ngày
   và giá mua ngay tùy chọn.
2. Backend đọc giá truyện và cấu hình Admin để tính giá khởi điểm, bước giá,
   tiền cọc và giới hạn mua ngay. Truyện được khóa khỏi luồng bán thường trong
   lúc yêu cầu được xử lý.
3. Yêu cầu được lưu riêng trong `auction_requests` với trạng thái `pending`.
4. Moderator/Admin chọn giờ bắt đầu để duyệt; giờ kết thúc được tính từ thời
   lượng Seller chọn. Nếu từ chối, lý do là bắt buộc và truyện được mở lại.
5. Người mua phải đặt cọc bằng ví trước khi ra giá. Seller không được tham gia
   phiên của chính mình. Giá mới phải đạt giá hiện tại cộng bước giá và nhỏ hơn
   giá mua ngay.
6. Giá được ghi bằng transaction backend; người đang dẫn đầu bị vượt giá nhận
   thông báo. Danh sách và lịch sử ra giá cập nhật theo Firestore realtime.
7. Mua ngay kết thúc việc trả giá, xác định người thắng và tạo hạn thanh toán.
8. Khi hết giờ, backend chọn người trả giá cao nhất; hoàn cọc người thua. Phiên
   không có lượt giá được hủy và hoàn toàn bộ cọc.
9. Người thắng thanh toán bằng ví trước hạn. Tiền cọc được khấu trừ, phần dư
   được hoàn, Seller nhận doanh thu và đơn hàng đấu giá được tạo.
10. Quá hạn thanh toán làm phiên thất bại, tiền cọc người thắng bị thu và
    chuyển cho Seller.
11. Seller/Moderator có thể dừng phiên đang chờ hoặc đang diễn ra; backend hoàn
    cọc và thông báo cho người tham gia.

## Phân quyền và dữ liệu

- Client chỉ được đọc `auctions`, `auction_bids` và dữ liệu cọc của chính mình.
- Client không được trực tiếp sửa giá, ví, cọc, người thắng hoặc kết quả.
- Các thay đổi tài chính và kết quả chỉ chạy trong Cloud Functions bằng
  transaction của Firestore.
- Cấu hình đấu giá chỉ Admin được sửa trong `auction_configs`.
- Scheduler chạy mỗi phút để bắt đầu/kết thúc phiên và xử lý quá hạn; thao tác
  mở chi tiết cũng gọi đồng bộ một phiên để giảm độ trễ hiển thị.

## Trạng thái

- Yêu cầu: `pending`, `approved`, `rejected`.
- Phiên: `upcoming`, `active`, `successful`, `completed`, `failed`,
  `cancelled`, `stopped`.
- Tiền cọc: `holding`, `refunded`, `used`, `seized`.

