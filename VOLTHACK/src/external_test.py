from pathlib import Path
import numpy as np
import tensorflow as tf

from .cnn_model import (
    CLASS_NAMES,
    normalize_window,
)

from .evaluation import (
    evaluate_predictions
)

def main(
    path="data/processed/"
         "ottawa_windows.npz"
):
    path = Path(path)

    if not path.exists():
        raise FileNotFoundError(
            path
        )

    model = (
        tf.keras.models.load_model(
            "models/"
            "motor_1dcnn.keras"
        )
    )

    data = np.load(
        path,
        allow_pickle=True,
    )

    X = np.asarray(
        data["X"],
        dtype=np.float32,
    )

    y = np.asarray(
        data["y"],
        dtype=np.int64,
    )

    X = np.stack(
        [
            normalize_window(
                x
            )
            for x in X
        ]
    )

    probabilities = (
        model.predict(
            X[..., None],
            batch_size=64,
            verbose=1,
        )
    )

    evaluate_predictions(
        y,
        probabilities,
        CLASS_NAMES,
        output_dir=(
            "data/processed/"
            "evaluation_external"
        ),
    )

if __name__ == "__main__":
    main()
