## ADDED Requirements

### Requirement: Provide configurable focus and rest durations
The system MUST expose controller-level configuration for focus duration and rest duration. The default focus duration MUST be 1500 seconds and the default rest duration MUST be 300 seconds.

#### Scenario: Default duration values are available on initialization
- **WHEN** the controller is created without saved configuration
- **THEN** the focus duration is 1500 seconds and the rest duration is 300 seconds

#### Scenario: User updates focus duration
- **WHEN** the user changes the configured focus duration
- **THEN** the controller stores the new focus duration value for future focus phases

#### Scenario: User updates rest duration
- **WHEN** the user changes the configured rest duration
- **THEN** the controller stores the new rest duration value for future rest phases

### Requirement: Refresh ready-state display when focus duration changes
The system MUST refresh `remainingSeconds` to the configured focus duration when the pomodoro is in the default ready state and the focus duration is updated. The system MUST NOT silently rewrite the remaining time of an already running phase.

#### Scenario: Updating focus duration from ready updates the displayed countdown
- **WHEN** the pomodoro is inactive in the default ready state and the focus duration is changed
- **THEN** the controller updates `remainingSeconds` to match the new focus duration

#### Scenario: Updating focus duration during an active phase does not rewrite current countdown
- **WHEN** the pomodoro is already running and the focus duration is changed
- **THEN** the controller preserves the current phase countdown and applies the new value only to later eligible phases

### Requirement: Support finite cycle counts only
The system MUST support a cycle count configuration of either `null` for no looping or a positive integer for a finite number of focus cycles. The system MUST reject zero, negative values, and any representation of infinite looping.

#### Scenario: User clears cycle count to disable looping
- **WHEN** the user removes the configured cycle count
- **THEN** the controller stores `null` and the pomodoro stops after the current rest completion path returns to ready

#### Scenario: User sets a finite cycle count
- **WHEN** the user enters a positive integer cycle count
- **THEN** the controller stores that number as the maximum focus-cycle target

#### Scenario: User attempts to configure an invalid cycle count
- **WHEN** the user provides zero, a negative number, or an infinite-loop value
- **THEN** the controller does not accept that value as a valid cycle configuration

### Requirement: Persist duration and cycle configuration
The system MUST persist focus duration, rest duration, and cycle count configuration so that configuration survives app restart and is available during recovery.

#### Scenario: Restore saved duration configuration on app start
- **WHEN** the app starts after the user previously changed focus or rest duration
- **THEN** the controller restores those saved duration values before exposing pomodoro state to the UI

#### Scenario: Restore saved cycle configuration on app start
- **WHEN** the app starts after the user previously configured a finite cycle count
- **THEN** the controller restores that cycle count before evaluating subsequent phase transitions
