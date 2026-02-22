import Foundation
import CoreGraphics

struct ScreenCapture {
    let displayID: CGDirectDisplayID
    let imageData: Data
    let timestamp: Date
    let displayNum: Int
    
    var compressed: Data { imageData }
}

struct CaptureResult {
    let summary: String
    let context: String
    let activities: [String]
    let keyElements: [String]
    let userIntent: String
}

struct AnalysisResult {
    let summary: String
    let context: String
    let activities: [String]
    let keyElements: [String]
    let userIntent: String
}
