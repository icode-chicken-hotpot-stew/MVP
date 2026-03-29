## ADDED Requirements

### Requirement: Auto-play global background music after app startup
The system MUST auto-play background music after app initialization regardless of pomodoro phase state.

#### Scenario: Startup triggers BGM autoplay
- **WHEN** app initialization completes
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

### Requirement: Trigger phase SFX on defined phase transitions
The system MUST trigger short SFX on specific pomodoro transitions: start focus, focus-to-rest completion, and rest-to-focus continuation.

#### Scenario: Start focus plays start SFX
- **WHEN** transition is `ready -> studying/running`
- **THEN** start SFX is triggered once

#### Scenario: Focus completion plays encouragement SFX
- **WHEN** transition is `studying/running -> resting/running`
- **THEN** encouragement SFX is triggered once

#### Scenario: Rest completion to next focus plays start SFX
- **WHEN** transition is `resting/running -> studying/running`
- **THEN** start SFX is triggered once

### Requirement: Keep timer flow resilient to audio failures
Audio playback failures MUST NOT block timer transitions, controller state updates, or persistence writes.

#### Scenario: SFX playback error during phase transition
- **WHEN** SFX playback fails at a transition point
- **THEN** timer transition still completes and system records non-blocking diagnostics

#### Scenario: BGM playback error at startup
- **WHEN** BGM autoplay fails during startup
- **THEN** app remains usable and pomodoro flow is unaffected
