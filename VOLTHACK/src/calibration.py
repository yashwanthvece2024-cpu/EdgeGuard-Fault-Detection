from pathlib import Path
import json
import numpy as np
from scipy.optimize import minimize_scalar

def _softmax(z):
    z = z - np.max(
        z,
        axis=1,
        keepdims=True,
    )
    e = np.exp(z)
    return e / np.sum(
        e,
        axis=1,
        keepdims=True,
    )

def fit_temperature(
    probabilities,
    y_true,
    output="models/temperature.json",
):
    probabilities = np.clip(
        np.asarray(
            probabilities,
            dtype=np.float64,
        ),
        1e-7,
        1.0,
    )

    y_true = np.asarray(
        y_true,
        dtype=np.int64,
    )

    logits = np.log(
        probabilities
    )

    def nll(log_t):
        temperature = float(
            np.exp(log_t)
        )

        p = _softmax(
            logits / temperature
        )

        return float(
            -np.mean(
                np.log(
                    np.clip(
                        p[
                            np.arange(
                                len(y_true)
                            ),
                            y_true,
                        ],
                        1e-7,
                        1.0,
                    )
                )
            )
        )

    result = minimize_scalar(
        nll,
        bounds=(-2.0, 2.0),
        method="bounded",
    )

    temperature = float(
        np.exp(result.x)
    )

    Path(output).parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with open(
        output,
        "w",
        encoding="utf-8",
    ) as f:
        json.dump(
            {
                "temperature":
                    temperature
            },
            f,
            indent=2,
        )

    print(
        f"Calibration temperature: "
        f"{temperature:.4f}"
    )

    print(
        "Saved:",
        output,
    )

    return temperature

def load_temperature(
    path="models/temperature.json"
):
    with open(
        path,
        "r",
        encoding="utf-8",
    ) as f:
        return float(
            json.load(f)[
                "temperature"
            ]
        )

def calibrate_probabilities(
    probabilities,
    temperature,
):
    probabilities = np.clip(
        np.asarray(
            probabilities,
            dtype=np.float64,
        ),
        1e-7,
        1.0,
    )

    logits = np.log(
        probabilities
    )

    return _softmax(
        logits / float(
            temperature
        )
    ).astype(
        np.float32
    )
