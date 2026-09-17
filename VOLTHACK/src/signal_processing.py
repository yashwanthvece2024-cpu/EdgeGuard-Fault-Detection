import numpy as np

def feature_vector(vibration, current, temperature, rpm, sample_rate_hz):
    # Convert to numpy arrays for fast math
    vib = np.asarray(vibration, dtype=np.float32)
    curr = np.asarray(current, dtype=np.float32)

    # Calculate RMS and Crest Factor for vibration
    rms_accel_g = float(np.sqrt(np.mean(vib**2)))
    peak = float(np.max(np.abs(vib)))
    crest_factor = peak / rms_accel_g if rms_accel_g > 0 else 0.0

    # Calculate FFT to find the dominant frequency (Hz)
    freqs = np.fft.rfftfreq(len(vib), d=1.0/sample_rate_hz)
    fft_mags = np.abs(np.fft.rfft(vib - np.mean(vib)))
    dominant_hz = float(freqs[np.argmax(fft_mags)]) if len(fft_mags) > 0 else 0.0

    # Calculate electrical features
    current_mean_a = float(np.mean(curr))
    current_std_a = float(np.std(curr))

    return {
        "rms_accel_g": rms_accel_g,
        "dominant_hz": dominant_hz,
        "crest_factor": crest_factor,
        "current_mean_a": current_mean_a,
        "current_std_a": current_std_a,
        "temperature_c": float(temperature),
        "rpm": float(rpm)
    }