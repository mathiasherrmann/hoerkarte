# Branding „Hörkarte“

Eigenes Icon des Forks. Es ersetzt in AA-5 die Dateien `hoerbert/hoerbert.icns`,
`hoerbert/hoerbert.ico`, `hoerbert/hoerbert.png` und die Verweise darauf in
`hoerbert/hoerbert.pro`, `hoerbert/resources.qrc`, `hoerbert/app.rc` und
`hoerbert/hoerbert.desktop`.

Nicht abgedeckt: weitere Bilder mit hörbert-Bezug unter `hoerbert/images/`
(u. a. `images/hoerbert.png` als Hintergrund der Playlist-Ansicht,
playlistview.cpp:65, und `:/images/hoerbert.ico` als Fenster-Icon,
mainwindow.cpp:65). AA-0 inventarisiert sie, siehe offener Punkt O1 im
Portierungsplan.

| Datei | Zweck |
|---|---|
| `hoerkarte-icon.svg` | Quelle. Änderungen nur hier, alle anderen Dateien daraus neu erzeugen. |
| `hoerkarte-1024.png` | Rendering 1024 × 1024, Ausgangsbild für `.icns` und `.ico` |
| `hoerkarte.icns` | macOS-App-Icon |
| `hoerkarte.ico` | Windows-Icon (16 bis 256 px) |
| `hoerkarte-512.png` | Linux-Desktop-Icon |

Das Motiv ist eine Eigenentwicklung (Speicherkarte mit Pegelbalken) und enthält
kein Bildmaterial des Originalprojekts. Lizenz: wie das Projekt, GPLv3.

Erzeugt am 22.11.2026 unter Linux mit rsvg-convert und Pillow. `hoerkarte.icns`
ist in AA-5 auf dem Mac zu prüfen (Darstellung im Finder und im Dock, alle
Größen vorhanden); bei Auffälligkeiten dort mit `iconutil` aus
`hoerkarte-1024.png` neu erzeugen.
