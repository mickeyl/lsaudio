import SwiftUI

@main
struct LSAudioApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window(R.L.App_PROCESSES_WINDOW, id: "processes") {
            MainWindowView()
                .environment(model)
        }
        .defaultSize(width: 1_180, height: 720)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
        .commands {
            CommandGroup(replacing: .newItem) {
                OpenProcessWindowButton()
            }
            CommandGroup(after: .toolbar) {
                Button(R.L.Common_REFRESH) { model.refresh() }
                    .keyboardShortcut("r")
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environment(model)
        } label: {
            MenuBarLabel(
                outputCount: model.lastUpdated == nil ? nil : model.outputCount,
                inputCount: model.lastUpdated == nil ? nil : model.inputCount
            )
            .task { model.start() }
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let outputCount: Int?
    let inputCount: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Image(systemName: "waveform")
            if let outputCount, let inputCount {
                Text(verbatim: "\(outputCount)\u{00b7}\(inputCount)")
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .padding(.top, 4)
            }
        }
        .font(.body)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let outputCount, let inputCount else { return R.L.App_NAME }
        return R.L.MenuBar_COUNT_ACCESSIBILITY(
            R.L.Count_PLAYING(outputCount),
            R.L.Count_RECORDING(inputCount)
        )
    }
}

private struct OpenProcessWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(R.L.Common_OPEN_WINDOW) {
            openWindow(id: "processes")
            NSApplication.shared.activate()
        }
        .keyboardShortcut("1")
    }
}
