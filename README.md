# ComicBook - Mua bán truyện tranh

Đồ án Flutter kết nối Firebase Authentication và Cloud Firestore.

## Chức năng đã có

- Đăng ký bằng họ tên, email, số điện thoại và mật khẩu mạnh: tối thiểu
  8 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt.
- Đăng nhập bằng email/mật khẩu Firebase Authentication.
- Quên mật khẩu bằng email hoặc số điện thoại:
  - Email nhận liên kết đặt lại mật khẩu an toàn do Firebase gửi.
  - Số điện thoại đã liên kết nhận OTP SMS, có màn hình nhập mã, thời hạn
    120 giây và nút gửi lại mã sau khi hết thời gian.
- Giao diện Manga Mart responsive được chuyển từ bản thiết kế React/Figma.
- Danh mục truyện, lọc thể loại, sắp xếp, tồn kho và giỏ hàng nhiều sản phẩm.
- Chi tiết truyện, thêm vào giỏ và thanh toán theo flow người mua.
- Danh sách/chi tiết đơn hàng và tiến trình trạng thái cho người mua.
- Danh sách/chi tiết đấu giá, đặt giá bằng Firestore transaction và lịch sử
  đấu giá của người dùng.
- Bài đăng trao đổi và form tạo bài mới.
- Hồ sơ cá nhân, thông báo, ví, lịch sử giao dịch và chat theo tài khoản.
- Thanh toán và lưu từng đơn mua vào Cloud Firestore.
- Gửi yêu cầu đăng ký bán truyện với trạng thái mặc định `Chờ duyệt`.
- Lịch sử mua truyện và lịch sử yêu cầu bán.
- Khu vực admin gồm dashboard, lọc/duyệt tin, đấu giá và danh sách người dùng.
- Mã quản trị nằm riêng tại `lib/admin/admin_hub_page.dart`, gồm màn quản lý
  đơn đặt mua và cập nhật trạng thái giao hàng theo thời gian thực.
- Seller Hub dùng dữ liệu Firestore thật cho dashboard, kho truyện, đơn hàng
  và doanh thu; seller có thể sửa giá/tồn kho, tạm ẩn truyện và cập nhật trạng
  thái đơn thuộc về mình.
- Source ComZone React/NestJS đã được ánh xạ sang Flutter + Firestore, gồm
  actor Moderator, đặt cọc đấu giá qua ví, hồ sơ/follow/feedback Seller, yêu cầu
  trao đổi, chat realtime và danh mục truyện do Admin cấu hình.
- Khi đặt mua truyện Firestore, transaction tạo đơn đồng thời trừ tồn kho.
  Mỗi đơn lưu `sellerUid` để rules chỉ cho đúng seller đọc và xử lý.
- Lịch sử khách hàng truy vấn theo `userId` và sắp xếp tại ứng dụng để không
  phụ thuộc composite index chưa được triển khai.

## Cấu trúc Firestore

Các collection chính:

`users`, `seller_profiles`, `comics`, `orders`, `sell_requests`, `auctions`,
`auction_bids`, `auction_deposits`, `exchange_posts`, `exchange_requests`,
`notifications`, `wallets`, `wallet_requests`, `wallet_transactions`, `chats`,
`saved_comics`, `seller_feedback`, `follows`, `comic_genres`,
`comic_conditions`, `comic_editions`, `comic_merchandises`.

Tin nhắn nằm tại subcollection `chats/{chatId}/messages`.

Chi tiết ánh xạ backend gốc sang Firebase nằm tại
[`docs/comzone_firebase_schema.md`](docs/comzone_firebase_schema.md).

Các liên kết chính của backend:

- `sell_requests.userId` là UID người gửi bán.
- Khi admin duyệt, document `comics/{requestId}` được tạo atomically và lưu
  `sellerUid`, `sourceRequestId`, `price`, `stock`, `status`.
- `orders` lưu cả `userId` của người mua và `sellerUid` của người bán. Rules
  giới hạn seller theo `sellerUid`; admin vẫn có quyền quản lý toàn bộ.
- Doanh thu seller chỉ tính các đơn có trạng thái `Đã giao`; phí sàn hiện đặt
  ở mức 15% trong giao diện đối soát.

Mật khẩu không được lưu trong collection `users`. Khi đăng ký,
`createUserWithEmailAndPassword` chuyển thông tin xác thực cho Firebase
Authentication quản lý an toàn. Ở những lần đăng nhập sau,
`signInWithEmailAndPassword` luôn yêu cầu Firebase Authentication đối chiếu
email/mật khẩu trước khi cho người dùng vào ứng dụng. Firestore chỉ lưu hồ sơ
như họ tên, email, số điện thoại và vai trò.

Trong màn **Admin > Người dùng**, tài khoản có vai trò `admin` có thể đặt mật
khẩu mới cho người dùng. Thao tác gọi HTTPS callable `setUserPassword`; backend
kiểm tra lại vai trò Admin rồi cập nhật trực tiếp Firebase Authentication bằng
Admin SDK. Mật khẩu không được ghi vào Firestore hoặc nhật ký. Collection
`admin_audit_logs` chỉ lưu người thực hiện, người bị tác động, loại thao tác và
thời điểm; client không có quyền ghi collection này.

Admin duyệt yêu cầu ngay trong Admin Hub. Ứng dụng dùng Firestore transaction
để đổi `sell_requests.status` và tạo comic tương ứng trong cùng một thao tác,
tránh trạng thái đã duyệt nhưng thiếu truyện trong danh mục.

Tệp [firestore.rules](firestore.rules) đã giới hạn thao tác duyệt và cập nhật
danh mục cho admin. Sau khi tạo tài khoản admin trong `users`, đổi trường
`role` của tài khoản đó thành `admin` trên Firebase Console, rồi triển khai
rules và index bằng Firebase CLI:

```bash
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions:setUserPassword
```

> Lưu ý: cần bật **Email/Password** trong Firebase Authentication và tạo
> Cloud Firestore. Dự án có cấu hình để chạy Web cục bộ; trước khi phát hành,
> hãy đăng ký một Firebase Web app riêng rồi chạy `flutterfire configure` để
> thay cấu hình dùng chung bằng thông tin Web app chính thức.
>
> Để dùng khôi phục bằng OTP SMS, cần bật thêm **Phone** trong Firebase
> Authentication và liên kết số điện thoại đã xác minh với cùng tài khoản
> Email/Password. Firebase có thể yêu cầu cấu hình SHA-1/SHA-256, APNs hoặc
> reCAPTCHA tùy nền tảng.

## Chạy dự án

```bash
flutter pub get
flutter run
```

Chạy riêng bản web:

```bash
flutter run -d chrome
```

Bản web phát hành được tạo bằng `flutter build web` và nằm trong `build/web`.
