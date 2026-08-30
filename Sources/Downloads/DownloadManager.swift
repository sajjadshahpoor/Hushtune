import Foundation
import UIKit

/// Downloads direct video file URLs (.mp4, .mov, .m3u8 playlists that resolve to
/// plain files, etc). This only works for URLs that point at an actual media
/// file — it can't pull video out of a page's custom player (e.g. a `blob:`
/// URL fed by JavaScript), because that isn't a real network resource to fetch.
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []

    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var taskIDs: [Int: UUID] = [:]
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func startDownload(url: URL, suggestedName: String? = nil) {
        let id = UUID()
        let fallbackName = "video-\(id.uuidString.prefix(8))\(url.pathExtension.isEmpty ? ".mp4" : ".\(url.pathExtension)")"
        let name = suggestedName ?? (url.lastPathComponent.isEmpty ? fallbackName : url.lastPathComponent)
        let item = DownloadItem(id: id, sourceURL: url, suggestedFileName: name)
        downloads.insert(item, at: 0)

        let task = session.downloadTask(with: url)
        taskIDs[task.taskIdentifier] = id
        task.resume()
    }

    static var downloadsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @objc private func appDidEnterBackground() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "HushtuneDownloads") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    @objc private func appWillEnterForeground() {
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move the file out of the temp location synchronously, before the
        // completion handler returns and the OS deletes the temp file.
        let taskId = downloadTask.taskIdentifier
        let suggestedName = downloadTask.response?.suggestedFilename

        var tempCopyURL: URL?
        do {
            let tempCopy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: location, to: tempCopy)
            tempCopyURL = tempCopy
        } catch {
            tempCopyURL = nil
        }

        Task { @MainActor in
            guard let id = self.taskIDs[taskId],
                  let index = self.downloads.firstIndex(where: { $0.id == id }) else { return }

            guard let tempCopyURL else {
                self.downloads[index].state = .failed("Could not save downloaded file")
                return
            }

            let filename = suggestedName ?? self.downloads[index].suggestedFileName
            let dest = DownloadManager.downloadsDirectory.appendingPathComponent(filename)
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: tempCopyURL, to: dest)
                self.downloads[index].suggestedFileName = filename
                self.downloads[index].localFileURL = dest
                self.downloads[index].state = .completed
                self.downloads[index].progress = 1.0
            } catch {
                self.downloads[index].state = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskId = downloadTask.taskIdentifier
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        Task { @MainActor in
            guard let id = self.taskIDs[taskId],
                  let index = self.downloads.firstIndex(where: { $0.id == id }) else { return }
            self.downloads[index].progress = progress
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let taskId = task.taskIdentifier
        Task { @MainActor in
            guard let id = self.taskIDs[taskId],
                  let index = self.downloads.firstIndex(where: { $0.id == id }) else { return }
            self.downloads[index].state = .failed(error.localizedDescription)
        }
    }
}
