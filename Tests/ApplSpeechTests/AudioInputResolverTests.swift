import Foundation
import Testing
@testable import ApplSpeech

@Suite("Audio Input Resolver")
struct AudioInputResolverTests {
  @Test("Local path resolves to file URL without download")
  func localPath() async throws {
    let resolved = try await AudioInputResolver.resolve("/tmp/a.wav")
    #expect(resolved.localFileURL.isFileURL)
    #expect(resolved.localFileURL.path == "/tmp/a.wav")
  }

  @Test("HTTP URL with unsupported extension throws unsupportedAudioFormat")
  func remoteUnsupportedExtension() async {
    do {
      _ = try await AudioInputResolver.resolve("https://example.com/a.aac")
      #expect(Bool(false))
    } catch let error as TranscriptionError {
      guard case .unsupportedAudioFormat(let path, _) = error else {
        #expect(Bool(false))
        return
      }
      #expect(path.contains("https://example.com/a.aac"))
    } catch {
      #expect(Bool(false))
    }
  }

  @Test("HTTP URL downloads to temp file and cleanup removes it")
  func remoteDownloadAndCleanup() async throws {
    let token = UUID().uuidString
    let session = makeStubSession(token: token) { request in
      let url = try #require(request.url)
      let response = HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data([0x00, 0x01, 0x02]))
    }
    defer { StubURLProtocol.unregisterHandler(token: token) }

    let resolved = try await AudioInputResolver.resolve(
      "https://example.com/a.wav?stub=\(token)",
      urlSession: session
    )

    #expect(resolved.localFileURL.pathExtension.lowercased() == "wav")
    #expect(FileManager.default.fileExists(atPath: resolved.localFileURL.path))

    resolved.cleanup()
    #expect(!FileManager.default.fileExists(atPath: resolved.localFileURL.path))
  }

  @Test("HTTP URL with non-2xx response throws remoteDownloadFailed")
  func remoteDownloadHTTPError() async {
    let token = UUID().uuidString
    let session = makeStubSession(token: token) { request in
      let url = try #require(request.url)
      let response = HTTPURLResponse(
        url: url,
        statusCode: 404,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }
    defer { StubURLProtocol.unregisterHandler(token: token) }

    do {
      _ = try await AudioInputResolver.resolve(
        "https://example.com/a.wav?stub=\(token)",
        urlSession: session
      )
      #expect(Bool(false))
    } catch let error as TranscriptionError {
      #expect(
        error
          == .remoteDownloadFailed(
            url: "https://example.com/a.wav?stub=\(token)",
            statusCode: 404
          )
      )
    } catch {
      #expect(Bool(false))
    }
  }

  @Test("HTTP URL with network error throws remoteDownloadNetworkError")
  func remoteDownloadNetworkError() async {
    let token = UUID().uuidString
    let session = makeStubSession(token: token) { _ in
      throw URLError(.timedOut)
    }
    defer { StubURLProtocol.unregisterHandler(token: token) }

    do {
      _ = try await AudioInputResolver.resolve(
        "https://example.com/a.wav?stub=\(token)",
        urlSession: session
      )
      #expect(Bool(false))
    } catch let error as TranscriptionError {
      #expect(
        error
          == .remoteDownloadNetworkError(
            url: "https://example.com/a.wav?stub=\(token)",
            code: URLError.Code.timedOut.rawValue
          )
      )
    } catch {
      #expect(Bool(false))
    }
  }

  @Test("HTTP URL with non-HTTP response throws remoteDownloadInvalidResponse")
  func remoteDownloadInvalidResponse() async {
    let token = UUID().uuidString
    let session = makeStubSession(token: token) { request in
      let url = try #require(request.url)
      let response = URLResponse(
        url: url,
        mimeType: "application/octet-stream",
        expectedContentLength: 3,
        textEncodingName: nil
      )
      return (response, Data([0x00, 0x01, 0x02]))
    }
    defer { StubURLProtocol.unregisterHandler(token: token) }

    do {
      _ = try await AudioInputResolver.resolve(
        "https://example.com/a.wav?stub=\(token)",
        urlSession: session
      )
      #expect(Bool(false))
    } catch let error as TranscriptionError {
      #expect(
        error
          == .remoteDownloadInvalidResponse(url: "https://example.com/a.wav?stub=\(token)")
      )
    } catch {
      #expect(Bool(false))
    }
  }
}

private func makeStubSession(
  token: String,
  handler: @escaping @Sendable (URLRequest) throws -> (URLResponse, Data)
) -> URLSession {
  StubURLProtocol.registerHandler(token: token, handler: handler)
  let config = URLSessionConfiguration.ephemeral
  config.protocolClasses = [StubURLProtocol.self]
  return URLSession(configuration: config)
}

private final class StubURLProtocol: URLProtocol {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var handlers:
    [String: (@Sendable (URLRequest) throws -> (URLResponse, Data))] = [:]

  static func registerHandler(
    token: String,
    handler: @escaping @Sendable (URLRequest) throws -> (URLResponse, Data)
  ) {
    lock.lock()
    handlers[token] = handler
    lock.unlock()
  }

  static func unregisterHandler(token: String) {
    lock.lock()
    handlers[token] = nil
    lock.unlock()
  }

  private static func handler(for request: URLRequest)
    -> (@Sendable (URLRequest) throws -> (URLResponse, Data))?
  {
    guard let url = request.url,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let token = components.queryItems?.first(where: { $0.name == "stub" })?.value
    else {
      return nil
    }

    lock.lock()
    let value = handlers[token]
    lock.unlock()
    return value
  }

  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = StubURLProtocol.handler(for: request) else {
      client?.urlProtocol(self, didFailWithError: URLError(.unknown))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
