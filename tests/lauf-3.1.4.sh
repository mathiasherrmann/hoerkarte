#!/bin/bash
# Referenzdaten fuer die ffmpeg-/ffprobe-Aufrufe der Version 3.1.4
# (upstream/feedback, 1280aac).
#
# 3.1.4 verzweigt in jeder schreibenden Funktion auf
# qApp->property("hoerbertModel"): 2011 ergibt den alten WAV-Pfad
# (pcm_s16le, 32 kHz, mono), jeder andere Wert den MP3-Pfad
# (44100 Hz, stereo, 192 kbit/s; bei Stille 128 kbit/s).
# Neu gegenueber 2.1.3 ist "-map a" in den meisten schreibenden Aufrufen —
# aber NICHT im Kapitelschnitt, was hier bewusst so nachgebildet wird.
#
# Erhoben wird die Kreuzmenge aus beiden Modellzweigen und beiden
# Einstellungen der Lautstaerkeanhebung (Global/increaseVolume), weil die
# installierte App den Schluessel nicht gesetzt hat und damit "aus" gilt,
# die Vorgabe des Quellcodes aber beide Faelle zulaesst.
#
# Aufruf: lauf-3.1.4.sh <ffmpeg-verzeichnis> <quellen> <ziel-wurzel>
set -u

FFDIR="${1:?ffmpeg-Verzeichnis fehlt}"
QUELLEN="${2:?Quellen fehlen}"
WURZEL="${3:?Ziel fehlt}"
FFMPEG="$FFDIR/ffmpeg"
FFPROBE="$FFDIR/ffprobe"
AUDIO_WURZEL="${AUDIO_ZIEL:-$WURZEL/audio}"

ZIEL_MAXPEGEL="-1.5"

LETZTER_CODE=0
ff()  { "$FFMPEG"  "$@" < /dev/null; LETZTER_CODE=$?; return 0; }
ffp() { "$FFPROBE" "$@" < /dev/null; LETZTER_CODE=$?; return 0; }

normalisiere() {
  sed -E -e 's/@ 0x[0-9a-f]+/@ 0xADRESSE/g' \
         -e 's/^(size|video|frame)=.*$/\1=<FLUECHTIG>/' \
         -e 's/speed=[[:space:]]*[^ ]*/speed=<FLUECHTIG>/g' \
         -e 's/bitrate=[[:space:]]*[^ ]*/bitrate=<FLUECHTIG>/g' \
         -e 's#'"$AUDIO"'#<AUDIO>#g' -e 's#'"$ZIEL"'#<ZIEL>#g' \
         -e 's#'"$QUELLEN"'#<QUELLEN>#g' -e 's#'"$FFDIR"'#<FFDIR>#g'
}

code() { echo "rueckgabecode: $LETZTER_CODE" > "$GEPARST/$1.code.txt"; }

messe() {
  local datei="$1" name="$2"
  ffp -hide_banner -v quiet -print_format json -show_format -show_streams "$datei" \
    | python3 -c '
import json,sys
d=json.load(sys.stdin); f=d.get("format",{})
for k in ("format_name","duration","size","bit_rate","nb_streams"):
    print("format_%s: %s" % (k, f.get(k)))
for k in sorted(f.get("tags",{})):
    print("tag_%s: %s" % (k.lower(), f["tags"][k]))
for s in d.get("streams",[]):
    for k in ("codec_name","sample_fmt","sample_rate","channels","channel_layout",
              "bits_per_sample","bit_rate","duration"):
        print("stream_%s: %s" % (k, s.get(k)))
' > "$MESS/$name.messwerte.txt"
  shasum -a 256 "$datei" | cut -d' ' -f1 > "$MESS/$name.datei-sha256.txt"
  ff -hide_banner -v error -i "$datei" -f s16le -c:a pcm_s16le - 2>/dev/null \
    | shasum -a 256 | cut -d' ' -f1 > "$MESS/$name.pcm-sha256.txt"
}

# Lautstaerkekorrektur wie getVolumeDifference (hoerbertprocessor.cpp:812-889)
korrektur() {
  local datei="$1" grenze="$2" ausgabe maxvol
  ausgabe="$("$FFMPEG" -hide_banner -nostdin -i "$datei" -af volumedetect -vn -sn -dn \
              -f null /dev/null < /dev/null 2>&1 || true)"
  maxvol="$(printf '%s\n' "$ausgabe" | grep -E '^\[Parsed_volumedetect' \
            | sed -n 's/.*max_volume:[[:space:]]*\(-\{0,1\}[0-9.]*\).*/\1/p' | head -1)"
  [ -n "$maxvol" ] || { echo ""; return; }
  python3 -c "
z=float('$ZIEL_MAXPEGEL'); f=float('$maxvol'); d=z-f
if not $ANHEBUNG and d>0.0: d=0.0
print('%.1f' % d if 0.1 < abs(d) < float('$grenze') else '')"
}

# Fuegt den Formatzweig des jeweiligen Modells an $@ an.
format_zweig() {
  if [ "$MODELL" = "2011" ]; then
    printf '%s\n' -acodec pcm_s16le -ar 32k -ac 1
  else
    printf '%s\n' -ar 44100 -ac 2 -b:a 192k
  fi
}

echo "ffmpeg: $("$FFMPEG" -hide_banner -version < /dev/null | head -1)"

for MODELL in 2011 2021; do
for ANHEBUNG in 0 1; do

  [ "$MODELL" = "2011" ] && ENDUNG=".WAV" || ENDUNG=".MP3"
  VARIANTE="modell-$MODELL-anhebung-$ANHEBUNG"
  ZIEL="$WURZEL/$VARIANTE"
  ROH="$ZIEL/rohausgaben"; GEPARST="$ZIEL/geparst"; MESS="$ZIEL/erzeugte-dateien"
  AUDIO="$AUDIO_WURZEL/$VARIANTE"
  mkdir -p "$ROH" "$GEPARST" "$MESS" "$AUDIO"
  echo "===== $VARIANTE (Zielformat $ENDUNG) ====="

  # --- C1 convertToAudioFile (hoerbertprocessor.cpp:471-522) -------------
  for quelle in "$QUELLEN"/ton.* "$QUELLEN"/leise.wav; do
    n="$(basename "$quelle")"; e="${n##*.}"; [ "$n" = "leise.wav" ] && e="leise"
    ziel="$AUDIO/C1-$e$ENDUNG"
    K="$(korrektur "$quelle" 30)"
    echo "volumenkorrektur_db: ${K:-keine}" > "$GEPARST/C1-$e-parameter.txt"
    set -- -i "$quelle"
    while IFS= read -r a; do set -- "$@" "$a"; done < <(format_zweig)
    set -- "$@" -metadata "title=AA-1c Titel" -metadata "album=AA-1c Album" \
                -metadata "comment=$quelle"
    [ -n "$K" ] && set -- "$@" -af "volume=${K}dB"
    set -- "$@" -y -hide_banner -map a "$ziel"
    ff "$@" > "$ROH/C1-$e.txt" 2>&1; code "C1-$e"
    normalisiere < "$ROH/C1-$e.txt" > "$ROH/C1-$e.normalisiert.txt"
    [ -f "$ziel" ] && messe "$ziel" "C1-$e"
  done

  # --- C2 convertToMp3 (hoerbertprocessor.cpp:525-557), modellunabhaengig
  if [ "$MODELL" = "2021" ]; then
    for quelle in "$QUELLEN"/ton.wav "$QUELLEN"/ton.flac; do
      n="$(basename "$quelle")"; e="${n##*.}"
      ziel="$AUDIO/C2-$e.MP3"
      ff -i "$quelle" -ar 44100 -ac 2 -b:a 192k -y -hide_banner -map a "$ziel" \
        > "$ROH/C2-$e.txt" 2>&1; code "C2-$e"
      normalisiere < "$ROH/C2-$e.txt" > "$ROH/C2-$e.normalisiert.txt"
      [ -f "$ziel" ] && messe "$ziel" "C2-$e"
    done
  fi

  # --- C3 splitPer3Mins (hoerbertprocessor.cpp:560-618) ------------------
  K="$(korrektur "$QUELLEN/stille-lang.flac" 30)"
  echo "volumenkorrektur_db: ${K:-keine}" > "$GEPARST/C3-parameter.txt"
  set -- -i "$QUELLEN/stille-lang.flac"
  while IFS= read -r a; do set -- "$@" "$a"; done < <(format_zweig)
  set -- "$@" -y -hide_banner -map a \
              -metadata "title=AA-1c Segment" -metadata "album=AA-1c Album" \
              -metadata "comment=stille-lang.flac" -f segment -segment_time 180
  [ -n "$K" ] && set -- "$@" -af "volume=${K}dB"
  set -- "$@" "$AUDIO/C3-7-%01d$ENDUNG" -y
  ff "$@" > "$ROH/C3-segment.txt" 2>&1; code "C3-segment"
  normalisiere < "$ROH/C3-segment.txt" > "$ROH/C3-segment.normalisiert.txt"
  for d in "$AUDIO"/C3-7-*"$ENDUNG"; do [ -f "$d" ] && messe "$d" "C3-$(basename "$d" "$ENDUNG")"; done
  ls "$AUDIO"/C3-7-*"$ENDUNG" 2>/dev/null | wc -l | tr -d ' ' | sed 's/^/segmentanzahl: /' > "$GEPARST/C3-segmentanzahl.txt"

  # --- C4 createSilenceAudioFile (hoerbertprocessor.cpp:892-938) ---------
  if [ "$MODELL" = "2011" ]; then
    set -- -f lavfi -i "anullsrc=r=32000:cl=mono" -t 5 -acodec pcm_s16le
  else
    set -- -f lavfi -i "anullsrc=r=44100:cl=stereo" -t 5 -ar 44100 -ac 2 -b:a 128k
  fi
  set -- "$@" -hide_banner -metadata "title=AA-1c Stille" \
              -metadata "album=AA-1c Album" -metadata "comment=synthetisch" \
              "$AUDIO/C4-stille$ENDUNG" -y
  ff "$@" > "$ROH/C4-stille.txt" 2>&1; code "C4-stille"
  normalisiere < "$ROH/C4-stille.txt" > "$ROH/C4-stille.normalisiert.txt"
  [ -f "$AUDIO/C4-stille$ENDUNG" ] && messe "$AUDIO/C4-stille$ENDUNG" "C4-stille"

  # --- C5 changeMetaData (hoerbertprocessor.cpp:941-987) -----------------
  cp "$AUDIO/C1-wav$ENDUNG" "$AUDIO/C5-eingang$ENDUNG" 2>/dev/null || true
  ff -i "$AUDIO/C5-eingang$ENDUNG" -hide_banner \
     -metadata "title=AA-1c geaendert" -metadata "album=AA-1c geaendert" \
     -metadata "comment=AA-1c geaendert" -codec copy "$AUDIO/C5-temp$ENDUNG" -y \
     > "$ROH/C5-metadaten.txt" 2>&1; code "C5-metadaten"
  normalisiere < "$ROH/C5-metadaten.txt" > "$ROH/C5-metadaten.normalisiert.txt"
  [ -f "$AUDIO/C5-temp$ENDUNG" ] && messe "$AUDIO/C5-temp$ENDUNG" "C5-temp"

  # --- C6 silencedetect, unveraendert (hoerbertprocessor.cpp:621-641) ----
  ff -i "$QUELLEN/stille-lang.flac" -af "silencedetect=n=-40dB:d=0.1" -hide_banner \
     -f null /dev/null > "$ROH/C6-silencedetect.txt" 2>&1; code "C6-silencedetect"
  normalisiere < "$ROH/C6-silencedetect.txt" > "$ROH/C6-silencedetect.normalisiert.txt"
  {
    grep -E '^\[silencedetect' "$ROH/C6-silencedetect.txt" | sed -E 's/^[^]]*\] *//' || true
    grep -E '^ *Duration:' "$ROH/C6-silencedetect.txt" | sed -E 's/^ *Duration: *([^,]*),.*/Duration: \1/' || true
  } > "$GEPARST/C6-silencedetect.txt"

  # --- C7 splitOnSilence, Schnitt (hoerbertprocessor.cpp:700-802) --------
  # Schnittplan wie die App: nur Stillen jenseits 180 s, Schwelle waechst.
  python3 -c '
import sys
z=[l.strip() for l in open(sys.argv[1]) if l.strip()]
st=[l for l in z if l.startswith("silence_")]
du=[l for l in z if l.startswith("Duration:")]
if not du: print("KEINE_DAUER"); sys.exit()
h,m,s=du[0].split("Duration:",1)[1].strip().split(":")
ges=float(h)*3600+float(m)*60+float(s)
sl=180.0; ch=0; gr=[]
i=0
while i < len(st):
    if "silence_start:" not in st[i]: break
    start=float(st[i].split(":",1)[1].strip())
    if start>sl and i+1<len(st):
        end=float(st[i+1].split("silence_end:",1)[1].split("|")[0].strip())
        if ges-end>1: ch+=1; sl=end+sl; gr.append(end)
    i+=2
print("gesamtlaenge: %.3f" % ges); print("chunk_count: %d" % ch)
for n,g in enumerate(gr): print("schnittgrenze_%d: %s" % (n,g))
' "$GEPARST/C6-silencedetect.txt" > "$GEPARST/C7-schnittplan.txt"
  G="$(sed -n 's/^schnittgrenze_0: //p' "$GEPARST/C7-schnittplan.txt")"
  if [ -n "$G" ]; then
    K="$(korrektur "$QUELLEN/stille-lang.flac" 20)"
    echo "volumenkorrektur_db: ${K:-keine}" > "$GEPARST/C7-parameter.txt"
    set -- -i "$QUELLEN/stille-lang.flac" -ss 0 -to "$G"
    while IFS= read -r a; do set -- "$@" "$a"; done < <(format_zweig)
    set -- "$@" -y -hide_banner -metadata "title=AA-1c Schnitt 1" \
                -metadata "album=AA-1c Album" -metadata "comment=stille-lang.flac"
    [ -n "$K" ] && set -- "$@" -af "volume=${K}dB"
    set -- "$@" -map a "$AUDIO/C7-8-0$ENDUNG"
    ff "$@" > "$ROH/C7-schnitt-0.txt" 2>&1; code "C7-schnitt-0"
    normalisiere < "$ROH/C7-schnitt-0.txt" > "$ROH/C7-schnitt-0.normalisiert.txt"
    [ -f "$AUDIO/C7-8-0$ENDUNG" ] && messe "$AUDIO/C7-8-0$ENDUNG" "C7-schnitt-0"
  fi

  # --- C8 Kapitelermittlung, unveraendert (audiobookconverter.cpp:58-62) -
  ff -i "$QUELLEN/kapitel.m4b" -hide_banner > "$ROH/C8-kapitel.txt" 2>&1; code "C8-kapitel"
  normalisiere < "$ROH/C8-kapitel.txt" > "$ROH/C8-kapitel.normalisiert.txt"
  python3 -c '
import re,sys
t=open(sys.argv[1],encoding="utf-8",errors="replace").read()
if "Chapter #" not in t: print("KEINE_KAPITEL"); sys.exit()
r=t.split("Chapter #",1)[1].split("Stream #",1)[0]
for i,k in enumerate(r.split("Chapter #"),1):
    s=e=ti=""; md=False
    for z in re.split(r"[\r\n]+",k):
        z=z.strip()
        if "start" in z and "end" in z:
            s=z.split("start ",1)[1].split(", end")[0].strip(); e=z.split(", end ",1)[1].strip()
        elif z.startswith("Metadata:"): md=True
        elif z.startswith("title") and md: ti=z.split("title",1)[1].split(":",1)[1].strip()
    print("kapitel_%d_start: %s"%(i,s)); print("kapitel_%d_end: %s"%(i,e)); print("kapitel_%d_title: %s"%(i,ti))
' "$ROH/C8-kapitel.txt" > "$GEPARST/C8-kapitel.txt"

  # --- C9 Kapitelschnitt (audiobookconverter.cpp:71-104) -----------------
  # Beachte: hier gibt es KEIN "-map a".
  K="$(korrektur "$QUELLEN/kapitel.m4b" 20)"
  echo "volumenkorrektur_db: ${K:-keine}" > "$GEPARST/C9-parameter.txt"
  k=0
  while read -r st en ti; do
    [ -n "$st" ] || continue
    ziel="$AUDIO/C9-kapitel-$k$ENDUNG"
    set -- -i "$QUELLEN/kapitel.m4b" -ss "$st" -to "$en"
    while IFS= read -r a; do set -- "$@" "$a"; done < <(format_zweig)
    set -- "$@" -metadata "title=$ti" -y -hide_banner
    [ -n "$K" ] && set -- "$@" -af "volume=${K}dB"
    set -- "$@" "$ziel"
    ff "$@" > "$ROH/C9-kapitel-$k.txt" 2>&1; code "C9-kapitel-$k"
    normalisiere < "$ROH/C9-kapitel-$k.txt" > "$ROH/C9-kapitel-$k.normalisiert.txt"
    [ -f "$ziel" ] && messe "$ziel" "C9-kapitel-$k"
    k=$((k+1))
  done < <(python3 -c '
import sys
w={}
for z in open(sys.argv[1]):
    if ":" in z: k,v=z.split(":",1); w[k.strip()]=v.strip()
i=1
while "kapitel_%d_start"%i in w:
    print(w["kapitel_%d_start"%i], w["kapitel_%d_end"%i], w.get("kapitel_%d_title"%i,"")); i+=1
' "$GEPARST/C8-kapitel.txt")

  # --- C10 volumedetect, unveraendert (hoerbertprocessor.cpp:828-845) ----
  for quelle in "$QUELLEN"/master.wav "$QUELLEN"/leise.wav; do
    n="$(basename "$quelle")"
    ff -i "$quelle" -af volumedetect -vn -sn -dn -hide_banner -f null /dev/null \
      > "$ROH/C10-$n.txt" 2>&1; code "C10-$n"
    normalisiere < "$ROH/C10-$n.txt" > "$ROH/C10-$n.normalisiert.txt"
    grep -E '^\[Parsed_volumedetect' "$ROH/C10-$n.txt" | sed -E 's/@ 0x[0-9a-f]+/@ 0xADRESSE/' \
      > "$GEPARST/C10-$n.txt" || true
  done

  # --- C11 convertWav2Flac, unveraendert (backupmanager.cpp:413-425) -----
  ff -i "$AUDIO/C1-wav$ENDUNG" -c:a flac -y -hide_banner "$AUDIO/C11-backup.flac" \
    > "$ROH/C11-wav2flac.txt" 2>&1; code "C11-wav2flac"
  normalisiere < "$ROH/C11-wav2flac.txt" > "$ROH/C11-wav2flac.normalisiert.txt"
  [ -f "$AUDIO/C11-backup.flac" ] && messe "$AUDIO/C11-backup.flac" "C11-backup"

  # --- C12 convertFlac2Audio, umbenannt, Argumente unveraendert ----------
  #     (backupmanager.cpp:432-444; hiess in 2.1.3 convertFlac2Wav)
  ff -i "$AUDIO/C11-backup.flac" -y -hide_banner -v quiet "$AUDIO/C12-restore$ENDUNG" \
    > "$ROH/C12-flac2audio.txt" 2>&1; code "C12-flac2audio"
  normalisiere < "$ROH/C12-flac2audio.txt" > "$ROH/C12-flac2audio.normalisiert.txt"
  [ -f "$AUDIO/C12-restore$ENDUNG" ] && messe "$AUDIO/C12-restore$ENDUNG" "C12-restore"

  # --- C13 ffprobe show_format, unveraendert (audioinfothread.cpp:99-137)
  for quelle in "$QUELLEN"/*; do
    n="$(basename "$quelle")"
    ffp -i "$quelle" -hide_banner -show_format -print_format json -v quiet \
      > "$ROH/C13-$n.json" 2>&1; code "C13-$n"
    python3 -c '
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception as e: print("JSON_UNLESBAR"); sys.exit()
f=d.get("format",{}); t=f.get("tags",{})
for k in ("title","album","comment"): print("%s: %s"%(k,t.get(k,"")))
print("duration: %s"%f.get("duration",""))
' "$ROH/C13-$n.json" > "$GEPARST/C13-$n.txt"
  done

done
done
echo "fertig."
