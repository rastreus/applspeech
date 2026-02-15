import Testing

@testable import ApplSpeech

@Suite("CLI Help")
struct CLIHelpTests {
  @Test("Help text includes usage and options")
  func helpText() {
    let text = HelpText.render()
    #expect(text.contains("USAGE:"))
    #expect(text.contains("--help"))
    #expect(text.contains("--locale"))
    #expect(text.contains("status"))
    #expect(text.contains("authorize"))
    #expect(text.contains("--download-model"))
    #expect(text.contains("transcribe"))
  }
}
