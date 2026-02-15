// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "applspeech",
  platforms: [
    // Keep the deployment target compatible with the CI/agent environment.
    // New SpeechTranscriber APIs are conditionally used via availability checks.
    .macOS(.v15)
  ],
  products: [
    .executable(name: "applspeech", targets: ["ApplSpeech"])
  ],
  targets: [
    .executableTarget(
      name: "ApplSpeech",
      path: "Sources/ApplSpeech"
    ),
    .testTarget(
      name: "ApplSpeechTests",
      dependencies: ["ApplSpeech"],
      path: "Tests/ApplSpeechTests"
    )
  ]
)
