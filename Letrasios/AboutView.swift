import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Abre la app cerca de la música: Letras reconoce la canción que suena y muestra su letra sincronizada con ella.")
                }

                Section("Créditos") {
                    LabeledContent("Reconocimiento musical", value: "Shazam")
                    Link(destination: URL(string: "https://lrclib.net")!) {
                        LabeledContent("Letras", value: "LRCLIB")
                    }
                }

                Section("Privacidad") {
                    Text("El audio no se graba ni se guarda: solo se envía a Shazam una huella digital para identificar la canción. La app no recoge datos ni usa analítica.")
                }

                Section {
                    LabeledContent("Versión", value: version)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Acerca de Letras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
