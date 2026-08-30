import Foundation

struct DownloadItem: Identifiable, Equatable {
    let id: UUID
    let sourceURL: URL
    var suggestedFileName: String
    var progress: Double = 0
    var state: State = .downloading
    var localFileURL: URL?

    enum State: Equatable {
        case downloading
        case completed
        case failed(String)
    }
}
