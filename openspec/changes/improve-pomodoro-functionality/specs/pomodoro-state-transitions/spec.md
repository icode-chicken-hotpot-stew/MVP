## ADDED Requirements

### Requirement: Start focus from ready state
The system MUST treat the default ready state as inactive `resting` with the configured focus duration shown in `remainingSeconds`. When the user starts the pomodoro from this state, the system MUST enter the `studying` phase, mark the timer active, and begin counting down from the current focus duration.

#### Scenario: First start enters studying
- **WHEN** the user taps play while the pomodoro is in the default ready state
- **THEN** the controller sets the business phase to `studying`, marks the timer active, and keeps `remainingSeconds` aligned with the configured focus duration countdown

### Requirement: Toggle active and paused state within the current phase
The system MUST use `toggleTimer()` to pause an active phase and resume an inactive paused phase without changing the current business phase. Pausing or resuming MUST preserve the current phase type and continue from the current remaining time.

#### Scenario: Pause focus without changing phase
- **WHEN** the user taps pause during an active focus phase
- **THEN** the controller keeps the business phase as `studying`, marks the timer inactive, and preserves the current `remainingSeconds`

#### Scenario: Resume rest without changing phase
- **WHEN** the user taps play during a paused rest phase
- **THEN** the controller keeps the business phase as `resting`, marks the timer active, and continues the countdown from the preserved `remainingSeconds`

### Requirement: Transition from focus to rest on natural completion
The system MUST transition from `studying` to `resting` when the focus phase naturally reaches zero remaining time. On this transition, the system MUST increment completed focus cycles, load the configured rest duration into `remainingSeconds`, and continue running the rest phase automatically.

#### Scenario: Focus completion enters rest
- **WHEN** an active focus phase counts down to zero
- **THEN** the controller increments completed focus cycles, changes the business phase to `resting`, sets `remainingSeconds` to the configured rest duration, and keeps the timer active

### Requirement: Transition after rest according to cycle configuration
The system MUST evaluate the configured cycle count when a rest phase naturally completes. If no cycle count is configured, the system MUST return to the default ready state. If a cycle count is configured and completed focus cycles are still below that count, the system MUST start the next focus phase automatically. If the configured cycle limit has been reached, the system MUST return to the default ready state.

#### Scenario: Rest completion without loop returns to ready
- **WHEN** an active rest phase reaches zero and `cycleCount` is `null`
- **THEN** the controller returns to inactive `resting` and sets `remainingSeconds` to the configured focus duration

#### Scenario: Rest completion with remaining cycles starts next focus
- **WHEN** an active rest phase reaches zero and `completedFocusCycles` is still less than the configured `cycleCount`
- **THEN** the controller starts the next `studying` phase automatically and loads the configured focus duration into `remainingSeconds`

#### Scenario: Rest completion at cycle limit returns to ready
- **WHEN** an active rest phase reaches zero and `completedFocusCycles` is equal to the configured `cycleCount`
- **THEN** the controller returns to inactive `resting` and sets `remainingSeconds` to the configured focus duration

### Requirement: Reset returns to a consistent ready state
The system MUST use `resetTimer()` to return the pomodoro to a consistent ready state regardless of whether the current phase is active or paused. Reset MUST leave the business phase as `resting`, mark the timer inactive, and set `remainingSeconds` to the configured focus duration.

#### Scenario: Reset while focus is running
- **WHEN** the user taps reset during an active focus phase
- **THEN** the controller stops the current phase, sets the business phase to `resting`, marks the timer inactive, and restores `remainingSeconds` to the configured focus duration

#### Scenario: Reset while rest is paused
- **WHEN** the user taps reset during a paused rest phase
- **THEN** the controller clears the paused phase state and restores the default ready state
