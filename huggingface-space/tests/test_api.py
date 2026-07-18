import io
import unittest

from fastapi.testclient import TestClient
from PIL import Image

from app import CLASS_NAMES, app


class ApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.client_context = TestClient(app)
        self.client = self.client_context.__enter__()

    def tearDown(self) -> None:
        self.client_context.__exit__(None, None, None)

    def test_health_and_prediction_contract(self) -> None:
        health = self.client.get("/health")
        self.assertEqual(health.status_code, 200)
        self.assertEqual(health.json()["num_classes"], 9)

        image = Image.new("RGB", (300, 260), (120, 150, 180))
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG")
        response = self.client.post(
            "/predict",
            files={"file": ("sample.jpg", buffer.getvalue(), "image/jpeg")},
        )

        self.assertEqual(response.status_code, 200)
        result = response.json()
        self.assertIn(result["predicted_class"], CLASS_NAMES)
        self.assertEqual(tuple(result["all_probabilities"]), CLASS_NAMES)

    def test_rejects_unsupported_content_type(self) -> None:
        response = self.client.post(
            "/predict",
            files={"file": ("sample.txt", b"not an image", "text/plain")},
        )
        self.assertEqual(response.status_code, 415)


if __name__ == "__main__":
    unittest.main()
