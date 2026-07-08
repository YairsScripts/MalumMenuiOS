import struct

path = r"C:\Users\Yairsabn\Documents\amg\MalumMenu\libMalumMenu.dylib"
with open(path, 'rb') as f:
    b = f.read()

# Find non-lazy bind offset
pos = 32
ncmds = struct.unpack_from('<I', b, 16)[0]
for i in range(ncmds):
    cmd, sz = struct.unpack_from('<II', b, pos)
    base = cmd & 0x7FFFFFFF
    if base == 0x22:
        _, _, bind_off, bind_sz, _, _, _, _ = struct.unpack_from('<IIIIIIII', b, pos+8)
        break
    pos += sz

print(f"Bind data at file offset 0x{bind_off:x}, size {bind_sz}")
print()

# Read raw hex at the bind offset
data = b[bind_off:bind_off+bind_sz]

# Show first 300 bytes as hex dump
for row in range(0, min(300, len(data)), 16):
    hex_part = ' '.join(f'{data[row+i]:02x}' for i in range(16))
    ascii_part = ''.join(chr(data[row+i]) if 32 <= data[row+i] < 127 else '.' for i in range(16))
    print(f"  0x{row:04x}: {hex_part}  {ascii_part}")
