# ComZone: ánh xạ NestJS/MySQL sang Flutter + Firebase

Tài liệu này ghi lại ánh xạ được dùng khi chuyển source `ComZone_Client` và
`ComZone-Server` sang ứng dụng Flutter hiện tại. Firebase Authentication quản
lý thông tin đăng nhập; Cloud Firestore thay thế controller/service TypeORM.

| Entity/module gốc | Firestore | Ghi chú |
| --- | --- | --- |
| `users`, authentication | `users/{uid}` + Firebase Auth | Không lưu mật khẩu trong Firestore |
| `seller_details` | `seller_profiles/{uid}` | Đăng ký Seller cập nhật role atomically |
| `comics` | `comics/{comicId}` | Lưu seller UID, tồn kho và metadata truyện |
| `genres`, `conditions`, `editions`, `merchandises` | `comic_genres`, `comic_conditions`, `comic_editions`, `comic_merchandises` | Admin quản lý, hỗ trợ soft delete |
| `orders`, `order-item` | `orders/{orderId}` | Snapshot truyện được lưu cùng đơn; trừ tồn kho bằng transaction |
| `auction_request`, `auction` | `auctions/{auctionId}` | `pending` → `active/rejected`; Seller có thể hủy |
| `bid` | `auction_bids/{bidId}` | Cập nhật giá hiện tại bằng Firestore transaction |
| `deposit` (auction) | `auction_deposits/{auctionId}_{uid}` | Chuyển tiền từ balance sang heldBalance trước khi bid |
| `exchange-posts` | `exchange_posts/{postId}` | Bài trao đổi công khai đang hoạt động |
| `exchanges` | `exchange_requests/{requestId}` | Hai participant; recipient chấp nhận hoặc từ chối |
| `chat-room`, `chat-message` | `chats/{chatId}/messages/{messageId}` | Realtime snapshot thay Socket.IO |
| `announcement` | `notifications/{notificationId}` | Người nhận đọc và đánh dấu đã đọc |
| `transactions` | `wallet_transactions/{transactionId}` | Lịch sử cộng/trừ tiền |
| `wallet-deposit`, `withdrawal` | `wallet_requests/{requestId}` | Trạng thái pending cho tích hợp cổng thanh toán/backend tin cậy |
| `seller-feedback`, follow | `seller_feedback`, `follows` | Feedback phải được staff duyệt |

Vai trò được chuẩn hóa thành `customer`, `seller`, `moderator`, `admin`.
Moderator xử lý nghiệp vụ kiểm duyệt; chỉ Admin được thay đổi role và danh mục
cấu hình. Các tác vụ thanh toán/callback cần môi trường tin cậy phải do Firebase
Functions hoặc server thanh toán thực hiện, không đánh dấu thành công từ client.
