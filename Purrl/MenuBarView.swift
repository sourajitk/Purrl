//
//  MenuBarView.swift
//  Purrl
//
//  Created by Daniel Jacob Chittoor on 02/03/26.
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var monitor: ClipboardMonitor

    var body: some View {
        Toggle("Auto-clean: \(monitor.autoCleanEnabled ? "ON" : "OFF")", isOn: $monitor.autoCleanEnabled)

        Button(pauseButtonLabel) {
            if monitor.isPaused {
                monitor.resumeFromPause()
            } else {
                monitor.pauseForOneHour()
            }
        }

        Divider()

        Text(lastCleanedLabel)

        Divider()

        Button("Settings...") {
            // TODO: open settings window
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit Purrl") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var pauseButtonLabel: String {
        monitor.isPaused ? "Resume" : "Pause for 1 hour"
    }

    private var lastCleanedLabel: String {
        guard let entry = monitor.lastCleanedResult else {
            return "Last cleaned: none"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last cleaned: \(formatter.localizedString(for: entry.date, relativeTo: .now))"
    }
}
