#!/bin/bash
# Erhebt, wie sich die ffmpeg-Aufrufe der App bei fehlerhaften Eingaben
# verhalten: Rückgabecode und die Zeilen, die die App daraus liest.
#
# Warum das eine eigene Erhebung braucht: Die App prüft Fehler auf drei
# verschiedene Weisen, und nur eine davon ist der Rückgabecode.
#
#   * A5, A6, A10, A11, A12, A13 prüfen `output.first==0`, also den Code.
#   * A3 ignoriert den Code und sucht in den letzten 300 Zeichen der Ausgabe
#     nach "Error" oder "Invalid" (audiobookconverter.cpp:125-127).
#   * A1 prüft weder Code noch Text, sondern verwirft die Datei, wenn
#     format.duration kleiner oder gleich 0 ist (audioinfothread.cpp:118).
#   * A7 bricht ab, wenn der Code ungleich 0 ist (hoerbertprocessor.cpp:456).
#
# Ändert ein neues ffmpeg den Rückgabecode oder den Wortlaut dieser Meldungen,
# verschiebt sich das Fehlerverhalten der App, ohne dass ein Erfolgsfall
# auffällig würde. Nach dem Wegfall von Rosetta ist diese Erhebung nicht mehr
# nachholbar.
#
# Aufruf: lauf-fehlerfaelle.sh <ffmpeg-verzeichnis> <quellen> <ziel>
set -u

FFDIR="${1:?ffmpeg-Verzeichnis fehlt}"
QUELLEN="${2:?Quellen fehlen}"
ZIEL="${3:?Ziel fehlt}"
FFMPEG="$FFDIR/ffmpeg"
FFPROBE="$FFDIR/ffprobe"

mkdir -p "$ZIEL"
SCHLECHT="$ZIEL/schlechte-eingaben"
mkdir -p "$SCHLECHT"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aa1b.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Fehlerhafte Eingaben anlegen. Bewusst klein und im Repository ablegbar.
# ---------------------------------------------------------------------------
: > "$SCHLECHT/leer.mp3"                                   # 0 Byte
printf 'Dies ist kein Audio, sondern Text.\n' > "$SCHLECHT/text.mp3"
head -c 1000 "$QUELLEN/ton.mp3" > "$SCHLECHT/abgeschnitten.mp3"
head -c 200  "$QUELLEN/ton.wav" > "$SCHLECHT/kopf-ohne-daten.wav"
# existiert absichtlich nicht:
FEHLT="$SCHLECHT/gibt-es-nicht.mp3"
rm -f "$FEHLT"

EINGABEN=("$SCHLECHT/leer.mp3" "$SCHLECHT/text.mp3" \
          "$SCHLECHT/abgeschnitten.mp3" "$SCHLECHT/kopf-ohne-daten.wav" "$FEHLT")

normalisiere() {
  sed -E -e 's/@ 0x[0-9a-f]+/@ 0xADRESSE/g' \
         -e 's#'"$SCHLECHT"'#<SCHLECHT>#g' \
         -e 's#'"$QUELLEN"'#<QUELLEN>#g' \
         -e 's#'"$TMP"'#<TMP>#g'
}

bericht="$ZIEL/FEHLERFAELLE.md"
{
echo "# Rückgabecodes und Fehlerverhalten des alten ffmpeg"
echo
echo "Erhoben am $(date '+%Y-%m-%d %H:%M %Z') mit"
"$FFMPEG" -hide_banner -version < /dev/null | head -1 | sed 's/^/`/; s/$/`/'
echo "auf arm64 unter Rosetta 2, macOS $(sw_vers -productVersion)."
echo
echo "Die Spalte \"Code\" ist der Rückgabecode des Prozesses. Die Spalte"
echo "\"App-Folge\" nennt, was die Anwendung daraus macht — siehe die"
echo "Erläuterung im Kopf von \`tests/lauf-fehlerfaelle.sh\`."
echo
} > "$bericht"

# ---------------------------------------------------------------------------
# A1 · ffprobe
# ---------------------------------------------------------------------------
{
echo "## A1 · ffprobe, Metadaten und Dauer"
echo
echo "Argumentliste: \`audioinfothread.cpp:82-90\`. Die App verwirft eine Datei,"
echo "wenn \`format.duration\` fehlt oder nicht größer als 0 ist."
echo
echo '| Eingabe | Code | format.duration | App-Folge |'
echo '|---|---|---|---|'
} >> "$bericht"

for e in "${EINGABEN[@]}"; do
  n="$(basename "$e")"
  aus="$("$FFPROBE" -i "$e" -hide_banner -show_format -print_format json -v quiet < /dev/null 2>&1)"
  code=$?
  printf '%s\n' "$aus" | normalisiere > "$ZIEL/A1-$n.json"
  dauer="$(printf '%s' "$aus" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("format",{}).get("duration","(fehlt)"))
except Exception:
    print("(kein JSON)")
')"
  folge="übersprungen"
  python3 -c "
import sys
w='''$dauer'''.strip()
try:
    sys.exit(0 if float(w)>0 else 1)
except ValueError:
    sys.exit(1)" && folge="in Liste aufgenommen"
  echo "| \`$n\` | $code | \`$dauer\` | $folge |" >> "$bericht"
done

# ---------------------------------------------------------------------------
# A2 · Kapitelermittlung
# ---------------------------------------------------------------------------
{
echo
echo "## A2 · ffmpeg, Kapitelermittlung"
echo
echo "Argumentliste: \`audiobookconverter.cpp:59-63\`. Findet \`parseForChapters\`"
echo "keinen Abschnitt \`Chapter #\`, läuft die Schleife über eine leere Liste —"
echo "es wird kein Fehler gemeldet, es entsteht nur keine Ausgabedatei."
echo
echo '| Eingabe | Code | enthält "Chapter #" | letzte Ausgabezeile |'
echo '|---|---|---|---|'
} >> "$bericht"

for e in "${EINGABEN[@]}"; do
  n="$(basename "$e")"
  aus="$("$FFMPEG" -i "$e" -hide_banner < /dev/null 2>&1)"
  code=$?
  printf '%s\n' "$aus" | normalisiere > "$ZIEL/A2-$n.txt"
  kap="nein"; printf '%s' "$aus" | grep -q 'Chapter #' && kap="ja"
  letzte="$(printf '%s\n' "$aus" | normalisiere | grep -v '^$' | tail -1 | cut -c1-70)"
  echo "| \`$n\` | $code | $kap | \`$letzte\` |" >> "$bericht"
done

# ---------------------------------------------------------------------------
# A4 · volumedetect
# ---------------------------------------------------------------------------
{
echo
echo "## A4 · ffmpeg, volumedetect"
echo
echo "Argumentliste: \`hoerbertprocessor.cpp:617-633\`. Bei einem Code ungleich 0"
echo "verlässt \`getVolumeDifference\` die Funktion mit \`return false\` — in einer"
echo "Funktion mit Rückgabetyp \`double\`, was 0.0 ergibt und damit \"keine"
echo "Korrektur\" bedeutet (siehe B12 in \`AUFRUFE.md\`)."
echo
echo '| Eingabe | Code | max_volume gefunden | App-Folge |'
echo '|---|---|---|---|'
} >> "$bericht"

for e in "${EINGABEN[@]}"; do
  n="$(basename "$e")"
  aus="$("$FFMPEG" -i "$e" -af volumedetect -vn -sn -dn -hide_banner -f null /dev/null < /dev/null 2>&1)"
  code=$?
  printf '%s\n' "$aus" | normalisiere > "$ZIEL/A4-$n.txt"
  mv_="nein"; printf '%s' "$aus" | grep -q 'max_volume:' && mv_="ja"
  folge="keine Korrektur (0.0)"
  [ "$code" -eq 0 ] && [ "$mv_" = "ja" ] && folge="Korrektur berechnet"
  echo "| \`$n\` | $code | $mv_ | $folge |" >> "$bericht"
done

# ---------------------------------------------------------------------------
# A5 · convertToWav
# ---------------------------------------------------------------------------
{
echo
echo "## A5 · ffmpeg, convertToWav"
echo
echo "Argumentliste: \`hoerbertprocessor.cpp:350-381\`. Rückgabe ist"
echo "\`output.first==0\`; ein Code ungleich 0 zählt als fehlgeschlagener Eintrag."
echo
echo '| Eingabe | Code | Ausgabedatei entstanden | Bytes | App-Folge |'
echo '|---|---|---|---|---|'
} >> "$bericht"

for e in "${EINGABEN[@]}"; do
  n="$(basename "$e")"
  ziel="$TMP/A5-$n.WAV"
  rm -f "$ziel"
  aus="$("$FFMPEG" -i "$e" -acodec pcm_s16le -ar 32k -ac 1 \
          -metadata "title=AA-1b" -metadata "album=AA-1b" -metadata "comment=$n" \
          -y -hide_banner "$ziel" < /dev/null 2>&1)"
  code=$?
  printf '%s\n' "$aus" | normalisiere > "$ZIEL/A5-$n.txt"
  if [ -f "$ziel" ]; then da="ja"; by="$(stat -f%z "$ziel")"; else da="nein"; by="-"; fi
  folge="FAILURE gezählt"; [ "$code" -eq 0 ] && folge="als Erfolg gewertet"
  echo "| \`$n\` | $code | $da | $by | $folge |" >> "$bericht"
done

# ---------------------------------------------------------------------------
# A7 · silencedetect
# ---------------------------------------------------------------------------
{
echo
echo "## A7 · ffmpeg, silencedetect"
echo
echo "Argumentliste: \`hoerbertprocessor.cpp:434-451\`. Bei Code ungleich 0 meldet"
echo "die App \`Failed to execute ffmpeg command\` und bricht den Schnitt ab"
echo "(\`hoerbertprocessor.cpp:454-459\`)."
echo
echo '| Eingabe | Code | silencedetect-Zeilen | Duration-Zeile |'
echo '|---|---|---|---|'
} >> "$bericht"

for e in "${EINGABEN[@]}"; do
  n="$(basename "$e")"
  aus="$("$FFMPEG" -i "$e" -af "silencedetect=n=-40dB:d=0.1" -hide_banner -f null /dev/null < /dev/null 2>&1)"
  code=$?
  printf '%s\n' "$aus" | normalisiere > "$ZIEL/A7-$n.txt"
  anz="$(printf '%s\n' "$aus" | grep -c '^\[silencedetect')"
  dur="nein"; printf '%s' "$aus" | grep -qE '^ *Duration:' && dur="ja"
  echo "| \`$n\` | $code | $anz | $dur |" >> "$bericht"
done

# ---------------------------------------------------------------------------
# Rückgabecodes der Erfolgsfälle, zum Vergleich
# ---------------------------------------------------------------------------
{
echo
echo "## Rückgabecodes der Erfolgsfälle"
echo
echo "Damit erkennbar ist, welcher Code \"in Ordnung\" bedeutet."
echo
echo '| Aufruf | Eingabe | Code |'
echo '|---|---|---|'
} >> "$bericht"

echo "| A1 ffprobe | \`ton.mp3\` | $("$FFPROBE" -i "$QUELLEN/ton.mp3" -hide_banner -show_format -print_format json -v quiet < /dev/null > /dev/null 2>&1; echo $?) |" >> "$bericht"
echo "| A2 Kapitel | \`kapitel.m4b\` | $("$FFMPEG" -i "$QUELLEN/kapitel.m4b" -hide_banner < /dev/null > /dev/null 2>&1; echo $?) |" >> "$bericht"
echo "| A4 volumedetect | \`master.wav\` | $("$FFMPEG" -i "$QUELLEN/master.wav" -af volumedetect -vn -sn -dn -hide_banner -f null /dev/null < /dev/null > /dev/null 2>&1; echo $?) |" >> "$bericht"
echo "| A5 convertToWav | \`ton.mp3\` | $("$FFMPEG" -i "$QUELLEN/ton.mp3" -acodec pcm_s16le -ar 32k -ac 1 -y -hide_banner "$TMP/ok.WAV" < /dev/null > /dev/null 2>&1; echo $?) |" >> "$bericht"
echo "| A7 silencedetect | \`stille-kurz.wav\` | $("$FFMPEG" -i "$QUELLEN/stille-kurz.wav" -af silencedetect=n=-40dB:d=0.1 -hide_banner -f null /dev/null < /dev/null > /dev/null 2>&1; echo $?) |" >> "$bericht"

echo "fertig: $bericht"
