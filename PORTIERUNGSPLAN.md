# Portierungsplan: hörbert-Software → natives Apple-Silicon-Build (macOS 27)

Stand: 2026-11-22, abends · Basis: Zweig `feedback` (`1280aac`, 31.10.2024) von `winzkigermany/hoerbert-software`, enthält Tag `3.1.4` (`be6062a`) · Version 3.1.4 · Lizenz GPLv3

**Basiswechsel am 22.11.2026:** Die erste Fassung dieses Plans analysierte den Standardzweig `main` (Version 2.1.3, Stand 12/2020). Die tatsächlich eingesetzte App ist 3.1.4; ihr Quelltext liegt auf dem Zweig `feedback`. Alle Datei- und Zeilenangaben in diesem Plan beziehen sich jetzt auf `1280aac`. Was aus der Arbeit an 2.1.3 weiter gilt, steht in Abschnitt 1.7.

Legende: **[BELEGT]** = im Code oder in einer Quelle nachgeprüft · **[ANNAHME]** = nicht verifiziert, muss im jeweiligen Arbeitsschritt geprüft werden.

---

## 1. Ausgangslage

### 1.1 Plattform-Zeitplan
- macOS 27 läuft nur noch auf Apple Silicon. Rosetta 2 wird beim Upgrade auf macOS 27 entfernt, lässt sich aber nachinstallieren; ab macOS 28 ist Rosetta für normale Apps weg. [BELEGT, Quellen 1–3; die Quellen widersprechen sich im Detail, ob Rosetta unter 27 "entfernt" oder nur "deinstalliert und nachinstallierbar" ist]
- Konsequenz: Die App ist unter macOS 27 nicht sofort tot, aber ohne manuellen Eingriff des Nutzers startet sie nicht mehr. Harte Frist ist macOS 28 (Herbst 2027).

### 1.2 Was im Repository liegt [BELEGT]
- Das Original-Repository hat drei Zweige: `main` (2.1.3, 190 Commits), `feedback` (3.1.4, 287 Commits, 97 davon nicht in `main`), `develop` (2.0.7, veraltet). `main` ist kein Vorfahre von 3.1.4.
- Version 3.1.4: Qt-Widgets-Anwendung, C++, qmake (`project.pro` → `hoerbert/hoerbert.pro`), 36 `.cpp` / 37 `.h`, rund 18.500 Zeilen, eine `.ui`-Datei (`downloaddialog.ui`). Keine Tests, kein CI, keine ARCHITECTURE.md.
- Gebaut gegen Qt 5.15.2 (`mac-deploy.sh` nennt `~/Qt/5.15.2/clang_64`).
- Qt-Module: core, gui, widgets, xml, network, concurrent.
- **Zwei Kartenformate in einem Programm.** Die Eigenschaft `hoerbertModel` (2011 oder 2021, abgefragt an über 30 Stellen) schaltet um: Modell 2011 erhält WAV (`pcm_s16le`, 32 kHz, mono), Modell 2021 erhält MP3 (44,1 kHz, stereo, 192 kbit/s; hoerbertprocessor.cpp:471–556) und eine `index.m3u`. Das Zielgerät dieses Ports ist ein Modell 2021.
- Neu gegenüber 2.1.3: Einstellungen für WLAN, Set-Modus, Bluetooth und Aufnahmen (werden als Dateien auf die Karte geschrieben; die App selbst nutzt weder Mikrofon noch Bluetooth des Mac), Internetradio-Einträge (`.URL`), Firmware-Prüfung und Firmware-Download von Servern des Herstellers.
- Die Audioarbeit machen mitgelieferte Fremdbinaries, per `QProcess` gestartet. Pfade: main.cpp:100–170 aus define.h:135–141, Existenzprüfung beim Start main.cpp:177–210.

### 1.3 Die Intel-Abhängigkeiten im Einzelnen [BELEGT per `file` auf alle Dateien unter `hoerbert/tools/mac`]

| Komponente | Ort | Architektur | Anmerkung |
|---|---|---|---|
| ffmpeg, ffprobe, ffplay + 8 dylibs | `tools/mac/ffmpeg/` | nur x86_64 | Byte-identisch mit 2.1.3 (0 geänderte Dateien zwischen `main` und `feedback`); Git-Snapshot `N-93548-g4d2f62150d`, libavcodec 58.48.101 |
| freaccmd, alte Fassung | `tools/mac/freac/osx10/` | i386 + x86_64 + ppc | wird auf jedem macOS außer Version 11 gewählt, siehe B18 |
| freaccmd, neue Fassung | `tools/mac/freac/osx11/` | **arm64 + x86_64** (113 Mach-O-Dateien von 243 Dateien, 31 MB) | wird nur gewählt, wenn die macOS-Version mit "11" beginnt (main.cpp:148) |
| sox, wavsilence | `tools/mac/` | x86_64 | nirgends im Bundle (hoerbert.pro:174–186), toter Ballast |
| Qt-Frameworks | via macdeployqt | x86_64 (Qt 5.15.2) | App selbst |

Zu ersetzen sind damit: Qt und die ffmpeg-Suite. Für fre:ac liegt ein arm64-fähiger Stand bereits im Repository (in AA-1c gestartet: "v1.1.3b (ARM64)"), wird aber auf aktuellem macOS nicht benutzt.

**MP3-Encoder:** Der MP3-Weg übergibt ffmpeg nur Abtastrate, Kanalzahl und Bitrate und überlässt die Wahl des Encoders der Dateiendung. Der Neubau von ffmpeg braucht deshalb einen MP3-Encoder; ohne externe Bibliothek hat ffmpeg keinen brauchbaren. [ANNAHME: Das alte Binary nutzt libmp3lame; an `tests/reference/altes-ffmpeg/ffmpeg.buildconf.txt` und der Encoder-Angabe in den Referenz-MP3s zu prüfen]

### 1.4 Qt-5-APIs, die in Qt 6 nicht mehr existieren [BELEGT per grep auf `1280aac`]

| API | Fundstellen |
|---|---|
| `QRegExp`, `QRegExpValidator` | audiobookconverter.cpp:189,284 · cardpage.cpp:322,354 · devicemanager.cpp:85,90,104,109 · hoerbertprocessor.cpp:655,851,1017 · playlistparser.cpp:70 |
| `QString::SkipEmptyParts` | dieselben `split`-Stellen, zusätzlich cardpage.cpp:1427,1475 |
| `QProcess::start(QString)` (ein String statt Programm + Argumentliste) | processexecutor.cpp:32,99 · devicemanager.cpp:312; betrifft die Aufrufer devicemanager.cpp:81,88,102,107,338,345,387,396,430,439 |
| `QTextCodec` | main.cpp:35,71 |
| `QDesktopWidget` | mainwindow.cpp:42,64 |
| `QLayout::setMargin` | aboutdialog.cpp:96 · cardpage.cpp:46 · playlistpage.cpp:73,78 |
| `QButtonGroup::buttonClicked(int)` | advancedfeaturesdialog.cpp:161 |
| `endl` ohne `Qt::` | xmlwriter.cpp:106,115 |
| `QLibraryInfo::location` | main.cpp:89 |
| `Qt::AA_EnableHighDpiScaling` | main.cpp:83 |

Rund 35 Stellen in 12 Dateien. [ANNAHME bis zum ersten Compile-Lauf: Die Liste stammt aus einer Mustersuche. Die neuen Netzwerk-Dialoge (downloaddialog, Firmware-Prüfung in mainwindow.cpp:1692–1800) nutzen `QNetworkAccessManager`/`QNetworkReply`; ob dort Signale oder Attribute betroffen sind, zeigt erst der Compiler]

### 1.5 Vorhandene Fehler im Originalcode

Stand in 3.1.4, am Quelltext `1280aac` geprüft, soweit nicht anders vermerkt. Die Nummern stammen aus der Arbeit an 2.1.3 und bleiben stabil.

| # | Stelle in 3.1.4 | Befund | Status |
|---|---|---|---|
| B1 | main.cpp:92–94 | qtbase-Übersetzung wird ins falsche Objekt geladen | [BELEGT] besteht |
| B2 | devicemanager.cpp:430–435 | `remountDrive` prüft nach `diskutil mount` auf "unmounted" und meldet auch bei Erfolg FAILURE | [BELEGT] besteht |
| B3 | processexecutor.cpp:16–18, 68–79 | `watcher.setFuture` vor Zuweisung des Future; `future.result()` blockiert den Aufrufer für die Dauer jedes ffmpeg-Laufs | [BELEGT] Datei unverändert gegenüber 2.1.3 |
| B4 | devicemanager.cpp:493–495 | `root.left(root.length() - 2)` bildet den Plattennamen für `diskutil eraseDisk` durch Abschneiden zweier Zeichen | [BELEGT] besteht |
| B5 | cdripper.cpp | `tr(...).arg()` ohne Platzhalter | in 3.1.4 neu zu prüfen (Datei geändert) |
| B6 | main.cpp:299–307 | `a.setStyle("…CSS…")` hat keine Wirkung | [BELEGT] besteht |
| B7, B8 | processexecutor.cpp:122–134 | Rückgabecode im Linux-sudo-Pfad vertauscht ausgewertet; `PASSWORD_INCORRECT` nie gesetzt | [BELEGT] Datei unverändert |
| B9 | audiobookconverter.cpp:212–213 | Kapitelende nie geprüft (zweimal `start.toDouble`) | [BELEGT] besteht |
| B10 | define.h:166 | `WAV_HEADER_SIZE_IN_BYTES = 44` trifft nicht zu (gemessen 122–178 Byte); betrifft nur noch den Weg für Modell 2011 | [BELEGT] besteht |
| B11 | – | altes `ffplay` enthält SDL-Klassen doppelt | Binary unverändert |
| B12 | hoerbertprocessor.cpp:847–848 | `return false` in `getVolumeDifference` (Rückgabetyp `double`) | [BELEGT] besteht |
| B13–B16 | – | Fehlererkennung der ffmpeg-Aufrufe (leere WAV akzeptiert, fehlende Datei unbemerkt, Code 0 trotz Fehlertext, abgeschnittene Dateien) | am alten ffmpeg gemessen; für die Aufrufe von 3.1.4 in AA-1c neu zu belegen. `convertToAudioFile` und `convertToMp3` werten weiterhin nur den Rückgabecode aus (hoerbertprocessor.cpp:521,556) |
| **B17** | playlistview.cpp:210 | Größenabschätzung für MP3 rechnet `Dauer × 24000 / 8`, also 3.000 Byte je Sekunde. 192 kbit/s sind 24.000 Byte je Sekunde; die Schätzung ist um den Faktor 8 zu klein. Beleg: Eine 411-s-Datei belegt auf der Karte 9,9 MB, geschätzt würden 1,2 MB. Die Kapazitätsprüfung lässt damit zu viel zu. | [BELEGT am Code und an einer mit 3.1.4 geschriebenen Karte] |
| **B18** | main.cpp:148–155 | Das arm64-fähige fre:ac (`osx11`) wird nur gewählt, wenn die macOS-Version mit "11" beginnt. Auf macOS 12 und neuer fällt die App auf die alte Intel-Fassung (`osx10`) zurück; die Auswahl hängt an der Systemversion, nicht an der Architektur. | [BELEGT] |
| **B19** | playlistview.cpp:626–629, 822; audiobookconverter.cpp:129; hoerbertprocessor.cpp:471 ff. | Hörbuchkapitel werden für Modell 2021 zweimal verlustbehaftet kodiert: Kapitelschnitt in eine MP3-Zwischendatei im Temp-Ordner, danach erneute MP3-Wandlung auf die Karte. Für Modell 2011 entsteht kein Verlust, weil beide Stufen PCM schreiben. | [BELEGT: zweistufige Nachbildung stimmt für 3 von 3 Kapiteln bit-genau mit der Karte überein] |
| **B20** | hoerbertprocessor.cpp:941 ff. (`changeMetaData`) | Bei einer Eingabe ohne Audiodaten endet ffmpeg mit Code 1, hinterlässt aber eine Zwischendatei mit 0 Byte, die nicht aufgeräumt wird. | [BELEGT laut AA-1c] |
| **B21** | playlistview.cpp:616–619 und 723–735; audioinfothread.cpp:155–166 | Enthält ein Ablegevorgang mindestens eine `.aiff`- oder `.cda`-Datei, gilt er als CD-Import. Dann erhalten alle übrigen Dateien desselben Vorgangs ihren Dateipfad als Titel, auch wenn sie einen Titel-Tag tragen. Das erklärt, warum die Kapitel auf der am 22.11.2026 geschriebenen Karte den Temp-Pfad als Titel haben: `kapitel.m4b` wurde zusammen mit `ton.aiff` abgelegt. Die Zwischendateien selbst tragen die Kapiteltitel und sind byte-identisch mit der Nachbildung. | [BELEGT am Code; der Zusammenhang mit der Karte ist plausibel, aber nicht durch einen Gegenversuch gemessen] |

Ergebnisse aus AA-1c (22.11.2026) [BELEGT laut Agentenbericht]:
- Alle 13 ffmpeg-/ffprobe-Aufrufstellen von 3.1.4 sind als C1 bis C13 in `tests/reference-3.1.4/AUFRUFE-3.1.4.md` erfasst und in vier Varianten gemessen (Modell 2011/2021 × Lautstärkeanhebung aus/ein), dazu die Fehlerfälle für alle schreibenden Aufrufe. Der Kapitelschnitt C9 ist der einzige schreibende Aufruf ohne `-map a`.
- Fehlerfälle im MP3-Weg: Abgeschnittene Eingaben liefern bei allen schreibenden Aufrufen Code 0 und eine Datei mit rund der halben Spieldauer.
- fre:ac: `osx10` meldet sich als "v1.1 Alpha 20190423a (x86-64)" und wird auf macOS 12 bis 26 gewählt; `osx11` als "v1.1.3b (ARM64)".
- Die ffmpeg-Binaries der installierten App 3.1.4 unterscheiden sich von denen im Repository nur durch die Codesignatur (gleiche Versionskennung, gleiche configure-Zeile, gleiche Messwerte).
- Die nachgebildeten MP3-Aufrufe erzeugen für alle acht Testquellen dieselben PCM-Daten wie die App auf der Karte (bit-genau), sofern die Einstellung "Lautstärke bis zum Grenzwert erhöhen" wie in der App aus ist. Die WAV-Referenzen aus AA-1 wurden mit eingeschalteter Anhebung gemessen; die Referenz muss beide Einstellungen abdecken.
- Karte im Format 2021: Ordner 0 bis 8, darin `N.MP3`, dazu `index.m3u` mit dem Inhalt `#EXTM3U`; keine `hoerbert.xml`.
- Der Stille-Eintrag wird mit 128 kbit/s erzeugt, alle anderen MP3 mit 192 kbit/s.
- Installierte App: Qt 5.15.2, Bundle-ID `de.winzki.hoerbert`, Mindest-macOS 10.13.

Weitere Befunde aus AA-1/AA-1b gelten unverändert, weil sie das ffmpeg-Binary betreffen: Die Kapitelabfrage endet auch bei Erfolg mit Code 1; die gemeldete Dauer abgeschnittener FLAC-, MP3- und WMA-Dateien ist zu hoch, bei Ogg nicht erkennbar; abgeschnittene MP4-Dateien werden abgewiesen.

### 1.6 Regressionsrisiken, die über "kompiliert" hinausgehen
- **ffmpeg-Versionssprung.** Die App parst Textausgaben von ffmpeg: `silencedetect` und `Duration:` (hoerbertprocessor.cpp:655 ff.), `max_volume` aus `volumedetect` (hoerbertprocessor.cpp:851 ff., audiobookconverter.cpp:284 ff.), Kapitel-Ausgabe (audiobookconverter.cpp:189 ff.). Ändert sich das Logformat, bricht die Funktion still. [BELEGT, dass geparst wird; ob sich das Format geändert hat: ANNAHME]
- **MP3-Ausgabe.** Ein anderer Encoder oder eine andere Encoder-Version erzeugt andere Bytes. Ob die hörbert-Firmware die neuen Dateien genauso abspielt, entscheidet der Test am Gerät (M2). Als Vorstufe werden Format, Bitrate, Abtastrate, Kanäle, Tag-Aufbau und Dauer gegen die Referenz geprüft. [ANNAHME]
- **Feste Argument-Indizes.** hoerbertprocessor.cpp:790–800 ersetzt Argumente über die Positionen 3, 5 und 15. Jede Änderung an dieser Argumentliste verschiebt sie.
- **Helper im Bundle.** Die Tools liegen unter `Contents/Resources` (hoerbert.pro:182). Für Hardened Runtime und Notarisierung muss jede ausführbare Datei einzeln signiert sein. Bleibt fre:ac, sind das im Repository-Stand 113 weitere Mach-O-Dateien. [ANNAHME zur Notarisierungspraxis, in AA-5 gegen Apple-Doku zu prüfen]
- **Zugriff auf Wechselmedien.** Keine eigene `Info.plist`, kein Erklärungstext für den Zugriffsdialog. [BELEGT, dass keine existiert; Verhalten unter macOS 27: ANNAHME]
- **Netzwerk unter Qt 6.** Firmware-Prüfung und -Download laufen über HTTPS. main.cpp:312 fragt die TLS-Unterstützung ab. Welches TLS-Backend die gewählte Qt-6-Version auf macOS mitbringt und ob macdeployqt es einpackt, ist in AA-0 zu belegen. [ANNAHME]
- **Qt und macOS 27.** Qt 6.12 nennt als unterstützt "macOS 14.4 oder höher (einschließlich macOS 26)"; macOS 27 wird nicht erwähnt. [BELEGT, Quelle 4]

### 1.7 Was aus der Arbeit an 2.1.3 weiter gilt

| Ergebnis | Geltung für 3.1.4 |
|---|---|
| Selbstauskunft des alten ffmpeg (`tests/reference/altes-ffmpeg/`) | gilt, Binaries identisch |
| Fehlerfälle und Befunde zum Verhalten von ffmpeg bei kaputten Eingaben | gelten, soweit sie das Binary betreffen; die Zuordnung zu App-Aufrufen ist neu zu ziehen |
| WAV-Referenzen (A1–A13) | nur noch für den Weg "Modell 2011" relevant; die Argumentlisten sind in 3.1.4 leicht verändert (u. a. zusätzlich `-map a`) und werden in AA-1c neu gemessen |
| `AUFRUFE.md` | beschreibt 2.1.3; wird durch `AUFRUFE-3.1.4.md` ergänzt, nicht überschrieben |
| Prüfskripte (`lauf.sh`, `compare.sh`, `wav-struktur.py`) | Gerüst bleibt, Aufrufe werden für 3.1.4 erweitert |
| Fork, Branding, Icon | gelten |
| Arbeitszweig `port/macos-arm64` | basiert auf `main` und wird nicht weitergeführt; neuer Zweig auf `feedback`, siehe AA-0c |

---

## 2. Machbarkeits-Gate

| Frage | Befund |
|---|---|
| (1) Kann Claude Code das nachweislich? | **Teilweise.** Quellcode-Port Qt 5 → Qt 6, Build-Skripte, ffmpeg aus Quellen bauen, Bundle-Struktur: ja, das sind lesbare, compilergeprüfte Änderungen in 18,5k Zeilen. **Nicht** durch einen Agenten leistbar: Signieren/Notarisieren (braucht Developer-ID-Zertifikat und Apple-Zugang), Test mit echter SD-Karte und echtem hörbert, Test mit Audio-CD und Laufwerk, Test auf einem Mac mit macOS 27. Der Agent muss außerdem **lokal auf einem Apple-Silicon-Mac mit Xcode** laufen; in einer Linux-Cloud-Sitzung lässt sich nichts davon bauen. |
| (2) Erfolgsquote > 90 %? | Code-Port bis "baut und startet als arm64": > 90 %. Funktionsgleichheit der Audio-Pipeline: nur mit den Referenzmessungen aus AA-1 belastbar, ohne sie nicht bezifferbar. Notarisierte Auslieferung: hängt an den manuellen Schritten, nicht am Agenten. |
| (3) Fallback? | F1: Rosetta unter macOS 27 nachinstallieren, bestehende 2.1.3 weiter nutzen (trägt bis macOS 28). F2: Minimalvariante mit Qt 5.15 für arm64 statt Qt 6 und nur Tausch der Binaries [ANNAHME: Qt 5.15 arm64 via Homebrew `qt@5` verfügbar; Qt 5 ist am Ende seiner Pflege und damit technische Schuld]. F3: Für hörbert-Modelle ab Oktober 2021 ist die Software laut README überflüssig, dort geht alles per WLAN im Browser. |

**Gate-Ergebnis: bestanden für den Code-Port unter drei Bedingungen:** lokaler Mac als Arbeitsumgebung, AA-1 (Referenzdaten) vor jeder Codeänderung, und die manuellen Abnahmen aus Abschnitt 6 bleiben beim Menschen.

**Neubewertung nach dem Basiswechsel (22.11.2026):** Das Gate bleibt bestanden. Der Umfang ist größer (18.500 statt 15.000 Zeilen), die Zahl der Qt-6-Brüche etwa gleich. Zwei neue Bedingungen: AA-1c (Referenzdaten für 3.1.4, vor allem der MP3-Weg) muss vor dem Update auf macOS 27 abgeschlossen sein, und der Neubau von ffmpeg muss einen MP3-Encoder enthalten. Die Netzwerkfunktionen (Firmware-Prüfung und -Download) habe ich nur überflogen; ihr Verhalten unter Qt 6 ist erst nach AA-0 beurteilbar.

**Zum Agentenschwarm:** nicht empfohlen. Die Qt-6-Änderungen betreffen rund 35 Stellen in 12 Dateien, die sich gegenseitig berühren (ProcessExecutor ↔ DeviceManager ↔ CDRipper). Parallele Agenten erzeugen hier Merge-Konflikte statt Tempo. Sinnvoll parallel ist genau ein Paar: AA-2 (ffmpeg bauen, fasst keinen App-Code an) neben AA-3 (Qt-6-Port).

---

## 3. Entscheidungen vor Arbeitsbeginn

| # | Frage | Empfehlung | Begründung |
|---|---|---|---|
| E1 | Qt 6 oder Qt 5.15 arm64? | **Qt 6, aktuelle Version** (beim Start in AA-0 feststellen und festschreiben) | Qt 5 wird nicht mehr gepflegt; alle Qt-6-Brüche sind hier mechanisch lösbar. |
| E2 | arm64-only oder Universal? | **arm64-only**, Mindest-macOS nach Vorgabe der gewählten Qt-Version | Intel-Macs können bei 2.1.3 bleiben. Universal verdoppelt den ffmpeg-Build und die Testmatrix ohne Gewinn für das Ziel. |
| E3 | fre:ac behalten oder ersetzen? | **Entschieden (22.11.2026): behalten. Das mitgelieferte fre:ac `osx11` verwenden, B18 beheben, `osx10` aus dem macOS-Bundle entfernen** | Gemessen in AA-1c: Alle 113 Mach-O-Dateien des `osx11`-Satzes enthalten arm64, `freaccmd` meldet sich als "v1.1.3b (ARM64)" und startet nativ. Behalten ändert kein Verhalten und braucht keinen neuen Code für den CD-Import, der mangels Laufwerk schwer abzunehmen ist. Preis: 113 Dateien sind zu signieren (per Skript), und fre:ac 1.1.3b ist ein Stand von 2020, dessen Lauf unter macOS 27 erst nach dem Upgrade prüfbar ist. Rückfallebene, falls es dort nicht läuft: Ersatz durch ffmpeg (CD-Titel liegen unter macOS als `.aiff` vor; cdripper.cpp:80–86 übergibt nur einen Dateipfad). |
| E4 | Geltungsbereich Windows/Linux? | **Nur macOS verifizieren.** Plattformcode hinter `Q_OS_WIN`/`Q_OS_LINUX` nur dort anfassen, wo Qt 6 es erzwingt; in ARCHITECTURE.md als "unter Qt 6 ungeprüft" ausweisen | Ohne Windows-/Linux-Testumgebung wäre jede Aussage dazu geraten. |
| E5 | Vorhandene Fehler mitbeheben? | **Entschieden (22.11.2026): B1, B2, B3, B4, B9, B10, B17, B18 beheben; B12 absichern; B5 erst am Quelltext von 3.1.4 prüfen; B6 getrennt entscheiden; B7, B8 nur dokumentieren.** B13–B16 und B20 hängen an E8, B19 liegt im Backlog (E11), B21 ist noch nicht entschieden | B2–B4 liegen in den Funktionen, die für Qt 6 ohnehin umgeschrieben werden. B17 lässt die Karte überlaufen. B18 wird in AA-4 behoben. B6 ändert das Erscheinungsbild. B7/B8 liegen im Linux-sudo-Pfad, der hier nicht testbar ist (E4). |
| E8 | Fehlererkennung der Audio-Aufrufe (B13–B16) | **Offen. Empfehlung: (1) für alle schreibenden Aufrufe (A3, A5, A6, A8, A11, A12, A13) Rückgabecode UND Textmarker auswerten, A2 nie über den Code; (2) zusätzlich die von A1 gemeldete Dauer mit der erzeugten vergleichen und bei Abweichung warnen, nicht abweisen; (3) Ogg als dokumentierte Grenze** | Zu (1), gemessen: Der Code allein reicht nicht (halbierte WMA/FLAC: Code 0 trotz "Error ... Invalid data"), der Text allein auch nicht (fehlende Datei, gesperrtes Ziel: Code 1 ohne die Wörter). Zu (2), an den Referenzdaten nachgerechnet: Die Differenz beträgt bei halbierter MP3 3,06 s, WMA 1,30 s, FLAC 3,28 s bzw. 3,19 s (jeweils 6-s-Dateien) und ist damit erkennbar; ein zweiter ffmpeg-Lauf ist nicht nötig, weil die gemeldete Dauer aus A1 vorliegt. Nur warnen, weil die gemeldete Dauer auch bei intakten Dateien geschätzt sein kann [ANNAHME: z. B. MP3 mit variabler Bitrate ohne Xing-Header; in AA-3 mit einer solchen Testdatei messen und die Toleranz daraus ableiten]. Zu (3), gemessen: Bei halbierter Ogg-Datei beträgt die Differenz 0,0002 s, und die vollständige Ausgabe des alten ffmpeg enthält keinerlei Hinweis. AA-2 prüft am selben Material, ob das neue ffmpeg dort etwas meldet. |
| E11 | Doppelte MP3-Kodierung von Hörbuchkapiteln (B19) | **Entschieden (22.11.2026): beheben, aber erst nach erfolgreicher Portierung; Backlog, Abschnitt 8** | Während der Portierung bleibt das Verhalten unverändert, damit die Kapiteldateien bit-genau mit der Referenz des Originals vergleichbar sind. |
| E9 | Dienste des Herstellers im Fork | **Offen. Empfehlung: Software-Update-Prüfung entfernen; Firmware-Prüfung und Firmware-Download behalten** | Die Update-Prüfung (mainwindow.cpp:1692–1730, `hoerbert.com/client/checkMacVersion2`) würde auf die Original-App verweisen. Firmware-Prüfung und -Download (mainwindow.cpp:1733 ff., downloaddialog.cpp, `link.hoerbert.com/firmware`) betreffen das Gerät, nicht die App, und sind für Nutzer nützlich; sie rufen aber weiterhin Server von WINZKI aus einer fremden App auf. Ob das gewollt ist, entscheidet der Herausgeber. |
| E10 | Weg für Modell 2011 (WAV) | **Im Code belassen, nur über Referenzdaten prüfen, als "am Gerät ungeprüft" kennzeichnen** | Ein Gerät dieses Typs steht nicht zur Verfügung. Den Weg zu entfernen wäre eine Funktionskürzung ohne Not. |
| E6 | Build-System | **qmake beibehalten** | Qt 6 unterstützt qmake weiter. Ein Wechsel auf CMake wäre ein zweites, unabhängiges Risiko im selben Schritt. |
| E7 | Herausgeberschaft | **Entschieden (22.11.2026): eigenständiger Fork `mathiasherrmann/hoerkarte`** | Folgen siehe Abschnitt 3.1. |

### 3.1 Vorgaben für den Fork (Folge aus E7)

Im Code verankerte Bezüge auf den Originalherausgeber [BELEGT]:
- Bundle-Präfix `de.winzki` (hoerbert.pro, `QMAKE_TARGET_BUNDLE_PREFIX`)
- Update-Check gegen `hoerbert.com/client/checkMacVersion2` (mainwindow.cpp:1705), Firmware-Prüfung gegen `hoerbert.com/client/checkFirmwareVersion` (mainwindow.cpp:1770), Firmware-Download von `link.hoerbert.com/firmware` (define.h:157), mehrere Links auf Hilfeseiten des Herstellers
- Einstellungs-Namensraum: Organisation "WINZKI GmbH & Co. KG", Domain `hoerbert.com` (main.cpp:227,246)
- Einzelinstanz-Sperre mit Schlüssel `winzki_hoerbert_app_running` (main.cpp:314)
- Link auf das Original-Repository im About-Dialog (aboutdialog.cpp:58)
- Firmen- und Copyright-Angaben in version.h

Vorgaben:
1. **Lizenz:** GPLv3 bleibt. `LICENSE`/`COPYING` und alle Copyright-Köpfe der Originalautoren bleiben unverändert stehen; geänderte Dateien erhalten einen Änderungsvermerk mit Datum. Der Quelltext zu jedem veröffentlichten Binary muss im Fork abrufbar sein, einschließlich Build-Skript und Lizenztexten für ffmpeg und SDL2. [ANNAHME zur Auslegung der GPLv3; keine Rechtsberatung]
2. **Eigene Identität:** eigene Bundle-ID, eigener Einstellungs-Namensraum, eigener RunGuard-Schlüssel. Sonst teilen sich Fork und Original Einstellungen und sperren sich gegenseitig beim Start.
3. **Dienste des Herstellers:** gemäß Entscheidung E9. Die Prüfung auf Software-Updates wird in jedem Fall entfernt, samt Menüeintrag und Übersetzungstexten; kein Ersatzmechanismus in dieser Portierung.
4. **Kennzeichnung:** About-Dialog und README weisen den Build als inoffiziellen Fork aus, nennen das Original-Repository als Herkunft und das Fork-Repository als Quelle und Anlaufstelle für Fehler. Supportfunktionen, die Nutzer an WINZKI verweisen (Support-Paket "winzki_service", mainwindow.cpp:905, `collectInformationForSupport`), werden in AA-0 inventarisiert und danach einzeln entschieden.
5. **Name und Logo:** Der Fork führt einen eigenen Namen und ein eigenes Icon. "hörbert" wird nur beschreibend genannt ("für hörbert"). Bildmaterial des Originals mit Produkt- oder Logobezug wird nicht als Kennzeichnung des Forks verwendet; AA-0 listet alle Bild- und Textstellen mit hörbert-Bezug auf, danach wird je Stelle entschieden. Bis das abgeschlossen ist, wird kein Release bereitgestellt.

Festlegungen für AA-5 (Stand 22.11.2026):
- **Name und Bundle-ID:** Anzeigename "Hörkarte", Untertitel "Inoffizieller Kartenmanager für hörbert", Bundle-Datei `Hoerkarte.app`, Bundle-ID `io.github.mathiasherrmann.hoerkarte`. Einstellungs-Namensraum und RunGuard-Schlüssel werden aus der Bundle-ID abgeleitet.
- **Eigenes Icon: geliefert (22.11.2026)** im Ordner `branding/` (SVG-Quelle, `.icns`, `.ico`, PNG 1024 und 512, README mit den zu ersetzenden Verweisen). Unter Linux erzeugt; `hoerkarte.icns` wird in AA-5 auf dem Mac geprüft. Weitere Bilder mit hörbert-Bezug unter `hoerbert/images/` sind damit nicht ersetzt.
- **Signatur:** Signiert und notarisiert wird mit der Developer-ID des Herausgebers. Apple-ID, Team-ID, Zertifikatsname und Notarisierungs-Zugang gehören nicht ins Repository; das Deploy-Skript liest sie aus Umgebungsvariablen bzw. einem Schlüsselbund-Profil.

Zielgerät: hörbert Modell 2021-Bauart (gekauft 2022). Es spielt Karten ab, die Version 3.1.4 im MP3-Format schreibt [BELEGT durch den Herausgeber im Betrieb; eine am 22.11.2026 mit 3.1.4 aus den Testquellen geschriebene Karte ist als Vergleichsbasis gesichert]. Fallback F3 entfällt.

---

## 4. Zielbild

- `Hoerkarte.app` (Anzeigename "Hörkarte"), arm64, Qt 6, signiert mit Hardened Runtime, notarisiert, als DMG.
- Im Bundle: ffmpeg, ffprobe, ffplay als arm64-Binaries aus einem versionierten Build-Skript, statisch gelinkt, mit MP3-Encoder, ohne `--enable-nonfree`, damit GPLv3-verträglich.
- fre:ac nur in der arm64-fähigen Fassung `osx11`; kein `osx10`, kein sox, kein wavsilence im macOS-Bundle.
- `ARCHITECTURE.md` als Single Source of Truth, bei jeder AA fortgeschrieben.
- Ein reproduzierbarer Build-Befehl ohne personengebundene Pfade.

### 4.1 Toolchain (Lücke, in AA-0 aufgefallen)

Stand 22.11.2026 auf dem Arbeitsrechner [BELEGT durch Agentenbericht]: Xcode 26.6 mit SDK macOS 26.5, Homebrew, `lipo`, `otool`, `codesign` vorhanden. Nicht vorhanden: Qt, `cmake`, `ninja`, `pkg-config`.

- **Qt 6: offizieller Qt-Installer, eine fest benannte Version.** Installation und Anmeldung mit Qt-Konto macht der Herausgeber selbst (interaktiv). Begründung: Ausgeliefert werden die Qt-Frameworks im Bundle; dafür soll eine eindeutig benannte, vom Hersteller gebaute Version mit dem zugehörigen `macdeployqt` verwendet werden, keine rollende Homebrew-Formel. Welche Version: AA-0 Schritt 3 stellt die aktuelle stabile Version und ihr Mindest-macOS mit Quelle fest; der Herausgeber installiert genau diese; ARCHITECTURE.md hält Versionsnummer und Installationspfad fest. Zu installieren sind nur die Desktop-Komponente für macOS und die im Projekt benutzten Module (core, gui, widgets, xml, network, concurrent). [ANNAHME: Die Open-Source-Variante des Installers genügt für ein GPLv3-Projekt; in AA-0 gegen die Qt-Lizenzseite prüfen]
- **Reine Build-Werkzeuge (`cmake`, `ninja`, `pkg-config` und was der ffmpeg-/SDL2-Build sonst verlangt): Homebrew.** Sie werden nicht ausgeliefert. Der Agent installiert sie zu Beginn von AA-2 nach ausdrücklicher Freigabe, hält die Versionen in ARCHITECTURE.md fest und installiert nur, was die offizielle Build-Anleitung nachweislich verlangt.
- **Xcode 27 nach dem Update auf macOS 27** (22.11.2026). Damit wird gegen das macOS-27-SDK gebaut. Qt 6.12 nennt als Build-Umgebung "Xcode 16 (macOS 15 SDK) oder höher" und als Ziel "einschließlich macOS 26" [BELEGT, Quelle 4]; Xcode 27 fällt formal unter "oder höher", ist dort aber nicht als getestet genannt. AA-0 Schritt 3 hält die tatsächliche Xcode- und SDK-Version fest und prüft in Qt-Dokumentation und Qt-Bugtracker, ob für die gewählte Qt-Version bekannte Probleme mit Xcode 27 oder macOS 27 gemeldet sind (Quellen angeben). Treten beim Build Fehler auf, die aus Qt-Headern oder dem SDK stammen und nicht aus Projektcode: stoppen und berichten, nicht umgehen.
- Kein Arbeitsschritt installiert etwas ohne Freigabe.

---

## 5. Arbeitsanweisungen

Reihenfolge: AA-0a (erledigt) → AA-1/AA-1b (erledigt, Basis 2.1.3) → **AA-1c → AA-0c** → AA-0 → (AA-2 ∥ AA-3) → AA-4 → AA-5 → AA-6. AA-1c braucht das alte x86_64-ffmpeg unter Rosetta und muss vor dem Update des Arbeitsrechners auf macOS 27 abgeschlossen sein. Jede AA wird einzeln beauftragt und einzeln per Diff abgenommen.

Für alle AAs gilt:
- Arbeitsumgebung: Claude Code lokal auf Apple-Silicon-Mac mit aktuellem Xcode.
- Vor jeder Änderung `ARCHITECTURE.md` lesen, nach jeder Änderung aktualisieren.
- Nicht raten: Jede Funktion vollständig lesen, bevor sie geändert wird. Unklarheiten als Frage zurückmelden, nicht per Annahme lösen.
- Jede Aussage zu Fremdsoftware (Qt, ffmpeg, Apple-Werkzeuge) mit aktueller Dokumentation belegen und die Quelle nennen.
- Abschluss jeder AA: `git diff` ausgeben, **nicht committen**.
- Pflicht-Erfolgskriterium bei jedem Build: 0 Fehler und 0 Warnungen aus dem Projektcode. Ein grüner Build ersetzt nicht das Diff-Review.

### AA-0a · Fork anlegen und Arbeitsumgebung prüfen (kein Quellcode wird geändert)

**Erledigt am 22.11.2026.** Fork `mathiasherrmann/hoerkarte`, Zweig `port/macos-arm64` auf `7f225e2`. Umgebung: arm64, macOS 26.5.1, Xcode 26.6, Rosetta installiert. Der Block bleibt zur Dokumentation stehen; die Platzhalter darin sind nicht mehr auszufüllen.

```
ZIEL
Ein eigener Fork von winzkigermany/hoerbert-software liegt unter dem
GitHub-Konto <GITHUB-NAME> und lokal auf diesem Mac vor, mit Arbeitszweig,
Portierungsplan und Branding-Ordner. Es wird nichts committet und nichts
gepusht.

EINGABEN (vom Auftraggeber, vor Start einsetzen)
- <GITHUB-NAME>: GitHub-Benutzername
- <ZIELORDNER>: lokaler Ordner, in den geklont wird; muss leer sein oder
  darf noch nicht existieren. Liegen <PLAN> und <BRANDING> darin, zuerst in
  einen Nachbarordner verschieben.
- <PLAN>: Pfad zur Datei PORTIERUNGSPLAN.md
- <BRANDING>: Pfad zum entpackten Ordner branding/

SCHRITTE
1. Umgebung prüfen und Ergebnisse notieren, nichts installieren:
   Prozessorarchitektur (erwartet arm64), macOS-Version, Xcode-Version und
   aktiver Entwicklerpfad, git-Version, ob die GitHub-CLI angemeldet ist und
   unter welchem Konto, ob Rosetta installiert ist, freier Plattenplatz
   (das Repository enthält rund 440 MB Binärdateien).
   Weicht das angemeldete GitHub-Konto von <GITHUB-NAME> ab, ist die
   Architektur nicht arm64 oder fehlt Xcode: stoppen und berichten.
2. Prüfen, ob unter <GITHUB-NAME> bereits ein Fork oder ein Repository
   namens "hoerkarte" existiert. Falls ja: stoppen und berichten, nichts
   überschreiben.
3. Fork von winzkigermany/hoerbert-software unter <GITHUB-NAME> mit dem
   Repository-Namen "hoerkarte" anlegen und nach <ZIELORDNER> klonen.
   Remote "origin" zeigt auf den Fork, Remote "upstream" auf das Original.
4. Prüfen, dass der Standardzweig auf Commit 7f225e2 steht. Ist upstream
   inzwischen weiter: stoppen und die neuen Commits auflisten, nicht
   selbst entscheiden.
5. Arbeitszweig "port/macos-arm64" von diesem Commit anlegen und auschecken.
6. <PLAN> als PORTIERUNGSPLAN.md und <BRANDING> als Ordner branding/ in das
   Wurzelverzeichnis kopieren. Inhalte nicht verändern.
7. Prüfen, dass .gitignore die Build-Ausgabe erfasst (hoerbert.pro schreibt
   nach ../../Build, also außerhalb des Repositorys). Befund berichten.
   .gitignore nicht ändern (.DS_Store ist dort bereits in Zeile 62
   erfasst). Keine .DS_Store-Datei mitkopieren.
8. Im PORTIERUNGSPLAN.md nach Platzhaltern in spitzen Klammern suchen und
   auflisten, welche noch offen sind. Nicht selbst ersetzen.

NICHT TUN
- Keinen Quellcode, kein README, keine Lizenzdatei ändern.
- Kein Release, kein Tag, keine Änderung an Repository-Einstellungen.
- Keine Zugangsdaten, Apple-IDs oder Team-IDs in Dateien schreiben.
- Nichts committen, nichts pushen.

ERFOLGSKRITERIEN
- Fork existiert, lokaler Klon steht auf Zweig port/macos-arm64 bei 7f225e2.
- git remote -v zeigt origin (Fork) und upstream (Original).
- git status zeigt genau zwei unversionierte Einträge: PORTIERUNGSPLAN.md
  und branding/. git diff ist leer.
- Umgebungsbericht aus Schritt 1 liegt als Text in der Antwort vor.

ABSCHLUSS
git status und git diff ausgeben, nicht committen.
```

### AA-1c · Referenzdaten für Version 3.1.4 (vor dem Update auf macOS 27)

```
ZIEL
Für alle ffmpeg-/ffprobe-Aufrufe der Version 3.1.4 liegen Referenzdaten
des alten x86_64-ffmpeg vor, insbesondere für den MP3-Weg (Modell 2021).
Kein Anwendungscode wird geändert, nichts installiert.

SCHRITTE (1 bis 4 brauchen Rosetta; bei Zeitnot hat Schritt 4 Vorrang)
1. Alle Zweige und Tags von upstream holen. Den aktuellen Zweig nicht
   verändern. Per git worktree einen zweiten Arbeitsordner auf
   upstream/feedback (1280aac) anlegen, außerhalb des jetzigen
   Arbeitsordners; existiert der Zielordner, stoppen.
2. Prüfen und berichten: Sind ffmpeg, ffprobe, ffplay und ihre dylibs
   unter hoerbert/tools/mac/ffmpeg in 3.1.4 byte-identisch mit den in
   tests/reference/altes-ffmpeg/HERKUNFT.md erfassten? Stimmen sie mit
   den Binaries der installierten App überein? Welchen MP3-Encoder
   enthält das alte ffmpeg laut buildconf und Encoder-Liste?
3. Alle ffmpeg-, ffprobe-, ffplay- und freac-Aufrufe aus dem
   3.1.4-Quelltext erheben, nach dem Muster von AUFRUFE.md, in
   tests/reference/AUFRUFE-3.1.4.md. Je Aufruf: unverändert, geändert
   oder neu gegenüber 2.1.3; und ob er vom Modell (2011/2021) abhängt.
4. Alle geänderten und neuen Aufrufe mit dem alten ffmpeg gegen die
   vorhandenen Quellen ausführen, zuerst die mit MP3 als Ziel.
   Referenzen wie in AA-1 und AA-1b: geparste Zeilen, Rückgabecodes,
   Messwerte der erzeugten Dateien (Container, Codec, Encoder-Angabe,
   Abtastrate, Kanäle, Bitrate, Dauer, Tags und ihr Aufbau, Prüfsumme
   der Datei und der dekodierten PCM-Daten), Fehlerfälle (dieselben
   Eingaben wie in AA-1b). Erzeugte Audiodateien byte-genau in einen
   Archivordner außerhalb des Repositorys, Liste mit Größe und SHA-256
   ins Repository. Ablage getrennt von den 2.1.3-Referenzen.
   compare.sh prüft beide Sätze.
5. Die mit der App 3.1.4 aus tests/reference/quellen/ bespielte SD-Karte
   sichern: gesamten Inhalt byte-genau in den Archivordner, SHA-256-Liste,
   index.m3u und alle weiteren Nicht-Audio-Dateien im Wortlaut ausgeben,
   jede MP3 der Karte mit den Ergebnissen aus Schritt 4 vergleichen
   (Messwerte und Prüfsummen) und jede Abweichung mit wahrscheinlicher
   Ursache nennen. Auf der Karte nichts ändern.
6. Von der installierten App festhalten: Info.plist, Architektur aller
   Mach-O-Dateien, eingebundene Qt-Version; Kopie des App-Bundles in den
   Archivordner.

ERFOLGSKRITERIEN
- compare.sh gegen das alte ffmpeg: 0 Fehler, zwei Durchläufe identisch,
  Gegenprobe mit verfälschter Referenz schlägt an.
- Der Bericht nennt jede Zelle der Fehlerfälle, in der die App nach dem
  Code von 3.1.4 einen Fehlschlag als Erfolg werten würde.

ABSCHLUSS
git status und git diff ausgeben, nicht committen.
```

### AA-0c · Arbeitszweig auf Version 3.1.4 umstellen

```
ZIEL
Ein neuer Arbeitszweig port/macos-arm64-v3 basiert auf upstream/feedback
(1280aac) und enthält Branding und Tests. Kein Anwendungscode wird
geändert.

SCHRITTE
1. Prüfen, ob der Fork die Zweige feedback und den Tag 3.1.4 enthält;
   falls nicht, von upstream holen und in den Fork übertragen (nur diese
   Referenzen, nach Freigabe).
2. Zweig port/macos-arm64-v3 von 1280aac anlegen.
3. Die Commits mit branding/ und tests/ vom bisherigen Zweig übernehmen.
   Sie fügen nur neue Dateien hinzu; entsteht dennoch ein Konflikt,
   stoppen und berichten.
4. Den bisherigen Zweig port/macos-arm64 nicht löschen und nicht
   verändern. In tests/README.md vermerken, welche Referenzen zu 2.1.3
   und welche zu 3.1.4 gehören.
5. compare.sh ausführen, soweit das ohne altes ffmpeg möglich ist, und
   berichten, was sich ohne Rosetta nicht mehr ausführen lässt.

ABSCHLUSS
git status, git log --oneline -8 und git diff ausgeben, nicht pushen.
```

### AA-0 · Bestandsaufnahme und ARCHITECTURE.md (nur lesen und dokumentieren)

```
ZIEL
Erstelle ARCHITECTURE.md im Repository-Wurzelverzeichnis. Ändere keinen Quellcode.

SCHRITTE
1. Arbeite auf dem Zweig port/macos-arm64-v3 (Version 3.1.4). Lies alle
   Dateien unter hoerbert/*.cpp und hoerbert/*.h vollständig.
2. Dokumentiere: Klassen und ihre Verantwortung; alle Stellen, an denen externe
   Programme gestartet werden (Programm, Argumente, welche Ausgabe wird wie
   ausgewertet); alle plattformspezifischen Zweige (Q_OS_MACOS, Q_OS_MAC, _WIN32,
   Q_OS_LINUX); Aufbau des App-Bundles laut hoerbert.pro; Speicherorte von
   Einstellungen und Temp-Dateien.
3. Stelle fest und halte mit Versionsnummer fest: installierte Xcode-Version,
   macOS-Version, aktuell verfügbare stabile Qt-6-Version und deren
   Mindest-macOS laut offizieller Qt-Dokumentation (Quelle angeben).
4. Voraussetzung: Qt 6 ist gemäß Abschnitt 4.1 installiert. Fehlt es, alle
   anderen Schritte ausführen und Schritt 4 nachziehen, sobald es steht.
   Baue das Projekt unverändert NICHT um; prüfe nur, ob es mit der gewählten
   Qt-6-Version konfiguriert, und liste die vollständige Fehlerliste des ersten
   Compile-Versuchs als Anhang "Qt-6-Brüche" auf. Vergleiche sie mit Abschnitt
   1.4 des Portierungsplans und nenne Abweichungen.
5. Prüfe die Vermutung B3 (processexecutor.cpp, setFuture vor Zuweisung) durch
   Lesen der Qt-Dokumentation zu QFutureWatcher und halte das Ergebnis fest.

ERFOLGSKRITERIEN
- ARCHITECTURE.md existiert und deckt alle 36 .cpp-Dateien ab, beschreibt
  die Umschaltung zwischen Modell 2011 und 2021 und listet jeden
  Netzwerkzugriff mit Ziel-URL und Zweck.
- Für die gewählte Qt-6-Version ist belegt, welches TLS-Backend auf macOS
  verfügbar ist und wie es ins Bundle kommt.
- Jede Aussage über Qt/Xcode trägt eine Quelle.
- Kein Quellcode verändert.

ABSCHLUSS
git diff ausgeben, nicht committen.
```

### AA-1 · Referenzdaten der bestehenden Audio-Pipeline (vor jeder Codeänderung)

**Erledigt am 22.11.2026 auf Basis 2.1.3, samt Nachtrag AA-1b** (Rückgabecodes, Fehlerfälle, archivierte Audioausgaben). Für 3.1.4 gilt AA-1c. Der Block bleibt zur Dokumentation stehen.

```
ZIEL
Lege fest, was "funktioniert wie vorher" messbar bedeutet. Ändere keinen
Anwendungscode.

SCHRITTE
1. Lege unter tests/reference/ einen Satz kurzer, selbst erzeugter Testdateien
   an (keine urheberrechtlich geschützten Inhalte): je eine Datei in mp3, m4a,
   m4b mit Kapiteln, ogg, flac, wav, wma, aiff; dazu eine Datei mit klaren
   Stillephasen und eine sehr leise Datei.
2. Führe mit dem im Repository liegenden alten ffmpeg/ffprobe exakt die
   Aufrufe aus, die die App absetzt (Argumentlisten aus ARCHITECTURE.md):
   Konvertierung nach WAV, Segmentierung, silencedetect, volumedetect,
   ffprobe-JSON, Kapitelabfrage. Auf Apple Silicon läuft das alte Binary nur
   mit installiertem Rosetta; falls nicht vorhanden, melde das und stoppe.
   Sichere zusätzlich vom alten ffmpeg, ffprobe und ffplay die Ausgaben
   zu Version, Build-Konfiguration sowie die Listen der Decoder, Demuxer,
   Muxer und Filter. Sie sind später die Vorlage für den Neubau in AA-2
   und nach dem Update auf macOS 27 nicht mehr zu gewinnen.
3. Speichere je Aufruf: vollständige Textausgabe, und für jede erzeugte WAV
   Dateigröße, Abtastrate, Kanalzahl, Bittiefe, Dauer, die Liste der
   RIFF-Chunks in Reihenfolge mit Größen, die enthaltenen Metadaten sowie eine
   Prüfsumme über die reinen PCM-Daten.
4. Schreibe ein Prüfskript tests/compare.sh, das dieselben Aufrufe mit einem
   per Parameter übergebenen ffmpeg-Verzeichnis wiederholt und Abweichungen
   gegen die Referenz meldet. Abweichung in der PCM-Prüfsumme wird als
   Hinweis ausgegeben, Abweichung in Format, Chunk-Struktur, Metadaten oder in
   den von der App geparsten Zeilen als Fehler.

ERFOLGSKRITERIEN
- compare.sh gegen das alte ffmpeg läuft ohne Fehler durch.
- Referenzdaten liegen versioniert vor, ARCHITECTURE.md beschreibt das
  Verfahren.

ABSCHLUSS
git diff ausgeben, nicht committen.
```

### AA-2 · ffmpeg-Suite für arm64 aus Quellen (parallel zu AA-3 möglich)

```
ZIEL
Ersetze die x86_64-Binaries unter hoerbert/tools/mac/ffmpeg durch arm64-Builds
von ffmpeg, ffprobe und ffplay aus einem reproduzierbaren Skript.

VORGABEN
- Recherchiere zuerst die aktuelle stabile FFmpeg-Version und die offizielle
  Build-Anleitung für macOS; Quellen nennen.
- Liste danach die fehlenden Build-Werkzeuge gemäß Abschnitt 4.1 auf und
  warte auf Freigabe, bevor du sie per Homebrew installierst.
- Skript tools-build/build-ffmpeg-macos.sh: lädt eine fest benannte
  Release-Version samt Prüfsumme, baut für arm64 mit dem Deployment-Target aus
  ARCHITECTURE.md, statisch, ohne --enable-nonfree. Der MP3-Encoder wird
  so gewählt, wie ihn das alte Binary laut AA-1c enthält, ebenfalls aus
  Quellen statisch gebaut, mit Lizenztext. Weitere externe
  Codec-Bibliotheken nur, wenn compare.sh sie nachweislich verlangt. ffplay benötigt SDL2:
  ebenfalls aus Quellen statisch bauen, nicht aus Homebrew verlinken.
- Die fertigen Binaries dürfen ausschließlich Systembibliotheken referenzieren
  (mit otool -L nachweisen) und müssen nur arm64 enthalten (mit lipo -archs
  nachweisen).
- Lege die Lizenztexte und die verwendete configure-Zeile neben die Binaries.
- Entferne die alten dylibs und die nicht referenzierten Dateien
  hoerbert/tools/mac/sox und hoerbert/tools/mac/wavsilence.

ERFOLGSKRITERIEN
- Prüfe mit halb-ton.ogg aus den Fehlerfällen, ob das neue ffmpeg bei
  einer abgeschnittenen Ogg-Datei einen Hinweis ausgibt (etwa eine
  fehlende Endmarkierung), und berichte den Wortlaut.
- Vergleiche die Decoder- und Demuxer-Listen des Neubaus mit
  tests/reference/altes-ffmpeg/ für alle Formate aus SUPPORTED_FILES
  (define.h) und berichte jede Lücke.
- tests/compare.sh mit dem neuen Verzeichnis: 0 Fehler. Jeder Hinweis
  (PCM-Abweichung) ist einzeln erklärt.
- Meldet compare.sh Fehler in geparsten Zeilen oder in der WAV-Struktur:
  nicht den Parser oder die Referenz anpassen, sondern stoppen und den Befund
  berichten.
- ARCHITECTURE.md aktualisiert (Version, Herkunft, Build-Verfahren).

ABSCHLUSS
git diff ausgeben, nicht committen.
```

### AA-3 · Quellcode auf Qt 6 portieren

```
ZIEL
hoerbert baut mit der in ARCHITECTURE.md festgelegten Qt-6-Version als arm64
und startet. Verhalten bleibt gleich, außer wo unten ausdrücklich genannt.

VORGABEN
- Arbeite die Liste "Qt-6-Brüche" aus ARCHITECTURE.md und Abschnitt 1.4 des
  Portierungsplans vollständig ab. Verwende ausschließlich Qt-6-eigene APIs;
  das Modul Core5Compat ist nicht zulässig.
- Reguläre Ausdrücke: Jede QRegExp-Stelle einzeln auf Semantik prüfen
  (Greedy-Verhalten, exakte vs. teilweise Übereinstimmung, Validator in
  cardpage.cpp) und das im Diff-Kommentar begründen.
- Prozessstarts: Es darf keinen Start über eine zusammengesetzte
  Kommandozeile mehr geben. ProcessExecutor nimmt Programm und Argumentliste
  getrennt entgegen; alle Aufrufer in devicemanager.cpp werden entsprechend
  umgestellt. Der Linux-sudo-Pfad wird nur so weit angepasst, wie der Compiler
  es verlangt, und in ARCHITECTURE.md als ungeprüft markiert.
- macOS-Gerätefunktionen: isRemovable, isEjectable, Formatierbefehl und
  Aus-/Einhängen werten die maschinenlesbare Ausgabe von diskutil aus statt
  Freitext. Der Gerätename der ganzen Platte wird aus dieser Ausgabe gelesen,
  nicht durch Abschneiden von Zeichen gebildet (behebt B4). remountDrive
  wertet den Erfolg korrekt aus (behebt B2).
- Behebe B1 (Übersetzungen), B3 (Reihenfolge Future/Watcher; in AA-1
  bestätigt), B9, B10 und B17 (Größenabschätzung MP3: aus der
  tatsächlichen Bitrate herleiten und an den Referenz-MP3s belegen).
  B5 zuerst am Quelltext von 3.1.4 prüfen. Bei B10: Konstante an die gemessene
  Dateistruktur anpassen, die Reserve in playlistview.cpp nicht ersatzlos
  streichen. B6 nicht anfassen. B7 und B8 nicht ändern, in ARCHITECTURE.md
  als bekannte Fehler im ungeprüften Linux-Pfad vermerken.
- Fehlererkennung gemäß Entscheidung E8. Liegt E8 noch nicht vor:
  stoppen. Jede Änderung an der Fehlererkennung wird durch die Fehlerfälle
  unter tests/reference/fehlerfaelle/ belegt.
- B19 (doppelte MP3-Kodierung der Kapitel) bleibt in dieser Portierung
  unverändert (E11). Der zweistufige Kapitelweg muss nach dem Port
  dieselben PCM-Daten liefern wie die Referenz.
- B13 nicht eigenmächtig beheben: Schlage vor, ab welcher Dauer bzw.
  Nutzdatenmenge eine Datei abgewiesen werden soll und an welcher Stelle,
  und warte auf Entscheidung.
- Der Aufruf A2 liefert auch im Erfolgsfall Rückgabecode 1. Beim Umbau von
  ProcessExecutor und seinen Aufrufern darf für A2 keine Prüfung auf den
  Rückgabecode hinzukommen; im Diff ausdrücklich nachweisen.
- hoerbertprocessor.cpp:790–800 ersetzt Argumente über feste Indizes
  (3, 5, 15 und den letzten). Jede Änderung an dieser Argumentliste muss die Indizes
  mitziehen; im Diff ausdrücklich nachweisen.
- Wird B3 behoben, blockiert der Aufrufer nicht mehr. Prüfe für jeden
  Aufrufer von executeCommand, ob er sich auf das bisherige blockierende
  Verhalten verlässt, und dokumentiere das Ergebnis je Aufrufer.
- Entferne QTextCodec und AA_EnableHighDpiScaling; prüfe und dokumentiere,
  dass Umlaute in Dateinamen, Metadaten und hoerbert.xml weiterhin korrekt
  als UTF-8 verarbeitet werden.
- Parser-Tests: tests/lauf.sh prüft die ffmpeg-Ausgaben nur über
  Python-Nachbildungen der Parser, nicht über den C++-Code. Lege deshalb
  mit Qt Test automatische Tests an, die die echten Funktionen
  (Kapitel-Parser, Auswertung von silencedetect, volumedetect und der
  Duration-Zeile, Fehlererkennung über "Error"/"Invalid") mit den
  gespeicherten Rohausgaben aus tests/reference/erwartet/rohausgaben/
  füttern und gegen die Werte unter geparst/ prüfen. Ist eine Funktion
  dafür nicht aufrufbar, ohne sie umzubauen: stoppen und den nötigen
  Umbau vorschlagen.
- Schalte in hoerbert.pro die Verwendung veralteter Qt-APIs als Fehler.
- hoerbert/Hoerbert_mac_rainer.pro und common.pri (liegt im
  Wurzelverzeichnis): beide werden von keiner .pro-Datei eingebunden
  (in AA-0a festgestellt); erneut prüfen und entfernen.

ERFOLGSKRITERIEN
- Build: 0 Fehler, 0 Warnungen aus Projektcode.
- lipo -archs auf das App-Binary zeigt arm64.
- App startet, Hauptfenster erscheint zentriert, deutsche Oberfläche inklusive
  Qt-eigener Dialogtexte ist übersetzt.
- ARCHITECTURE.md aktualisiert.

ABSCHLUSS
git diff ausgeben, nicht committen.
```

### AA-4 · fre:ac auf den arm64-fähigen Satz festlegen

```
ZIEL
Auf macOS wird ausschließlich das mitgelieferte fre:ac aus
hoerbert/tools/mac/freac/osx11 verwendet. Der Intel-Satz osx10 wird auf
macOS weder ausgewählt noch ausgeliefert.

SCHRITTE
1. Lies cdripper.cpp, playlistview.cpp (Erkennung von .cda/.aiff und
   Ablauf danach) und main.cpp (Pfadwahl und Startprüfung) vollständig
   und beschreibe den heutigen Ablauf in ARCHITECTURE.md.
2. Ersetze die Versionsweiche in main.cpp:148–155 (B18) durch die feste
   Wahl des osx11-Satzes auf macOS. Passe define.h entsprechend an.
3. Entferne hoerbert/tools/mac/freac/osx10 und stelle sicher, dass
   hoerbert.pro nur noch osx11 ins Bundle legt. Prüfe, ob im osx11-Satz
   Dateien liegen, die für freaccmd nicht gebraucht werden (z. B. die
   grafische Oberfläche); entferne nichts ohne Nachweis, sondern liste
   Kandidaten auf.
4. Prüfe per Skript: Jede Mach-O-Datei unter osx11 enthält arm64; keine
   verweist auf Bibliotheken außerhalb des Bundles oder des Systems.
5. Führe den Aufruf aus cdripper.cpp (freaccmd -e flac -o <Ziel> <Quelle>)
   mit ton.aiff aus den Testquellen aus und vergleiche das Ergebnis
   (Format, Dauer, PCM-Prüfsumme) mit der Quelle.

ERFOLGSKRITERIEN
- Build wie AA-3; die App startet, ohne nach osx10 zu suchen.
- Import einer .aiff-Datei von der Festplatte funktioniert Ende-zu-Ende.
- Schlägt Schritt 5 unter macOS 27 fehl: stoppen und berichten; die
  Rückfallebene (Ersatz durch ffmpeg) wird dann gesondert beauftragt.
- Der Test mit echter Audio-CD ist als offene manuelle Abnahme M3
  vermerkt.

ABSCHLUSS
git diff ausgeben, nicht committen.
```

### AA-5 · Bundle-Struktur, Info.plist, Deployment-Skript

```
ZIEL
Ein einziger Befehl erzeugt aus einem sauberen Checkout ein vollständiges,
signierfähiges Hoerkarte.app (Anzeigename "Hörkarte"). Der qmake-TARGET in
hoerbert/hoerbert.pro wird entsprechend umbenannt; alle Stellen, die den
alten Programmnamen voraussetzen, werden mitgezogen.

VORGABEN
- Recherchiere die aktuelle Apple-Dokumentation zu Bundle-Aufbau, Hardened
  Runtime, Signieren eingebetteter Hilfsprogramme und Notarisierung sowie die
  Qt-Dokumentation zu macdeployqt; Quellen nennen. Lege danach fest, wo
  ffmpeg/ffprobe/ffplay im Bundle liegen, und passe define.h entsprechend an.
- Eigene Info.plist: Bundle-ID und Anzeigename gemäß Abschnitt 3.1, Version aus version.h,
  Mindest-macOS, Erklärungstext für den Zugriff auf Wechselmedien, Angabe
  dass nur arm64 unterstützt wird.
- Build-Ausgabe: hoerbert/hoerbert.pro schreibt auf macOS nach ../../Build,
  also in den Elternordner des Repositorys. Ändere DESTDIR (Zeile 31)
  auf <Repository>/Build. Dieser Pfad ist in .gitignore bereits erfasst
  (Zeile 52, /Build); .gitignore bleibt unverändert.
- Ersetze mac-deploy.sh und macdeployqtfix.py durch ein Skript ohne
  personengebundene Pfade. Signieridentität und Notarisierungsprofil kommen
  aus Umgebungsvariablen; fehlen sie, baut das Skript ein unsigniertes Bundle
  und sagt das deutlich.
- Fork-Vorgaben aus Abschnitt 3.1 Punkt 2 bis 4 vollständig umsetzen (Bundle-ID,
  Einstellungs-Namensraum, RunGuard-Schlüssel, Update-Check entfernen,
  Kennzeichnung im About-Dialog und README, eigenes Icon). Fehlt der Ordner branding/, stoppen. Keine Zugangsdaten, Apple-IDs oder
  Team-IDs in Dateien des Repositorys schreiben.
- Die in define.h festgelegte Schrift für macOS prüfen: existiert sie auf dem
  Zielsystem, sonst Systemschrift verwenden.
- README.md auf den neuen Build-Weg aktualisieren.

ERFOLGSKRITERIEN
- Skript läuft auf sauberem Checkout durch.
- Prüfskript bestätigt: alle Mach-O-Dateien im Bundle arm64, keine Referenz
  auf Pfade außerhalb des Bundles oder des Systems.
- App startet aus /Applications nach Kopie auf einen zweiten Benutzeraccount.
- ARCHITECTURE.md aktualisiert.

ABSCHLUSS
git diff ausgeben, nicht committen.
```

### AA-6 · Abschlussprüfung durch einen unabhängigen Agenten

```
ZIEL
Unabhängiges Review des Gesamtdiffs gegen Commit 1280aac (Version 3.1.4) durch einen Agenten,
der an AA-0 bis AA-5 nicht beteiligt war.

PRÜFE
- Jede geänderte Stelle: Ist die Semantik gegenüber dem Original belegt
  gleich, oder ist die Abweichung im Plan vorgesehen?
- Gibt es verbliebene Qt-5-Reste, auskommentierten Altcode, TODOs, die durch
  den Port entstanden sind?
- Stimmen ARCHITECTURE.md und Code überein?
- Laufen tests/compare.sh und der Bundle-Architektur-Check fehlerfrei?

ERGEBNIS
Liste aller Funde. Jeder Fund ist zu beheben; es gibt keine Einstufung als
"später". Kein Code ändern, nur berichten.
```

---

## 6. Manuelle Abnahmen (nicht delegierbar)

| # | Abnahme | Wer/Was nötig |
|---|---|---|
| M1 | Signieren und Notarisieren, Gatekeeper-Test auf frischem Mac | Apple Developer-ID, App-spezifisches Passwort oder API-Key |
| M2 | SD-Karte mit dem neuen Build: erkennen, lesen, bespielen (MP3-Weg), auswerfen, formatieren; Karte im hörbert abspielen. Vergleichsbasis ist die am 22.11.2026 mit 3.1.4 geschriebene, gesicherte Karte | Kartenleser, hörbert (Bauart 2021) |
| M2b | Set-Modus-, WLAN- und Aufnahme-Einstellungen mit dem neuen Build auf die Karte schreiben und am Gerät prüfen | wie M2 |
| M2c | Firmware-Prüfung und Firmware-Download (sofern E9 = behalten) | Internetverbindung |
| M3 | Audio-CD einlesen | externes CD-Laufwerk |
| M4 | Kompletter Durchlauf auf macOS 27 **ohne** installiertes Rosetta | Mac mit macOS 27 |
| M5 | Backup erstellen und zurückspielen, Diagnosemodus an/aus, Support-Paket erzeugen | wie M2 |
| M6 | Hell-/Dunkelmodus und Retina-Darstellung sichten | – |

M2 ist das eigentliche Abnahmekriterium des Projekts: Erst wenn eine mit dem neuen Build bespielte Karte im Gerät läuft, ist die ffmpeg-Frage beantwortet. Der Weg für Modell 2011 (WAV) bleibt mangels Gerät am Gerät ungeprüft (E10).

---

## 7. Quellen

1. MacRumors, "macOS 27 Golden Gate Is the Last to Support Intel Apps via Rosetta 2", 10.06.2026 – https://www.macrumors.com/2026/06/10/macos-golden-gate-last-to-support-intel-apps/
2. Cult of Mac, "macOS 27 Golden Gate is last update to support Intel apps" – https://www.cultofmac.com/news/macos-27-golden-gate-last-update-support-intel-apps
3. AppleInsider, "How and when macOS will finally stop support for Intel apps", 12.06.2026 – https://appleinsider.com/articles/26/06/12/how-and-when-macos-will-finally-stop-support-for-intel-apps
4. Qt-Dokumentation, "Qt for macOS" (Qt 6.12) – https://doc.qt.io/qt-6/macos.html
5. fre:ac, "fre:ac is now available for Apple Silicon Macs" – https://www.freac.org/component/content/article/1-latest/348-freac-available-for-apple-silicon ; Homebrew-Cask freac 1.1.7 – https://formulae.brew.sh/cask/freac
6. Qt-Dokumentation, "Building FFmpeg from source on macOS" – https://doc.qt.io/qt-6.10/qtmultimedia-building-ffmpeg-macos.html
7. Repository `winzkigermany/hoerbert-software`, Zweig `feedback`, Commit 1280aac – alle Datei- und Zeilenangaben
8. hoerbert.com, Service-Archiv und Software-Downloads (Version 3.1.4 für hörbert 2021 mit Firmware vor "Butterfly") – https://www.hoerbert.com/service-archive/ , https://en.hoerbert.com/customer-service/downloads-and-questions-about-transferring-contents/

---

## 8. Backlog nach der Portierung

Diese Punkte werden erst bearbeitet, wenn die Portierung abgenommen ist (AA-6 und die manuellen Abnahmen aus Abschnitt 6). Bis dahin bleibt das jeweilige Verhalten unverändert.

| # | Punkt | Stand |
|---|---|---|
| BL-1 | B19 beheben: Hörbuchkapitel für Modell 2021 nur einmal verlustbehaftet kodieren. Vor der Umsetzung: Vorschlag, wie die zweite Kodierung entfällt, und neue Referenz für die Kapiteldateien, weil sie danach nicht mehr mit dem Original übereinstimmen. | entschieden am 22.11.2026 (E11) |
