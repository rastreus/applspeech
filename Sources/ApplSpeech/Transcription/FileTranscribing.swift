import Foundation

protocol FileTranscribing: Sendable {
  func transcribeFile(at url: URL) async throws -> String
}
