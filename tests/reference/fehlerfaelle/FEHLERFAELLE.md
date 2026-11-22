# Rückgabecodes und Fehlerverhalten des alten ffmpeg

Erhoben für AA-1b am 22.11.2026 unter Rosetta 2 auf arm64, macOS 26.5.1,
mit `ffmpeg version N-93548-g4d2f62150d` aus `hoerbert/tools/mac/ffmpeg`.

Die Rohdaten liegen je Fall einzeln unter `erwartet/hart/` (Fehlerklasse)
und `erwartet/informativ/`. Diese Datei ist nur die Zusammenschau.

## Wie die App Fehler erkennt

| Aufruf | Zweck | Argumentliste | Fehlererkennung |
|---|---|---|---|
| **A1** | ffprobe, Metadaten und Dauer | `audioinfothread.cpp:82-90` | verwirft nur bei duration <= 0 |
| **A2** | Kapitelermittlung | `audiobookconverter.cpp:59-63` | Code auch im Erfolgsfall 1 |
| **A3** | Kapitelschnitt | `audiobookconverter.cpp:71-97` | sucht nur Error/Invalid im Text |
| **A4** | volumedetect | `hoerbertprocessor.cpp:617-633` | Code != 0 ergibt keine Korrektur |
| **A5** | convertToWav | `hoerbertprocessor.cpp:350-381` | wertet nur output.first == 0 |
| **A7** | silencedetect | `hoerbertprocessor.cpp:434-451` | bricht ab bei Code != 0 |
| **A13** | convertFlac2Wav | `backupmanager.cpp:404-411` | wertet nur output.first == 0 |

## Ergebnisse

`Code` ist der Rückgabecode. `Error` und `Invalid` sagen, ob das Wort in
genau dieser Schreibweise in den letzten 300 Zeichen der Ausgabe steht —
das ist die Prüfung, die A3 tatsächlich anwendet. `Datei` nennt, ob eine
Ausgabedatei entstand, und ihre Größe in Byte.

### A1 · ffprobe, Metadaten und Dauer

| Fall | Code | Error | Invalid | Datei | Größe |
|---|---|---|---|---|---|
| (a) nicht vorhandene Datei | 1 | nein | nein | schreibt keine | – |
| (b) Audio-Endung, zufälliger Inhalt | 1 | nein | nein | schreibt keine | – |
| (c) nach der Hälfte abgeschnitten | 0 | nein | nein | schreibt keine | – |
| (d) Ausgabeziel nicht beschreibbar | entfällt | – | – | – | ffprobe schreibt keine Ausgabedatei |
| (e) Textdatei mit .mp3 | 1 | nein | nein | schreibt keine | – |
| (f) nur erste 1.000 Byte | 1 | nein | nein | schreibt keine | – |
| (g) 0 Byte | 1 | nein | nein | schreibt keine | – |
| (h) WAV-Kopf ohne Audiodaten | 0 | nein | nein | schreibt keine | – |

### A2 · Kapitelermittlung

| Fall | Code | Error | Invalid | Datei | Größe |
|---|---|---|---|---|---|
| (a) nicht vorhandene Datei | 1 | nein | nein | schreibt keine | – |
| (b) Audio-Endung, zufälliger Inhalt | 1 | nein | ja | schreibt keine | – |
| (c) nach der Hälfte abgeschnitten | 1 | nein | nein | schreibt keine | – |
| (d) Ausgabeziel nicht beschreibbar | entfällt | – | – | – | dieser Aufruf hat keine Ausgabedatei |
| (e) Textdatei mit .mp3 | 1 | nein | ja | schreibt keine | – |
| (f) nur erste 1.000 Byte | 1 | nein | ja | schreibt keine | – |
| (g) 0 Byte | 1 | nein | ja | schreibt keine | – |
| (h) WAV-Kopf ohne Audiodaten | 1 | nein | nein | schreibt keine | – |

### A3 · Kapitelschnitt

| Fall | Code | Error | Invalid | Datei | Größe |
|---|---|---|---|---|---|
| (a) nicht vorhandene Datei | 1 | nein | nein | nein | - |
| (b) Audio-Endung, zufälliger Inhalt | 1 | nein | ja | nein | - |
| (c) nach der Hälfte abgeschnitten | 0 | nein | nein | ja | 128092 |
| (d) Ausgabeziel nicht beschreibbar | 1 | nein | nein | nein | - |
| (e) Textdatei mit .mp3 | 1 | nein | ja | nein | - |
| (f) nur erste 1.000 Byte | 1 | nein | ja | nein | - |
| (g) 0 Byte | 1 | nein | ja | nein | - |
| (h) WAV-Kopf ohne Audiodaten | 0 | nein | nein | ja | 92 |

### A4 · volumedetect

| Fall | Code | Error | Invalid | Datei | Größe |
|---|---|---|---|---|---|
| (a) nicht vorhandene Datei | 1 | nein | nein | schreibt keine | – |
| (b) Audio-Endung, zufälliger Inhalt | 1 | nein | ja | schreibt keine | – |
| (c) nach der Hälfte abgeschnitten | 0 | nein | nein | schreibt keine | – |
| (d) Ausgabeziel nicht beschreibbar | entfällt | – | – | – | volumedetect schreibt nach /dev/null |
| (e) Textdatei mit .mp3 | 1 | nein | ja | schreibt keine | – |
| (f) nur erste 1.000 Byte | 1 | nein | ja | schreibt keine | – |
| (g) 0 Byte | 1 | nein | ja | schreibt keine | – |
| (h) WAV-Kopf ohne Audiodaten | 0 | nein | nein | schreibt keine | – |

### A5 · convertToWav

| Fall | Code | Error | Invalid | Datei | Größe |
|---|---|---|---|---|---|
| (a) nicht vorhandene Datei | 1 | nein | nein | nein | - |
| (b) Audio-Endung, zufälliger Inhalt | 1 | nein | ja | nein | - |
| (c) nach der Hälfte abgeschnitten | 0 | nein | nein | ja | 190784 |
| (d) Ausgabeziel nicht beschreibbar | 1 | nein | nein | nein | - |
| (e) Textdatei mit .mp3 | 1 | nein | ja | nein | - |
| (f) nur erste 1.000 Byte | 1 | nein | ja | nein | - |
| (g) 0 Byte | 1 | nein | ja | nein | - |
| (h) WAV-Kopf ohne Audiodaten | 0 | nein | nein | ja | 132 |

### A7 · silencedetect

| Fall | Code | Error | Invalid | Datei | Größe |
|---|---|---|---|---|---|
| (a) nicht vorhandene Datei | 1 | nein | nein | schreibt keine | – |
| (b) Audio-Endung, zufälliger Inhalt | 1 | nein | ja | schreibt keine | – |
| (c) nach der Hälfte abgeschnitten | 0 | nein | nein | schreibt keine | – |
| (d) Ausgabeziel nicht beschreibbar | entfällt | – | – | – | silencedetect schreibt nach /dev/null |
| (e) Textdatei mit .mp3 | 1 | nein | ja | schreibt keine | – |
| (f) nur erste 1.000 Byte | 1 | nein | ja | schreibt keine | – |
| (g) 0 Byte | 1 | nein | ja | schreibt keine | – |
| (h) WAV-Kopf ohne Audiodaten | 0 | nein | nein | schreibt keine | – |

### A13 · convertFlac2Wav

| Fall | Code | Error | Invalid | Datei | Größe |
|---|---|---|---|---|---|
| (a) nicht vorhandene Datei | 1 | nein | nein | nein | - |
| (b) Audio-Endung, zufälliger Inhalt | 1 | nein | nein | nein | - |
| (c) nach der Hälfte abgeschnitten | 0 | nein | nein | ja | 525578 |
| (d) Ausgabeziel nicht beschreibbar | 1 | nein | nein | nein | - |
| (e) Textdatei mit .mp3 | 1 | nein | nein | nein | - |
| (f) nur erste 1.000 Byte | 1 | nein | nein | nein | - |
| (g) 0 Byte | 1 | nein | nein | nein | - |
| (h) WAV-Kopf ohne Audiodaten | 0 | nein | nein | ja | 198 |

## Die Zellen, in denen die App einen Fehlschlag als Erfolg wertet

Nach dem Code von heute, ohne jede Änderung daran:

1. **A1 / (c) halbierte MP3.** ffprobe meldet Code 0 und `duration`
   6,034286 — die Dauer der *vollständigen* Datei, weil der Xing-Header die
   ursprüngliche Frame-Anzahl trägt. Die Prüfung `duration <= 0`
   (`audioinfothread.cpp:118`) greift nicht, die Datei kommt in die Liste,
   und sowohl die angezeigte Dauer als auch der über
   `playlistview.cpp:198` gerechnete Platzbedarf sind doppelt zu groß.
2. **A3 / (a) nicht vorhandene Datei.** Code 1, Ausgabe
   `No such file or directory` — ohne „Error" und ohne „Invalid". A3 prüft
   nur diese zwei Wörter, löst also kein `failed()` aus. Der Ausgabepfad
   steht zu diesem Zeitpunkt bereits in `info_list`.
3. **A3 / (d) gesperrtes Ausgabeziel.** Code 1, Ausgabe `Permission denied`
   — ebenfalls ohne die beiden Wörter. Kein Fehler wird gemeldet, keine
   Datei entsteht.
4. **A5 / (c) halbierte MP3.** Code 0, also Erfolg. Die erzeugte WAV hat
   190.784 Byte, das sind 2,97 von 6 Sekunden. Die Hälfte des Hörstücks
   fehlt auf der Karte, ohne jede Meldung.
5. **A13 / (c) halbierte MP3.** Code 0, 525.578 Byte. Beim Zurückspielen
   eines Backups derselbe stille Verlust.

Daneben, kein Fehlschlag im strengen Sinn, aber dieselbe Blindheit:
**A4 / (c)** liefert Code 0 und misst den Maximalpegel über die halbe
Datei. Die daraus abgeleitete Korrektur wird auf das Ganze angewandt.

Erkannt wird nur **A3 / (b)**: Bei zufälligem Inhalt meldet ffmpeg
`Invalid data found when processing input`, und A3 schlägt an. Das ist der
einzige der acht Fälle, in dem die Textsuche von A3 ihren Zweck erfüllt.

Festgehalten als B13, B14 und B15 in `../AUFRUFE.md`.

## Nachtrag: Fall (c) für weitere Quellformate

Der Fall „nach der Hälfte abgeschnitten" war zunächst nur mit `halb-ton.mp3`
erhoben. MP3 ist dabei der günstigste Fall: ein MP3-Strom besteht aus
unabhängigen Frames, ein Schnitt mitten hinein kostet nur den Rest. Bei einem
MP4-Container (m4a, m4b) steht die Indextabelle `moov` am Dateiende, bei FLAC
und Ogg hängt die Lesbarkeit an Block- und Seitengrenzen. Das Verhalten ist
daher je Format zu messen, nicht zu verallgemeinern.

| Quelle | Byte | Aufruf | Code | Error | Invalid | Datei | Größe | A1-Dauer |
|---|---|---|---|---|---|---|---|---|
| `halb-kapitel.m4b` | 44.632 von 89.264 | **A1** | 1 | nein | nein | schreibt keine | – | (fehlt) |
|  |  | **A2** | 1 | nein | ja | schreibt keine | – |  |
|  |  | **A3** | 1 | nein | ja | nein | - |  |
|  |  | **A4** | 1 | nein | ja | schreibt keine | – |  |
| `halb-backup.flac` | 65.794 von 131.589 | **A1** | 0 | nein | nein | schreibt keine | – | 6.000000 |
|  |  | **A13** | 0 | nein | nein | ja | 179862 |  |
| `halb-ton.m4a` | 44.240 von 88.480 | **A1** | 1 | nein | nein | schreibt keine | – | (fehlt) |
|  |  | **A5** | 1 | nein | ja | nein | - |  |
| `halb-ton.ogg` | 13.694 von 27.389 | **A1** | 0 | nein | nein | schreibt keine | – | 2.015782 |
|  |  | **A5** | 0 | nein | nein | ja | 129146 |  |
| `halb-ton.wma` | 104.272 von 208.544 | **A1** | 0 | nein | nein | schreibt keine | – | 4.322000 |
|  |  | **A5** | 0 | ja | ja | ja | 193326 |  |
| `halb-ton.flac` | 43.633 von 87.266 | **A1** | 0 | nein | nein | schreibt keine | – | 6.000000 |
|  |  | **A5** | 0 | ja | ja | ja | 174006 |  |

### Was daraus folgt

**Der MP4-Container schützt.** `halb-kapitel.m4b` und `halb-ton.m4a` werden
durchgehend mit Code 1 abgewiesen, weil die Indextabelle am Dateiende fehlt.
Bei A2, A3, A4 und A5 steht zusätzlich „Invalid" im Text, A3 würde es also
auch über seine Textsuche bemerken. Das ist der einzige Formatfall, der
sauber scheitert.

**FLAC lügt über die Dauer.** Für `halb-backup.flac` und `halb-ton.flac`
meldet ffprobe Code 0 und als Dauer glatte **6.000000** Sekunden — die Dauer
der vollständigen Datei, weil der `STREAMINFO`-Block die Gesamtzahl der
Samples trägt und ffprobe ihm folgt. Wiederherstellbar sind 2,72 bzw. 2,81
Sekunden. Dasselbe Muster wie beim Xing-Header von MP3 (B15), nur noch
deutlicher, weil der Wert exakt und damit unverdächtig aussieht.

**Ogg und WMA melden kürzer, aber nicht richtig.** Ogg gibt 2,015782
Sekunden an und konvertiert 2,02 — konsistent. WMA gibt 4,322 Sekunden an
und konvertiert 3,02; die Differenz von 1,3 Sekunden fällt niemandem auf.

**Der schwerste Befund: Code 0 trotz Fehlermeldung.** Bei `halb-ton.wma` und
`halb-ton.flac` schreibt ffmpeg wörtlich

```
Error while decoding stream #0:0: Invalid data found when processing input
```

und beendet sich trotzdem mit **Code 0**. A5 wertet ausschließlich
`output.first==0` und zählt das als Erfolg. Die Meldung enthält sogar beide
Wörter, auf die A3 prüft — die Information liegt also vor, A5 sieht nur nicht
hin. Ein Parser, der an dieser Stelle den Text mitliest, würde fünf der acht
stillen Fälle abfangen.

### Zellen, in denen die App einen Fehlschlag als Erfolg wertet

1. **A1 / `halb-backup.flac`** — Code 0, Dauer 6,000000 statt 2,81 s.
2. **A1 / `halb-ton.flac`** — Code 0, Dauer 6,000000 statt 2,72 s.
3. **A1 / `halb-ton.wma`** — Code 0, Dauer 4,322 statt 3,02 s.
4. **A5 / `halb-ton.wma`** — Code 0 trotz „Error" und „Invalid" im Text;
   193.326 Byte, 3,02 von 6,00 s (50,3 %).
5. **A5 / `halb-ton.flac`** — Code 0 trotz „Error" und „Invalid" im Text;
   174.006 Byte, 2,72 von 6,00 s (45,3 %).
6. **A5 / `halb-ton.ogg`** — Code 0, keine Marker, kein Hinweis irgendeiner
   Art; 129.146 Byte, 2,02 von 6,00 s (33,6 %).
7. **A13 / `halb-backup.flac`** — Code 0; 179.862 Byte, 2,81 von 6,00 s
   (46,8 %). Ein Backup wird zu knapp der Hälfte zurückgespielt, gemeldet
   als Erfolg.

Nicht in dieser Liste, weil korrekt abgewiesen: alle vier Zellen von
`halb-kapitel.m4b` und beide von `halb-ton.m4a`.

Festgehalten als B16 in `../AUFRUFE.md`.
