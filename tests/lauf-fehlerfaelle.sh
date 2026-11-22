#!/bin/bash
# Erhebt, wie sich die ffmpeg-Aufrufe der App bei fehlerhaften Eingaben
# verhalten: Rueckgabecode, Fehlermarker im Text, und ob trotzdem eine
# Ausgabedatei entstand.
#
# Warum das eine eigene Erhebung braucht: Die App erkennt Fehler auf drei
# verschiedene Weisen, und nur eine davon ist der Rueckgabecode.
#
#   * A5, A6, A10, A11, A12, A13 pruefen `output.first==0`, also den Code.
#   * A3 ignoriert den Code und sucht in den letzten 300 Zeichen der Ausgabe
#     nach "Error" oder "Invalid", gross geschrieben, mit Qt::CaseSensitive
#     (audiobookconverter.cpp:125-127).
#   * A1 prueft weder Code noch Text, sondern verwirft die Datei nur, wenn
#     format.duration nicht groesser als 0 ist (audioinfothread.cpp:118).
#   * A2 liefert auch im Erfolgsfall Code 1 und darf deshalb nie ueber den
#     Code bewertet werden.
#   * A7 bricht ab, wenn der Code ungleich 0 ist (hoerbertprocessor.cpp:454).
#
# Aendert ein neues ffmpeg einen Rueckgabecode oder den Wortlaut dieser
# Meldungen, verschiebt sich das Fehlerverhalten der App, ohne dass ein
# Erfolgsfall auffaellig wuerde. Nach dem Wegfall von Rosetta ist diese
# Erhebung nicht mehr nachholbar.
#
# Aufruf: lauf-fehlerfaelle.sh <ffmpeg-verzeichnis> <quellen> <ziel>
set -u

FFDIR="${1:?ffmpeg-Verzeichnis fehlt}"
QUELLEN="${2:?Quellen fehlen}"
ZIEL="${3:?Ziel fehlt}"
FFMPEG="$FFDIR/ffmpeg"
FFPROBE="$FFDIR/ffprobe"
HIER="$(cd "$(dirname "$0")" && pwd)"

# Die fehlerhaften Eingaben sind versioniert, nicht generiert: zufall.mp3
# waere sonst bei jedem Lauf anders und compare.sh nicht reproduzierbar.
SCHLECHT="$HIER/reference/fehlerfaelle/schlechte-eingaben"
[ -d "$SCHLECHT" ] || { echo "Pruefdateien fehlen: $SCHLECHT" >&2; exit 2; }

HART="$ZIEL/hart"              # von compare.sh hart geprueft
INFO="$ZIEL/informativ"        # nur mitgeschrieben
rm -rf "$HART" "$INFO"
mkdir -p "$HART" "$INFO"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/aa1b.XXXXXX")"
# (d) nicht beschreibbares Ausgabeziel: Verzeichnis ohne Schreibrecht.
# Zur Laufzeit angelegt, weil git Verzeichnisrechte nicht abbildet.
SPERRE="$TMP/nicht-schreibbar"
mkdir -p "$SPERRE"
chmod 0500 "$SPERRE"
aufraeumen() { chmod 0700 "$SPERRE" 2>/dev/null; rm -rf "$TMP"; }
trap aufraeumen EXIT

# ---------------------------------------------------------------------------
# Die Faelle. (a) bis (d) sind von AA-1b vorgegeben, (e) bis (h) sind
# zusaetzliche Faelle aus der ersten Erhebung, die erhalten bleiben.
# ---------------------------------------------------------------------------
FALL_NAMEN=(a-nicht-vorhanden b-zufall c-halbiert d-ziel-nicht-schreibbar
            e-text f-abgeschnitten-1000 g-leer h-kopf-ohne-daten)

fall_eingabe() {
  case "$1" in
    a-nicht-vorhanden)      echo "$SCHLECHT/gibt-es-nicht.mp3" ;;
    b-zufall)               echo "$SCHLECHT/zufall.mp3" ;;
    c-halbiert)             echo "$SCHLECHT/halb-ton.mp3" ;;
    d-ziel-nicht-schreibbar) echo "$QUELLEN/ton.mp3" ;;   # Eingabe gueltig!
    e-text)                 echo "$SCHLECHT/text.mp3" ;;
    f-abgeschnitten-1000)   echo "$SCHLECHT/abgeschnitten.mp3" ;;
    g-leer)                 echo "$SCHLECHT/leer.mp3" ;;
    h-kopf-ohne-daten)      echo "$SCHLECHT/kopf-ohne-daten.wav" ;;
  esac
}
rm -f "$SCHLECHT/gibt-es-nicht.mp3"

normalisiere() {
  # Die Fortschrittszeile von ffmpeg (size=/video=/frame=) enthaelt
  # Geschwindigkeits- und Laufzeitangaben, die sich bei jedem Lauf
  # unterscheiden. Sie wird als Ganzes ersetzt, genau wie in lauf.sh.
  # Das zusaetzliche speed-Muster faengt die Schreibweise mit Leerzeichen
  # ("speed= 273x"), die ein Muster ohne \s uebersieht.
  sed -E -e 's/@ 0x[0-9a-f]+/@ 0xADRESSE/g' \
         -e 's/^(size|video|frame)=.*$/\1=<FLUECHTIG>/' \
         -e 's/speed=[[:space:]]*[^ ]*/speed=<FLUECHTIG>/g' \
         -e 's/bitrate=[[:space:]]*[^ ]*/bitrate=<FLUECHTIG>/g' \
         -e 's#'"$SCHLECHT"'#<SCHLECHT>#g' \
         -e 's#'"$QUELLEN"'#<QUELLEN>#g' \
         -e 's#'"$SPERRE"'#<SPERRE>#g' \
         -e 's#'"$TMP"'#<TMP>#g' \
         -e 's#'"$FFDIR"'#<FFDIR>#g'
}

# Schreibt die fuenf Dateien eines Falls.
# $1 Kennung, $2 Rueckgabecode, $3 Rohausgabe, $4 Pfad der Ausgabedatei
#    (leer = der Aufruf schreibt keine Datei)
erfasse() {
  local kennung="$1" code="$2" rohausgabe="$3" ausgabepfad="$4"

  # --- hart: Rueckgabecode ---
  echo "rueckgabecode: $code" > "$HART/$kennung.code.txt"

  # --- hart: Fehlermarker in den letzten 300 Zeichen, genau diese
  #     Schreibweise, wie es audiobookconverter.cpp:127 prueft.
  #     Bewusst auf der ROHEN Ausgabe: die App sieht ebenfalls die rohe
  #     Ausgabe, und nur so stimmt das Ergebnis mit ihrem Verhalten
  #     ueberein. Marker haengen nicht an Speicheradressen, der Test ist
  #     also trotzdem stabil. ---
  local letzte300
  letzte300="$(printf '%s' "$rohausgabe" | tail -c 300)"
  {
    if printf '%s' "$letzte300" | grep -q 'Error';   then echo "Error: ja";   else echo "Error: nein";   fi
    if printf '%s' "$letzte300" | grep -q 'Invalid'; then echo "Invalid: ja"; else echo "Invalid: nein"; fi
  } > "$HART/$kennung.marker.txt"

  # --- hart: Ausgabedatei und Groesse ---
  {
    if [ -z "$ausgabepfad" ]; then
      echo "ausgabedatei: entfaellt (dieser Aufruf schreibt keine Datei)"
      echo "groesse: entfaellt"
    elif [ -f "$ausgabepfad" ]; then
      echo "ausgabedatei: ja"
      echo "groesse: $(stat -f%z "$ausgabepfad")"
    else
      echo "ausgabedatei: nein"
      echo "groesse: -"
    fi
  } > "$HART/$kennung.ausgabedatei.txt"

  # --- informativ: die letzten 300 Zeichen im Wortlaut ---
  #     Hier wird VOR dem Schnitt normalisiert, nicht danach. Sonst
  #     zerschneidet die 300-Zeichen-Grenze eine Speicheradresse, und das
  #     uebrig bleibende Bruchstueck ("x7faf48810e00]") entzieht sich jeder
  #     Normalisierung; zusaetzlich verschiebt sich das Fenster, weil
  #     Adressen unterschiedlich lang ausfallen. Die Datei waere dann bei
  #     jedem Lauf anders und als Referenz wertlos. Fuer die harte
  #     Markerpruefung oben gilt weiterhin die rohe Ausgabe.
  printf '%s\n' "$rohausgabe" | normalisiere | tail -c 300 > "$INFO/$kennung.letzte300.txt"

  # --- informativ: vollstaendige Rohausgabe ---
  printf '%s\n' "$rohausgabe" | normalisiere > "$INFO/$kennung.roh.txt"
}

# Vermerkt einen Fall, der fuer diesen Aufruf nicht anwendbar ist.
entfaellt() {
  local kennung="$1" grund="$2"
  echo "entfaellt: $grund" > "$HART/$kennung.code.txt"
  echo "entfaellt: $grund" > "$HART/$kennung.marker.txt"
  echo "entfaellt: $grund" > "$HART/$kennung.ausgabedatei.txt"
  echo "entfaellt: $grund" > "$INFO/$kennung.letzte300.txt"
  echo "entfaellt: $grund" > "$INFO/$kennung.roh.txt"
}

echo "ffmpeg: $("$FFMPEG" -hide_banner -version < /dev/null | head -1)"

for fall in "${FALL_NAMEN[@]}"; do
  eingabe="$(fall_eingabe "$fall")"
  echo "--- $fall"

  # Ausgabeziel: bei (d) in das gesperrte Verzeichnis, sonst nach $TMP
  if [ "$fall" = "d-ziel-nicht-schreibbar" ]; then zielordner="$SPERRE"; else zielordner="$TMP"; fi

  # ===== A1 · ffprobe, schreibt keine Datei =====
  if [ "$fall" = "d-ziel-nicht-schreibbar" ]; then
    entfaellt "A1-$fall" "ffprobe schreibt keine Ausgabedatei"
  else
    aus="$("$FFPROBE" -i "$eingabe" -hide_banner -show_format -print_format json -v quiet < /dev/null 2>&1)"; code=$?
    erfasse "A1-$fall" "$code" "$aus" ""
  fi

  # ===== A2 · Kapitelermittlung, schreibt keine Datei =====
  if [ "$fall" = "d-ziel-nicht-schreibbar" ]; then
    entfaellt "A2-$fall" "dieser Aufruf hat keine Ausgabedatei"
  else
    aus="$("$FFMPEG" -i "$eingabe" -hide_banner < /dev/null 2>&1)"; code=$?
    erfasse "A2-$fall" "$code" "$aus" ""
  fi

  # ===== A3 · Kapitelschnitt =====
  ziel="$zielordner/A3-$fall.WAV"; rm -f "$ziel" 2>/dev/null
  aus="$("$FFMPEG" -i "$eingabe" -ss 0 -to 2 -acodec pcm_s16le -ar 32k -ac 1 \
          -metadata "title=AA-1b" -y -hide_banner "$ziel" < /dev/null 2>&1)"; code=$?
  erfasse "A3-$fall" "$code" "$aus" "$ziel"

  # ===== A4 · volumedetect, schreibt nach /dev/null =====
  if [ "$fall" = "d-ziel-nicht-schreibbar" ]; then
    entfaellt "A4-$fall" "volumedetect schreibt nach /dev/null"
  else
    aus="$("$FFMPEG" -i "$eingabe" -af volumedetect -vn -sn -dn -hide_banner \
            -f null /dev/null < /dev/null 2>&1)"; code=$?
    erfasse "A4-$fall" "$code" "$aus" ""
  fi

  # ===== A5 · convertToWav =====
  ziel="$zielordner/A5-$fall.WAV"; rm -f "$ziel" 2>/dev/null
  aus="$("$FFMPEG" -i "$eingabe" -acodec pcm_s16le -ar 32k -ac 1 \
          -metadata "title=AA-1b" -metadata "album=AA-1b" -metadata "comment=$fall" \
          -y -hide_banner "$ziel" < /dev/null 2>&1)"; code=$?
  erfasse "A5-$fall" "$code" "$aus" "$ziel"

  # ===== A7 · silencedetect, schreibt nach /dev/null =====
  if [ "$fall" = "d-ziel-nicht-schreibbar" ]; then
    entfaellt "A7-$fall" "silencedetect schreibt nach /dev/null"
  else
    aus="$("$FFMPEG" -i "$eingabe" -af "silencedetect=n=-40dB:d=0.1" -hide_banner \
            -f null /dev/null < /dev/null 2>&1)"; code=$?
    erfasse "A7-$fall" "$code" "$aus" ""
  fi

  # ===== A13 · FLAC nach WAV =====
  # Bei (d) eine gueltige FLAC als Eingabe, sonst die fehlerhafte Datei.
  if [ "$fall" = "d-ziel-nicht-schreibbar" ]; then
    a13_ein="$QUELLEN/ton.flac"
  else
    a13_ein="$eingabe"
  fi
  ziel="$zielordner/A13-$fall.WAV"; rm -f "$ziel" 2>/dev/null
  aus="$("$FFMPEG" -i "$a13_ein" -y -hide_banner -v quiet "$ziel" < /dev/null 2>&1)"; code=$?
  erfasse "A13-$fall" "$code" "$aus" "$ziel"
done


# ---------------------------------------------------------------------------
# Nachtrag: Fall (c) fuer weitere Quellformate.
#
# Der Fall "nach der Haelfte abgeschnitten" war bisher nur mit halb-ton.mp3
# erhoben. MP3 ist dabei der guenstigste Fall: ein MP3-Strom besteht aus
# unabhaengigen Frames, ein Schnitt mitten hinein kostet nur den Rest. Bei
# einem MP4-Container (m4a, m4b) steht die Indextabelle moox/stco am Ende der
# Datei, bei FLAC und Ogg haengt die Lesbarkeit an Seiten- und Blockgrenzen.
# Ob die App das bemerkt, laesst sich nur je Format messen.
#
# Je Quelle werden nur die Aufrufe gefahren, fuer die das Format ueberhaupt
# in Frage kommt.
# ---------------------------------------------------------------------------
echo
echo "Nachtrag: Fall (c) fuer weitere Quellformate"

NACHTRAG=(
  "halb-kapitel.m4b|c-halbiert-kapitel-m4b|A1 A2 A3 A4"
  "halb-backup.flac|c-halbiert-backup-flac|A1 A13"
  "halb-ton.m4a|c-halbiert-ton-m4a|A1 A5"
  "halb-ton.ogg|c-halbiert-ton-ogg|A1 A5"
  "halb-ton.wma|c-halbiert-ton-wma|A1 A5"
  "halb-ton.flac|c-halbiert-ton-flac|A1 A5"
)

for eintrag in "${NACHTRAG[@]}"; do
  datei="${eintrag%%|*}"
  rest="${eintrag#*|}"
  fall="${rest%%|*}"
  aufrufe="${rest##*|}"
  eingabe="$SCHLECHT/$datei"
  [ -f "$eingabe" ] || { echo "  FEHLT: $eingabe" >&2; continue; }
  echo "--- $fall ($datei, Aufrufe: $aufrufe)"

  for ruf in $aufrufe; do
    case "$ruf" in
      A1)
        aus="$("$FFPROBE" -i "$eingabe" -hide_banner -show_format -print_format json -v quiet < /dev/null 2>&1)"; code=$?
        erfasse "A1-$fall" "$code" "$aus" ""
        ;;
      A2)
        aus="$("$FFMPEG" -i "$eingabe" -hide_banner < /dev/null 2>&1)"; code=$?
        erfasse "A2-$fall" "$code" "$aus" ""
        ;;
      A3)
        ziel="$TMP/A3-$fall.WAV"; rm -f "$ziel" 2>/dev/null
        aus="$("$FFMPEG" -i "$eingabe" -ss 0 -to 2 -acodec pcm_s16le -ar 32k -ac 1 \
                -metadata "title=AA-1b" -y -hide_banner "$ziel" < /dev/null 2>&1)"; code=$?
        erfasse "A3-$fall" "$code" "$aus" "$ziel"
        ;;
      A4)
        aus="$("$FFMPEG" -i "$eingabe" -af volumedetect -vn -sn -dn -hide_banner \
                -f null /dev/null < /dev/null 2>&1)"; code=$?
        erfasse "A4-$fall" "$code" "$aus" ""
        ;;
      A5)
        ziel="$TMP/A5-$fall.WAV"; rm -f "$ziel" 2>/dev/null
        aus="$("$FFMPEG" -i "$eingabe" -acodec pcm_s16le -ar 32k -ac 1 \
                -metadata "title=AA-1b" -metadata "album=AA-1b" -metadata "comment=$fall" \
                -y -hide_banner "$ziel" < /dev/null 2>&1)"; code=$?
        erfasse "A5-$fall" "$code" "$aus" "$ziel"
        ;;
      A13)
        ziel="$TMP/A13-$fall.WAV"; rm -f "$ziel" 2>/dev/null
        aus="$("$FFMPEG" -i "$eingabe" -y -hide_banner -v quiet "$ziel" < /dev/null 2>&1)"; code=$?
        erfasse "A13-$fall" "$code" "$aus" "$ziel"
        ;;
    esac
  done
done

echo
echo "hart geprueft:  $(ls "$HART" | wc -l | tr -d ' ') Dateien"
echo "informativ:     $(ls "$INFO" | wc -l | tr -d ' ') Dateien"
