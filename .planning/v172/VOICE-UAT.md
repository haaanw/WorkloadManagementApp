# Voice logging — on-device UAT script (v1.7.2, 2026-08-17)

**HAN ruling 2026-08-21: pre-ship device UAT is WAIVED.** This script runs
against the official 1.7.2 App Store build after release. Sections 1–3 and 5
plus the two unchecked §4 items are the post-release checklist.

Device required: on-device speech recognition does not behave in the simulator.
The typed-text path covers the full pipeline in the simulator.
Backend prerequisites (HAN): run `008_parse_quota.sql`, set `DEEPSEEK_API_KEY`,
deploy `parse-workout`. Without the deploy, capture works but every parse fails
into the error state (which is itself worth one test pass).

## 1. Permissions

- [ ] Fresh install → tap the mic in the Log header → speech + mic permission
      prompts appear with the Tuwa usage strings.
- [ ] Deny → inline notice + "Open Settings" button works; typing still works.
- [ ] Re-grant in Settings → mic records.

## 2. Post-workout narrative (LogCaptureSheet)

English, speak naturally:
- [ ] "Bench press three sets of eight at eighty kilos, then squats five by
      five at one hundred. Last set felt like a nine. About forty five minutes."
      → draft: 3×8@80 bench (canonical catalog name), 5×5@100 squat, all sets
      done, duration backdated ≈45 min.
- [ ] "Two warmup sets of ten at the bar, then deadlifts one set of five at
      one forty" → warmup flags on the first two sets.
- [ ] "185 pounds for 5" → 83.9 kg.
- [ ] Speak past 90 seconds continuously → transcript never resets (segment
      stitching); check for doubled/dropped words at ~50s boundaries.
- [ ] Typed path: paste the first narrative as text, no mic → same draft.
- [ ] Keyboard-dictation path: use the iOS keyboard mic into the editor → same.
- [ ] Unknown movement ("Nordic curls three sets of six") → row appears with
      NEW EXERCISE stamp; after save it exists in Movement Bank as custom.
- [ ] Airplane mode → parse fails to the offline error; text stays editable;
      "Log manually" opens a blank session with the transcript in notes.
- [ ] Kill the app mid-narration → reopen sheet → "Resume your last note?"
      restore works.
- [ ] Cancel clears; drafts never auto-save; un-check every set → zero-done
      guard still refuses to save.
- [ ] Saved session: duration, volume, internal load, PR detection all correct
      in SessionDetailView; syncs like a manual session.

zh-Hans (switch app language):
- [ ] "卧推三组，每组八次八十公斤，然后深蹲五组五次一百公斤" → same shape as the
      English narrative; zh UI copy throughout (no raw keys, no uppercase
      transform on zh annotation).
- [ ] "热身两组每组十次，硬拉一组五次一百四十公斤" → warmups flagged.

## 3. Live incremental (VoiceDictationCard in ActiveWorkoutSheet)

- [ ] Start a blank workout → card visible → "bench press eight reps at
      eighty" → entry + one done set appears; light haptic.
- [ ] "same weight" → new done set, same 80 kg, same exercise.
- [ ] "add a set" → duplicates the last done set.
- [ ] "eight reps" (bodyweight) → done set, weight nil/BW.
- [ ] Silence auto-stop: speak, stop talking → recording ends ≈1.5 s later.
- [ ] Typed chip path: type "squat 5 at 100" → set lands without the mic.
- [ ] Gibberish ("purple monkey dishwasher") → fallback chip, text editable,
      never silently dropped.
- [ ] lbs preference athlete: "one eighty five for five" → stored as kg,
      displayed in lb.
- [ ] zh: "八次八十公斤" → set appended; "同样重量" → carry-forward; "再来一组"
      → repeat.
- [ ] Airplane mode + a parser-confident utterance → still lands (local path,
      no network).

## 4. Backend guards (curl, after deploy) — VERIFIED BY CLAUDE 2026-08-18

Function deployed + `DEEPSEEK_API_KEY` set + `008_parse_quota.sql` run 2026-08-18.
Verified with a disposable test user (voice-uat-2026-08-18@tuwa-test.invalid,
id cf47f450 — HAN may delete it in the dashboard; its quota row expires daily):

- [x] No Authorization header → 401.
- [x] Valid JWT, `mode:"plan"` → legacy target_* shape unchanged.
- [x] Valid JWT, `mode:"log"` en fixture → actuals shape; "3 sets of 8" and
      "5x5" both expanded; "last set felt like a nine" → rpe 9 on the final
      squat set only; session_duration_minutes 45; ~6 s latency.
- [x] Valid JWT, `mode:"log"` zh fixture → 卧推 3×8@80 + 深蹲 5×5@100 correct.
- [x] Quota: 429 at exactly the 41st call of the UTC day (default limit 40).
- [ ] In-app quota copy ("Log manually" only) — check during device UAT.
- [ ] Import regression (WorkoutImportSheet text/PDF/photo signed-in) — check
      during device UAT.

## 5. Design fence spot-checks

- [ ] Travertine appears ONLY on the recording dots (live-state law).
- [ ] Annotation stamps (REC / PARSING… / ADDING… / NEW EXERCISE) are Fragment
      Mono ≤12pt, uppercase in en, no case transform in zh.
- [ ] Reduce Motion on → dots static, no pulse.
- [ ] VoiceOver: mic/stop/submit/notices all read sensibly.
