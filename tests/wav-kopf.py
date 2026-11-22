#!/usr/bin/env python3
"""Schreibt den Kopfbereich einer RIFF-/AIFF-Datei als annotierten Hexdump.

Zweck: Die erzeugten Audiodateien selbst sind zu groß für die
Versionsverwaltung und mit dem Wegfall von Rosetta nicht mehr reproduzierbar.
Der Kopfbereich — alles bis einschließlich des data-Chunk-Headers — ist
dagegen klein, und genau dort entscheidet sich, ob die hörbert-Firmware eine
Datei lesen kann: Chunk-Reihenfolge, fmt-Parameter, der LIST/INFO-Block mit den
Metadaten. Diese Dumps gehören deshalb ins Repository, auch wenn die Dateien
selbst draußen bleiben.

Aufruf: wav-kopf.py <datei> [<maximalbytes>]
"""
import struct
import sys


def chunk_grenzen(daten):
    """Liefert (gross_endian, [(id, offset, groesse)]) oder (None, None)."""
    container = daten[0:4].decode("ascii", "replace")
    if container == "RIFF":
        gross = False
    elif container == "FORM":
        gross = True
    else:
        return None, None

    chunks = []
    pos = 12
    while pos + 8 <= len(daten):
        cid = daten[pos:pos + 4].decode("ascii", "replace")
        (groesse,) = struct.unpack(">I" if gross else "<I", daten[pos + 4:pos + 8])
        chunks.append((cid, pos, groesse))
        pos += 8 + groesse
        if groesse % 2:
            pos += 1
    return gross, chunks


def hexdump(daten, breite=16):
    for start in range(0, len(daten), breite):
        teil = daten[start:start + breite]
        hexteil = " ".join("%02x" % b for b in teil)
        text = "".join(chr(b) if 32 <= b < 127 else "." for b in teil)
        yield "%08x  %-*s  |%s|" % (start, breite * 3 - 1, hexteil, text)


def main():
    if len(sys.argv) not in (2, 3):
        print("Aufruf: wav-kopf.py <datei> [<maximalbytes>]", file=sys.stderr)
        return 2

    pfad = sys.argv[1]
    grenze = int(sys.argv[2]) if len(sys.argv) == 3 else 512

    with open(pfad, "rb") as fh:
        daten = fh.read()

    _, chunks = chunk_grenzen(daten)

    # Bis einschließlich des data-/SSND-Chunk-Headers, danach beginnen die
    # Audiodaten und sind für den Kopfvergleich ohne Belang.
    ende = grenze
    if chunks:
        for cid, off, _ in chunks:
            if cid in ("data", "SSND"):
                ende = min(off + 8, len(daten))
                break

    print("# Kopfbereich von %s" % pfad.split("/")[-1])
    print("# Gesamtgroesse der Datei: %d Byte" % len(daten))
    print("# Gedumpt: %d Byte (bis einschliesslich data-Chunk-Header)" % ende)
    if chunks:
        print("# Chunks: %s" % " ".join(c[0] for c in chunks))
    print()
    for zeile in hexdump(daten[:ende]):
        print(zeile)
    return 0


if __name__ == "__main__":
    sys.exit(main())
