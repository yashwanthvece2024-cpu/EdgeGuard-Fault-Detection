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
