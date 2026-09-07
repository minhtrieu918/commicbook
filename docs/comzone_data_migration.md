# Nhập dữ liệu ComZone vào Firebase

Nguồn dữ liệu được sử dụng là `Dump20250111_version_2.sql`. File dump gốc
không được đóng gói vào ứng dụng.

## Dữ liệu được nhập

- Danh mục thể loại, tình trạng, phiên bản và merchandise.
- Truyện cùng các liên kết danh mục, ảnh nguồn và thông tin xuất bản.
- Hồ sơ công khai của người bán đã loại thông tin riêng tư.
- Phiên đấu giá, bài trao đổi, cấu hình đấu giá và gói người bán.

Seed hiện có 211 document. Admin mở **Cài đặt** và chọn
**Nhập dữ liệu ComZone** để ghi dữ liệu vào Firebase. Quá trình sử dụng ID gốc
và `SetOptions(merge: true)`, vì vậy có thể chạy lại mà không tạo bản ghi trùng.

## Dữ liệu không đóng gói trong ứng dụng

Mật khẩu, refresh token, device ID, OTP, email, số điện thoại, địa chỉ, tài
khoản ngân hàng và lịch sử tài chính bị loại khỏi seed. Các UUID người dùng từ
MySQL không phải Firebase Auth UID; muốn chuyển tài khoản và dữ liệu riêng tư
cần một đợt migration phía server có ánh xạ UID riêng.

Các URL ảnh nguồn còn hoạt động được tải về `assets/comzone-comics`. Với 99
truyện có URL Firebase cũ không còn dùng được, ảnh thay thế đã được tìm theo tên
truyện trên Google Images, rà lại kết quả và lưu nội bộ. Seed vẫn giữ URL ảnh
nguồn cũ, URL tìm kiếm Google và URL kết quả để có thể kiểm tra nguồn.

- `assets/data/comzone_image_manifest.json`: kết quả tải ảnh từ nguồn ban đầu.
- `assets/data/google_image_supplement_manifest.json`: kết quả bổ sung từ
  Google Images.
- `tool/data/google_comic_image_mapping.json`: ánh xạ đã rà soát dùng để chạy
  lại công cụ nhập ảnh.

## Tạo lại seed

```sh
dart run tool/convert_comzone_sql.dart path/to/dump.sql \
  assets/data/comzone_public_seed.json

dart run tool/localize_comzone_images.dart \
  assets/data/comzone_public_seed.json \
  assets/comzone-comics \
  assets/data/comzone_image_manifest.json

dart run tool/import_google_comic_images.dart \
  assets/data/comzone_public_seed.json \
  tool/data/google_comic_image_mapping.json \
  assets/comzone-comics \
  assets/data/google_image_supplement_manifest.json
```
