import Foundation
import CoreNFC

/// Wraps CoreNFC write and scan sessions with async/await.
/// Must be a class (not struct) to conform to NFCNDEFReaderSessionDelegate.
/// @MainActor is on individual public methods only — delegate callbacks are nonisolated.
final class NFCSessionCoordinator: NSObject {

    private var readerSession: NFCNDEFReaderSession?
    private var writerSession: NFCNDEFReaderSession?
    private var scanContinuation: CheckedContinuation<UUID, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?
    private var athleteIdToWrite: UUID?

    // MARK: - Public API (called from @MainActor views)

    /// Writes the athlete's UUID to an NFC tag.
    /// Call from a view button action — presents the system NFC UI.
    @MainActor
    func startWrite(athleteId: UUID) async throws {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw NFCError.notAvailable
        }
        athleteIdToWrite = athleteId
        return try await withCheckedThrowingContinuation { continuation in
            self.writeContinuation = continuation
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            session.alertMessage = "Hold your iPhone near the coach's device."
            self.writerSession = session
            session.begin()
        }
    }

    /// Scans an NFC tag and returns the athleteId written by the athlete's device.
    /// Call from a view button action — presents the system NFC UI.
    @MainActor
    func startScan() async throws -> UUID {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw NFCError.notAvailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.scanContinuation = continuation
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = "Hold your iPhone near the athlete's device."
            self.readerSession = session
            session.begin()
        }
    }

    // MARK: - Errors

    enum NFCError: LocalizedError {
        case notAvailable
        case invalidPayload
        case invalidUUID

        var errorDescription: String? {
            switch self {
            case .notAvailable: return "NFC is not available on this device."
            case .invalidPayload: return "Could not read NFC data. Try again."
            case .invalidUUID: return "NFC data was not a valid athlete ID."
            }
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate (nonisolated — called on CoreNFC background thread)

extension NFCSessionCoordinator: NFCNDEFReaderSessionDelegate {

    nonisolated func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Writing happens in readerSession(_:didDetectTags:) below
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetectNDEFs messages: [NFCNDEFMessage]
    ) {
        // Scan path: extract UUID from first text record
        guard let record = messages.first?.records.first,
              record.typeNameFormat == .nfcWellKnown,
              let payloadString = String(data: record.payload.advanced(by: 3), encoding: .utf8),
              let uuid = UUID(uuidString: payloadString) else {
            scanContinuation?.resume(throwing: NFCError.invalidPayload)
            scanContinuation = nil
            return
        }
        session.invalidate()
        scanContinuation?.resume(returning: uuid)
        scanContinuation = nil
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetect tags: [NFCNDEFTag]
    ) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                self?.writeContinuation?.resume(throwing: error)
                self?.writeContinuation = nil
                return
            }
            guard let athleteId = self?.athleteIdToWrite else { return }
            let uuidString = athleteId.uuidString
            let langData = Data([0x02, 0x65, 0x6E])  // length(2) + "en"
            let textData = uuidString.data(using: .utf8)!
            let payload = NFCNDEFPayload(
                format: .nfcWellKnown,
                type: "T".data(using: .utf8)!,
                identifier: Data(),
                payload: langData + textData
            )
            let message = NFCNDEFMessage(records: [payload])
            tag.writeNDEF(message) { error in
                if let error {
                    session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                    self?.writeContinuation?.resume(throwing: error)
                } else {
                    session.alertMessage = "Linked!"
                    session.invalidate()
                    self?.writeContinuation?.resume()
                }
                self?.writeContinuation = nil
            }
        }
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didInvalidateWithError error: Error
    ) {
        let nsError = error as NSError
        // Code 200 = user cancelled — not an error
        guard nsError.code != 200 else {
            scanContinuation?.resume(throwing: CancellationError())
            writeContinuation?.resume(throwing: CancellationError())
            scanContinuation = nil
            writeContinuation = nil
            return
        }
        scanContinuation?.resume(throwing: error)
        writeContinuation?.resume(throwing: error)
        scanContinuation = nil
        writeContinuation = nil
    }
}
