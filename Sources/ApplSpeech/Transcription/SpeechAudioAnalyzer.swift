import Foundation
import Speech

struct VoiceAnalysis: Codable, Sendable {
  let pitch: Double?
  let tempo: Double?
  let volume: Double?
  let jitter: Double?
  let shimmer: Double?
}

enum VoiceAnalysisError: Error, CustomStringConvertible, Equatable, Sendable {
  case fileNotFound(path: String)
  case unsupportedAudioFormat(path: String, supported: [SupportedAudioFormat])
  case analysisFailed(message: String)
  case speechNotAvailable

  var description: String {
    switch self {
    case .fileNotFound(let path):
      return "file not found: \(path)"
    case .unsupportedAudioFormat(let path, let supported):
      let exts = supported.map(\.rawValue).sorted().joined(separator: ", ")
      return "unsupported audio format: \(path) (supported: \(exts))"
    case .analysisFailed(let message):
      return "voice analysis failed: \(message)"
    case .speechNotAvailable:
      return "speech recognition is not available on this device"
    }
  }
}

struct SpeechAudioAnalyzer: Sendable {
  func analyzeFile(at url: URL) async throws -> VoiceAnalysis {
    let path = url.path
    guard FileManager.default.fileExists(atPath: path) else {
      throw VoiceAnalysisError.fileNotFound(path: path)
    }

    guard SupportedAudioFormat.from(url) != nil else {
      throw VoiceAnalysisError.unsupportedAudioFormat(
        path: path,
        supported: Array(SupportedAudioFormat.allCases)
      )
    }

    // SpeechAnalyzer requires modules - for voice analysis we would use VoiceAnalysisModule
    // For now, return placeholder values - the actual implementation would use
    // SpeechAnalyzer with VoiceAnalysisModule for real pitch/tempo/volume data
    return VoiceAnalysis(
      pitch: nil,
      tempo: nil,
      volume: nil,
      jitter: nil,
      shimmer: nil
    )
  }
}
