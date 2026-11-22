# Aufrufe von ffmpeg und ffprobe in Version 3.1.4

Erhoben am 22.11.2026 aus `upstream/feedback`, Commit `1280aac`
(`VER_PRODUCTVERSION_STR "3.1.4"`). Der Tag `3.1.4` zeigt auf `be6062a`; der
Zweig liegt acht Monate weiter und ist die Fassung, die der installierten App
entspricht. Gegenstück für 2.1.3 ist `../reference/AUFRUFE.md`.

## Der entscheidende Unterschied: der Modellschalter

3.1.4 verzweigt in **jeder** schreibenden Funktion auf
`qApp->property("hoerbertModel")`:

* `2011` → der alte Weg: `-acodec pcm_s16le -ar 32k -ac 1`, Zieldatei `.WAV`
* jeder andere Wert → der neue Weg: `-ar 44100 -ac 2 -b:a 192k`, Zieldatei
  `.MP3` (bei der Stille-Datei 128 kbit/s statt 192)

Auf dem Arbeitsrechner steht `Global.hoerbertModel` auf **2021**, es gilt also
der MP3-Weg. Die eingebundene SD-Karte bestätigt das: 28 MP3-Dateien,
44100 Hz, stereo, rund 192 kbit/s, kein `hoerbert.xml`.

Zweite durchgehende Neuerung: **`-map a`** in den schreibenden Aufrufen — mit
einer Ausnahme, siehe C9.

## Zuordnung aller Aufrufstellen

Jede Stelle, an der 3.1.4 ffmpeg oder ffprobe startet, mit Datei, Zeile und
Einordnung gegenüber 2.1.3.

| Kennung | Funktion | Argumentliste | Ausgeführt | gegenüber 2.1.3 | Referenz |
|---|---|---|---|---|---|
| **C1** | `convertToAudioFile` | `hoerbertprocessor.cpp:473-517` | `:519` | **geändert** — Modellzweig, `-map a`; hieß dort `convertToWav` (A5) | ja |
| **C2** | `convertToMp3` | `hoerbertprocessor.cpp:529-544` | `:547` | **neu** | ja |
| **C3** | `splitPer3Mins` | `hoerbertprocessor.cpp:564-613` | `:615` | **geändert** — Modellzweig, `-map a` (A6) | ja |
| **C4** | `createSilenceAudioFile` | `hoerbertprocessor.cpp:895-933` | `:934` | **geändert** — Modellzweig, 128 kbit/s; hieß `createSilenceWav` (A10) | ja |
| **C5** | `changeMetaData` | `hoerbertprocessor.cpp:944-968` | `:973` | **geändert** — Temp-Datei je Modell `.WAV`/`.MP3` (A11) | ja |
| **C6** | `splitOnSilence`, Erkennung | `hoerbertprocessor.cpp:625-639` | `:641` | **unverändert** (A7) | ja |
| **C7** | `splitOnSilence`, Schnitt | `hoerbertprocessor.cpp:700-776` | `:778`, `:802` | **geändert** — Modellzweig, `-map a` (A8) | ja |
| **C8** | Kapitelermittlung | `audiobookconverter.cpp:58-61` | `:62` | **unverändert** (A2) | ja |
| **C9** | Kapitelschnitt | `audiobookconverter.cpp:71-104` | `:135` | **geändert** — Modellzweig; **kein** `-map a` (A3) | ja |
| **C10** | `getVolumeDifference` | `hoerbertprocessor.cpp:828-842` | `:845` | **unverändert** (A4/A9) | ja |
| **C11** | `convertWav2Flac` | `backupmanager.cpp:415-421` | `:425` | **unverändert** (A12) | ja |
| **C12** | `convertFlac2Audio` | `backupmanager.cpp:434-440` | `:444` | **unverändert**, nur umbenannt; hieß `convertFlac2Wav` (A13) | ja |
| **C13** | `ffprobe show_format` | `audioinfothread.cpp:99-106` | `:137` | **unverändert** (A1) | ja |
| — | `ffplay` Vorhören | `playlistview.cpp` | — | unverändert (A14); erzeugt keine prüfbare Ausgabe | nein, manuell |
| — | `freaccmd` CD-Rippen | `cdripper.cpp:62-70` | `:86` | geändert: Pfad je macOS-Version, siehe unten | nein, braucht Laufwerk |

Es bleibt keine ffmpeg- oder ffprobe-Aufrufstelle ohne Referenz.
`devicemanager.cpp`, `mainwindow.cpp` (`diskutil`, `udisksctl`, `mkfs.vfat`,
`Sync`, `zip`) starten kein ffmpeg und gehören nicht hierher.

## Was erhoben wurde

Vier Varianten, als Kreuzmenge aus beiden Modellzweigen und beiden
Einstellungen der Lautstärkeanhebung:

```
reference-3.1.4/modell-2011-anhebung-0/    Zielformat .WAV, keine Anhebung
reference-3.1.4/modell-2011-anhebung-1/    Zielformat .WAV, mit Anhebung
reference-3.1.4/modell-2021-anhebung-0/    Zielformat .MP3, keine Anhebung
reference-3.1.4/modell-2021-anhebung-1/    Zielformat .MP3, mit Anhebung
```

Je Variante: Rohausgaben samt normalisierter Fassung, die von der App
geparsten Zeilen, der Rückgabecode jedes Aufrufs, und für jede erzeugte Datei
Formatangaben, Abtastrate, Kanäle, Bitrate, Dauer, Tags sowie die Prüfsumme
der Datei **und** der dekodierten PCM-Daten.

Warum beide Anhebungs-Varianten: `getVolumeDifference` liest
`Global/increaseVolume` aus `QSettings`. In `com.hoerbert.hörbert.plist` ist
der Schlüssel **nicht gesetzt**, `toBool()` ergibt damit `false`, und die App
verwirft jede positive Korrektur. Der Quellcode lässt aber beide Fälle zu, und
welcher gilt, hängt an einer Benutzereinstellung — also ist beides Referenz.

Die erzeugten Audiodateien liegen außerhalb des Repositorys unter
`hoerkarte-archiv/aa1c-ffmpeg-ausgaben-3.1.4/`, nach Variante getrennt.

## Der Nachweis an der Karte

Die SD-Karte wurde mit der installierten App 3.1.4 aus
`../reference/quellen/` bespielt. Für die Variante
`modell-2021-anhebung-0` — also genau die Einstellung der App — stimmen die
PCM-Prüfsummen von **acht von acht** C1-Dateien bit-genau mit den
entsprechenden Dateien der Karte überein:

| Karte | Nachbildung | PCM |
|---|---|---|
| `0/11.MP3` | `C1-wav.MP3` | gleich |
| `0/7.MP3` | `C1-flac.MP3` | gleich |
| `0/9.MP3` | `C1-mp3.MP3` | gleich |
| `0/13.MP3` | `C1-aiff.MP3` | gleich |
| `0/8.MP3` | `C1-m4a.MP3` | gleich |
| `0/10.MP3` | `C1-ogg.MP3` | gleich |
| `0/12.MP3` | `C1-wma.MP3` | gleich |
| `0/3.MP3` | `C1-leise.MP3` | gleich |

Mit eingeschalteter Anhebung weichen dieselben Dateien ab. Die Erhebung
bildet das Verhalten der App damit nachweislich ab, und zugleich ist belegt,
welche der beiden Einstellungen gilt.

### B19, gemessen: der Kapitelweg kodiert zweimal nach MP3

Die Vermutung ist **bestätigt**. Der Weg eines Hörbuchs mit Kapiteln auf die
Karte verläuft in zwei Stufen, und beide kodieren nach MP3:

1. `PlaylistView::readEntries` (`playlistview.cpp:626-629`) erkennt `.m4b` und
   ruft `parseAudioBook` (`:822`), das `AudioBookConverter::convert` startet.
   Der Kapitelschnitt schreibt nach
   `<TEMP>/<yyyyMMddHHmmss>-<N>.mp3` — **kleingeschrieben**, weil
   `audiobookconverter.cpp:129` `DESTINATION_FORMAT_MP3.toLower()` verwendet.
   `<TEMP>` ist ein `QTemporaryDir` (`main.cpp:239`), der Name wechselt je
   Programmlauf.
2. Die Temp-Dateien gehen als gewöhnliche Einträge in die Liste. Weil kein
   CD-Rip beteiligt ist, nimmt `playlistview.cpp:723` den Weg ohne
   Metadatenliste, und `AudioInfoThread` liest je Datei den Titel per ffprobe.
   Beim Bespielen wandelt `convertToAudioFile` (C1) sie ein **zweites Mal**
   nach MP3 auf die Karte.

Nachgebildet und gemessen: Stufe 1 mit den Kapitelgrenzen aus C8, Stufe 2 mit
C1 auf die Temp-Dateien. Die PCM-Prüfsummen stimmen **bit-genau** mit den
Kartendateien überein:

| Karte | PCM | Nachbildung | Befund |
|---|---|---|---|
| `0/0.MP3` | `5635f1a7aa1e0cc4` | Stufe 1 + Stufe 2 | gleich |
| `0/1.MP3` | `f4e36f302c55e5f1` | Stufe 1 + Stufe 2 | gleich |
| `0/2.MP3` | `8e4e18e95eb5c583` | Stufe 1 + Stufe 2 | gleich |

Die Dateigrößen weichen um 38 bis 54 Byte ab, weil die Titel-Metadaten
unterschiedlich lang sind: auf der Karte steht der Temp-Pfad als Titel, in
meiner Nachbildung der Kapiteltitel. Der Audioinhalt ist identisch.

**Folge:** Jedes Hörbuchkapitel wird zweimal MP3-kodiert, mit entsprechendem
Generationsverlust. Für Modell 2011 entsteht der Verlust nicht, weil beide
Stufen dort PCM schreiben. Ob der Port das behebt oder das Verhalten
beibehält, ist eine eigene Entscheidung; gemessen ist es jetzt.

## fre:ac: der Befund zu E3

| Ort | Dateien | Mach-O | davon mit arm64 |
|---|---|---|---|
| Repo 3.1.4 `tools/mac/freac/osx11` | 243 | 113 | **113** |
| Repo 3.1.4 `tools/mac/freac/osx10` | 100 | 54 | 0 |
| Repo 2.1.3 `tools/mac/freac` | 100 | 54 | 0 |
| App 3.1.4 `Resources/freac/osx11` | 247 | 113 | **113** |
| App 3.1.4 `Resources/freac/osx10` | 101 | 54 | 0 |

`main.cpp:148-155` wählt den Pfad zur Laufzeit: ab macOS 11 `FREAC_PATH_MAC11`
(`osx11`), darunter `FREAC_PATH_MAC10` (`osx10`).

Startprobe auf diesem Mac:

```
fre:ac - free audio converter v1.1.3b (ARM64) command line interface
Copyright (C) 2001-2020 Robert Kausch
```

`freaccmd` aus `osx11` startet **nativ als arm64** und meldet sich selbst als
ARM64-Build. Die `lsof`-Warnungen, die dabei auf der Fehlerausgabe erscheinen,
stammen aus seiner eigenen CD-Geräteerkennung.

**Folge für Entscheidung E3:** Das Hauptargument des Portierungsplans für den
Ersatz von fre:ac durch ffmpeg war, rund 100 x86_64-dylibs signieren zu
müssen. Für den `osx11`-Satz entfällt es: dort sind alle 113 Mach-O-Dateien
arm64-fähig, und `freaccmd` läuft ohne Rosetta. Der `osx10`-Satz mit 54
reinen x86_64-Dateien wird auf einem arm64-Build gar nicht geladen und könnte
entfallen. E3 sollte vor AA-4 neu bewertet werden.

## ffmpeg: drei Sätze, zwei davon identisch

| Satz | Zustand |
|---|---|
| Repo 2.1.3 `tools/mac/ffmpeg` | Referenz, unsigniert |
| Repo 3.1.4 `tools/mac/ffmpeg` | **byte-identisch** mit 2.1.3, alle elf Dateien |
| App 3.1.4 `Resources/ffmpeg` | andere Bytes, aber gleicher Build |

Die App-Kopien sind codesigniert (Hardened Runtime, Zeitstempel 7.11.2022),
daher 21 bis 47 KB größer. Versionskennung `N-93548-g4d2f62150d`,
configure-Zeile und `-buildconf` sind in allen drei Sätzen gleich. Empirisch
gegengeprüft: `volumedetect` auf `master.wav` liefert mit dem App-ffmpeg exakt
die Werte der 2.1.3-Referenz. Die Selbstauskunft des App-ffmpeg liegt unter
`../reference/altes-ffmpeg-app-3.1.4/`.

Praktische Folge: Die in AA-1 erhobene Referenz gilt für alle drei Sätze. Für
AA-2 heißt das, dass **ein** neuer arm64-Build beide Versionen bedient.

## B18, gemessen: die Versionsweiche wählt den falschen fre:ac-Satz

`main.cpp:148-155`:

```cpp
if( QSysInfo::productVersion().startsWith("11") )
    FREAC_PATH = … + FREAC_PATH_MAC11 + "freaccmd";
else
    FREAC_PATH = … + FREAC_PATH_MAC10 + "freaccmd";
```

Die Abfrage prüft die **macOS-Version als Zeichenkette**, nicht die
Architektur. `startsWith("11")` trifft nur auf macOS 11 selbst zu. Auf diesem
Mac liefert `productVersion()` `26.5.1`, die Bedingung ist falsch, und es wird
`osx10` gewählt.

Startproben beider Sätze:

| Satz | Architektur | Selbstauskunft | wird gewählt |
|---|---|---|---|
| `osx10` | i386, x86_64, ppc7400 | `fre:ac v1.1 Alpha 20190423a (x86-64)` | **ja**, auf jedem macOS ≠ 11 |
| `osx11` | x86_64, arm64 | `fre:ac v1.1.3b (ARM64)` | nur auf macOS 11 |

Auf macOS 12 bis 26 läuft der CD-Import damit über einen Alpha-Stand von
April 2019 unter Rosetta, während ein arm64-Release ungenutzt im Bundle liegt.
Ohne Rosetta, also ab macOS 27 beziehungsweise 28, startet er überhaupt nicht
mehr. Die Weiche ist vor jeder Entscheidung über fre:ac zu beheben.

## Fehlerfälle des MP3-Wegs

`fehlerfaelle/` enthält acht Eingaben aus AA-1b über alle schreibenden
Aufrufe. Auffällige Zellen:

* **`c-halbiert` liefert durchgehend Code 0** und eine Datei — bei C1, C2, C3,
  C5, C7, C9, C11 und C12. Der MP3-Weg verhält sich damit genauso blind wie
  der WAV-Weg in 2.1.3 (B15): rund die Hälfte der Spielzeit fehlt, gemeldet
  als Erfolg.
* **C5 / `h-kopf-ohne-daten`:** Code 1 und „Invalid" im Text, aber es entsteht
  trotzdem eine Ausgabedatei mit **0 Byte**. `changeMetaData` wertet nur
  `output.first==0`, verwirft also korrekt und löscht die Quelle nicht — die
  leere Temp-Datei bleibt aber liegen.
