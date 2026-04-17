// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "AlfredForMe",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(url: "https://github.com/nicklockwood/Expression.git", from: "0.13.0")
  ],
  targets: [
    .executableTarget(
      name: "AlfredForMe",
      dependencies: [
        .product(name: "Expression", package: "Expression")
      ],
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
