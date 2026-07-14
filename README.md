# Waste Classification

Ứng dụng Flutter Android nhận diện và phân loại rác từ camera, được xây dựng cho IT-Challenge lần II năm 2026. Giao diện hỗ trợ tiếng Việt/Anh, lưu ảnh và kết quả quét trong vùng dữ liệu riêng trên thiết bị, đồng thời tách biệt lớp AI để có thể chuyển giữa model mô phỏng và REST API.

## Model và hợp đồng API

Mã nguồn đã được đối chiếu trực tiếp với hai notebook Kaggle của nhóm:

- Model: EfficientNet-B0, định dạng ONNX, đầu vào RGB `224 × 224`.
- Tiền xử lý: chia pixel cho `255`, sau đó chuẩn hóa theo ImageNet (`mean = [0.485, 0.456, 0.406]`, `std = [0.229, 0.224, 0.225]`).
- 9 nhãn theo thứ tự model: `Cardboard`, `Food Organics`, `Glass`, `Metal`, `Miscellaneous Trash`, `Paper`, `Plastic`, `Textile Trash`, `Vegetation`.
- API: `POST /predict`, multipart field `file`.
- Phản hồi: `predicted_class`, `confidence`, `all_probabilities`.

Notebook hiện chưa phát hành tệp ONNX hoặc một endpoint cố định. Vì vậy app mặc định dùng `MockClassifierService` để toàn bộ luồng camera → loading → kết quả có thể demo ổn định. Không có token ngrok hoặc URL tạm thời nào được đưa vào repository.

## Chạy dự án

```bash
flutter pub get
flutter run
```

Để dùng API thật:

```bash
flutter run \
  --dart-define=CLASSIFIER_MODE=api \
  --dart-define=WASTE_API_BASE_URL=https://your-api.example.com
```

Chỉ cấu hình endpoint do nhóm kiểm soát. Ở chế độ API, ảnh được gửi đến `/predict` để suy luận; ứng dụng không dùng endpoint này làm nơi lưu trữ dữ liệu.

## Kiến trúc chính

```text
lib/
  core/       # cấu hình, theme và design tokens
  data/       # model, seed data, SQLite và lưu ảnh cục bộ
  services/   # classifier và quyền camera
  features/   # Home, Scan, Result, Settings
```

- Riverpod cung cấp implementation classifier.
- `camera` và `permission_handler` quản lý luồng chụp/quyền Android.
- SQLite lưu kết quả quét với index theo thời gian và nhóm rác, sẵn sàng cho màn hình lịch sử/thống kê sau này.
- `easy_localization` + `shared_preferences` lưu lựa chọn ngôn ngữ.
- Be Vietnam Pro được bundle trong `assets/fonts`, không tải font ở runtime.

## Kiểm tra chất lượng

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```
