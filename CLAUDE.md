# OBD2 AI Diagnostic App — Claude Code Instructions

## Project Overview

Build a Flutter Android app that connects to an ELM327 Bluetooth Classic (SPP) OBD2 scanner,
runs AI-driven diagnostic sessions using Gemini 2.0 Flash function calling, and guides the
user through structured vehicle tests with optional voice narration via Gemini Live.

The app behaves like an expert mechanic: it reads fault codes, forms hypotheses, prescribes
specific tests under specific engine conditions, collects sensor data, interprets results,
and produces an evidence-based diagnosis.

---

## Tech Stack

- **Flutter** (Android only for now, minSdkVersion 21)
- **Bluetooth Classic SPP** via `flutter_bluetooth_serial`
- **Gemini 2.0 Flash** via `google_generative_ai` Dart SDK
- **Gemini Live API** for real-time voice narration during active test phases
- **Local storage** via `hive` for session history
- **PDF generation** via `printing` + `pdf` packages
- **State management** via `riverpod`
- **Navigation** via `go_router`

### pubspec.yaml dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_generative_ai: ^0.4.3
  flutter_bluetooth_serial: ^0.4.0
  permission_handler: ^11.3.0
  riverpod: ^2.5.1
  flutter_riverpod: ^2.5.1
  go_router: ^13.2.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  pdf: ^3.10.8
  printing: ^5.12.0
  flutter_dotenv: ^5.1.0
  http: ^1.2.1
```

---

## Project Structure

```
lib/
├── main.dart
├── app.dart                          # GoRouter setup, ProviderScope
│
├── core/
│   ├── obd/
│   │   ├── elm327_connector.dart     # Bluetooth SPP connection manager
│   │   ├── obd_service.dart          # PID polling, DTC reading, command queue
│   │   ├── pid_decoder.dart          # Hex → human values (SAE J1979 formulas)
│   │   ├── dtc_decoder.dart          # DTC hex → P0xxx string
│   │   ├── pid_constants.dart        # All supported PID codes as constants
│   │   └── models/
│   │       ├── sensor_reading.dart
│   │       ├── dtc_code.dart
│   │       └── test_result.dart
│   │
│   ├── diagnosis/
│   │   ├── gemini_agent.dart         # ChatSession wrapper, function call router
│   │   ├── gemini_live_service.dart  # Live API WebSocket for voice narration
│   │   ├── test_executor.dart        # Executes named tests, produces SensorSummary
│   │   ├── test_library.dart         # All named test definitions
│   │   ├── function_tools.dart       # Gemini tool definitions (function declarations)
│   │   ├── system_prompt.dart        # Full mechanic persona system instruction
│   │   └── models/
│   │       ├── diagnostic_session.dart
│   │       ├── prescribed_test.dart
│   │       ├── sensor_summary.dart
│   │       └── diagnosis_result.dart
│   │
│   └── storage/
│       ├── session_repository.dart   # Hive persistence for sessions
│       └── hive_adapters.dart
│
├── features/
│   ├── home/
│   │   └── home_screen.dart          # Past sessions + start new scan
│   │
│   ├── connect/
│   │   ├── connect_screen.dart       # Scan for BT devices, pair, connect
│   │   └── connect_provider.dart
│   │
│   ├── intake/
│   │   ├── intake_screen.dart        # Vehicle info + driver complaint form
│   │   └── intake_provider.dart
│   │
│   ├── session/
│   │   ├── session_screen.dart       # Main diagnostic session UI
│   │   ├── session_provider.dart     # Session state machine
│   │   ├── widgets/
│   │   │   ├── test_instruction_card.dart  # Shows current test instructions
│   │   │   ├── condition_validator.dart    # Live check: is condition met?
│   │   │   ├── live_sensor_dashboard.dart  # Real-time PID display during test
│   │   │   ├── agent_thinking_indicator.dart
│   │   │   └── test_history_timeline.dart  # All tests run so far
│   │   └── live_narration_overlay.dart     # Gemini Live audio UI
│   │
│   ├── diagnosis/
│   │   ├── diagnosis_screen.dart     # Final diagnosis report
│   │   └── diagnosis_provider.dart
│   │
│   └── report/
│       └── report_generator.dart     # PDF export
│
└── shared/
    ├── theme.dart
    └── widgets/
        ├── pid_value_tile.dart
        └── severity_badge.dart
```

---

## Core Architecture: The Diagnostic Agent Loop

The session flows through these states managed by `session_provider.dart`:

```
intake → llm_hypothesis → test_prescribed → waiting_for_condition
→ collecting → llm_analysis → [loop back to test_prescribed OR conclude]
→ concluded
```

### State Machine (SessionState enum)

```dart
enum SessionState {
  idle,
  intakeScan,         // Reading DTCs, freeze frame
  llmHypothesis,      // Gemini is reasoning over intake data
  testPrescribed,     // Gemini has returned a prescribe_test call
  waitingForCondition,// App showing instructions, user confirming readiness
  collecting,         // Actively polling PIDs
  llmAnalysis,        // Gemini is analyzing test results
  concluded,          // conclude_diagnosis call received
  error,
}
```

---

## OBD Layer

### ELM327 Connector (`elm327_connector.dart`)

Responsibilities:
- Scan for paired Bluetooth Classic devices, filter ELM327-like names
- Connect via `BluetoothConnection.toAddress()`
- Listen to input stream, buffer until `>` character received
- Expose `sendCommand(String cmd)` → `Future<String>`
- Handle timeouts (default 2000ms), reconnection logic
- Initialization sequence on connect: `ATZ` → delay 500ms → `ATE0` → `ATL0` → `ATS0` → `ATH0` → `ATSP0`

### OBD Service (`obd_service.dart`)

Responsibilities:
- `readDTCs()` → sends `03`, parses response into `List<DtcCode>`
- `readFreezeFram()` → sends `02` mode PIDs for the first stored DTC
- `readPID(String pid)` → sends `01{pid}`, decodes via `PidDecoder`, returns `double?`
- `pollPID(String pid, {int seconds})` → repeated reads, returns `List<SensorReading>`
- `readSupportedPIDs()` → sends `0100`, `0120`, `0140`, returns bitmask of supported PIDs
- Command queue: serial execution only — ELM327 cannot handle concurrent commands

### PID Decoder (`pid_decoder.dart`)

Implement SAE J1979 formulas for these PIDs at minimum:

| PID | Name | Formula |
|-----|------|---------|
| 0C | RPM | ((A×256)+B)/4 |
| 0D | Speed km/h | A |
| 05 | Coolant temp °C | A−40 |
| 0F | Intake air temp °C | A−40 |
| 04 | Engine load % | A×100/255 |
| 11 | Throttle position % | A×100/255 |
| 2F | Fuel level % | A×100/255 |
| 06 | Short-term fuel trim % | (A−128)×100/128 |
| 07 | Long-term fuel trim % | (A−128)×100/128 |
| 0B | Intake manifold pressure kPa | A |
| 0A | Fuel pressure kPa | A×3 |
| 10 | MAF g/s | ((A×256)+B)/100 |
| 14 | O2 Sensor B1S1 voltage | A/200 |
| 15 | O2 Sensor B1S2 voltage | A/200 |
| 1F | Engine run time seconds | (A×256)+B |
| 21 | Distance with MIL on km | (A×256)+B |
| 2C | EGR commanded % | A×100/255 |
| 33 | Barometric pressure kPa | A |
| 5C | Oil temperature °C | A−40 |

---

## Test Library (`test_library.dart`)

Define a fixed library of named tests. Gemini selects from this list — it does not invent
arbitrary tests. Each test has:

```dart
class TestDefinition {
  final String id;
  final String name;
  final String conditionDescription;   // shown to user
  final String conditionExpression;    // evaluated against live OBD (e.g. "coolant_temp > 85 && rpm < 900")
  final int durationSeconds;
  final List<String> pids;             // PIDs to poll during test
  final double sampleRateHz;
  final String purpose;                // for system prompt context
}
```

### Required Test Definitions

**`cold_start_monitor`**
- Condition: coolant_temp < 35
- Duration: 180s
- PIDs: coolant_temp, rpm, stft_b1, o2_b1s1, iat, engine_load
- Purpose: Observe warm-up enrichment, O2 sensor light-off, thermostat behavior

**`warm_idle_baseline`**
- Condition: coolant_temp > 85 && rpm < 1000
- Duration: 60s
- PIDs: rpm, stft_b1, ltft_b1, o2_b1s1, o2_b1s2, map, maf, throttle, engine_load
- Purpose: Core fuel trim reading at idle — vacuum leak detection, O2 switching rate

**`fuel_trim_2000rpm`**
- Condition: coolant_temp > 85 && rpm > 1800 && rpm < 2200
- Duration: 45s
- PIDs: rpm, stft_b1, ltft_b1, maf, map, throttle
- Purpose: Compare trims at idle vs 2000 RPM — vacuum leak shows at idle only

**`fuel_trim_rpm_sweep`**
- Condition: coolant_temp > 85, vehicle stationary, neutral
- Duration: 90s (user steps RPM: 1000 → 1500 → 2000 → 2500 → 3000, ~15s each)
- PIDs: rpm, stft_b1, ltft_b1, maf, map
- Purpose: Full picture of how trims change with airflow

**`o2_switching_analysis`**
- Condition: coolant_temp > 85 && rpm < 1000
- Duration: 30s
- PIDs: o2_b1s1, stft_b1, rpm
- Sample rate: 5Hz (higher than default for waveform capture)
- Purpose: Measure O2 sensor switching frequency — healthy = ~0.8–1.2 Hz

**`cat_efficiency_test`**
- Condition: coolant_temp > 85 && rpm between 2300–2700
- Duration: 45s
- PIDs: o2_b1s1, o2_b1s2, rpm, stft_b1
- Purpose: Compare upstream vs downstream O2 — downstream should be stable if cat is working

**`egr_response_test`**
- Condition: coolant_temp > 85 && rpm between 1800–2200
- Duration: 30s
- PIDs: rpm, map, egr_commanded, engine_load
- Purpose: Check EGR behavior and MAP response at cruise RPM

**`misfire_idle_monitor`**
- Condition: coolant_temp > 85 && rpm < 1000
- Duration: 60s
- PIDs: rpm, engine_load, stft_b1, ltft_b1, map, o2_b1s1
- Purpose: Capture RPM instability events — near-stall events logged as notable events

**`cold_start_temp_curve`**
- Condition: coolant_temp < 30
- Duration: 300s (5 minutes)
- PIDs: coolant_temp, rpm, stft_b1
- Sample rate: 0.5Hz
- Purpose: Plot coolant temp rise — thermostat stuck open shows as plateau below 80°C

---

## Sensor Summary (`sensor_summary.dart`)

After each test, compute a summary — do NOT send raw data arrays to Gemini.

```dart
class PidSummary {
  final String pid;
  final double avg;
  final double min;
  final double max;
  final double stdDev;
  final String stability;  // "stable" | "variable" | "erratic"
}

class NotableEvent {
  final int secondsIntoTest;
  final String description;  // e.g. "RPM dipped to 580 (near-stall)"
}

class SensorSummary {
  final String testId;
  final int durationSeconds;
  final int sampleCount;
  final Map<String, PidSummary> pidSummaries;
  final List<NotableEvent> notableEvents;

  // Serialize to clean text block for Gemini prompt
  String toPromptText();
}
```

Notable event detection logic:
- RPM drop > 200 in under 2 seconds → "RPM dip / near-stall event"
- STFT spike > 20% → "Fuel trim spike"
- O2 sensor stuck at same voltage for > 5s → "O2 sensor non-responsive period"

---

## Gemini Agent (`gemini_agent.dart`)

### Function Tool Declarations (`function_tools.dart`)

Define four Gemini function tools:

**1. `prescribe_test`**
```
Parameters:
  test_id (string, required) — must be one of the test library IDs
  instruction (string, required) — plain English instruction shown to user
  condition_hint (string) — brief condition reminder e.g. "engine warm, neutral"
  rationale (string, required) — why this test, what hypothesis it tests
  urgency (string) — "first" | "follow_up" | "confirmatory"
```

**2. `request_vehicle_info`**
```
Parameters:
  questions (array of strings, required) — max 3 questions for the user
  context (string) — why this info is needed
```

**3. `conclude_diagnosis`**
```
Parameters:
  primary_fault (string, required)
  confidence (string, required) — "high" | "medium" | "low"
  evidence (array of strings, required) — bullet points of supporting data
  severity (string, required) — "critical" | "high" | "medium" | "low"
  symptoms_driver_may_notice (array of strings)
  recommended_action (string, required)
  what_obd_cannot_tell (string, required) — honest limits of OBD2 diagnosis
  further_physical_tests (string) — what a mechanic would do next
```

**4. `request_live_narration`**
```
Parameters:
  test_id (string) — the test about to be run
  context (string) — what Gemini Live should watch for and narrate
```

### ChatSession Flow

```dart
class GeminiAgent {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  // Initialize with tools and system instruction
  Future<void> initialize();

  // Turn 1: send intake data, await first function call
  Future<AgentAction> submitIntake(IntakeData intake);

  // Subsequent turns: send test result, await next action
  Future<AgentAction> submitTestResult(SensorSummary result);

  // Submit user answers to request_vehicle_info
  Future<AgentAction> submitVehicleInfo(Map<String, String> answers);
}

// AgentAction is a sealed class:
sealed class AgentAction {}
class PrescribeTestAction extends AgentAction { PrescribedTest test; }
class RequestVehicleInfoAction extends AgentAction { List<String> questions; }
class RequestLiveNarrationAction extends AgentAction { String testId; String context; }
class ConcludeAction extends AgentAction { DiagnosisResult result; }
```

### IntakeData (sent on Turn 1)

```dart
class IntakeData {
  final String vehicleMake;
  final String vehicleModel;
  final int vehicleYear;
  final String engineDisplacement;
  final int odometer;
  final List<DtcCode> dtcs;
  final Map<String, double> freezeFrame;   // PID values at time of fault
  final List<String> supportedPids;
  final String driverComplaint;            // free text from user
  final String? recentRepairs;
}
```

Format as a structured text block when sending to Gemini — not as JSON.

---

## System Prompt (`system_prompt.dart`)

The system prompt is the mechanic persona. Include these sections:

### Identity
You are an expert automotive diagnostic technician with deep knowledge of OBD2 systems,
engine management, fuel systems, and emissions. You diagnose vehicles by forming hypotheses
and testing them with real sensor data — never by looking up fault codes in a table.

### Core Diagnostic Rules
1. Fault codes indicate a symptom, not a cause. Always find the root cause.
2. Never conclude from codes alone. Every conclusion must be supported by sensor evidence.
3. Form 1–3 competing hypotheses after seeing intake data. Design tests that differentiate between them.
4. Prefer the test that eliminates the most hypotheses with the least effort.
5. Idle tests before drive tests. Cold tests only when cold start is the specific symptom.
6. After each test result, state explicitly: which hypotheses are strengthened, which are eliminated.
7. Maximum 5 tests per session. If unresolved after 5, conclude with remaining uncertainty stated.

### Test Selection Rules
- Always start with `warm_idle_baseline` unless the complaint is specifically cold-start related.
- Fuel trim questions: follow with `fuel_trim_2000rpm` to compare idle vs off-idle.
- O2 sensor suspicion: use `o2_switching_analysis` (not just fuel trims).
- Misfire: use `misfire_idle_monitor` first, then `cat_efficiency_test` if codes suggest cat.
- Temperature complaints: use `cold_start_temp_curve`.

### Key Diagnostic Patterns (embed these directly in system prompt)

**Fuel Trim Patterns:**
- STFT/LTFT high at idle only → vacuum leak (normalizes off-idle due to higher airflow masking the leak)
- STFT/LTFT high at all RPMs → MAF under-reading or low fuel pressure
- STFT/LTFT very negative → fuel pressure too high, leaking injector, or coolant temp sensor stuck cold
- STFT hunting/unstable → lazy O2 sensor (ECU can't find closed-loop equilibrium)

**O2 Sensor Patterns:**
- Upstream switching rate < 0.5 Hz when warm → contaminated/lazy sensor
- Downstream switching like upstream → dead catalytic converter
- Both banks lean (P0171 + P0174) → upstream cause: MAF, intake leak before throttle body
- One bank lean → bank-specific: injector, O2 sensor, manifold leak that bank

**Misfire Patterns:**
- Misfire at idle, clears at RPM → injector drip, low compression (easier to fire at lower pressure), EGR stuck open
- Misfire worsens under load → weak ignition coil, low compression, injector failing at high duty cycle
- Random misfires across cylinders → fuel pressure issue, MAF/MAP fueling error, cam/crank correlation
- Single cylinder + positive fuel trim that bank → weak/dead injector

**Temperature Patterns:**
- Coolant rises quickly, plateaus below 80°C → thermostat stuck open
- Coolant reads cold when warm → sensor fault (ECU over-enriches permanently)
- Rapid overheating → coolant loss, head gasket, water pump failure

### Honesty Rules
Always separate:
- "OBD2 data confirms" vs "OBD2 data suggests"
- What can be fixed with this data vs what requires physical inspection

State confidence level. State what evidence would change your conclusion.
Tell the user what a mechanic would do next that goes beyond OBD2 scope (smoke test, compression test, etc).

### Response Format
You must ONLY respond by calling one of the four provided functions.
Never respond with plain text. Every turn must result in exactly one function call.

---

## Session UI (`session_screen.dart`)

The session screen has three zones:

### Zone 1 — Agent Status Bar (top)
Shows current state: "Analyzing fault codes...", "Test 2 of 3 complete", "Forming diagnosis..."

### Zone 2 — Main Content (center, changes by state)

**State: `llmHypothesis` / `llmAnalysis`**
Show thinking animation + last agent rationale text (extracted from the `rationale` field
of the prescribe_test call).

**State: `testPrescribed`**
Show `TestInstructionCard`:
- Large instruction text (the `instruction` field from Gemini)
- Condition indicator: live check if condition is currently met
  (e.g. green check when coolant_temp > 85 confirmed from live OBD)
- "Start Test" button — only enabled when condition is met
- Rationale section (collapsed by default): "Why this test?"

**State: `waitingForCondition`**
Live mini-dashboard showing the 2–3 PIDs relevant to the condition:
- Large value display
- Target range indicator
- "Condition met — tap to start" banner appears when condition satisfied

**State: `collecting`**
Full live sensor dashboard:
- All test PIDs displayed with current value + small sparkline
- Progress bar showing time elapsed / total duration
- Notable events list updating in real time
- If Gemini Live active: waveform visualizer + Gemini narration text

**State: `concluded`**
Transition to diagnosis screen.

### Zone 3 — Test History Timeline (bottom, always visible)
Scrollable list of completed tests with pass/flag indicator and one-line summary.

---

## Condition Validation

Conditions from the test library are string expressions. Parse and evaluate them against
live OBD readings:

```dart
class ConditionEvaluator {
  // Polls the relevant PIDs every 3 seconds
  // Evaluates the expression string against current values
  // Emits bool stream: is condition currently satisfied?
  Stream<ConditionStatus> evaluate(String conditionExpression);
}

class ConditionStatus {
  final bool isMet;
  final Map<String, double> currentValues;   // PIDs involved in condition
  final Map<String, String> targetDescriptions; // "needs to be > 85°C"
}
```

The UI uses this stream to show live feedback to the user before starting a test.

---

## Gemini Live Integration (`gemini_live_service.dart`)

Only activate during `collecting` state, and only when Gemini has called `request_live_narration`.

Architecture:
- Open WebSocket to Gemini Live API
- Every 2 seconds during collection, send a text message:
  `"[{elapsed}s] RPM:{rpm} STFT:{stft}% LTFT:{ltft}% MAF:{maf}g/s O2:{o2}V"`
- Receive audio stream, play via Flutter audio output
- On test complete, close WebSocket, return to standard ChatSession flow

The Live context (from `request_live_narration.context`) becomes the Live session's
system instruction — telling Gemini Live what to watch for and how to guide the driver.

---

## Diagnosis Report (`report_generator.dart`)

PDF report sections:
1. Vehicle info + date
2. Driver complaint
3. Fault codes found
4. Tests performed (table: test name, condition, duration, key findings)
5. Diagnosis: primary fault, confidence, evidence bullets
6. Severity badge
7. Recommended actions
8. What requires physical inspection (the `what_obd_cannot_tell` field)
9. Raw sensor summaries (appendix)

---

## Environment Configuration

Use `flutter_dotenv`. `.env` file at project root:

```
GEMINI_API_KEY=your_key_here
```

Load in `main.dart` before `runApp()`. Access via `dotenv.env['GEMINI_API_KEY']`.
Add `.env` to `.gitignore` immediately.

---

## Android Configuration

### `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### `android/app/build.gradle`
```
minSdkVersion 21
targetSdkVersion 34
```

---

## Build Order

Build in this exact sequence. Do not proceed to the next phase until the current one works end-to-end.

### Phase 1 — OBD Foundation
1. `elm327_connector.dart` — connect, initialize, `sendCommand()`
2. `obd_service.dart` — `readDTCs()`, `readPID()`, `pollPID()`
3. `pid_decoder.dart` — all PIDs in the table above
4. `connect_screen.dart` — scan devices, tap to connect, show connection status
5. Simple debug screen: send `ATZ`, display raw response. Then read RPM + coolant temp live.

**Acceptance test:** App connects to ELM327, reads coolant temp and RPM, displays them updating live.

### Phase 2 — Test Execution
1. `test_library.dart` — all test definitions
2. `test_executor.dart` — execute any test by ID, produce `SensorSummary`
3. `condition_evaluator.dart` — live condition checking
4. Simple test runner screen: pick a test from dropdown, run it, display summary text output

**Acceptance test:** App runs `warm_idle_baseline`, displays a clean summary with avg/min/max per PID and any notable events.

### Phase 3 — Gemini Agent
1. `system_prompt.dart`
2. `function_tools.dart` — all four tool declarations
3. `gemini_agent.dart` — ChatSession, function call routing
4. `intake_screen.dart` — vehicle info form + driver complaint
5. `session_provider.dart` — full state machine
6. `session_screen.dart` — all states

**Acceptance test:** Full session runs end to end — intake → Gemini prescribes test → test runs → Gemini analyzes → conclusion rendered.

### Phase 4 — Gemini Live
1. `gemini_live_service.dart`
2. Live narration overlay in `session_screen.dart`

**Acceptance test:** During a `warm_idle_baseline` test, Gemini Live narrates sensor readings in voice.

### Phase 5 — Polish
1. `session_repository.dart` — Hive persistence
2. `home_screen.dart` — past sessions list
3. `report_generator.dart` — PDF export
4. Full app theming (`theme.dart`) — dark automotive aesthetic

---

## Key Implementation Notes

- **ELM327 command queue is strictly serial.** Never send a new command before receiving `>` from the previous one. Use a `Queue` with a mutex/lock pattern.

- **Condition expressions** are simple strings like `"coolant_temp > 85 && rpm < 1000"`. Parse them by splitting on `&&`, evaluating each clause against a `Map<String, double>` of current PID values. No need for a full expression parser.

- **Gemini function call handling:** The `google_generative_ai` SDK returns `FunctionCall` objects in the response. Always check `response.functionCalls` first. Send back a `FunctionResponse` part to continue the chat. Never let the user see a plain text response — the system prompt enforces function-only replies but handle the case defensively.

- **SensorSummary → prompt text:** Call `summary.toPromptText()` which returns a clean multi-line string (not JSON). Gemini reasons better over formatted text than raw data structures for this use case.

- **Session recovery:** Persist session state to Hive after every state transition. If the app is killed mid-session, offer to resume on next open.

- **Gemini Live WebSocket:** Use the `web_socket_channel` package. The Live API requires a specific message format — refer to the Gemini Live API documentation for the exact protocol (setup message, audio config, text input format).

- **Do not send raw PID arrays to Gemini.** Always summarize first. A 60-second test at 2Hz produces 120 readings — send the statistics, not the array.
