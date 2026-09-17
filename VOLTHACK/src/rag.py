import os
from dotenv import load_dotenv
from google import genai

load_dotenv()

def query_rag(diagnosis, features):
    """
    Queries the Gemini model to retrieve grounded root cause analysis (RCA) and SOPs.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key or api_key == "your_key_here":
        return {
            "analysis": "RAG analysis unavailable: GEMINI_API_KEY missing or unconfigured in .env.",
            "source": "Local Fallback SOP Engine"
        }

    client = genai.Client(api_key=api_key)
    fault = diagnosis.get("fault", "unknown")
    component = diagnosis.get("affected_component", "unknown motor assembly")
    severity = diagnosis.get("severity", "normal")
    rms = features.get("rms_accel_g", 0.0)
    current = features.get("current_mean_a", 0.0)
    temp = features.get("temperature_c", 0.0)
    dominant_hz = features.get("dominant_hz", 0.0)

    question = (
        f"Industrial motor triage detected a '{fault}' condition affecting the {component} "
        f"with severity '{severity}'. Telemetry metrics: RMS vibration={rms:.2f}g, "
        f"dominant harmonic frequency={dominant_hz:.1f}Hz, current draw={current:.2f}A, "
        f"housing temperature={temp:.1f}C. "
        f"What are the primary root causes and step-by-step standard operating procedures (SOPs) "
        f"to safely resolve this fault according to maintenance documentation?"
    )

    try:
        model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
        response = client.models.generate_content(
            model=model_name,
            contents=question
        )
        return {
            "analysis": response.text,
            "source": f"Live Gemini GenAI ({model_name})"
        }
    except Exception as e:
        return {
            "analysis": f"RAG retrieval exception: {str(e)}",
            "source": "Error Fallback Handler"
        }