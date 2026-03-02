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

    static func sanitize(_ urlString: String) -> SanitizeResult? {
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
            if isTrackingParam(name) {
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

    private static func isTrackingParam(_ name: String) -> Bool {
        let lowered = name.lowercased()
        if trackingParams.contains(lowered) { return true }
        if lowered.hasPrefix("utm_") { return true }
        return false
    }
}
