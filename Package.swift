// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "applspeech",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "applspeech", targets: ["ApplSpeech"])
  ],
  targets: [
    .executableTarget(
      name: "ApplSpeech",
      path: "Sources/ApplSpeech"
    )
  ]
)

