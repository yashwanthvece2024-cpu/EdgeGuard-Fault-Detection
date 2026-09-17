# VoltHacks Multi-Agent Motor Triage MVP

## Run

```bash
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/Raspberry Pi:
source .venv/bin/activate

pip install -r requirements.txt
streamlit run app.py
```

The MVP starts in simulator mode, so it can be demonstrated without hardware.

## Hardware path

ESP32 -> USB Serial -> Raspberry Pi -> telemetry parser -> signal processing -> agents -> diagnosis -> dashboard.

The existing teammate bridge used COM8/115200 and expected `rms`, `status`, and `confidence`. This project changes the contract to sensor-level values:
`rms_accel_g`, `current_a`, `temperature_c`, `rpm`.

Do not mix the old `status/confidence` contract with the new architecture.

## RAG

1. Put maintenance manuals, sensor datasheets, fault-signature references and SOPs under `data/knowledge/`.
2. Set `GEMINI_API_KEY`.
3. Run:

```bash
python -c "from src.rag import upload_knowledge_directory; print(upload_knowledge_directory())"
```

4. Put the returned store name in `GEMINI_FILE_SEARCH_STORE`.

Google's Gemini File Search can chunk/index files and retrieve relevant context. It also supports multimodal File Search with `gemini-embedding-2`, which is useful later for maintenance images.

## Important MVP boundary

The current digital twin is a procedural visualization, not a 3D scan. ADXL345/ACS712/DS18B20 measure condition signals; they do not capture motor geometry. For an actual scanned 3D twin, add a camera/depth/LiDAR/photogrammetry pipeline and map the diagnosed component to the resulting mesh.
