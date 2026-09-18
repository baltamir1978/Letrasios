import Foundation

/// Lyrics lookup against LRCLIB (https://lrclib.net): free, no API key, and one of the few
/// sources that serves time-synced LRC lyrics.
nonisolated enum LyricsService {
    struct Result: Sendable {
        let lyrics: Lyrics
        /// Track length in seconds, when LRCLIB knows it. Tells the app when the song must
        /// have ended even if nothing new has been recognized.
        let duration: TimeInterval?
    }

    private struct Record: Decodable {
        let trackName: String?
        let artistName: String?
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private static let baseURL = URL(string: "https://lrclib.net/api/search")!
    private static let userAgent = "Letras/1.0 (https://github.com/baltamir1978/Letrasios)"

    /// nil when LRCLIB has nothing for the song. Throws only on network / decoding failures,
    /// so the caller can tell "no lyrics exist" from "try again".
    static func lyrics(for song: Song) async throws -> Result? {
        // Shazam titles and artists often carry extras LRCLIB doesn't ("Song (feat. X)",
        // "Song - Remastered 2011", "A & B"), so a miss is retried with the bare title and then
        // with the main artist alone. The full artist goes first: "Andy y Lucas" is one artist.
        let title = cleanTitle(song.title)
        let attempts = [
            (song.title, song.artist),
            (title, song.artist),
            (title, primaryArtist(song.artist)),
        ]
        var tried: [String] = []
        for (title, artist) in attempts {
            let key = "\(title)|\(artist)"
            guard !tried.contains(key) else { continue }
            tried.append(key)
            let records = try await search(title: title, artist: artist)
            if let best = pick(from: records, title: title) { return best }
        }
        return nil
    }

    private static func search(title: String, artist: String) async throws -> [Record] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return [] }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Record].self, from: data)
    }

    /// Prefers synced lyrics, then a title that matches exactly, then plain lyrics.
    private static func pick(from records: [Record], title: String) -> Result? {
        func titleMatches(_ record: Record) -> Bool {
            normalized(record.trackName ?? "") == normalized(title)
        }
        let ranked = records.sorted { a, b in
            let sa = (a.syncedLyrics?.isEmpty == false ? 2 : 0) + (titleMatches(a) ? 1 : 0)
            let sb = (b.syncedLyrics?.isEmpty == false ? 2 : 0) + (titleMatches(b) ? 1 : 0)
            return sa > sb
        }
        for record in ranked {
            if let synced = record.syncedLyrics, !synced.isEmpty {
                let lines = LRCParser.parse(synced)
                if !lines.isEmpty { return Result(lyrics: .synced(lines), duration: record.duration) }
            }
            if let plain = record.plainLyrics, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return Result(lyrics: .plain(plain), duration: record.duration)
            }
            if record.instrumental == true {
                return Result(lyrics: .instrumental, duration: record.duration)
            }
        }
        return nil
    }

    /// "Song (feat. X) - Remastered 2011" → "Song".
    static func cleanTitle(_ title: String) -> String {
        var t = title
        for pattern in [#"\s*[\(\[][^\)\]]*[\)\]]"#, #"\s+-\s+.*$"#] {
            t = t.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        t = t.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? title : t
    }

    /// "Artist A & Artist B" / "Artist A feat. B" → "Artist A": LRCLIB files lyrics under the
    /// main artist. Only tried after the full name has failed, since "&" is also part of names.
    static func primaryArtist(_ artist: String) -> String {
        let separators = [" feat. ", " feat ", " ft. ", " featuring ", " & ", ", "]
        var result = artist
        for separator in separators {
            if let range = result.range(of: separator, options: .caseInsensitive) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func normalized(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }
}
