import AVFoundation
import Foundation
import Speech

@available(macOS 26.0, *)
struct SpeechTranscriberFileTranscriber: FileTranscribing {
  private let localeIdentifier: String

  init(localeIdentifier: String = "en-US") {
    self.localeIdentifier = localeIdentifier
  }

  func transcribeFile(at url: URL) async throws -> String {
    let path = url.path
    guard FileManager.default.fileExists(atPath: path) else {
      throw TranscriptionError.fileNotFound(path: path)
    }

    guard SupportedAudioFormat.from(url) != nil else {
      throw TranscriptionError.unsupportedAudioFormat(
        path: path,
        supported: Array(SupportedAudioFormat.allCases)
      )
    }

    let status = await SpeechAuthorization.request()
    guard status == .authorized else {
      throw TranscriptionError.speechNotAuthorized
    }

    let requested = Locale(identifier: localeIdentifier)
    guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: requested)
    else {
      throw TranscriptionError.speechTranscriberLocaleUnsupported(
        localeIdentifier: localeIdentifier)
    }

    let installed = await SpeechTranscriber.installedLocales
    let installedSet = Set(installed.map { normalizeLocaleIdentifier($0.identifier) })
    guard installedSet.contains(normalizeLocaleIdentifier(supportedLocale.identifier)) else {
      throw TranscriptionError.speechTranscriberModelNotInstalled(
        localeIdentifier: supportedLocale.identifier)
    }

    let transcriber = SpeechTranscriber(locale: supportedLocale, preset: .progressiveTranscription)
    let modules: [any SpeechModule] = [transcriber]
    let analyzer = SpeechAnalyzer(modules: modules)

    let audioFile = try AVAudioFile(forReading: url)
    let analysisTask = Task {
      try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
    }

    var text = ""
    for try await result in transcriber.results {
      text += String(result.text.characters)
    }

    try await analysisTask.value

    guard !text.isEmpty else {
      throw TranscriptionError.noFinalResult
    }

    return text
  }
}

@available(macOS 26.0, *)
private func normalizeLocaleIdentifier(_ identifier: String) -> String {
  identifier.replacingOccurrences(of: "_", with: "-").lowercased()
}
