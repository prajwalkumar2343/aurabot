import Foundation

enum BrowserContextSource: String, Codable, Sendable {
    case automation
    case extensionData = "extension"
}

enum BrowserActivityKind: String, Codable, Sendable {
    case browsing
    case scrolling
    case media
    case unknown
}

struct BrowserContext: Codable, Sendable {
    let source: BrowserContextSource
    let browser: String
    let bundleIdentifier: String?
    let url: String?
    let title: String?
    let activity: BrowserActivityKind
    let pageID: String?
    let mediaID: String?
    let mediaIsPlaying: Bool
    let scrollPercent: Double?
    let viewportSignature: String?
    let noveltyScore: Double?
    let timestamp: Date

    var sessionKey: String {
        if let mediaID, !mediaID.isEmpty {
            return "media:\(mediaID)"
        }
        if let pageID, !pageID.isEmpty {
            return "page:\(pageID)"
        }
        if let url, !url.isEmpty {
            return "url:\(url)"
        }
        if let title, !title.isEmpty {
            return "title:\(title)"
        }
        return "browser:\(browser)"
    }

    var pageSignature: String {
        if let pageID, !pageID.isEmpty {
            return pageID
        }
        if let url, !url.isEmpty {
            return url
        }
        if let title, !title.isEmpty {
            return title
        }
        return browser
    }

    var llmSummary: String {
        var parts: [String] = ["Browser: \(browser)"]

        if let title, !title.isEmpty {
            parts.append("Title: \(title)")
        }
        if let url, !url.isEmpty {
            parts.append("URL: \(url)")
        }

        switch activity {
        case .media:
            parts.append(mediaIsPlaying ? "Activity: media playback" : "Activity: media page")
        case .scrolling:
            parts.append("Activity: scrolling")
        case .browsing:
            parts.append("Activity: browsing")
        case .unknown:
            break
        }

        return parts.joined(separator: " | ")
    }
}
