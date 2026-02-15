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

    case .status(format: let format, localeIdentifier: let localeIdentifier):
      let status = await SpeechEnvironment.status(localeIdentifier: localeIdentifier)
      if format == .json {
        writeJSON(status, prettyPrinted: true)
      } else {
        print(renderStatusText(status))
      }

    case .authorize(
      format: let format,
      localeIdentifier: let localeIdentifier,
      requestMicrophone: let requestMicrophone,
      downloadModel: let downloadModel
    ):
      do {
        let status = try await SpeechEnvironment.authorize(
          localeIdentifier: localeIdentifier,
          requestMicrophone: requestMicrophone,
          downloadModel: downloadModel
        )
        if format == .json {
          writeJSON(status, prettyPrinted: true)
        } else {
          print(renderStatusText(status))
        }
      } catch {
        if format == .json {
          writeJSONError(code: "authorize_failed", message: error.description)
        } else {
          fputs("error: \(error.description)\n", stderr)
        }
      }

    case .unknown(arguments: let arguments):
      fputs("error: unknown arguments: \(arguments.joined(separator: " "))\n", stderr)
      print(HelpText.render())
    }
  }
}

private func writeJSON<T: Encodable>(_ value: T, prettyPrinted: Bool) {
  let encoder = JSONEncoder()
  if prettyPrinted {
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  } else {
    encoder.outputFormatting = []
  }

  if let data = try? encoder.encode(value),
    let json = String(data: data, encoding: .utf8)
  {
    print(json)
  }
}

private func writeJSONError(code: String, message: String) {
  let error: [String: Any] = ["ok": false, "error": ["code": code, "message": message]]
  if let data = try? JSONSerialization.data(withJSONObject: error),
    let json = String(data: data, encoding: .utf8)
  {
    fputs(json, stderr)
  }
}

private func renderStatusText(_ status: SpeechEnvironmentStatus) -> String {
  var lines: [String] = []
  lines.append("Locale: \(status.locale)")
  lines.append("Speech Recognition: \(status.permissions.speechRecognition.rawValue)")
  lines.append("Microphone: \(status.permissions.microphone.rawValue)")

  let legacy = status.engines.sfSpeechRecognizer
  if legacy.available {
    lines.append("SFSpeechRecognizer: available")
    if let recognizerAvailable = legacy.recognizerAvailable {
      lines.append("  isAvailable: \(recognizerAvailable)")
    }
    if let supportsOnDevice = legacy.supportsOnDeviceRecognition {
      lines.append("  supportsOnDeviceRecognition: \(supportsOnDevice)")
    }
  } else {
    lines.append("SFSpeechRecognizer: unavailable for locale")
  }

  let modern = status.engines.speechTranscriber
  if modern.available {
    let supportedLocale = modern.supportedLocale ?? "unsupported locale"
    let installed = modern.modelInstalled.map(String.init(describing:)) ?? "unknown"
    lines.append("SpeechTranscriber: available")
    lines.append("  supportedLocale: \(supportedLocale)")
    lines.append("  modelInstalled: \(installed)")
  } else {
    lines.append("SpeechTranscriber: unavailable on this OS")
  }

  lines.append("Ready: \(status.ok)")
  return lines.joined(separator: "\n")
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
      applspeech status [--format json] [--locale en-US]
      applspeech authorize [--format json] [--locale en-US] [--microphone] [--download-model]

    COMMANDS:
      transcribe <file-or-url>   Transcribe audio file, URL (http/https), or stdin (-)
      transcribe -              Read audio from stdin (e.g., cat file.m4a | applspeech transcribe -)
      transcribe tg:<file_id>   Download via Telegram then transcribe (needs TELEGRAM_BOT_TOKEN)
      analyze <file-or-url>     Analyze voice characteristics (pitch, tempo, volume)
      status                    Show speech/microphone permission status and model availability
      authorize                 Request permissions (and optionally download SpeechTranscriber models)

    OPTIONS:
      -h, --help           Show this help message
      -v, --version        Show version number
      --format json        Output JSON format (default: text)
      --locale <bcp47>    Locale identifier (default: en-US, e.g., es-ES, fr-FR)
      --microphone         Also request microphone permission (used for live transcription)
      --download-model     Download SpeechTranscriber model for --locale (if supported)

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

      # Check permissions and model status for Spanish
      applspeech status --locale es-ES --format json

      # Trigger permission prompts and download model (if needed)
      applspeech authorize --locale es-ES --microphone --download-model --format json

    ENVIRONMENT:
      TELEGRAM_BOT_TOKEN   Bot token for Telegram audio download

    See https://github.com/77smith-norm/applspeech for full documentation
    """
  }
}
