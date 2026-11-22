#!/usr/bin/env python3
"""Liest eine RIFF/WAVE- oder AIFF-Datei und gibt ihre Chunk-Struktur aus.

Zweck in AA-1: Die hörbert-Firmware liest die von der App erzeugten WAV-Dateien
direkt. Ob ein neuer ffmpeg die Datei strukturell gleich schreibt
(Chunk-Reihenfolge, Größen, zusätzliche LIST/INFO-Blöcke), ist deshalb ein
Abnahmekriterium und nicht nur eine Formalie. define.h:150 rechnet mit einem
WAV-Header von genau 44 Byte; playlistview.cpp nutzt denselben Wert für die
Größenabschätzung. Jeder zusätzliche Chunk vor den Audiodaten verschiebt diese
Annahme.

Ausgabe: eine Zeile je Chunk, "ID Offset Groesse", danach eine Zusammenfassung
der fmt-Parameter. Bewusst ohne Fremdbibliotheken, damit das Skript auf jedem
Mac ohne Installation läuft.
"""
import struct
import sys


def lies_chunks(daten):
    """Liefert [(id, offset, groesse)] in Dateireihenfolge."""
    if len(daten) < 12:
        raise ValueError("Datei zu kurz für einen RIFF-Header")

    container = daten[0:4].decode("ascii", "replace")
    if container == "RIFF":
        gross_endian = False
    elif container == "FORM":          # AIFF
        gross_endian = True
    else:
        # Kein chunkbasierter Container, etwa fLaC oder ID3. Die Datei wird
        # nicht aufgeschluesselt, aber gemeldet, damit der Vergleich eine
        # stabile Zeile zu sehen bekommt statt eines Abbruchs.
        return container, "", None

    form = daten[8:12].decode("ascii", "replace")
    chunks = []
    pos = 12
    while pos + 8 <= len(daten):
        cid = daten[pos:pos + 4].decode("ascii", "replace")
        (groesse,) = struct.unpack(">I" if gross_endian else "<I",
                                   daten[pos + 4:pos + 8])
        chunks.append((cid, pos, groesse))
        pos += 8 + groesse
        if groesse % 2:                # RIFF-Chunks sind auf 2 Byte ausgerichtet
            pos += 1
    return container, form, chunks


def fmt_details(daten, chunks):
    """Entpackt den fmt-Chunk einer WAVE-Datei, falls vorhanden."""
    for cid, off, groesse in chunks:
        if cid != "fmt ":
            continue
        roh = daten[off + 8:off + 8 + groesse]
        if len(roh) < 16:
            return None
        (codec, kanaele, rate, byterate, block, bits) = struct.unpack("<HHIIHH", roh[:16])
        return {
            "codec_tag": codec,
            "kanaele": kanaele,
            "abtastrate": rate,
            "byte_pro_sekunde": byterate,
            "blockausrichtung": block,
            "bittiefe": bits,
            "fmt_chunk_groesse": groesse,
        }
    return None


def main():
    if len(sys.argv) != 2:
        print("Aufruf: wav-struktur.py <datei>", file=sys.stderr)
        return 2

    pfad = sys.argv[1]
    with open(pfad, "rb") as fh:
        daten = fh.read()

    container, form, chunks = lies_chunks(daten)

    print("datei_bytes: %d" % len(daten))
    print("container: %s" % container)
    if chunks is None:
        print("chunkstruktur: nicht anwendbar (kein RIFF/FORM-Container)")
        return 0
    print("form: %s" % form)
    print("chunk_anzahl: %d" % len(chunks))
    print("# Chunks in Dateireihenfolge: ID Offset Groesse")
    for cid, off, groesse in chunks:
        print("chunk: %-4s %8d %10d" % (cid, off, groesse))

    details = fmt_details(daten, chunks)
    if details:
        for schluessel in ("codec_tag", "kanaele", "abtastrate",
                           "byte_pro_sekunde", "blockausrichtung", "bittiefe",
                           "fmt_chunk_groesse"):
            print("fmt_%s: %s" % (schluessel, details[schluessel]))

        datenchunk = [c for c in chunks if c[0] == "data"]
        if datenchunk:
            _, off, groesse = datenchunk[0]
            print("header_bytes_vor_data: %d" % (off + 8))
            print("data_bytes: %d" % groesse)
            if details["byte_pro_sekunde"]:
                print("dauer_aus_data_sekunden: %.6f"
                      % (groesse / details["byte_pro_sekunde"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
