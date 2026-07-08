import struct

path = r"C:\Users\Yairsabn\Documents\amg\MalumMenu\libMalumMenu.dylib"
with open(path, 'rb') as f:
    b = f.read()

# Find non-lazy bind offset and size
pos = 32
ncmds = struct.unpack_from('<I', b, 16)[0]
for i in range(ncmds):
    cmd, sz = struct.unpack_from('<II', b, pos)
    base = cmd & 0x7FFFFFFF
    if base == 0x22:
        _, _, bind_off, bind_sz, _, _, _, _ = struct.unpack_from('<IIIIIIII', b, pos+8)
        break
    pos += sz

data = b[bind_off:bind_off+bind_sz]

# Show exact bytes at positions 0x10-0x20
print("Bytes at offsets 0x10-0x20:")
for i in range(0x10, 0x20):
    print(f"  [{i:#05x}] {data[i]:02x} {chr(data[i]) if 32<=data[i]<127 else '.'}")

# Decode SLEB at position 0x13 (which should be the ordinal for _objc_msgSend)
print("\nSLEB decoding at offset 0x13:")
off = 0x13
val = 0
shift = 0
raw = []
while True:
    bval = data[off]; raw.append(bval); off += 1
    val |= (bval & 0x7F) << shift
    shift += 7
    print(f"  byte={bval:02x} val_interim={val:#x} shift={shift}")
    if not (bval & 0x80):
        break
# sign extend
if val & (1 << (shift-1)):
    val |= -1 << shift
print(f"Final: {val} (0x{val:x})")
print(f"As int32: {val & 0xFFFFFFFF}")

# Also check: is this maybe ULEB (not SLEB)?
print(f"  As ULEB (no sign): {val}")

# For SET_DYLIB_ORDINAL_IMM with imm 0x0E:
# The byte would be 0x10 | 0x0E = 0x1E
# Our byte is 0x3E, which is different
print(f"\n0x1E = SET_DYLIB_ORDINAL_IMM | 0x0E (imm ordinal 14)")
print(f"0x3E = SET_TYPE_IMM | ??? or SET_DYLIB_ORDINAL_SLEB | ???")
