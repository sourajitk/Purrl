//
//  URLSanitizer.swift
//  Purrl
//
//  Created by Daniel Jacob Chittoor on 02/03/26.
//

import Foundation

enum SanitizeResult: Equatable {
    case unchanged(String)
    case cleaned(original: String, cleaned: String, removedParams: [String])
}

struct URLSanitizer {
    private static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
        "fbclid", "gclid", "gbraid", "wbraid",
        "mc_cid", "mc_eid",
        "msclkid", "twclid", "igshid",
        "_hsenc", "_hsmi",
        "oly_enc_id", "oly_anon_id",
        "__s", "vero_id", "dclid",
        "ref", "ref_src", "ref_url",
        "s_cid", "spm", "_openstat",
    ]

    static func sanitize(_ urlString: String, additionalParams: [String] = []) -> SanitizeResult? {
        let extraParams = Set(additionalParams.map { $0.lowercased() })
        guard var components = URLComponents(string: urlString),
              components.host != nil else {
            return nil
        }

        guard let queryItems = components.queryItems, !queryItems.isEmpty else {
            return .unchanged(urlString)
        }

        var removedParams: [String] = []
        var keptItems: [URLQueryItem] = []

        for item in queryItems {
            let name = item.name
            if isTrackingParam(name) || extraParams.contains(name.lowercased()) {
                removedParams.append(name)
            } else {
                keptItems.append(item)
            }
        }

        guard !removedParams.isEmpty else {
            return .unchanged(urlString)
        }

        components.queryItems = keptItems.isEmpty ? nil : keptItems
        guard let cleaned = components.string else { return nil }

        return .cleaned(original: urlString, cleaned: cleaned, removedParams: removedParams)
    }

    private static let allowedParams: Set<String> = [
        "q", "query", "search", "v", "id", "p", "pid", "page", "start", "offset",
        "t", "time", "timestamp", "sort", "order", "orderby", "lang", "locale", "hl",
        "tab", "section", "view", "limit", "per_page", "count", "format", "type",
    ]

    static func sanitizeStrict(_ urlString: String) -> SanitizeResult? {
        guard var components = URLComponents(string: urlString),
              components.host != nil else {
            return nil
        }

        guard let queryItems = components.queryItems, !queryItems.isEmpty else {
            return .unchanged(urlString)
        }

        var removedParams: [String] = []
        var keptItems: [URLQueryItem] = []

        for item in queryItems {
            let name = item.name
            if allowedParams.contains(name.lowercased()) {
                keptItems.append(item)
            } else {
                removedParams.append(name)
            }
        }

        guard !removedParams.isEmpty else {
            return .unchanged(urlString)
        }

        components.queryItems = keptItems.isEmpty ? nil : keptItems
        guard let cleaned = components.string else { return nil }

        return .cleaned(original: urlString, cleaned: cleaned, removedParams: removedParams)
    }

    private static func isTrackingParam(_ name: String) -> Bool {
        let lowered = name.lowercased()
        if trackingParams.contains(lowered) { return true }
        if lowered.hasPrefix("utm_") { return true }
        return false
    }
}
