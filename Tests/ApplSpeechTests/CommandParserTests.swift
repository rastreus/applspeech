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
        == .transcribe(filePath: "a.wav", format: .text, localeIdentifier: "en-US", engine: .auto)
    )
  }

  @Test("transcribe -> transcribe with missing file")
  func transcribeMissingFile() {
    #expect(
      CommandParser.parse(arguments: ["transcribe"])
        == .transcribe(filePath: nil, format: .text, localeIdentifier: "en-US", engine: .auto)
    )
  }

  @Test("transcribe --format json <file> -> json format")
  func transcribeWithJsonFormat() {
    #expect(
      CommandParser.parse(arguments: ["transcribe", "--format", "json", "a.wav"])
        == .transcribe(filePath: "a.wav", format: .json, localeIdentifier: "en-US", engine: .auto)
    )
  }

  @Test("transcribe --locale es-ES <file> -> locale set")
  func transcribeWithLocale() {
    #expect(
      CommandParser.parse(arguments: ["transcribe", "--locale", "es-ES", "a.wav"])
        == .transcribe(filePath: "a.wav", format: .text, localeIdentifier: "es-ES", engine: .auto)
    )
  }

  @Test("transcribe --engine legacy <file> -> legacy engine")
  func transcribeWithEngine() {
    #expect(
      CommandParser.parse(arguments: ["transcribe", "--engine", "legacy", "a.wav"])
        == .transcribe(
          filePath: "a.wav",
          format: .text,
          localeIdentifier: "en-US",
          engine: .sfSpeechRecognizer
        )
    )
  }

  @Test("status -> status command")
  func statusCommand() {
    #expect(
      CommandParser.parse(arguments: ["status"])
        == .status(format: .text, localeIdentifier: "en-US")
    )
  }

  @Test("authorize flags -> authorize command")
  func authorizeCommand() {
    #expect(
      CommandParser.parse(arguments: [
        "authorize",
        "--locale",
        "es-ES",
        "--microphone",
        "--download-model",
        "--format",
        "json",
      ])
        == .authorize(
          format: .json,
          localeIdentifier: "es-ES",
          requestMicrophone: true,
          downloadModel: true
        )
    )
  }

  @Test("Unknown args -> unknown")
  func unknownArgs() {
    #expect(CommandParser.parse(arguments: ["wat"]) == .unknown(arguments: ["wat"]))
  }
}
