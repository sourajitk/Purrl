//
//  PurrlApp.swift
//  Purrl
//
//  Created by Daniel Jacob Chittoor on 02/03/26.
//

import SwiftUI

@main
struct PurrlApp: App {
    @StateObject private var clipboardMonitor = ClipboardMonitor()

    init() {
        SettingsKeys.registerDefaults()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: clipboardMonitor)
                .onAppear { clipboardMonitor.start() }
        } label: {
            Image(systemName: clipboardMonitor.menuBarIcon)
        }

        Settings {
            SettingsView()
        }
    }
}
