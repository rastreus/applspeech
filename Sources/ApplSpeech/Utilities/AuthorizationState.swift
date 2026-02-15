import AVFoundation
import Speech

enum AuthorizationState: String, Codable, Sendable {
  case authorized
  case denied
  case restricted
  case notDetermined
  case unknown

  init(speech status: SFSpeechRecognizerAuthorizationStatus) {
    switch status {
    case .authorized:
      self = .authorized
    case .denied:
      self = .denied
    case .restricted:
      self = .restricted
    case .notDetermined:
      self = .notDetermined
    @unknown default:
      self = .unknown
    }
  }

  init(microphone status: AVAuthorizationStatus) {
    switch status {
    case .authorized:
      self = .authorized
    case .denied:
      self = .denied
    case .restricted:
      self = .restricted
    case .notDetermined:
      self = .notDetermined
    @unknown default:
      self = .unknown
    }
  }
}

