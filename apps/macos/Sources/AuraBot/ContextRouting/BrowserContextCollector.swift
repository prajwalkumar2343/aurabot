import Foundation

actor BrowserContextCollector {
    private let browserContextService: BrowserContextService

    init(browserContextService: BrowserContextService) {
        self.browserContextService = browserContextService
    }

    func collect() async -> BrowserContext? {
        await browserContextService.currentContext()
    }
}
