"""
Strip LC_CODE_SIGNATURE from a dylib by removing the command & truncating
the trailing signature data (which is always at end of file).
"""
import struct, sys, pathlib

dylib_path = pathlib.Path(sys.argv[1])
with open(dylib_path, 'rb') as f:
    b = bytearray(f.read())

magic, cpu, sub, ftype, ncmds, sizeofcmds, flags, reserved = (
    struct.unpack_from('<IIIIIIII', b, 0))
assert magic == 0xFEEDFACF, 'Not Mach-O 64'

# Find LC_CODE_SIGNATURE
pos = 32
cs_pos = None
cs_dataoff = None
cs_datasize = None
for i in range(ncmds):
    cmd, sz = struct.unpack_from('<II', b, pos)
    base = cmd & 0x7FFFFFFF
    if base == 0x1D:  # LC_CODE_SIGNATURE
        cs_pos = pos
        cs_dataoff, cs_datasize = struct.unpack_from('<II', b, pos+8)
        break
    pos += sz

if cs_pos is None:
    print('No LC_CODE_SIGNATURE found')
    sys.exit(0)

print(f'Found LC_CODE_SIGNATURE at +0x{cs_pos:x}: dataoff=0x{cs_dataoff:x} datasize={cs_datasize}')

# Verify sig data is at end of file
assert cs_dataoff + cs_datasize == len(b), \
    f'Sig not at end: data ends at 0x{cs_dataoff+cs_datasize:x}, file size 0x{len(b):x}'

# Remove the LC_CODE_SIGNATURE command from the load command area
new_ncmds = ncmds - 1
new_sizeofcmds = sizeofcmds - 16  # CODE_SIGNATURE cmd size = 16

# Remove command bytes from new_b
new_b = bytearray(len(b) - cs_datasize)  # trim the sig data
new_b[:cs_pos] = b[:cs_pos]
new_b[cs_pos:32+new_sizeofcmds] = b[cs_pos+16:32+sizeofcmds]  # remove command, fill gap
data_after_old = b[32+sizeofcmds:]
data_after_new = data_after_old  # unchanged, but sig data was at end
# Actually, the gap from cmds_end to first section data needs copying too
# cs_pos+16 to 32+sizeofcmds is 16 bytes less, so we shift data after cs_pos+16 back by 16
# then from 32+new_sizeofcmds onward = old data from 32+sizeofcmds - 16... wait this is confusing.

# Simpler: build new file from scratch
new_b = bytearray()
# Header
new_b += struct.pack('<IIIIIIII', magic, cpu, sub, ftype, new_ncmds, new_sizeofcmds, flags, reserved)
# Load commands before CS
new_b += b[32:cs_pos]
# Load commands after CS (shifted back by 16 to close the gap)
new_b += b[cs_pos+16:32+sizeofcmds]
# Data after load commands (no change)
new_b += b[32+sizeofcmds:]

# Remove the trailing signature data
assert len(new_b) == len(b) - cs_datasize, f'Size mismatch: {len(new_b)} vs {len(b)-cs_datasize}'

# Update __LINKEDIT filesize: shrink by cs_datasize
# Also update segment/section fileoffs that pointed past the signature area
# Scan segments and update fileoffs
delta = -cs_datasize  # the file shrank by this much
pos = 32
for i in range(new_ncmds):
    cmd, sz = struct.unpack_from('<II', new_b, pos)
    base = cmd & 0x7FFFFFFF
    if base == 0x19:  # LC_SEGMENT_64
        segname = new_b[pos+8:pos+24].split(b'\x00')[0].decode()
        fo = struct.unpack_from('<Q', new_b, pos+40)[0]
        fs = struct.unpack_from('<Q', new_b, pos+48)[0]
        ns = struct.unpack_from('<I', new_b, pos+64)[0]
        if segname == '__LINKEDIT':
            print(f'  Shrinking __LINKEDIT: filesize 0x{fs:x} -> 0x{fs+delta:x}')
            fs_new = fs + delta  # reduce by cs_datasize
            struct.pack_into('<Q', new_b, pos+48, fs_new)
        # Update fileoff if it pointed past the code sig data area
        if fo >= cs_dataoff and fo != 0:
            struct.pack_into('<Q', new_b, pos+40, fo + delta)
        so = pos + 72
        for j in range(ns):
            sfo = struct.unpack_from('<I', new_b, so+48)[0]
            if sfo >= cs_dataoff and sfo != 0:
                struct.pack_into('<I', new_b, so+48, sfo + delta)
            so += 80
    elif base in (0x22, 2):  # DYLD_INFO, SYMTAB
        pass  # These offsets are before the signature data area, no update needed
    pos += sz

print(f'Stripped: ncmds={new_ncmds} file={len(new_b)} bytes')

with open(dylib_path, 'wb') as f:
    f.write(new_b)

print('Done')
