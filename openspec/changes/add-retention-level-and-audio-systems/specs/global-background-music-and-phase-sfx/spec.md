## ADDED Requirements

### Requirement: Auto-play global background music after app startup
The system MUST auto-play background music after app initialization regardless of pomodoro phase state, subject to persisted playback preference.

#### Scenario: Startup triggers BGM autoplay
- **WHEN** app initialization completes and autoplay is enabled
- **THEN** background music starts playing by default

#### Scenario: Autoplay independent from pomodoro phase
- **WHEN** pomodoro phase is `ready`, `studying`, or `resting`
- **THEN** global BGM policy remains valid and can keep playing

### Requirement: Persist manual playback overrides
The system MUST allow users to pause/resume BGM manually, and MUST persist playback preferences including autoplay-enabled flag, playing state, track index, and volume.

#### Scenario: Manual pause overrides autoplay
- **WHEN** user pauses BGM manually
- **THEN** playback stops and persisted state reflects manual override

#### Scenario: Restart restores playback preference
- **WHEN** app restarts after user-adjusted playback settings
- **THEN** controller restores track, volume, and autoplay/playing preferences

### Requirement: Pause and resume BGM across lifecycle transitions
The system MUST pause auto-managed BGM on app backgrounding and attempt to resume it on foreground return when the user has not explicitly turned music off.

#### Scenario: Background pauses music
- **WHEN** app enters background while auto-managed BGM is playing
- **THEN** the controller pauses BGM without discarding playback preference

#### Scenario: Foreground resumes lifecycle-paused music
- **WHEN** app returns to foreground after lifecycle-driven pause
- **THEN** the controller attempts to resume BGM using persisted volume

### Requirement: Trigger phase SFX on defined phase transitions
The system MUST trigger short SFX on specific pomodoro transitions: start study, study-to-rest completion, and rest-to-study continuation.

#### Scenario: Start study plays start SFX
- **WHEN** transition is `ready -> studying/running`
- **THEN** `study_start` SFX is triggered once

#### Scenario: Study completion plays end SFX
- **WHEN** transition is `studying/running -> resting/running`
- **THEN** `study_end` SFX is triggered once

#### Scenario: Rest completion to next study plays start SFX
- **WHEN** transition is `resting/running -> studying/running`
- **THEN** `study_start` SFX is triggered once

### Requirement: Support four semantic SFX types
The system MUST provide and route four semantic SFX types: `study_start`, `study_end`, `button_open`, and `button_back`.

#### Scenario: Study phase start maps to study_start SFX
- **WHEN** an event indicates study phase is started
- **THEN** the system routes `study_start` SFX for playback

#### Scenario: Study phase completion maps to study_end SFX
- **WHEN** an event indicates study phase is completed and moved to rest
- **THEN** the system routes `study_end` SFX for playback

#### Scenario: Open interaction maps to button_open SFX
- **WHEN** an event indicates a UI open action (for example open panel/dialog)
- **THEN** the system routes `button_open` SFX for playback

#### Scenario: Back interaction maps to button_back SFX
- **WHEN** an event indicates a UI back/close action (for example cancel/close/pop)
- **THEN** the system routes `button_back` SFX for playback

### Requirement: Trigger UI button SFX on open/back interactions
The system MUST trigger UI SFX on semantic open/back interactions and MUST keep this behavior non-blocking to UI state transitions.

#### Scenario: Opening pomodoro config plays open SFX
- **WHEN** user opens pomodoro config while interaction is allowed
- **THEN** one `button_open` SFX is triggered

#### Scenario: Closing dialog or config plays back SFX
- **WHEN** user closes/cancels config or closes a dialog
- **THEN** one `button_back` SFX is triggered

### Requirement: Deduplicate rapid repeated UI SFX requests
The system MUST prevent duplicate UI SFX playback caused by rapid repeated triggers within a single interaction chain, while keeping UI behavior non-blocking.

#### Scenario: Same-type rapid trigger is deduplicated
- **WHEN** two `button_open` requests (or two `button_back` requests) arrive within a short dedup window
- **THEN** at most one playback starts and the duplicate request is dropped silently

#### Scenario: Consecutive rapid trigger is throttled
- **WHEN** two UI SFX requests of any type arrive within a short cooldown window
- **THEN** only the first playback is accepted and later request(s) are ignored

#### Scenario: Duplicate prevention does not block UI flow
- **WHEN** a UI SFX request is dropped by dedup/throttle logic
- **THEN** UI state transition and controller logic continue normally without error

### Requirement: Keep timer flow resilient to audio failures
Audio playback failures MUST NOT block timer transitions, controller state updates, or persistence writes.

#### Scenario: SFX playback error during phase transition
- **WHEN** SFX playback fails at a transition point
- **THEN** timer transition still completes and system records non-blocking diagnostics

#### Scenario: BGM playback error at startup
- **WHEN** BGM autoplay fails during startup
- **THEN** app remains usable and pomodoro flow is unaffected
