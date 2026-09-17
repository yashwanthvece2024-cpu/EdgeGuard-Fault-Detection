import asyncio
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, BackgroundTasks
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np

from src.agents import TriageSupervisor
from src.simulator import make_window
from src.rag import query_rag

ai_engine = {}
active_connections: list[WebSocket] = []

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("⚡ Initializing EdgeGuard AI Supervisor...")
    ai_engine["supervisor"] = TriageSupervisor(cnn_model_path="models/motor_1dcnn.keras")
    print("✅ AI Supervisor loaded and ready.")
    yield
    ai_engine.clear()

app = FastAPI(title="EdgeGuard API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TelemetryWindow(BaseModel):
    vibration: list[float]
    current: list[float]
    temperature: float
    rpm: float
    sample_rate_hz: float

@app.get("/", response_class=HTMLResponse)
async def serve_dashboard():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    for folder in ["template", "templates"]:
        html_path = os.path.abspath(os.path.join(base_dir, "..", folder, "index.html"))
        if os.path.exists(html_path):
            with open(html_path, "r", encoding="utf-8") as f:
                return f.read()
    return "<h1>Dashboard template not found.</h1>"

async def broadcast_telemetry(payload: dict):
    for connection in active_connections.copy():
        try:
            await connection.send_json(payload)
        except WebSocketDisconnect:
            active_connections.remove(connection)
        except Exception:
            pass

@app.post("/api/simulate/{fault_type}")
async def simulate_fault(fault_type: str, background_tasks: BackgroundTasks):
    """
    Triggers physical signal generation for a selected fault, runs all specialist 
    agents, executes Gemini RAG analysis, and returns the full evidentiary payload.
    """
    # 1. Generate realistic multi-sensor telemetry window
    window_dict = make_window(fault=fault_type)
    
    # 2. Run Multi-Agent Triage Supervisor & CNN Arbiter
    supervisor = ai_engine["supervisor"]
    result = await asyncio.to_thread(supervisor.run, window_dict)
    
    diagnosis = result["diagnosis"]
    features = result["features"]
    agent_outputs = result["agent_outputs"]

    # 3. Query Gemini RAG Layer for grounded RCA & SOPs
    rag_result = await asyncio.to_thread(query_rag, diagnosis.model_dump(), features)

    # Convert NumPy arrays to lists for JSON serialization
    response_payload = {
        "diagnosis": diagnosis.model_dump(),
        "features": features,
        "agent_outputs": agent_outputs,
        "rag": rag_result,
        "raw_window": {
            "vibration": window_dict["vibration"][:100].tolist(), # Send preview slice for charts
            "current": window_dict["current"][:100].tolist(),
        }
    }

    broadcast_payload = {
        "type": "telemetry_update",
        "triage": response_payload
    }
    
    background_tasks.add_task(broadcast_telemetry, broadcast_payload)
    return response_payload

@app.post("/api/diagnose")
async def diagnose_window(window: TelemetryWindow, background_tasks: BackgroundTasks):
    window_dict = {
        "vibration": np.array(window.vibration, dtype=np.float32),
        "current": np.array(window.current, dtype=np.float32),
        "temperature": window.temperature,
        "rpm": window.rpm,
        "sample_rate_hz": window.sample_rate_hz
    }
    supervisor = ai_engine["supervisor"]
    result = await asyncio.to_thread(supervisor.run, window_dict)
    diagnosis = result["diagnosis"]
    features = result["features"]
    
    rag_result = await asyncio.to_thread(query_rag, diagnosis.model_dump(), features)

    response_payload = {
        "diagnosis": diagnosis.model_dump(),
        "features": features,
        "agent_outputs": result["agent_outputs"],
        "rag": rag_result,
    }
    return response_payload

@app.websocket("/ws/telemetry")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in active_connections:
            active_connections.remove(websocket)