import Foundation

enum BrowserContextSource: String, Codable, Sendable {
    case automation
    case extensionData = "extension"
}

enum BrowserContextSourceQuality: String, Codable, Equatable, Sendable {
    case extensionFull = "extension_full"
    case extensionMetadataOnly = "extension_metadata_only"
    case extensionPrivate = "extension_private"
    case automationFallback = "automation_fallback"
}

enum BrowserActivityKind: String, Codable, Sendable {
    case browsing
    case scrolling
    case media
    case unknown
}

struct BrowserContext: Codable, Sendable {
    static let visibleTextMemoryLimit = 700
    static let selectedTextMemoryLimit = 500
    static let readableTextMemoryLimit = 900

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
    let visibleText: String?
    let selectedText: String?
    let readableText: String?
    let visibleTextHash: String?
    let readableTextHash: String?
    let textCaptureMode: String?
    let privateWindow: Bool
    let schemaVersion: Int
    let captureID: String?
    let sourceQuality: BrowserContextSourceQuality
    let timestamp: Date

    init(
        source: BrowserContextSource,
        browser: String,
        bundleIdentifier: String?,
        url: String?,
        title: String?,
        activity: BrowserActivityKind,
        pageID: String?,
        mediaID: String?,
        mediaIsPlaying: Bool,
        scrollPercent: Double?,
        viewportSignature: String?,
        noveltyScore: Double?,
        visibleText: String?,
        selectedText: String?,
        readableText: String?,
        visibleTextHash: String?,
        readableTextHash: String?,
        textCaptureMode: String?,
        privateWindow: Bool,
        schemaVersion: Int = 1,
        captureID: String? = nil,
        sourceQuality: BrowserContextSourceQuality? = nil,
        timestamp: Date
    ) {
        self.source = source
        self.browser = browser
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.title = title
        self.activity = activity
        self.pageID = pageID
        self.mediaID = mediaID
        self.mediaIsPlaying = mediaIsPlaying
        self.scrollPercent = scrollPercent
        self.viewportSignature = viewportSignature
        self.noveltyScore = noveltyScore
        self.visibleText = visibleText
        self.selectedText = selectedText
        self.readableText = readableText
        self.visibleTextHash = visibleTextHash
        self.readableTextHash = readableTextHash
        self.textCaptureMode = textCaptureMode
        self.privateWindow = privateWindow
        self.schemaVersion = schemaVersion
        self.captureID = captureID
        self.sourceQuality = sourceQuality ?? Self.deriveSourceQuality(
            source: source,
            privateWindow: privateWindow,
            textCaptureMode: textCaptureMode,
            visibleText: visibleText,
            selectedText: selectedText,
            readableText: readableText
        )
        self.timestamp = timestamp
    }

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
        if let textCaptureMode, !textCaptureMode.isEmpty {
            parts.append("Text capture: \(textCaptureMode)")
        }
        parts.append("Source quality: \(sourceQuality.rawValue)")

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

        if let selectedTextExcerpt {
            parts.append("Selected text: \(selectedTextExcerpt)")
        }

        if let visibleTextExcerpt {
            parts.append("Visible text: \(visibleTextExcerpt)")
        }

        if readableText != nil {
            let characterCount = readableText?.count ?? 0
            let hash = readableTextHash.map { " hash: \($0)" } ?? ""
            parts.append("Readable page text captured: \(characterCount) chars\(hash)")
            if let readableTextSummary {
                parts.append("Readable text summary: \(readableTextSummary)")
            }
        }

        return parts.joined(separator: " | ")
    }

    var visibleTextExcerpt: String? {
        BrowserContext.trimmedExcerpt(visibleText, limit: Self.visibleTextMemoryLimit)
    }

    var selectedTextExcerpt: String? {
        BrowserContext.trimmedExcerpt(selectedText, limit: Self.selectedTextMemoryLimit)
    }

    var readableTextSummary: String? {
        BrowserContext.trimmedExcerpt(readableText, limit: Self.readableTextMemoryLimit)
    }

    private static func trimmedExcerpt(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let normalized = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !normalized.isEmpty else { return nil }
        guard normalized.count > limit else { return normalized }

        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<end]) + "..."
    }

    private static func deriveSourceQuality(
        source: BrowserContextSource,
        privateWindow: Bool,
        textCaptureMode: String?,
        visibleText: String?,
        selectedText: String?,
        readableText: String?
    ) -> BrowserContextSourceQuality {
        guard source == .extensionData else {
            return .automationFallback
        }

        if privateWindow {
            return .extensionPrivate
        }

        let normalizedMode = textCaptureMode?.lowercased() ?? ""
        if normalizedMode.contains("metadata_only") || normalizedMode.contains("sensitive") {
            return .extensionMetadataOnly
        }

        if [visibleText, selectedText, readableText].contains(where: { ($0 ?? "").isEmpty == false }) {
            return .extensionFull
        }

        return .extensionMetadataOnly
    }
}
