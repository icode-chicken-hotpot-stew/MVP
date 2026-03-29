## ADDED Requirements

### Requirement: Trigger supervisor only for active focus background sessions
The system MUST start a background supervisor session only when the app enters background from an active focus phase where `pomodoroState = studying` and `phaseStatus = running`.

#### Scenario: Enter background during active focus
- **WHEN** the app transitions to background while the pomodoro is `studying + running`
- **THEN** the controller creates one background supervisor session

#### Scenario: Enter background outside active focus
- **WHEN** the app transitions to background while pomodoro is not `studying + running`
- **THEN** the controller does not create a supervisor session

### Requirement: Send two staged notifications at 3 minutes and 6 minutes
For each valid background supervisor session, the system MUST send at most two local notifications: first at 180 seconds and second at 360 seconds after session start.

#### Scenario: First staged reminder at 3 minutes
- **WHEN** a valid supervisor session reaches 180 seconds in background
- **THEN** the system sends the first reminder notification once

#### Scenario: Second staged reminder at 6 minutes
- **WHEN** the same supervisor session reaches 360 seconds in background
- **THEN** the system sends the second reminder notification once

### Requirement: Enforce session-level deduplication
The system MUST prevent duplicate staged notifications within the same background session, including repeated lifecycle callbacks or scheduling retries.

#### Scenario: Duplicate callback does not duplicate 3-minute notification
- **WHEN** lifecycle callbacks repeat within one session around the 180-second node
- **THEN** the 3-minute stage is marked as sent and not sent again

#### Scenario: Duplicate callback does not duplicate 6-minute notification
- **WHEN** lifecycle callbacks repeat within one session around the 360-second node
- **THEN** the 6-minute stage is marked as sent and not sent again

### Requirement: Cancel pending stages when session becomes invalid
The system MUST cancel pending supervisor stages when any invalidation event occurs: app returns foreground, timer pauses, timer resets, or phase exits the `studying + running` combination.

#### Scenario: Return foreground before 3 minutes
- **WHEN** user returns foreground before 180 seconds
- **THEN** no staged reminder is sent

#### Scenario: Return foreground between stages
- **WHEN** user returns foreground after 3-minute stage but before 6-minute stage
- **THEN** the 6-minute stage is canceled and not sent

#### Scenario: Pause while backgrounded
- **WHEN** pomodoro is paused during a supervisor session
- **THEN** all pending stages are canceled

### Requirement: Graceful permission-denied handling
If local-notification permission is unavailable, the system MUST degrade gracefully without blocking timer execution or causing app errors.

#### Scenario: Notification permission denied
- **WHEN** the staged reminder is due but permission is denied
- **THEN** the system skips delivery and records non-blocking diagnostics
