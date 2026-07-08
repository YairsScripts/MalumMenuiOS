"""Clean dump of bind opcodes from a Mach-O dylib"""
import struct, sys

path = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\Yairsabn\Documents\amg\MalumMenu\libMalumMenu.dylib"
with open(path, 'rb') as f:
    b = f.read()

pos = 32
ncmds = struct.unpack_from('<I', b, 16)[0]
bind_off = bind_sz = 0

for i in range(ncmds):
    cmd, sz = struct.unpack_from('<II', b, pos)
    base = cmd & 0x7FFFFFFF
    if base == 0x22:
        _, _, bind_off, bind_sz, _, _, _, _ = struct.unpack_from('<IIIIIIII', b, pos+8)
        break
    pos += sz

data = b[bind_off:bind_off+bind_sz]
print(f"BIND: offset=0x{bind_off:x} size={bind_sz}")
print()

i = 0
ordinal = 0
sym = ""
target = ""
while i < len(data):
    off = i
    op = data[i]; i += 1
    imm = op & 0x0F
    cmd = op & 0xF0
    desc = ""

    if cmd == 0x00:  # DONE
        desc = "DONE"
        print(f"  0x{off:04x}: {op:02x}                           {desc}")
        break

    elif cmd == 0x10:  # SET_DYLIB_ORDINAL_IMM
        ordinal = imm
        desc = f"ORDINAL_IMM = {ordinal}"
        if ordinal == 0: desc += " (self)"
        elif ordinal == 0xF: desc += " (flat)"
        else: desc += f" (lib#{ordinal})"
        print(f"  0x{off:04x}: {op:02x}                           {desc}")

    elif cmd == 0x20:  # SET_DYLIB_ORDINAL_ULEB
        val = 0; shift = 0; raw = []
        while True:
            byte = data[i]; raw.append(byte); i += 1
            val |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break
        val_s = val
        val = val & 0xFFFFFFFF
        if val >= 0x80000000: val = val - 0x100000000
        ordinal = val
        raw_hex = ' '.join(f'{x:02x}' for x in raw)
        desc = f"ORDINAL_ULEB = {val}"
        if val == 0: desc += " (self)"
        elif val == -1: desc += " (flat/all images)"
        elif val == -2: desc += " (main executable)"
        else: desc += f" (lib#{val})"
        print(f"  0x{off:04x}: {op:02x} {raw_hex:<25s} {desc}")

    elif cmd == 0x30:  # SET_DYLIB_ORDINAL_SLEB (actually not standard, but I'll support it)
        val = 0; shift = 0; raw = []
        while True:
            byte = data[i]; raw.append(byte); i += 1
            val |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break
        if val & (1 << (shift-1)): val |= -1 << shift
        raw_hex = ' '.join(f'{x:02x}' for x in raw)
        desc = f"ORDINAL_SLEB = {val}"
        print(f"  0x{off:04x}: {op:02x} {raw_hex:<25s} {desc}")

    elif cmd == 0x40:  # SET_SYMBOL_TRAILING_FLAGS_IMM
        flags = imm
        name_bytes = []
        while data[i] != 0:
            name_bytes.append(data[i]); i += 1
        i += 1
        sym = bytes(name_bytes).decode('ascii', errors='replace')
        desc = f"SYMBOL = '{sym}' flags={flags}"
        print(f"  0x{off:04x}: {op:02x} '{sym}'                     {desc}")

    elif cmd == 0x50:  # SET_TYPE_IMM
        desc = f"TYPE = {'pointer' if imm==1 else 'pointer64' if imm==0 else imm}"
        print(f"  0x{off:04x}: {op:02x}                           {desc}")

    elif cmd == 0x60:  # SET_ADDEND_SLEB
        val = 0; shift = 0; raw = []
        while True:
            byte = data[i]; raw.append(byte); i += 1
            val |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break
        if val & (1 << (shift-1)): val |= -1 << shift
        raw_hex = ' '.join(f'{x:02x}' for x in raw)
        desc = f"ADDEND = {val}"
        print(f"  0x{off:04x}: {op:02x} {raw_hex:<25s} {desc}")

    elif cmd == 0x70:  # SET_SEGMENT_AND_OFFSET_ULEB
        seg_idx = imm
        val = 0; shift = 0; raw = []
        while True:
            byte = data[i]; raw.append(byte); i += 1
            val |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break
        seg_off = val
        raw_hex = ' '.join(f'{x:02x}' for x in raw)
        seg_names = ["__TEXT","__DATA_CONST","__DATA","__LINKEDIT"]
        sname = seg_names[seg_idx] if seg_idx < len(seg_names) else f"seg{seg_idx}"
        target = f"{sname}+0x{seg_off:x}"
        desc = f"SEG({seg_idx}) {sname}+0x{seg_off:x}"
        print(f"  0x{off:04x}: {op:02x} {raw_hex:<25s} {desc}")

    elif cmd == 0x80:  # ADD_ADDR_ULEB
        val = 0; shift = 0; raw = []
        while True:
            byte = data[i]; raw.append(byte); i += 1
            val |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break
        raw_hex = ' '.join(f'{x:02x}' for x in raw)
        desc = f"ADD_ADDR +0x{val:x}"
        print(f"  0x{off:04x}: {op:02x} {raw_hex:<25s} {desc}")

    elif cmd == 0x90:  # DO_BIND
        desc = f"BIND {target} ordinal={ordinal} '{sym}'"
        print(f"  0x{off:04x}: {op:02x}                           {desc}")

    elif cmd == 0xA0:  # DO_BIND_ADD_ADDR_ULEB
        val = 0; shift = 0; raw = []
        while True:
            byte = data[i]; raw.append(byte); i += 1
            val |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break
        raw_hex = ' '.join(f'{x:02x}' for x in raw)
        desc = f"BIND_ADD_ADDR +0x{val:x} ordinal={ordinal} '{sym}'"
        print(f"  0x{off:04x}: {op:02x} {raw_hex:<25s} {desc}")

    elif cmd == 0xB0:  # DO_BIND_ADD_ADDR_IMM_SCALED
        desc = f"BIND_ADD_ADDR_IMM *{imm} ordinal={ordinal} '{sym}'"
        print(f"  0x{off:04x}: {op:02x}                           {desc}")

    elif cmd == 0xC0:  # DO_BIND_ULEB_TIMES_SKIPPING_ULEB
        count = 0; shift = 0; raw1 = []
        while True:
            byte = data[i]; raw1.append(byte); i += 1
            count |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break
        skip = 0; shift = 0; raw2 = []
        while True:
            byte = data[i]; raw2.append(byte); i += 1
            skip |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break
        r1 = ' '.join(f'{x:02x}' for x in raw1)
        r2 = ' '.join(f'{x:02x}' for x in raw2)
        desc = f"BIND_TIMES {count} SKIP {skip}"
        print(f"  0x{off:04x}: {op:02x} {r1:<10s} {r2:<10s} {desc}")

    else:
        desc = f"UNKNOWN op={op:#04x}"
        print(f"  0x{off:04x}: {op:02x}                           {desc}")
        break
