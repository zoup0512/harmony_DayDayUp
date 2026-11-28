# harmony_DayDayUp (apps/harmony/harmony_DayDayUp) — agent notes

## Build / verify
- `scripts/build.sh` — assembleHap via bundled hvigor (DevEco at
  `C:\Program Files\Huawei\DevEco Studio`; no hvigor/ohpm on PATH — the script
  exports `DEVECO_SDK_HOME` + PATH itself).
- `scripts/errors.sh` — build + grep only `ERROR`/`Error Message` lines.
  ArkTS warnings ("Function may throw exceptions") are noise; chase `ERROR` first.
- No rg on PATH — use `grep -rn` / `find` / the read tools.
- iOS reference: `apps/mobile/ChinaTextbookStudy/**` (Domain/Models/Services/
  Stores/Features/Components/DesignSystem mirrors this tree 1:1).

## ArkTS/ArkUI gotchas discovered (don't relearn)
- Reserved @Param/@Local names (they're base CustomComponent attrs): `size`,
  `width`, `background`, `enabled`, `borderColor`, `outline`, `fill`, `scale`,
  `position`, `opacity`, `onClick` → rename (we use `sz`, `bgColor`, `active`,
  `stroke`, `outlineData`…).
- `build()`/`@Builder` bodies accept ONLY UI syntax: no const/let statements,
  no plain function calls. Compute in getters/methods; UI slots via
  `@BuilderParam`; a lambda slot must itself be a UI-producing fn.
- `import` must precede all statements (arkts-no-misplaced-imports).
- Explicit return types required (`arkts-no-implicit-return-types`) — including
  arrow consts inside functions: `(x): void => {...}`.
- `bigint` works (`U64_MASK` etc); `@ObservedV2`+`@Trace`+`@Local`+`@Monitor`+`@Param`+`@Event`+`@BuilderParam` work (V2 state).
- SymbolGlyph `$r('sys.symbol.*')` covers most SF-Symbol equivalents; custom
  SVGs live in `resources/base/media/ic_*.svg`.
- Form cards: `src: "./ets/widget/pages/X.ets"` (NOT `pages/X`); card UI is a
  plain `@Component` (V1) with `@LocalStorageProp` — no V2 decorators in cards.
- `ohos.permission.NOTIFICATION` is NOT a requestable permission (removed) —
  user consent is `notificationManager.requestEnableNotification()` at runtime.
  Valid perms used: INTERNET, VIBRATE, MICROPHONE(+reason).

## Port invariants (match iOS / packages/core — don't drift)
- Economy: hearts 5 / 300s regen / 350 gems refill; freezes 2 / 200 gems;
  makeup 50; dailyGoal default 50; lesson XP 10/correct +5 perfect +5 firstPerfect
  ×2 weekend ×2 exam; gem drip 3/5/10/15/20; review ≥5 correct → +1 heart.
- Jump test: 15 questions, ≥0.8 accuracy, seeded (`Jump.sampleQuestions`).
- League: 16 entries, 5/5 promote/demote, deterministic via `League.*(weekKey,tier,salt)`.
- Backup: `BackupEnvelope` schema v1, `platform:'harmony'`; `validateBackup` +
  `userProgressFromEnvelope` normalize iOS/web shapes.
- Reading ids go through `readingId()/normalizeReadingId()` — kinds
  'listen' | 'followup' | 'story'.
- Lesson session resume: `ActiveLessonSession` + `lessonContentKey()` (sha256 of
  lesson minus audio) — stale sessions are dropped, not resumed.

## Kids mode (Harmony-only, intentional deviation — `SettingsStore.kidsMode`, default ON)
- Rules live in `domain/KidsMode.ets` (pure); reference design:
  `D:\workspace\My\harmony\DayDayUp\docs\DESIGN.md` §2/§5.2/§5.4/§8.
- No hearts lost (lesson + jump test). Wrong non-stretch questions → demons;
  `completeLesson(..., extras)` seals that lesson's gem drip + knowledge card into
  a `SealedChest` (XP still immediate). `RemedyPage`: correct original + `need`
  variants (start 2, +1 per miss, cap 5; help modal after 3 misses in a row);
  `unsealChest` returns gems + 2/demon bonus + card. Chests expire after 3 days.
- Slots (non-exam, ≥4 questions): stretch = hardest (wrong ≠ demon), speed =
  easiest choice/TF, 15 s, in-time correct = +xpPerCorrect bonus XP.
- Knowledge cards: one per lesson, tier = stars (only upgrades), exams have none;
  unit guardian unlocks when the unit is fully collected (derived, not stored).
- With kids mode OFF the economy is the iOS one, except cards are still granted.
- `sealedChests` / `knowledgeCards` are NOT in BackupEnvelope v1; `importBackup`
  keeps the local ones.

## Multi-child profiles (mirrors Web `lib/learnerProfiles.ts` / `lib/family.ts`)
- `stores/LearnerStore.ets`: `cstf/learners.json` = `{version, activeId, learners[]}`. The
  `default` child keeps the legacy `cstf/progress.json` + `cstf/prefs.json` (zero migration;
  learners.json is only written on the first change); others live in `cstf/learners/<id>/`.
- Child name = learner name (`ProgressStore.displayName` reads LearnerStore; `progress.displayName`
  is only a mirror). Names ≤ 20 chars like Web.
- `ProgressStore.shared` always follows the active child; `ProgressStore.forLearner(id)` gives a
  separate instance for another child (returns `shared` for the active one — never two writers).
  Only `shared` pushes the widget snapshot.
- Switching = `Family.switchTo(id)` (stop audio, clear Router, `ProgressStore.shared.switchTo`);
  Index resets tab/overlays when `LearnerStore.activeId` changes.
- Cold start with >1 child: `LearnerStore.pickerAuto` → `LearnerPicker` overlay; `refreshForNow`
  is skipped until a child is picked (it credits the daily login gems).
- SettingsStore stays family-level (sound, appearance, reminders, kids mode).
- Parent PIN: `services/ParentLock.ets` (salted sha256 in `cstf_settings` key `cstf.parentLock`,
  10-min in-process unlock, adult-math "forgot PIN"). Guarded: child management, import, reset,
  kids-mode toggle, parent overview, optional child switching.
- Backup: optional top-level `learner` + `cstf-family-backup` (`validateAnyBackup`,
  `makeFamilyEnvelope`); keep in sync with `packages/core/src/backup.ts`.
- Pages that host a gate keep `gateReason` + `gateAction` and render `ParentGate`; subscribe to
  `LearnerStore.onChange` anywhere child names/counts are shown.

## Device testing via hdc (wireless device in use)
- hdc: `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`;
  install `hdc install -r entry/build/default/outputs/default/entry-default-signed.hap`,
  launch `hdc shell aa start -a EntryAbility -b org.chinatextbook.study`.
- App sandbox (debug build): `/data/app/el2/100/base/org.chinatextbook.study/haps/entry/files/cstf/`
  (readable with `hdc shell cat`). Back it up before testing on the real device.
- Drive UI with `uitest dumpLayout` + `uitest uiInput click/inputText`; `accessibilityText` and
  TextInput placeholders are NOT in the dump (find inputs by `type`, swatches by bounds).
- Screenshots go black while a password TextInput is focused (secure input) — assert via dump.
- Git Bash mangles device paths in `hdc file send` → prefix with `MSYS_NO_PATHCONV=1`.
- Setting a TextInput's bound text programmatically fires `onChange` — don't clear error
  messages there unconditionally.

## Repo hygiene
- Standalone repo; parent congcong-school ignores `apps/harmony/`.
- `build-profile.json5` is committed WITHOUT signing (`signingConfigs: []`).
  Local copy holds the DevEco auto-sign config and is `git update-index
  --skip-worktree`d — never commit it back. To edit the tracked version:
  `--no-skip-worktree`, edit, strip signing, commit, re-skip.
- Real-device screenshots / UI dumps (`/*.jpeg`, `/lay*.json`) are gitignored.
- `harmony_push.bat` never stores the token in `.git/config` (one-shot
  `http.extraheader`); remote URL must stay credential-free.

## UI state conventions (real-device findings)
- Components refresh via `ProgressStore.onChange` / `Router.onChange` /
  `SettingsStore.onChange`; each returns an unsubscribe fn — store it and call
  it in `aboutToDisappear` (dead listeners leak and re-run rebuilds).
- System back: `Index.onBackPress` → `Router.handleBack()`; pages with modal
  state register `Router.shared.interceptBack(() => boolean)` (true = handled).
- Theme/dark: `Palette.apply()` from `Index.applyPalette()`; on change the whole
  shell re-mounts via `ForEach([themeRev])` because `C.xxx` is read at build time.
