import struct, sys

"""Post-process a Mach-O dylib to fix bind opcodes.
Changes all BIND_OPCODE_SET_DYLIB_ORDINAL_IMM2(14) bindings to
flat namespace lookup (0xFF) so all symbols resolve at runtime.
"""

def patch_dylib(path):
    with open(path, 'rb') as f:
        b = bytearray(f.read())

    m = struct.unpack_from('<IIIIII', b, 0)
    ncmds = m[4]

    # Find LC_DYLD_INFO_ONLY
    co = 32
    dyld_co = None
    for i in range(ncmds):
        cmd, size = struct.unpack_from('<II', b, co)
        c = cmd & 0x7FFFFFFF
        if c == 0x22:  # LC_DYLD_INFO_ONLY
            dyld_co = co
            break
        co += size

    if dyld_co is None:
        print('No LC_DYLD_INFO_ONLY found')
        return False

    rebase_off = struct.unpack_from('<I', b, dyld_co+8)[0]
    rebase_size = struct.unpack_from('<I', b, dyld_co+12)[0]
    bind_off = struct.unpack_from('<I', b, dyld_co+16)[0]
    bind_size = struct.unpack_from('<I', b, dyld_co+20)[0]
    lazy_bind_off = struct.unpack_from('<I', b, dyld_co+32)[0]
    lazy_bind_size = struct.unpack_from('<I', b, dyld_co+36)[0]
    export_off = struct.unpack_from('<I', b, dyld_co+40)[0]
    export_size = struct.unpack_from('<I', b, dyld_co+44)[0]

    print(f'Before: bind={bind_off:#x}({bind_size}) lazy={lazy_bind_off:#x}({lazy_bind_size}) export={export_off:#x}({export_size})')

    # Scan bind opcodes for ordinal-14 references
    # 0x3E = BIND_OPCODE_SET_DYLIB_ORDINAL_IMM2(14)
    ORDINAL14_OPCODE = 0x3E
    FLAT_ORDINAL_SEQ = bytes([0x20, 0xFF])  # SET_DYLIB_ORDINAL_ULEB(255 = flat lookup)

    # Find all positions of 0x3E in the bind data
    bind_data = b[bind_off:bind_off+bind_size]
    positions = []
    pos = 0
    while pos < len(bind_data):
        if bind_data[pos] == ORDINAL14_OPCODE:
            positions.append(pos)
        pos += 1

    if not positions:
        print('No ordinal-14 bindings found')
        return True

    print(f'Found {len(positions)} ordinal-14 bindings at positions: {positions[:5]}...')

    # Rebuild bind data: replace each 0x3E with 0x20 0xFF
    new_bind = bytearray()
    pos = 0
    for p in positions:
        new_bind.extend(bind_data[pos:p])
        new_bind.extend(FLAT_ORDINAL_SEQ)
        pos = p + 1
    new_bind.extend(bind_data[pos:])

    growth = len(new_bind) - bind_size
    print(f'Bind section grew by {growth} bytes ({bind_size} -> {len(new_bind)})')

    # Update LC_DYLD_INFO_ONLY
    struct.pack_into('<I', b, dyld_co+20, len(new_bind))
    if lazy_bind_off:
        struct.pack_into('<I', b, dyld_co+32, lazy_bind_off + growth)
    if export_off:
        struct.pack_into('<I', b, dyld_co+40, export_off + growth)

    # Rebuild file: insert new bind data, shift lazy bind and export data
    # New data order: bind + lazy_bind + export (shifted)
    before_bind = b[:bind_off]
    after_bind = b[bind_off+bind_size:]

    b = bytearray()
    b.extend(before_bind)
    b.extend(new_bind)
    b.extend(after_bind)

    print(f'After: bind={bind_off:#x}({len(new_bind)}) lazy={lazy_bind_off+growth:#x} export={export_off+growth:#x}')

    with open(path, 'wb') as f:
        f.write(b)

    print(f'Patched {len(positions)} ordinal-14 bindings -> flat namespace')
    return True


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: fix_bind.py <dylib>')
        sys.exit(1)
    patch_dylib(sys.argv[1])
