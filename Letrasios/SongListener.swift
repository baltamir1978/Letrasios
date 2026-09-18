import AVFAudio
import Foundation
import Observation
import ShazamKit
import UIKit
import os

private nonisolated let listenLog = Logger(subsystem: "com.letrasios.listening", category: "listener")

/// Listens to the music around the phone, recognizes it with ShazamKit and keeps the synced
/// lyrics in step with it.
///
/// Recognition runs in a loop for as long as the app is in the foreground:
/// - A match of a **new** song swaps the song and fetches its lyrics.
/// - A match of the **same** song only re-anchors the playback position, so any drift between
///   our clock and the music is corrected every few seconds.
/// - Several misses in a row, or running past the song's known length, clear the song: the
///   music has stopped or changed to something Shazam doesn't know.
///
/// Sync works from `SHMatchedMediaItem.predictedCurrentMatchOffset`: where in the recording the
/// music is at the moment of the match. From then on the position is that offset plus the time
/// elapsed since (`position(at:)`).
@Observable
final class SongListener {
    enum Phase: Equatable {
        case idle
        case listening
        case permissionDenied
    }

    enum LyricsState: Equatable {
        case loading
        case loaded(Lyrics)
        case notFound
        case failed
    }

    private(set) var phase: Phase = .idle {
        didSet {
            // Someone reading lyrics isn't touching the screen; don't let it lock mid-song.
            UIApplication.shared.isIdleTimerDisabled = phase == .listening
        }
    }
    private(set) var song: Song?
    private(set) var lyricsState: LyricsState = .loading
    /// Consecutive recognition attempts without a match. Lets the UI tell "listening" from
    /// "listening, but what's playing isn't recognizable".
    private(set) var missedAttempts = 0

    private var anchorOffset: TimeInterval = 0
    private var anchorDate = Date.distantPast
    private var songDuration: TimeInterval?

    /// Set when the user stops listening from the toolbar; cleared when the app leaves the
    /// foreground, so opening the app always starts listening again.
    private var pausedByUser = false
    private var loop: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var session: SHManagedSession?

    /// After a match of the song already on screen, wait this long before listening again.
    /// Short enough to notice the next song quickly, long enough not to keep the mic busy.
    private let resyncInterval: Duration = .seconds(8)
    /// Misses in a row after which the song on screen is considered over.
    private let missesToClear = 4

    var isListening: Bool { phase == .listening }

    /// Seconds into the current song at `date`, or nil when nothing has been recognized.
    func position(at date: Date) -> TimeInterval? {
        guard song != nil else { return nil }
        return anchorOffset + date.timeIntervalSince(anchorDate)
    }

    // MARK: - Lifecycle

    /// The app came to the foreground.
    func appBecameActive() {
        guard !pausedByUser else { return }
        start()
    }

    /// The app left the foreground. There is no background microphone mode for this, so
    /// listening stops; it starts again on the next launch or return.
    func appEnteredBackground() {
        stop()
        pausedByUser = false
    }

    /// Toolbar button.
    func toggleListening() {
        if isListening {
            pausedByUser = true
            stop()
        } else {
            pausedByUser = false
            start()
        }
    }

    func retryLyrics() {
        guard let song else { return }
        loadLyrics(for: song)
    }

    private func start() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoSong") { startDemo(); return }
        #endif
        guard loop == nil else { return }
        loop = Task { await run() }
    }

    private func stop() {
        loop?.cancel()
        loop = nil
        session?.cancel()
        session = nil
        if phase == .listening { phase = .idle }
    }

    // MARK: - Recognition loop

    private func run() async {
        guard await microphoneAllowed() else {
            listenLog.info("microphone permission denied")
            phase = .permissionDenied
            loop = nil
            return
        }
        guard !Task.isCancelled else { return }

        let session = SHManagedSession()
        self.session = session
        phase = .listening
        missedAttempts = 0
        await session.prepare()

        while !Task.isCancelled {
            let result = await session.result()
            let receivedAt = Date()
            guard !Task.isCancelled else { break }

            switch result {
            case .match(let match):
                missedAttempts = 0
                handle(match, receivedAt: receivedAt)
                try? await Task.sleep(for: resyncInterval)
            case .noMatch:
                missedAttempts += 1
                clearSongIfOver(at: receivedAt)
            case .error(let error, _):
                listenLog.error("recognition failed: \(error.localizedDescription, privacy: .public)")
                missedAttempts += 1
                clearSongIfOver(at: receivedAt)
                try? await Task.sleep(for: .seconds(2))
            }
        }
        session.cancel()
    }

    private func handle(_ match: SHMatch, receivedAt: Date) {
        guard let item = match.mediaItems.first else { return }
        let matched = Song(
            title: item.title ?? "",
            artist: item.artist ?? "",
            artworkURL: item.artworkURL,
            appleMusicURL: item.appleMusicURL,
            shazamID: item.shazamID
        )
        anchorOffset = item.predictedCurrentMatchOffset
        anchorDate = receivedAt

        if let song, song.isSameSong(as: matched) { return }
        listenLog.info("new song: \(matched.artist, privacy: .public) — \(matched.title, privacy: .public)")
        song = matched
        songDuration = nil
        loadLyrics(for: matched)
    }

    /// A miss alone doesn't end a song — quiet passages and noisy rooms miss too. It ends when
    /// the misses pile up or the song has run past its length.
    private func clearSongIfOver(at date: Date) {
        guard song != nil else { return }
        let pastEnd = songDuration.map { (position(at: date) ?? 0) > $0 + 5 } ?? false
        guard pastEnd || missedAttempts >= missesToClear else { return }
        listenLog.info("song over (pastEnd=\(pastEnd), misses=\(self.missedAttempts))")
        lyricsTask?.cancel()
        song = nil
        songDuration = nil
        lyricsState = .loading
    }

    private func microphoneAllowed() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }

    // MARK: - Lyrics

    private func loadLyrics(for song: Song) {
        lyricsTask?.cancel()
        lyricsState = .loading
        lyricsTask = Task {
            do {
                let result = try await LyricsService.lyrics(for: song)
                guard !Task.isCancelled, self.song == song else { return }
                if let result {
                    lyricsState = .loaded(result.lyrics)
                    songDuration = result.duration
                } else {
                    lyricsState = .notFound
                }
            } catch {
                guard !Task.isCancelled, self.song == song else { return }
                listenLog.error("lyrics lookup failed: \(error.localizedDescription, privacy: .public)")
                lyricsState = .failed
            }
        }
    }

    #if DEBUG
    /// Simulator stand-in for a match (`-demoSong` launch argument): the simulator has no
    /// music to hear, and the lyrics screen still needs checking in both appearances.
    private func startDemo() {
        guard song == nil else { return }
        phase = .listening
        let demo = Song(title: "Bohemian Rhapsody", artist: "Queen", artworkURL: nil,
                        appleMusicURL: nil, shazamID: "demo")
        anchorOffset = 62
        anchorDate = .now
        song = demo
        loadLyrics(for: demo)
    }
    #endif
}
