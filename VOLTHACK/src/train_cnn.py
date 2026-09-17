from pathlib import Path
import json
import numpy as np
import tensorflow as tf

from .cnn_model import (
    build_model,
    normalize_window,
    CLASS_NAMES,
)

from .evaluation import (
    evaluate_keras_model
)

from .calibration import (
    fit_temperature
)

from .ood_detector import (
    EmbeddingOODDetector
)

TRAIN = Path(
    "data/processed/train.npz"
)

VAL = Path(
    "data/processed/val.npz"
)

TEST = Path(
    "data/processed/test.npz"
)

OUTPUT = Path(
    "models/motor_1dcnn.keras"
)

def load_split(path):
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
                sample
            )
            for sample in X
        ]
    )

    return X, y

def main():
    for path in [
        TRAIN,
        VAL,
        TEST,
    ]:
        if not path.exists():
            raise FileNotFoundError(
                f"Missing {path}. "
                "Run: "
                "python -m "
                "src.prepare_training_data"
            )

    X_train, y_train = load_split(
        TRAIN
    )

    X_val, y_val = load_split(
        VAL
    )

    X_test, y_test = load_split(
        TEST
    )

    print(
        "TRAIN:",
        X_train.shape,
    )

    print(
        "VAL:",
        X_val.shape,
    )

    print(
        "TEST:",
        X_test.shape,
    )

    print(
        "CLASSES:",
        CLASS_NAMES,
    )

    model = build_model(
        input_length=X_train.shape[1],
        num_classes=len(
            CLASS_NAMES
        ),
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss",
            patience=10,
            restore_best_weights=True,
        ),

        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=4,
            min_lr=1e-5,
        ),
    ]

    model.fit(
        X_train,
        y_train,
        validation_data=(
            X_val,
            y_val,
        ),
        epochs=80,
        batch_size=64,
        shuffle=True,
        callbacks=callbacks,
        verbose=1,
    )

    OUTPUT.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    model.save(
        OUTPUT
    )

    print(
        "\n=== HELD-OUT TEST ==="
    )

    evaluate_keras_model(
        model,
        X_test,
        y_test,
        CLASS_NAMES,
        "data/processed/"
        "evaluation_test",
    )

    print(
        "\n=== TEMPERATURE CALIBRATION ==="
    )

    val_probabilities = (
        model.predict(
            X_val[..., None],
            verbose=0,
        )
    )

    fit_temperature(
        val_probabilities,
        y_val,
        output=(
            "models/"
            "temperature.json"
        ),
    )

    print(
        "\n=== OOD DETECTOR ==="
    )

    detector = (
        EmbeddingOODDetector(
            model
        )
    )

    detector.fit(
        X_val,
        y_val,
        quantile=0.95,
    )

    detector.save(
        "models/"
        "ood_detector.npz"
    )

    print(
        "OOD threshold:",
        detector.threshold,
    )

    with open(
        "models/model_card.json",
        "w",
        encoding="utf-8",
    ) as f:
        json.dump(
            {
                "model":
                    "VoltHacks lightweight 1D CNN",

                "classes":
                    CLASS_NAMES,

                "input_length":
                    int(
                        X_train.shape[1]
                    ),

                "purpose":
                    "motor vibration "
                    "fault-family classification",

                "synthetic_accuracy_is_not_an_industrial_claim":
                    True,

                "evaluation":
                    {
                        "split":
                            "group/run-wise",
                        "metrics":
                            [
                                "accuracy",
                                "balanced_accuracy",
                                "precision_macro",
                                "recall_macro",
                                "f1_macro",
                                "f1_weighted",
                            ],
                        "ood_rejection":
                            True,
                        "temperature_calibration":
                            True,
                    },
            },
            f,
            indent=2,
        )

    print(
        "\nSaved:",
        OUTPUT,
    )

if __name__ == "__main__":
    main()
