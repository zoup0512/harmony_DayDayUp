# apps/harmony — agent notes

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
