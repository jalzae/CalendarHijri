import Foundation
import AVFoundation
import Combine

/// Catalog of adhan recitations available for download (islamcan.com CDN).
struct AdhanReciter: Identifiable, Hashable {
    let id: String
    let name: String

    var fileURL: URL {
        URL(string: "https://www.islamcan.com/audio/adhan/\(id).mp3")!
    }
}

enum AdhanCatalog {
    static let reciters = (1...21).map {
        AdhanReciter(id: "azan\($0)", name: "Adzan \($0)")
    }

    static func reciter(id: String) -> AdhanReciter? {
        reciters.first { $0.id == id }
    }

    static let defaultReciterID = "azan1"
}

/// Downloads adhan recordings to Application Support and plays them with
/// AVAudioPlayer when a prayer time is reached (or from the settings preview).
@MainActor
final class AdhanPlayer: NSObject, ObservableObject {
    static let shared = AdhanPlayer()

    enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)
    }

    @Published private(set) var states: [String: DownloadState] = [:]
    @Published private(set) var playingReciterID: String?

    private var player: AVAudioPlayer?

    private let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("AdhanAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override private init() {
        super.init()
        // Mark files already on disk as ready.
        for reciter in AdhanCatalog.reciters where fileURL(for: reciter.id) != nil {
            states[reciter.id] = .ready
        }
    }

    func localFileURL(for reciterID: String) -> URL? {
        fileURL(for: reciterID)
    }

    private func fileURL(for reciterID: String) -> URL? {
        let url = directory.appendingPathComponent("\(reciterID).mp3")
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
            ? url
            : nil
    }

    func state(for reciterID: String) -> DownloadState {
        states[reciterID] ?? .notDownloaded
    }

    /// Downloads the recitation if missing, then returns the local file URL.
    @discardableResult
    func ensureDownloaded(_ reciter: AdhanReciter) async -> URL? {
        if let existing = fileURL(for: reciter.id) {
            states[reciter.id] = .ready
            return existing
        }

        if case .downloading = state(for: reciter.id) { return nil }
        states[reciter.id] = .downloading(progress: 0)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(from: reciter.fileURL)
            let expected = response.expectedContentLength
            var data = Data()
            data.reserveCapacity(expected > 0 ? Int(expected) : 800_000)
            for try await byte in bytes {
                data.append(byte)
                if expected > 0, data.count % 32_768 == 0 {
                    states[reciter.id] = .downloading(progress: Double(data.count) / Double(expected))
                }
            }
            let destination = directory.appendingPathComponent("\(reciter.id).mp3")
            try data.write(to: destination, options: .atomic)
            states[reciter.id] = .ready
            return destination
        } catch {
            states[reciter.id] = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Plays the given recitation, downloading it first when needed.
    func play(reciterID: String) {
        guard let reciter = AdhanCatalog.reciter(id: reciterID) else { return }
        Task { [weak self] in
            guard let url = await self?.ensureDownloaded(reciter) else { return }
            self?.startPlaying(url: url, reciterID: reciterID)
        }
    }

    private func startPlaying(url: URL, reciterID: String) {
        stop()
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.volume = 1.0
            guard audioPlayer.play() else { return }
            player = audioPlayer
            playingReciterID = reciterID
        } catch {
            states[reciterID] = .failed(error.localizedDescription)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingReciterID = nil
    }
}

extension AdhanPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.playingReciterID = nil
        }
    }
}
