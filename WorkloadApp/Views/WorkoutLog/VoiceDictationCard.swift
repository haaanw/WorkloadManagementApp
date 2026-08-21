import SwiftUI

/// What the host sheet did with one utterance. The card is deliberately DUMB about logging: it
/// hands back a final string and renders whichever of these two answers it gets. All matching,
/// resolution, and mutation live in `ActiveWorkoutSheet` — the card owns the microphone and the
/// surface, nothing else.
enum UtteranceOutcome: Equatable {
    /// A set (or a new exercise) landed in the session; the name is echoed back for the stamp.
    case added(exerciseName: String)
    /// The words could not be turned into a set. The card keeps them in an editable chip —
    /// an utterance is NEVER silently discarded.
    case needsFallbackChip
}

/// Live incremental voice logging, inline (Phase D).
///
/// Not a sheet: the session list stays visible behind it, because the whole point is logging a set
/// the moment it ends and SEEING it appear. One tap starts listening; 1.5s of silence stops it;
/// the utterance goes to the host, which appends a set. Typing is always available beside the mic
/// (modality-neutral law — voice is one input among several, never a gate on logging).
///
/// Speech ownership follows `SpeechCaptureService`'s documented rule: a fresh instance per surface,
/// torn down with `cancel()` on disappear. Never shared, never a singleton.
/// Main-actor isolated as a whole (not just `body`): the ingest `Task` writes `@State` after an
/// `await`, and only a statically isolated enclosing method makes that continuation resume on the
/// main actor rather than a generic executor.
@MainActor
struct VoiceDictationCard: View {
    /// Hands the host a FINAL utterance and awaits its verdict. Async because the host may fall
    /// back to the LLM parser for anything the local grammar cannot read.
    let onUtterance: (String) async -> UtteranceOutcome

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    @State private var speech = SpeechCaptureService()
    @State private var phase: Phase = .collapsed
    /// The typed path's field. Independent of `fallbackText` so a failed voice utterance never
    /// overwrites something the athlete was in the middle of typing.
    @State private var typedText = ""
    /// The utterance held for repair after a failed ingest — editable, never discarded for them.
    @State private var fallbackText = ""
    /// The last exercise a successful ingest touched, echoed as a stamp so the athlete gets
    /// confirmation even when the appended set scrolled out of view.
    @State private var lastAdded: String?
    @FocusState private var isTypingFocused: Bool

    /// The card's own state machine. Deliberately NOT the speech state: typing never touches the
    /// mic, and a failed ingest must leave the mic usable.
    private enum Phase: Equatable {
        case collapsed
        case typing
        case recording
        /// Carries the final utterance so it stays on screen while the host works on it.
        case resolving(String)
        /// The repair chip. The words themselves live in `fallbackText` (editable).
        case unparsed
    }

    /// Silence that ends an utterance. Long enough to survive the pause between "eighty kilos"
    /// and "for five", short enough that the set lands before the athlete puts the phone down.
    private static let silenceTimeout: TimeInterval = 1.5

    private var trimmedTyped: String {
        typedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            switch phase {
            case .collapsed:
                collapsedRow
            case .typing:
                typingRow
            case .recording:
                recordingRow
            case .resolving(let utterance):
                resolvingRow(utterance)
            case .unparsed:
                fallbackChip
            }

            if case .failed(let error) = speech.state {
                failureNotice(for: error)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: phase)
        .accessibilityIdentifier("activeWorkout.voiceDictation")
        // Silence auto-stop rides the service's OWN 0.5s elapsed tick rather than a second timer
        // this view would have to own and invalidate — one less timer to leak on disappear.
        .onChange(of: speech.elapsed) { _, _ in
            checkSilenceTimeout()
        }
        // The recognizer can fail mid-take (recognizer withdrawn, audio session lost). Return the
        // card to its resting state so the failure notice below is the only thing to read.
        .onChange(of: speech.state) { _, newValue in
            guard case .failed = newValue, phase == .recording else { return }
            phase = .collapsed
        }
        // Dismissing the keyboard with nothing typed is a "never mind" — return the card to its
        // one-tap resting state instead of stranding an empty field on the session.
        .onChange(of: isTypingFocused) { _, isFocused in
            guard !isFocused, phase == .typing, trimmedTyped.isEmpty else { return }
            phase = .collapsed
        }
        .onDisappear {
            speech.cancel()
        }
    }

    // MARK: - Collapsed

    /// One tap to talk, one tap to type — the two are siblings, never nested buttons, so each
    /// keeps its own hit area and press feedback.
    private var collapsedRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Button {
                    Haptics.tap()
                    Task { await beginRecording() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "mic")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Text(promptLabel)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                .disabled(speech.state == .requestingPermission)
                .accessibilityIdentifier("activeWorkout.voiceDictation.record")
                .accessibilityLabel(recordButtonAccessibilityLabel)

                Button {
                    Haptics.tap()
                    phase = .typing
                    isTypingFocused = true
                } label: {
                    Text(typeLabel)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.baselinePair)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("activeWorkout.voiceDictation.type")
                .accessibilityLabel(typeButtonAccessibilityLabel)
            }

            // A machine receipt for the last thing that landed — marginalia, not a sentence.
            if let lastAdded {
                AnnotationLabel("\(loggedStamp) · \(lastAdded)", color: ColorTokens.text2)
                    .annotationReveal()
            }
        }
    }

    // MARK: - Typing

    /// The typed path. Same destination as the spoken one: whatever is in the field goes through
    /// the identical ingest pipeline, so a parser improvement helps both inputs at once.
    private var typingRow: some View {
        HStack(spacing: Spacing.xs) {
            TextField(typePlaceholder, text: $typedText)
                .textFieldStyle(SharpTextFieldStyle())
                .focused($isTypingFocused)
                .submitLabel(.done)
                .onSubmit { submit(typedText) }
                .accessibilityIdentifier("activeWorkout.voiceDictation.field")

            Button {
                submit(typedText)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.Tokens.body)
                    .foregroundStyle(trimmedTyped.isEmpty ? ColorTokens.text3 : ColorTokens.text1)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .disabled(trimmedTyped.isEmpty)
            .accessibilityLabel(submitLabel)
            .accessibilityIdentifier("activeWorkout.voiceDictation.submit")
        }
    }

    // MARK: - Recording

    /// Tap anywhere on the row to stop early; otherwise silence ends it. The live partial reads
    /// head-truncated so the WORDS JUST SPOKEN stay visible as the transcript grows.
    private var recordingRow: some View {
        Button {
            stopAndSubmit()
        } label: {
            HStack(spacing: Spacing.xs) {
                // The live-recording dot — accent's sanctioned live-state territory (DESIGN.md v6
                // Reading Color Rule). Scale rides the smoothed audio level; reduceMotion pins it
                // flat so the mark stays a static live indicator rather than a pulse.
                Circle()
                    .fill(ColorTokens.accent)
                    .frame(width: 10, height: 10)
                    .scaleEffect(reduceMotion ? 1 : 1 + CGFloat(min(speech.audioLevel, 1)) * 0.6)
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: speech.audioLevel)
                    // Decorative: the row's own accessibilityLabel below already names the
                    // recording state, so the dot must not read as its own element.
                    .accessibilityHidden(true)

                Text(livePartial)
                    .font(.Tokens.label)
                    .foregroundStyle(speech.transcript.isEmpty ? ColorTokens.text3 : ColorTokens.text1)
                    .lineLimit(1)
                    .truncationMode(.head)

                Spacer(minLength: 0)

                Image(systemName: "stop.fill")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
        .accessibilityLabel(stopLabel)
        .accessibilityIdentifier("activeWorkout.voiceDictation.stop")
    }

    // MARK: - Resolving

    /// The words stay on screen while the host works on them — never a bare spinner, because if
    /// the ingest fails the athlete must recognize what they said in the repair chip.
    private func resolvingRow(_ utterance: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            Text(utterance)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
                .lineLimit(2)
            AnnotationLabel(addingStamp, color: ColorTokens.text2)
                .accessibilityLabel(addingStampAccessibilityLabel)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        // One VoiceOver stop: the utterance and its "adding" stamp are one status, not two
        // independent facts — same idiom as the notices' message blocks.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("activeWorkout.voiceDictation.resolving")
    }

    // MARK: - Fallback chip

    /// The repair surface. Two equal-weight butted cells (nocebo guard): retry the same words,
    /// or drop them. No ink-filled pill here — neither route is nudged.
    private var fallbackChip: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(unparsedNotice)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)

            TextField("", text: $fallbackText)
                .textFieldStyle(SharpTextFieldStyle())
                .accessibilityIdentifier("activeWorkout.voiceDictation.fallback")
                // The visible field has no placeholder (it always opens pre-filled with the
                // words that failed to parse) — but VoiceOver still needs a label of its own.
                .accessibilityLabel(fallbackFieldAccessibilityLabel)

            KeyRow([
                KeyRow.Key(
                    title: "voice.capture.retry",
                    accessibilityID: "activeWorkout.voiceDictation.retry"
                ) {
                    submit(fallbackText)
                },
                KeyRow.Key(
                    title: "action.cancel",
                    accessibilityID: "activeWorkout.voiceDictation.dismiss"
                ) {
                    fallbackText = ""
                    phase = .collapsed
                }
            ])
        }
    }

    // MARK: - Failure notice

    /// Inline permission/recognizer notice, mirroring `LogCaptureSheet`'s pattern. The message
    /// comes from `CaptureError.errorDescription` on the service, so this view owns no duplicate
    /// error copy. Typing keeps working through every one of these states.
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
        .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.divider, lineWidth: 0.5))
        .accessibilityIdentifier("activeWorkout.voiceDictation.failure")
    }

    // MARK: - Capture control

    /// One tap = authorize + listen. Authorization failures leave `speech.state == .failed`, which
    /// the notice above reads; the card stays collapsed so typing is still one tap away.
    private func beginRecording() async {
        lastAdded = nil
        let granted = await speech.requestAuthorization()
        guard granted else { return }
        speech.start(localeIdentifier: container.localeManager.activeLocale.identifier)
        guard speech.state == .recording else { return }
        phase = .recording
    }

    /// Stop rather than cancel: `stop()`'s return value carries the last recognized words, so the
    /// tail of the utterance is never a race against the final partial-result callback.
    private func stopAndSubmit() {
        let captured = speech.stop()
        submit(captured)
    }

    /// End the take once `silenceTimeout` has passed with no new partial result. `lastSpeechAt`
    /// stays nil until the recognizer hears something, so a take that opens in silence waits
    /// indefinitely instead of closing on itself before the athlete speaks.
    private func checkSilenceTimeout() {
        guard phase == .recording, speech.state == .recording else { return }
        guard let lastSpeechAt = speech.lastSpeechAt else { return }
        guard Date.now.timeIntervalSince(lastSpeechAt) >= Self.silenceTimeout else { return }
        stopAndSubmit()
    }

    // MARK: - Ingest

    /// Hand one utterance to the host and render its verdict. The words survive every branch:
    /// a failure lands them in the editable chip rather than dropping them on the floor.
    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .collapsed
            return
        }
        isTypingFocused = false
        fallbackText = trimmed
        phase = .resolving(trimmed)

        Task {
            let outcome = await onUtterance(trimmed)
            switch outcome {
            case .added(let exerciseName):
                lastAdded = exerciseName
                typedText = ""
                fallbackText = ""
                phase = .collapsed
            case .needsFallbackChip:
                phase = .unparsed
            }
        }
    }

    // MARK: - Copy

    private var promptLabel: String {
        LocalePinnedStrings.localized(
            "voice.dictation.prompt",
            defaultValue: "Log by voice",
            locale: locale
        )
    }

    private var typeLabel: String {
        LocalePinnedStrings.localized(
            "voice.dictation.type",
            defaultValue: "Type",
            locale: locale
        )
    }

    private var typePlaceholder: String {
        LocalePinnedStrings.localized(
            "voice.dictation.typePlaceholder",
            defaultValue: "Bench press 80 for 5",
            locale: locale
        )
    }

    private var submitLabel: String {
        LocalePinnedStrings.localized(
            "voice.dictation.submit",
            defaultValue: "Add set",
            locale: locale
        )
    }

    private var stopLabel: String {
        LocalePinnedStrings.localized(
            "voice.dictation.stop",
            defaultValue: "Stop listening",
            locale: locale
        )
    }

    private var livePartial: String {
        speech.transcript.isEmpty
            ? LocalePinnedStrings.localized(
                "voice.dictation.listening",
                defaultValue: "Listening…",
                locale: locale
            )
            : speech.transcript
    }

    /// Machine stamps — the annotation voice applies the uppercase transform, so the catalog
    /// values stay sentence case (and zh-Hans takes no transform at all).
    private var addingStamp: String {
        LocalePinnedStrings.localized(
            "voice.dictation.adding",
            defaultValue: "Adding…",
            locale: locale
        )
    }

    private var loggedStamp: String {
        LocalePinnedStrings.localized(
            "voice.dictation.logged",
            defaultValue: "Logged",
            locale: locale
        )
    }

    private var unparsedNotice: String {
        LocalePinnedStrings.localized(
            "voice.dictation.unparsed",
            defaultValue: "Couldn't read that as a set. Fix the words and try again.",
            locale: locale
        )
    }

    // MARK: - VoiceOver copy

    /// The record button's visible label (`promptLabel`, "Log by voice") already names the
    /// modality; this spells out the object as well, matching `LogCaptureSheet`'s mic button.
    private var recordButtonAccessibilityLabel: String {
        LocalePinnedStrings.localized(
            "voice.dictation.record.a11y",
            defaultValue: "Record workout by voice",
            locale: locale
        )
    }

    private var typeButtonAccessibilityLabel: String {
        LocalePinnedStrings.localized(
            "voice.dictation.type.a11y",
            defaultValue: "Type a set instead of speaking",
            locale: locale
        )
    }

    /// The clean-sentence VoiceOver reading of `addingStamp` — no mono/uppercase presentation.
    private var addingStampAccessibilityLabel: String {
        LocalePinnedStrings.localized(
            "voice.dictation.adding.a11y",
            defaultValue: "Adding your set",
            locale: locale
        )
    }

    private var fallbackFieldAccessibilityLabel: String {
        LocalePinnedStrings.localized(
            "voice.dictation.fallback.a11y",
            defaultValue: "Edit the words you said",
            locale: locale
        )
    }
}
