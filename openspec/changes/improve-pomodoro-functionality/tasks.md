## 1. Controller state and persistence foundation

- [x] 1.1 Add pomodoro business state, phase-status state, duration configuration, cycle configuration, and completed-cycle state to `lib/app_controller.dart`
- [x] 1.2 Add an internal pomodoro snapshot model and local persistence read/write helpers for phase type, phase status, optional running `startedAt`, phase duration, non-running remaining time, durations, cycle count, and completed cycles
- [x] 1.3 Add a controller initialization entrypoint that restores saved configuration and pomodoro snapshot during app startup
- [x] 1.4 Add `shared_preferences` dependency and wire pomodoro persistence through a lightweight local key-value storage path
- [x] 1.5 Freeze state responsibilities in implementation: `pomodoroState` serves business-phase semantics for animation/dialogue/companion behavior; `phaseStatus` serves runtime-control semantics for timer/button/recovery/persistence behavior
- [x] 1.6 Persist default ready-state snapshots with fixed values: `startedAt = null`, `phaseDurationSeconds = focusDurationSeconds`, and `remainingSeconds = focusDurationSeconds`

## 2. Timer runtime and state transitions

- [x] 2.1 Replace `toggleTimer()` as the target contract with explicit `startTimer()` and `pauseTimer()` semantics: start from ready, pause an active phase, and resume a paused phase without changing the wrong business phase
- [x] 2.2 Implement runtime countdown updates and natural focus-to-rest transition behavior, including completed focus cycle increments
- [x] 2.3 Implement rest completion branching for no-loop, remaining-loop, and loop-limit-reached cases
- [x] 2.4 Implement `resetTimer()` so any active or paused phase returns to a consistent ready state, clears session-scoped `completedFocusCycles`, and persists that reset snapshot
- [x] 2.5 Implement recovery-time phase advancement so expired saved phases are advanced until a valid current phase or ready state is reached, including multi-phase catch-up logic
- [x] 2.6 Treat invalid control calls as no-op: `startTimer()` while running, `pauseTimer()` while ready/paused, and `resetTimer()` while ready must not create extra transitions or persistence writes
- [x] 2.7 Ensure any terminal path back to default ready state clears session-scoped `completedFocusCycles`

## 3. Duration and cycle configuration behavior

- [x] 3.1 Add `updateFocusDuration(int seconds)` and `updateRestDuration(int seconds)` with defaults of 1500 and 300 seconds and persistence of updated values
- [x] 3.2 Add `updateCycleCount(int? count)` with validation for `null` or finite positive integers only
- [x] 3.3 Apply the rule that ready-state focus duration updates refresh `remainingSeconds`, while active-phase updates affect only future eligible phases
- [x] 3.4 Enforce duration validation for finite positive integer seconds only; reject zero, negative, empty, non-numeric, and decimal-derived values for this change
- [x] 3.5 Implement the frozen UI/controller unit boundary: frontend duration inputs use minutes, while controller contract and persistence use seconds

## 4. UI integration with real controller state

- [x] 4.1 Remove the formal dependency on `_fakeTimer`, `_fakeProgress`, and `_resetFakeProgress()` in `lib/ui_widgets.dart`
- [x] 4.2 Change the top progress indicator to derive progress from controller state and the current phase duration instead of `_fakeProgress`, including the ready-state special case that uses focus duration with zero progress
- [x] 4.3 Replace the current play/pause-toggle interaction with explicit start, pause, and reset controls driven by controller methods and derive phase labels from `pomodoroState + phaseStatus`
- [x] 4.4 Add three frontend inputs for focus duration, rest duration, and cycle count, wired only to controller configuration methods
- [x] 4.5 Ensure `lib/main.dart` triggers controller initialization early enough that restored state is available before normal UI interaction
- [x] 4.6 Keep UI-side semantics aligned with the frozen contract: `pomodoroState` drives companion/animation semantics, while `phaseStatus` drives control/button/recovery semantics

## 5. Deferred non-goals for this change

- [x] 5.1 Leave `fetchHistoryData()` as placeholder/non-blocking interface for this batch and avoid expanding this change into full history-statistics contract work
- [x] 5.2 Leave settings-entry visual placement and final interaction design out of this batch while keeping future settings consumption compatible with controller configuration methods

## 6. Verification

- [ ] 6.1 Add targeted tests for controller start, pause, resume, reset, focus completion, rest completion, cycle-limit behavior, and ready-state progress selection
- [ ] 6.2 Add targeted tests for snapshot persistence, paused recovery, active recovery, expired-phase advancement, and multi-phase recovery catch-up
- [ ] 6.3 Add targeted tests for invalid control-call no-op behavior and session-scoped `completedFocusCycles` clearing
- [ ] 6.4 Add targeted tests for duration validation and the frozen minute-input / second-contract conversion boundary
- [ ] 6.5 Run `flutter analyze` and `flutter test`
- [ ] 6.6 Manually verify the main pomodoro flow, including app background/resume, restart recovery, three control buttons, and three configuration inputs
