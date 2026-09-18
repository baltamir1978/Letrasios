import SwiftUI

/// The recognized song: its header and, below, its lyrics.
struct SongView: View {
    let song: Song
    @Environment(SongListener.self) private var listener

    var body: some View {
        VStack(spacing: 0) {
            SongHeader(song: song)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.surface)

            lyrics
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var lyrics: some View {
        switch listener.lyricsState {
        case .loading:
            ProgressView("Buscando la letra…")
        case .loaded(.synced(let lines)):
            SyncedLyricsView(lines: lines)
        case .loaded(.plain(let text)):
            PlainLyricsView(text: text)
        case .loaded(.instrumental):
            ContentUnavailableView("Instrumental", systemImage: "music.note",
                                   description: Text("Esta canción no tiene letra."))
        case .notFound:
            ContentUnavailableView {
                Label("Sin letra", systemImage: "text.badge.xmark")
            } description: {
                Text("No hemos encontrado la letra de esta canción.")
            } actions: {
                if let url = song.externalURL {
                    Link("Buscar en Apple Music", destination: url)
                }
            }
        case .failed:
            ContentUnavailableView {
                Label("Sin conexión", systemImage: "wifi.exclamationmark")
            } description: {
                Text("No se ha podido descargar la letra.")
            } actions: {
                Button("Reintentar") { listener.retryLyrics() }
            }
        }
    }
}

private struct SongHeader: View {
    let song: Song
    @ScaledMetric(relativeTo: .headline) private var artworkSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: song.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
            }
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if let url = song.externalURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Abrir en Apple Music")
            }
        }
    }
}

/// Plain lyrics: LRCLIB has the text but no timestamps, so the reader scrolls it by hand.
private struct PlainLyricsView: View {
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Letra sin sincronizar", systemImage: "text.alignleft")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.title3.weight(.semibold))
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }
}
