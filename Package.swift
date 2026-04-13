// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "AlfredForMe",
  platforms: [
    .macOS(.v13)
  ],
  targets: [
    .executableTarget(
      name: "AlfredForMe",
      path: "AlfredForMe",
      exclude: [
        "Resources/Info.plist", "Resources/AlfredForMe.entitlements", "Resources/AppIcon.icns",
        "Resources/AppIcon_preview.png",
      ],
      swiftSettings: [
        .unsafeFlags(["-parse-as-library"])
      ]
    )
  ]
)
