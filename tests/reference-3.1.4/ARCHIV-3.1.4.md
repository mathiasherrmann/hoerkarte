# Archiv der AA-1c-Daten außerhalb des Repositorys

Alles, was mit dem alten x86_64-ffmpeg unter Rosetta 2 entstanden ist und
nach dem Upgrade auf macOS 27 nicht mehr erzeugt werden kann. Erhoben am
22.11.2026.

## Ablageorte

```
/Users/mathias/Projekte/hoerkarte-archiv/aa1c-ffmpeg-ausgaben-3.1.4/     Audiodateien der vier Varianten
/Users/mathias/Projekte/hoerkarte-archiv/aa1c-kapitel-zwischendateien/   Zwischendateien der App aus dem Kapitelweg
/Users/mathias/Projekte/hoerkarte-archiv/m2-karte-3.1.4/                 vollständige Kopie der bespielten SD-Karte
/Users/mathias/Projekte/hoerkarte-archiv/app-3.1.4/                      Kopie des App-Bundles 3.1.4
```

## Varianten der ffmpeg-Ausgaben

| Variante | Dateien | Größe |
|---|---|---|
| `modell-2011-anhebung-0` | 20 |  42M |
| `modell-2011-anhebung-1` | 20 |  42M |
| `modell-2021-anhebung-0` | 22 |  18M |
| `modell-2021-anhebung-1` | 22 |  17M |

Je Variante liegt eine `SHA256SUMS.txt` bei. Prüfen mit:

```
cd <variante> && shasum -a 256 -c SHA256SUMS.txt
```

## Zwischendateien des Kapitelwegs

Aus dem laufenden Temp-Ordner der App kopiert
(`~/Library/Application Support/hörbert/.UDjZgf`, 22:00):

| Datei | Bytes | SHA-256 | Titel-Tag |
|---|---|---|---|
| `20261122220008-0.mp3` | 49824 | `9b3256b64ad6da154b2f69e225d1c0a0412d3be17dddfc903964c318954ef597` | Kapitel Eins |
| `20261122220008-1.mp3` | 49878 | `aa54679032c51a6cc0f0b8f9d37c97029d2decef82dd0f04995b8cbd7bf483ee` | Kapitel Zwei |
| `20261122220008-2.mp3` | 49824 | `ac444f633a158e0552f3879bec0358b933f0bbf6ee7bb7544f71cce1b3e0fdd1` | Kapitel Drei |

Diese drei Dateien sind **byte-identisch** mit der Nachbildung aus Stufe 1
des Kapitelwegs. Damit ist der Weg doppelt belegt: bit-genau im Ton gegen
die Karte und byte-identisch gegen die Zwischendateien der App selbst.

## Was nicht im Archiv liegt

16 Audiodateien aus den beiden Läufen vor der Umstrukturierung auf vier
Varianten liegen nicht mehr hier; sie sind durch
`modell-2021-anhebung-0` und `-1` ersetzt und reproduzierbar, solange
Rosetta läuft.
