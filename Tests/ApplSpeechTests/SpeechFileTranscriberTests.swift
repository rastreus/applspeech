import Foundation
import Testing
@testable import ApplSpeech

@Suite("Speech File Transcriber")
struct SpeechFileTranscriberTests {
  @Test("Missing file throws fileNotFound")
  func missingFile() async {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("wav")

    do {
      _ = try await SpeechFileTranscriber().transcribeFile(at: url)
      #expect(Bool(false))
    } catch let error as TranscriptionError {
      #expect(error == .fileNotFound(path: url.path))
    } catch {
      #expect(Bool(false))
    }
  }

  @Test("Unsupported extension throws unsupportedAudioFormat")
  func unsupportedExtension() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let url = dir.appendingPathComponent("a.aac")
    try Data().write(to: url)

    do {
      _ = try await SpeechFileTranscriber().transcribeFile(at: url)
      #expect(Bool(false))
    } catch let error as TranscriptionError {
      guard case .unsupportedAudioFormat(let path, let supported) = error else {
        #expect(Bool(false))
        return
      }

      #expect(path == url.path)
      #expect(
        supported.map(\.rawValue).sorted()
          == SupportedAudioFormat.allCases.map(\.rawValue).sorted()
      )
    } catch {
      #expect(Bool(false))
    }
  }
}
