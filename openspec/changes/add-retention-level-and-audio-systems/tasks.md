## 1. Parallel change setup and dependency check

- [x] 1.1 Confirm `improve-pomodoro-functionality` provides stable `pomodoroState`, `phaseStatus`, and phase-completion flow before wiring extensions
- [x] 1.2 Add capability specs for supervisor notifications, XP/level unlock, and global music/SFX under this change only
- [x] 1.3 Keep existing pomodoro-core tasks untouched to preserve rollback clarity
- [x] 1.4 Freeze extension hooks in controller: lifecycle event hook, focus-completion hook, and startup hook

## 2. Background supervisor notifications (3m/6m)

- [x] 2.1 Add lifecycle observer wiring so controller receives app foreground/background transitions
- [x] 2.2 Create a background-session model and schedule stage notifications at +180s and +360s
- [x] 2.3 Enforce session limits: max two notifications per session, no duplicate stage triggers
- [x] 2.4 Cancel pending supervisor notifications on foreground return, pause, reset, or phase exit from studying/running
- [x] 2.5 Add graceful permission-denied handling and non-blocking logging
- [x] 2.6 Add notification payload contract to distinguish `3m` and `6m` stage in logs/analytics

## 3. Focus XP, level, and strict dialogue unlock

- [x] 3.1 Add XP/level state holders and persistence keys in controller
- [x] 3.2 Grant XP on focus completion only, with min effective threshold (<5 min => 0 XP)
- [x] 3.3 Enforce daily XP cap of 2000 and handle day rollover by saved date key
- [x] 3.4 Implement LV1-LV10 threshold mapping and level-up detection without duplicate emits
- [x] 3.5 Implement `canUnlockDialogue(requiredLevel)` with strict level-only gating
- [x] 3.6 Return standardized lock reason for insufficient level (for UI copy reuse)

## 4. Global background music and phase SFX

- [x] 4.1 Introduce audio playback integration suitable for BGM and short SFX
- [x] 4.2 Auto-play BGM after app initialization regardless of pomodoro phase
- [x] 4.3 Persist manual override state (`isPlaying`, `autoPlayEnabled`, track, volume)
- [x] 4.4 Trigger phase SFX on start and phase transitions defined in spec
- [x] 4.5 Ensure audio failures degrade silently and do not block timer transitions
- [x] 4.6 Define BGM and SFX coexistence behavior to avoid unintended playback interruption

## 5. UI contract alignment

- [x] 5.1 Bind music controls to controller methods/notifiers instead of UI-local playback booleans
- [x] 5.2 Keep pomodoro control rendering consistent with existing phase-state contracts
- [x] 5.3 Surface dialogue lock reason text from strict level gating
- [x] 5.4 Ensure app startup path waits for controller initialization before applying autoplay state

## 6. Verification

- [x] 6.1 Add targeted tests for 3m/6m background notifications and cancellation paths
- [x] 6.2 Add targeted tests for XP grant formula, daily cap, day rollover, and level upgrades
- [x] 6.3 Add targeted tests for strict level unlock behavior and rejection cases
- [x] 6.4 Add targeted tests for BGM autoplay, manual override persistence, and phase SFX triggers
- [x] 6.5 Run `flutter analyze` and `flutter test`
- [ ] 6.6 Run manual Android verification for lifecycle transitions, notifications, and audio behavior
- [ ] 6.7 Verify extension rollback does not affect existing pomodoro core behavior
