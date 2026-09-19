import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Set random seed for reproducibility
np.random.seed(42)

# Generate 1000 timestamps
start_time = datetime.now() - timedelta(days=1)
timestamps = [start_time + timedelta(minutes=i) for i in range(1000)]

# Generate Normal Data (80% of dataset)
normal_temp = np.random.normal(45.0, 2.0, 800)
normal_vib = np.random.normal(2.5, 0.5, 800)
normal_curr = np.random.normal(12.0, 0.5, 800)

# Generate Faulty Data (Overheating & Bearing Faults - 20% of dataset)
faulty_temp = np.random.normal(85.0, 5.0, 200)
faulty_vib = np.random.normal(8.0, 1.5, 200)
faulty_curr = np.random.normal(18.0, 2.0, 200)

# Combine and shuffle
temperatures = np.concatenate([normal_temp, faulty_temp])
vibrations = np.concatenate([normal_vib, faulty_vib])
currents = np.concatenate([normal_curr, faulty_curr])
labels = np.concatenate([np.zeros(800), np.ones(200)]) # 0 = Normal, 1 = Fault

# Create DataFrame
df = pd.DataFrame({
    'timestamp': timestamps,
    'temperature_celsius': temperatures,
    'vibration_mm_s': vibrations,
    'current_amps': currents,
    'fault_detected': labels
})

# Shuffle the dataset
df = df.sample(frac=1).reset_index(drop=True)

# Save to CSV
df.to_csv('motor_telemetry_dataset.csv', index=False)
print("motor_telemetry_dataset.csv generated successfully!")