//
//  ClipboardMonitor.swift
//  Purrl
//
//  Created by Daniel Jacob Chittoor on 02/03/26.
//

import AppKit
import Combine

final class ClipboardMonitor: ObservableObject {
    @Published var autoCleanEnabled = true
    @Published private(set) var lastCleanedResult: CleanedEntry?
    @Published private(set) var pauseUntil: Date?

    struct CleanedEntry: Equatable {
        let original: String
        let cleaned: String
        let removedParams: [String]
        let date: Date
    }

    private var timer: AnyCancellable?
    private var debounceTimer: AnyCancellable?
    private var lastChangeCount: Int

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkClipboard() }
    }

    func stop() {
        timer = nil
        debounceTimer = nil
    }

    func pauseForOneHour() {
        pauseUntil = Date.now + 3600
    }

    func resumeFromPause() {
        pauseUntil = nil
    }

    var isPaused: Bool {
        guard let pauseUntil else { return false }
        return Date.now < pauseUntil
    }

    // MARK: - Private

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard autoCleanEnabled,
              !isPaused else { return }

        guard let string = pasteboard.string(forType: .string),
              let url = validatedURL(from: string) else { return }

        guard let result = URLSanitizer.sanitize(url.absoluteString),
              case .cleaned(let original, let cleaned, let removedParams) = result else { return }

        // Debounce: wait 150ms before writing back
        debounceTimer?.cancel()
        debounceTimer = Just(())
            .delay(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.writeCleanedURL(original: original, cleaned: cleaned, removedParams: removedParams)
            }
    }

    private func writeCleanedURL(original: String, cleaned: String, removedParams: [String]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(cleaned, forType: .string)

        // Update changeCount so we don't re-trigger on our own write
        lastChangeCount = pasteboard.changeCount

        lastCleanedResult = CleanedEntry(
            original: original,
            cleaned: cleaned,
            removedParams: removedParams,
            date: .now
        )
    }

    private func validatedURL(from string: String) -> URL? {
        guard string.count < 2048,
              !string.contains("\n"),
              !string.hasPrefix("{"),
              !string.hasPrefix("["),
              string.hasPrefix("http://") || string.hasPrefix("https://") else {
            return nil
        }

        guard let url = URL(string: string),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host, !host.isEmpty else {
            return nil
        }

        return url
    }
}
