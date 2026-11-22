# Archiv außerhalb des Repositorys

Die von AA-1 erzeugten Audiodateien selbst liegen **nicht** im Repository:
42 MB Audiodaten gehören nicht in die Versionsverwaltung. Sie sind aber auch
nicht reproduzierbar, weil sie nur mit dem alten x86_64-ffmpeg unter Rosetta 2
entstehen können und Rosetta mit dem Update auf macOS 27 entfällt.

Deshalb dieses Verzeichnis: Es hält fest, was außerhalb liegt, wo es liegt
und mit welcher Prüfsumme — damit ein verlorenes oder verändertes Archiv
auffällt, statt unbemerkt zu bleiben.

## Ablageort

```
/Users/mathias/Projekte/hoerkarte-archiv/aa1-ffmpeg-ausgaben
```

Daneben liegen dort `HERKUNFT.md` mit der Zuordnung jeder Datei zu ihrem
Aufruf und `SHA256SUMS.txt` zum Nachprüfen.

**Zweites Medium:** noch offen. Das Archiv liegt bislang nur auf der internen
Platte dieses Rechners, also auf genau dem Gerät, das umgestellt wird.

## Was im Repository stattdessen liegt

* `erwartet/erzeugte-wavs/` — Formatangaben, Chunk-Struktur und PCM-Prüfsumme
  jeder Datei. Das ist die Grundlage für `compare.sh`.
* `erwartet/wav-koepfe/` — der Kopfbereich jeder Datei als annotierter
  Hexdump, bis einschließlich des `data`-Chunk-Headers. 80 KB für alle 20
  Dateien. Dort entscheidet sich die Lesbarkeit durch die hörbert-Firmware:
  Chunk-Reihenfolge, `fmt`-Parameter und der `LIST`/`INFO`-Block mit den
  Metadaten sind vollständig sichtbar.

Wer in AA-2 einer strittigen Messung nachgehen will, kommt damit ohne das
Archiv aus, solange es um den Dateikopf geht. Für die Audiodaten selbst
braucht es das Archiv.

## Prüfsummen, Stand 2026-11-22 14:36 CET

| Datei | Bytes | SHA-256 |
|---|---|---|
| `A10-stille.WAV` | 320146 | `c7d988358d93853e282dcfbaaec91f1c0314dc35e59b8a79bc593bd89797b11c` |
| `A11-eingang.WAV` | 384150 | `865c18143cf9862ccce1b96d03527a4d5b0413c450c70fcac0ad0dabf2b8fc49` |
| `A11-temp.WAV` | 384178 | `44d51f60eff8f453916c26b38fbcde4722986d1bdf2c3f0cb5d9d31f2d606766` |
| `A13-restore.WAV` | 384150 | `865c18143cf9862ccce1b96d03527a4d5b0413c450c70fcac0ad0dabf2b8fc49` |
| `A3-kapitel-0.WAV` | 128122 | `c16a239128a18182678f6e5487159703149119de20648cbc33b34f39a566d444` |
| `A3-kapitel-1.WAV` | 128122 | `048e599473833359a0bde1b5150b7166faae5937028bc88e6a7424f886bd5238` |
| `A3-kapitel-2.WAV` | 128122 | `768691aa193d8f50917ff139fc458f2128f1a0d1a934fcc7889250bf19055b8e` |
| `A5-aiff.WAV` | 384152 | `69ffec90c3b121aa8095e5de31f0cde80780951935fbca4d82878d29eac90341` |
| `A5-flac.WAV` | 384152 | `d0a2665d7db16f58cb72a6ad137e2455c8d644963143ef9baa2ad63aad575ea9` |
| `A5-leise.WAV` | 384144 | `a0795eb091e3bb3e133fb1df30b3e65689d571fcc7fc6d6e200dcc57df4e197f` |
| `A5-m4a.WAV` | 385044 | `e480cc565333c86c6ce86f1795d93ea6a4824c666e1a85631ecf60cbb213f816` |
| `A5-mp3.WAV` | 384150 | `24d6f3ef23f750e82f6b640a108c5c7d17f1de915649bb6e88ba5b11c274c070` |
| `A5-ogg.WAV` | 384952 | `8d6a41e2e8a43b2a5aae9264d91395f9a881ca623fafab29e7daea0b5e3e58d7` |
| `A5-wav.WAV` | 384150 | `865c18143cf9862ccce1b96d03527a4d5b0413c450c70fcac0ad0dabf2b8fc49` |
| `A5-wma.WAV` | 386532 | `8dacfdf3cd1fcb5dabd71d890236c3eeb2cc7a84cf2d950707d975b3adca49d6` |
| `A6-7-0.WAV` | 11522424 | `466639e31268e64df305a3c0154008339dcb94d4d8b0db41d9660b222871419e` |
| `A6-7-1.WAV` | 11522458 | `6add3ff356beaf8081b8a34fb6cacda34380aa71d8bec429021e109a428dc719` |
| `A6-7-2.WAV` | 3259592 | `4543fa39de58464dbd783ae61c2b7d8c4bd90125e2ee3e98558ccdf281a1e69c` |
| `A8-8-0.WAV` | 12992156 | `5a789f0c5834307c5052ccb30519f5401e379a8823ba2e557ea52ffa46cf0039` |
| `A12-backup.flac` | 131589 | `06eed1be909c3249e5e3dcab738ba43227ca34db74204ca2875cfa741bff4d7d` |

Insgesamt 20 Dateien,  42M.

Nachprüfen:

```
cd /Users/mathias/Projekte/hoerkarte-archiv/aa1-ffmpeg-ausgaben && shasum -a 256 -c SHA256SUMS.txt
```
