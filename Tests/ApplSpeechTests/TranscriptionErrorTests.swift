import Testing
@testable import ApplSpeech

@Suite("Transcription Errors")
struct TranscriptionErrorTests {
  @Test("Unsupported audio format includes supported extensions")
  func unsupportedAudioFormatMessage() {
    let err = TranscriptionError.unsupportedAudioFormat(
      path: "a.ogg",
      supported: [.wav, .mp3]
    )
    #expect(err.description.contains("a.ogg"))
    #expect(err.description.contains("supported: mp3, wav"))
  }
}

