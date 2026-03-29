## ADDED Requirements

### Requirement: Grant XP from effective focus completion only
The system MUST grant XP only on focus completion boundaries and MUST reject fragmentary progress below the minimum effective threshold.

#### Scenario: Focus completion grants XP
- **WHEN** a focus phase completes naturally
- **THEN** the system calculates and grants XP for that completion

#### Scenario: Effective focus under 5 minutes grants zero
- **WHEN** effective focus duration is less than 5 minutes
- **THEN** granted XP is 0 for that completion

### Requirement: Apply XP formula and daily cap
The system MUST apply `xpGain = floor(focusMinutes) * 10 * multiplier` with default `multiplier = 1.0`, and MUST enforce a per-day cap of 2000 XP.

#### Scenario: Standard 25-minute focus award
- **WHEN** a 25-minute effective focus completion is processed with default multiplier
- **THEN** the granted XP is 250

#### Scenario: Daily cap reached
- **WHEN** daily accumulated XP has reached 2000
- **THEN** additional XP grants do not increase daily XP beyond 2000

### Requirement: Persist XP and date for rollover accounting
The system MUST persist total XP, daily XP, level, and last accounting date to support restart recovery and day rollover.

#### Scenario: Restore XP state after restart
- **WHEN** the app restarts
- **THEN** total XP, daily XP, level, and last date are restored from local persistence

#### Scenario: New day resets daily bucket
- **WHEN** current date differs from persisted last accounting date
- **THEN** daily XP bucket resets before processing new XP grants

### Requirement: Use fixed level thresholds for LV1-LV10
The system MUST evaluate level-up against the fixed cumulative XP thresholds for LV1-LV10 defined by product rules.

#### Scenario: Crossing threshold upgrades level
- **WHEN** total XP crosses the threshold for the next level
- **THEN** level increases accordingly and emits a single level-up state transition

### Requirement: Strict level-only dialogue unlock gating
Dialogue unlock MUST be determined strictly by level comparison and MUST NOT depend on streaks, tasks, or additional hidden conditions.

#### Scenario: Eligible by level unlocks dialogue
- **WHEN** `currentLevel >= requiredLevel`
- **THEN** dialogue is unlocked

#### Scenario: Ineligible by level remains locked
- **WHEN** `currentLevel < requiredLevel`
- **THEN** dialogue remains locked and returns a readable reason
