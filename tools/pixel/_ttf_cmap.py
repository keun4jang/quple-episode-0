import struct, sys

def cmap_chars(path):
    d = open(path, "rb").read()
    num = struct.unpack(">H", d[4:6])[0]
    off = None
    for i in range(num):
        p = 12 + 16*i
        tag = d[p:p+4]
        if tag == b"cmap":
            off = struct.unpack(">I", d[p+8:p+12])[0]
            break
    if off is None:
        raise SystemExit("no cmap")
    n = struct.unpack(">H", d[off+2:off+4])[0]
    best = None
    for i in range(n):
        p = off + 4 + 8*i
        pid, eid, sub = struct.unpack(">HHI", d[p:p+8])
        fmt = struct.unpack(">H", d[off+sub:off+sub+2])[0]
        # prefer format 12 (full unicode), else format 4
        rank = {12: 3, 4: 2}.get(fmt, 1)
        if best is None or rank > best[0]:
            best = (rank, fmt, off+sub)
    rank, fmt, p = best
    chars = set()
    if fmt == 4:
        segX2 = struct.unpack(">H", d[p+6:p+8])[0]
        seg = segX2 // 2
        ends = struct.unpack(">%dH" % seg, d[p+14:p+14+segX2])
        sp = p+14+segX2+2
        starts = struct.unpack(">%dH" % seg, d[sp:sp+segX2])
        dp = sp+segX2
        deltas = struct.unpack(">%dh" % seg, d[dp:dp+segX2])
        rp = dp+segX2
        ranges = struct.unpack(">%dH" % seg, d[rp:rp+segX2])
        for i in range(seg):
            for c in range(starts[i], min(ends[i], 0xFFFF)+1):
                if c == 0xFFFF: continue
                if ranges[i] == 0:
                    g = (c + deltas[i]) & 0xFFFF
                else:
                    gp = rp + 2*i + ranges[i] + 2*(c - starts[i])
                    if gp+2 > len(d): continue
                    g = struct.unpack(">H", d[gp:gp+2])[0]
                    if g: g = (g + deltas[i]) & 0xFFFF
                if g: chars.add(c)
    elif fmt == 12:
        ngroups = struct.unpack(">I", d[p+12:p+16])[0]
        for i in range(ngroups):
            q = p+16+12*i
            s, e, gi = struct.unpack(">III", d[q:q+12])
            for c in range(s, e+1):
                chars.add(c)
    return chars

if __name__ == "__main__":
    cs = cmap_chars(sys.argv[1])
    print(sys.argv[1], "glyphs:", len(cs))
