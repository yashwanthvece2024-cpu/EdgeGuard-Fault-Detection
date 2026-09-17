from pathlib import Path
import numpy as np

from .cnn_model import predict_window

class CNNAgent:
    def __init__(
        self,
        model_path="models/motor_1dcnn.keras",
    ):
        self.model = None
        self.model_path = Path(
            model_path
        )
        self.ood = None
        self.temperature = 1.0

        if self.model_path.exists():
            import tensorflow as tf

            self.model = (
                tf.keras.models.load_model(
                    self.model_path
                )
            )

            ood_path = Path(
                "models/ood_detector.npz"
            )

            if ood_path.exists():
                from .ood_detector import (
                    EmbeddingOODDetector
                )

                self.ood = (
                    EmbeddingOODDetector(
                        self.model
                    ).load(
                        ood_path
                    )
                )

            temp_path = Path(
                "models/temperature.json"
            )

            if temp_path.exists():
                from .calibration import (
                    load_temperature
                )

                self.temperature = (
                    load_temperature(
                        temp_path
                    )
                )

    def available(self):
        return (
            self.model is not None
        )

    def run(
        self,
        vibration_window,
    ):
        if self.model is None:
            return None

        x = np.asarray(
            vibration_window,
            dtype=np.float32,
        )

        probs = predict_window(
            self.model,
            x,
        )

        from .calibration import (
            calibrate_probabilities
        )

        names = list(
            probs.keys()
        )

        raw = np.asarray(
            [
                probs[name]
                for name in names
            ],
            dtype=np.float32,
        )

        calibrated = (
            calibrate_probabilities(
                raw[None, :],
                self.temperature,
            )[0]
        )

        result = {
            name: float(probability)
            for name, probability
            in zip(
                names,
                calibrated,
            )
        }

        if self.ood is not None:
            distance = float(
                self.ood.score(
                    x[None, :]
                )[0]
            )

            result[
                "_ood_distance"
            ] = distance

            result["_ood"] = bool(
                distance
                > self.ood.threshold
            )

        return result
