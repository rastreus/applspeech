import Foundation

struct ResolvedAudioInput: Sendable {
  let localFileURL: URL
  let cleanup: @Sendable () -> Void
}

enum AudioInputResolver {
  static func resolve(
    _ input: String,
    fileManager: FileManager = .default,
    urlSession: URLSession = .shared,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) async throws -> ResolvedAudioInput {
    if let url = URL(string: input), let scheme = url.scheme?.lowercased() {
      if scheme == "file" {
        return ResolvedAudioInput(localFileURL: url, cleanup: {})
      }

      if scheme == "tg" || scheme == "telegram" {
        guard let fileID = TelegramBotAPI.fileID(from: url) else {
          throw TranscriptionError.telegramInvalidFileID
        }

        guard let botToken = environment["TELEGRAM_BOT_TOKEN"], !botToken.isEmpty else {
          throw TranscriptionError.telegramMissingBotToken
        }

        let filePath = try await TelegramBotAPI.getFilePath(
          fileID: fileID,
          botToken: botToken,
          urlSession: urlSession
        )

        let extensionLowercased = URL(fileURLWithPath: filePath).pathExtension.lowercased()
        guard SupportedAudioFormat(rawValue: extensionLowercased) != nil else {
          throw TranscriptionError.unsupportedAudioFormat(
            path: "telegram:\(filePath)",
            supported: Array(SupportedAudioFormat.allCases)
          )
        }

        let data = try await TelegramBotAPI.downloadFile(
          filePath: filePath,
          botToken: botToken,
          urlSession: urlSession
        )

        let destination = fileManager.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension(extensionLowercased)
        try data.write(to: destination, options: [.atomic])

        return ResolvedAudioInput(
          localFileURL: destination,
          cleanup: { try? FileManager.default.removeItem(at: destination) }
        )
      }

      if scheme == "http" || scheme == "https" {
        guard SupportedAudioFormat.from(url) != nil else {
          throw TranscriptionError.unsupportedAudioFormat(
            path: url.absoluteString,
            supported: Array(SupportedAudioFormat.allCases)
          )
        }

        let (data, response): (Data, URLResponse)
        do {
          (data, response) = try await urlSession.data(from: url)
        } catch let error as URLError {
          throw TranscriptionError.remoteDownloadNetworkError(
            url: url.absoluteString,
            code: error.code.rawValue
          )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
          throw TranscriptionError.remoteDownloadInvalidResponse(url: url.absoluteString)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
          throw TranscriptionError.remoteDownloadFailed(
            url: url.absoluteString,
            statusCode: httpResponse.statusCode
          )
        }

        let destination = fileManager.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension(url.pathExtension)
        try data.write(to: destination, options: [.atomic])

        return ResolvedAudioInput(
          localFileURL: destination,
          cleanup: { try? FileManager.default.removeItem(at: destination) }
        )
      }
    }

    // Handle stdin pipe: "cat audio.m4a | applspeech transcribe -"
    if input == "-" {
      let data = FileHandle.standardInput.readDataToEndOfFile()
      guard !data.isEmpty else {
        throw TranscriptionError.stdinEmpty
      }

      // Try to detect format from initial bytes, default to m4a
      let format = detectFormatFromData(data) ?? .m4a
      let destination = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(format.rawValue)
      try data.write(to: destination, options: [.atomic])

      return ResolvedAudioInput(
        localFileURL: destination,
        cleanup: { try? FileManager.default.removeItem(at: destination) }
      )
    }

    return ResolvedAudioInput(localFileURL: URL(fileURLWithPath: input), cleanup: {})
  }
}

private func detectFormatFromData(_ data: Data) -> SupportedAudioFormat? {
  // WAV: starts with "RIFF"
  if data.count >= 4 {
    let header = String(data: data.prefix(4), encoding: .ascii)
    if header == "RIFF" { return .wav }
  }
  // FLAC: starts with "fLaC"
  if data.count >= 4 {
    let header = String(data: data.prefix(4), encoding: .ascii)
    if header == "fLaC" { return .flac }
  }
  // MP3: starts with ID3 or $FF $FB
  if data.count >= 2 {
    let bytes = data.prefix(2)
    if bytes[0] == 0xFF { return .mp3 }
    if bytes[0] == 0x49 && bytes[1] == 0x44 { return .mp3 }  // ID3
  }
  // M4A/OGG: check common patterns - default to m4a for now
  // Could check for ftyp atom for M4A
  return .m4a
}

private enum TelegramBotAPI {
  static func fileID(from url: URL) -> String? {
    if let host = url.host, !host.isEmpty { return host }
    let trimmed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return trimmed.isEmpty ? nil : trimmed
  }

  static func getFilePath(fileID: String, botToken: String, urlSession: URLSession) async throws
    -> String
  {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.telegram.org"
    components.path = "/bot\(botToken)/getFile"
    components.queryItems = [URLQueryItem(name: "file_id", value: fileID)]

    guard let url = components.url else {
      throw TranscriptionError.telegramAPIInvalidPayload(operation: "getFile")
    }

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await urlSession.data(from: url)
    } catch let error as URLError {
      throw TranscriptionError.telegramAPINetworkError(
        operation: "getFile", code: error.code.rawValue)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw TranscriptionError.telegramAPIInvalidResponse(operation: "getFile")
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw TranscriptionError.telegramAPIRequestFailed(
        operation: "getFile",
        statusCode: httpResponse.statusCode
      )
    }

    let decoded: TelegramGetFileResponse
    do {
      decoded = try JSONDecoder().decode(TelegramGetFileResponse.self, from: data)
    } catch {
      throw TranscriptionError.telegramAPIInvalidPayload(operation: "getFile")
    }

    guard decoded.ok, let filePath = decoded.result?.filePath, !filePath.isEmpty else {
      throw TranscriptionError.telegramAPIInvalidPayload(operation: "getFile")
    }

    return filePath
  }

  static func downloadFile(filePath: String, botToken: String, urlSession: URLSession) async throws
    -> Data
  {
    guard let url = URL(string: "https://api.telegram.org/file/bot\(botToken)/\(filePath)") else {
      throw TranscriptionError.telegramAPIInvalidPayload(operation: "download")
    }

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await urlSession.data(from: url)
    } catch let error as URLError {
      throw TranscriptionError.telegramAPINetworkError(
        operation: "download", code: error.code.rawValue)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw TranscriptionError.telegramAPIInvalidResponse(operation: "download")
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw TranscriptionError.telegramAPIRequestFailed(
        operation: "download",
        statusCode: httpResponse.statusCode
      )
    }

    return data
  }
}

private struct TelegramGetFileResponse: Decodable, Sendable {
  let ok: Bool
  let result: TelegramGetFileResult?

  struct TelegramGetFileResult: Decodable, Sendable {
    let filePath: String

    enum CodingKeys: String, CodingKey {
      case filePath = "file_path"
    }
  }
}
