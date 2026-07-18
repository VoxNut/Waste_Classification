---
title: Waste Classification API
emoji: ♻️
colorFrom: green
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
license: gpl-3.0
---

# Waste Classification API

Public FastAPI inference for the Waste Classification Android app. The Docker
Space serves the EfficientNet-B0 model exported to ONNX by the training
notebook and implements the same nine-class contract as the API notebook.

- Health: `GET /health`
- Interactive docs: `GET /docs`
- Inference: `POST /predict` as `multipart/form-data`, field `file`
- Supported images: JPEG, PNG, WebP (maximum 10 MB)

```bash
curl -X POST \
  -F "file=@sample.jpg" \
  https://voxnuts947-waste-classification-api.hf.space/predict
```

The response includes `predicted_class`, `confidence`, and
`all_probabilities`. Input is resized to 224 x 224 and normalized with the
ImageNet mean and standard deviation used during training.

## Sources

- [Training notebook](https://www.kaggle.com/code/ledainhan/waste-classification)
- [API notebook](https://www.kaggle.com/code/ledainhan/waste-classification-api)
- [Android application](https://github.com/VoxNut/Waste_Classification)

Model SHA-256: `bc573cb16ab51dad2c239262db1872c8221493b41bf02bcd1efedc9cac3c2f52`
