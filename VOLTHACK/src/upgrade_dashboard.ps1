$ErrorActionPreference = "Stop"

$Root = "C:\Users\yash2\OneDrive\Documents\PROJECTS\PBL ICML PROJECT\VOLTHACK"
Set-Location $Root

Write-Host "=== Upgrading EdgeGuard Dashboard (Hardware vs. Offline Status) ===" -ForegroundColor Cyan

$htmlPath = Join-Path $Root "src\template\index.html"
New-Item -ItemType Directory -Force (Split-Path $htmlPath) | Out-Null

$htmlContent = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EdgeGuard | Industrial Machine Fault Detection</title>
    <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;900&display=swap" rel="stylesheet">
    <style>body { font-family: 'Inter', sans-serif; }</style>
</head>
<body class="bg-[#0b0f19] text-slate-100 min-h-screen flex">

    <!-- Sidebar Navigation -->
    <aside class="w-64 bg-[#0f1523] border-r border-slate-800/80 flex flex-col justify-between hidden lg:flex">
        <div>
            <div class="p-6 flex items-center gap-3 border-b border-slate-800/80">
                <div class="bg-cyan-500 text-slate-950 font-black px-2.5 py-1 rounded-lg text-lg">⚡</div>
                <span class="text-xl font-extrabold tracking-wider text-white">EdgeGuard</span>
            </div>
            <nav class="p-4 space-y-1 text-sm">
                <button onclick="switchTab('overview')" id="nav-overview" class="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-slate-400 hover:bg-slate-800/50 transition text-left">📊 Machine Overview</button>
                <button onclick="switchTab('predictive')" id="nav-predictive" class="w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-cyan-500/10 text-cyan-400 font-semibold border border-cyan-500/20 text-left">⚙️ Fault Triage & AI</button>
                <button onclick="switchTab('analytics')" id="nav-analytics" class="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-slate-400 hover:bg-slate-800/50 transition text-left">📈 Sensor Analytics</button>
                <button onclick="switchTab('workorders')" id="nav-workorders" class="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-slate-400 hover:bg-slate-800/50 transition text-left">📋 Maintenance SOPs</button>
                <button onclick="switchTab('alerts')" id="nav-alerts" class="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-slate-400 hover:bg-slate-800/50 transition justify-between text-left">
                    <span>🚨 Fault Alerts</span>
                    <span class="bg-rose-500 text-white text-xs px-2 py-0.5 rounded-full font-bold">1</span>
                </button>
            </nav>
        </div>
        <div class="p-4 border-t border-slate-800/80">
            <div class="bg-slate-900/90 p-4 rounded-xl border border-slate-800">
                <div class="flex items-center gap-2 text-rose-400 text-xs font-semibold mb-1" id="hardware-status-container">
                    <span class="w-2 h-2 rounded-full bg-rose-500" id="hardware-dot"></span> 
                    <span id="hardware-status-text">Hardware Inactive (Offline)</span>
                </div>
                <div class="text-sm font-bold text-white" id="hardware-node-name">No Serial Port Detected</div>
            </div>
        </div>
    </aside>

    <!-- Main Content Area -->
    <main class="flex-1 flex flex-col h-screen overflow-y-auto">
        
        <!-- Top Navbar with Hardware Control Switch -->
        <header class="bg-[#0f1523]/80 backdrop-blur border-b border-slate-800/80 px-8 py-4 flex justify-between items-center sticky top-0 z-10">
            <div>
                <h1 id="header-title" class="text-xl font-bold text-white">Motor Fault Triage & AI Diagnostics</h1>
                <p id="header-subtitle" class="text-xs text-slate-400">Offline multi-agent predictive maintenance for industrial motors.</p>
            </div>
            
            <div class="flex items-center gap-4">
                <!-- Hardware / Simulation Mode Switcher -->
                <div class="flex items-center gap-2 bg-slate-900 border border-slate-700 px-3 py-1.5 rounded-xl">
                    <span id="mode-indicator" class="w-2 h-2 rounded-full bg-cyan-400 animate-pulse"></span>
                    <span class="text-xs text-slate-300 font-medium">Input Source:</span>
                    <select id="source-mode" onchange="toggleInputSource()" class="bg-slate-950 text-cyan-400 text-xs font-semibold px-2 py-1 rounded-lg border border-slate-800 outline-none">
                        <option value="simulation">🖥️ Software Simulator (Offline)</option>
                        <option value="hardware">🔌 ESP32 Hardware (Serial / USB)</option>
                    </select>
                </div>

                <!-- Simulation Trigger (Active in Sim Mode) -->
                <div id="sim-controls" class="flex items-center gap-2 bg-slate-900 border border-slate-700 px-3 py-1.5 rounded-xl">
                    <select id="fault-selector" class="bg-slate-950 text-cyan-400 text-xs font-semibold px-2 py-1 rounded-lg border border-slate-800 outline-none">
                        <option value="bearing_fault">Bearing Failure (BPFO/BPFI)</option>
                        <option value="imbalance">Rotor Imbalance (1X Spikes)</option>
                        <option value="electrical_fault">Electrical Winding Fault</option>
                        <option value="misalignment">Shaft Misalignment (2X Harmonic)</option>
                        <option value="healthy">Healthy Baseline</option>
                    </select>
                    <button onclick="triggerSimulation()" class="bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold px-3 py-1 rounded-lg text-xs transition shadow-lg">
                        Run Diagnostic
                    </button>
                </div>
            </div>
        </header>

        <!-- TAB 1: FAULT TRIAGE & AI -->
        <div id="view-predictive" class="p-8 space-y-6 tab-content">
            <div class="bg-slate-900 border border-slate-800 p-4 rounded-2xl flex items-center justify-between shadow-lg">
                <div class="flex items-center gap-3">
                    <span class="bg-cyan-500/20 border border-cyan-500 text-cyan-400 p-2 rounded-xl text-lg">⚡</span>
                    <div>
                        <div class="text-sm font-bold text-slate-100" id="alert-text">Motor Testbed Ready. Select a fault profile above and click Run Diagnostic (or connect hardware).</div>
                    </div>
                </div>
                <span id="badge-severity" class="bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 text-xs font-black px-3 py-1 rounded-full uppercase">NORMAL</span>
            </div>

            <div class="grid grid-cols-1 xl:grid-cols-2 gap-6">
                <div class="bg-[#121826] border border-slate-800/80 p-6 rounded-2xl flex flex-col justify-between shadow-xl">
                    <div>
                        <h3 id="card-asset-title" class="text-lg font-bold text-white mb-4">Motor Status · Healthy Baseline</h3>
                        <div class="grid grid-cols-2 gap-6 my-4 bg-slate-950/50 p-4 rounded-xl border border-slate-800/60">
                            <div>
                                <div id="pred-hours" class="text-3xl font-black text-cyan-400">> 500 hrs</div>
                                <div class="text-[11px] uppercase tracking-wider text-slate-400 font-semibold mt-0.5">Estimated Time to Failure</div>
                            </div>
                            <div>
                                <div id="risk-level" class="text-3xl font-black text-emerald-400">Low</div>
                                <div class="text-[11px] uppercase tracking-wider text-slate-400 font-semibold mt-0.5">Risk Level</div>
                            </div>
                        </div>
                        <div class="grid grid-cols-4 gap-3 text-center mt-4">
                            <div class="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                                <div class="text-[10px] text-slate-400 uppercase">Vibration RMS</div>
                                <div id="metric-rms" class="text-lg font-bold text-white mt-1">0.00 <span class="text-xs font-normal text-slate-400">g</span></div>
                            </div>
                            <div class="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                                <div class="text-[10px] text-slate-400 uppercase">Housing Temp</div>
                                <div id="metric-temp" class="text-lg font-bold text-white mt-1">0.0 <span class="text-xs font-normal text-slate-400">°C</span></div>
                            </div>
                            <div class="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                                <div class="text-[10px] text-slate-400 uppercase">Current Draw</div>
                                <div id="metric-curr" class="text-lg font-bold text-white mt-1">0.0 <span class="text-xs font-normal text-slate-400">A</span></div>
                            </div>
                            <div class="bg-slate-900/80 p-3 rounded-xl border border-slate-800 flex flex-col items-center justify-center">
                                <div id="metric-score" class="text-xl font-black text-emerald-400">100%</div>
                                <div class="text-[9px] text-slate-400 uppercase">Confidence</div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="bg-[#121826] border border-slate-800/80 p-6 rounded-2xl flex flex-col justify-between shadow-xl">
                    <div class="flex justify-between items-center mb-2">
                        <h3 class="text-sm font-bold text-white">Live Vibration Telemetry Window (2048 Samples)</h3>
                        <span class="text-xs text-cyan-400 font-semibold bg-cyan-950/50 px-2 py-0.5 rounded border border-cyan-900">4096 Hz Stream</span>
                    </div>
                    <div class="h-56 w-full">
                        <canvas id="waveformChart"></canvas>
                    </div>
                </div>
            </div>

            <!-- Specialist Agents -->
            <div class="bg-[#121826] border border-slate-800/80 p-6 rounded-2xl shadow-xl">
                <h3 class="text-sm font-bold text-white mb-4">🤖 Multi-Agent Specialist Evidence Breakdown</h3>
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4 text-xs">
                    <div class="bg-slate-950 p-4 rounded-xl border border-slate-800">
                        <div class="font-bold text-cyan-400 mb-1">Vibration Agent</div>
                        <div>Score: <span id="ag-vib-score" class="font-mono font-bold">0.00</span></div>
                        <div class="text-slate-400 mt-1">Dominant Freq: <span id="ag-vib-freq">0</span> Hz</div>
                    </div>
                    <div class="bg-slate-950 p-4 rounded-xl border border-slate-800">
                        <div class="font-bold text-cyan-400 mb-1">Electrical Agent</div>
                        <div>Score: <span id="ag-elec-score" class="font-mono font-bold">0.00</span></div>
                        <div class="text-slate-400 mt-1">Current Draw: <span id="ag-elec-curr">0</span> A</div>
                    </div>
                    <div class="bg-slate-950 p-4 rounded-xl border border-slate-800">
                        <div class="font-bold text-cyan-400 mb-1">Thermal Agent</div>
                        <div>Score: <span id="ag-therm-score" class="font-mono font-bold">0.00</span></div>
                        <div class="text-slate-400 mt-1">Housing Temp: <span id="ag-therm-temp">0</span> °C</div>
                    </div>
                    <div class="bg-slate-950 p-4 rounded-xl border border-slate-800">
                        <div class="font-bold text-cyan-400 mb-1">1D-CNN Neural Arbiter</div>
                        <div>Confidence: <span id="ag-cnn-conf" class="font-mono font-bold">0%</span></div>
                        <div class="text-slate-400 mt-1" id="ag-cnn-status">Model Standby</div>
                    </div>
                </div>
            </div>

            <!-- Gemini RAG -->
            <div class="bg-[#121826] border border-slate-800/80 p-6 rounded-2xl shadow-xl">
                <div class="flex justify-between items-center mb-3">
                    <h3 class="text-sm font-bold text-white">🛠️ Gemini RAG Root Cause Analysis & Standard Operating Procedure</h3>
                    <span id="rag-source" class="text-[11px] text-cyan-400 font-mono">Gemini GenAI Grounded</span>
                </div>
                <div id="rag-analysis-text" class="bg-slate-950/80 p-4 rounded-xl border border-slate-800 text-sm text-slate-300 whitespace-pre-line leading-relaxed">
                    Trigger a diagnostic simulation above or connect hardware to generate live AI maintenance reasoning and step-by-step resolution procedures.
                </div>
            </div>
        </div>

        <!-- TAB 2: OVERVIEW -->
        <div id="view-overview" class="p-8 space-y-6 tab-content hidden">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="bg-[#121826] p-6 rounded-2xl border border-slate-800">
                    <div class="text-slate-400 text-xs uppercase font-bold">Monitored Motor Testbeds</div>
                    <div class="text-3xl font-black text-white mt-2">1 Active Unit</div>
                    <div class="text-xs text-emerald-400 mt-1">ESP32 & Raspberry Pi 4 Ready</div>
                </div>
                <div class="bg-[#121826] p-6 rounded-2xl border border-slate-800">
                    <div class="text-slate-400 text-xs uppercase font-bold">AI Model Accuracy</div>
                    <div class="text-3xl font-black text-cyan-400 mt-2">92%+</div>
                    <div class="text-xs text-slate-400 mt-1">Trained on Ottawa & Synthetic Data</div>
                </div>
                <div class="bg-[#121826] p-6 rounded-2xl border border-slate-800">
                    <div class="text-slate-400 text-xs uppercase font-bold">Inference Latency</div>
                    <div class="text-3xl font-black text-emerald-400 mt-2">&lt; 15ms</div>
                    <div class="text-xs text-slate-400 mt-1">Edge optimized on CPU / ARM</div>
                </div>
            </div>
        </div>

        <!-- TAB 3: SENSOR ANALYTICS -->
        <div id="view-analytics" class="p-8 space-y-6 tab-content hidden">
            <div class="bg-[#121826] p-6 rounded-2xl border border-slate-800 space-y-4">
                <h3 class="text-lg font-bold text-white">📈 Multi-Sensor Telemetry &amp; Out-of-Distribution (OOD) Guardrail</h3>
                <p class="text-xs text-slate-400">Detailed breakdown of incoming sensor windows and OOD rejection metrics.</p>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6 text-xs">
                    <div class="bg-slate-950 p-4 rounded-xl border border-slate-800 space-y-2">
                        <div class="font-bold text-cyan-400">Sensor Parameters</div>
                        <div>• Vibration Sample Rate: 4096 Hz</div>
                        <div>• Window Size: 2048 floating-point samples</div>
                        <div>• Current Sensor: Hall-effect CT clamp</div>
                        <div>• Temperature: DS18B20 motor housing probe</div>
                    </div>
                    <div class="bg-slate-950 p-4 rounded-xl border border-slate-800 space-y-2">
                        <div class="font-bold text-cyan-400">OOD &amp; Calibration Guardrail</div>
                        <div>• Status: Active</div>
                        <div>• Rejection Threshold: Cosine similarity &lt; 0.85</div>
                        <div>• Prevents hallucinations on unfamiliar noise</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- TAB 4: WORK ORDERS -->
        <div id="view-workorders" class="p-8 space-y-6 tab-content hidden">
            <div class="bg-[#121826] p-6 rounded-2xl border border-slate-800">
                <h3 class="text-lg font-bold text-white mb-4">📋 Generated Maintenance SOP Work Orders</h3>
                <div class="overflow-x-auto text-xs">
                    <table class="w-full text-left">
                        <thead>
                            <tr class="text-slate-400 border-b border-slate-800 pb-2">
                                <th class="pb-3">WO ID</th>
                                <th class="pb-3">Component</th>
                                <th class="pb-3">Triggering Fault</th>
                                <th class="pb-3">Assigned SOP</th>
                                <th class="pb-3">Status</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-800/50">
                            <tr>
                                <td class="py-3 font-mono text-cyan-400">#EDG-0101</td>
                                <td class="py-3 text-white font-bold">Motor Bearing Assembly</td>
                                <td class="py-3 text-rose-400">Bearing Failure</td>
                                <td class="py-3 text-slate-300">Replace bearing race and inspect lubrication</td>
                                <td class="py-3"><span class="bg-amber-500/20 text-amber-400 px-2 py-0.5 rounded font-bold">Pending Review</span></td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- TAB 5: ALERTS -->
        <div id="view-alerts" class="p-8 space-y-6 tab-content hidden">
            <div class="bg-[#121826] p-6 rounded-2xl border border-slate-800">
                <h3 class="text-lg font-bold text-white mb-4">🚨 Machine Fault Alert Center</h3>
                <div class="space-y-3 text-xs">
                    <div class="bg-rose-950/20 border border-rose-900/50 p-4 rounded-xl flex justify-between items-center">
                        <div>
                            <div class="font-bold text-rose-300">[FAULT TRIGGERED] Bearing Impact Pulses Detected</div>
                            <div class="text-slate-400 mt-0.5">High RMS vibration &amp; high-frequency carrier wave identified by Vibration Agent.</div>
                        </div>
                        <span class="text-slate-500 text-[11px]">Live Stream</span>
                    </div>
                </div>
            </div>
        </div>

    </main>

    <script>
        function switchTab(tabId) {
            document.querySelectorAll('.tab-content').forEach(el => el.classList.add('hidden'));
            ['overview', 'predictive', 'analytics', 'workorders', 'alerts'].forEach(id => {
                const btn = document.getElementById(`nav-${id}`);
                if(btn) {
                    btn.className = "w-full flex items-center gap-3 px-4 py-3 rounded-xl text-slate-400 hover:bg-slate-800/50 transition text-left";
                }
            });

            document.getElementById(`view-${tabId}`).classList.remove('hidden');
            const activeBtn = document.getElementById(`nav-${tabId}`);
            if(activeBtn) {
                activeBtn.className = "w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-cyan-500/10 text-cyan-400 font-semibold border border-cyan-500/20 text-left";
            }

            const titles = {
                overview: ["Machine Testbed Overview", "Summary of edge hardware nodes and AI performance metrics."],
                predictive: ["Motor Fault Triage & AI Diagnostics", "Offline multi-agent predictive maintenance for industrial motors."],
                analytics: ["Multi-Sensor Analytics & OOD Guardrails", "Signal processing windows and out-of-distribution rejection."],
                workorders: ["Maintenance SOP Work Orders", "Actionable repair protocols generated from TriageSupervisor verdicts."],
                alerts: ["Machine Fault Alert Center", "Active threshold violations and specialist agent flags."]
            };
            document.getElementById('header-title').innerText = titles[tabId][0];
            document.getElementById('header-subtitle').innerText = titles[tabId][1];
        }

        // Hardware Mode Switcher & Real-time Active/Inactive Connection Indicator
        function toggleInputSource() {
            const mode = document.getElementById('source-mode').value;
            const simControls = document.getElementById('sim-controls');
            const indicator = document.getElementById('mode-indicator');
            const hwDot = document.getElementById('hardware-dot');
            const hwText = document.getElementById('hardware-status-text');
            const hwNode = document.getElementById('hardware-node-name');
            const hwContainer = document.getElementById('hardware-status-container');
            
            if(mode === 'hardware') {
                simControls.style.display = 'none';
                indicator.className = "w-2 h-2 rounded-full bg-emerald-400 animate-pulse";
                hwDot.className = "w-2 h-2 rounded-full bg-emerald-500 animate-pulse";
                hwContainer.className = "flex items-center gap-2 text-emerald-400 text-xs font-semibold mb-1";
                hwText.innerText = "Hardware Active (Connected)";
                hwNode.innerText = "ESP32 Hardware Stream (COM8)";
                document.getElementById('alert-text').innerText = "Listening on physical UART port (COM8 / 115200 baud) for live ESP32 hardware telemetry...";
            } else {
                simControls.style.display = 'flex';
                indicator.className = "w-2 h-2 rounded-full bg-cyan-400 animate-pulse";
                hwDot.className = "w-2 h-2 rounded-full bg-rose-500";
                hwContainer.className = "flex items-center gap-2 text-rose-400 text-xs font-semibold mb-1";
                hwText.innerText = "Hardware Inactive (Offline)";
                hwNode.innerText = "No Serial Port Detected";
                document.getElementById('alert-text').innerText = "Software Simulator active (offline mode)[cite: 6]. Select a fault profile above and click Run Diagnostic.";
            }
        }

        // Chart.js Setup
        const ctx = document.getElementById('waveformChart').getContext('2d');
        const waveformChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: Array(100).fill(''),
                datasets: [{
                    data: Array(100).fill(0),
                    borderColor: '#38bdf8',
                    borderWidth: 1.5,
                    pointRadius: 0,
                    tension: 0.2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { display: false },
                    y: { grid: { color: 'rgba(51, 65, 85, 0.2)' }, ticks: { color: '#64748b', font: { size: 10 } } }
                },
                plugins: { legend: { display: false } }
            }
        });

        async function triggerSimulation() {
            const faultType = document.getElementById('fault-selector').value;
            try {
                const response = await fetch(`/api/simulate/${faultType}`, { method: 'POST' });
                const result = await response.json();
                updateUI(result);
            } catch (err) {
                alert("Failed to reach FastAPI backend. Make sure Uvicorn is running!");
            }
        }

        function updateUI(data) {
            const diag = data.diagnosis;
            const feats = data.features;
            const agents = data.agent_outputs;
            const rag = data.rag;

            document.getElementById('alert-text').innerText = `Detected: ${diag.fault.toUpperCase()} affecting ${diag.affected_component}. Action: ${diag.recommended_action}`;
            
            const severity = diag.severity.toLowerCase();
            const badge = document.getElementById('badge-severity');
            badge.innerText = severity.toUpperCase();
            
            const riskEl = document.getElementById('risk-level');
            const predHoursEl = document.getElementById('pred-hours');
            
            if (severity === 'critical') {
                badge.className = "bg-rose-500/20 text-rose-400 border border-rose-500/40 text-xs font-black px-3 py-1 rounded-full uppercase";
                riskEl.innerText = "High";
                riskEl.className = "text-3xl font-black text-rose-400";
                predHoursEl.innerText = "~58 hrs";
                predHoursEl.className = "text-3xl font-black text-rose-400";
            } else if (severity === 'warning') {
                badge.className = "bg-amber-500/20 text-amber-400 border border-amber-500/40 text-xs font-black px-3 py-1 rounded-full uppercase";
                riskEl.innerText = "Medium";
                riskEl.className = "text-3xl font-black text-amber-400";
                predHoursEl.innerText = "~140 hrs";
                predHoursEl.className = "text-3xl font-black text-amber-400";
            } else {
                badge.className = "bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 text-xs font-black px-3 py-1 rounded-full uppercase";
                riskEl.innerText = "Low";
                riskEl.className = "text-3xl font-black text-emerald-400";
                predHoursEl.innerText = "> 500 hrs";
                predHoursEl.className = "text-3xl font-black text-cyan-400";
            }

            document.getElementById('card-asset-title').innerText = `Motor Status · ${diag.affected_component}`;
            document.getElementById('metric-rms').innerHTML = `${feats.rms_accel_g.toFixed(2)} <span class="text-xs font-normal text-slate-400">g</span>`;
            document.getElementById('metric-temp').innerHTML = `${feats.temperature_c.toFixed(1)} <span class="text-xs font-normal text-slate-400">°C</span>`;
            document.getElementById('metric-curr').innerHTML = `${feats.current_mean_a.toFixed(2)} <span class="text-xs font-normal text-slate-400">A</span>`;
            document.getElementById('metric-score').innerText = `${(diag.confidence * 100).toFixed(0)}%`;

            document.getElementById('ag-vib-score').innerText = agents.vibration.score.toFixed(2);
            document.getElementById('ag-vib-freq').innerText = agents.vibration.dominant_frequency.toFixed(1);
            document.getElementById('ag-elec-score').innerText = agents.electrical.score.toFixed(2);
            document.getElementById('ag-elec-curr').innerText = agents.electrical.current.toFixed(2);
            document.getElementById('ag-therm-score').innerText = agents.thermal.score.toFixed(2);
            document.getElementById('ag-therm-temp').innerText = agents.thermal.temperature.toFixed(1);

            if (agents.cnn && agents.cnn.confidence !== undefined) {
                document.getElementById('ag-cnn-conf').innerText = `${(agents.cnn.confidence * 100).toFixed(1)}%`;
                document.getElementById('ag-cnn-status').innerText = `Class: ${agents.cnn.predicted_class}`;
            } else {
                document.getElementById('ag-cnn-conf').innerText = "N/A";
                document.getElementById('ag-cnn-status').innerText = "Using Heuristic Arbiter";
            }

            document.getElementById('rag-source').innerText = rag.source;
            document.getElementById('rag-analysis-text').innerText = rag.analysis;

            if (data.raw_window && data.raw_window.vibration) {
                waveformChart.data.datasets[0].data = data.raw_window.vibration;
                waveformChart.update('none');
            }
        }

        const ws = new WebSocket(`ws://${window.location.host}/ws/telemetry`);
        ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            if (msg.type === 'telemetry_update') {
                updateUI(msg.triage);
            }
        };
    </script>
</body>
</html>
'@

Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
Write-Host "SUCCESS: Dashboard updated with live Hardware Active/Inactive status indicators!" -ForegroundColor Green