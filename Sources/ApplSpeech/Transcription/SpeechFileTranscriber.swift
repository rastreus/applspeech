import AVFoundation
import Foundation
import Speech

struct SpeechFileTranscriber: FileTranscribing {
  private let localeIdentifier: String

  init(localeIdentifier: String = "en-US") {
    self.localeIdentifier = localeIdentifier
  }

  func transcribeFile(at url: URL) async throws -> String {
    let path = url.path
    guard FileManager.default.fileExists(atPath: path) else {
      throw TranscriptionError.fileNotFound(path: path)
    }

    guard SupportedAudioFormat.from(url) != nil else {
      throw TranscriptionError.unsupportedAudioFormat(
        path: path,
        supported: Array(SupportedAudioFormat.allCases)
      )
    }

    let locale = Locale(identifier: localeIdentifier)
    guard let recognizer = SFSpeechRecognizer(locale: locale),
      recognizer.isAvailable
    else {
      throw TranscriptionError.speechNotAvailable
    }

    let status = await SpeechAuthorization.request()
    guard status == .authorized else {
      throw TranscriptionError.speechNotAuthorized
    }

    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false

    // Use on-device recognition if supported (faster, works offline)
    if recognizer.supportsOnDeviceRecognition {
      request.requiresOnDeviceRecognition = true
    }

    return try await withCheckedThrowingContinuation { continuation in
      recognizer.recognitionTask(with: request) { result, error in
        if let error = error {
          continuation.resume(throwing: TranscriptionError.transcriptionFailed(
            message: String(describing: error))
          )
          return
        }

        guard let result = result, result.isFinal else {
          return
        }

        let text = result.bestTranscription.formattedString
        continuation.resume(returning: text)
      }
    }
  }
}
