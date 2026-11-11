import SwiftUI
import AppKit

@main
struct NigateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Nigate", id: "main") {
            RootView()
                .environmentObject(model)
                .task {
                    appDelegate.model = model
                    await model.bootstrap()
                }
        }
        .defaultSize(width: 900, height: 680)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.t("app.about")) { model.aboutOpen = true }
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
