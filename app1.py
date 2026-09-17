import streamlit as st
import numpy as np
import pandas as pd
import time
from datetime import datetime
import plotly.graph_objects as go
import plotly.express as px

# --- Page Configuration ---
st.set_page_config(
    page_title="Smart Fault Detection Framework", 
    page_icon="⚡", 
    layout="wide",
    initial_sidebar_state="expanded"
)

# --- Light Industrial Custom CSS ---
st.markdown("""
    <style>
    .stApp { background-color: #F8FAFC; color: #0B1F3A; font-family: 'Inter', sans-serif; }
    .navbar { display: flex; justify-content: space-between; align-items: center; background-color: #FFFFFF; padding: 12px 30px; border-bottom: 2px solid #E2E8F0; margin-bottom: 25px; border-radius: 8px; }
    .navbar-brand { font-size: 22px; font-weight: 900; color: #0B1F3A; letter-spacing: -0.5px; }
    
    .kpi-card { background: #FFFFFF; border-left: 5px solid #2563EB; border-radius: 8px; padding: 15px 20px; box-shadow: 0 4px 12px rgba(0,0,0,0.04); margin-bottom: 15px; }
    .kpi-title { font-size: 13px; color: #64748B; font-weight: 700; text-transform: uppercase; margin-bottom: 5px; }
    .kpi-value { font-size: 28px; font-weight: 800; color: #0B1F3A; }
    
    .relay-armed { background-color: #ECFDF5; border: 1px solid #10B981; color: #047857; padding: 12px; border-radius: 6px; font-weight: 800; text-align: center; font-size: 16px;}
    .relay-tripped { background-color: #FEF2F2; border: 1px solid #EF4444; color: #B91C1C; padding: 12px; border-radius: 6px; font-weight: 800; text-align: center; font-size: 16px; animation: pulse 1.2s infinite; }
    
    .rag-window { background-color: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 8px; padding: 20px; height: 100%; box-shadow: 0 4px 12px rgba(0,0,0,0.03); }

    @keyframes pulse {
        0% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.4); }
        70% { box-shadow: 0 0 0 10px rgba(239, 68, 68, 0); }
        100% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); }
    }
    </style>
""", unsafe_allow_html=True)

# --- Session State Setup ---
if 'system_active' not in st.session_state:
    st.session_state.system_active = False
if 'manual_override' not in st.session_state:
    st.session_state.manual_override = False
if 'incident_log' not in st.session_state:
    st.session_state.incident_log = pd.DataFrame(columns=["Timestamp", "Fault Classification", "Confidence", "Action Taken"])

# --- Navigation Bar ---
st.markdown("""
    <div class="navbar">
        <div class="navbar-brand">⚡ Smart Fault Detection Framework</div>
        <div style="font-weight: 600; color: #64748B;">Edge Compute Latency: <span style="color:#10B981;">14 ms</span> | Protocol: UART/JSON</div>
    </div>
""", unsafe_allow_html=True)

# --- Sidebar Controls ---
st.sidebar.image("https://cdn-icons-png.flaticon.com/512/2043/2043004.png", width=50)
st.sidebar.header("🎛️ Edge Node Controls")
st.sidebar.markdown("---")

if not st.session_state.system_active:
    if st.sidebar.button("▶️ START HARDWARE POLLING", type="primary", use_container_width=True):
        st.session_state.system_active = True
        st.rerun()
else:
    if st.sidebar.button("⏹️ SYSTEM STANDBY", type="secondary", use_container_width=True):
        st.session_state.system_active = False
        st.session_state.manual_override = False
        st.rerun()

st.sidebar.markdown("### 🔌 Remote Actuation")
if st.sidebar.toggle("🚨 MANUAL RELAY OVERRIDE", value=st.session_state.manual_override):
    st.session_state.manual_override = True
else:
    st.session_state.manual_override = False

st.sidebar.markdown("### 🔬 1D-CNN Fault Injection")
scenario = st.sidebar.radio(
    "Select Operating State:",
    ["🟢 Healthy / Baseline", "🟠 Stage 1: Rotor Imbalance", "🔴 Stage 2: Bearing Degradation"]
)

if not st.session_state.system_active:
    st.info("👋 **Edge Server is on Standby.** Click **'▶️ START HARDWARE POLLING'** in the sidebar to initialize the ESP32 serial bridge, DSP engine, and AI agent.")
    st.stop()

# --- Simulation Logic ---
if scenario == "🟢 Healthy / Baseline":
    fault_code = 0
    rms = np.random.uniform(0.18, 0.25)
    temp = 62.0 + np.random.uniform(-1, 1)
    current = 12.4 + np.random.uniform(-0.5, 0.5)
    rul_hours = 1240
    health_idx = 98.2
    cnn_class = "NORMAL_OPERATION"
    cnn_conf = 99.4
elif scenario == "🟠 Stage 1: Rotor Imbalance":
    fault_code = 1
    rms = np.random.uniform(1.10, 1.35)
    temp = 72.5 + np.random.uniform(-1, 1)
    current = 16.1 + np.random.uniform(-0.5, 0.5)
    rul_hours = 48
    health_idx = 64.5
    cnn_class = "ROTOR_IMBALANCE (HARMONIC SPIKE)"
    cnn_conf = 92.1
else:
    fault_code = 2
    rms = np.random.uniform(2.80, 3.40)
    temp = 94.2 + np.random.uniform(-1, 1)
    current = 28.7 + np.random.uniform(-0.5, 0.5)
    rul_hours = 2
    health_idx = 14.1
    cnn_class = "CRITICAL_BEARING_FRICTION"
    cnn_conf = 98.7

# --- Incident Logging Logic ---
if fault_code > 0 or st.session_state.manual_override:
    new_entry = {
        "Timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "Fault Classification": "MANUAL OVERRIDE" if st.session_state.manual_override else cnn_class,
        "Confidence": "100%" if st.session_state.manual_override else f"{cnn_conf}%",
        "Action Taken": "RELAY KILLED" if (fault_code == 2 or st.session_state.manual_override) else "LOGGED WARNING"
    }
    # Append safely using pd.concat
    st.session_state.incident_log = pd.concat([pd.DataFrame([new_entry]), st.session_state.incident_log]).head(10)

# ==========================================
# TOP KPI ROW
# ==========================================
k1, k2, k3, k4, k5 = st.columns(5)
k1.markdown(f'<div class="kpi-card"><div class="kpi-title">Health Index</div><div class="kpi-value">{health_idx}%</div></div>', unsafe_allow_html=True)
k2.markdown(f'<div class="kpi-card"><div class="kpi-title">Predictive RUL</div><div class="kpi-value">{rul_hours} Hrs</div></div>', unsafe_allow_html=True)
k3.markdown(f'<div class="kpi-card"><div class="kpi-title">RMS Velocity</div><div class="kpi-value">{rms:.2f} V</div></div>', unsafe_allow_html=True)
k4.markdown(f'<div class="kpi-card"><div class="kpi-title">Casing Temp</div><div class="kpi-value">{temp:.1f} °C</div></div>', unsafe_allow_html=True)
k5.markdown(f'<div class="kpi-card"><div class="kpi-title">Current Draw</div><div class="kpi-value">{current:.1f} A</div></div>', unsafe_allow_html=True)

# Hardware Relay Interlock Status
if fault_code == 2 or st.session_state.manual_override:
    st.markdown('<div class="relay-tripped">⚡ GPIO 5V RELAY: EMERGENCY TRIP ACTIVATED (MOTOR HALTED)</div>', unsafe_allow_html=True)
else:
    st.markdown('<div class="relay-armed">✅ GPIO 5V RELAY: ARMED / CIRCUIT CLOSED (MOTOR RUNNING)</div>', unsafe_allow_html=True)

st.markdown("---")

# ==========================================
# MAIN DASHBOARD CONTENT
# ==========================================
col_graphs, col_ai = st.columns([1.8, 1])

# --- LEFT COLUMN: Multi-Sensor Data Fusion ---
with col_graphs:
    tab1, tab2, tab3 = st.tabs(["📈 Vibration (FFT Spectrum)", "🔊 Acoustic (Audio Freq)", "🌡️ Thermal & Load Profiling"])
    
    with tab1:
        frequencies = np.linspace(0, 6000, 300)
        if fault_code == 0:
            amplitude = np.exp(-frequencies/500) * 10 + np.random.normal(0, 0.5, 300)
        elif fault_code == 1:
            amplitude = np.exp(-frequencies/500) * 10 + np.exp(-((frequencies-1200)/300)**2) * 22 + np.random.normal(0, 0.8, 300)
        else:
            amplitude = np.exp(-frequencies/500) * 10 + np.exp(-((frequencies-4800)/250)**2) * 35 + np.random.normal(0, 0.8, 300)
            
        fig_fft = go.Figure()
        line_color = "#10B981" if fault_code == 0 else "#EF4444"
        fig_fft.add_trace(go.Scatter(x=frequencies, y=np.clip(amplitude, 0, None), mode='lines', line=dict(color=line_color, width=2), fill='tozeroy'))
        fig_fft.update_layout(height=320, margin=dict(l=0, r=0, t=10, b=0), plot_bgcolor="rgba(0,0,0,0)", xaxis_title="Frequency (Hz)", yaxis_title="Power Spectral Density (dB)")
        st.plotly_chart(fig_fft, use_container_width=True)

    with tab2:
        audio_freq = np.linspace(0, 15000, 300)
        audio_amp = np.random.normal(5, 2, 300) if fault_code < 2 else np.exp(-((audio_freq-12000)/500)**2) * 40 + np.random.normal(5, 3, 300)
        fig_audio = px.area(x=audio_freq, y=audio_amp, labels={'x':'Audio Frequency (Hz)', 'y':'dBFS'}, color_discrete_sequence=["#8B5CF6"])
        fig_audio.update_layout(height=320, margin=dict(l=0, r=0, t=10, b=0), plot_bgcolor="rgba(0,0,0,0)")
        st.plotly_chart(fig_audio, use_container_width=True)
        
    with tab3:
        time_x = ["T-4", "T-3", "T-2", "T-1", "NOW"]
        if fault_code == 0:
            temp_y = [61, 61.5, 62, 61.8, temp]
            curr_y = [12.2, 12.3, 12.4, 12.4, current]
        else:
            temp_y = [62, 68, 75, 85, temp]
            curr_y = [12.4, 18.2, 22.1, 26.5, current]
            
        fig_tl = go.Figure()
        fig_tl.add_trace(go.Scatter(x=time_x, y=temp_y, name="Temp (°C)", line=dict(color="#F59E0B", width=3)))
        fig_tl.add_trace(go.Scatter(x=time_x, y=curr_y, name="Current (A)", line=dict(color="#3B82F6", width=3)))
        fig_tl.update_layout(height=320, margin=dict(l=0, r=0, t=10, b=0), plot_bgcolor="rgba(0,0,0,0)")
        st.plotly_chart(fig_tl, use_container_width=True)

# --- RIGHT COLUMN: AI & RAG Triage Agent ---
with col_ai:
    st.markdown('<div class="rag-window">', unsafe_allow_html=True)
    st.subheader("🧠 1D-CNN Edge Inference")
    st.markdown(f"**Classification:** `{cnn_class}`")
    st.progress(cnn_conf / 100.0)
    st.markdown(f"<p style='text-align:right; font-size:12px; color:#64748B;'>Confidence: {cnn_conf}%</p>", unsafe_allow_html=True)
    
    st.markdown("---")
    
    st.subheader("🤖 Featherless.ai RAG Agent")
    
    if st.session_state.manual_override:
        st.error("**🚨 SYSTEM OVERRIDE:** Human operator has manually tripped the hardware relay. Power cut to physical motor.")
    elif fault_code == 0:
        st.success("**AI Status:** System operates within baseline parameters. No maintenance action required.")
    elif fault_code == 1:
        st.warning("""
        **⚠️ Root Cause Analysis (RCA):**
        Harmonic spike at 1.2 kHz detected. Indicates early-stage rotor imbalance.
        
        **SOP Generated (From Vector DB):**
        1. Schedule maintenance window.
        2. Inspect eccentric coupler alignment.
        3. Verify mounting bracket torque.
        """)
    elif fault_code == 2:
        st.error("""
        **🚨 CRITICAL RCA (RELAY TRIPPED):**
        High-frequency structural resonance (4.8 kHz) detected with rapid thermal drift. 
        
        **Emergency SOP (From Vector DB):**
        1. **HARDWARE KILLED.** Do not attempt manual restart.
        2. Lock-out/Tag-out (LOTO) main power line.
        3. Dispatch mechanical team.
        """)
    st.markdown('</div>', unsafe_allow_html=True)

# --- Incident Logging Table ---
with st.expander("📂 View Historical Incident Logs & Export Data"):
    if not st.session_state.incident_log.empty:
        st.dataframe(st.session_state.incident_log, use_container_width=True, hide_index=True)
        csv = st.session_state.incident_log.to_csv(index=False).encode('utf-8')
        st.download_button("📥 Download Incident CSV", data=csv, file_name="fault_log.csv", mime="text/csv")
    else:
        st.info("No incidents logged in the current session.")

# Auto-refresh loop to emulate live hardware polling
if not st.session_state.manual_override:
    time.sleep(1.5)
    st.rerun()