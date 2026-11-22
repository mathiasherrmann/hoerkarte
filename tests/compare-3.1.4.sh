#!/bin/bash
# Vergleicht einen ffmpeg-Satz gegen die 3.1.4-Referenz, ueber alle vier
# Varianten (zwei Modellzweige mal zwei Lautstaerke-Einstellungen).
#
# Einstufung wie in compare.sh: geparste Zeilen, Rueckgabecodes sowie Format,
# Kanaele, Abtastrate, Dauer und Tags der erzeugten Dateien sind Fehlerklasse.
# Die Pruefsumme der Datei selbst und die der PCM-Daten sind Hinweis, weil ein
# anderer Encoder bitweise abweichen darf.
set -u

FFDIR="${1:?Aufruf: compare-3.1.4.sh <ffmpeg-verzeichnis>}"
HIER="$(cd "$(dirname "$0")" && pwd)"
REF="$HIER/reference-3.1.4"
QUELLEN="$HIER/reference/quellen"
[ -d "$REF" ] || { echo "Referenz fehlt: $REF" >&2; exit 2; }

IST="$(mktemp -d "${TMPDIR:-/tmp}/aa1c.XXXXXX")"
trap 'rm -rf "$IST"' EXIT

echo "Referenz: $REF"
echo "Prüfling: $FFDIR"
echo

AUDIO_ZIEL="$IST/audio" "$HIER/lauf-3.1.4.sh" "$FFDIR" "$QUELLEN" "$IST/ref" > "$IST/lauf.log" 2>&1
if [ $? -ne 0 ]; then
  echo "FEHLER: lauf-3.1.4.sh brach ab:"; tail -20 "$IST/lauf.log" | sed 's/^/    /'; exit 1
fi

FEHLER=0; HINWEISE=0
melde_fehler()  { echo "FEHLER  $*";  FEHLER=$((FEHLER+1)); }
melde_hinweis() { echo "HINWEIS $*"; HINWEISE=$((HINWEISE+1)); }

HART='^(format_format_name|format_duration|format_nb_streams|tag_title|tag_album|tag_comment|stream_codec_name|stream_sample_fmt|stream_sample_rate|stream_channels|stream_channel_layout|stream_bits_per_sample|stream_duration):'
WEICH='^(format_size|format_bit_rate|stream_bit_rate|tag_encoder):'

for v in "$REF"/modell-*; do
  variante="$(basename "$v")"
  echo "--- $variante ---"

  for ref in "$v"/geparst/*; do
    n="$(basename "$ref")"; ist="$IST/ref/$variante/geparst/$n"
    [ -f "$ist" ] || { melde_fehler "$variante/geparst/$n fehlt"; continue; }
    diff -q "$ref" "$ist" > /dev/null || {
      melde_fehler "$variante/geparst/$n weicht ab:"
      diff -u "$ref" "$ist" | sed -n '3,$p' | sed 's/^/        /'; }
  done

  for ref in "$v"/erzeugte-dateien/*.messwerte.txt; do
    n="$(basename "$ref")"; ist="$IST/ref/$variante/erzeugte-dateien/$n"
    [ -f "$ist" ] || { melde_fehler "$variante/$n fehlt"; continue; }
    diff -q <(grep -E "$HART" "$ref") <(grep -E "$HART" "$ist") > /dev/null || {
      melde_fehler "$variante/$n: Format oder Tags weichen ab:"
      diff -u <(grep -E "$HART" "$ref") <(grep -E "$HART" "$ist") | sed -n '3,$p' | sed 's/^/        /'; }
    diff -q <(grep -E "$WEICH" "$ref") <(grep -E "$WEICH" "$ist") > /dev/null || \
      melde_hinweis "$variante/$n: Groesse oder Bitrate weicht ab"
  done

  for art in datei-sha256 pcm-sha256; do
    abw=0
    for ref in "$v"/erzeugte-dateien/*."$art".txt; do
      n="$(basename "$ref")"; ist="$IST/ref/$variante/erzeugte-dateien/$n"
      [ -f "$ist" ] || continue
      diff -q "$ref" "$ist" > /dev/null || abw=$((abw+1))
    done
    [ "$abw" -gt 0 ] && melde_hinweis "$variante: $abw $art-Pruefsummen unterscheiden sich"
  done

  abwroh=0
  for ref in "$v"/rohausgaben/*.normalisiert.txt; do
    n="$(basename "$ref")"; ist="$IST/ref/$variante/rohausgaben/$n"
    [ -f "$ist" ] || continue
    diff -q "$ref" "$ist" > /dev/null || abwroh=$((abwroh+1))
  done
  echo "        $abwroh normalisierte Rohausgaben unterscheiden sich"
done

# --- Fehlerfaelle des MP3-Wegs ---------------------------------------------
echo "--- Fehlerfälle MP3-Weg ---"
if [ ! -d "$REF/fehlerfaelle/hart" ]; then
  melde_hinweis "keine Fehlerfall-Referenz — Abschnitt übersprungen"
else
  "$HIER/lauf-fehlerfaelle-3.1.4.sh" "$FFDIR" "$QUELLEN" "$IST/fehler" > "$IST/fehler.log" 2>&1
  if [ $? -ne 0 ]; then
    melde_fehler "lauf-fehlerfaelle-3.1.4.sh brach ab:"
    tail -15 "$IST/fehler.log" | sed 's/^/        /'
  else
    for ref in "$REF"/fehlerfaelle/hart/*; do
      n="$(basename "$ref")"; ist="$IST/fehler/hart/$n"
      [ -f "$ist" ] || { melde_fehler "fehlerfaelle/hart/$n fehlt"; continue; }
      diff -q "$ref" "$ist" > /dev/null || {
        melde_fehler "fehlerfaelle/hart/$n weicht ab:"
        diff -u "$ref" "$ist" | sed -n '3,$p' | sed 's/^/        /'; }
    done
    for ist in "$IST"/fehler/hart/*; do
      n="$(basename "$ist")"
      [ -f "$REF/fehlerfaelle/hart/$n" ] || melde_fehler "fehlerfaelle/hart/$n ist neu"
    done
    ai=0
    for ref in "$REF"/fehlerfaelle/informativ/*; do
      n="$(basename "$ref")"; ist="$IST/fehler/informativ/$n"
      [ -f "$ist" ] || continue
      diff -q "$ref" "$ist" > /dev/null || ai=$((ai+1))
    done
    echo "        $ai informative Fehlerfall-Dateien unterscheiden sich"
  fi
fi

echo
echo "========================================"
echo "Fehler:   $FEHLER"
echo "Hinweise: $HINWEISE"
echo "========================================"
[ "$FEHLER" -gt 0 ] && { echo "Ergebnis: NICHT BESTANDEN"; exit 1; }
echo "Ergebnis: bestanden"
exit 0
