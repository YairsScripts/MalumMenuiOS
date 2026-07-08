import struct, sys

dylib = sys.argv[1]
with open(dylib, 'rb') as f:
    b = bytearray(f.read())

magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds = struct.unpack_from('<IIIIII', b, 0)
assert magic == 0xFEEDFACF
assert filetype == 6

cmds_end = 32 + sizeofcmds
pad = (0x4000 - (cmds_end % 0x4000)) % 0x4000

# --- Identify commands to keep vs strip ---
# Keep: LC_SEGMENT_64(0x19), LC_DYLD_INFO_ONLY(0x22), LC_SYMTAB(2), LC_DYSYMTAB(0x0B),
#        LC_ID_DYLIB(0x0D), LC_LOAD_DYLIB(0x0C), LC_UUID(0x1B), LC_BUILD_VERSION(0x32),
#        LC_SOURCE_VERSION(0x2A), LC_FUNCTION_STARTS(0x26), LC_DATA_IN_CODE(0x29),
#        LC_LOAD_UPWARD_DYLIB(0x23), LC_CODE_SIGNATURE(0x1D)
# Strip: everything else

KEEP_BASES = {0x19, 2, 0x0B, 0x0C, 0x0D, 0x1B, 0x1D, 0x22, 0x26, 0x29, 0x2A, 0x32, 0x23}

# Scan commands
cmds = []  # (base_cmd, size, data_start)
co = 32
for i in range(ncmds):
    cmd = struct.unpack_from('<I', b, co)[0]
    base = cmd & 0x7FFFFFFF
    size = struct.unpack_from('<I', b, co+4)[0]
    cmds.append((cmd, size, co))
    co += size

# Build list of kept commands and bytes they occupy
kept_coords = []
total_stripped = 0
for cmd, size, co in cmds:
    base = cmd & 0x7FFFFFFF
    if base in KEEP_BASES:
        kept_coords.append((cmd, size, co))
    else:
        total_stripped += size

total_stripped = sizeofcmds - sum(s for (_,s,_) in kept_coords)

# Calculate new header size and pad
new_ncmds = len(kept_coords)
new_sizeofcmds = sum(s for (_,s,_) in kept_coords)
new_cmds_end = 32 + new_sizeofcmds
pad = (0x4000 - (new_cmds_end % 0x4000)) % 0x4000

# Build the new load command area
new_lc = bytearray()
for cmd, size, co in kept_coords:
    new_lc.extend(b[co:co+size])
assert len(new_lc) == new_sizeofcmds

# Build new file: header + new load commands + padding + old data after original cmds_end
data_after = b[cmds_end:]  # data following original load commands
new_total = 32 + new_sizeofcmds + pad + len(data_after)
nb = bytearray(new_total)

# Copy header (first 32 bytes, but update ncmds, sizeofcmds, and flags)
orig_flags = struct.unpack_from('<I', b, 24)[0]
struct.pack_into('<IIIIII', nb, 0, magic, cputype, cpusubtype, filetype, new_ncmds, new_sizeofcmds)
# Preserve original flags but ensure MH_DYLDLINK (0x4) is set and MH_TWOLEVEL (0x80) is clear for flat namespace
new_flags = (orig_flags | 0x4) & ~0x80
struct.pack_into('<I', nb, 24, new_flags)
struct.pack_into('<I', nb, 28, struct.unpack_from('<I', b, 28)[0])  # reserved

# Copy load commands right after header
nb[32:32+new_sizeofcmds] = new_lc

# Add padding
# (already zero-filled)

# Copy data after the padding
nb[32+new_sizeofcmds+pad:] = data_after

# --- Now update file offsets ---
# All data that was after cmds_end is now at offset: 32+new_sizeofcmds+pad + (old_offset - cmds_end)
# = old_offset + (new_sizeofcmds + pad - sizeofcmds)
# = old_offset + delta
delta = new_sizeofcmds + pad - sizeofcmds

co = 32
p = 0  # index into kept_coords
for i in range(new_ncmds):
    cmd, size = struct.unpack_from('<II', nb, co)
    base = cmd & 0x7FFFFFFF

    if base == 0x19:  # LC_SEGMENT_64
        fo = struct.unpack_from('<Q', nb, co+40)[0]
        if fo >= cmds_end and fo != 0:
            struct.pack_into('<Q', nb, co+40, fo + delta)
        ns = struct.unpack_from('<I', nb, co+64)[0]
        so = co + 72
        for s in range(ns):
            sf = struct.unpack_from('<I', nb, so+48)[0]
            if sf >= cmds_end and sf != 0:
                struct.pack_into('<I', nb, so+48, sf + delta)
            so += 80

    elif base == 0x22:  # LC_DYLD_INFO_ONLY
        for off in (8, 16, 24, 32, 40):
            v = struct.unpack_from('<I', nb, co+off)[0]
            if v >= cmds_end and v != 0:
                struct.pack_into('<I', nb, co+off, v + delta)

    elif base == 2:  # LC_SYMTAB (symoff=8, nsyms=12, stroff=16, strsize=20)
        for off in (8, 16):
            v = struct.unpack_from('<I', nb, co+off)[0]
            if v >= cmds_end:
                struct.pack_into('<I', nb, co+off, v + delta)

    elif base == 0x0B:  # LC_DYSYMTAB
        for off in (60, 64, 68):
            v = struct.unpack_from('<I', nb, co+off)[0]
            if v >= cmds_end and v != 0:
                struct.pack_into('<I', nb, co+off, v + delta)

    elif base in (0x26, 0x29):  # LC_FUNCTION_STARTS, LC_DATA_IN_CODE
        v = struct.unpack_from('<I', nb, co+8)[0]
        if v >= cmds_end:
            struct.pack_into('<I', nb, co+8, v + delta)

    elif base == 0x1D:  # LC_CODE_SIGNATURE
        v = struct.unpack_from('<I', nb, co+8)[0]
        if v >= cmds_end:
            struct.pack_into('<I', nb, co+8, v + delta)
    elif base == 0x23:  # LC_LOAD_UPWARD_DYLIB
        pass  # no file offsets to update

    co += size

# Remove REQ flag from any remaining LC_REQ_DYLD commands
co = 32
for i in range(new_ncmds):
    cmd = struct.unpack_from('<I', nb, co)[0]
    if cmd & 0x80000000:
        struct.pack_into('<I', nb, co, cmd & 0x7FFFFFFF)
    size = struct.unpack_from('<I', nb, co+4)[0]
    co += size

# Patch platform to iOS in LC_BUILD_VERSION
co = 32
for i in range(new_ncmds):
    cmd = struct.unpack_from('<I', nb, co)[0] & 0x7FFFFFFF
    size = struct.unpack_from('<I', nb, co+4)[0]
    if cmd == 0x32:
        nb[co+8] = 2
        break
    co += size

# Validate
magic2 = struct.unpack_from('<I', nb, 0)[0]
type2 = struct.unpack_from('<I', nb, 12)[0]
ok = magic2 == 0xFEEDFACF and type2 == 6

with open(dylib, 'wb') as f:
    f.write(nb)

stripped_names = [(c & 0x7FFFFFFF) for c,_,_ in cmds if (c & 0x7FFFFFFF) not in KEEP_BASES]
print(f'Patched: pad={pad}, ncmds={new_ncmds}, total={len(nb)}, stripped={stripped_names}')
if not ok:
    print('FAILED')
    sys.exit(1)
print('OK')
