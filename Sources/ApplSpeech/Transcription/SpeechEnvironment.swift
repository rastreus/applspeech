import Foundation
import Speech

struct SpeechEnvironmentStatus: Codable, Sendable {
  struct Permissions: Codable, Sendable {
    let speechRecognition: AuthorizationState
    let microphone: AuthorizationState
  }

  struct Engines: Codable, Sendable {
    let sfSpeechRecognizer: LegacySpeechEngineStatus
    let speechTranscriber: SpeechTranscriberModelStatus
  }

  let ok: Bool
  let locale: String
  let permissions: Permissions
  let engines: Engines
}

struct LegacySpeechEngineStatus: Codable, Sendable {
  let available: Bool
  let recognizerAvailable: Bool?
  let supportsOnDeviceRecognition: Bool?
}

enum SpeechEnvironmentError: Error, CustomStringConvertible, Sendable {
  case speechTranscriberNotAvailable
  case speechTranscriberLocaleUnsupported(localeIdentifier: String)
  case speechTranscriberModelInstallFailed(message: String)

  var description: String {
    switch self {
    case .speechTranscriberNotAvailable:
      return "SpeechTranscriber API is not available on this OS"
    case .speechTranscriberLocaleUnsupported(let localeIdentifier):
      return "SpeechTranscriber does not support locale: \(localeIdentifier)"
    case .speechTranscriberModelInstallFailed(let message):
      return "failed to download/install SpeechTranscriber model: \(message)"
    }
  }
}

enum SpeechEnvironment {
  static func status(localeIdentifier: String) async -> SpeechEnvironmentStatus {
    let speech = AuthorizationState(speech: SFSpeechRecognizer.authorizationStatus())
    let microphone = AuthorizationState(microphone: MicrophoneAuthorization.status())

    let legacy = legacyStatus(localeIdentifier: localeIdentifier)
    let transcriber = await SpeechTranscriberModelSupport.status(localeIdentifier: localeIdentifier)

    let readyLegacy = speech == .authorized && legacy.available && (legacy.recognizerAvailable ?? false)
    let readyTranscriber =
      speech == .authorized && transcriber.available && (transcriber.modelInstalled ?? false)

    return SpeechEnvironmentStatus(
      ok: readyLegacy || readyTranscriber,
      locale: localeIdentifier,
      permissions: SpeechEnvironmentStatus.Permissions(
        speechRecognition: speech,
        microphone: microphone
      ),
      engines: SpeechEnvironmentStatus.Engines(
        sfSpeechRecognizer: legacy,
        speechTranscriber: transcriber
      )
    )
  }

  static func authorize(
    localeIdentifier: String,
    requestMicrophone: Bool,
    downloadModel: Bool
  ) async throws(SpeechEnvironmentError) -> SpeechEnvironmentStatus {
    _ = await SpeechAuthorization.request()

    if requestMicrophone {
      _ = await MicrophoneAuthorization.request()
    }

    if downloadModel {
      try await SpeechTranscriberModelSupport.ensureInstalled(localeIdentifier: localeIdentifier)
    }

    return await status(localeIdentifier: localeIdentifier)
  }

  private static func legacyStatus(localeIdentifier: String) -> LegacySpeechEngineStatus {
    let locale = Locale(identifier: localeIdentifier)
    guard let recognizer = SFSpeechRecognizer(locale: locale) else {
      return LegacySpeechEngineStatus(
        available: false,
        recognizerAvailable: nil,
        supportsOnDeviceRecognition: nil
      )
    }

    return LegacySpeechEngineStatus(
      available: true,
      recognizerAvailable: recognizer.isAvailable,
      supportsOnDeviceRecognition: recognizer.supportsOnDeviceRecognition
    )
  }
}

