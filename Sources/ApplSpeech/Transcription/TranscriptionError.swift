import Foundation

enum TranscriptionError: Error, CustomStringConvertible, Equatable, Sendable {
  case fileNotFound(path: String)
  case unsupportedAudioFormat(path: String, supported: [SupportedAudioFormat])
  case remoteDownloadFailed(url: String, statusCode: Int)
  case remoteDownloadNetworkError(url: String, code: Int)
  case remoteDownloadInvalidResponse(url: String)
  case stdinEmpty
  case telegramMissingBotToken
  case telegramInvalidFileID
  case telegramAPIRequestFailed(operation: String, statusCode: Int)
  case telegramAPINetworkError(operation: String, code: Int)
  case telegramAPIInvalidResponse(operation: String)
  case telegramAPIInvalidPayload(operation: String)
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
    case .remoteDownloadFailed(let url, let statusCode):
      return "failed to download remote audio: \(url) (status: \(statusCode))"
    case .remoteDownloadNetworkError(let url, let code):
      return "failed to download remote audio: \(url) (network: \(code))"
    case .remoteDownloadInvalidResponse(let url):
      return "failed to download remote audio: \(url) (invalid response)"
    case .stdinEmpty:
      return "stdin is empty, no audio data received"
    case .telegramMissingBotToken:
      return "telegram bot token missing (set TELEGRAM_BOT_TOKEN)"
    case .telegramInvalidFileID:
      return "telegram file id missing or invalid"
    case .telegramAPIRequestFailed(let operation, let statusCode):
      return "telegram \(operation) failed (status: \(statusCode))"
    case .telegramAPINetworkError(let operation, let code):
      return "telegram \(operation) failed (network: \(code))"
    case .telegramAPIInvalidResponse(let operation):
      return "telegram \(operation) failed (invalid response)"
    case .telegramAPIInvalidPayload(let operation):
      return "telegram \(operation) failed (invalid payload)"
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
