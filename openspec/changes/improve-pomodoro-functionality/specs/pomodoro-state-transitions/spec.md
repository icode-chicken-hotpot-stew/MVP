## ADDED Requirements

### Requirement: Start focus from ready state
The system MUST treat the default ready state as `pomodoroState = resting` and `phaseStatus = ready`, with the configured focus duration shown in `remainingSeconds`. When the user starts the pomodoro from this state, the system MUST enter the `studying` phase, set `phaseStatus` to `running`, and begin counting down from the current focus duration.

#### Scenario: First start enters studying
- **WHEN** the user taps start while the pomodoro is in the default ready state
- **THEN** the controller sets the business phase to `studying`, sets `phaseStatus` to `running`, and keeps `remainingSeconds` aligned with the configured focus duration countdown

### Requirement: Pause and resume within the current phase
The system MUST expose explicit start and pause semantics. `pauseTimer()` MUST pause an active phase without changing the current business phase. `startTimer()` MUST start from ready or resume an inactive paused phase without changing the paused business phase. Pausing or resuming MUST preserve the current phase type and continue from the current remaining time.

#### Scenario: Pause focus without changing phase
- **WHEN** the user taps pause during an active focus phase
- **THEN** the controller keeps the business phase as `studying`, sets `phaseStatus` to `paused`, and preserves the current `remainingSeconds`

#### Scenario: Resume rest without changing phase
- **WHEN** the user taps start during a paused rest phase
- **THEN** the controller keeps the business phase as `resting`, sets `phaseStatus` to `running`, and continues the countdown from the preserved `remainingSeconds`

### Requirement: Transition from focus to rest on natural completion
The system MUST transition from `studying` to `resting` when the focus phase naturally reaches zero remaining time. On this transition, the system MUST increment completed focus cycles, load the configured rest duration into `remainingSeconds`, set `phaseStatus` to `running`, and continue running the rest phase automatically.

#### Scenario: Focus completion enters rest
- **WHEN** an active focus phase counts down to zero
- **THEN** the controller increments completed focus cycles, changes the business phase to `resting`, sets `phaseStatus` to `running`, and sets `remainingSeconds` to the configured rest duration

### Requirement: Transition after rest according to cycle configuration
The system MUST evaluate the configured cycle count when a rest phase naturally completes. If no cycle count is configured, the system MUST return to the default ready state. If a cycle count is configured and `completedFocusCycles` is still below that count, the system MUST start the next focus phase automatically. If `completedFocusCycles` is equal to or greater than the configured cycle count, the system MUST return to the default ready state.

#### Scenario: Rest completion without loop returns to ready
- **WHEN** an active rest phase reaches zero and `cycleCount` is `null`
- **THEN** the controller returns to `pomodoroState = resting`, `phaseStatus = ready`, and sets `remainingSeconds` to the configured focus duration

#### Scenario: Rest completion with remaining cycles starts next focus
- **WHEN** an active rest phase reaches zero and `completedFocusCycles` is still less than the configured `cycleCount`
- **THEN** the controller starts the next `studying` phase automatically, sets `phaseStatus` to `running`, and loads the configured focus duration into `remainingSeconds`

#### Scenario: Rest completion at or above cycle limit returns to ready
- **WHEN** an active rest phase reaches zero and `completedFocusCycles` is equal to or greater than the configured `cycleCount`
- **THEN** the controller returns to `pomodoroState = resting`, `phaseStatus = ready`, and sets `remainingSeconds` to the configured focus duration

### Requirement: Reset returns to a consistent ready state
The system MUST use `resetTimer()` to return the pomodoro to a consistent ready state regardless of whether the current phase is active or paused. Reset MUST leave the business phase as `resting`, set `phaseStatus` to `ready`, and set `remainingSeconds` to the configured focus duration.

#### Scenario: Reset while focus is running
- **WHEN** the user taps reset during an active focus phase
- **THEN** the controller stops the current phase, sets the business phase to `resting`, sets `phaseStatus` to `ready`, and restores `remainingSeconds` to the configured focus duration

#### Scenario: Reset while rest is paused
- **WHEN** the user taps reset during a paused rest phase
- **THEN** the controller clears the paused phase state and restores the default ready state
