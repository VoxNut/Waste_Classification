import io
import math
import unittest

from PIL import Image

import app


class InferenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        app.load_model()

    def test_preprocessing_and_model_contract(self) -> None:
        image = Image.new("RGB", (320, 240), (90, 160, 120))
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG")

        tensor = app.preprocess_image(buffer.getvalue())
        label, confidence, probabilities = app.predict(buffer.getvalue())

        self.assertEqual(tensor.shape, (1, 3, 224, 224))
        self.assertIn(label, app.CLASS_NAMES)
        self.assertGreaterEqual(confidence, 0.0)
        self.assertLessEqual(confidence, 1.0)
        self.assertEqual(tuple(probabilities), app.CLASS_NAMES)
        self.assertTrue(math.isclose(sum(probabilities.values()), 1.0, abs_tol=1e-6))


if __name__ == "__main__":
    unittest.main()
