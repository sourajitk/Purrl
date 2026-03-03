//
//  ClipboardMonitor.swift
//  Purrl
//
//  Created by Daniel Jacob Chittoor on 02/03/26.
//

import AppKit
import Combine

final class ClipboardMonitor: ObservableObject {
    @Published private(set) var lastCleanedResult: CleanedEntry?
    @Published private(set) var pauseUntil: Date?
    @Published var menuBarIcon = "link.badge.plus"
    @Published private(set) var activityLog: [LogEntry] = []

    struct CleanedEntry: Equatable {
        let original: String
        let cleaned: String
        let removedParams: [String]
        let date: Date
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let date: Date
        let original: String
        let cleaned: String?
        let removedParams: [String]
        let skippedReason: String?
    }

    private var timer: DispatchSourceTimer?
    private var debounceTimer: AnyCancellable?
    private var iconResetTimer: AnyCancellable?
    private var terminationObserver: Any?
    private var lastChangeCount: Int

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(500), leeway: .milliseconds(150))
        source.setEventHandler { [weak self] in self?.checkClipboard() }
        source.activate()
        timer = source

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.stop() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        debounceTimer = nil
        iconResetTimer = nil
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
            terminationObserver = nil
        }
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

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: SettingsKeys.autoCleanEnabled),
              !isPaused else { return }

        // Ignore clipboard content that is primarily a file, image, or rich text
        let types = pasteboard.types ?? []
        if types.contains(.fileURL) || types.contains(.png) || types.contains(.tiff) {
            return
        }

        guard let string = pasteboard.string(forType: .string),
              let url = validatedURL(from: string) else { return }

        // Skip sanitization for whitelisted domains
        let whitelistedDomains: [String] = (try? JSONDecoder().decode(
            [String].self,
            from: (defaults.string(forKey: SettingsKeys.whitelistedDomains) ?? "[]").data(using: .utf8) ?? Data()
        )) ?? []
        if let host = url.host, isWhitelisted(host: host, domains: whitelistedDomains) {
            appendLog(LogEntry(date: .now, original: url.absoluteString, cleaned: nil, removedParams: [], skippedReason: "whitelisted"))
            return
        }

        let cleaningMode = defaults.string(forKey: SettingsKeys.cleaningMode) ?? "standard"

        let result: SanitizeResult?
        if cleaningMode == "strict" {
            result = URLSanitizer.sanitizeStrict(url.absoluteString)
        } else {
            let customBlockedParams: [String] = (try? JSONDecoder().decode(
                [String].self,
                from: (defaults.string(forKey: SettingsKeys.customBlockedParams) ?? "[]").data(using: .utf8) ?? Data()
            )) ?? []
            result = URLSanitizer.sanitize(url.absoluteString, additionalParams: customBlockedParams)
        }

        guard case .cleaned(let original, let cleaned, let removedParams) = result else { return }

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

        appendLog(LogEntry(date: .now, original: original, cleaned: cleaned, removedParams: removedParams, skippedReason: nil))

        // Animate menu bar icon
        menuBarIcon = "checkmark.circle"
        iconResetTimer?.cancel()
        iconResetTimer = Just(())
            .delay(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.menuBarIcon = "link.badge.plus" }

    }

    func validatedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.count <= 2048,
              !trimmed.contains("\n"),
              !trimmed.contains(" "),
              !trimmed.contains("\t"),
              !trimmed.hasPrefix("{"),
              !trimmed.hasPrefix("["),
              trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else {
            return nil
        }

        guard let url = URL(string: trimmed),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host, !host.isEmpty else {
            return nil
        }

        // Never modify URLs containing authentication credentials
        if components.user != nil || components.password != nil {
            return nil
        }

        return url
    }

    func appendLog(_ entry: LogEntry) {
        activityLog.insert(entry, at: 0)
        if activityLog.count > 20 {
            activityLog.removeLast(activityLog.count - 20)
        }
    }

    func isWhitelisted(host: String, domains: [String]) -> Bool {
        let normalizedHost = host.lowercased()
        let hostWithoutWWW = normalizedHost.hasPrefix("www.") ? String(normalizedHost.dropFirst(4)) : normalizedHost

        return domains.contains { pattern in
            let p = pattern.lowercased()

            if p.hasPrefix("*.") {
                let suffix = String(p.dropFirst(1)) // ".example.com"
                return normalizedHost.hasSuffix(suffix) || hostWithoutWWW == String(p.dropFirst(2))
            }

            let patternWithoutWWW = p.hasPrefix("www.") ? String(p.dropFirst(4)) : p
            return hostWithoutWWW == patternWithoutWWW
        }
    }
}
