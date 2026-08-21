import SwiftUI
import SwiftData

/// Capture sheet for the voice/text workout-logging feature. Modality-neutral by design: voice
/// and typing feed the SAME editable text (`text`), and either one alone is a complete way to log
/// a session — this is never a voice-only surface. Submitting runs the text through
/// `WorkoutVoiceLogService` and hands the caller a reviewable `ParsedSessionDraft` (Phase C).
///
/// Recording model: while `speech.state == .recording`, `speech.transcript` mirrors live into
/// `text`, appended after whatever the athlete had already typed (`recordingPrefix`, captured
/// at the moment recording starts). On stop, `speech.stop()`'s return value is folded in
/// directly rather than relying on the last mirrored update, so the final text is never a race
/// against the last `onChange`.
///
/// Failure model: the text is NEVER cleared except by a successful parse or an explicit Cancel.
/// A parse failure returns the editor to an editable state with the athlete's own words intact —
/// they can fix "bench press tree sets" by hand and retry, or hand the raw text to the manual
/// logger. Parsing is a convenience over typing, never a gate on logging.
struct LogCaptureSheet: View {
    /// The parsed, reviewable session. The caller presents it in `ActiveWorkoutSheet(parsedSession:)`.
    let onParsed: (WorkoutVoiceLogService.ParsedSessionDraft) -> Void
    /// Raw-text fallback: parsing failed (or is pointless today), so the athlete logs by hand with
    /// their words carried across rather than retyped from memory.
    let onLogManually: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Query private var customExercises: [CustomExercise]

    @State private var speech = SpeechCaptureService()
    @State private var text: String = ""
    /// The athlete's typed text at the moment recording starts — the live transcript is
    /// appended after this, never replacing it.
    @State private var recordingPrefix: String = ""
    @State private var parseState: ParseState = .idle
    /// A prior narration recovered from `UserDefaults` on appear, offered back to the athlete
    /// before they start a fresh one. `nil` once resolved (restored, discarded, or never found).
    @State private var stashedTranscript: String?

    /// `UserDefaults` key for the crash/swipe-dismiss stash (Phase E). Written on every non-blank
    /// edit while the sheet is open, cleared only on the paths that mean the athlete is DONE with
    /// the text (parsed, handed to manual logging, or explicitly cancelled) — never on a plain
    /// `onDisappear`, since that is exactly the path (crash, swipe, app kill) the stash exists to
    /// survive.
    private static let transcriptStashKey = "voice.lastTranscript"

    /// Where the capture stands relative to the parser. Deliberately NOT the speech state: the two
    /// are independent (an athlete can type without ever recording, and a parse failure must leave
    /// the mic usable).
    private enum ParseState {
        case idle
        case parsing
        case failed(WorkoutVoiceLogService.VoiceLogError)
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isRecording: Bool {
        speech.state == .recording
    }

    private var isParsing: Bool {
        if case .parsing = parseState { return true }
        return false
    }

    /// The parse failure currently on screen, if any.
    private var parseFailure: WorkoutVoiceLogService.VoiceLogError? {
        if case .failed(let error) = parseState { return error }
        return nil
    }

    /// Quota is spent for today, so "try again" would fail identically — only the manual route is
    /// offered. Every other failure is worth one more attempt.
    private func isRetryable(_ error: WorkoutVoiceLogService.VoiceLogError) -> Bool {
        if case .quotaExceeded = error { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                InstrumentSheetHeader(title: "voice.capture.navTitle") {
                    SheetHeaderButton(title: "action.cancel") {
                        // Explicit Cancel means the athlete chose to discard these words —
                        // unlike a swipe-dismiss or crash, the stash should not survive this.
                        clearStash()
                        speech.cancel()
                        dismiss()
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        if let stashedTranscript {
                            stashNotice(stashedTranscript)
                        }

                        editor
                        micControl

                        if case .failed(let error) = speech.state {
                            failureNotice(for: error)
                        }

                        if let parseFailure {
                            parseFailureNotice(for: parseFailure)
                        }
                    }
                    .padding(Spacing.sm)
                }
                .background(ColorTokens.background)

                footer
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.sm)
            }
            .background(ColorTokens.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: speech.transcript) { _, newValue in
            guard isRecording else { return }
            text = recordingPrefix.isEmpty ? newValue : recordingPrefix + newValue
        }
        .onChange(of: text) { _, newValue in
            persistStash(newValue)
        }
        .onAppear {
            offerStashIfNeeded()
        }
        .onDisappear {
            // NOT a stash-clearing path: a swipe-dismiss or backgrounding lands here too, and
            // the stash exists precisely to survive it. Only Cancel, manual handoff, and a
            // successful parse clear it.
            speech.cancel()
        }
    }

    // MARK: - Footer

    /// The one ink-filled pill per screen — EXCEPT after a parse failure, where it steps aside for
    /// the equal-weight decision row (retry vs log by hand). The two are never on screen together,
    /// so the CTA Law holds and neither recovery route is nudged (nocebo guard).
    @ViewBuilder
    private var footer: some View {
        if let parseFailure {
            KeyRow(recoveryKeys(for: parseFailure))
        } else {
            PrimaryActionButton(
                title: "voice.capture.submit",
                isLoading: isParsing,
                isDisabled: trimmedText.isEmpty
            ) {
                Task { await submit() }
            }
            .accessibilityIdentifier("logCapture.submit")
        }
    }

    /// Equal-weight butted cells: identical size, type, fill, and press treatment. `.quotaExceeded`
    /// drops the retry cell entirely rather than offering an action that provably cannot succeed.
    private func recoveryKeys(for error: WorkoutVoiceLogService.VoiceLogError) -> [KeyRow.Key] {
        var keys: [KeyRow.Key] = []
        if isRetryable(error) {
            keys.append(
                KeyRow.Key(
                    title: "voice.capture.retry",
                    accessibilityID: "logCapture.retry"
                ) {
                    Task { await submit() }
                }
            )
        }
        keys.append(
            KeyRow.Key(
                title: "voice.capture.logManually",
                accessibilityID: "logCapture.logManually"
            ) {
                // The words are handed off, not lost — but the crash-stash's job ends here.
                clearStash()
                speech.cancel()
                dismiss()
                onLogManually(text)
            }
        )
        return keys
    }

    // MARK: - Editor

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(Spacing.xs)
                // Read-only while the mic owns the text and while the parser reads it — but the
                // words stay fully visible in both states, never hidden behind a spinner.
                .disabled(isRecording || isParsing)
                .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(ColorTokens.divider, lineWidth: 0.5)
                )
                .accessibilityIdentifier("logCapture.editor")
                .accessibilityLabel(Text("voice.capture.editor.a11y"))
                // The overlay Text below already stands in for a native placeholder; mirror it
                // as a hint while it's showing so VoiceOver still hears it once, on the editor
                // itself, rather than as a second (and unfocusable) floating element.
                .accessibilityHint(text.isEmpty ? Text("voice.capture.placeholder") : Text(verbatim: ""))

            if text.isEmpty {
                Text("voice.capture.placeholder")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xs)
                    .allowsHitTesting(false)
                    // Decorative relative to the editor above: its content is already offered
                    // as the editor's accessibility hint, so it must not appear a second time
                    // as its own VoiceOver stop.
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Mic control

    private var micControl: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                Task { await toggleRecording() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    micIcon
                    Text(isRecording ? "voice.capture.mic.stop" : "voice.capture.mic.start")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                )
            }
            .buttonStyle(.pressable)
            .disabled(speech.state == .requestingPermission || isParsing)
            .accessibilityIdentifier("logCapture.mic")
            .accessibilityLabel(isRecording ? Text("voice.capture.mic.stop.a11y") : Text("voice.capture.mic.start.a11y"))

            // One stamp slot, one state at a time: the recording clock while the mic runs, the
            // parse stamp while the parser reads. Both are machine marginalia (v6).
            if isRecording {
                AnnotationLabel(recordingStamp, color: ColorTokens.text2)
                    .accessibilityLabel(recordingStampAccessibilityLabel)
            } else if isParsing {
                AnnotationLabel(parsingStamp, color: ColorTokens.text2)
                    .accessibilityIdentifier("logCapture.parsing")
                    .accessibilityLabel(Text("voice.capture.parsing.a11y"))
            }
        }
    }

    @ViewBuilder
    private var micIcon: some View {
        switch speech.state {
        case .requestingPermission:
            ProgressView()
                .tint(ColorTokens.text2)
        case .recording:
            // The live-recording dot — accent's sanctioned live-state territory (DESIGN.md
            // v6 Reading Color Rule). Scale rides the smoothed audio level; reduceMotion
            // pins the scale flat so the mark is a static live indicator, not a pulse.
            Circle()
                .fill(ColorTokens.accent)
                .frame(width: 10, height: 10)
                .scaleEffect(reduceMotion ? 1 : 1 + CGFloat(min(speech.audioLevel, 1)) * 0.6)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: speech.audioLevel)
                // Decorative: the mic button already carries the recording state in its own
                // accessibility label, so the dot itself must not read as its own element.
                .accessibilityHidden(true)
            Image(systemName: "stop.fill")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        default:
            Image(systemName: "mic")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        }
    }

    /// "REC MM:SS" — the annotation-voice recording stamp. The clock digits are universal and
    /// unlocalized by design (same idiom as the RPE/volume annotations elsewhere); only the
    /// surrounding word is a catalog key.
    private var recordingStamp: String {
        let totalSeconds = Int(speech.elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let clock = String(format: "%02d:%02d", minutes, seconds)
        return String(format: String(localized: "voice.capture.recording"), clock)
    }

    /// The clean-sentence VoiceOver reading of `recordingStamp` — no "REC" abbreviation, no
    /// mono/uppercase presentation, just the clock spoken plainly.
    private var recordingStampAccessibilityLabel: Text {
        let totalSeconds = Int(speech.elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let clock = String(format: "%02d:%02d", minutes, seconds)
        return Text(String(format: String(localized: "voice.capture.recording.a11y"), clock))
    }

    /// The working stamp shown while the parser reads the text — the annotation voice takes the
    /// uppercase transform, so the catalog value stays sentence case.
    private var parsingStamp: String {
        LocalePinnedStrings.localized(
            "voice.capture.parsing",
            defaultValue: "Parsing…",
            locale: locale
        )
    }

    // MARK: - Failure notice

    /// Inline failure notice. `CaptureError.errorDescription` (defined on `SpeechCaptureService`
    /// itself) supplies the localized message, so this view owns no duplicate error copy.
    /// Typing keeps working through any of these — voice is one input among several, never
    /// a gate on logging.
    private func failureNotice(for error: SpeechCaptureService.CaptureError) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let message = error.errorDescription {
                Text(message)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            if error == .permissionDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("action.openSettings")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
    }

    /// Inline parse-failure notice. The message comes from `VoiceLogError.errorDescription`, which
    /// lives on the service, so this view owns no duplicate error copy. The recovery actions are in
    /// the footer's equal-weight row, not here — one decision surface per screen.
    @ViewBuilder
    private func parseFailureNotice(for error: WorkoutVoiceLogService.VoiceLogError) -> some View {
        if let message = error.errorDescription {
            Text(message)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
                .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
                .accessibilityIdentifier("logCapture.parseFailure")
        }
    }

    // MARK: - Crash stash

    /// Inline "resume your last note?" notice. Shown only once, on appear, when the editor is
    /// otherwise empty — never while the athlete is mid-edit, so it can't clobber fresh words.
    /// Same card-plane pattern as `failureNotice`/`parseFailureNotice` above.
    private func stashNotice(_ stashed: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("voice.stash.title")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                Text(stashed)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            // One VoiceOver stop for the message — the two texts are one sentence split
            // across lines, not two independent facts.
            .accessibilityElement(children: .combine)

            KeyRow([
                KeyRow.Key(
                    title: "voice.stash.restore",
                    accessibilityID: "logCapture.stash.restore"
                ) {
                    text = stashed
                    stashedTranscript = nil
                },
                KeyRow.Key(
                    title: "voice.stash.discard",
                    accessibilityID: "logCapture.stash.discard"
                ) {
                    clearStash()
                    stashedTranscript = nil
                }
            ])
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
        .accessibilityIdentifier("logCapture.stashNotice")
    }

    /// Checked once on appear: an empty editor plus a non-blank stash means the last sheet
    /// never reached a clearing path (crash, swipe, app kill) — offer it back rather than
    /// silently discarding the athlete's words.
    private func offerStashIfNeeded() {
        guard trimmedText.isEmpty else { return }
        guard let stashed = UserDefaults.standard.string(forKey: Self.transcriptStashKey) else { return }
        guard !stashed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        stashedTranscript = stashed
    }

    /// Persists the live editor text so a crash, swipe-dismiss, or app kill never loses it. A
    /// tiny string write on every keystroke needs no debounce timer.
    private func persistStash(_ newValue: String) {
        guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        UserDefaults.standard.set(newValue, forKey: Self.transcriptStashKey)
    }

    private func clearStash() {
        UserDefaults.standard.removeObject(forKey: Self.transcriptStashKey)
    }

    // MARK: - Parsing

    /// Submit the captured text for parsing. Stops any live recording first so the final transcript
    /// is folded in before the text is read, then hands the caller a reviewable draft.
    @MainActor
    private func submit() async {
        // Stop rather than cancel: `stop()`'s return value carries the last recognized words, so
        // submitting mid-recording can never drop the tail of what the athlete just said.
        let captured = isRecording ? stopRecording() : text
        guard !captured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        parseState = .parsing
        do {
            let response = try await WorkoutVoiceLogService.parseLoggedWorkoutText(
                captured,
                client: container.supabase
            )
            let draft = mapToDraft(response, transcript: captured)
            parseState = .idle
            // Handoff succeeded — the words now live in the draft, so the stash has nothing
            // left to protect.
            clearStash()
            dismiss()
            onParsed(draft)
        } catch let error as WorkoutVoiceLogService.VoiceLogError {
            parseState = .failed(error)
        } catch {
            parseState = .failed(.parseFailed(error.localizedDescription))
        }
    }

    /// The ONE call site of the service's mapping step, isolated so the resolution inputs (catalog +
    /// the athlete's customs) are named in a single place. `ExerciseDatabase.all` is the same pool the
    /// picker resolves against: legacy curated names first, then the bundled catalog, so a parsed name
    /// binds to the identity history and PRs already use.
    private func mapToDraft(
        _ response: WorkoutVoiceLogService.ParsedLoggedWorkoutResponse,
        transcript: String
    ) -> WorkoutVoiceLogService.ParsedSessionDraft {
        WorkoutVoiceLogService.mapToParsedSessionDraft(
            response,
            transcript: transcript,
            catalogExercises: ExerciseDatabase.all,
            customExercises: customExercises
        )
    }

    // MARK: - Recording control

    private func toggleRecording() async {
        if isRecording {
            stopRecording()
            return
        }

        let granted = await speech.requestAuthorization()
        guard granted else { return }
        // A new take supersedes the previous parse attempt: clear the failure so the recovery row
        // steps aside for the submit pill again. The text itself is untouched.
        parseState = .idle
        recordingPrefix = text.isEmpty ? "" : text + " "
        speech.start(localeIdentifier: container.localeManager.activeLocale.identifier)
    }

    /// Stop the recognizer and fold its FINAL transcript into `text` (never the last mirrored
    /// `onChange` value, which can lag the tail). Returns the resulting text so a caller that needs
    /// it in the same turn — `submit()` — does not have to read `@State` back.
    @discardableResult
    private func stopRecording() -> String {
        let finalText = speech.stop()
        let combined = recordingPrefix.isEmpty ? finalText : recordingPrefix + finalText
        text = combined
        recordingPrefix = ""
        return combined
    }
}
