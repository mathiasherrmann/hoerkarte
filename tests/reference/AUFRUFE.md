# Aufrufe von ffmpeg, ffprobe, ffplay und freaccmd im Quellcode

Erhoben für AA-1 am 22.11.2026 aus Commit `7f225e2`, Zweig `port/macos-arm64`.
Grundlage ist der Quelltext, nicht die Laufzeitbeobachtung: jede Argumentliste
unten ist der Stelle entnommen, die sie aufbaut. `ARCHITECTURE.md` existiert
noch nicht (AA-0 ist zurückgestellt), deshalb tritt diese Datei vorläufig an
ihre Stelle.

## Wie die Programmpfade entstehen

`main.cpp:43-46` deklariert vier globale Zeichenketten, die in `main.cpp:100-166`
plattformabhängig belegt werden. Auf macOS (`main.cpp:142-148`):

| Variable | Zusammensetzung | Ergebnis im Bundle |
|---|---|---|
| `FFMPEG_PATH` | `applicationDirPath()` + `FFMPEG_PATH_MAC` + `"ffmpeg"` | `Contents/Resources/ffmpeg/ffmpeg` |
| `FFPROBE_PATH` | dito + `"ffprobe"` | `Contents/Resources/ffmpeg/ffprobe` |
| `FFPLAY_PATH` | dito + `"ffplay"` | `Contents/Resources/ffmpeg/ffplay` |
| `FREAC_PATH` | `applicationDirPath()` + `FREAC_PATH_MAC` + `"freaccmd"` | `Contents/Resources/freac/MacOS/freaccmd` |

`FFMPEG_PATH_MAC` ist `/../Resources/ffmpeg/` (`define.h:127`), `FREAC_PATH_MAC`
ist `/../Resources/freac/MacOS/` (`define.h:131`). Beim Start prüft
`main.cpp:176-213` jede der vier Dateien auf Existenz und bricht sonst ab.

Alle Aufrufe laufen über `ProcessExecutor::executeCommand`
(`processexecutor.cpp:10-49`), das Programm und Argumentliste getrennt an
`QProcess::start` gibt und `MergedChannels` setzt — Standardausgabe und
Fehlerausgabe landen also in einem Strom. Das ist wichtig, weil ffmpeg seine
Analyseausgaben auf die Fehlerausgabe schreibt und die App sie trotzdem liest.

## Die Aufrufe

Kennzeichnung A1 bis A14 wird in `tests/lauf.sh` und in den Dateinamen unter
`erwartet/` verwendet.

### A1 · ffprobe: Metadaten und Dauer

* Argumentliste: `audioinfothread.cpp:82-90`
* Ausgeführt: `audioinfothread.cpp:103`
* Ausgewertet: `audioinfothread.cpp:105-119`

```
-i <DATEI> -hide_banner -show_format -print_format json -v quiet
```

Gelesen werden ausschließlich `format.tags.title`, `format.tags.album`,
`format.tags.comment` und `format.duration`. Ist `duration` kleiner oder gleich
0, überspringt die App die Datei (`audioinfothread.cpp:118`). Dieser Aufruf
entscheidet also darüber, ob eine Datei überhaupt in der Liste erscheint.

### A2 · ffmpeg: Kapitel eines Hörbuchs ermitteln

* Argumentliste: `audiobookconverter.cpp:59-63`
* Ausgeführt: `audiobookconverter.cpp:64`
* Ausgewertet: `audiobookconverter.cpp:160-232` (`parseForChapters`)

```
-i <DATEI> -hide_banner
```

Ein Aufruf ohne Ausgabedatei; ffmpeg bricht mit Fehlercode ab, und die App liest
den Informationsblock. Gemessen: Der Rückgabecode ist **auch im Erfolgsfall 1**
(siehe `fehlerfaelle/FEHLERFAELLE.md`). Dieser Aufruf darf deshalb nie über den
Rückgabecode bewertet werden — eine Falle für jede Umstellung in AA-3. Geparst wird der Textabschnitt zwischen `Chapter #` und
`Stream #`, daraus je Kapitel `start`, `end` und der Titel aus dem
`Metadata:`-Block. Das ist der empfindlichste Parser im Programm: er hängt an
Einrückung, Reihenfolge und Wortlaut der ffmpeg-Ausgabe.

### A3 · ffmpeg: Kapitel in WAV schneiden

* Argumentliste: `audiobookconverter.cpp:71-97`
* Ausgeführt: `audiobookconverter.cpp:123`

```
-i <DATEI> -ss <START> -to <ENDE> -acodec pcm_s16le -ar 32k -ac 1 \
  -metadata title=<TITEL> -y -hide_banner [-af volume=<N>dB] <AUSGABE>
```

Der `-af`-Parameter wird nur angehängt, wenn die Korrektur aus A4 betragsmäßig
zwischen 0,1 und 20 dB liegt (`audiobookconverter.cpp:91-95`). Der Titel wird
vorher auf `METADATA_MAX_LENGTH` = 80 Byte beschnitten (`define.h:149`).
Erfolgsprüfung erfolgt über eine Textsuche nach `Error` oder `Invalid` in den
letzten 300 Zeichen der Ausgabe (`audiobookconverter.cpp:125-127`), nicht über
den Rückgabecode.

### A4 · ffmpeg: Maximalpegel ermitteln

* Argumentliste: `audiobookconverter.cpp:250-266`
* Ausgeführt: `audiobookconverter.cpp:270`
* Ausgewertet: `audiobookconverter.cpp:272-290`

```
-i <DATEI> -af volumedetect -vn -sn -dn -hide_banner -f null /dev/null
```

Auf Windows steht `NUL` statt `/dev/null` (`audiobookconverter.cpp:262-266`).
Gesucht wird die erste Zeile, die mit `[Parsed_volumedetect` beginnt und nach
`max_volume:` einen Wert enthält. Aus diesem Wert und der Einstellung
`Global/volume` (Vorgabe −1,5 dB) entsteht die Korrektur; ist
`Global/increaseVolume` falsch, werden positive Korrekturen verworfen.

### A5 · ffmpeg: Umwandlung in das Kartenformat

* Argumentliste: `hoerbertprocessor.cpp:350-381`
* Ausgeführt: `hoerbertprocessor.cpp:383`

```
-i <DATEI> -acodec pcm_s16le -ar 32k -ac 1 \
  -metadata title=<TITEL> -metadata album=<ALBUM> -metadata comment=<QUELLPFAD> \
  [-af volume=<N>dB] -y -hide_banner <AUSGABE>
```

Der Hauptpfad der Anwendung: jede Datei, die auf die Karte kommt, läuft hier
durch. Grenze der Lautstärkekorrektur hier 30 dB, nicht 20 (`:372`).
Bemerkenswert: `comment` wird mit dem Quellpfad belegt, nicht mit dem
Benutzerkommentar (`:369`).

### A6 · ffmpeg: Zerlegen in 180-Sekunden-Stücke

* Argumentliste: `hoerbertprocessor.cpp:391-424`
* Ausgeführt: `hoerbertprocessor.cpp:426`

```
-i <DATEI> -acodec pcm_s16le -ar 32k -ac 1 -y -hide_banner \
  -metadata title=<TITEL> -metadata album=<ALBUM> -metadata comment=<KOMMENTAR> \
  -f segment -segment_time 180 [-af volume=<N>dB] <ZIEL>/<N>-%01d.WAV -y
```

`180` kommt aus `SPLIT_AUDIO_SEGMENT_LENGTH` (`hoerbertprocessor.h:34`).
Das Namensmuster `%01d` begrenzt die Nummerierung auf eine Stelle; bei mehr als
zehn Segmenten erzeugt ffmpeg trotzdem zweistellige Namen, die
`renameSplitFiles` danach einsammelt.

### A7 · ffmpeg: Stillephasen erkennen

* Argumentliste: `hoerbertprocessor.cpp:434-451`
* Ausgeführt: `hoerbertprocessor.cpp:452`
* Ausgewertet: `hoerbertprocessor.cpp:462-473`

```
-i <DATEI> -af silencedetect=n=-40dB:d=0.1 -hide_banner -f null /dev/null
```

Schwelle `-40dB` und Mindestdauer `0.1` stehen in `hoerbertprocessor.cpp:49-50`.
Geparst werden zwei Dinge: Zeilen, die mit `[silencedetect` beginnen, davon der
Teil hinter der schließenden Klammer, und die Zeile `Duration:` bis zum ersten
Komma. Die Gesamtlänge wird aus dieser Textangabe gerechnet
(`hoerbertprocessor.cpp:482-484`), nicht aus ffprobe.

### A8 · ffmpeg: Schnitt an den Stillephasen

* Argumentliste: `hoerbertprocessor.cpp:479-571`
* Ausgeführt: `hoerbertprocessor.cpp:572` und, je Folgesegment, `:592`

```
-i <DATEI> -ss <START> -to <ENDE> -acodec pcm_s16le -ar 32k -ac 1 \
  -y -hide_banner -metadata title=<TITEL> -metadata album=<ALBUM> \
  -metadata comment=<KOMMENTAR> [-af volume=<N>dB] <ZIEL>/<N>-<M>.WAV
```

Wichtig für jeden Test: geschnitten wird nur an Stillephasen, deren Beginn
jenseits von `m_splitOnSilenceSegmentLength` = 180 Sekunden liegt
(`hoerbertprocessor.cpp:505`). Nach jedem Schnitt wächst diese Schwelle um
weitere 180 Sekunden (`:519`). Eine Datei von wenigen Sekunden durchläuft diesen
Pfad daher nie, egal wie viele Stillephasen sie enthält. Deshalb ist
`stille-lang.flac` 411 Sekunden lang.

Die Ersetzung der Argumente in der Schleife erfolgt über feste Indizes
(`:584-587`: Index 3 für `-ss`, 5 für `-to`, 15 für den Titel). Wird die
Argumentliste geändert, verschieben sich diese Indizes stillschweigend — ein
Risiko für jede Umstellung in AA-3.

### A9 · ffmpeg: Maximalpegel ermitteln (zweite Fassung)

* Argumentliste: `hoerbertprocessor.cpp:617-633`
* Ausgeführt: `hoerbertprocessor.cpp:635`

Argumentliste und Auswertung sind identisch mit A4. Der Quelltext weist die
Dopplung in `audiobookconverter.cpp:234` selbst als zu beseitigen aus.

Die beiden Fassungen sind allerdings **nicht** deckungsgleich: Die Fassung in
`hoerbertprocessor.cpp:637-638` prüft den Rückgabecode und verlässt die
Funktion bei einem Wert ungleich 0, die Fassung in `audiobookconverter.cpp`
prüft ihn überhaupt nicht und parst einfach die leere Ausgabe. Beim
Zusammenführen in AA-3 ist das zu entscheiden, nicht stillschweigend zu
vereinheitlichen.

### A10 · ffmpeg: Stille-Eintrag erzeugen

* Argumentliste: `hoerbertprocessor.cpp:684-709`
* Ausgeführt: `hoerbertprocessor.cpp:711`

```
-f lavfi -i anullsrc=r=32000:cl=mono -t <SEKUNDEN> -acodec pcm_s16le -hide_banner \
  -metadata title=<TITEL> -metadata album=<ALBUM> -metadata comment=<KOMMENTAR> \
  <AUSGABE> -y
```

Die Dauer kommt über `-t` als Ausgabeoption, nicht über eine Filteroption. Das
ist die Schreibweise, die auch die FFmpeg-4.2-Generation versteht; `anullsrc`
kannte dort noch kein `duration=`.

### A11 · ffmpeg: Metadaten ohne Neukodierung ändern

* Argumentliste: `hoerbertprocessor.cpp:718-741`
* Ausgeführt: `hoerbertprocessor.cpp:743`

```
-i <DATEI> -hide_banner -metadata title=<TITEL> -metadata album=<ALBUM> \
  -metadata comment=<KOMMENTAR> -codec copy <TEMPDATEI> -y
```

Danach wird die Quelldatei gelöscht und die Temporärdatei an ihre Stelle
umbenannt (`hoerbertprocessor.cpp:747-756`). Weil `-codec copy` die Audiodaten
unverändert übernimmt, ändert sich hier nur der Metadatenblock — und damit die
Länge des `LIST`-Chunks und die Gesamtgröße der Datei.

### A12 · ffmpeg: WAV nach FLAC für das Backup

* Argumentliste: `backupmanager.cpp:386-394`
* Ausgeführt: `backupmanager.cpp:395`

```
-i <DATEI> -c:a flac -y -hide_banner <AUSGABE>
```

### A13 · ffmpeg: FLAC nach WAV beim Zurückspielen

* Argumentliste: `backupmanager.cpp:404-411`
* Ausgeführt: `backupmanager.cpp:412`

```
-i <DATEI> -y -hide_banner -v quiet <AUSGABE>
```

Ohne `-acodec`, ohne `-ar`, ohne `-ac`: Format und Abtastrate ergeben sich aus
der Endung der Zieldatei und dem Inhalt der Quelle. Beim Zurückspielen eines
Backups entsteht die WAV also auf einem anderen Weg als beim normalen
Bespielen über A5.

### A14 · ffplay: Vorhören

* Argumentliste: `playlistview.cpp:293-297`
* Ausgeführt: `playlistview.cpp:298`

```
-nodisp -autoexit <DATEI>
```

Gestartet nicht über `ProcessExecutor`, sondern über ein eigenes `QProcess`
(`m_player`), das beim Umschalten auf einen anderen Eintrag geschlossen wird.
Dieser Aufruf erzeugt keine Datei und keine auswertbare Textausgabe; er ist
deshalb nicht Teil des messbaren Vergleichs in `compare.sh`, sondern gehört zu
den manuellen Abnahmen.

### Nicht-ffmpeg-Aufrufe, der Vollständigkeit halber

Diese laufen über denselben `ProcessExecutor`, gehören aber nicht zur
Audio-Pipeline und sind nicht Gegenstand von AA-1:

| Programm | Stelle | Zweck |
|---|---|---|
| `freaccmd` | `cdripper.cpp:65-70`, ausgeführt `:89` | `-e flac -o <ZIEL> <QUELLE>`, CD-Titel nach FLAC |
| `diskutil` | `devicemanager.cpp:81,86,100,105,357,400` | Laufwerksinformationen, Aus- und Einhängen |
| `udisksctl` | `devicemanager.cpp:366,409` | dasselbe unter Linux |
| `mkfs.vfat` | `devicemanager.cpp:300` | Formatieren mit erhöhten Rechten |
| `sudo -k` | `devicemanager.cpp:308,315` | Rechte-Zwischenspeicher verwerfen |
| `EjectMedia` | `devicemanager.cpp:347` | Auswerfen unter Windows |
| `Sync` | `mainwindow.cpp:814` | Puffer leeren |
| `/usr/bin/zip`, `ZIP_PATH` | `mainwindow.cpp:1007,1019` | Support-Paket `winzki_service` |

## Was beim Lesen des Quelltexts auffiel

Nicht Teil von AA-1, aber hier festgehalten, damit es nicht verloren geht. Die
Nummerierung setzt die Liste B1 bis B6 aus Abschnitt 1.5 des Portierungsplans
fort.

* **B3 ist belegt, nicht mehr nur Vermutung.** `processexecutor.cpp:14-16` ruft
  `watcher.setFuture(future)` auf, bevor `future` in Zeile 18 überhaupt
  zugewiesen wird. Der Watcher beobachtet damit ein leeres, bereits
  abgeschlossenes Future. Der Kommentar in Zeile 41 behauptet, der Watcher
  bewahre das `finished`-Signal auf — er bewahrt es für das falsche Objekt.
  Die Ereignisschleife endet daher sofort, und `future.result()` in Zeile 46
  blockiert den aufrufenden Thread für die gesamte Laufzeit von ffmpeg. Der
  Kommentar in Zeile 48 räumt das Blockieren selbst ein. Dieselbe Reihenfolge
  steht ein zweites Mal in `:66-68`.
* **B7 (neu), `processexecutor.cpp:124-134`:** Die Auswertung ist vertauscht.
  `result.first` ist der Rückgabecode des Prozesses. Die Bedingung
  `if (result.first)` ist genau dann wahr, wenn der Code ungleich 0 ist, also
  im Fehlerfall — und setzt dann `SUCCESS`. Ein erfolgreiches Formatieren
  (Code 0) wird als `FAILURE` gemeldet und umgekehrt.
* **B8 (neu), `processexecutor.cpp:55,126,132`:** `ret_code` wird mit −1
  belegt und in dieser Funktion nie auf `PASSWORD_INCORRECT` gesetzt. Die
  beiden Abfragen `if (ret_code != PASSWORD_INCORRECT)` sind damit immer wahr;
  die Erkennung eines falschen Kennworts wirkt nur auf den Dialogtext, nicht
  auf den Rückgabewert.
* **B9 (neu), `audiobookconverter.cpp:200-201`:** 
  `auto e = start.toDouble(&end_ok);` prüft zweimal `start`. Der Wert `end`
  wird nie auf Gültigkeit geprüft. Ein unlesbares Kapitelende fällt daher
  nicht auf und geht als leere Zeichenkette in den `-to`-Parameter von A3.
* **B10 (neu), gemessen statt gelesen:** `WAV_HEADER_SIZE_IN_BYTES = 44`
  (`define.h:150`) trifft auf keine der von dieser Pipeline erzeugten Dateien
  zu. ffmpeg schreibt einen `LIST`/`INFO`-Chunk zwischen `fmt ` und `data`;
  gemessen wurden Header von 122 bis 178 Byte, abhängig von der Länge der
  Metadaten. Belegt durch die Messwerte unter `erwartet/erzeugte-wavs/`.

  Die Abschätzung in `playlistview.cpp:198` rechnet
  `44 + Dauer × 32000 × 16 / 8 + MEMORY_SPARE_SPACE_IN_BYTES`, und die Reserve
  von 1024 Byte (`define.h:151`) fängt den zu kleinen Headerwert vollständig
  auf. Nachgerechnet an vier gemessenen Dateien liegt die Schätzung um 890 bis
  946 Byte **über** der tatsächlichen Größe, ist also konservativ. Es handelt
  sich damit um eine falsche Konstante ohne gegenwärtige Folge, nicht um einen
  Rechenfehler mit Überlauf. Gefährlich wird es erst, wenn die Reserve entfällt
  oder die Metadaten den `LIST`-Chunk über etwa 1 KB hinaus wachsen lassen.
  Für AA-3 heißt das: Konstante richtigstellen, Reserve nicht ersatzlos
  streichen.
* **B11 (neu), beobachtet beim Aufruf:** Das mitgelieferte `ffplay` enthält
  SDL-Klassen, die auch in `libavdevice.58.dylib` stecken. Jeder Start meldet
  elf Objective-C-Warnungen der Form „Class SDLApplication is implemented in
  both …". Festgehalten in `altes-ffmpeg/ffplay.version.txt`. Für den
  Neubau in AA-2 heißt das: SDL2 nur an einer Stelle einbinden.
* **B12 (neu), `hoerbertprocessor.cpp:637-638`:** In `getVolumeDifference`, einer
  Funktion mit Rückgabetyp `double` (deklariert in Zeile 602), steht
  `return false;`. Das ergibt 0.0 und bedeutet zufällig das Richtige, nämlich
  „keine Korrektur". Gemeint war erkennbar ein Fehlerausgang. Beim Umstellen in
  AA-3 nicht in `return -1` o. Ä. ändern, sonst entsteht aus einem harmlosen
  Typfehler eine stille Pegelverschiebung.
* **B13 (neu), gemessen in AA-1b:** Eine abgeschnittene WAV-Datei ohne
  Audiodaten (200 Byte Kopf, Prüffall `kopf-ohne-daten.wav`) durchläuft die
  gesamte Kette **ohne jede Beanstandung**. `ffprobe` meldet Rückgabecode 0 und
  eine Dauer von 0,000703 Sekunden; weil die Prüfung in
  `audioinfothread.cpp:118` nur `duration <= 0.0` abfängt, landet die Datei in
  der Liste. `convertToWav` meldet Code 0 und erzeugt eine 134 Byte große WAV
  ohne Nutzdaten, die als Erfolg gezählt wird und auf der Karte landet. Die
  übrigen vier Prüffälle (0 Byte, Textdatei mit `.mp3`, abgeschnittene MP3,
  nicht vorhandene Datei) werden dagegen überall korrekt mit Code 1 abgewiesen.
  Ein eigener Prüffall für AA-3; der Plan führt ihn bisher nicht.
* **B14 (neu), gemessen in AA-1b, `audiobookconverter.cpp:125-144`:** A3 wertet
  ausschliesslich den Text aus und ignoriert den Rückgabecode. Gemessen wurde,
  dass genau dadurch echte Fehlschläge unbemerkt bleiben. Bei einer nicht
  vorhandenen Quelldatei lautet die Ausgabe `No such file or directory`, bei
  einem nicht beschreibbaren Ausgabeziel `Permission denied`. **Beide enthalten
  weder „Error" noch „Invalid"**, also schlägt die Bedingung nicht an, und es
  wird kein `failed()` ausgelöst. Verschärfend: Die Prüfung, ob die
  Ausgabedatei überhaupt existiert, steht *innerhalb* dieser Bedingung
  (`:131-144`) und wird deshalb ebenfalls nie erreicht. Der Pfad ist zu diesem
  Zeitpunkt aber schon in `info_list` eingetragen (`:121`). Ergebnis: Die
  Kapitelliste enthält einen Pfad auf eine Datei, die es nicht gibt, und
  niemand erfährt davon. Nur der Fall „zufälliger Inhalt" wird erkannt, weil
  ffmpeg dort `Invalid data found when processing input` meldet.
* **B15 (neu), gemessen in AA-1b:** Eine nach der Hälfte ihrer Bytes
  abgeschnittene MP3 wird von der gesamten Kette als gültig behandelt. ffprobe
  meldet Rückgabecode 0 und als Dauer **6,034286 Sekunden** — die Dauer der
  *vollständigen* Datei, weil der Xing-Header die ursprüngliche Frame-Anzahl
  enthält und ffprobe ihm folgt. Tatsächlich wiederherstellbar sind 2,97
  Sekunden: `convertToWav` liefert Code 0 und eine Datei von 190.784 Byte, also
  2,97 Sekunden bei 64.000 Byte je Sekunde. Die Folge reicht weiter als der
  einzelne Eintrag: `playlistview.cpp:198` rechnet den Platzbedarf aus der
  gemeldeten Dauer, also mit 6 Sekunden, und die Liste zeigt 6 Sekunden an,
  während auf der Karte die Hälfte landet. Derselbe Effekt trifft A4, das den
  Maximalpegel über die halbe Datei misst und daraus eine Korrektur für das
  Ganze ableitet, und A13 beim Zurückspielen eines Backups.
* **B16 (neu), gemessen im Nachtrag zu AA-1b:** Wie eine beschädigte Datei
  durchkommt, hängt vollständig am Quellformat, und in drei von vier Fällen
  kommt sie durch.

  Ein MP4-Container scheitert sauber: `halb-kapitel.m4b` und `halb-ton.m4a`
  werden mit Code 1 abgewiesen, weil die Indextabelle `moov` am Dateiende
  fehlt. FLAC dagegen meldet über `STREAMINFO` die Gesamtzahl der Samples der
  *ursprünglichen* Datei; ffprobe gibt für eine halbierte FLAC glatte
  **6.000000** Sekunden an, wiederherstellbar sind 2,72. Ogg meldet 2,02 und
  liefert 2,02, ist also ehrlich; WMA meldet 4,322 und liefert 3,02.

  Der schwerwiegende Teil: Bei `halb-ton.wma` und `halb-ton.flac` schreibt
  ffmpeg wörtlich `Error while decoding stream #0:0: Invalid data found when
  processing input` und **beendet sich trotzdem mit Code 0**. `convertToWav`
  wertet nur `output.first==0` (`hoerbertprocessor.cpp:385`) und zählt das als
  Erfolg; auf der Karte landen 45 bis 50 Prozent des Hörstücks. Dieselbe
  Meldung enthält beide Wörter, auf die A3 prüft — die Information liegt also
  vor, A5 liest sie nur nicht. Für AA-3 heißt das: Der Rückgabecode allein ist
  als Erfolgskriterium nachweislich untauglich. Eine zusätzliche Textprüfung
  auf `Error while decoding` würde fünf der acht stillen Fälle abfangen; der
  Vollständigkeit halber bleibt nur ein Abgleich der erzeugten Dauer gegen die
  erwartete.

