import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.abhinav.oracle", category: "AudioPlayer")

enum AudioPlayerError: Error, LocalizedError {
    case noData
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No audio data to play."
        case .playbackFailed(let msg):
            return "Playback failed: \(msg)"
        }
    }
}

final class AudioPlayerService: @unchecked Sendable {
    private var player: AVAudioPlayer?
    private var completionContinuation: CheckedContinuation<Void, Error>?
    private var currentDelegate: PlayerDelegate?

    func play(data: Data) async throws {
        logger.info("Starting audio playback")
        stop()

        return try await withCheckedThrowingContinuation { continuation in
            do {
                let delegate = PlayerDelegate()
                let player = try AVAudioPlayer(data: data)
                player.delegate = delegate
                player.prepareToPlay()

                delegate.onFinish = { [weak self] in
                    logger.info("Audio playback finished")
                    self?.completionContinuation?.resume()
                    self?.completionContinuation = nil
                }

                self.completionContinuation = continuation
                self.currentDelegate = delegate
                self.player = player
                player.play()
                logger.info("Audio playback started")
            } catch {
                logger.error("Failed to start playback: \(error.localizedDescription)")
                continuation.resume(throwing: AudioPlayerError.playbackFailed(error.localizedDescription))
            }
        }
    }

    func stop() {
        logger.info("Stopping audio playback")
        player?.stop()
        player = nil
        currentDelegate = nil
        if let continuation = completionContinuation {
            continuation.resume()
            completionContinuation = nil
        }
    }
}

private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
