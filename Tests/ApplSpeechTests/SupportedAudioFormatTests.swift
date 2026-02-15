import Foundation
import Testing

@testable import ApplSpeech

@Suite("Supported Audio Formats")
struct SupportedAudioFormatTests {
  @Test("Matches case-insensitively by file extension")
  func fromURL() {
    #expect(SupportedAudioFormat.from(URL(fileURLWithPath: "/tmp/a.WAV")) == .wav)
    #expect(SupportedAudioFormat.from(URL(fileURLWithPath: "/tmp/a.m4a")) == .m4a)
    #expect(SupportedAudioFormat.from(URL(fileURLWithPath: "/tmp/a.mp3")) == .mp3)
    #expect(SupportedAudioFormat.from(URL(fileURLWithPath: "/tmp/a.flac")) == .flac)
  }

  @Test("Unknown extension returns nil")
  func unknownExtension() {
    #expect(SupportedAudioFormat.from(URL(fileURLWithPath: "/tmp/a.aac")) == nil)
  }
}
