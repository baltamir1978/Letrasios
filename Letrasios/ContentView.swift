import SwiftUI

struct ContentView: View {
    @Environment(SongListener.self) private var listener
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            Group {
                if listener.phase == .permissionDenied {
                    MicrophoneDeniedView()
                } else if let song = listener.song {
                    SongView(song: song)
                } else {
                    ListeningView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAbout = true
                    } label: {
                        Label("Acerca de Letras", systemImage: "info.circle")
                    }
                }
                if listener.phase != .permissionDenied {
                    ToolbarItem(placement: .topBarTrailing) {
                        ListenToggle()
                    }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
        .tint(.brand)
    }
}

/// Starts and stops listening. Its label always says what tapping it will do.
private struct ListenToggle: View {
    @Environment(SongListener.self) private var listener

    var body: some View {
        Button {
            listener.toggleListening()
        } label: {
            if listener.isListening {
                Label("Dejar de escuchar", systemImage: "mic.fill")
            } else {
                Label("Escuchar", systemImage: "mic.slash")
            }
        }
    }
}

// MARK: - Waiting for a song

struct ListeningView: View {
    @Environment(SongListener.self) private var listener

    var body: some View {
        VStack(spacing: 24) {
            ListeningBadge(active: listener.isListening)

            VStack(spacing: 8) {
                Text(listener.isListening ? "Escuchando…" : "En pausa")
                    .font(.title2.weight(.bold))
                Text(hint)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            if !listener.isListening {
                Button {
                    listener.toggleListening()
                } label: {
                    Label("Escuchar", systemImage: "mic.fill")
                        .font(.headline)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color.appBackground)
            }
        }
        .padding(32)
        .frame(maxWidth: 480)
    }

    private var hint: LocalizedStringKey {
        if !listener.isListening { return "Pulsa el micrófono para volver a escuchar." }
        if listener.missedAttempts >= 2 { return "No reconozco lo que suena. Acerca el móvil a la música." }
        return "Pon música cerca del móvil y aparecerá la letra."
    }
}

/// Microphone in a soft disc, with a sound wave that moves while listening.
private struct ListeningBadge: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: active ? "waveform" : "mic.slash")
            .font(.system(size: 56, weight: .semibold))
            .foregroundStyle(Color.brand)
            .symbolEffect(.variableColor.iterative.reversing, options: .repeating,
                          isActive: active && !reduceMotion)
            .frame(width: 136, height: 136)
            .background(Color.surface, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Microphone denied

struct MicrophoneDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("Sin acceso al micrófono", systemImage: "mic.slash")
        } description: {
            Text("Letras necesita el micrófono para reconocer la música que suena. Puedes activarlo en Ajustes.")
        } actions: {
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Color.appBackground)
        }
    }
}

#Preview {
    ContentView()
        .environment(SongListener())
}
