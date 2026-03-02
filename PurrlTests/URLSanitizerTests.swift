//
//  URLSanitizerTests.swift
//  PurrlTests
//
//  Created by Daniel Jacob Chittoor on 02/03/26.
//

import Testing
@testable import Purrl

struct URLSanitizerTests {

    // MARK: - Unchanged URLs

    @Test func urlWithNoParams() {
        let result = URLSanitizer.sanitize("https://example.com/path")
        #expect(result == .unchanged("https://example.com/path"))
    }

    @Test func urlWithOnlyLegitParams() {
        let result = URLSanitizer.sanitize("https://example.com/search?q=swift&page=2")
        #expect(result == .unchanged("https://example.com/search?q=swift&page=2"))
    }

    // MARK: - Cleaning tracking params

    @Test func urlWithOnlyTrackingParams() {
        let result = URLSanitizer.sanitize("https://example.com/page?utm_source=twitter&utm_medium=social")
        guard case .cleaned(_, let cleaned, let removed) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com/page")
        #expect(Set(removed) == Set(["utm_source", "utm_medium"]))
    }

    @Test func urlWithMixedParams() {
        let result = URLSanitizer.sanitize("https://example.com/page?q=hello&fbclid=abc123&page=1")
        guard case .cleaned(_, let cleaned, let removed) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com/page?q=hello&page=1")
        #expect(removed == ["fbclid"])
    }

    @Test func allKnownTrackingParams() {
        let params = [
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
            "fbclid", "gclid", "gbraid", "wbraid",
            "mc_cid", "mc_eid", "msclkid", "twclid", "igshid",
            "_hsenc", "_hsmi", "oly_enc_id", "oly_anon_id",
            "__s", "vero_id", "dclid", "ref", "ref_src", "ref_url",
            "s_cid", "spm", "_openstat",
        ]
        let query = params.map { "\($0)=val" }.joined(separator: "&")
        let result = URLSanitizer.sanitize("https://example.com?\(query)")
        guard case .cleaned(_, let cleaned, let removed) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com")
        #expect(removed.count == params.count)
    }

    @Test func customUtmParam() {
        let result = URLSanitizer.sanitize("https://example.com?utm_custom_thing=abc&q=1")
        guard case .cleaned(_, let cleaned, let removed) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com?q=1")
        #expect(removed == ["utm_custom_thing"])
    }

    // MARK: - Fragment preservation

    @Test func fragmentPreserved() {
        let result = URLSanitizer.sanitize("https://example.com/page?utm_source=x#section")
        guard case .cleaned(_, let cleaned, _) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com/page#section")
    }

    @Test func fragmentWithNoTracking() {
        let result = URLSanitizer.sanitize("https://example.com/page?q=1#section")
        #expect(result == .unchanged("https://example.com/page?q=1#section"))
    }

    @Test func fragmentWithMixedParams() {
        let result = URLSanitizer.sanitize("https://example.com?keep=1&gclid=abc#top")
        guard case .cleaned(_, let cleaned, _) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com?keep=1#top")
    }

    // MARK: - Encoded characters

    @Test func encodedCharactersInPath() {
        let result = URLSanitizer.sanitize("https://example.com/p%C3%A4th?utm_source=x&q=hello%20world")
        guard case .cleaned(_, let cleaned, _) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com/p%C3%A4th?q=hello%20world")
    }

    @Test func encodedCharactersInParamValue() {
        let result = URLSanitizer.sanitize("https://example.com?q=a%26b&fbclid=123")
        guard case .cleaned(_, let cleaned, _) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com?q=a%26b")
    }

    // MARK: - Edge cases

    @Test func emptyQueryValue() {
        let result = URLSanitizer.sanitize("https://example.com?fbclid=&q=test")
        guard case .cleaned(_, let cleaned, let removed) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com?q=test")
        #expect(removed == ["fbclid"])
    }

    @Test func duplicateTrackingParams() {
        let result = URLSanitizer.sanitize("https://example.com?utm_source=a&utm_source=b&q=1")
        guard case .cleaned(_, let cleaned, let removed) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com?q=1")
        #expect(removed == ["utm_source", "utm_source"])
    }

    @Test func nonURLInput() {
        #expect(URLSanitizer.sanitize("not a url") == nil)
    }

    @Test func emptyString() {
        #expect(URLSanitizer.sanitize("") == nil)
    }

    @Test func pathPreservedExactly() {
        let result = URLSanitizer.sanitize("https://example.com/a/b/c?utm_source=x")
        guard case .cleaned(_, let cleaned, _) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com/a/b/c")
    }

    @Test func originalPreservedInResult() {
        let original = "https://example.com?fbclid=abc123"
        let result = URLSanitizer.sanitize(original)
        guard case .cleaned(let orig, _, _) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(orig == original)
    }

    @Test func caseInsensitiveParamMatching() {
        let result = URLSanitizer.sanitize("https://example.com?UTM_SOURCE=x&q=1")
        guard case .cleaned(_, let cleaned, _) = result else {
            Issue.record("Expected .cleaned result")
            return
        }
        #expect(cleaned == "https://example.com?q=1")
    }
}
