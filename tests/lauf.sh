#!/bin/bash
# Führt genau die ffmpeg-/ffprobe-Aufrufe aus, die die hörbert-Software absetzt,
# und schreibt Rohausgaben und Messwerte in ein Zielverzeichnis.
#
# Die Argumentlisten sind 1:1 dem Quellcode entnommen; die Herkunft jeder Liste
# steht in tests/reference/AUFRUFE.md mit Datei und Zeilennummer.
#
# Aufruf: lauf.sh <ffmpeg-verzeichnis> <quellen-verzeichnis> <ziel-verzeichnis>
set -eu

FFDIR="${1:?ffmpeg-Verzeichnis fehlt}"
QUELLEN="${2:?Quellen-Verzeichnis fehlt}"
ZIEL="${3:?Ziel-Verzeichnis fehlt}"

FFMPEG="$FFDIR/ffmpeg"
FFPROBE="$FFDIR/ffprobe"
HIER="$(cd "$(dirname "$0")" && pwd)"
STRUKTUR="$HIER/wav-struktur.py"

for pfad in "$FFMPEG" "$FFPROBE" "$STRUKTUR"; do
  [ -x "$pfad" ] || { echo "FEHLT: $pfad" >&2; exit 2; }
done

ROH="$ZIEL/rohausgaben"      # vollständige Textausgabe je Aufruf
GEPARST="$ZIEL/geparst"      # nur die Zeilen, die die App tatsächlich auswertet
WAVS="$ZIEL/erzeugte-wavs"   # Messwerte der erzeugten Dateien
TMP="$ZIEL/tmp"              # Audio-Ausgaben, nicht Teil des Vergleichs
rm -rf "$ROH" "$GEPARST" "$WAVS" "$TMP"
mkdir -p "$ROH" "$GEPARST" "$WAVS" "$TMP"

# Einstellungen, die die App aus QSettings liest. Für die Referenz fest
# gesetzt, damit die Lautstärkekorrektur deterministisch ist.
#   hoerbertprocessor.cpp:603-612 / audiobookconverter.cpp:237-247
ZIEL_MAXPEGEL="-1.5"     # Fallback der App, "Not to ever ever change."
LAUTER_MACHEN="1"        # QSettings Global/increaseVolume

# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------

# Entfernt alles, was sich zwischen zwei Läufen zwangsläufig unterscheidet:
# Speicheradressen in Filternamen, Laufzeit-/Geschwindigkeitsangaben und die
# absoluten Pfade des Arbeitsverzeichnisses.
normalisiere() {
  sed -E \
    -e 's/@ 0x[0-9a-f]+/@ 0xADRESSE/g' \
    -e 's#'"$ZIEL"'#<ZIEL>#g' \
    -e 's#'"$QUELLEN"'#<QUELLEN>#g' \
    -e 's#'"$FFDIR"'#<FFDIR>#g' \
    -e 's/^(size|video|frame)=.*$/\1=<FLUECHTIG>/' \
    -e 's/time=[0-9:.]+/time=<FLUECHTIG>/g' \
    -e 's/bitrate=[^ ]+/bitrate=<FLUECHTIG>/g' \
    -e 's/speed=[^ ]+/speed=<FLUECHTIG>/g' \
    -e 's/Lsize=[^ ]+/Lsize=<FLUECHTIG>/g'
}

# Messwerte einer erzeugten Audiodatei: Formatangaben aus ffprobe, die
# RIFF-Chunk-Struktur und eine Prüfsumme über die reinen PCM-Daten.
# Die PCM-Summe wird getrennt gehalten, weil eine Abweichung dort laut
# Plan nur ein Hinweis ist, eine Abweichung in Struktur oder Metadaten
# dagegen ein Fehler.
messe() {
  local datei="$1" name="$2"

  {
    echo "# ffprobe-Formatangaben"
    ffprobe_lauf -hide_banner -v quiet -print_format json -show_format -show_streams "$datei" \
      | python3 -c '
import json, sys
d = json.load(sys.stdin)
f = d.get("format", {})
for k in ("format_name", "duration", "size", "bit_rate", "nb_streams"):
    print("format_%s: %s" % (k, f.get(k)))
for k in sorted(f.get("tags", {})):
    print("tag_%s: %s" % (k.lower(), f["tags"][k]))
for s in d.get("streams", []):
    for k in ("codec_name", "sample_fmt", "sample_rate", "channels",
              "channel_layout", "bits_per_sample", "duration"):
        print("stream_%s: %s" % (k, s.get(k)))
'
    echo "# RIFF-Struktur"
    python3 "$STRUKTUR" "$datei"
  } > "$WAVS/$name.messwerte.txt"

  # Prüfsumme über die dekodierten PCM-Daten, ohne Header und Metadaten.
  ffmpeg_lauf -hide_banner -nostdin -v error -i "$datei" -f s16le -c:a pcm_s16le - 2>/dev/null \
    | shasum -a 256 | cut -d' ' -f1 > "$WAVS/$name.pcm-sha256.txt"
}

# Berechnet die Lautstärkekorrektur genau wie getVolumeDifference.
# Gibt die Zahl in dB aus, oder leer, wenn die App keinen -af-Parameter anhängt.
# $1 = Quelldatei, $2 = Obergrenze (30 bei convertToWav/splitPer3Mins,
# 20 bei splitOnSilence und AudioBookConverter)
volumenkorrektur() {
  local datei="$1" grenze="$2" ausgabe maxvol diff
  ausgabe="$(ffmpeg_lauf -hide_banner -nostdin -i "$datei" -af volumedetect \
              -vn -sn -dn -f null /dev/null 2>&1 || true)"
  maxvol="$(printf '%s\n' "$ausgabe" \
            | grep -E '^\[Parsed_volumedetect' \
            | sed -n 's/.*max_volume:[[:space:]]*\(-\{0,1\}[0-9.]*\).*/\1/p' \
            | head -1)"
  [ -n "$maxvol" ] || { echo ""; return; }
  diff="$(python3 -c "
zielpegel = float('$ZIEL_MAXPEGEL')
datei = float('$maxvol')
d = zielpegel - datei
if not $LAUTER_MACHEN and d > 0.0:
    d = 0.0
print('%.1f' % d)
")"
  python3 -c "
d = float('$diff')
print('%.1f' % d if 0.1 < abs(d) < float('$grenze') else '')
"
}

protokoll() { echo "  $*"; }

# ffmpeg liest ohne Not von der Standardeingabe und wuerde in Schleifen, die
# selbst von stdin lesen, Zeichen der naechsten Zeile verschlucken. Die App
# startet ffmpeg ueber QProcess ohne verbundene Standardeingabe; genau das
# wird hier nachgebildet, ohne der Argumentliste ein -nostdin hinzuzufuegen,
# das die App nicht uebergibt.
ffmpeg_lauf()  { "$FFMPEG"  "$@" < /dev/null; }
ffprobe_lauf() { "$FFPROBE" "$@" < /dev/null; }

echo "ffmpeg-Verzeichnis: $FFDIR"
"$FFMPEG" -hide_banner -version < /dev/null | head -1

# ===========================================================================
# A1 · ffprobe: Metadaten und Dauer als JSON
#     audioinfothread.cpp:82-90, ausgeführt in Zeile 103
# ===========================================================================
echo "A1 ffprobe show_format (audioinfothread.cpp:82-90)"
for quelle in "$QUELLEN"/*; do
  name="$(basename "$quelle")"
  protokoll "$name"
  ffprobe_lauf -i "$quelle" -hide_banner -show_format -print_format json -v quiet \
    > "$ROH/A1-ffprobe-$name.json" 2>&1 || true

  # Die App liest ausschließlich format.tags.{title,album,comment}
  # und format.duration (audioinfothread.cpp:107-115).
  python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("JSON_UNLESBAR: %s" % e); sys.exit()
f = d.get("format", {})
t = f.get("tags", {})
print("title: %s"    % t.get("title", ""))
print("album: %s"    % t.get("album", ""))
print("comment: %s"  % t.get("comment", ""))
print("duration: %s" % f.get("duration", ""))
' "$ROH/A1-ffprobe-$name.json" > "$GEPARST/A1-$name.txt"
done

# ===========================================================================
# A2 · ffmpeg: Kapitel eines Hörbuchs ermitteln
#     audiobookconverter.cpp:59-63, ausgeführt in Zeile 64
#     Gelesen wird die Fehlerausgabe, nicht stdout.
# ===========================================================================
echo "A2 ffmpeg Kapitelermittlung (audiobookconverter.cpp:59-63)"
ffmpeg_lauf -i "$QUELLEN/kapitel.m4b" -hide_banner > "$ROH/A2-kapitel.txt" 2>&1 || true
normalisiere < "$ROH/A2-kapitel.txt" > "$ROH/A2-kapitel.normalisiert.txt"

# parseForChapters (audiobookconverter.cpp:160-232) nachgebildet:
# Abschnitt zwischen "Chapter #" und "Stream #", je Kapitel start/end/title.
python3 -c '
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
if "Chapter #" not in text:
    print("KEINE_KAPITEL_GEFUNDEN"); sys.exit()
rest = text.split("Chapter #", 1)[1]
rest = rest.split("Stream #", 1)[0]
for i, kap in enumerate(rest.split("Chapter #"), start=1):
    start = end = titel = ""
    metadata_gesehen = False
    for zeile in re.split(r"[\r\n]+", kap):
        zeile = zeile.strip()
        if "start" in zeile and "end" in zeile:
            start = zeile.split("start ", 1)[1].split(", end")[0].strip()
            end   = zeile.split(", end ", 1)[1].strip()
        elif zeile.startswith("Metadata:"):
            metadata_gesehen = True
        elif zeile.startswith("title") and metadata_gesehen:
            titel = zeile.split("title", 1)[1].split(":", 1)[1].strip()
    print("kapitel_%d_start: %s" % (i, start))
    print("kapitel_%d_end: %s"   % (i, end))
    print("kapitel_%d_title: %s" % (i, titel))
' "$ROH/A2-kapitel.txt" > "$GEPARST/A2-kapitel.txt"

# ===========================================================================
# A3 · ffmpeg: Kapitel in WAV schneiden
#     audiobookconverter.cpp:71-97, ausgeführt in Zeile 123
# ===========================================================================
echo "A3 ffmpeg Kapitelschnitt (audiobookconverter.cpp:71-97)"
KORR="$(volumenkorrektur "$QUELLEN/kapitel.m4b" 20)"
echo "volumenkorrektur_db: ${KORR:-keine}" > "$GEPARST/A3-parameter.txt"
k=0
while read -r start end titel; do
  [ -n "$start" ] || continue
  ausgabe="$TMP/A3-kapitel-$k.WAV"
  set -- -i "$QUELLEN/kapitel.m4b" -ss "$start" -to "$end" \
         -acodec pcm_s16le -ar 32k -ac 1 \
         -metadata "title=$titel" -y -hide_banner
  [ -n "$KORR" ] && set -- "$@" -af "volume=${KORR}dB"
  set -- "$@" "$ausgabe"
  protokoll "Kapitel $k: $start..$end"
  ffmpeg_lauf "$@" > "$ROH/A3-kapitel-$k.txt" 2>&1 || true
  normalisiere < "$ROH/A3-kapitel-$k.txt" > "$ROH/A3-kapitel-$k.normalisiert.txt"
  [ -f "$ausgabe" ] && messe "$ausgabe" "A3-kapitel-$k"
  k=$((k + 1))
done < <(python3 -c '
import sys
werte = {}
for zeile in open(sys.argv[1]):
    if ":" not in zeile: continue
    k, v = zeile.split(":", 1)
    werte[k.strip()] = v.strip()
i = 1
while "kapitel_%d_start" % i in werte:
    print(werte["kapitel_%d_start" % i], werte["kapitel_%d_end" % i],
          werte.get("kapitel_%d_title" % i, ""))
    i += 1
' "$GEPARST/A2-kapitel.txt")

# ===========================================================================
# A4/A9 · ffmpeg: volumedetect
#     audiobookconverter.cpp:250-266 (Zeile 270)
#     hoerbertprocessor.cpp:617-633 (Zeile 635) — identische Liste
# ===========================================================================
echo "A4 ffmpeg volumedetect (audiobookconverter.cpp:250-266)"
for quelle in "$QUELLEN"/master.wav "$QUELLEN"/leise.wav "$QUELLEN"/ton.mp3; do
  name="$(basename "$quelle")"
  protokoll "$name"
  ffmpeg_lauf -i "$quelle" -af volumedetect -vn -sn -dn -hide_banner -f null /dev/null \
    > "$ROH/A4-volumedetect-$name.txt" 2>&1 || true
  normalisiere < "$ROH/A4-volumedetect-$name.txt" > "$ROH/A4-volumedetect-$name.normalisiert.txt"

  # Die App liest nur max_volume aus Zeilen, die mit [Parsed_volumedetect
  # beginnen (hoerbertprocessor.cpp:636-650).
  grep -E '^\[Parsed_volumedetect' "$ROH/A4-volumedetect-$name.txt" \
    | sed -E 's/@ 0x[0-9a-f]+/@ 0xADRESSE/' \
    > "$GEPARST/A4-$name.txt" || true
done

# ===========================================================================
# A5 · ffmpeg: convertToWav — der Hauptpfad der App
#     hoerbertprocessor.cpp:350-381, ausgeführt in Zeile 383
# ===========================================================================
echo "A5 ffmpeg convertToWav (hoerbertprocessor.cpp:350-381)"
for quelle in "$QUELLEN"/ton.*; do
  name="$(basename "$quelle")"
  endung="${name##*.}"
  ausgabe="$TMP/A5-$endung.WAV"
  KORR="$(volumenkorrektur "$quelle" 30)"
  set -- -i "$quelle" -acodec pcm_s16le -ar 32k -ac 1 \
         -metadata "title=AA-1 Referenztitel" \
         -metadata "album=AA-1 Referenzalbum" \
         -metadata "comment=$name"
  [ -n "$KORR" ] && set -- "$@" -af "volume=${KORR}dB"
  set -- "$@" -y -hide_banner "$ausgabe"
  protokoll "$name (Korrektur: ${KORR:-keine})"
  echo "volumenkorrektur_db: ${KORR:-keine}" > "$GEPARST/A5-$endung-parameter.txt"
  ffmpeg_lauf "$@" > "$ROH/A5-$endung.txt" 2>&1 || true
  normalisiere < "$ROH/A5-$endung.txt" > "$ROH/A5-$endung.normalisiert.txt"
  [ -f "$ausgabe" ] && messe "$ausgabe" "A5-$endung"
done

# Die leise Datei getrennt, weil hier die Lautstärkekorrektur greift.
KORR="$(volumenkorrektur "$QUELLEN/leise.wav" 30)"
echo "volumenkorrektur_db: ${KORR:-keine}" > "$GEPARST/A5-leise-parameter.txt"
set -- -i "$QUELLEN/leise.wav" -acodec pcm_s16le -ar 32k -ac 1 \
       -metadata "title=AA-1 leise" -metadata "album=AA-1 Referenzalbum" \
       -metadata "comment=leise.wav"
[ -n "$KORR" ] && set -- "$@" -af "volume=${KORR}dB"
set -- "$@" -y -hide_banner "$TMP/A5-leise.WAV"
protokoll "leise.wav (Korrektur: ${KORR:-keine})"
ffmpeg_lauf "$@" > "$ROH/A5-leise.txt" 2>&1 || true
normalisiere < "$ROH/A5-leise.txt" > "$ROH/A5-leise.normalisiert.txt"
[ -f "$TMP/A5-leise.WAV" ] && messe "$TMP/A5-leise.WAV" "A5-leise"

# ===========================================================================
# A6 · ffmpeg: splitPer3Mins — Segmentierung in 180-Sekunden-Stücke
#     hoerbertprocessor.cpp:391-424, ausgeführt in Zeile 426
# ===========================================================================
echo "A6 ffmpeg splitPer3Mins (hoerbertprocessor.cpp:391-424)"
KORR="$(volumenkorrektur "$QUELLEN/stille-lang.flac" 30)"
echo "volumenkorrektur_db: ${KORR:-keine}" > "$GEPARST/A6-parameter.txt"
set -- -i "$QUELLEN/stille-lang.flac" -acodec pcm_s16le -ar 32k -ac 1 \
       -y -hide_banner \
       -metadata "title=AA-1 Segmenttitel" \
       -metadata "album=AA-1 Referenzalbum" \
       -metadata "comment=stille-lang.flac" \
       -f segment -segment_time 180
[ -n "$KORR" ] && set -- "$@" -af "volume=${KORR}dB"
set -- "$@" "$TMP/A6-7-%01d.WAV" -y
ffmpeg_lauf "$@" > "$ROH/A6-segment.txt" 2>&1 || true
normalisiere < "$ROH/A6-segment.txt" > "$ROH/A6-segment.normalisiert.txt"
for datei in "$TMP"/A6-7-*.WAV; do
  [ -f "$datei" ] || continue
  protokoll "$(basename "$datei")"
  messe "$datei" "A6-$(basename "$datei" .WAV)"
done
ls "$TMP"/A6-7-*.WAV 2>/dev/null | wc -l | tr -d ' ' \
  | sed 's/^/segmentanzahl: /' > "$GEPARST/A6-segmentanzahl.txt"

# ===========================================================================
# A7 · ffmpeg: silencedetect
#     hoerbertprocessor.cpp:434-451, ausgeführt in Zeile 452
#     Schwelle und Dauer aus hoerbertprocessor.cpp:49-50
# ===========================================================================
echo "A7 ffmpeg silencedetect (hoerbertprocessor.cpp:434-451)"
for quelle in "$QUELLEN"/stille-kurz.wav "$QUELLEN"/stille-lang.flac; do
  name="$(basename "$quelle")"
  protokoll "$name"
  ffmpeg_lauf -i "$quelle" -af "silencedetect=n=-40dB:d=0.1" -hide_banner -f null /dev/null \
    > "$ROH/A7-silencedetect-$name.txt" 2>&1 || true
  normalisiere < "$ROH/A7-silencedetect-$name.txt" > "$ROH/A7-silencedetect-$name.normalisiert.txt"

  # Die App sammelt Zeilen, die mit [silencedetect beginnen, und nimmt den
  # Teil nach der schließenden Klammer; zusätzlich die Duration-Zeile
  # (hoerbertprocessor.cpp:466-473).
  {
    grep -E '^\[silencedetect' "$ROH/A7-silencedetect-$name.txt" \
      | sed -E 's/^[^]]*\] *//' || true
    grep -E '^ *Duration:' "$ROH/A7-silencedetect-$name.txt" \
      | sed -E 's/^ *Duration: *([^,]*),.*/Duration: \1/' || true
  } > "$GEPARST/A7-$name.txt"
done

# ===========================================================================
# A8 · ffmpeg: splitOnSilence — der eigentliche Schnitt
#     hoerbertprocessor.cpp:479-571, ausgeführt in Zeile 572 und 592
#     Schneidet nur, wenn silence_start > 180 s liegt.
# ===========================================================================
echo "A8 ffmpeg splitOnSilence Schnitt (hoerbertprocessor.cpp:479-571)"
python3 -c '
import re, sys
# splitOnSilence nachgebildet (hoerbertprocessor.cpp:475-533)
zeilen = [z.strip() for z in open(sys.argv[1]) if z.strip()]
stille = [z for z in zeilen if z.startswith("silence_")]
dauer_zeile = [z for z in zeilen if z.startswith("Duration:")]
if not dauer_zeile:
    print("KEINE_DAUER"); sys.exit()
d = dauer_zeile[0].split("Duration:", 1)[1].strip()
h, m, s = d.split(":")
gesamt = float(h) * 3600 + float(m) * 60 + float(s)
segmentlaenge = 180.0
chunks = 0
grenzen = []
i = 0
while i < len(stille):
    if "silence_start:" not in stille[i]:
        break
    start = float(stille[i].split(":", 1)[1].strip())
    if start > segmentlaenge and i + 1 < len(stille):
        ende = float(stille[i+1].split("silence_end:", 1)[1].split("|")[0].strip())
        if gesamt - ende > 1:
            chunks += 1
            segmentlaenge = ende + segmentlaenge
            grenzen.append(ende)
    i += 2
print("gesamtlaenge: %.3f" % gesamt)
print("chunk_count: %d" % chunks)
for n, g in enumerate(grenzen):
    print("schnittgrenze_%d: %s" % (n, g))
' "$GEPARST/A7-stille-lang.flac.txt" > "$GEPARST/A8-schnittplan.txt"
cat "$GEPARST/A8-schnittplan.txt" | sed 's/^/  /'

GRENZE="$(sed -n 's/^schnittgrenze_0: //p' "$GEPARST/A8-schnittplan.txt")"
if [ -n "$GRENZE" ]; then
  KORR="$(volumenkorrektur "$QUELLEN/stille-lang.flac" 20)"
  echo "volumenkorrektur_db: ${KORR:-keine}" > "$GEPARST/A8-parameter.txt"
  set -- -i "$QUELLEN/stille-lang.flac" -ss 0 -to "$GRENZE" \
         -acodec pcm_s16le -ar 32k -ac 1 -y -hide_banner \
         -metadata "title=AA-1 Schnitt 1" \
         -metadata "album=AA-1 Referenzalbum" \
         -metadata "comment=stille-lang.flac"
  [ -n "$KORR" ] && set -- "$@" -af "volume=${KORR}dB"
  set -- "$@" "$TMP/A8-8-0.WAV"
  ffmpeg_lauf "$@" > "$ROH/A8-schnitt-0.txt" 2>&1 || true
  normalisiere < "$ROH/A8-schnitt-0.txt" > "$ROH/A8-schnitt-0.normalisiert.txt"
  [ -f "$TMP/A8-8-0.WAV" ] && messe "$TMP/A8-8-0.WAV" "A8-schnitt-0"
else
  echo "kein Schnitt moeglich" > "$GEPARST/A8-parameter.txt"
fi

# ===========================================================================
# A10 · ffmpeg: createSilenceWav — Stille-Eintrag auf der Karte
#      hoerbertprocessor.cpp:684-709, ausgeführt in Zeile 711
# ===========================================================================
echo "A10 ffmpeg createSilenceWav (hoerbertprocessor.cpp:684-709)"
ffmpeg_lauf -f lavfi -i "anullsrc=r=32000:cl=mono" -t 5 -acodec pcm_s16le -hide_banner \
  -metadata "title=AA-1 Stille" -metadata "album=AA-1 Referenzalbum" \
  -metadata "comment=synthetisch" "$TMP/A10-stille.WAV" -y \
  > "$ROH/A10-stille.txt" 2>&1 || true
normalisiere < "$ROH/A10-stille.txt" > "$ROH/A10-stille.normalisiert.txt"
[ -f "$TMP/A10-stille.WAV" ] && messe "$TMP/A10-stille.WAV" "A10-stille"

# ===========================================================================
# A11 · ffmpeg: changeMetaData — Metadaten ohne Neukodierung ändern
#      hoerbertprocessor.cpp:718-741, ausgeführt in Zeile 743
# ===========================================================================
echo "A11 ffmpeg changeMetaData (hoerbertprocessor.cpp:718-741)"
cp "$TMP/A5-wav.WAV" "$TMP/A11-eingang.WAV"
ffmpeg_lauf -i "$TMP/A11-eingang.WAV" -hide_banner \
  -metadata "title=AA-1 geaenderter Titel" \
  -metadata "album=AA-1 geaendertes Album" \
  -metadata "comment=AA-1 geaenderter Kommentar" \
  -codec copy "$TMP/A11-temp.WAV" -y \
  > "$ROH/A11-metadaten.txt" 2>&1 || true
normalisiere < "$ROH/A11-metadaten.txt" > "$ROH/A11-metadaten.normalisiert.txt"
[ -f "$TMP/A11-temp.WAV" ] && messe "$TMP/A11-temp.WAV" "A11-temp"

# ===========================================================================
# A12 · ffmpeg: WAV -> FLAC für das Backup
#      backupmanager.cpp:386-394, ausgeführt in Zeile 395
# ===========================================================================
echo "A12 ffmpeg convertWav2Flac (backupmanager.cpp:386-394)"
ffmpeg_lauf -i "$TMP/A5-wav.WAV" -c:a flac -y -hide_banner "$TMP/A12-backup.flac" \
  > "$ROH/A12-wav2flac.txt" 2>&1 || true
normalisiere < "$ROH/A12-wav2flac.txt" > "$ROH/A12-wav2flac.normalisiert.txt"
[ -f "$TMP/A12-backup.flac" ] && messe "$TMP/A12-backup.flac" "A12-backup"

# ===========================================================================
# A13 · ffmpeg: FLAC -> WAV beim Zurückspielen
#      backupmanager.cpp:404-411, ausgeführt in Zeile 412
# ===========================================================================
echo "A13 ffmpeg convertFlac2Wav (backupmanager.cpp:404-411)"
ffmpeg_lauf -i "$TMP/A12-backup.flac" -y -hide_banner -v quiet "$TMP/A13-restore.WAV" \
  > "$ROH/A13-flac2wav.txt" 2>&1 || true
normalisiere < "$ROH/A13-flac2wav.txt" > "$ROH/A13-flac2wav.normalisiert.txt"
[ -f "$TMP/A13-restore.WAV" ] && messe "$TMP/A13-restore.WAV" "A13-restore"

# ---------------------------------------------------------------------------
echo "fertig. Ausgaben in $ZIEL"
