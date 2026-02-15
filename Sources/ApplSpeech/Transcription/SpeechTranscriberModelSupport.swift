import Foundation
import Speech

struct SpeechTranscriberModelStatus: Codable, Sendable {
  let available: Bool
  let supportedLocale: String?
  let modelInstalled: Bool?
}

enum SpeechTranscriberModelSupport {
  static func status(localeIdentifier: String) async -> SpeechTranscriberModelStatus {
    if #available(macOS 26.0, *) {
      let requested = Locale(identifier: localeIdentifier)
      guard let supported = await supportedLocale(equivalentTo: requested) else {
        return SpeechTranscriberModelStatus(
          available: true,
          supportedLocale: nil,
          modelInstalled: false
        )
      }

      let installed = await SpeechTranscriber.installedLocales
      let installedSet = Set(installed.map { normalizeLocaleIdentifier($0.identifier) })
      let modelInstalled = installedSet.contains(normalizeLocaleIdentifier(supported.identifier))

      return SpeechTranscriberModelStatus(
        available: true,
        supportedLocale: supported.identifier,
        modelInstalled: modelInstalled
      )
    }

    return SpeechTranscriberModelStatus(
      available: false,
      supportedLocale: nil,
      modelInstalled: nil
    )
  }

  static func ensureInstalled(localeIdentifier: String) async throws(SpeechEnvironmentError) {
    guard #available(macOS 26.0, *) else {
      throw .speechTranscriberNotAvailable
    }

    let requested = Locale(identifier: localeIdentifier)
    guard let supported = await supportedLocale(equivalentTo: requested) else {
      throw .speechTranscriberLocaleUnsupported(localeIdentifier: localeIdentifier)
    }

    let installed = await SpeechTranscriber.installedLocales
    let installedSet = Set(installed.map { normalizeLocaleIdentifier($0.identifier) })
    if installedSet.contains(normalizeLocaleIdentifier(supported.identifier)) {
      return
    }

    let transcriber = SpeechTranscriber(locale: supported, preset: .progressiveTranscription)
    let modules: [any SpeechModule] = [transcriber]

    do {
      if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
        try await request.downloadAndInstall()
      }
    } catch {
      throw .speechTranscriberModelInstallFailed(message: String(describing: error))
    }
  }

  @available(macOS 26.0, *)
  private static func supportedLocale(equivalentTo locale: Locale) async -> Locale? {
    if let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
      return supported
    }

    let supportedLocales = await SpeechTranscriber.supportedLocales
    let normalizedTarget = normalizeLocaleIdentifier(locale.identifier)
    if let exact = supportedLocales.first(where: {
      normalizeLocaleIdentifier($0.identifier) == normalizedTarget
    }) {
      return exact
    }

    return nil
  }
}

private func normalizeLocaleIdentifier(_ identifier: String) -> String {
  identifier.replacingOccurrences(of: "_", with: "-").lowercased()
}
