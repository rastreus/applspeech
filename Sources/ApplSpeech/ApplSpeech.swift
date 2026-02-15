import Foundation

struct TranscribeOutput: Codable {
  let text: String
  let file: String
  let language: String
}

@main
struct ApplSpeech {
  static let version = "0.1.0"

  static func main() async {
    let args = Array(CommandLine.arguments.dropFirst())
    let command = CommandParser.parse(arguments: args)

    switch command {
    case .help:
      print(HelpText.render())
      return

    case .version:
      print("applspeech \(version)")
      return

    case .transcribe(filePath: let filePath, format: let format, localeIdentifier: let localeIdentifier):
      guard let filePath else {
        if format == .json {
          let error = ["ok": false, "error": ["code": "missing_file", "message": "missing audio file path"]] as [String: Any]
          if let data = try? JSONSerialization.data(withJSONObject: error),
             let json = String(data: data, encoding: .utf8) {
            fputs(json, stderr)
          }
        } else {
          fputs("error: missing audio file path\n", stderr)
          print(HelpText.render())
        }
        return
      }

      do {
        let resolved = try await AudioInputResolver.resolve(filePath)
        defer { resolved.cleanup() }
        let transcriber = SpeechFileTranscriber(localeIdentifier: localeIdentifier)
        let text = try await transcriber.transcribeFile(at: resolved.localFileURL)

        if format == .json {
          let output = TranscribeOutput(text: text, file: filePath, language: localeIdentifier)
          let encoder = JSONEncoder()
          encoder.outputFormatting = []
          if let data = try? encoder.encode(output),
             let json = String(data: data, encoding: .utf8) {
            print(json)
          }
        } else {
          print(text)
        }
      } catch let error as TranscriptionError {
        if format == .json {
          let errorDict: [String: Any] = [
            "ok": false,
            "error": ["code": "transcription_error", "message": error.description]
          ]
          if let data = try? JSONSerialization.data(withJSONObject: errorDict),
             let json = String(data: data, encoding: .utf8) {
            fputs(json, stderr)
          }
        } else {
          fputs("error: \(error.description)\n", stderr)
        }
      } catch {
        if format == .json {
          let errorDict: [String: Any] = [
            "ok": false,
            "error": ["code": "unknown", "message": String(describing: error)]
          ]
          if let data = try? JSONSerialization.data(withJSONObject: errorDict),
             let json = String(data: data, encoding: .utf8) {
            fputs(json, stderr)
          }
        } else {
          fputs("error: \(String(describing: error))\n", stderr)
        }
      }

    case .analyze(filePath: let filePath, format: let format):
      guard let filePath else {
        if format == .json {
          let error = ["ok": false, "error": ["code": "missing_file", "message": "missing audio file path"]] as [String: Any]
          if let data = try? JSONSerialization.data(withJSONObject: error),
             let json = String(data: data, encoding: .utf8) {
            fputs(json, stderr)
          }
        } else {
          fputs("error: missing audio file path\n", stderr)
          print(HelpText.render())
        }
        return
      }

      do {
        let resolved = try await AudioInputResolver.resolve(filePath)
        defer { resolved.cleanup() }
        let analyzer = SpeechAudioAnalyzer()
        let analysis = try await analyzer.analyzeFile(at: resolved.localFileURL)

        if format == .json {
          let encoder = JSONEncoder()
          encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
          if let data = try? encoder.encode(analysis),
             let json = String(data: data, encoding: .utf8) {
            print(json)
          }
        } else {
          print("Voice Analysis:")
          if let pitch = analysis.pitch { print("  Pitch: \(pitch)") }
          if let tempo = analysis.tempo { print("  Tempo: \(tempo)") }
          if let volume = analysis.volume { print("  Volume: \(volume)") }
          if let jitter = analysis.jitter { print("  Jitter: \(jitter)") }
          if let shimmer = analysis.shimmer { print("  Shimmer: \(shimmer)") }
        }
      } catch let error as VoiceAnalysisError {
        if format == .json {
          let errorDict: [String: Any] = [
            "ok": false,
            "error": ["code": "analysis_error", "message": error.description]
          ]
          if let data = try? JSONSerialization.data(withJSONObject: errorDict),
             let json = String(data: data, encoding: .utf8) {
            fputs(json, stderr)
          }
        } else {
          fputs("error: \(error.description)\n", stderr)
        }
      } catch {
        if format == .json {
          let errorDict: [String: Any] = [
            "ok": false,
            "error": ["code": "unknown", "message": String(describing: error)]
          ]
          if let data = try? JSONSerialization.data(withJSONObject: errorDict),
             let json = String(data: data, encoding: .utf8) {
            fputs(json, stderr)
          }
        } else {
          fputs("error: \(String(describing: error))\n", stderr)
        }
      }

    case .unknown(arguments: let arguments):
      fputs("error: unknown arguments: \(arguments.joined(separator: " "))\n", stderr)
      print(HelpText.render())
    }
  }
}

enum HelpText {
  static func render() -> String {
    """
    applspeech — on-device speech transcription (AI agent friendly)

    USAGE:
      applspeech [--help]
      applspeech [--version]
      applspeech transcribe <file-or-url> [--format json] [--locale en-US]
      applspeech transcribe - [--format json] [--locale en-US]
      applspeech transcribe tg:<telegram_file_id> [--format json] [--locale en-US]
      applspeech analyze <file-or-url> [--format json]

    COMMANDS:
      transcribe <file-or-url>   Transcribe audio file, URL (http/https), or stdin (-)
      transcribe -              Read audio from stdin (e.g., cat file.m4a | applspeech transcribe -)
      transcribe tg:<file_id>   Download via Telegram then transcribe (needs TELEGRAM_BOT_TOKEN)
      analyze <file-or-url>     Analyze voice characteristics (pitch, tempo, volume)

    OPTIONS:
      -h, --help           Show this help message
      -v, --version        Show version number
      --format json        Output JSON format (default: text)
      --locale <bcp47>    Locale identifier (default: en-US, e.g., es-ES, fr-FR)

    EXAMPLES:
      # Transcribe a local file
      applspeech transcribe audio.m4a

      # Transcribe with Spanish locale, JSON output
      applspeech transcribe audio.m4a --locale es-ES --format json

      # Transcribe from URL
      applspeech transcribe https://example.com/audio.wav

      # Pipe audio from curl
      curl -L https://example.com/audio.m4a | applspeech transcribe -

      # Analyze voice characteristics
      applspeech analyze voice.m4a --format json

    ENVIRONMENT:
      TELEGRAM_BOT_TOKEN   Bot token for Telegram audio download

    See https://github.com/77smith-norm/applspeech for full documentation
    """
  }
}
