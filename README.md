<div align="center">

# Waste Classification

**Scan one item. Get the waste class, confidence, and a practical way to dispose of it.**

[![Latest release](https://img.shields.io/github/v/release/VoxNut/Waste_Classification?style=flat-square&color=5FA084)](https://github.com/VoxNut/Waste_Classification/releases/latest)
![Flutter](https://img.shields.io/badge/Flutter-Android-5FA084?style=flat-square&logo=flutter&logoColor=white)
![Classes](https://img.shields.io/badge/model-9_classes-F2DDA4?style=flat-square)

**English** · [Tiếng Việt](README.vi.md)

[Download the latest APK](https://github.com/VoxNut/Waste_Classification/releases/latest)

</div>

Waste Classification is a Flutter Android app built for IT-Challenge II 2026. The important part is not just taking a photo: the image sent to the model must match the frame shown on screen. The app captures that exact region, classifies it through the API, then keeps the result locally for history and statistics.

## Demo

[Watch the 37-second demo](repo%20images/Demo%20Video.mp4)

<table>
  <tr>
    <td align="center"><img src="repo%20images/main%20screen.jpg" width="230" alt="Home screen"><br><sub>Start a scan</sub></td>
    <td align="center"><img src="repo%20images/take%20picture%20screen.jpg" width="230" alt="Camera frame"><br><sub>Keep one item in frame</sub></td>
    <td align="center"><img src="repo%20images/result%20screen.jpg" width="230" alt="Classification result"><br><sub>Result and disposal advice</sub></td>
  </tr>
  <tr>
    <td align="center" colspan="1"><img src="repo%20images/stats.jpg" width="230" alt="Scan statistics"><br><sub>Daily, weekly and monthly statistics</sub></td>
    <td align="center" colspan="2"><img src="repo%20images/scan%20details.jpg" width="230" alt="Saved scan details"><br><sub>Saved scan details</sub></td>
  </tr>
</table>

## What is included

- Camera capture with an on-screen guide; only the visible scan frame is uploaded.
- Nine model labels: `Cardboard`, `Food Organics`, `Glass`, `Metal`, `Miscellaneous Trash`, `Paper`, `Plastic`, `Textile Trash`, and `Vegetation`.
- Confidence score, waste-group explanation, and disposal guidance.
- Local scan history with image, timestamp, label, and confidence.
- Waste distribution by day, week, or month.
- Vietnamese and English interface.

## How classification works

```text
Camera preview → exact frame crop → POST /predict → result → local SQLite history
```

The model is served separately from the APK. The current contract follows the project notebooks:

| Item | Value |
| --- | --- |
| Model | EfficientNet-B0, exported to ONNX |
| Input | RGB `224 × 224`, ImageNet normalization |
| Request | `multipart/form-data`, field name `file` |
| Response | `predicted_class`, `confidence`, `all_probabilities` |

The app maps the nine model labels into three practical groups: organic, recyclable, and other waste.

## Run locally

Requirements: Flutter SDK, Android SDK, and an Android 7.0+ device or emulator.

```bash
flutter pub get
flutter run
```

Use your own API endpoint when developing:

```bash
flutter run \
  --dart-define=WASTE_API_BASE_URL=https://your-api.example.com
```

For an offline UI demo without inference:

```bash
flutter run --dart-define=CLASSIFIER_MODE=mock
```

The default ngrok URL is useful for the project demo, but it is not a permanent production endpoint.

## Project map

```text
lib/
├── core/       theme, configuration, shared widgets
├── data/       models, SQLite repository, local image storage
├── features/   home, camera scan, result, history, settings
└── services/   API/mock classifiers and camera permission
```

Flutter Riverpod selects the classifier implementation. SQLite stores scan metadata, while captured images remain in the app's private directory. `easy_localization` handles the two interface languages, and Be Vietnam Pro is bundled with the app.

## Checks

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
```

## Data and privacy

Scan history is local to the device. In API mode, one cropped image is sent to the configured `/predict` endpoint for inference; the app does not use that endpoint as cloud storage. Clearing app data or uninstalling the app may remove local history.

## Project references

- [Waste classification notebook](https://www.kaggle.com/code/ledainhan/waste-classification)
- [Waste classification API notebook](https://www.kaggle.com/code/ledainhan/waste-classification-api)
