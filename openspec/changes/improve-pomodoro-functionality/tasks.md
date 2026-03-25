## 1. Controller state and persistence foundation

- [ ] 1.1 Add pomodoro business state, duration configuration, cycle configuration, and completed-cycle state to `lib/app_controller.dart`
- [ ] 1.2 Add an internal pomodoro snapshot model and local persistence read/write helpers for phase type, start time, phase duration, active state, paused remaining time, durations, cycle count, and completed cycles
- [ ] 1.3 Add a controller initialization entrypoint that restores saved configuration and pomodoro snapshot during app startup
- [ ] 1.4 Add `shared_preferences` dependency and wire pomodoro persistence through a lightweight local key-value storage path

## 2. Timer runtime and state transitions

- [ ] 2.1 Implement `toggleTimer()` to support first start from ready, pause of an active phase, and resume of a paused phase without changing the wrong business phase
- [ ] 2.2 Implement runtime countdown updates and natural focus-to-rest transition behavior, including completed focus cycle increments
- [ ] 2.3 Implement rest completion branching for no-loop, remaining-loop, and loop-limit-reached cases
- [ ] 2.4 Implement `resetTimer()` so any active or paused phase returns to a consistent ready state and persists that reset snapshot
- [ ] 2.5 Implement recovery-time phase advancement so expired saved phases are advanced until a valid current phase or ready state is reached

## 3. Duration and cycle configuration behavior

- [ ] 3.1 Add `updateFocusDuration(int seconds)` and `updateRestDuration(int seconds)` with defaults of 1500 and 300 seconds and persistence of updated values
- [ ] 3.2 Add `updateCycleCount(int? count)` with validation for `null` or finite positive integers only
- [ ] 3.3 Apply the rule that ready-state focus duration updates refresh `remainingSeconds`, while active-phase updates affect only future eligible phases

## 4. UI integration with real controller state

- [ ] 4.1 Remove the formal dependency on `_fakeTimer`, `_fakeProgress`, and `_resetFakeProgress()` in `lib/ui_widgets.dart`
- [ ] 4.2 Change the top `LinearProgressIndicator` to derive progress from controller state and the current phase duration instead of `_fakeProgress`
- [ ] 4.3 Keep countdown text, play/pause button state, and reset behavior fully driven by controller state and methods
- [ ] 4.4 Ensure `lib/main.dart` triggers controller initialization early enough that restored state is available before normal UI interaction

## 5. Deferred non-goals for this change

- [ ] 5.1 Leave `fetchHistoryData()` as placeholder/non-blocking interface for this batch and avoid expanding this change into full history-statistics contract work
- [ ] 5.2 Leave settings-entry UI placement and interaction design out of this batch while keeping future settings consumption compatible with controller configuration methods

## 6. Verification

- [ ] 6.1 Add targeted tests for controller start, pause, resume, reset, focus completion, rest completion, and cycle-limit behavior
- [ ] 6.2 Add targeted tests for snapshot persistence, paused recovery, active recovery, and expired-phase advancement
- [ ] 6.3 Run `flutter analyze` and `flutter test`
- [ ] 6.4 Manually verify the main pomodoro flow, including app background/resume and restart recovery behavior
