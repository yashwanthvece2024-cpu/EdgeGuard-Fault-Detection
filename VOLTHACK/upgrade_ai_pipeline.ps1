$ErrorActionPreference = "Stop"

$Root = "C:\Users\yash2\OneDrive\Documents\PROJECTS\PBL ICML PROJECT\VOLTHACK"
Set-Location $Root

Write-Host "=== VoltHacks AI Robustness Upgrade ===" -ForegroundColor Cyan

$dirs = @(
    "models",
    "data\synthetic",
    "data\ottawa\raw",
    "data\paderborn\raw",
    "data\cwru\raw",
    "data\processed",
    "data\manifests"
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $d) | Out-Null
}

$backup = Join-Path $Root ("backup_ai_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Force $backup | Out-Null

$filesToBackup = @(
    "src\schemas.py",
    "src\cnn_model.py",
    "src\cnn_agent.py",
    "src\fault_engine.py",
    "src\agents.py",
    "src\make_dataset.py",
    "src\train_cnn.py"
)
foreach ($rel in $filesToBackup) {
    $src = Join-Path $Root $rel
    if (Test-Path $src) {
        $dst = Join-Path $backup $rel
        New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
        Copy-Item $src $dst -Force
    }
}

function Write-Utf8File([string]$RelativePath, [string]$Content) {
    $path = Join-Path $Root $RelativePath
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    Set-Content -Path $path -Value $Content -Encoding UTF8
    if ((Get-Item $path).Length -eq 0) {
        throw "Refusing to leave empty file: $RelativePath"
    }
    Write-Host "CREATED/UPDATED: $RelativePath" -ForegroundColor Green
}

Write-Utf8File "src\__init__.py" @'
"""VoltHacks Motor Fault Triage AI package."""
'@

Write-Utf8File "src\schemas.py" @'
from typing import Literal
from pydantic import BaseModel, Field

FaultType = Literal[
    "healthy",
    "bearing_fault",
    "imbalance",
    "misalignment",
    "electrical_fault",
    "overheating",
    "unknown",
]

class Telemetry(BaseModel):
    timestamp: float
    rms_accel_g: float
    current_a: float
    temperature_c: float
    rpm: float = 0.0
    voltage_v: float = 12.0
    sample_rate_hz: float = 1000.0
    source: Literal["simulator", "serial"] = "simulator"

class FaultEvidence(BaseModel):
    vibration_score: float = 0.0
    electrical_score: float = 0.0
    thermal_score: float = 0.0
    cnn_score: float = 0.0
    ood_score: float = 0.0

class Diagnosis(BaseModel):
    fault: FaultType
    confidence: float = Field(ge=0.0, le=1.0)
    severity: Literal["normal", "warning", "critical"]
    affected_component: str
    evidence: FaultEvidence
    recommended_action: str
    rag_sources: list[str] = Field(default_factory=list)
    decision_status: Literal["confident", "uncertain", "out_of_distribution"] = "confident"
'@

Write-Utf8File "src\augmentation.py" @'
import numpy as np

def augment_vibration(
    x,
    rng=None,
    amplitude_range=(0.85, 1.15),
    noise_std_range=(0.005, 0.04),
    shift_fraction=0.03,
):
    """Physically modest augmentation for sensor, mounting and load variation."""
    rng = rng or np.random.default_rng()
    x = np.asarray(x, dtype=np.float32).copy()

    x *= rng.uniform(*amplitude_range)

    max_shift = max(1, int(len(x) * shift_fraction))
    shift = int(rng.integers(-max_shift, max_shift + 1))
    x = np.roll(x, shift)

    noise_std = rng.uniform(*noise_std_range)
    noise = rng.normal(
        0.0,
        noise_std * (np.std(x) + 1e-6),
        size=len(x),
    )
    x += noise.astype(np.float32)

    t = np.linspace(-1.0, 1.0, len(x), dtype=np.float32)
    drift = rng.uniform(-0.03, 0.03) * (np.std(x) + 1e-6) * t
    x += drift

    return x.astype(np.float32)
'@

Write-Utf8File "src\synthetic_dataset.py" @'
from pathlib import Path
import numpy as np
from .augmentation import augment_vibration

CLASS_NAMES = [
    "healthy",
    "imbalance",
    "bearing_fault",
    "electrical_fault",
    "misalignment",
]

def _make_signal(label, n, fs, rng):
    t = np.arange(n, dtype=np.float32) / fs
    rpm = rng.uniform(900.0, 3600.0)
    shaft_hz = rpm / 60.0

    signal = rng.normal(
        0.0,
        rng.uniform(0.015, 0.05),
        n,
    ).astype(np.float32)

    base_amp = rng.uniform(0.08, 0.30)
    signal += base_amp * np.sin(
        2 * np.pi * shaft_hz * t
        + rng.uniform(0, 2 * np.pi)
    )

    if label == "imbalance":
        signal += rng.uniform(0.45, 1.15) * np.sin(
            2 * np.pi * shaft_hz * t
            + rng.uniform(0, 2 * np.pi)
        )
        signal += rng.uniform(0.03, 0.12) * np.sin(
            2 * np.pi * 2 * shaft_hz * t
        )

    elif label == "misalignment":
        signal += rng.uniform(0.30, 0.85) * np.sin(
            2 * np.pi * 2 * shaft_hz * t
            + rng.uniform(0, 2 * np.pi)
        )
        signal += rng.uniform(0.08, 0.25) * np.sin(
            2 * np.pi * 3 * shaft_hz * t
        )

    elif label == "bearing_fault":
        carrier = rng.uniform(3.0, 8.0) * shaft_hz
        impulses = np.zeros(n, dtype=np.float32)
        period = max(1, int(fs / carrier))
        offset = int(rng.integers(0, period))
        decay = rng.uniform(0.93, 0.995)

        for i in range(offset, n, period):
            end = min(n, i + int(fs * 0.015))
            k = np.arange(end - i, dtype=np.float32)
            impulses[i:end] += (
                rng.uniform(0.5, 1.3) * (decay ** k)
            )

        signal += impulses
        signal += rng.uniform(0.08, 0.25) * np.sin(
            2 * np.pi * rng.uniform(4, 12) * shaft_hz * t
        )

    elif label == "electrical_fault":
        f = rng.uniform(0.6, 1.4) * shaft_hz
        signal += rng.uniform(0.15, 0.45) * np.sin(
            2 * np.pi * f * t
        )
        signal += rng.uniform(0.05, 0.18) * np.sin(
            2 * np.pi * 2 * f * t
        )
        modulation = (
            1.0
            + rng.uniform(0.05, 0.25)
            * np.sin(2 * np.pi * rng.uniform(2, 8) * t)
        )
        signal *= modulation

    return augment_vibration(signal, rng=rng).astype(np.float32), rpm

def generate_synthetic_dataset(
    output="data/synthetic/synthetic_windows.npz",
    samples_per_class=1000,
    n=2048,
    fs=4096,
    seed=2026,
):
    rng = np.random.default_rng(seed)
    X, y, groups = [], [], []

    for label_id, label in enumerate(CLASS_NAMES):
        for i in range(samples_per_class):
            x, _ = _make_signal(label, n, fs, rng)
            X.append(x)
            y.append(label_id)
            groups.append(
                f"synthetic_{label}_{i // 10:04d}"
            )

    X = np.asarray(X, dtype=np.float32)
    y = np.asarray(y, dtype=np.int64)
    groups = np.asarray(groups)

    Path(output).parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    np.savez_compressed(
        output,
        X=X,
        y=y,
        groups=groups,
        class_names=np.asarray(CLASS_NAMES),
        sample_rate_hz=np.asarray(
            [fs],
            dtype=np.float32,
        ),
    )

    print(
        f"Saved {len(X)} synthetic windows to {output}"
    )
    print("Classes:", CLASS_NAMES)

if __name__ == "__main__":
    generate_synthetic_dataset()
'@

Write-Utf8File "src\dataset_manager.py" @'
from pathlib import Path
import re
import numpy as np
import pandas as pd
from sklearn.model_selection import GroupShuffleSplit

CLASS_NAMES = [
    "healthy",
    "imbalance",
    "bearing_fault",
    "electrical_fault",
    "misalignment",
]

def ottawa_label_from_name(name):
    stem = Path(name).stem.upper()

    m = re.search(r"([A-Z])-([A-Z])", stem)
    if not m:
        m = re.search(r"([A-Z])([A-Z])", stem)
    if not m:
        return None

    a, b = m.group(1), m.group(2)

    if a == "H" and b == "H":
        return "healthy"

    if b == "U":
        return "imbalance"

    if b == "M":
        return "misalignment"

    if a == "F" and b == "B":
        return "bearing_fault"

    if a == "B":
        # Bowed rotor is kept in the mechanical family.
        return "imbalance"

    if a == "K":
        # Broken rotor bars are treated as an electrical family.
        return "electrical_fault"

    if a in {"S", "V"}:
        return "electrical_fault"

    return None

def _stream_windows(
    csv_path,
    n=2048,
    max_windows=80,
    stride=None,
):
    stride = stride or n
    chunksize = 50000
    buffer = np.empty(0, dtype=np.float32)
    windows = []

    for chunk in pd.read_csv(
        csv_path,
        header=None,
        usecols=[0],
        chunksize=chunksize,
    ):
        values = pd.to_numeric(
            chunk.iloc[:, 0],
            errors="coerce",
        ).dropna().to_numpy(np.float32)

        if len(values) == 0:
            continue

        buffer = np.concatenate(
            [buffer, values]
        )

        while (
            len(buffer) >= n
            and len(windows) < max_windows
        ):
            windows.append(
                buffer[:n].copy()
            )
            buffer = buffer[stride:]

        if len(windows) >= max_windows:
            break

    return windows

def prepare_ottawa(
    raw_dir="data/ottawa/raw",
    output="data/processed/ottawa_windows.npz",
    n=2048,
    max_windows_per_file=80,
):
    raw_dir = Path(raw_dir)
    files = sorted(
        raw_dir.rglob("*.csv")
    )

    if not files:
        raise FileNotFoundError(
            f"No CSV files found under {raw_dir}. "
            "Download/extract the University of Ottawa dataset there first."
        )

    X, y, groups, source_files = [], [], [], []
    skipped = []

    for path in files:
        label = ottawa_label_from_name(
            path.name
        )

        if label is None:
            skipped.append(path.name)
            continue

        windows = _stream_windows(
            path,
            n=n,
            max_windows=max_windows_per_file,
            stride=n,
        )

        for w in windows:
            X.append(w)
            y.append(
                CLASS_NAMES.index(label)
            )
            groups.append(path.stem)
            source_files.append(path.name)

    if not X:
        raise RuntimeError(
            "No recognized Ottawa CSV files were processed. "
            "Run the command and inspect the printed skipped filenames."
        )

    X = np.asarray(X, dtype=np.float32)
    y = np.asarray(y, dtype=np.int64)
    groups = np.asarray(groups)
    source_files = np.asarray(source_files)

    Path(output).parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    np.savez_compressed(
        output,
        X=X,
        y=y,
        groups=groups,
        source_files=source_files,
        class_names=np.asarray(CLASS_NAMES),
    )

    print(
        f"Processed {len(X)} Ottawa windows "
        f"from {len(set(groups))} recordings."
    )

    if skipped:
        print(
            "Skipped unrecognized files "
            "(first 20):",
            skipped[:20],
        )

    print("Saved:", output)

if __name__ == "__main__":
    prepare_ottawa()
'@

Write-Utf8File "src\evaluation.py" @'
from pathlib import Path
import json
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)

def evaluate_predictions(
    y_true,
    probabilities,
    class_names,
    output_dir="data/processed/evaluation",
):
    Path(output_dir).mkdir(
        parents=True,
        exist_ok=True,
    )

    probabilities = np.asarray(
        probabilities
    )

    y_pred = np.argmax(
        probabilities,
        axis=1,
    )

    metrics = {
        "accuracy": float(
            accuracy_score(y_true, y_pred)
        ),
        "balanced_accuracy": float(
            balanced_accuracy_score(
                y_true,
                y_pred,
            )
        ),
        "precision_macro": float(
            precision_score(
                y_true,
                y_pred,
                average="macro",
                zero_division=0,
            )
        ),
        "recall_macro": float(
            recall_score(
                y_true,
                y_pred,
                average="macro",
                zero_division=0,
            )
        ),
        "f1_macro": float(
            f1_score(
                y_true,
                y_pred,
                average="macro",
                zero_division=0,
            )
        ),
        "f1_weighted": float(
            f1_score(
                y_true,
                y_pred,
                average="weighted",
                zero_division=0,
            )
        ),
    }

    report = classification_report(
        y_true,
        y_pred,
        target_names=class_names,
        zero_division=0,
        output_dict=True,
    )

    with open(
        Path(output_dir) / "metrics.json",
        "w",
        encoding="utf-8",
    ) as f:
        json.dump(
            {
                "overall": metrics,
                "per_class": report,
            },
            f,
            indent=2,
        )

    cm = confusion_matrix(
        y_true,
        y_pred,
        labels=np.arange(
            len(class_names)
        ),
    )

    fig = plt.figure(
        figsize=(8, 7)
    )

    ax = fig.add_subplot(111)

    im = ax.imshow(cm)

    ax.set(
        xticks=np.arange(
            len(class_names)
        ),
        yticks=np.arange(
            len(class_names)
        ),
        xticklabels=class_names,
        yticklabels=class_names,
        xlabel="Predicted",
        ylabel="True",
        title="Motor Fault Confusion Matrix",
    )

    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            ax.text(
                j,
                i,
                int(cm[i, j]),
                ha="center",
                va="center",
            )

    fig.colorbar(
        im,
        ax=ax,
    )

    fig.tight_layout()

    fig.savefig(
        Path(output_dir)
        / "confusion_matrix.png",
        dpi=160,
    )

    plt.close(fig)

    print(
        json.dumps(
            metrics,
            indent=2,
        )
    )

    return metrics

def evaluate_keras_model(
    model,
    X,
    y,
    class_names,
    output_dir,
    batch_size=64,
):
    probabilities = model.predict(
        X[..., None],
        batch_size=batch_size,
        verbose=0,
    )

    return evaluate_predictions(
        y,
        probabilities,
        class_names,
        output_dir,
    )
'@

Write-Utf8File "src\calibration.py" @'
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
'@

Write-Utf8File "src\ood_detector.py" @'
from pathlib import Path
import numpy as np

class EmbeddingOODDetector:
    """
    Lightweight OOD detector based on distance from
    class centroids in the CNN embedding space.
    """

    def __init__(
        self,
        model,
        threshold=None,
    ):
        self.model = model
        self.threshold = threshold
        self.centroids = None
        self.scale = None

        import tensorflow as tf

        try:
            self.encoder = tf.keras.Model(
                model.input,
                model.get_layer(
                    "embedding"
                ).output,
            )
        except Exception as exc:
            raise RuntimeError(
                "CNN must contain an 'embedding' layer."
            ) from exc

    def fit(
        self,
        X,
        y,
        quantile=0.95,
    ):
        embeddings = (
            self.encoder.predict(
                X[..., None],
                verbose=0,
            )
        )

        self.centroids = {}

        distances = []

        for c in np.unique(y):
            ec = embeddings[
                y == c
            ]

            centroid = np.mean(
                ec,
                axis=0,
            )

            self.centroids[
                int(c)
            ] = centroid

            distances.extend(
                np.linalg.norm(
                    ec - centroid,
                    axis=1,
                ).tolist()
            )

        distances = np.asarray(
            distances
        )

        self.threshold = float(
            np.quantile(
                distances,
                quantile,
            )
        )

        self.scale = float(
            np.std(distances)
            + 1e-8
        )

        return self

    def score(self, X):
        embeddings = (
            self.encoder.predict(
                X[..., None],
                verbose=0,
            )
        )

        scores = []

        for embedding in embeddings:
            distance = min(
                float(
                    np.linalg.norm(
                        embedding
                        - centroid
                    )
                )
                for centroid
                in self.centroids.values()
            )

            scores.append(
                distance
            )

        return np.asarray(
            scores,
            dtype=np.float32,
        )

    def is_ood(self, X):
        return (
            self.score(X)
            > self.threshold
        )

    def save(
        self,
        path="models/ood_detector.npz",
    ):
        Path(path).parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        keys = np.asarray(
            sorted(
                self.centroids.keys()
            ),
            dtype=np.int64,
        )

        centroids = np.stack(
            [
                self.centroids[
                    int(k)
                ]
                for k in keys
            ]
        )

        np.savez_compressed(
            path,
            class_ids=keys,
            centroids=centroids,
            threshold=np.asarray(
                [self.threshold],
                dtype=np.float32,
            ),
            scale=np.asarray(
                [self.scale],
                dtype=np.float32,
            ),
        )

    def load(
        self,
        path="models/ood_detector.npz",
    ):
        data = np.load(path)

        keys = data[
            "class_ids"
        ]

        centroids = data[
            "centroids"
        ]

        self.centroids = {
            int(k):
                centroids[i]
            for i, k
            in enumerate(keys)
        }

        self.threshold = float(
            data["threshold"][0]
        )

        self.scale = float(
            data["scale"][0]
        )

        return self
'@

Write-Utf8File "src\cnn_model.py" @'
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
'@

Write-Utf8File "src\cnn_agent.py" @'
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
'@

Write-Utf8File "src\fault_engine.py" @'
from .schemas import Diagnosis, FaultEvidence

def diagnose(
    features,
    cnn_probs=None,
):
    cnn_probs = cnn_probs or {}

    vibration = features[
        "rms_accel_g"
    ]

    current = features[
        "current_mean_a"
    ]

    temperature = features[
        "temperature_c"
    ]

    dominant_frequency = features[
        "dominant_hz"
    ]

    bearing_score = 0.0

    if dominant_frequency > 400:
        bearing_score = min(
            1.0,
            max(
                0.0,
                (vibration - 1.2)
                / 2.0,
            ),
        )

    imbalance_score = min(
        1.0,
        max(
            0.0,
            (vibration - 1.0)
            / 2.5,
        ),
    )

    electrical_score = min(
        1.0,
        max(
            0.0,
            (current - 1.5)
            / 2.5,
        ),
    )

    thermal_score = min(
        1.0,
        max(
            0.0,
            (temperature - 55.0)
            / 35.0,
        ),
    )

    misalignment_score = 0.0

    if dominant_frequency > 0:
        misalignment_score = min(
            1.0,
            max(
                0.0,
                (vibration - 0.9)
                / 3.0,
            ),
        )

    scores = {
        "bearing_fault":
            0.45 * bearing_score
            + 0.55
            * cnn_probs.get(
                "bearing_fault",
                0.0,
            ),

        "imbalance":
            0.45 * imbalance_score
            + 0.55
            * cnn_probs.get(
                "imbalance",
                0.0,
            ),

        "misalignment":
            0.45 * misalignment_score
            + 0.55
            * cnn_probs.get(
                "misalignment",
                0.0,
            ),

        "electrical_fault":
            0.45 * electrical_score
            + 0.55
            * cnn_probs.get(
                "electrical_fault",
                0.0,
            ),

        "overheating":
            thermal_score,
    }

    if bool(
        cnn_probs.get(
            "_ood",
            False,
        )
    ):
        return Diagnosis(
            fault="unknown",
            confidence=0.0,
            severity="warning",
            affected_component=(
                "unknown / outside trained distribution"
            ),
            evidence=FaultEvidence(
                vibration_score=max(
                    bearing_score,
                    imbalance_score,
                    misalignment_score,
                ),
                electrical_score=
                    electrical_score,
                thermal_score=
                    thermal_score,
                cnn_score=max(
                    [
                        value
                        for key, value
                        in cnn_probs.items()
                        if not key.startswith("_")
                    ]
                    or [0.0]
                ),
                ood_score=float(
                    cnn_probs.get(
                        "_ood_distance",
                        0.0,
                    )
                ),
            ),
            recommended_action=(
                "Collect another window and verify "
                "operating condition, sensor mounting "
                "and RPM before assigning a fault."
            ),
            decision_status=(
                "out_of_distribution"
            ),
        )

    fault, confidence = max(
        scores.items(),
        key=lambda item: item[1],
    )

    if confidence < 0.45:
        return Diagnosis(
            fault="unknown",
            confidence=float(
                confidence
            ),
            severity="normal",
            affected_component=(
                "not confidently identified"
            ),
            evidence=FaultEvidence(
                vibration_score=max(
                    bearing_score,
                    imbalance_score,
                    misalignment_score,
                ),
                electrical_score=
                    electrical_score,
                thermal_score=
                    thermal_score,
                cnn_score=max(
                    [
                        value
                        for key, value
                        in cnn_probs.items()
                        if not key.startswith("_")
                    ]
                    or [0.0]
                ),
            ),
            recommended_action=(
                "Collect additional diagnostic "
                "windows and verify RPM/load."
            ),
            decision_status="uncertain",
        )

    severity = (
        "normal"
        if confidence < 0.60
        else "warning"
        if confidence < 0.82
        else "critical"
    )

    component = {
        "bearing_fault":
            "front bearing",
        "imbalance":
            "rotor / motor assembly",
        "misalignment":
            "shaft / coupling",
        "electrical_fault":
            "motor electrical circuit",
        "overheating":
            "motor housing / windings",
    }.get(
        fault,
        "unknown",
    )

    action = {
        "bearing_fault":
            "Inspect bearing lubrication, play, "
            "temperature and vibration.",
        "imbalance":
            "Inspect rotor balance, coupling "
            "and mounting.",
        "misalignment":
            "Inspect shaft alignment, coupling "
            "and mounting.",
        "electrical_fault":
            "Check current draw, controller, "
            "supply and motor circuit.",
        "overheating":
            "Inspect cooling, loading, bearings "
            "and electrical condition.",
    }.get(
        fault,
        "Collect another diagnostic window.",
    )

    return Diagnosis(
        fault=fault,
        confidence=float(
            min(
                1.0,
                confidence,
            )
        ),
        severity=severity,
        affected_component=component,
        evidence=FaultEvidence(
            vibration_score=max(
                bearing_score,
                imbalance_score,
                misalignment_score,
            ),
            electrical_score=
                electrical_score,
            thermal_score=
                thermal_score,
            cnn_score=max(
                [
                    value
                    for key, value
                    in cnn_probs.items()
                    if not key.startswith("_")
                ]
                or [0.0]
            ),
        ),
        recommended_action=action,
        decision_status="confident",
    )
'@

Write-Utf8File "src\agents.py" @'
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
'@

Write-Utf8File "src\make_dataset.py" @'
from .synthetic_dataset import generate_synthetic_dataset

if __name__ == "__main__":
    generate_synthetic_dataset(
        output=(
            "data/synthetic/"
            "synthetic_windows.npz"
        ),
        samples_per_class=1000,
        n=2048,
        fs=4096,
        seed=2026,
    )
'@

Write-Utf8File "src\prepare_training_data.py" @'
from pathlib import Path
import numpy as np
from sklearn.model_selection import GroupShuffleSplit

from .synthetic_dataset import (
    generate_synthetic_dataset
)

SYNTHETIC = Path(
    "data/synthetic/"
    "synthetic_windows.npz"
)

OTTAWA = Path(
    "data/processed/"
    "ottawa_windows.npz"
)

OUT = Path(
    "data/processed"
)

def load_npz(path):
    data = np.load(
        path,
        allow_pickle=True,
    )

    return (
        np.asarray(
            data["X"],
            dtype=np.float32,
        ),
        np.asarray(
            data["y"],
            dtype=np.int64,
        ),
        np.asarray(
            data["groups"]
        ).astype(str),
    )

def split_groups(
    X,
    y,
    groups,
    seed=2026,
):
    """
    Split by recording/group rather than by individual windows.
    This is the key leakage-control mechanism.
    """

    gss = GroupShuffleSplit(
        n_splits=1,
        test_size=0.20,
        random_state=seed,
    )

    train_idx, temp_idx = next(
        gss.split(
            X,
            y,
            groups,
        )
    )

    X_train = X[
        train_idx
    ]

    y_train = y[
        train_idx
    ]

    g_train = groups[
        train_idx
    ]

    X_temp = X[
        temp_idx
    ]

    y_temp = y[
        temp_idx
    ]

    g_temp = groups[
        temp_idx
    ]

    gss2 = GroupShuffleSplit(
        n_splits=1,
        test_size=0.50,
        random_state=seed + 1,
    )

    val_idx, test_idx = next(
        gss2.split(
            X_temp,
            y_temp,
            g_temp,
        )
    )

    return (
        (
            X_train,
            y_train,
            g_train,
        ),
        (
            X_temp[val_idx],
            y_temp[val_idx],
            g_temp[val_idx],
        ),
        (
            X_temp[test_idx],
            y_temp[test_idx],
            g_temp[test_idx],
        ),
    )

def save_split(
    name,
    X,
    y,
    groups,
):
    output = (
        OUT / f"{name}.npz"
    )

    np.savez_compressed(
        output,
        X=np.asarray(
            X,
            dtype=np.float32,
        ),
        y=np.asarray(
            y,
            dtype=np.int64,
        ),
        groups=np.asarray(
            groups
        ),
    )

    print(
        f"{name}: "
        f"{len(X)} windows, "
        f"{len(set(groups))} groups"
    )

def main():
    OUT.mkdir(
        parents=True,
        exist_ok=True,
    )

    if not SYNTHETIC.exists():
        print(
            "Synthetic dataset missing. "
            "Creating it..."
        )

        generate_synthetic_dataset(
            output=str(
                SYNTHETIC
            ),
            samples_per_class=1000,
            n=2048,
            fs=4096,
            seed=2026,
        )

    Xs, ys, gs = load_npz(
        SYNTHETIC
    )

    if OTTAWA.exists():
        Xr, yr, gr = load_npz(
            OTTAWA
        )

        real_train, real_val, real_test = (
            split_groups(
                Xr,
                yr,
                gr,
                seed=77,
            )
        )

        syn_train, syn_val, _ = (
            split_groups(
                Xs,
                ys,
                gs,
                seed=78,
            )
        )

        X_train = np.concatenate(
            [
                syn_train[0],
                real_train[0],
            ],
            axis=0,
        )

        y_train = np.concatenate(
            [
                syn_train[1],
                real_train[1],
            ],
            axis=0,
        )

        g_train = np.concatenate(
            [
                np.asarray(
                    [
                        "synthetic_" + g
                        for g in syn_train[2]
                    ]
                ),
                np.asarray(
                    [
                        "ottawa_" + g
                        for g in real_train[2]
                    ]
                ),
            ]
        )

        X_val = np.concatenate(
            [
                syn_val[0],
                real_val[0],
            ],
            axis=0,
        )

        y_val = np.concatenate(
            [
                syn_val[1],
                real_val[1],
            ],
            axis=0,
        )

        g_val = np.concatenate(
            [
                np.asarray(
                    [
                        "synthetic_" + g
                        for g in syn_val[2]
                    ]
                ),
                np.asarray(
                    [
                        "ottawa_" + g
                        for g in real_val[2]
                    ]
                ),
            ]
        )

        # The final test is REAL Ottawa data only.
        X_test, y_test, g_test = (
            real_test
        )

        save_split(
            "train",
            X_train,
            y_train,
            g_train,
        )

        save_split(
            "val",
            X_val,
            y_val,
            g_val,
        )

        save_split(
            "test",
            X_test,
            y_test,
            [
                "OTTAWA_TEST_" + g
                for g in g_test
            ],
        )

        print(
            "\nFINAL TEST = REAL OTTAWA ONLY"
        )

    else:
        syn_train, syn_val, syn_test = (
            split_groups(
                Xs,
                ys,
                gs,
            )
        )

        save_split(
            "train",
            *syn_train,
        )

        save_split(
            "val",
            *syn_val,
        )

        save_split(
            "test",
            *syn_test,
        )

        print(
            "\nWARNING: Ottawa data not found."
        )

        print(
            "This is synthetic-only evaluation."
        )

if __name__ == "__main__":
    main()
'@

Write-Utf8File "src\train_cnn.py" @'
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
'@

Write-Utf8File "src\external_test.py" @'
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
'@

Write-Utf8File "data\README_AI_DATA.md" @'
# VoltHacks AI Data Policy

## Synthetic data

`data/synthetic/` is controlled development data. It is useful for debugging and proving that the pipeline works, but its accuracy must never be presented as industrial validation.

## University of Ottawa data

Place the real CSV files under:

`data/ottawa/raw/`

The University of Ottawa dataset contains vibration, acoustic and temperature measurements from eight D396 Marathon Electric three-phase motors, with 420,000 samples per 10-second file at 42 kHz. Its filenames encode health condition, speed and load. The preprocessing code uses the first accelerometer column for the vibration CNN.

## Paderborn

`data/paderborn/raw/` is reserved for cross-domain bearing validation. Do not merge it blindly with Ottawa labels because the experimental setup and label taxonomy differ.

## CWRU

`data/cwru/raw/` is reserved for an independent bearing benchmark.

## Leakage rule

Never randomly split overlapping windows from the same recording into train and test. Split by recording/run/machine group first.

## Reporting rule

Report:
- accuracy
- balanced accuracy
- precision
- recall
- macro F1
- weighted F1
- confusion matrix
- calibration
- OOD/unknown rejection
- inference latency

A synthetic 100% score is a development result, not industrial accuracy.
'@

Write-Utf8File "AI_TRAINING_PLAN.md" @'
# VoltHacks AI Training Plan

SENSE
ESP32 -> vibration/current/temperature/RPM

PROCESS
RMS -> FFT -> statistical features

SPECIALISTS
Vibration Agent
Electrical Agent
Thermal Agent

CNN
Lightweight 1D CNN learns vibration fault families

TRIAGE
CNN + specialist evidence

CALIBRATION
Temperature scaling on validation probabilities

OOD
Embedding-distance rejection for unfamiliar signals

RAG
Maintenance explanation grounded in the knowledge store

SHOW
Streamlit dashboard + digital twin

## Fault families

healthy
imbalance
bearing_fault
electrical_fault
misalignment

## Evaluation ladder

1. Strict synthetic group-wise benchmark
2. Synthetic + Ottawa real training groups
3. Ottawa held-out real test
4. Paderborn cross-domain bearing test
5. CWRU independent bearing benchmark
6. Physical 775 motor MVP

## Product rule

The system must be allowed to answer:
"unknown / outside trained distribution"
instead of forcing every unfamiliar waveform into a known class.
'@

Write-Utf8File "requirements-cnn.txt" @'
-r requirements.txt
tensorflow>=2.20
scipy>=1.13
matplotlib>=3.9
seaborn>=0.13
scikit-learn>=1.5
'@

Write-Host ""
Write-Host "=== VERIFYING CREATED FILES ===" -ForegroundColor Cyan

$check = @(
    "src\__init__.py",
    "src\schemas.py",
    "src\augmentation.py",
    "src\synthetic_dataset.py",
    "src\dataset_manager.py",
    "src\evaluation.py",
    "src\calibration.py",
    "src\ood_detector.py",
    "src\cnn_model.py",
    "src\cnn_agent.py",
    "src\fault_engine.py",
    "src\agents.py",
    "src\make_dataset.py",
    "src\prepare_training_data.py",
    "src\train_cnn.py",
    "src\external_test.py",
    "data\README_AI_DATA.md",
    "AI_TRAINING_PLAN.md"
)

foreach ($rel in $check) {
    $p = Join-Path $Root $rel

    if (!(Test-Path $p)) {
        throw "MISSING FILE: $rel"
    }

    if ((Get-Item $p).Length -eq 0) {
        throw "EMPTY FILE: $rel"
    }
}

Write-Host ""
Write-Host "=== SUCCESS: AI FILES CREATED AND NONE ARE EMPTY ===" -ForegroundColor Green
Write-Host "Backup: $backup"
Write-Host ""
Write-Host "NEXT:"
Write-Host "1. python -m src.make_dataset"
Write-Host "2. Put Ottawa CSV files in data\ottawa\raw"
Write-Host "3. python -m src.dataset_manager"
Write-Host "4. python -m src.prepare_training_data"
Write-Host "5. python -m src.train_cnn"
Write-Host ""
