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
