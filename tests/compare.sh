#!/bin/bash
# Vergleicht einen ffmpeg-Satz gegen die in AA-1 erhobene Referenz.
#
# Aufruf:  compare.sh <ffmpeg-verzeichnis> [<referenz-verzeichnis>]
#
# Einstufung der Abweichungen, abgeleitet aus der Vorgabe von AA-1:
#
#   FEHLER  · von der App geparste Zeilen (silencedetect, volumedetect,
#             Duration, Kapitel, ffprobe-JSON-Felder)
#           · Audioformat: Codec, Abtastrate, Kanalzahl, Bittiefe, Dauer
#           · Chunk-Reihenfolge und Größe des data-Chunks
#           · Metadaten title, album, comment
#
#   HINWEIS · Prüfsumme über die reinen PCM-Daten. Ein anderer Encoder darf
#             bitweise abweichen, solange Format und Struktur stimmen.
#           · Länge des LIST/INFO-Chunks, Dateigröße, Bitrate und die daraus
#             folgenden Chunk-Offsets. Diese Werte hängen an der Länge der
#             Zeichenkette, die ffmpeg als encoder-Tag schreibt
#             ("Lavf58.27.100"), und ändern sich mit jeder Version, ohne dass
#             sich am Audioinhalt etwas ändert.
#           · das encoder-Tag selbst.
#
# Die Einstufung ist bewusst sichtbar gehalten: Wer sie anders braucht,
# ändert die Listen FEHLERFELDER und HINWEISFELDER unten.
set -u

FFDIR="${1:?Aufruf: compare.sh <ffmpeg-verzeichnis> [<referenz-verzeichnis>]}"
HIER="$(cd "$(dirname "$0")" && pwd)"
REFERENZ="${2:-$HIER/reference}"
ERWARTET="$REFERENZ/erwartet"
QUELLEN="$REFERENZ/quellen"

[ -d "$ERWARTET" ] || { echo "Referenz fehlt: $ERWARTET" >&2; exit 2; }
[ -d "$QUELLEN" ]  || { echo "Quellen fehlen: $QUELLEN" >&2; exit 2; }

IST="$(mktemp -d "${TMPDIR:-/tmp}/aa1-vergleich.XXXXXX")"
aufraeumen() { rm -rf "$IST"; }
trap aufraeumen EXIT

echo "Referenz: $ERWARTET"
echo "Prüfling: $FFDIR"
echo

"$HIER/lauf.sh" "$FFDIR" "$QUELLEN" "$IST" > "$IST/lauf.log" 2>&1
LAUF_CODE=$?
if [ $LAUF_CODE -ne 0 ]; then
  echo "FEHLER: lauf.sh brach mit Code $LAUF_CODE ab. Protokoll:"
  tail -30 "$IST/lauf.log" | sed 's/^/    /'
  exit 1
fi

FEHLER=0
HINWEISE=0

melde_fehler()  { echo "FEHLER  $*";  FEHLER=$((FEHLER + 1)); }
melde_hinweis() { echo "HINWEIS $*"; HINWEISE=$((HINWEISE + 1)); }

# Felder der Messwertdateien, die hart verglichen werden.
FEHLERFELDER='^(format_format_name|format_duration|format_nb_streams|tag_title|tag_album|tag_comment|stream_codec_name|stream_sample_fmt|stream_sample_rate|stream_channels|stream_channel_layout|stream_bits_per_sample|stream_duration|container|form|chunk_anzahl|fmt_codec_tag|fmt_kanaele|fmt_abtastrate|fmt_byte_pro_sekunde|fmt_blockausrichtung|fmt_bittiefe|fmt_fmt_chunk_groesse|data_bytes|dauer_aus_data_sekunden|chunkstruktur):'
# Felder, deren Abweichung nur gemeldet wird.
HINWEISFELDER='^(tag_encoder|datei_bytes|format_size|format_bit_rate|header_bytes_vor_data):'

# Nur die Chunk-IDs in Reihenfolge, ohne Offsets und Größen.
chunkfolge() { grep '^chunk: ' "$1" 2>/dev/null | awk '{printf "%s ", $2}'; echo; }

# ---------------------------------------------------------------------------
# 1. Von der App geparste Zeilen — jede Abweichung ist ein Fehler.
# ---------------------------------------------------------------------------
echo "--- geparste Zeilen ---"
for ref in "$ERWARTET"/geparst/*; do
  name="$(basename "$ref")"
  ist="$IST/geparst/$name"
  if [ ! -f "$ist" ]; then
    melde_fehler "geparst/$name fehlt beim Prüfling"
    continue
  fi
  if ! diff -q "$ref" "$ist" > /dev/null; then
    melde_fehler "geparst/$name weicht ab:"
    diff -u "$ref" "$ist" | sed -n '3,$p' | sed 's/^/        /'
  fi
done
for ist in "$IST"/geparst/*; do
  name="$(basename "$ist")"
  [ -f "$ERWARTET/geparst/$name" ] || melde_fehler "geparst/$name ist beim Prüfling neu"
done

# ---------------------------------------------------------------------------
# 2. Erzeugte Audiodateien: Format, Struktur, Metadaten.
# ---------------------------------------------------------------------------
echo "--- Format, Chunk-Struktur, Metadaten ---"
for ref in "$ERWARTET"/erzeugte-wavs/*.messwerte.txt; do
  name="$(basename "$ref")"
  ist="$IST/erzeugte-wavs/$name"
  if [ ! -f "$ist" ]; then
    melde_fehler "erzeugte-wavs/$name fehlt beim Prüfling"
    continue
  fi

  if ! diff -q <(grep -E "$FEHLERFELDER" "$ref") <(grep -E "$FEHLERFELDER" "$ist") > /dev/null; then
    melde_fehler "$name: Format oder Metadaten weichen ab:"
    diff -u <(grep -E "$FEHLERFELDER" "$ref") <(grep -E "$FEHLERFELDER" "$ist") \
      | sed -n '3,$p' | sed 's/^/        /'
  fi

  if [ "$(chunkfolge "$ref")" != "$(chunkfolge "$ist")" ]; then
    melde_fehler "$name: Chunk-Reihenfolge weicht ab:"
    echo "        Referenz: $(chunkfolge "$ref")"
    echo "        Prüfling: $(chunkfolge "$ist")"
  fi

  if ! diff -q <(grep -E "$HINWEISFELDER" "$ref") <(grep -E "$HINWEISFELDER" "$ist") > /dev/null; then
    melde_hinweis "$name: Dateigröße oder encoder-Tag weicht ab (Länge der encoder-Zeichenkette):"
    diff -u <(grep -E "$HINWEISFELDER" "$ref") <(grep -E "$HINWEISFELDER" "$ist") \
      | sed -n '3,$p' | sed 's/^/        /'
  fi
done

# ---------------------------------------------------------------------------
# 3. PCM-Prüfsummen — Abweichung ist laut Vorgabe nur ein Hinweis.
# ---------------------------------------------------------------------------
echo "--- PCM-Prüfsummen ---"
for ref in "$ERWARTET"/erzeugte-wavs/*.pcm-sha256.txt; do
  name="$(basename "$ref")"
  ist="$IST/erzeugte-wavs/$name"
  if [ ! -f "$ist" ]; then
    melde_fehler "erzeugte-wavs/$name fehlt beim Prüfling"
    continue
  fi
  if ! diff -q "$ref" "$ist" > /dev/null; then
    melde_hinweis "${name%.pcm-sha256.txt}: PCM-Daten unterscheiden sich"
    echo "        Referenz: $(cat "$ref")"
    echo "        Prüfling: $(cat "$ist")"
  fi
done

# ---------------------------------------------------------------------------
# 4. Rohausgaben — rein informativ, Banner und Versionszeilen ändern sich
#    zwangsläufig. Es wird nur gezählt, nicht bewertet.
# ---------------------------------------------------------------------------
echo "--- Rohausgaben (informativ) ---"
abweichend=0
for ref in "$ERWARTET"/rohausgaben/*.normalisiert.txt; do
  name="$(basename "$ref")"
  ist="$IST/rohausgaben/$name"
  [ -f "$ist" ] || continue
  diff -q "$ref" "$ist" > /dev/null || abweichend=$((abweichend + 1))
done
echo "        $abweichend von $(ls "$ERWARTET"/rohausgaben/*.normalisiert.txt 2>/dev/null | wc -l | tr -d ' ') normalisierten Rohausgaben unterscheiden sich"

# ---------------------------------------------------------------------------
echo
echo "========================================"
echo "Fehler:   $FEHLER"
echo "Hinweise: $HINWEISE"
echo "========================================"
if [ "$FEHLER" -gt 0 ]; then
  echo "Ergebnis: NICHT BESTANDEN"
  exit 1
fi
echo "Ergebnis: bestanden"
[ "$HINWEISE" -gt 0 ] && echo "Jeder Hinweis ist vor der Abnahme einzeln zu erklären."
exit 0
