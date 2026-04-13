import AppKit
import SwiftUI

@main
enum AlfredForMeApp {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }
}
