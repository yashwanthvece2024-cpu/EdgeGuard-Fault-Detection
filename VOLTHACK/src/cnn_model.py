import numpy as np

CLASS_NAMES = [
    "healthy",
    "imbalance",
    "bearing_fault",
    "electrical_fault",
    "misalignment",
]

def build_model(
    input_length=2048,
    num_classes=len(CLASS_NAMES),
):
    import tensorflow as tf

    inputs = tf.keras.layers.Input(
        shape=(input_length, 1),
        name="vibration_input",
    )

    x = tf.keras.layers.Conv1D(
        16,
        7,
        padding="same",
        activation="relu",
    )(inputs)

    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling1D(4)(x)
    x = tf.keras.layers.Dropout(0.10)(x)

    x = tf.keras.layers.Conv1D(
        32,
        5,
        padding="same",
        activation="relu",
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling1D(4)(x)
    x = tf.keras.layers.Dropout(0.15)(x)

    x = tf.keras.layers.Conv1D(
        64,
        3,
        padding="same",
        activation="relu",
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.GlobalAveragePooling1D(
        name="embedding"
    )(x)

    x = tf.keras.layers.Dense(
        48,
        activation="relu",
    )(x)

    x = tf.keras.layers.Dropout(
        0.30
    )(x)

    outputs = tf.keras.layers.Dense(
        num_classes,
        activation="softmax",
        name="fault_output",
    )(x)

    model = tf.keras.Model(
        inputs,
        outputs,
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(
            learning_rate=1e-3
        ),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=["accuracy"],
    )

    return model

def normalize_window(x):
    x = np.asarray(
        x,
        dtype=np.float32,
    )

    x = x - np.mean(x)

    return x / (
        np.std(x) + 1e-8
    )

def predict_window(
    model,
    x,
):
    x = normalize_window(x)

    probabilities = model.predict(
        x[None, :, None],
        verbose=0,
    )[0]

    return {
        name: float(probability)
        for name, probability
        in zip(
            CLASS_NAMES,
            probabilities,
        )
    }
