#!/bin/bash
# Fehlerfaelle fuer den MP3-Weg der Version 3.1.4, fuer alle schreibenden
# Aufrufe. Eingaben und Einstufung wie in AA-1b.
#
# Hart geprueft je Zelle: Rueckgabecode, Vorkommen von "Error" und "Invalid"
# in den letzten 300 Zeichen in genau dieser Schreibweise, sowie ob eine
# Ausgabedatei entstand und wie gross sie ist. Informativ: die letzten 300
# Zeichen im Wortlaut und die vollstaendige Rohausgabe.
#
# Aufruf: lauf-fehlerfaelle-3.1.4.sh <ffmpeg-verzeichnis> <quellen> <ziel>
set -u

FFDIR="${1:?ffmpeg-Verzeichnis fehlt}"
QUELLEN="${2:?Quellen fehlen}"
ZIEL="${3:?Ziel fehlt}"
FFMPEG="$FFDIR/ffmpeg"
HIER="$(cd "$(dirname "$0")" && pwd)"
SCHLECHT="$HIER/reference/fehlerfaelle/schlechte-eingaben"
[ -d "$SCHLECHT" ] || { echo "Pruefdateien fehlen: $SCHLECHT" >&2; exit 2; }

HART="$ZIEL/hart"; INFO="$ZIEL/informativ"
mkdir -p "$HART" "$INFO"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aa1c-f.XXXXXX")"
SPERRE="$TMP/nicht-schreibbar"; mkdir -p "$SPERRE"; chmod 0500 "$SPERRE"
trap 'chmod 0700 "$SPERRE" 2>/dev/null; rm -rf "$TMP"' EXIT

FALL_NAMEN=(a-nicht-vorhanden b-zufall c-halbiert d-ziel-nicht-schreibbar
            e-text f-abgeschnitten-1000 g-leer h-kopf-ohne-daten)
fall_eingabe() {
  case "$1" in
    a-nicht-vorhanden)       echo "$SCHLECHT/gibt-es-nicht.mp3" ;;
    b-zufall)                echo "$SCHLECHT/zufall.mp3" ;;
    c-halbiert)              echo "$SCHLECHT/halb-ton.mp3" ;;
    d-ziel-nicht-schreibbar) echo "$QUELLEN/ton.mp3" ;;
    e-text)                  echo "$SCHLECHT/text.mp3" ;;
    f-abgeschnitten-1000)    echo "$SCHLECHT/abgeschnitten.mp3" ;;
    g-leer)                  echo "$SCHLECHT/leer.mp3" ;;
    h-kopf-ohne-daten)       echo "$SCHLECHT/kopf-ohne-daten.wav" ;;
  esac
}
rm -f "$SCHLECHT/gibt-es-nicht.mp3"

normalisiere() {
  sed -E -e 's/@ 0x[0-9a-f]+/@ 0xADRESSE/g' \
         -e 's/^(size|video|frame)=.*$/\1=<FLUECHTIG>/' \
         -e 's/speed=[[:space:]]*[^ ]*/speed=<FLUECHTIG>/g' \
         -e 's/bitrate=[[:space:]]*[^ ]*/bitrate=<FLUECHTIG>/g' \
         -e 's#'"$SCHLECHT"'#<SCHLECHT>#g' -e 's#'"$QUELLEN"'#<QUELLEN>#g' \
         -e 's#'"$SPERRE"'#<SPERRE>#g' -e 's#'"$TMP"'#<TMP>#g'
}

erfasse() {
  local kennung="$1" code="$2" roh="$3" ausgabe="$4" letzte300
  echo "rueckgabecode: $code" > "$HART/$kennung.code.txt"
  letzte300="$(printf '%s' "$roh" | tail -c 300)"
  {
    printf '%s' "$letzte300" | grep -q 'Error'   && echo "Error: ja"   || echo "Error: nein"
    printf '%s' "$letzte300" | grep -q 'Invalid' && echo "Invalid: ja" || echo "Invalid: nein"
  } > "$HART/$kennung.marker.txt"
  {
    if [ -z "$ausgabe" ]; then echo "ausgabedatei: entfaellt"; echo "groesse: entfaellt"
    elif [ -f "$ausgabe" ]; then echo "ausgabedatei: ja"; echo "groesse: $(stat -f%z "$ausgabe")"
    else echo "ausgabedatei: nein"; echo "groesse: -"; fi
  } > "$HART/$kennung.ausgabedatei.txt"
  printf '%s\n' "$roh" | normalisiere | tail -c 300 > "$INFO/$kennung.letzte300.txt"
  printf '%s\n' "$roh" | normalisiere > "$INFO/$kennung.roh.txt"
}
entfaellt() {
  for d in "$HART/$1.code.txt" "$HART/$1.marker.txt" "$HART/$1.ausgabedatei.txt" \
           "$INFO/$1.letzte300.txt" "$INFO/$1.roh.txt"; do echo "entfaellt: $2" > "$d"; done
}

MP3FMT=(-ar 44100 -ac 2 -b:a 192k)

echo "ffmpeg: $("$FFMPEG" -hide_banner -version < /dev/null | head -1)"
for fall in "${FALL_NAMEN[@]}"; do
  ein="$(fall_eingabe "$fall")"
  [ "$fall" = "d-ziel-nicht-schreibbar" ] && zo="$SPERRE" || zo="$TMP"
  echo "--- $fall"

  # C1 convertToAudioFile
  z="$zo/C1-$fall.MP3"; rm -f "$z" 2>/dev/null
  o="$("$FFMPEG" -i "$ein" "${MP3FMT[@]}" -metadata "title=t" -metadata "album=a" \
        -metadata "comment=$fall" -y -hide_banner -map a "$z" < /dev/null 2>&1)"; c=$?
  erfasse "C1-$fall" "$c" "$o" "$z"

  # C2 convertToMp3
  z="$zo/C2-$fall.MP3"; rm -f "$z" 2>/dev/null
  o="$("$FFMPEG" -i "$ein" "${MP3FMT[@]}" -y -hide_banner -map a "$z" < /dev/null 2>&1)"; c=$?
  erfasse "C2-$fall" "$c" "$o" "$z"

  # C3 splitPer3Mins
  z="$zo/C3-$fall-%01d.MP3"
  o="$("$FFMPEG" -i "$ein" "${MP3FMT[@]}" -y -hide_banner -map a \
        -metadata "title=t" -metadata "album=a" -metadata "comment=$fall" \
        -f segment -segment_time 180 "$z" -y < /dev/null 2>&1)"; c=$?
  erfasse "C3-$fall" "$c" "$o" "$zo/C3-$fall-0.MP3"

  # C4 createSilenceAudioFile — hat keine Eingabedatei, nur Fall (d) sinnvoll
  if [ "$fall" = "d-ziel-nicht-schreibbar" ]; then
    z="$zo/C4-$fall.MP3"; rm -f "$z" 2>/dev/null
    o="$("$FFMPEG" -f lavfi -i "anullsrc=r=44100:cl=stereo" -t 5 -ar 44100 -ac 2 -b:a 128k \
          -hide_banner -metadata "title=t" -metadata "album=a" -metadata "comment=s" \
          "$z" -y < /dev/null 2>&1)"; c=$?
    erfasse "C4-$fall" "$c" "$o" "$z"
  else
    entfaellt "C4-$fall" "dieser Aufruf hat keine Eingabedatei"
  fi

  # C5 changeMetaData, -codec copy
  z="$zo/C5-$fall.MP3"; rm -f "$z" 2>/dev/null
  o="$("$FFMPEG" -i "$ein" -hide_banner -metadata "title=t" -metadata "album=a" \
        -metadata "comment=k" -codec copy "$z" -y < /dev/null 2>&1)"; c=$?
  erfasse "C5-$fall" "$c" "$o" "$z"

  # C7 splitOnSilence, Schnitt
  z="$zo/C7-$fall.MP3"; rm -f "$z" 2>/dev/null
  o="$("$FFMPEG" -i "$ein" -ss 0 -to 2 "${MP3FMT[@]}" -y -hide_banner \
        -metadata "title=t" -metadata "album=a" -metadata "comment=k" -map a "$z" < /dev/null 2>&1)"; c=$?
  erfasse "C7-$fall" "$c" "$o" "$z"

  # C9 Kapitelschnitt — ohne -map a
  z="$zo/C9-$fall.MP3"; rm -f "$z" 2>/dev/null
  o="$("$FFMPEG" -i "$ein" -ss 0 -to 2 "${MP3FMT[@]}" -metadata "title=t" \
        -y -hide_banner "$z" < /dev/null 2>&1)"; c=$?
  erfasse "C9-$fall" "$c" "$o" "$z"

  # C11 convertWav2Flac
  z="$zo/C11-$fall.flac"; rm -f "$z" 2>/dev/null
  o="$("$FFMPEG" -i "$ein" -c:a flac -y -hide_banner "$z" < /dev/null 2>&1)"; c=$?
  erfasse "C11-$fall" "$c" "$o" "$z"

  # C12 convertFlac2Audio
  z="$zo/C12-$fall.MP3"; rm -f "$z" 2>/dev/null
  o="$("$FFMPEG" -i "$ein" -y -hide_banner -v quiet "$z" < /dev/null 2>&1)"; c=$?
  erfasse "C12-$fall" "$c" "$o" "$z"
done
echo
echo "hart: $(ls "$HART" | wc -l | tr -d ' ')   informativ: $(ls "$INFO" | wc -l | tr -d ' ')"
