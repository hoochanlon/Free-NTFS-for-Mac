import SwiftUI
import AppKit

@main
struct NigateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Nigate", id: "main") {
            RootView()
                .environmentObject(model)
                .nigateDisableFullScreen()
                .task {
                    appDelegate.model = model
                    model.bindOpenMainWindow { openWindow(id: "main") }
                    model.noteMainWindowOnScreen()
                    await model.bootstrap()
                }
        }
        .defaultSize(width: WindowLayout.width, height: WindowLayout.minHeight)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.t("app.about")) { model.aboutOpen = true }
            }
            CommandGroup(replacing: .appTermination) {
                Button(L10n.t("menu.quit")) { model.requestQuit() }
                    .keyboardShortcut("q")
            }
            CommandGroup(replacing: .help) {
                Button(L10n.t("menu.guide")) { model.setTab(.help) }
                Button(L10n.t("menu.github")) {
                    if let url = URL(string: githubRepo + "/issues") { NSWorkspace.shared.open(url) }
                }
            }
        }
    }
}
