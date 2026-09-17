# VoltHacks: Agents + CNN + RAG implementation order

## PHASE A — Agents

1. SensorAgent
2. VibrationAgent
3. ElectricalAgent
4. ThermalAgent
5. TriageSupervisor
6. Verify each agent with simulator data.

Command:
python -m pytest -q

## PHASE B — CNN

1. Install `requirements-cnn.txt` on training PC.
2. Generate software-test dataset:
   python -m src.make_dataset
3. Train:
   python -m src.train_cnn
4. Model:
   models/motor_1dcnn.keras
5. Test CNN predictions.
6. Only then connect CNNAgent to TriageSupervisor.

## PHASE C — REAL DATA

1. Connect ESP32 + ADXL345.
2. Record raw vibration windows.
3. Add labels: healthy / imbalance / bearing_fault / electrical_fault.
4. Repeat across speed/load conditions.
5. Retrain CNN.
6. Compare CNN accuracy and confusion matrix.
7. Do NOT claim industrial accuracy from the prototype.

## PHASE D — RAG

1. Collect trusted documents.
2. Put them in data/knowledge/.
3. Create Gemini File Search store.
4. Test retrieval with 5-10 known questions.
5. Add diagnostic context to the RAG query.
6. Display explanation + sources later.

## PHASE E — INTEGRATION

Only after A-D work independently:

ESP32 → bridge.py → telemetry parser → agents/CNN → RAG → app1.py

This preserves the teammate's dashboard instead of rewriting it.

## MEMORY RULE

Remember the pipeline as:

SENSE → PROCESS → SPECIALISTS → CNN → TRIAGE → RAG → SHOW

SENSE = ESP32
PROCESS = RMS/FFT
SPECIALISTS = vibration/current/thermal agents
CNN = vibration classifier
TRIAGE = final fusion
RAG = explanation/maintenance knowledge
SHOW = existing Streamlit dashboard
