import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.abhinav.oracle", category: "AudioRecorder")

enum AudioRecorderError: Error, LocalizedError {
    case permissionDenied
    case setupFailed(String)
    case notRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access was denied. Please enable it in System Settings > Privacy & Security > Microphone."
        case .setupFailed(let msg):
            return "Audio setup failed: \(msg)"
        case .notRecording:
            return "Not currently recording."
        }
    }
}

final class AudioRecorder: @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private(set) var recordedFileURL: URL?

    private let decibelLock = NSLock()
    private var _currentDecibelLevel: Double = 0
    var currentDecibelLevel: Double {
        decibelLock.lock()
        defer { decibelLock.unlock() }
        return _currentDecibelLevel
    }

    func startRecording() async throws {
        logger.info("Starting audio recording")

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("oracle_recording_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            outputFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        } catch {
            logger.error("Failed to create output file: \(error.localizedDescription)")
            throw AudioRecorderError.setupFailed(error.localizedDescription)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)

            do {
                try self?.outputFile?.write(from: buffer)
            } catch {
                logger.error("Audio write error: \(error.localizedDescription)")
            }
        }

        do {
            try engine.start()
            logger.info("Audio engine started successfully")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            throw AudioRecorderError.setupFailed(error.localizedDescription)
        }

        self.audioEngine = engine
        self.recordedFileURL = fileURL
    }

    func stopRecording() {
        logger.info("Stopping audio recording")
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        outputFile = nil

        decibelLock.lock()
        _currentDecibelLevel = 0
        decibelLock.unlock()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)
        let db = 20 * log10(max(average, 0.0001))
        let normalized = max(0, min(1, (db + 60) / 60))

        decibelLock.lock()
        _currentDecibelLevel = Double(normalized)
        decibelLock.unlock()
    }
}
