import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np

from src.agents import TriageSupervisor

# Global state dictionaries
ai_engine = {}
active_connections: list[WebSocket] = []

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager loads the TF CNN and multi-agent system into 
    memory once at startup, preventing latency spikes on the first API request.
    """
    print("⚡ Initializing EdgeGuard AI Supervisor...")
    ai_engine["supervisor"] = TriageSupervisor(cnn_model_path="models/motor_1dcnn.keras")
    print("✅ AI Supervisor loaded and ready.")
    yield
    print("Shutting down AI engine...")
    ai_engine.clear()

app = FastAPI(title="EdgeGuard API", lifespan=lifespan)

# Enable CORS so the upcoming Next.js frontend (e.g., localhost:3000) can communicate
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Align exactly with the inputs expected by TriageSupervisor & signal_processing
class TelemetryWindow(BaseModel):
    vibration: list[float]
    current: list[float]
    temperature: float
    rpm: float
    sample_rate_hz: float

async def broadcast_telemetry(payload: dict):
    """Pushes the raw waveform and AI diagnosis to all connected Next.js clients."""
    for connection in active_connections.copy():
        try:
            await connection.send_json(payload)
        except WebSocketDisconnect:
            active_connections.remove(connection)
        except Exception:
            pass

@app.post("/api/diagnose")
async def diagnose_window(window: TelemetryWindow, background_tasks: BackgroundTasks):
    """
    REST endpoint hit by the ESP32 bridge script. 
    It runs the multi-agent AI and automatically broadcasts the results to the UI.
    """
    # Cast incoming JSON arrays to fast NumPy arrays
    window_dict = {
        "vibration": np.array(window.vibration, dtype=np.float32),
        "current": np.array(window.current, dtype=np.float32),
        "temperature": window.temperature,
        "rpm": window.rpm,
        "sample_rate_hz": window.sample_rate_hz
    }

    # Offload the AI processing to a background thread to prevent blocking the WebSocket loop
    supervisor = ai_engine["supervisor"]
    result = await asyncio.to_thread(supervisor.run, window_dict)

    # Extract the Pydantic model to a standard dictionary for JSON serialization
    diagnosis_dict = result["diagnosis"].model_dump()

    response_payload = {
        "diagnosis": diagnosis_dict,
        "features": result["features"],
        "agent_outputs": result["agent_outputs"],
    }

    # Package the raw hardware data and the AI decision for the live UI monitor
    broadcast_payload = {
        "type": "telemetry_update",
        "raw_window": window.model_dump(),
        "triage": response_payload
    }
    
    # Trigger the WebSocket broadcast immediately after sending the POST response
    background_tasks.add_task(broadcast_telemetry, broadcast_payload)

    return response_payload

@app.websocket("/ws/telemetry")
async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint for the Next.js dashboard to subscribe to live data streams.
    """
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            # Keep connection alive; future-proofed for bidirectional UI commands (e.g., manual kill-switch)
            await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in active_connections:
            active_connections.remove(websocket)