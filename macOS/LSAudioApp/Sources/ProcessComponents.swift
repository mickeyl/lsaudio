import AppKit
import LSAudioCore
import SwiftUI

struct ProcessIcon: View {
    let process: AudioProcess
    var size: CGFloat = 28

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        if let app = NSRunningApplication(processIdentifier: process.pid), let icon = app.icon {
            return icon
        }
        if let path = process.executablePath {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSImage(systemSymbolName: "waveform", accessibilityDescription: nil) ?? NSImage()
    }
}

struct ActivityBadges: View {
    let process: AudioProcess
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            if process.isRunningOutput {
                activityBadge(
                    title: compact ? nil : R.L.Activity_PLAYING,
                    systemImage: "speaker.wave.2.fill",
                    tint: LSAudioTheme.output
                )
            }
            if process.isRunningInput {
                activityBadge(
                    title: compact ? nil : R.L.Activity_RECORDING,
                    systemImage: "mic.fill",
                    tint: LSAudioTheme.input
                )
            }
            if !process.isActive {
                activityBadge(
                    title: compact ? nil : R.L.Activity_IDLE,
                    systemImage: "pause.fill",
                    tint: LSAudioTheme.idle
                )
            }
        }
    }

    private func activityBadge(title: String?, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            if let title { Text(title) }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, LSAudioMetrics.badgeHorizontalPadding)
        .padding(.vertical, LSAudioMetrics.badgeVerticalPadding)
        .background(tint.opacity(0.12), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

struct ProcessSummaryRow: View {
    let process: AudioProcess

    var body: some View {
        HStack(spacing: 10) {
            ProcessIcon(process: process)
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ActivityBadges(process: process, compact: true)
        }
        .padding(.vertical, LSAudioMetrics.rowVerticalPadding)
        .contentShape(.rect)
    }

    private var subtitle: String {
        let identity = process.bundleID ?? "PID \(process.pid)"
        guard let device = process.deviceNames.first, !device.isEmpty else { return identity }
        return "\(identity) · \(device)"
    }
}

extension AudioProcess {
    var localizedActivityDescription: String {
        switch (isRunningOutput, isRunningInput) {
        case (true, true): R.L.Activity_PLAYING_RECORDING
        case (true, false): R.L.Activity_PLAYING
        case (false, true): R.L.Activity_RECORDING
        case (false, false): R.L.Activity_IDLE
        }
    }
}
