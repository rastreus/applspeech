import Foundation

enum TranscriptionError: Error, CustomStringConvertible, Equatable, Sendable {
  case fileNotFound(path: String)
  case unsupportedAudioFormat(path: String, supported: [SupportedAudioFormat])
  case speechNotAvailable
  case speechNotAuthorized
  case noFinalResult
  case transcriptionFailed(message: String)

  var description: String {
    switch self {
    case .fileNotFound(let path):
      return "file not found: \(path)"
    case .unsupportedAudioFormat(let path, let supported):
      let exts = supported.map(\.rawValue).sorted().joined(separator: ", ")
      return "unsupported audio format: \(path) (supported: \(exts))"
    case .speechNotAvailable:
      return "speech recognition is not available on this device"
    case .speechNotAuthorized:
      return "speech recognition is not authorized"
    case .noFinalResult:
      return "no transcription result produced"
    case .transcriptionFailed(let message):
      return "transcription failed: \(message)"
    }
  }
}

