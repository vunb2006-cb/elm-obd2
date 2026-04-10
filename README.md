# ELM OBD2 AI Diagnostics

An Android app that connects to an ELM327 Bluetooth OBD2 adapter and runs AI-driven diagnostic sessions using **Gemini 2.0 Flash**. The app behaves like an expert mechanic — it reads fault codes, forms competing hypotheses, prescribes specific sensor tests, collects real data from the vehicle, and produces an evidence-based diagnosis with recommended actions.

---

## How it works

```
Connect ELM327  →  Fill intake form  →  AI reads DTCs + forms hypotheses
       ↓
AI prescribes a test  →  User meets condition (e.g. engine warm, idle)
       ↓
App polls OBD2 sensors for test duration  →  Summarises data
       ↓
AI analyses summary  →  [repeat up to 5 tests]
       ↓
AI concludes diagnosis with confidence, evidence, severity, and next steps
```

The AI never diagnoses from fault codes alone. Every conclusion is backed by live sensor evidence collected during structured tests.

---

## Features

- **Bluetooth Classic (SPP)** connection to ELM327 adapters
- **18 diagnostic tests** covering fuel delivery, air metering, O2 sensors, catalyst efficiency, EGR, misfires, cold-start behaviour, and more
- **Gemini 2.0 Flash function calling** — AI only responds via structured function calls (`prescribe_test`, `request_vehicle_info`, `conclude_diagnosis`, `request_live_narration`)
- **Automatic PID support detection** — skips unsupported sensors gracefully, tells the AI which sensors were unavailable
- **Session checkpointing** — if the app is killed mid-session, an interrupted session is detected on next launch and can be resumed (Gemini context is reconstructed from saved test summaries)
- **Gemini Live voice narration** during active test collection
- **PDF report export** with full evidence summary
- **Dark automotive UI** with live sensor dashboards and sparklines

---

## Requirements

- Android phone with Bluetooth Classic support (Android 5.0+, minSdk 21)
- ELM327 Bluetooth Classic (SPP) OBD2 adapter — paired in Android Bluetooth settings before use
- A Google AI Studio API key with Gemini 2.0 Flash access
- Flutter SDK 3.7+

> **Note:** Bluetooth LE / BLE adapters are **not** supported. The app uses the RFCOMM Serial Port Profile (SPP).

---

## Setup

### 1. Clone and install dependencies

```bash
git clone https://github.com/your-username/elm-obd2.git
cd elm-obd2
flutter pub get
```

### 2. Add your Gemini API key

Create a `.env` file in the project root:

```env
GEMINI_API_KEY=your_key_here
```

Get a free key at [aistudio.google.com](https://aistudio.google.com). The `.env` file is listed in `.gitignore` — never commit it.

### 3. Run on a physical Android device

```bash
flutter run
```

> The app requires a real device. Bluetooth is not available in emulators.

---

## Project structure

```
lib/
├── main.dart
├── app.dart                        # GoRouter + ProviderScope
│
├── core/
│   ├── obd/
│   │   ├── elm327_connector.dart   # BT SPP connection, serial command queue
│   │   ├── obd_service.dart        # PID polling, DTC reading, supported PID cache
│   │   ├── pid_decoder.dart        # SAE J1979 hex → engineering value formulas
│   │   ├── dtc_decoder.dart        # DTC hex → P0xxx string
│   │   └── pid_constants.dart      # All supported PID codes and names
│   │
│   ├── diagnosis/
│   │   ├── gemini_agent.dart       # ChatSession wrapper, function call router
│   │   ├── test_executor.dart      # Runs a test, produces SensorSummary
│   │   ├── test_library.dart       # All 18 named test definitions
│   │   ├── function_tools.dart     # Gemini tool declarations
│   │   ├── system_prompt.dart      # Expert mechanic persona + diagnostic rules
│   │   └── models/
│   │       ├── sensor_summary.dart
│   │       ├── prescribed_test.dart
│   │       ├── diagnosis_result.dart
│   │       └── diagnostic_session.dart
│   │
│   └── storage/
│       └── session_repository.dart # Hive persistence (sessions + checkpoints)
│
└── features/
    ├── home/         # Past sessions + resume interrupted session
    ├── connect/      # Bluetooth device list, connection state
    ├── intake/       # Vehicle info + driver complaint form
    ├── session/      # Main diagnostic loop UI + state machine
    ├── diagnosis/    # Final diagnosis report screen
    └── report/       # PDF export
```

---

## Diagnostic test library

18 tests covering the most common engine and emissions fault patterns:

| Test | Condition | What it diagnoses |
|---|---|---|
| `warm_idle_baseline` | Warm engine, idle | Fuel trims, vacuum leaks, O2 switching |
| `fuel_trim_2000rpm` | Warm, 1800–2200 RPM | Vacuum leak vs MAF/fuel pressure |
| `fuel_trim_rpm_sweep` | Warm, stationary, neutral | Full trim picture across RPM range |
| `o2_switching_analysis` | Warm, idle (5 Hz) | O2 sensor response rate |
| `cat_efficiency_test` | Warm, 2300–2700 RPM | Upstream vs downstream O2 comparison |
| `egr_response_test` | Warm, 1800–2200 RPM | EGR behavior and MAP response |
| `misfire_idle_monitor` | Warm, idle | RPM instability, near-stall events |
| `cold_start_monitor` | Coolant < 35°C | Warm-up enrichment, thermostat |
| `cold_start_temp_curve` | Coolant < 30°C | Coolant rise curve, thermostat fault |
| `fuel_pressure_idle` | Warm, idle | Fuel pump, regulator, filter |
| `maf_map_correlation` | Warm, RPM sweep | MAF accuracy vs MAP |
| `throttle_snap_test` | Warm, idle (5 Hz) | Transient enrichment, MAF peak |
| `cruise_load_fuel_trim` | Warm, 60–80 km/h | Load-dependent trim issues |
| `decel_fuel_cutoff` | Warm, coasting >50 km/h | DFCO, injector leak-down |
| `bank_fuel_trim_comparison` | Warm, idle | Bank 1 vs Bank 2 divergence (V6/V8) |
| `map_baro_sanity` | Warm, idle | MAP sensor accuracy, intake vacuum |
| `oil_temp_warmup_correlation` | Coolant > 60°C | Oil thermostat, oil cooler |
| `extended_idle_stability` | Warm, idle (5 min) | Intermittent idle faults |

---

## Key design decisions

**Serial command queue** — The ELM327 is strictly single-command: a new command is only sent after receiving `>` from the previous one. All commands go through a `Queue` with a mutex pattern.

**No raw data to Gemini** — After each test, raw readings are summarised (avg/min/max/stdDev/stability + notable events). A 60s test at 2 Hz produces 120 readings; only the statistics are sent.

**Unsupported PIDs** — Before a test starts, each required PID is checked against the supported-PID bitmask read from the ECU. Unsupported PIDs are skipped (no timeout wait) and explicitly reported to Gemini as "not available on this vehicle."

**Reconnection resilience** — On connect, any stale RFCOMM socket is torn down before opening a new one, and the connection is retried once with a 1.5 s delay to handle the Android BT stack releasing orphaned sockets from a previous app session.

**Session recovery** — A checkpoint is saved to Hive as soon as the intake scan completes, updated after each test, and finalised on diagnosis. If the app is killed mid-session, the next launch detects the interrupted session and reconstructs the full Gemini context from the saved intake prompt and test summaries.

---

## Android permissions

The following permissions are declared in `AndroidManifest.xml`:

```
BLUETOOTH, BLUETOOTH_ADMIN, BLUETOOTH_CONNECT, BLUETOOTH_SCAN
ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION
INTERNET
RECORD_AUDIO  (Gemini Live voice narration)
```

---

## Dependencies

| Package | Purpose |
|---|---|
| `google_generative_ai` | Gemini 2.0 Flash function calling + Live API |
| `flutter_bluetooth_serial` | Bluetooth Classic SPP connection |
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `hive_flutter` | Local session persistence |
| `pdf` + `printing` | PDF report generation |
| `flutter_dotenv` | API key management via `.env` |
| `web_socket_channel` | Gemini Live WebSocket |
| `permission_handler` | Runtime Bluetooth + location permissions |
