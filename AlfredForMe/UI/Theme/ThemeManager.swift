import AppKit
import SwiftUI

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
  case light = "light"
  case dark = "dark"
  case system = "system"

  var id: String { rawValue }

  var displayName: String {
    LocalizationManager.shared.t(
      self == .light ? "appearance.light" : self == .dark ? "appearance.dark" : "appearance.system"
    )
  }
}

// MARK: - Theme Manager

final class ThemeManager: ObservableObject {
  static let shared = ThemeManager()

  @Published var current: AppTheme
  @Published var availableThemes: [AppTheme]
  @Published var appearanceMode: AppearanceMode {
    didSet {
      UserDefaults.standard.set(appearanceMode.rawValue, forKey: "AppearanceMode")
      applyAppearanceMode()
    }
  }

  private var appearanceObserver: NSObjectProtocol?

  private init() {
    let themes = AppTheme.builtInThemes
    self.availableThemes = themes

    // Migrate old Chinese rawValues to English
    let savedRaw = UserDefaults.standard.string(forKey: "AppearanceMode") ?? "system"
    let migratedRaw: String
    switch savedRaw {
    case "浅色": migratedRaw = "light"
    case "深色": migratedRaw = "dark"
    case "跟随系统": migratedRaw = "system"
    default: migratedRaw = savedRaw
    }
    let savedMode = AppearanceMode(rawValue: migratedRaw) ?? .system
    self.appearanceMode = savedMode
    if migratedRaw != savedRaw {
      UserDefaults.standard.set(migratedRaw, forKey: "AppearanceMode")
    }

    let savedThemeName = SettingsManager.shared.selectedTheme
    self.current = themes.first { $0.name == savedThemeName } ?? themes[0]

    setupAppearanceObserver()
    applyAppearanceMode()
  }

  func apply(theme: AppTheme) {
    current = theme
    SettingsManager.shared.selectedTheme = theme.name
  }

  func addCustomTheme(_ theme: AppTheme) {
    availableThemes.append(theme)
  }

  private func setupAppearanceObserver() {
    appearanceObserver = DistributedNotificationCenter.default().addObserver(
      forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self = self, self.appearanceMode == .system else { return }
      self.applySystemAppearance()
    }
  }

  private func applyAppearanceMode() {
    switch appearanceMode {
    case .light:
      NSApp.appearance = NSAppearance(named: .aqua)
      apply(theme: .macOSLight)
    case .dark:
      NSApp.appearance = NSAppearance(named: .darkAqua)
      apply(theme: .macOSDark)
    case .system:
      NSApp.appearance = nil  // Follow system
      applySystemAppearance()
    }
  }

  private func applySystemAppearance() {
    let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    let theme: AppTheme = isDark ? .macOSDark : .macOSLight
    apply(theme: theme)
  }

  deinit {
    if let observer = appearanceObserver {
      DistributedNotificationCenter.default().removeObserver(observer)
    }
  }
}

// MARK: - App Theme

struct AppTheme: Identifiable, Equatable {
  let id: String
  let name: String
  let backgroundColor: Color
  let textColor: Color
  let subtitleColor: Color
  let placeholderColor: Color
  let selectedColor: Color
  let accentColor: Color
  let borderColor: Color
  let separatorColor: Color
  let fontSize: CGFloat
  let searchBarBackgroundColor: Color

  static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
    lhs.id == rhs.id
  }

  // MARK: - Built-in Themes

  static let builtInThemes: [AppTheme] = [
    alfredClassic,
    alfredDark,
    macOSLight,
    macOSDark,
    monokai,
    solarizedDark,
    solarizedLight,
    nord,
    dracula,
    oneDark,
  ]

  static let alfredClassic = AppTheme(
    id: "alfred-classic",
    name: "Alfred Classic",
    backgroundColor: Color(red: 0.95, green: 0.95, blue: 0.95),
    textColor: Color(red: 0.1, green: 0.1, blue: 0.1),
    subtitleColor: Color(red: 0.5, green: 0.5, blue: 0.5),
    placeholderColor: Color(red: 0.6, green: 0.6, blue: 0.6),
    selectedColor: Color(red: 0.85, green: 0.85, blue: 0.9),
    accentColor: Color(red: 0.3, green: 0.5, blue: 0.9),
    borderColor: Color(red: 0.8, green: 0.8, blue: 0.8),
    separatorColor: Color(red: 0.85, green: 0.85, blue: 0.85),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.98, green: 0.98, blue: 0.98)
  )

  static let alfredDark = AppTheme(
    id: "alfred-dark",
    name: "Alfred Dark",
    backgroundColor: Color(red: 0.15, green: 0.15, blue: 0.17),
    textColor: Color(red: 0.9, green: 0.9, blue: 0.9),
    subtitleColor: Color(red: 0.6, green: 0.6, blue: 0.6),
    placeholderColor: Color(red: 0.5, green: 0.5, blue: 0.5),
    selectedColor: Color(red: 0.25, green: 0.25, blue: 0.3),
    accentColor: Color(red: 0.4, green: 0.6, blue: 1.0),
    borderColor: Color(red: 0.25, green: 0.25, blue: 0.28),
    separatorColor: Color(red: 0.2, green: 0.2, blue: 0.22),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.12, green: 0.12, blue: 0.14)
  )

  static let macOSLight = AppTheme(
    id: "macos-light",
    name: "macOS Light",
    backgroundColor: Color(nsColor: .windowBackgroundColor),
    textColor: Color(nsColor: .labelColor),
    subtitleColor: Color(nsColor: .secondaryLabelColor),
    placeholderColor: Color(nsColor: .placeholderTextColor),
    selectedColor: Color(nsColor: .selectedContentBackgroundColor),
    accentColor: Color.accentColor,
    borderColor: Color(nsColor: .separatorColor),
    separatorColor: Color(nsColor: .separatorColor),
    fontSize: 18,
    searchBarBackgroundColor: Color(nsColor: .controlBackgroundColor)
  )

  static let macOSDark = AppTheme(
    id: "macos-dark",
    name: "macOS Dark",
    backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.14),
    textColor: Color.white,
    subtitleColor: Color(red: 0.6, green: 0.6, blue: 0.65),
    placeholderColor: Color(red: 0.45, green: 0.45, blue: 0.5),
    selectedColor: Color(red: 0.22, green: 0.22, blue: 0.27),
    accentColor: Color.blue,
    borderColor: Color(red: 0.2, green: 0.2, blue: 0.23),
    separatorColor: Color(red: 0.18, green: 0.18, blue: 0.2),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.1, green: 0.1, blue: 0.12)
  )

  static let monokai = AppTheme(
    id: "monokai",
    name: "Monokai",
    backgroundColor: Color(red: 0.16, green: 0.16, blue: 0.14),
    textColor: Color(red: 0.97, green: 0.97, blue: 0.95),
    subtitleColor: Color(red: 0.6, green: 0.6, blue: 0.52),
    placeholderColor: Color(red: 0.46, green: 0.44, blue: 0.36),
    selectedColor: Color(red: 0.26, green: 0.26, blue: 0.22),
    accentColor: Color(red: 0.4, green: 0.85, blue: 0.94),
    borderColor: Color(red: 0.3, green: 0.3, blue: 0.25),
    separatorColor: Color(red: 0.22, green: 0.22, blue: 0.18),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.14, green: 0.14, blue: 0.12)
  )

  static let solarizedDark = AppTheme(
    id: "solarized-dark",
    name: "Solarized Dark",
    backgroundColor: Color(red: 0.0, green: 0.17, blue: 0.21),
    textColor: Color(red: 0.51, green: 0.58, blue: 0.59),
    subtitleColor: Color(red: 0.4, green: 0.48, blue: 0.51),
    placeholderColor: Color(red: 0.33, green: 0.41, blue: 0.43),
    selectedColor: Color(red: 0.03, green: 0.21, blue: 0.26),
    accentColor: Color(red: 0.15, green: 0.55, blue: 0.82),
    borderColor: Color(red: 0.03, green: 0.21, blue: 0.26),
    separatorColor: Color(red: 0.03, green: 0.21, blue: 0.26),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.0, green: 0.15, blue: 0.19)
  )

  static let solarizedLight = AppTheme(
    id: "solarized-light",
    name: "Solarized Light",
    backgroundColor: Color(red: 0.99, green: 0.96, blue: 0.89),
    textColor: Color(red: 0.4, green: 0.48, blue: 0.51),
    subtitleColor: Color(red: 0.51, green: 0.58, blue: 0.59),
    placeholderColor: Color(red: 0.58, green: 0.63, blue: 0.63),
    selectedColor: Color(red: 0.93, green: 0.91, blue: 0.84),
    accentColor: Color(red: 0.15, green: 0.55, blue: 0.82),
    borderColor: Color(red: 0.93, green: 0.91, blue: 0.84),
    separatorColor: Color(red: 0.93, green: 0.91, blue: 0.84),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.93, green: 0.91, blue: 0.84)
  )

  static let nord = AppTheme(
    id: "nord",
    name: "Nord",
    backgroundColor: Color(red: 0.18, green: 0.2, blue: 0.25),
    textColor: Color(red: 0.85, green: 0.87, blue: 0.91),
    subtitleColor: Color(red: 0.62, green: 0.67, blue: 0.74),
    placeholderColor: Color(red: 0.44, green: 0.5, blue: 0.56),
    selectedColor: Color(red: 0.23, green: 0.26, blue: 0.32),
    accentColor: Color(red: 0.53, green: 0.75, blue: 0.82),
    borderColor: Color(red: 0.26, green: 0.3, blue: 0.37),
    separatorColor: Color(red: 0.23, green: 0.26, blue: 0.32),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.16, green: 0.18, blue: 0.23)
  )

  static let dracula = AppTheme(
    id: "dracula",
    name: "Dracula",
    backgroundColor: Color(red: 0.16, green: 0.16, blue: 0.21),
    textColor: Color(red: 0.97, green: 0.97, blue: 0.95),
    subtitleColor: Color(red: 0.62, green: 0.63, blue: 0.76),
    placeholderColor: Color(red: 0.48, green: 0.49, blue: 0.55),
    selectedColor: Color(red: 0.27, green: 0.28, blue: 0.35),
    accentColor: Color(red: 0.74, green: 0.58, blue: 0.98),
    borderColor: Color(red: 0.27, green: 0.28, blue: 0.35),
    separatorColor: Color(red: 0.22, green: 0.23, blue: 0.29),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.14, green: 0.14, blue: 0.19)
  )

  static let oneDark = AppTheme(
    id: "one-dark",
    name: "One Dark",
    backgroundColor: Color(red: 0.17, green: 0.19, blue: 0.22),
    textColor: Color(red: 0.67, green: 0.73, blue: 0.81),
    subtitleColor: Color(red: 0.5, green: 0.55, blue: 0.61),
    placeholderColor: Color(red: 0.39, green: 0.43, blue: 0.47),
    selectedColor: Color(red: 0.21, green: 0.24, blue: 0.28),
    accentColor: Color(red: 0.38, green: 0.65, blue: 0.95),
    borderColor: Color(red: 0.24, green: 0.27, blue: 0.32),
    separatorColor: Color(red: 0.2, green: 0.22, blue: 0.26),
    fontSize: 18,
    searchBarBackgroundColor: Color(red: 0.15, green: 0.17, blue: 0.2)
  )
}
