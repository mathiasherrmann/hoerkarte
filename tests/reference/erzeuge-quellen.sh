#!/bin/bash
# Erzeugt die synthetischen Testdateien für AA-1.
#
# Es wird ausschließlich synthetisches Material verwendet (sine/anullsrc),
# kein Fremdmaterial und kein urheberrechtlich geschützter Inhalt.
# Alle Dateien werden mit dem ffmpeg erzeugt, das als Parameter übergeben wird;
# in AA-1 ist das das alte x86_64-Binary aus dem Repository.
#
# Aufruf:  erzeuge-quellen.sh <pfad-zum-ffmpeg-verzeichnis> <zielverzeichnis>
set -eu

FFDIR="${1:?ffmpeg-Verzeichnis fehlt}"
OUT="${2:?Zielverzeichnis fehlt}"
FFMPEG="$FFDIR/ffmpeg"
mkdir -p "$OUT"
cd "$OUT"

G="-hide_banner -nostdin -y -loglevel error"

# ---------------------------------------------------------------------------
# 1. Mastersignal: 6 s, 44100 Hz, stereo, drei unterscheidbare Tonstufen.
#    Absichtlich NICHT 32 kHz mono, damit die Umwandlung der App
#    (Resampling 44100->32000 und Downmix stereo->mono) wirklich arbeitet.
# ---------------------------------------------------------------------------
$FFMPEG $G -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=2" \
           -f lavfi -i "sine=frequency=880:sample_rate=44100:duration=2" \
           -f lavfi -i "sine=frequency=1320:sample_rate=44100:duration=2" \
  -filter_complex "[0:a][1:a][2:a]concat=n=3:v=0:a=1[m];[m]aformat=channel_layouts=stereo[out]" \
  -map "[out]" -c:a pcm_s16le master.wav

# ---------------------------------------------------------------------------
# 2. Formatfächer aus dem Mastersignal. Je ein Container pro von der App
#    laut SUPPORTED_FILES (define.h:53) akzeptiertem Format.
# ---------------------------------------------------------------------------
$FFMPEG $G -i master.wav -c:a pcm_s16le                     ton.wav
$FFMPEG $G -i master.wav -c:a libmp3lame -b:a 192k          ton.mp3
$FFMPEG $G -i master.wav -c:a aac        -b:a 192k          ton.m4a
$FFMPEG $G -i master.wav -c:a libvorbis  -q:a 5             ton.ogg
$FFMPEG $G -i master.wav -c:a flac                          ton.flac
$FFMPEG $G -i master.wav -c:a wmav2      -b:a 192k          ton.wma
$FFMPEG $G -i master.wav -c:a pcm_s16be                     ton.aiff

# ---------------------------------------------------------------------------
# 3. Hörbuch mit Kapiteln als .m4b. Die Kapitelmarken kommen aus einer
#    ffmetadata-Datei; drei Kapitel entsprechen den drei Tonstufen.
#    Diese Datei ist der Prüffall für AudioBookConverter::parseForChapters.
# ---------------------------------------------------------------------------
cat > kapitel.ffmetadata <<'META'
;FFMETADATA1
title=Synthetisches Testhoerbuch
album=AA-1 Referenz
[CHAPTER]
TIMEBASE=1/1000
START=0
END=2000
title=Kapitel Eins
[CHAPTER]
TIMEBASE=1/1000
START=2000
END=4000
title=Kapitel Zwei
[CHAPTER]
TIMEBASE=1/1000
START=4000
END=6000
title=Kapitel Drei
META
$FFMPEG $G -i master.wav -i kapitel.ffmetadata -map_metadata 1 \
  -c:a aac -b:a 192k -f ipod kapitel.m4b

# ---------------------------------------------------------------------------
# 4. Kurze Datei mit klaren Stillephasen: Ton 3 s / Stille 2 s / Ton 3 s /
#    Stille 2 s / Ton 3 s. Dient dem Nachweis des Ausgabeformats von
#    silencedetect (Schwelle -40dB, Mindestdauer 0,1 s laut
#    hoerbertprocessor.cpp:49-50).
# ---------------------------------------------------------------------------
$FFMPEG $G \
  -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=3" \
  -f lavfi -t 2 -i "anullsrc=r=44100:cl=stereo" \
  -f lavfi -i "sine=frequency=880:sample_rate=44100:duration=3" \
  -f lavfi -t 2 -i "anullsrc=r=44100:cl=stereo" \
  -f lavfi -i "sine=frequency=1320:sample_rate=44100:duration=3" \
  -filter_complex "[0:a]aformat=channel_layouts=stereo[a0];[2:a]aformat=channel_layouts=stereo[a2];[4:a]aformat=channel_layouts=stereo[a4];[a0][1:a][a2][3:a][a4]concat=n=5:v=0:a=1[out]" \
  -map "[out]" -c:a pcm_s16le stille-kurz.wav

# ---------------------------------------------------------------------------
# 5. Lange Datei mit Stillephasen JENSEITS der 180-Sekunden-Schwelle.
#    HoerbertProcessor::splitOnSilence schneidet nur, wenn
#    silence_start > m_splitOnSilenceSegmentLength (180 s) ist
#    (hoerbertprocessor.cpp:505). Eine kurze Datei durchläuft den
#    Schneidepfad daher NIE. Aufbau:
#      Ton 200 s | Stille 3 s | Ton 185 s | Stille 3 s | Ton 20 s
#    Damit gilt: silence_start1=200 > 180, danach segment_length=383,
#    silence_start2=388 > 383, Restlänge nach der zweiten Stille 20 s > 1.
#    Erwartet werden also zwei Schnitte, chunk_count=2.
#    Ablage als FLAC statt WAV: verlustfrei, PCM bit-identisch, 4,5 MB statt
#    72 MB. .flac ist in define.h:53 unter SUPPORTED_FILES aufgefuehrt.
# ---------------------------------------------------------------------------
$FFMPEG $G \
  -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=200" \
  -f lavfi -t 3 -i "anullsrc=r=44100:cl=stereo" \
  -f lavfi -i "sine=frequency=880:sample_rate=44100:duration=185" \
  -f lavfi -t 3 -i "anullsrc=r=44100:cl=stereo" \
  -f lavfi -i "sine=frequency=1320:sample_rate=44100:duration=20" \
  -filter_complex "[0:a]aformat=channel_layouts=stereo[a0];[2:a]aformat=channel_layouts=stereo[a2];[4:a]aformat=channel_layouts=stereo[a4];[a0][1:a][a2][3:a][a4]concat=n=5:v=0:a=1[out]" \
  -map "[out]" -c:a flac stille-lang.flac

# ---------------------------------------------------------------------------
# 6. Sehr leise Datei: Mastersignal um 30 dB abgesenkt. Prüffall für
#    getVolumeDifference / volumedetect und die daraus folgende
#    volume=NdB-Korrektur.
# ---------------------------------------------------------------------------
$FFMPEG $G -i master.wav -af "volume=-30dB" -c:a pcm_s16le leise.wav

rm -f kapitel.ffmetadata
echo "Testdateien erzeugt in $OUT"
