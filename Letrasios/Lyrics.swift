import Foundation

/// The song ShazamKit recognized.
nonisolated struct Song: Equatable, Sendable {
    let title: String
    let artist: String
    let artworkURL: URL?
    let appleMusicURL: URL?
    /// Shazam's catalog id; nil for some matches, in which case title + artist identify the song.
    let shazamID: String?

    /// Whether two matches are the same recording, so a re-match only re-syncs the lyrics.
    func isSameSong(as other: Song) -> Bool {
        if let a = shazamID, let b = other.shazamID { return a == b }
        return title.caseInsensitiveCompare(other.title) == .orderedSame
            && artist.caseInsensitiveCompare(other.artist) == .orderedSame
    }

    /// Where to read or play the song outside the app: Shazam's exact Apple Music link, or an
    /// Apple Music search built from artist and title.
    var externalURL: URL? {
        if let appleMusicURL { return appleMusicURL }
        var components = URLComponents(string: "https://music.apple.com/search")!
        components.queryItems = [URLQueryItem(name: "term", value: "\(artist) \(title)")]
        return components.url
    }
}

/// One time-stamped line of synced lyrics.
nonisolated struct LyricLine: Equatable, Sendable, Identifiable {
    let id: Int
    /// Seconds from the start of the song.
    let time: TimeInterval
    /// Empty for instrumental gaps; the view draws those as a musical note.
    let text: String
}

nonisolated enum Lyrics: Equatable, Sendable {
    case synced([LyricLine])
    case plain(String)
    case instrumental
}

extension [LyricLine] {
    /// Index of the line being sung at `time`: the last one whose timestamp has passed.
    /// nil before the first line starts.
    nonisolated func currentIndex(at time: TimeInterval) -> Int? {
        // Binary search: the timeline ticks several times a second over a few dozen lines.
        var low = 0, high = count
        while low < high {
            let mid = (low + high) / 2
            if self[mid].time <= time { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? nil : low - 1
    }
}

/// Parser for the LRC format LRCLIB serves: `[mm:ss.xx] text`.
///
/// Handles lines with several timestamps (`[00:12.00][01:40.50] chorus`), the `[offset:±ms]`
/// tag, and ignores the other ID tags (`[ar:…]`, `[ti:…]`).
nonisolated enum LRCParser {
    static func parse(_ lrc: String) -> [LyricLine] {
        var offset: TimeInterval = 0
        var stamped: [(TimeInterval, String)] = []

        for rawLine in lrc.split(whereSeparator: \.isNewline) {
            var rest = Substring(rawLine).trimmingCharacters(in: .whitespaces)[...]
            var times: [TimeInterval] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                if let time = timestamp(tag) {
                    times.append(time)
                } else if tag.lowercased().hasPrefix("offset:"),
                          let ms = Double(tag.dropFirst("offset:".count).trimmingCharacters(in: .whitespaces)) {
                    // Positive offset means the lyrics come earlier.
                    offset = -ms / 1000
                }
                rest = rest[rest.index(after: close)...]
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            for time in times { stamped.append((time, text)) }
        }

        return stamped
            .sorted { $0.0 < $1.0 }
            .enumerated()
            .map { LyricLine(id: $0.offset, time: max(0, $0.element.0 + offset), text: $0.element.1) }
    }

    /// `mm:ss`, `mm:ss.xx` or `mm:ss.xxx` → seconds.
    private static func timestamp(_ tag: Substring) -> TimeInterval? {
        let parts = tag.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1].replacingOccurrences(of: ",", with: "."))
        else { return nil }
        return minutes * 60 + seconds
    }
}
