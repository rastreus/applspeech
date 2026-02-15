import Foundation

@main
struct ApplSpeech {
  static func main() {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.isEmpty || args.contains("--help") || args.contains("-h") || args.first == "help" {
      print(HelpText.render())
      return
    }

    fputs("error: unknown arguments: \(args.joined(separator: " "))\n", stderr)
    print(HelpText.render())
  }
}

enum HelpText {
  static func render() -> String {
    """
    applspeech — on-device speech transcription (AI agent friendly)

    USAGE:
      applspeech [--help]

    OPTIONS:
      -h, --help     Show help
    """
  }
}

