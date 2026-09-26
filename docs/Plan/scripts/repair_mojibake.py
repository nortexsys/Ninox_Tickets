"""Repair double-encoded UTF-8 (UTF-8 bytes mis-read as cp1252/latin-1) in .md files and inside .docx XML.
Usage:  python repair_mojibake.py <file.md|file.docx> <output_path>   (never overwrites the input)
Prints a report; exits 1 if anything could not be repaired."""
import re, sys, zipfile, collections
from xml.dom import minidom
CP = set('€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ')
def to_byte(ch):
    if ch in CP: return ch.encode('cp1252')
    o = ord(ch)
    return bytes([o]) if 0x80 <= o < 0x100 else None
def lead_len(b):
    return 2 if 0xC2 <= b <= 0xDF else 3 if 0xE0 <= b <= 0xEF else 4 if 0xF0 <= b <= 0xF4 else 0
def repair_stream(chars):
    """chars: list of str (one char each). Returns list of (start, end, replacement)."""
    edits = []; i = 0; n = len(chars)
    while i < n:
        b = to_byte(chars[i])
        L = lead_len(b[0]) if b else 0
        if L and i + L <= n:
            bs = b
            ok = True
            for k in range(1, L):
                c = to_byte(chars[i+k])
                if not c or not (0x80 <= c[0] <= 0xBF): ok = False; break
                bs += c
            if ok:
                try:
                    edits.append((i, i+L, bs.decode('utf-8'))); i += L; continue
                except UnicodeDecodeError: pass
        i += 1
    return edits
MOJI = re.compile('Â|â€|Ã[\u0080-¿]|â[\u0080-¿†-›€™]')
def fix_text(t):
    chars = list(t); edits = repair_stream(chars)
    out = []; last = 0
    for s, e, r in edits: out.append(t[last:s]); out.append(r); last = e
    out.append(t[last:]); return ''.join(out), len(edits)
def fix_xml(x):
    # split into tags and text; repair across text segments, ignoring tags in between
    parts = re.split(r'(<[^>]*>)', x)
    idx = [k for k, p in enumerate(parts) if p and not p.startswith('<')]
    stream = []; owner = []
    for k in idx:
        for j, ch in enumerate(parts[k]): stream.append(ch); owner.append((k, j))
    edits = repair_stream(stream)
    segs = {k: list(parts[k]) for k in idx}
    for s, e, r in edits:
        k0, j0 = owner[s]; segs[k0][j0] = r
        for p in range(s+1, e):
            k, j = owner[p]; segs[k][j] = ''
    for k in idx: parts[k] = ''.join(segs[k])
    return ''.join(parts), len(edits)
def main(src, dst):
    if src == dst: sys.exit('refusing to overwrite the input')
    bad = 0
    if src.lower().endswith('.md'):
        raw = open(src, 'rb').read(); t = raw.decode('utf-8')
        f, n = fix_text(t)
        rem = len(MOJI.findall(f)); bad += rem
        open(dst, 'wb').write(f.encode('utf-8'))
        print(f'{src}: {n} sequences repaired, {rem} suspicious left; lines {t.count(chr(10))} -> {f.count(chr(10))}')
    else:
        zin = zipfile.ZipFile(src)
        with zipfile.ZipFile(dst, 'w') as zout:
            for info in zin.infolist():
                data = zin.read(info.filename)
                if info.filename.endswith('.xml'):
                    x = data.decode('utf-8'); f, n = fix_xml(x)
                    if n:
                        minidom.parseString(f.encode('utf-8'))   # raises if not well-formed
                        rem = len(MOJI.findall(re.sub(r'<[^>]*>', '', f))); bad += rem
                        print(f'{info.filename}: {n} sequences repaired, {rem} suspicious left, XML well-formed')
                        data = f.encode('utf-8')
                zout.writestr(info, data)
    print('RESULT:', 'OK' if bad == 0 else f'{bad} suspicious sequences left')
    sys.exit(0 if bad == 0 else 1)
if __name__ == '__main__': main(sys.argv[1], sys.argv[2])
