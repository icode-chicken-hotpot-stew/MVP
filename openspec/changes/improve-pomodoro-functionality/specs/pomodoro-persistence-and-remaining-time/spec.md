## ADDED Requirements

### Requirement: Persist pomodoro runtime snapshot
The system MUST persist a pomodoro runtime snapshot in local storage when a pomodoro phase starts, resumes, pauses, resets, or naturally transitions. The snapshot MUST include the current phase type, the current `phaseStatus`, the current phase duration, the remaining seconds needed for non-running recovery, the configured focus duration, the configured rest duration, the configured cycle count, and the completed focus cycle count. The snapshot MUST include `startedAt` when `phaseStatus == running`; `startedAt` MAY be absent when `phaseStatus` is `paused` or `ready`.

#### Scenario: Save snapshot when focus starts
- **WHEN** the user starts the pomodoro from the default ready state
- **THEN** the system saves a snapshot containing `studying` as the current phase, `running` as the current `phaseStatus`, the new phase start time, the focus phase duration, and the current configuration values

#### Scenario: Save snapshot when timer pauses
- **WHEN** the user pauses a running pomodoro phase
- **THEN** the system saves a snapshot containing the current phase type, `paused` as the current `phaseStatus`, and the remaining seconds at the moment of pause

### Requirement: Use lightweight key-value local storage for pomodoro persistence
The system MUST implement pomodoro snapshot and configuration persistence using `shared_preferences`-style local key-value storage for this change. The system MUST NOT require a relational schema, multi-table storage model, or heavier database layer to satisfy the current rapid-delivery persistence contract.

#### Scenario: Persist pomodoro snapshot with lightweight local storage
- **WHEN** the controller saves the latest pomodoro runtime snapshot
- **THEN** it writes the snapshot through a `shared_preferences`-style local key-value persistence path suitable for the current rapid-delivery single-device app phase

### Requirement: Recover remaining time from persisted snapshot
The system MUST restore pomodoro state from the latest persisted snapshot during controller initialization. If the snapshot indicates a running phase, the system MUST recompute remaining time from the persisted phase start time and phase duration instead of trusting a stale in-memory countdown value.

#### Scenario: Restore an active focus session after app restart
- **WHEN** the app starts and the latest snapshot represents a running focus phase that has not yet expired
- **THEN** the controller restores the focus phase, sets `phaseStatus` to `running`, and sets `remainingSeconds` to the recomputed time left in that phase

#### Scenario: Restore a paused session after app restart
- **WHEN** the app starts and the latest snapshot represents a paused phase
- **THEN** the controller restores that phase, sets `phaseStatus` to `paused`, and sets `remainingSeconds` to the persisted paused value

### Requirement: Advance expired phases during recovery
The system MUST handle expired persisted phases during recovery by applying the pomodoro state transition rules until the recovered state reaches a non-expired phase or the default ready state. The system MUST NOT restore an already expired phase as if it were still current.

#### Scenario: Advance from expired focus to rest during recovery
- **WHEN** the app starts and the latest snapshot represents a running focus phase whose persisted end time is already in the past
- **THEN** the controller advances the recovered state according to the phase transition rules instead of restoring the expired focus phase unchanged

#### Scenario: Advance across multiple expired phases during recovery
- **WHEN** the app starts and the latest snapshot is so old that recovery must cross more than one expired focus/rest phase pair
- **THEN** the controller repeatedly applies the transition rules in order, increments `completedFocusCycles` for each recovered focus completion, and stops only when it reaches a non-expired current phase or the default ready state

#### Scenario: Return to ready when recovery has no remaining active phase
- **WHEN** recovery advances through expired phases and no next active phase should continue
- **THEN** the controller restores the default ready state with `pomodoroState = resting`, `phaseStatus = ready`, and the configured focus duration as the displayed remaining time

### Requirement: Expose recovered remaining time to UI
The system MUST expose the recovered and runtime-updated `remainingSeconds` through controller state so that UI countdown text and progress display can consume the same source of truth.

#### Scenario: UI receives recovered remaining time after initialization
- **WHEN** the controller completes initialization from persisted snapshot data
- **THEN** the UI can read `remainingSeconds` from the controller as the authoritative remaining time for the current phase

### Requirement: Provide explicit initialization entrypoint for recovery
The controller MUST provide an `initialize()` method or an equivalent explicit startup recovery entrypoint so app startup can complete persistence restoration before normal UI interaction begins.

#### Scenario: Main stage triggers controller initialization on startup
- **WHEN** the app creates the shared `AppController` instance during startup
- **THEN** the app can invoke `initialize()` or the equivalent recovery entrypoint before exposing stable pomodoro state to normal UI interaction
