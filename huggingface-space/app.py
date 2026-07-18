from __future__ import annotations

import io
from contextlib import asynccontextmanager
from pathlib import Path

import numpy as np
import onnxruntime as ort
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError

MODEL_PATH = Path(__file__).parent / "model" / "efficientnet_b0_realwaste.onnx"
CLASS_NAMES = (
    "Cardboard",
    "Food Organics",
    "Glass",
    "Metal",
    "Miscellaneous Trash",
    "Paper",
    "Plastic",
    "Textile Trash",
    "Vegetation",
)
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_IMAGE_BYTES = 10 * 1024 * 1024
IMAGE_SIZE = (224, 224)
IMAGENET_MEAN = np.asarray([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.asarray([0.229, 0.224, 0.225], dtype=np.float32)

_session: ort.InferenceSession | None = None
_input_name = ""
_output_name = ""


def load_model() -> None:
    global _session, _input_name, _output_name
    if _session is not None:
        return
    if not MODEL_PATH.is_file():
        raise RuntimeError(f"Model file not found: {MODEL_PATH}")

    options = ort.SessionOptions()
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    options.intra_op_num_threads = 2
    _session = ort.InferenceSession(
        str(MODEL_PATH),
        sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    _input_name = _session.get_inputs()[0].name
    _output_name = _session.get_outputs()[0].name

    output_shape = _session.get_outputs()[0].shape
    if output_shape[-1] != len(CLASS_NAMES):
        raise RuntimeError(
            f"Model returns {output_shape[-1]} classes; expected {len(CLASS_NAMES)}."
        )


@asynccontextmanager
async def lifespan(_: FastAPI):
    load_model()
    yield


app = FastAPI(
    title="Waste Classification API",
    description="EfficientNet-B0 ONNX inference for the nine RealWaste classes.",
    version="1.0.0",
    lifespan=lifespan,
)


def preprocess_image(contents: bytes) -> np.ndarray:
    try:
        with Image.open(io.BytesIO(contents)) as image:
            image.load()
            rgb = image.convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError) as error:
        raise ValueError("The uploaded file is not a valid image.") from error

    resized = rgb.resize(IMAGE_SIZE, Image.Resampling.BILINEAR)
    pixels = np.asarray(resized, dtype=np.float32) / 255.0
    normalized = (pixels - IMAGENET_MEAN) / IMAGENET_STD
    return np.transpose(normalized, (2, 0, 1))[np.newaxis, ...].astype(
        np.float32,
        copy=False,
    )


def predict(contents: bytes) -> tuple[str, float, dict[str, float]]:
    load_model()
    assert _session is not None
    tensor = preprocess_image(contents)
    logits = np.asarray(
        _session.run([_output_name], {_input_name: tensor})[0][0],
        dtype=np.float64,
    )
    shifted = logits - np.max(logits)
    probabilities = np.exp(shifted) / np.exp(shifted).sum()
    predicted_index = int(np.argmax(probabilities))
    all_probabilities = {
        label: float(probabilities[index])
        for index, label in enumerate(CLASS_NAMES)
    }
    return (
        CLASS_NAMES[predicted_index],
        float(probabilities[predicted_index]),
        all_probabilities,
    )


@app.get("/")
@app.get("/health")
def health() -> dict[str, object]:
    load_model()
    return {
        "status": "ok",
        "model": "EfficientNet-B0 ONNX",
        "num_classes": len(CLASS_NAMES),
    }


@app.post("/predict")
async def classify(file: UploadFile = File(...)) -> dict[str, object]:
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail="Only JPEG, PNG, and WebP images are supported.",
        )

    contents = await file.read(MAX_IMAGE_BYTES + 1)
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")
    if len(contents) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="The image exceeds the 10 MB limit.")

    try:
        predicted_class, confidence, all_probabilities = predict(contents)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    return {
        "predicted_class": predicted_class,
        "confidence": confidence,
        "all_probabilities": all_probabilities,
    }
