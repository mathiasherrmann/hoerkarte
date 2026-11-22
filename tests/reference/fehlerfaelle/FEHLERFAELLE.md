# Rückgabecodes und Fehlerverhalten des alten ffmpeg

Erhoben am 2026-11-22 14:35 CET mit
`ffmpeg version N-93548-g4d2f62150d Copyright (c) 2000-2019 the FFmpeg developers`
auf arm64 unter Rosetta 2, macOS 26.5.1.

Die Spalte "Code" ist der Rückgabecode des Prozesses. Die Spalte
"App-Folge" nennt, was die Anwendung daraus macht — siehe die
Erläuterung im Kopf von `tests/lauf-fehlerfaelle.sh`.

## A1 · ffprobe, Metadaten und Dauer

Argumentliste: `audioinfothread.cpp:82-90`. Die App verwirft eine Datei,
wenn `format.duration` fehlt oder nicht größer als 0 ist.

| Eingabe | Code | format.duration | App-Folge |
|---|---|---|---|
| `leer.mp3` | 1 | `(fehlt)` | übersprungen |
| `text.mp3` | 1 | `(fehlt)` | übersprungen |
| `abgeschnitten.mp3` | 1 | `(fehlt)` | übersprungen |
| `kopf-ohne-daten.wav` | 0 | `0.000703` | in Liste aufgenommen |
| `gibt-es-nicht.mp3` | 1 | `(fehlt)` | übersprungen |

## A2 · ffmpeg, Kapitelermittlung

Argumentliste: `audiobookconverter.cpp:59-63`. Findet `parseForChapters`
keinen Abschnitt `Chapter #`, läuft die Schleife über eine leere Liste —
es wird kein Fehler gemeldet, es entsteht nur keine Ausgabedatei.

| Eingabe | Code | enthält "Chapter #" | letzte Ausgabezeile |
|---|---|---|---|
| `leer.mp3` | 1 | nein | `<SCHLECHT>/leer.mp3: Invalid argument` |
| `text.mp3` | 1 | nein | `<SCHLECHT>/text.mp3: Invalid argument` |
| `abgeschnitten.mp3` | 1 | nein | `<SCHLECHT>/abgeschnitten.mp3: Invalid argument` |
| `kopf-ohne-daten.wav` | 1 | nein | `At least one output file must be specified` |
| `gibt-es-nicht.mp3` | 1 | nein | `<SCHLECHT>/gibt-es-nicht.mp3: No such file or directory` |

## A4 · ffmpeg, volumedetect

Argumentliste: `hoerbertprocessor.cpp:617-633`. Bei einem Code ungleich 0
verlässt `getVolumeDifference` die Funktion mit `return false` — in einer
Funktion mit Rückgabetyp `double`, was 0.0 ergibt und damit "keine
Korrektur" bedeutet (siehe B12 in `AUFRUFE.md`).

| Eingabe | Code | max_volume gefunden | App-Folge |
|---|---|---|---|
| `leer.mp3` | 1 | nein | keine Korrektur (0.0) |
| `text.mp3` | 1 | nein | keine Korrektur (0.0) |
| `abgeschnitten.mp3` | 1 | nein | keine Korrektur (0.0) |
| `kopf-ohne-daten.wav` | 0 | ja | Korrektur berechnet |
| `gibt-es-nicht.mp3` | 1 | nein | keine Korrektur (0.0) |

## A5 · ffmpeg, convertToWav

Argumentliste: `hoerbertprocessor.cpp:350-381`. Rückgabe ist
`output.first==0`; ein Code ungleich 0 zählt als fehlgeschlagener Eintrag.

| Eingabe | Code | Ausgabedatei entstanden | Bytes | App-Folge |
|---|---|---|---|---|
| `leer.mp3` | 1 | nein | - | FAILURE gezählt |
| `text.mp3` | 1 | nein | - | FAILURE gezählt |
| `abgeschnitten.mp3` | 1 | nein | - | FAILURE gezählt |
| `kopf-ohne-daten.wav` | 0 | ja | 134 | als Erfolg gewertet |
| `gibt-es-nicht.mp3` | 1 | nein | - | FAILURE gezählt |

## A7 · ffmpeg, silencedetect

Argumentliste: `hoerbertprocessor.cpp:434-451`. Bei Code ungleich 0 meldet
die App `Failed to execute ffmpeg command` und bricht den Schnitt ab
(`hoerbertprocessor.cpp:454-459`).

| Eingabe | Code | silencedetect-Zeilen | Duration-Zeile |
|---|---|---|---|
| `leer.mp3` | 1 | 0 | nein |
| `text.mp3` | 1 | 0 | nein |
| `abgeschnitten.mp3` | 1 | 0 | nein |
| `kopf-ohne-daten.wav` | 0 | 0 | ja |
| `gibt-es-nicht.mp3` | 1 | 0 | nein |

## Rückgabecodes der Erfolgsfälle

Damit erkennbar ist, welcher Code "in Ordnung" bedeutet.

| Aufruf | Eingabe | Code |
|---|---|---|
| A1 ffprobe | `ton.mp3` | 0 |
| A2 Kapitel | `kapitel.m4b` | 1 |
| A4 volumedetect | `master.wav` | 0 |
| A5 convertToWav | `ton.mp3` | 0 |
| A7 silencedetect | `stille-kurz.wav` | 0 |
