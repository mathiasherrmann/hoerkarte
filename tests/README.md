# Referenzdaten und Prüfverfahren der Audio-Pipeline (AA-1)

Erhoben am 22.11.2026 auf einem Apple-Silicon-Mac (arm64, macOS 26.5.1) mit
installiertem Rosetta 2, gegen Commit `7f225e2` im Zweig `port/macos-arm64`.

**Dieser Text ist nach AA-0 in `ARCHITECTURE.md` zu übernehmen.** AA-1 verlangt,
dass `ARCHITECTURE.md` das Verfahren beschreibt; diese Datei existierte zum
Zeitpunkt der Erhebung noch nicht, weil AA-0 zurückgestellt wurde.

## Wozu das Ganze

Die hörbert-Software macht die eigentliche Audioarbeit nicht selbst, sondern
ruft ein mitgeliefertes ffmpeg auf und **liest dessen Textausgabe**. Sie sucht
nach Zeilen wie `silence_start:`, `max_volume:`, `Duration:` und nach dem
Kapitelblock eines Hörbuchs. Ändert eine neue ffmpeg-Version den Wortlaut, das
Format oder die Reihenfolge dieser Ausgaben, bricht die Funktion **still** — die
App kompiliert, startet, läuft, und erzeugt falsche oder leere Ergebnisse.

Genauso gilt: Die erzeugten WAV-Dateien werden von der hörbert-Firmware direkt
gelesen. Ob ein neues ffmpeg sie strukturell gleich schreibt, entscheidet
darüber, ob eine bespielte Karte im Gerät läuft.

Beides lässt sich nicht erraten, nur messen. Deshalb wird die Referenz erhoben,
**bevor** eine Zeile Anwendungscode geändert wird — und vor allem, solange das
alte x86_64-Binary überhaupt noch läuft.

## Warum der Zeitpunkt zählte

Das mitgelieferte ffmpeg ist ausschließlich x86_64 (siehe
`reference/altes-ffmpeg/HERKUNFT.md`). Auf Apple Silicon läuft es nur über
Rosetta 2. Mit dem Wechsel auf macOS 27 wird Rosetta entfernt; ab macOS 28 ist
es für normale Anwendungen endgültig weg. Nach dem Systemwechsel ist die
Referenz nicht mehr neu erhebbar — die hier abgelegten Daten sind dann die
einzige Vergleichsgrundlage, die es noch gibt.

## Was hier liegt

```
tests/
├── README.md                  diese Beschreibung
├── wav-struktur.py            RIFF-/AIFF-Chunk-Leser, ohne Fremdbibliotheken
├── wav-kopf.py                Kopfbereich einer Datei als annotierter Hexdump
├── lauf.sh                    führt alle App-Aufrufe aus und misst die Ergebnisse
├── lauf-fehlerfaelle.sh       erhebt Rückgabecodes und Verhalten bei Fehlern
├── compare.sh                 vergleicht einen ffmpeg-Satz gegen die Referenz
└── reference/
    ├── AUFRUFE.md             alle Aufrufe mit Datei und Zeilennummer
    ├── ARCHIV.md              was außerhalb des Repositorys liegt, mit Prüfsummen
    ├── erzeuge-quellen.sh     erzeugt die Testdateien aus synthetischen Signalen
    ├── fehlerfaelle/          Rückgabecodes und Ausgaben bei fehlerhaften Eingaben
    │   ├── FEHLERFAELLE.md    die Auswertung als Tabelle je Aufruf
    │   └── schlechte-eingaben/ die vier Prüfdateien, zusammen unter 2 KB
    ├── altes-ffmpeg/          Selbstauskunft des alten Binärsatzes
    │   ├── HERKUNFT.md        SHA-256, Architektur, Bibliotheksbindung
    │   ├── *.version.txt      Version und configure-Zeile
    │   ├── *.buildconf.txt    Build-Konfiguration
    │   └── ffmpeg.*.txt       Decoder, Encoder, Demuxer, Muxer, Filter, Formate,
    │                          Codecs, Bitstromfilter, Protokolle, Kanallayouts,
    │                          Sample- und Pixelformate
    ├── quellen/               die Testdateien
    └── erwartet/              die Referenz
        ├── rohausgaben/       vollständige Textausgabe je Aufruf, zusätzlich
        │                      in normalisierter Fassung
        ├── geparst/           nur die Zeilen, die die App tatsächlich auswertet
        ├── erzeugte-wavs/     Messwerte und PCM-Prüfsummen der Ergebnisdateien
        └── wav-koepfe/        Kopfbereich jeder Ergebnisdatei als Hexdump
```

## Die erzeugten Audiodateien selbst

Sie liegen **nicht** im Repository, sondern unter
`/Users/mathias/Projekte/hoerkarte-archiv/aa1-ffmpeg-ausgaben/`, mit
Prüfsummenliste und Herkunftsvermerk. `reference/ARCHIV.md` hält Ablageort und
Prüfsummen fest.

Ein früherer Stand dieser Beschreibung nannte die Dateien „aus den Quellen
jederzeit reproduzierbar". **Das ist falsch.** Reproduzierbar sind sie nur mit
dem alten x86_64-ffmpeg, und das lässt sich ohne Rosetta nicht mehr starten. Sie
sind damit genauso unwiederbringlich wie die Messwerte selbst und gehören
gesichert, nicht in ein temporäres Verzeichnis.

Was ersatzweise im Repository liegt, ist der Kopfbereich jeder Datei als
annotierter Hexdump unter `erwartet/wav-koepfe/` — 80 KB für alle 20 Dateien.
Dort ist alles sichtbar, was über die Lesbarkeit durch die hörbert-Firmware
entscheidet: Chunk-Reihenfolge, `fmt`-Parameter und der `LIST`/`INFO`-Block mit
den Metadaten. Für die Audiodaten selbst braucht es das Archiv.

## Die Testdateien

Ausschließlich synthetisch erzeugt — Sinustöne und Stille aus `lavfi`, kein
Fremdmaterial, kein urheberrechtlich geschützter Inhalt. Erzeugt mit dem alten
ffmpeg selbst, damit nichts installiert werden musste. Nachbaubar über
`reference/erzeuge-quellen.sh`.

Zur Reproduzierbarkeit, nachgemessen: Ein zweiter Lauf des Generators liefert
zehn der elf Dateien **bitgleich**. Einzige Ausnahme ist `ton.ogg`: libvorbis
schreibt eine zufällige Seriennummer in den Ogg-Datenstrom, woraus 64
abweichende Bytes in den Seitenköpfen und deren Prüfsummen folgen. Der
dekodierte PCM-Inhalt ist nachweislich identisch (gleiche SHA-256 über die
Rohdaten). Auf den Vergleich in `compare.sh` wirkt sich das nicht aus, weil
dort die Quelldateien nicht verglichen werden, sondern nur die Ergebnisse der
App-Aufrufe.

| Datei | Inhalt | Prüfzweck |
|---|---|---|
| `master.wav` | 6 s, 44100 Hz, stereo, drei Tonstufen 440/880/1320 Hz | Ausgangssignal; absichtlich nicht 32 kHz mono, damit Resampling und Downmix wirklich arbeiten |
| `ton.wav` `.mp3` `.m4a` `.ogg` `.flac` `.wma` `.aiff` | dasselbe Signal je Container | Formatfächer über alle in `define.h:53` genannten Eingangsformate |
| `kapitel.m4b` | drei Kapitelmarken über 6 s | der Kapitelparser aus `audiobookconverter.cpp` |
| `stille-kurz.wav` | Ton 3 s / Stille 2 s / Ton 3 s / Stille 2 s / Ton 3 s | Ausgabeformat von `silencedetect` |
| `stille-lang.flac` | Ton 200 s / Stille 3 s / Ton 185 s / Stille 3 s / Ton 20 s | der Schneidepfad; siehe unten |
| `leise.wav` | Mastersignal um 30 dB abgesenkt | `volumedetect` und die Lautstärkekorrektur |

`stille-lang` ist als FLAC abgelegt, nicht als WAV: verlustfrei, PCM
bit-identisch nachgewiesen, 4,5 MB statt 72 MB. `.flac` ist ein von der App
unterstütztes Eingangsformat.

### Warum die lange Datei nötig ist

`HoerbertProcessor::splitOnSilence` schneidet nur an Stillephasen, deren Beginn
jenseits von 180 Sekunden liegt (`hoerbertprocessor.cpp:505`), und erhöht diese
Schwelle nach jedem Schnitt um weitere 180 Sekunden (`:519`). Eine kurze
Testdatei durchläuft den Schneidepfad daher **nie**, gleichgültig wie viele
Stillephasen sie enthält. Der Aufbau von `stille-lang.flac` ist so gewählt, dass
genau zwei Schnitte entstehen; gemessen wurde `chunk_count: 2` mit den Grenzen
203,0 und 391,0 Sekunden, wie vorab gerechnet.

## Das Prüfverfahren

```
tests/compare.sh <ffmpeg-verzeichnis>
```

Das Skript führt über `lauf.sh` dieselben Aufrufe mit dem übergebenen
ffmpeg-Verzeichnis aus und vergleicht das Ergebnis gegen `reference/erwartet/`.
Die Einstufung folgt der Vorgabe aus AA-1:

| Eingestuft als | Was darunter fällt |
|---|---|
| **FEHLER** | die von der App geparsten Zeilen; Codec, Abtastrate, Kanalzahl, Bittiefe und Dauer; Reihenfolge der RIFF-Chunks; Größe des `data`-Chunks; die Metadaten `title`, `album`, `comment` |
| **HINWEIS** | die Prüfsumme über die reinen PCM-Daten; Länge des `LIST`/`INFO`-Chunks, Dateigröße, Bitrate und die daraus folgenden Chunk-Offsets; das `encoder`-Tag |

Die Trennung ist eine Auslegungsentscheidung und in `compare.sh` offen gelegt:
Dateigröße und `LIST`-Länge hängen unmittelbar an der Länge der Zeichenkette,
die ffmpeg als `encoder`-Tag schreibt (hier `Lavf58.27.100`). Dieser Wert ändert
sich mit **jeder** Version, ohne dass sich am Audioinhalt etwas ändert. Würde er
als Fehler gelten, schlüge der Vergleich gegen jedes neue ffmpeg fehl und wäre
nutzlos. Die Chunk-**Reihenfolge** wird dagegen hart geprüft, denn ein
zusätzlicher oder fehlender Chunk verändert die Datei strukturell. Wer die
Einstufung anders braucht, ändert die Listen `FEHLERFELDER` und `HINWEISFELDER`
in `compare.sh`.

Für AA-2 gilt die Vorgabe des Plans: Meldet `compare.sh` einen Fehler in
geparsten Zeilen oder in der WAV-Struktur, wird **nicht** der Parser und
**nicht** die Referenz angepasst, sondern gestoppt und berichtet.

### Umgang mit flüchtigen Werten

Rohausgaben werden zusätzlich normalisiert abgelegt: Speicheradressen in
Filternamen (`@ 0x…`), Laufzeit-, Größen- und Geschwindigkeitsangaben sowie die
absoluten Pfade des Arbeitsverzeichnisses werden ersetzt. Ohne das wäre kein
zwei Läufe überdauernder Vergleich möglich. Die Rohausgaben gehen nicht in die
Bewertung ein; sie werden nur gezählt und sind Beleg für eine Nachprüfung von
Hand.

### Feste Einstellungen

Die Lautstärkekorrektur hängt an zwei Werten aus `QSettings`, die die App zur
Laufzeit liest. Für die Referenz sind sie in `lauf.sh` festgeschrieben:
`Global/volume` = −1,5 dB (der Fallback der App, im Quelltext als „Not to ever
ever change" markiert) und `Global/increaseVolume` = wahr. Letzteres ist
bewusst gegen die Programmvorgabe gesetzt, damit der `-af volume=`-Pfad
überhaupt durchlaufen wird.

## Stand der Referenz

Selbstprüfung gegen das alte ffmpeg: **0 Fehler, 0 Hinweise**, alle 23
normalisierten Rohausgaben identisch. Das Verfahren ist also reproduzierbar.

Gegenprobe zur Wirksamkeit: Mit absichtlich verfälschter Referenz (ein
`silence_start`-Wert, eine Abtastrate, eine PCM-Prüfsumme) meldet `compare.sh`
zwei Fehler und einen Hinweis und endet mit „NICHT BESTANDEN". Das Skript
bestätigt also nicht stumm.

### Rückgabecodes und Fehlerfälle

`reference/fehlerfaelle/FEHLERFAELLE.md` hält fest, welchen Rückgabecode jeder
Aufruf liefert und was die App daraus macht. Das braucht eine eigene Erhebung,
weil die App Fehler auf drei verschiedene Weisen erkennt: über den
Rückgabecode (A5, A6, A10 bis A13), über eine Textsuche nach `Error` oder
`Invalid` (A3), oder über den Wert `format.duration` (A1). Zwei Ergebnisse sind
dabei nicht selbstverständlich:

* **A2 liefert auch im Erfolgsfall Code 1.** Der Aufruf hat keine Ausgabedatei,
  ffmpeg bricht ab. Dieser Aufruf darf also niemals über den Rückgabecode
  bewertet werden.
* **Eine abgeschnittene WAV ohne Audiodaten wird überall akzeptiert.** Sie
  erhält Code 0, eine Dauer von 0,000703 Sekunden und landet als 134 Byte große
  Datei auf der Karte. Festgehalten als B13 in `AUFRUFE.md`.

### Was die Referenz nicht abdeckt

Ehrlich benannte Lücken, damit niemand mehr aus diesen Daten liest, als darin
steckt:

* **A14, `ffplay`.** Das Vorhören erzeugt keine Datei und keine auswertbare
  Textausgabe. Es bleibt eine manuelle Abnahme.
* **freaccmd und das CD-Einlesen.** Nicht Teil der ffmpeg-Pipeline, und ohne
  Laufwerk und Audio-CD nicht prüfbar. Entspricht Abnahme M3.
* **Echte Musik und Sprache.** Geprüft wird mit Sinustönen. Ein Codec kann sich
  bei synthetischen Signalen anders verhalten als bei realem Material. Die
  Aussagekraft endet an der Pipeline, nicht am Hörergebnis.
* **Das Gerät selbst.** Ob die hörbert-Firmware eine erzeugte Karte abspielt,
  beantwortet keine Prüfsumme. Das ist Abnahme M2 und bleibt das eigentliche
  Abnahmekriterium des Projekts.
* **Lange Metadaten und Sonderzeichen.** Die Titel in der Referenz sind kurz
  und ASCII. Die Beschneidung auf 80 Byte und das Verhalten bei Umlauten in
  Metadaten sind nicht abgedeckt und sollten in AA-3 eigene Prüffälle bekommen.
