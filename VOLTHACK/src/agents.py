from .fault_engine import diagnose
from .signal_processing import feature_vector
from .cnn_agent import CNNAgent

class SensorAgent:
    def run(self, window):
        return feature_vector(
            window["vibration"],
            window["current"],
            window["temperature"],
            window["rpm"],
            window["sample_rate_hz"],
        )

class VibrationAgent:
    def run(self, features):
        score = max(
            0.0,
            min(
                1.0,
                (
                    features["rms_accel_g"]
                    - 0.8
                ) / 3.0,
            ),
        )

        return {
            "agent": "vibration",
            "score": score,
            "rms": features[
                "rms_accel_g"
            ],
            "dominant_frequency":
                features[
                    "dominant_hz"
                ],
            "crest_factor":
                features[
                    "crest_factor"
                ],
        }

class ElectricalAgent:
    def run(self, features):
        score = max(
            0.0,
            min(
                1.0,
                (
                    features[
                        "current_mean_a"
                    ] - 1.5
                ) / 2.5,
            ),
        )

        return {
            "agent": "electrical",
            "score": score,
            "current":
                features[
                    "current_mean_a"
                ],
            "current_variation":
                features[
                    "current_std_a"
                ],
        }

class ThermalAgent:
    def run(self, features):
        score = max(
            0.0,
            min(
                1.0,
                (
                    features[
                        "temperature_c"
                    ] - 55.0
                ) / 35.0,
            ),
        )

        return {
            "agent": "thermal",
            "score": score,
            "temperature":
                features[
                    "temperature_c"
                ],
        }

class TriageSupervisor:
    def __init__(
        self,
        cnn_model_path=
            "models/motor_1dcnn.keras",
    ):
        self.cnn = CNNAgent(
            cnn_model_path
        )

    def run(self, window):
        features = (
            SensorAgent().run(
                window
            )
        )

        vibration = (
            VibrationAgent().run(
                features
            )
        )

        electrical = (
            ElectricalAgent().run(
                features
            )
        )

        thermal = (
            ThermalAgent().run(
                features
            )
        )

        cnn_probs = (
            self.cnn.run(
                window["vibration"]
            )
            or {}
        )

        diagnosis = diagnose(
            features,
            cnn_probs=cnn_probs,
        )

        return {
            "features":
                features,

            "agent_outputs": {
                "vibration":
                    vibration,
                "electrical":
                    electrical,
                "thermal":
                    thermal,
                "cnn":
                    cnn_probs,
            },

            "diagnosis":
                diagnosis,
        }

def industrial_scale_profile(
    nominal_voltage=12.0,
    nominal_rpm=3000,
    nominal_power_w=60,
):
    return {
        "nominal_voltage_v":
            nominal_voltage,
        "nominal_rpm":
            nominal_rpm,
        "nominal_power_w":
            nominal_power_w,
        "class":
            "prototype",
        "note": (
            "Synthetic operating envelope only. "
            "Not validated industrial data."
        ),
    }
