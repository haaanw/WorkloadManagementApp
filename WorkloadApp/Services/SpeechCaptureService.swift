import Speech
import AVFoundation
import Observation

/// Per-sheet, on-device-first speech capture for narrated set logging.
///
/// Ownership: created fresh by the presenting sheet (`@State private var speech =
/// SpeechCaptureService()`) and torn down via `cancel()` on disappear. Never a shared or
/// singleton instance — `SFSpeechRecognizer` recognition tasks and `AVAudioEngine` taps are
/// single-consumer resources, and reusing one across sheets would race teardown against setup.
///
/// STITCHING STRATEGY: a single `SFSpeechAudioBufferRecognitionRequest`/task pair is not safe
/// to run for an entire narrated set — server-assisted recognition is capped around one minute,
/// and on-device recognition is not documented as unbounded either. Rather than let a long
/// narration silently cut off, this service treats each request/task pair as a disposable
/// *segment*: a 50s per-segment timer, a `isFinal` result, or a recognition error each fold the
/// segment's text into `finalizedText` and immediately open a fresh request/task pair. The
/// `AVAudioEngine` and its input tap run continuously across every segment boundary — only the
/// recognition request/task are swapped — so no audio is ever dropped and the transcript shown
/// on screen never resets.
@MainActor
@Observable
final class SpeechCaptureService {

    // MARK: - Public Types

    enum CaptureError: LocalizedError, Equatable {
        /// Mic or speech recognition authorization was denied — UI should link to Settings.
        case permissionDenied
        /// No recognizer exists for the requested locale, or it reports itself unavailable.
        case recognizerUnavailable
        /// The audio session or engine failed to start.
        case audioEngineFailure

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return String(
                    localized: "voice.error.permission",
                    defaultValue: "Microphone or speech access is off. Turn it on in Settings."
                )
            case .recognizerUnavailable:
                return String(
                    localized: "voice.error.recognizer",
                    defaultValue: "Speech recognition isn't available right now."
                )
            case .audioEngineFailure:
                return String(
                    localized: "voice.error.audio",
                    defaultValue: "The microphone couldn't start. Try again."
                )
            }
        }
    }

    enum CaptureState: Equatable {
        case idle
        case requestingPermission
        case recording
        case stopped
        case failed(CaptureError)
    }

    // MARK: - Public State

    private(set) var state: CaptureState = .idle

    /// `finalizedText` (prior segments) joined with the live partial of the current segment.
    private(set) var transcript: String = ""

    /// Smoothed 0...1 RMS level from the input tap, for a live level meter.
    private(set) var audioLevel: Float = 0

    /// Seconds since `start()`, ticked by a 0.5s timer while `state == .recording`.
    private(set) var elapsed: TimeInterval = 0

    /// Timestamp of the most recent partial-transcript update, for silence-timeout UI.
    private(set) var lastSpeechAt: Date?

    // MARK: - Private State

    private var audioEngine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?

    /// The current segment's recognition request. Written only from the main actor (start,
    /// segment rotation, teardown), but read AND called (`.append(_:)`) directly from the
    /// `AVAudioEngine` input tap's real-time audio thread — `append(_:)` is documented safe to
    /// call from any thread. `nonisolated(unsafe)` opts this single property out of actor
    /// isolation checking so the tap closure can touch it without an async hop per buffer
    /// (a hop that would risk reordering audio relative to the recognizer).
    private nonisolated(unsafe) var request: SFSpeechAudioBufferRecognitionRequest?

    private var finalizedText = ""
    private var currentPartial = ""

    /// `nonisolated(unsafe)` (like `request` above) so `deinit` — which is never actor-isolated,
    /// even on a `@MainActor` class — can invalidate them as a defensive backstop if a caller
    /// forgets to call `cancel()`. `Timer.invalidate()` is documented safe from any thread.
    private nonisolated(unsafe) var elapsedTimer: Timer?
    private nonisolated(unsafe) var segmentTimer: Timer?
    private var startDate: Date?

    private static let segmentDuration: TimeInterval = 50
    private static let tapBufferSize: AVAudioFrameCount = 1024

    // MARK: - Init / Deinit

    init() {}

    deinit {
        elapsedTimer?.invalidate()
        segmentTimer?.invalidate()
    }

    // MARK: - Authorization

    /// Chains speech-recognition then microphone authorization. Sets `state = .failed` on
    /// either denial and returns `false`; leaves `state == .idle` on success.
    func requestAuthorization() async -> Bool {
        state = .requestingPermission

        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            state = .failed(.permissionDenied)
            return false
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            state = .failed(.permissionDenied)
            return false
        }

        state = .idle
        return true
    }

    // MARK: - Capture Lifecycle

    /// Starts capture for the given app or full locale identifier. No-op if already recording.
    /// Requires `requestAuthorization()` to have already succeeded; otherwise fails immediately
    /// with `.permissionDenied` rather than prompting (prompting is `requestAuthorization`'s job).
    func start(localeIdentifier: String) {
        guard state != .recording else { return }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted else {
            state = .failed(.permissionDenied)
            return
        }

        let locale = recognizerLocale(for: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            state = .failed(.recognizerUnavailable)
            return
        }
        self.recognizer = recognizer

        finalizedText = ""
        currentPartial = ""
        transcript = ""
        audioLevel = 0
        elapsed = 0
        lastSpeechAt = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            state = .failed(.audioEngineFailure)
            return
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: Self.tapBufferSize, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            let level = Self.rms(from: buffer)
            Task { @MainActor [weak self] in
                self?.updateAudioLevel(level)
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            state = .failed(.audioEngineFailure)
            return
        }

        audioEngine = engine
        startDate = .now
        state = .recording
        startElapsedTimer()
        startSegment()
    }

    /// Ends capture and returns the final transcript (trimmed). Folds the last live partial into
    /// `finalizedText` synchronously — it does not wait for an async final-result callback.
    /// Idempotent: calling this when not recording just returns the current transcript.
    @discardableResult
    func stop() -> String {
        guard state == .recording else { return transcript }

        finalizedText = finalizedTranscript()
        currentPartial = ""
        transcript = finalizedText

        teardownRecognition()
        teardownAudio()
        invalidateTimers()

        state = .stopped
        return finalizedText
    }

    /// Discards all captured text and audio state and returns to `.idle`. Idempotent.
    func cancel() {
        teardownRecognition()
        teardownAudio()
        invalidateTimers()

        finalizedText = ""
        currentPartial = ""
        transcript = ""
        audioLevel = 0
        elapsed = 0
        lastSpeechAt = nil
        startDate = nil
        recognizer = nil

        state = .idle
    }

    // MARK: - Locale Mapping

    /// Maps app-style ("en", "zh-Hans") or full locale identifiers to a recognizer locale.
    private func recognizerLocale(for identifier: String) -> Locale {
        if identifier.hasPrefix("zh") {
            return Locale(identifier: "zh-CN")
        }
        return Locale(identifier: "en-US")
    }

    // MARK: - Segment Management

    /// Opens a fresh recognition request/task fed by the already-running audio tap. Safe to call
    /// repeatedly across segment boundaries — the engine and tap are untouched.
    private func startSegment() {
        guard let recognizer, audioEngine != nil else { return }

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.taskHint = .dictation
        newRequest.addsPunctuation = false
        if recognizer.supportsOnDeviceRecognition {
            newRequest.requiresOnDeviceRecognition = true
        }

        request = newRequest
        currentPartial = ""

        // Recognition tasks aren't Sendable, so identify "is this callback still for the
        // current segment" via `ObjectIdentifier` (Sendable) rather than capturing the task
        // itself across the `@MainActor` hop.
        var newTask: SFSpeechRecognitionTask?
        newTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            let callbackTaskID = newTask.map(ObjectIdentifier.init)
            Task { @MainActor [weak self] in
                guard let self, let callbackTaskID, self.task.map(ObjectIdentifier.init) == callbackTaskID else { return }
                self.handleRecognitionCallback(result: result, error: error)
            }
        }
        task = newTask
        let currentTaskID = newTask.map(ObjectIdentifier.init)

        segmentTimer?.invalidate()
        segmentTimer = Timer.scheduledTimer(withTimeInterval: Self.segmentDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let currentTaskID, self.task.map(ObjectIdentifier.init) == currentTaskID else { return }
                self.rotateSegment()
            }
        }
    }

    /// Folds the current segment's text into `finalizedText`, tears down ONLY the request/task
    /// (never the engine or tap), and opens the next segment.
    private func rotateSegment() {
        guard state == .recording else { return }

        finalizedText = finalizedTranscript()
        currentPartial = ""
        transcript = finalizedText

        teardownRecognition()
        startSegment()
    }

    private func handleRecognitionCallback(result: SFSpeechRecognitionResult?, error: Error?) {
        guard state == .recording else { return }

        if let result {
            currentPartial = result.bestTranscription.formattedString
            lastSpeechAt = .now
            transcript = finalizedTranscript()
            if result.isFinal {
                rotateSegment()
                return
            }
        }

        // Segment ended (timeout, task force-stop, transient recognizer error) rather than a
        // fatal condition — restart defensively so the mic never silently stops listening.
        if error != nil {
            rotateSegment()
        }
    }

    // MARK: - Teardown

    private func teardownRecognition() {
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    private func teardownAudio() {
        guard let audioEngine else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        self.audioEngine = nil

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func invalidateTimers() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        segmentTimer?.invalidate()
        segmentTimer = nil
    }

    // MARK: - Timers

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickElapsed()
            }
        }
    }

    private func tickElapsed() {
        guard let startDate, state == .recording else { return }
        elapsed = Date.now.timeIntervalSince(startDate)
    }

    // MARK: - Level Metering

    private func updateAudioLevel(_ rms: Float) {
        guard state == .recording else { return }
        // Raw speech RMS sits roughly in 0...0.3 — scale up, then exponentially smooth so the
        // meter doesn't jitter buffer-to-buffer.
        let normalized = min(max(rms * 4, 0), 1)
        audioLevel = audioLevel * 0.7 + normalized * 0.3
    }

    /// Computes RMS for a PCM buffer. Runs on the audio tap's real-time thread — must stay
    /// `nonisolated` (no main-actor state, no allocation beyond what the buffer already owns).
    private nonisolated static func rms(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let samples = channelData[0]
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = samples[i]
            sum += sample * sample
        }
        return (sum / Float(frameLength)).squareRoot()
    }

    // MARK: - Transcript Assembly

    private func finalizedTranscript() -> String {
        joined(finalizedText, currentPartial)
    }

    private func joined(_ finalized: String, _ partial: String) -> String {
        let trimmedFinalized = finalized.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPartial = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFinalized.isEmpty { return trimmedPartial }
        if trimmedPartial.isEmpty { return trimmedFinalized }
        return trimmedFinalized + " " + trimmedPartial
    }
}
