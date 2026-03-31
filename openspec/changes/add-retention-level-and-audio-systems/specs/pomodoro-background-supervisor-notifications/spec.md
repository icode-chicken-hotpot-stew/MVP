## ADDED Requirements

### Requirement: Trigger supervisor only for active focus background sessions
The system MUST start a background supervisor session only when the app enters background from an active focus phase where `pomodoroState = studying` and `phaseStatus = running`.

#### Scenario: Enter background during active focus
- **WHEN** the app transitions to background while the pomodoro is `studying + running`
- **THEN** the controller creates one background supervisor session

#### Scenario: Enter background outside active focus
- **WHEN** the app transitions to background while pomodoro is not `studying + running`
- **THEN** the controller does not create a supervisor session

### Requirement: Schedule two staged notifications at 3 minutes and 6 minutes
For each valid background supervisor session, the system MUST schedule at most two local notifications: first at 180 seconds and second at 360 seconds after session start.

#### Scenario: First staged reminder at 3 minutes
- **WHEN** a valid supervisor session is scheduled
- **THEN** the system schedules a first reminder notification for 180 seconds after background entry

#### Scenario: Second staged reminder at 6 minutes
- **WHEN** the same supervisor session is scheduled
- **THEN** the system schedules a second reminder notification for 360 seconds after background entry

### Requirement: Prevent duplicate scheduling while a session is active
The system MUST prevent duplicate supervisor scheduling while the same background session remains active.

#### Scenario: Repeated background callback after successful scheduling
- **WHEN** lifecycle callbacks repeat after a supervisor session has already been activated
- **THEN** the controller does not create or schedule a second session

#### Scenario: Failed schedule can be retried by a later callback
- **WHEN** scheduling fails and no active session is recorded
- **THEN** a later eligible background callback may attempt scheduling again

### Requirement: Cancel pending stages when session becomes invalid
The system MUST cancel pending supervisor stages when any invalidation event occurs: app returns foreground, timer pauses, timer resets, or phase exits the `studying + running` combination.

#### Scenario: Return foreground before 3 minutes
- **WHEN** user returns foreground before 180 seconds
- **THEN** no staged reminder is delivered for that session

#### Scenario: Return foreground between stages
- **WHEN** user returns foreground after scheduling but before the second stage has fired
- **THEN** pending reminders for the active session are canceled

#### Scenario: Pause while backgrounded
- **WHEN** pomodoro is paused during a supervisor session
- **THEN** all pending stages are canceled

### Requirement: Include stage payload and handle permission denial gracefully
Supervisor notifications MUST include session/stage payload metadata, and permission denial MUST degrade gracefully without blocking timer execution or causing app errors.

#### Scenario: Notification payload distinguishes stage
- **WHEN** the service schedules staged reminders
- **THEN** each reminder payload includes the session identifier and either `3m` or `6m` stage metadata

#### Scenario: Notification permission denied
- **WHEN** permission is unavailable during scheduling
- **THEN** the system skips delivery and records non-blocking diagnostics
