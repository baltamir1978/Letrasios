# Letras

App de iOS que, nada más abrirla, escucha la música que suena alrededor, reconoce la canción con **Shazam** y muestra su **letra sincronizada**, resaltando la línea que se está cantando.

**Versión actual: 1.0**

## Características

- 🎧 **Empieza a escuchar al abrir**: no hay que pulsar nada. Al pasar a segundo plano deja de escuchar y vuelve a hacerlo al volver.
- 🎼 **Reconocimiento con ShazamKit** (`SHManagedSession`), que gestiona el micrófono por sí mismo.
- 📝 **Letra sincronizada** desde [LRCLIB](https://lrclib.net): la línea actual se resalta y la vista la sigue sola. Si LRCLIB solo tiene la letra sin tiempos, se muestra para leerla a mano; si la canción es instrumental, se dice.
- 🔄 **Resincronización continua**: la app sigue escuchando y cada nuevo reconocimiento corrige la posición. Si cambia la canción, cambia la letra; si la música para, vuelve a la pantalla de escucha.
- 👆 **Desplazamiento manual**: al arrastrar la letra, la vista deja de seguir la canción durante unos segundos.
- 🔗 **Apple Music**: enlace a la canción, o a una búsqueda cuando no hay letra.
- 🌗 **Modo claro y oscuro**, con colores adaptativos e icono claro, oscuro y tintado.
- ♿️ **Accesibilidad**: VoiceOver en toda la interfaz (la línea actual se marca como seleccionada y las pausas instrumentales se leen como tales), Dynamic Type, contraste WCAG AA medido, *Reducir movimiento* y *Aumentar contraste*.
- 🌍 **6 idiomas**: español, inglés, francés, alemán, italiano y portugués, incluido el aviso del permiso de micrófono.
- 🔒 **Sin datos**: ni cuenta, ni analítica, ni SDK de terceros.

## Requisitos

- Xcode 26 o superior (Swift 6, aislamiento por defecto en `MainActor`)
- iOS 26.5+
- Cuenta de desarrollador de Apple

## Puesta en marcha

1. Abre `Letrasios.xcodeproj` y comprueba el *Team* en *Signing & Capabilities*.
2. **Activa ShazamKit en el App ID.** No es una *capability* de Xcode: developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → `Altamirano.Letrasios` → pestaña **App Services** → marca **ShazamKit** → Save. Sin esto, `SHManagedSession` funciona pero nunca encuentra nada.
3. Ejecuta en un iPhone real: el simulador no oye música.

### Modo demo (solo Debug)

Para revisar la pantalla de letra en el simulador, lanza la app con el argumento `-demoSong` (*Edit Scheme → Run → Arguments*). Simula que ha reconocido *Bohemian Rhapsody* a partir del minuto 1 y descarga su letra real.

## Estructura

```
Letrasios/
├── Letrasios/                 # Target de la app (carpeta sincronizada: los ficheros nuevos entran solos)
│   ├── LetrasApp.swift        # Punto de entrada; arranca y para la escucha según el ciclo de vida
│   ├── SongListener.swift     # Bucle de reconocimiento (ShazamKit) y reloj de sincronización
│   ├── LyricsService.swift    # Cliente de LRCLIB
│   ├── Lyrics.swift           # Modelos y parser LRC
│   ├── ContentView.swift      # Navegación, pantalla de escucha y permiso denegado
│   ├── SongView.swift         # Cabecera de la canción y estados de la letra
│   ├── SyncedLyricsView.swift # Letra sincronizada
│   ├── AboutView.swift        # Créditos y privacidad
│   ├── Theme.swift            # Colores adaptativos
│   ├── Localizable.xcstrings  # Interfaz en 6 idiomas
│   ├── InfoPlist.xcstrings    # Permiso de micrófono en 6 idiomas
│   └── PrivacyInfo.xcprivacy  # Manifiesto de privacidad
└── Tools/generate_icon.py     # Genera los tres iconos (claro, oscuro, tintado)
```

## Cómo se sincroniza

`SHMatchedMediaItem.predictedCurrentMatchOffset` dice en qué segundo de la grabación está la música en el momento del reconocimiento. La app guarda ese desfase y la hora a la que llegó; a partir de ahí, la posición es el desfase más el tiempo transcurrido (`SongListener.position(at:)`). Un `TimelineView` la consulta cinco veces por segundo y busca la línea con una búsqueda binaria sobre las marcas de tiempo.

Detalles que no son evidentes:

- **La línea se enciende 0,3 s antes** de su marca (`SyncedLyricsView.lead`): una línea que llega tarde se percibe más desincronizada que una que llega pronto.
- **Un reconocimiento de la misma canción solo reancla el reloj**; no vuelve a descargar la letra. Tras cada uno la app espera 8 s antes de volver a escuchar.
- **Un fallo aislado no quita la canción** (los pasajes suaves y los sitios ruidosos fallan). La quitan cuatro fallos seguidos o haber pasado de la duración que da LRCLIB.

## Búsqueda de letras

Los títulos y artistas de Shazam traen añadidos que LRCLIB no tiene («Song (feat. X)», «Song - Remastered 2011», «A & B»). `LyricsService` prueba por orden: título y artista tal cual, título limpio y, por último, solo el artista principal. El artista completo va primero porque «Andy y Lucas» o «Simon & Garfunkel» son un solo artista. Entre los resultados prefiere la letra sincronizada y el título exacto.

## Localización

String Catalogs con el español como idioma de origen: las claves son los textos en español tal cual aparecen en el código. Para comprobar que no falta ninguna traducción, compila y compara las claves de los `.stringsdata` generados con las de `Localizable.xcstrings`.

## Accesibilidad

- `Color.brand` sobre el fondo: 5,7:1 en claro y 10,4:1 en oscuro; sobre `surface`, 5,2:1 y 8,8:1. Recalcula antes de tocar un color.
- **Nada blanco sobre `Color.brand`**: en oscuro es un verde menta claro. Los textos sobre el acento usan `Color.appBackground`.
- Con *Aumentar contraste* las líneas que no se están cantando dejan de atenuarse.
- Con *Reducir movimiento* no hay animación del icono de escucha, ni zoom de la línea actual, ni desplazamiento animado.

## Privacidad

La app **no recoge datos**. El micrófono solo alimenta a ShazamKit, que envía a Apple una huella del audio, no el audio. La única otra conexión es la consulta de la letra a LRCLIB (título y artista), sin identificador. No guarda nada en el dispositivo.

- `PrivacyInfo.xcprivacy`: sin rastreo, sin datos recogidos y sin APIs de motivo requerido (no usa `UserDefaults`).
- `NSMicrophoneUsageDescription`, localizado en `InfoPlist.xcstrings`.

> ⚠️ **Letras y App Store.** Las letras tienen derechos de autor y LRCLIB es una base de datos colaborativa sin licencia de las editoriales. Para uso personal o TestFlight no hay problema, pero publicar en el App Store mostrando la letra puede acabar en rechazo o reclamación. Si se publica, habría que pasar a un proveedor con licencia (Musixmatch comercial, LyricFind) o, como en RadioApp, enlazar a Apple Music en lugar de mostrar el texto.

## Iconos

```sh
python3 Tools/generate_icon.py
```

Genera `AppIcon.png`, `AppIcon-dark.png` y `AppIcon-tinted.png` (1024×1024, sin canal alfa) en `AppIcon.appiconset`.

## Licencia

Proyecto personal de Bruno Altamirano. Todos los derechos reservados salvo indicación contraria.
