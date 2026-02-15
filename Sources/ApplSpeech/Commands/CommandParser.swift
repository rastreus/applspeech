import Foundation

enum OutputFormat: String, Equatable, Sendable {
  case text
  case json
}

enum ApplSpeechCommand: Equatable {
  case help
  case version
  case transcribe(filePath: String?, format: OutputFormat, localeIdentifier: String)
  case analyze(filePath: String?, format: OutputFormat)
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
        } else if !arg.hasPrefix("-") && filePath == nil {
          filePath = arg
          index += 1
          continue
        }

        index += 1
      }

      return .transcribe(filePath: filePath, format: format, localeIdentifier: localeIdentifier)
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

    return .unknown(arguments: arguments)
  }
}
