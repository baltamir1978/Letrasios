import SwiftUI

/// Synced lyrics that follow the music: the line being sung is highlighted and kept near the
/// top third of the screen.
struct SyncedLyricsView: View {
    let lines: [LyricLine]
    @Environment(SongListener.self) private var listener

    /// Highlight a line slightly before its timestamp: reading lags hearing, and a line that
    /// lights up late feels more out of sync than one that lights up early.
    private static let lead: TimeInterval = 0.3

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let time = listener.position(at: context.date).map { $0 + Self.lead }
            LyricLinesView(lines: lines, current: time.flatMap { lines.currentIndex(at: $0) })
        }
    }
}

private struct LyricLinesView: View {
    let lines: [LyricLine]
    let current: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// While the reader scrolls on their own, the view stops following the song for a moment
    /// instead of yanking the text out from under their finger.
    @State private var followPausedUntil = Date.distantPast

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(lines) { line in
                        LyricLineRow(line: line, isCurrent: line.id == current,
                                     isPast: current.map { line.id < $0 } ?? false)
                            .id(line.id)
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                // Room to bring the last lines up to the reading position.
                .padding(.bottom, 320)
            }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting || phase == .decelerating {
                    followPausedUntil = .now.addingTimeInterval(4)
                }
            }
            .onChange(of: current, initial: true) { _, index in
                guard let index, Date.now >= followPausedUntil else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                    proxy.scrollTo(index, anchor: UnitPoint(x: 0.5, y: 0.3))
                }
            }
        }
    }
}

private struct LyricLineRow: View {
    let line: LyricLine
    let isCurrent: Bool
    let isPast: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(line.text.isEmpty ? "♪" : line.text)
            .font(.title2.weight(.bold))
            .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
            .opacity(opacity)
            .scaleEffect(isCurrent && !reduceMotion ? 1.04 : 1, anchor: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isCurrent)
            .accessibilityLabel(line.text.isEmpty ? Text("Pausa instrumental") : Text(line.text))
            .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    /// Lines other than the current one are dimmed to make the current one stand out. With
    /// Increase Contrast on, they stay at the full secondary color.
    private var opacity: Double {
        if isCurrent || contrast == .increased { return 1 }
        return isPast ? 0.45 : 0.7
    }
}
