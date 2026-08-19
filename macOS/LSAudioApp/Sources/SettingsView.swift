import Foundation
import SwiftUI

struct MenuBarSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            Label(R.L.Settings_GENERAL, systemImage: "gearshape")
                .font(.headline)

            Divider()

            Toggle(R.L.Common_SHOW_IDLE, isOn: $model.showIdle)
            Text(R.L.Settings_IDLE_NOTE)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(R.L.Common_SHOW_PATHS, isOn: $model.showPaths)

            Divider()

            Toggle(
                R.L.Settings_CONFIRM_QUICK_TERMINATION,
                isOn: $model.confirmsQuickTermination
            )
            Text(R.L.Settings_CONFIRM_QUICK_TERMINATION_NOTE)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Picker(R.L.Settings_SORT_BY, selection: $model.sortOrder) {
                ForEach(ProcessSortOrder.allCases) { sortOrder in
                    Text(sortOrder.title).tag(sortOrder)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            Text(credits)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(LSAudioMetrics.menuPadding)
    }

    private var credits: AttributedString {
        (try? AttributedString(markdown: R.L.Settings_CREDITS))
            ?? AttributedString(R.L.Settings_CREDITS)
    }
}

extension ProcessSortOrder {
    var title: String {
        switch self {
        case .activity: R.L.Settings_SORT_ACTIVITY
        case .alphabetical: R.L.Settings_SORT_ALPHABETICAL
        case .pid: R.L.Settings_SORT_PID
        case .device: R.L.Settings_SORT_DEVICE
        }
    }
}
