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
