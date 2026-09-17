import numpy as np

def make_window(fault="healthy"):
    return {
        "vibration": np.random.normal(0, 0.1, 2048).astype(np.float32),
        "current": np.random.normal(1.5, 0.1, 2048).astype(np.float32),
        "temperature": 45.0 + np.random.uniform(0, 5),
        "rpm": 3000.0,
        "sample_rate_hz": 4096.0
    }