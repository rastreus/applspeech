import Testing
@testable import ApplSpeech

@Suite("Command Parsing")
struct CommandParserTests {
  @Test("Empty args -> help")
  func emptyArgs() {
    #expect(CommandParser.parse(arguments: []) == .help)
  }

  @Test("--help -> help")
  func longHelp() {
    #expect(CommandParser.parse(arguments: ["--help"]) == .help)
  }

  @Test("transcribe <file> -> transcribe command")
  func transcribeWithFile() {
    #expect(
      CommandParser.parse(arguments: ["transcribe", "a.wav"])
        == .transcribe(filePath: "a.wav", format: .text, localeIdentifier: "en-US")
    )
  }

  @Test("transcribe -> transcribe with missing file")
  func transcribeMissingFile() {
    #expect(
      CommandParser.parse(arguments: ["transcribe"])
        == .transcribe(filePath: nil, format: .text, localeIdentifier: "en-US")
    )
  }

  @Test("transcribe --format json <file> -> json format")
  func transcribeWithJsonFormat() {
    #expect(
      CommandParser.parse(arguments: ["transcribe", "--format", "json", "a.wav"])
        == .transcribe(filePath: "a.wav", format: .json, localeIdentifier: "en-US")
    )
  }

  @Test("transcribe --locale es-ES <file> -> locale set")
  func transcribeWithLocale() {
    #expect(
      CommandParser.parse(arguments: ["transcribe", "--locale", "es-ES", "a.wav"])
        == .transcribe(filePath: "a.wav", format: .text, localeIdentifier: "es-ES")
    )
  }

  @Test("Unknown args -> unknown")
  func unknownArgs() {
    #expect(CommandParser.parse(arguments: ["wat"]) == .unknown(arguments: ["wat"]))
  }
}
