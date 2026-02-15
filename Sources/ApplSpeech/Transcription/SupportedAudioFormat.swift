import Foundation

enum SupportedAudioFormat: String, CaseIterable, Sendable {
  case flac
  case wav
  case m4a
  case mp3
  case ogg
  case oga

  static func from(_ url: URL) -> SupportedAudioFormat? {
    SupportedAudioFormat(rawValue: url.pathExtension.lowercased())
  }
}
