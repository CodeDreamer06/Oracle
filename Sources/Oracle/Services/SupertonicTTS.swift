import Foundation
import os.log

private let logger = Logger(subsystem: "com.abhinav.oracle", category: "TTS")

enum TTSError: Error, LocalizedError {
    case executableNotFound
    case assetsNotFound
    case voiceStyleNotFound(String)
    case synthesisFailed(String)
    case outputNotFound

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Supertonic executable not found. Please run ./setup.sh to download and build Supertonic."
        case .assetsNotFound:
            return "Supertonic ONNX assets not found. Please run ./setup.sh to download models."
        case .voiceStyleNotFound(let voice):
            return "Voice style '\(voice)' not found. Available: M1-M5, F1-F5."
        case .synthesisFailed(let msg):
            return "TTS synthesis failed: \(msg)"
        case .outputNotFound:
            return "TTS output file was not generated."
        }
    }
}

final class SupertonicTTS: @unchecked Sendable {
    private func findExecutable() -> URL? {
        let paths: [URL] = [
            Bundle.main.url(forResource: "example_onnx", withExtension: nil, subdirectory: "supertonic"),
            URL(fileURLWithPath: "../supertonic/swift/.build/release/example_onnx"),
            Bundle.main.url(forResource: "example_onnx", withExtension: nil),
            URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path)
                .appendingPathComponent("Projects/supertonic/swift/.build/release/example_onnx")
        ].compactMap { $0 }

        return paths.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func findAssetsDir() -> URL? {
        let paths: [URL] = [
            Bundle.main.url(forResource: "assets", withExtension: nil, subdirectory: "supertonic"),
            URL(fileURLWithPath: "../supertonic/assets"),
            Bundle.main.url(forResource: "assets", withExtension: nil),
            URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path)
                .appendingPathComponent("Projects/supertonic/assets")
        ].compactMap { $0 }

        return paths.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func synthesize(
        text: String,
        voiceStyle: String,
        lang: String,
        totalStep: Int,
        speed: Float
    ) async throws -> Data {
        logger.info("Starting TTS synthesis for voice \(voiceStyle)")

        guard let executable = findExecutable() else {
            logger.error("Supertonic executable not found")
            throw TTSError.executableNotFound
        }

        guard let assetsDir = findAssetsDir() else {
            logger.error("Supertonic assets not found")
            throw TTSError.assetsNotFound
        }

        let onnxDir = assetsDir.appendingPathComponent("onnx").path
        let voiceStylesDir = assetsDir.appendingPathComponent("voice_styles")
        let voiceStylePath = voiceStylesDir.appendingPathComponent("\(voiceStyle).json").path

        guard FileManager.default.fileExists(atPath: voiceStylePath) else {
            logger.error("Voice style not found: \(voiceStyle)")
            throw TTSError.voiceStyleNotFound(voiceStyle)
        }

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("oracle_tts_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "--onnx-dir", onnxDir,
            "--voice-style", voiceStylePath,
            "--text", text,
            "--lang", lang,
            "--save-dir", tmpDir.path,
            "--total-step", "\(totalStep)",
            "--speed", "\(speed)",
            "--n-test", "1"
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                do {
                    if proc.terminationStatus != 0 {
                        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let stderrString = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                        logger.error("TTS process failed: \(stderrString)")
                        continuation.resume(throwing: TTSError.synthesisFailed(stderrString))
                        return
                    }

                    let files = try FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
                    guard let wavFile = files.first(where: { $0.pathExtension.lowercased() == "wav" }) else {
                        logger.error("TTS output WAV not found")
                        continuation.resume(throwing: TTSError.outputNotFound)
                        return
                    }

                    let data = try Data(contentsOf: wavFile)
                    try? FileManager.default.removeItem(at: tmpDir)

                    logger.info("TTS synthesis completed successfully")
                    continuation.resume(returning: data)
                } catch {
                    logger.error("TTS post-processing error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }

            do {
                try process.run()
                logger.info("TTS process started")
            } catch {
                logger.error("Failed to start TTS process: \(error.localizedDescription)")
                continuation.resume(throwing: TTSError.synthesisFailed(error.localizedDescription))
            }
        }
    }
}
