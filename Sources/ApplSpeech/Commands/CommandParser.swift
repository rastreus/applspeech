import Foundation

enum OutputFormat: String, Equatable, Sendable {
  case text
  case json
}

enum ApplSpeechCommand: Equatable {
  case help
  case version
  case transcribe(
    filePath: String?,
    format: OutputFormat,
    localeIdentifier: String,
    engine: SpeechEngine
  )
  case analyze(filePath: String?, format: OutputFormat)
  case status(format: OutputFormat, localeIdentifier: String)
  case authorize(
    format: OutputFormat,
    localeIdentifier: String,
    requestMicrophone: Bool,
    downloadModel: Bool
  )
  case unknown(arguments: [String])
}

enum CommandParser {
  static func parse(arguments: [String]) -> ApplSpeechCommand {
    if arguments.isEmpty
      || arguments.contains("--help")
      || arguments.contains("-h")
      || arguments.first == "help"
    {
      return .help
    }

    if arguments.first == "--version" || arguments.first == "-v" {
      return .version
    }

    if arguments.first == "transcribe" {
      let remaining = Array(arguments.dropFirst())
      var filePath: String?
      var format: OutputFormat = .text
      var localeIdentifier = "en-US"
      var engine: SpeechEngine = .auto

      var index = 0
      while index < remaining.count {
        let arg = remaining[index]

        if arg == "--format" || arg == "-f" {
          if index + 1 < remaining.count {
            let value = remaining[index + 1]
            if value == "json" {
              format = .json
            } else if value == "text" {
              format = .text
            }
            index += 2
            continue
          }
        } else if arg == "--format=json" || arg == "-f=json" || arg == "json" {
          format = .json
          index += 1
          continue
        } else if arg == "--format=text" || arg == "-f=text" || arg == "text" {
          format = .text
          index += 1
          continue
        } else if arg == "--locale" {
          if index + 1 < remaining.count {
            localeIdentifier = remaining[index + 1]
            index += 2
            continue
          }
        } else if arg.hasPrefix("--locale=") {
          localeIdentifier = String(arg.dropFirst("--locale=".count))
          index += 1
          continue
        } else if arg == "--engine" {
          if index + 1 < remaining.count {
            if let value = parseEngine(remaining[index + 1]) {
              engine = value
            }
            index += 2
            continue
          }
        } else if arg.hasPrefix("--engine=") {
          let rawValue = String(arg.dropFirst("--engine=".count))
          if let value = parseEngine(rawValue) {
            engine = value
          }
          index += 1
          continue
        } else if !arg.hasPrefix("-") && filePath == nil {
          filePath = arg
          index += 1
          continue
        }

        index += 1
      }

      return .transcribe(
        filePath: filePath,
        format: format,
        localeIdentifier: localeIdentifier,
        engine: engine
      )
    }

    if arguments.first == "analyze" {
      let remaining = Array(arguments.dropFirst())
      var filePath: String?
      var format: OutputFormat = .text

      var index = 0
      while index < remaining.count {
        let arg = remaining[index]

        if arg == "--format" || arg == "-f" {
          if index + 1 < remaining.count {
            let value = remaining[index + 1]
            if value == "json" {
              format = .json
            } else if value == "text" {
              format = .text
            }
            index += 2
            continue
          }
        } else if arg == "--format=json" || arg == "-f=json" || arg == "json" {
          format = .json
          index += 1
          continue
        } else if arg == "--format=text" || arg == "-f=text" || arg == "text" {
          format = .text
          index += 1
          continue
        } else if !arg.hasPrefix("-") && filePath == nil {
          filePath = arg
          index += 1
          continue
        }

        index += 1
      }

      return .analyze(filePath: filePath, format: format)
    }

    if arguments.first == "status" {
      let remaining = Array(arguments.dropFirst())
      var format: OutputFormat = .text
      var localeIdentifier = "en-US"

      var index = 0
      while index < remaining.count {
        let arg = remaining[index]

        if arg == "--format" || arg == "-f" {
          if index + 1 < remaining.count {
            let value = remaining[index + 1]
            if value == "json" {
              format = .json
            } else if value == "text" {
              format = .text
            }
            index += 2
            continue
          }
        } else if arg == "--format=json" || arg == "-f=json" || arg == "json" {
          format = .json
          index += 1
          continue
        } else if arg == "--format=text" || arg == "-f=text" || arg == "text" {
          format = .text
          index += 1
          continue
        } else if arg == "--locale" {
          if index + 1 < remaining.count {
            localeIdentifier = remaining[index + 1]
            index += 2
            continue
          }
        } else if arg.hasPrefix("--locale=") {
          localeIdentifier = String(arg.dropFirst("--locale=".count))
          index += 1
          continue
        }

        index += 1
      }

      return .status(format: format, localeIdentifier: localeIdentifier)
    }

    if arguments.first == "authorize" {
      let remaining = Array(arguments.dropFirst())
      var format: OutputFormat = .text
      var localeIdentifier = "en-US"
      var requestMicrophone = false
      var downloadModel = false

      var index = 0
      while index < remaining.count {
        let arg = remaining[index]

        if arg == "--format" || arg == "-f" {
          if index + 1 < remaining.count {
            let value = remaining[index + 1]
            if value == "json" {
              format = .json
            } else if value == "text" {
              format = .text
            }
            index += 2
            continue
          }
        } else if arg == "--format=json" || arg == "-f=json" || arg == "json" {
          format = .json
          index += 1
          continue
        } else if arg == "--format=text" || arg == "-f=text" || arg == "text" {
          format = .text
          index += 1
          continue
        } else if arg == "--locale" {
          if index + 1 < remaining.count {
            localeIdentifier = remaining[index + 1]
            index += 2
            continue
          }
        } else if arg.hasPrefix("--locale=") {
          localeIdentifier = String(arg.dropFirst("--locale=".count))
          index += 1
          continue
        } else if arg == "--microphone" {
          requestMicrophone = true
          index += 1
          continue
        } else if arg == "--download-model" {
          downloadModel = true
          index += 1
          continue
        }

        index += 1
      }

      return .authorize(
        format: format,
        localeIdentifier: localeIdentifier,
        requestMicrophone: requestMicrophone,
        downloadModel: downloadModel
      )
    }

    return .unknown(arguments: arguments)
  }
}

private func parseEngine(_ value: String) -> SpeechEngine? {
  switch value.lowercased() {
  case "auto":
    return .auto
  case "legacy", "sf", "sfspeechrecognizer":
    return .sfSpeechRecognizer
  case "modern", "transcriber", "speechtranscriber":
    return .speechTranscriber
  default:
    return nil
  }
}
