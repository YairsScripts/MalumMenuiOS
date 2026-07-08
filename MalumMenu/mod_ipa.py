"""
Build complete modified IPA: embed dylib + add LC_LOAD_DYLIB to main binary.
Usage: python mod_ipa.py <extracted_ipa_dir> <dylib_path> <output_ipaa>
"""
import struct, shutil, os, sys, pathlib, zipfile, tempfile

def inject_lc_load_dylib(binary_path, dylib_path_in_app):
    """Add LC_LOAD_DYLIB to a thin Mach-O 64 binary.
    Returns new binary bytes with the command inserted.
    """
    with open(binary_path, 'rb') as f:
        b = bytearray(f.read())

    magic, cpu, sub, ftype, ncmds, sizeofcmds, flags, reserved = struct.unpack_from('<IIIIIIII', b, 0)
    assert magic == 0xFEEDFACF, "Not a thin 64-bit Mach-O"

    # Build LC_LOAD_DYLIB
    path_bytes = dylib_path_in_app.encode('ascii') + b'\x00'
    while len(path_bytes) % 8:
        path_bytes += b'\x00'

    lc_size = 24 + len(path_bytes)
    lc_data = struct.pack('<II', 0xC, lc_size)  # cmd, cmdsize
    lc_data += struct.pack('<IIIII', 24, 2, 0x10000, 0x10000)  # offset, timestamp, cur_ver, compat_ver
    lc_data += path_bytes

    new_sizeofcmds = sizeofcmds + lc_size
    new_ncmds = ncmds + 1

    # Insert LC after last load command, shift everything after
    cmds_end_old = 32 + sizeofcmds
    new_b = bytearray(len(b) + lc_size)
    # Header
    struct.pack_into('<IIIIIIII', new_b, 0, magic, cpu, sub, ftype, new_ncmds, new_sizeofcmds, flags, reserved)
    # Load commands (old + new)
    new_b[32:32+sizeofcmds] = b[32:cmds_end_old]
    new_b[32+sizeofcmds:32+new_sizeofcmds] = lc_data
    # Data after old load commands (shifted)
    new_b[32+new_sizeofcmds:] = b[cmds_end_old:]

    # Update file offsets in segments, LINKEDIT pointers, etc.
    delta = lc_size  # positive shift

    pos = 32
    for i in range(ncmds):  # iterate over OLD commands (non-updated header area)
        cmd = struct.unpack_from('<I', new_b, pos)[0]
        base = cmd & 0x7FFFFFFF
        sz = struct.unpack_from('<I', new_b, pos+4)[0]

        if base == 0x19:  # LC_SEGMENT_64
            fo = struct.unpack_from('<Q', new_b, pos+40)[0]
            if fo >= cmds_end_old and fo != 0:
                struct.pack_into('<Q', new_b, pos+40, fo + delta)
            nsects = struct.unpack_from('<I', new_b, pos+64)[0]
            so = pos + 72
            for _ in range(nsects):
                sf = struct.unpack_from('<I', new_b, so+48)[0]
                if sf >= cmds_end_old and sf != 0:
                    struct.pack_into('<I', new_b, so+48, sf + delta)
                so += 80

        elif base == 0x22:  # LC_DYLD_INFO_ONLY
            for off in (8, 16, 24, 32, 40):
                v = struct.unpack_from('<I', new_b, pos+off)[0]
                if v >= cmds_end_old and v != 0:
                    struct.pack_into('<I', new_b, pos+off, v + delta)

        elif base == 2:  # LC_SYMTAB
            for off in (8, 16):
                v = struct.unpack_from('<I', new_b, pos+off)[0]
                if v >= cmds_end_old:
                    struct.pack_into('<I', new_b, pos+off, v + delta)

        elif base == 0x0B:  # LC_DYSYMTAB
            for off in (60, 64, 68):
                v = struct.unpack_from('<I', new_b, pos+off)[0]
                if v >= cmds_end_old and v != 0:
                    struct.pack_into('<I', new_b, pos+off, v + delta)

        elif base in (0x26, 0x29):  # LC_FUNCTION_STARTS, LC_DATA_IN_CODE
            v = struct.unpack_from('<I', new_b, pos+8)[0]
            if v >= cmds_end_old:
                struct.pack_into('<I', new_b, pos+8, v + delta)

        elif base == 0x1D:  # LC_CODE_SIGNATURE
            v = struct.unpack_from('<I', new_b, pos+8)[0]
            if v >= cmds_end_old:
                struct.pack_into('<I', new_b, pos+8, v + delta)

        pos += sz

    return bytes(new_b)


def build_ipa(extracted_dir, dylib_path, output_path, dylib_install_name=None):
    extracted = pathlib.Path(extracted_dir)
    payload = extracted / 'Payload'
    apps = list(payload.glob('*.app'))
    assert len(apps) == 1, f"Expected 1 app, found {len(apps)}"
    app_dir = apps[0]
    frameworks_dir = app_dir / 'Frameworks'
    main_binary = app_dir / 'AmongUs'

    dylib_name = pathlib.Path(dylib_path).name
    if dylib_install_name is None:
        dylib_install_name = f'@executable_path/Frameworks/{dylib_name}'

    # 1. Copy dylib into Frameworks/
    print(f"Copying {dylib_name} -> {frameworks_dir}")
    shutil.copy2(dylib_path, frameworks_dir / dylib_name)

    # 2. Inject LC_LOAD_DYLIB into main binary
    print(f"Injecting LC_LOAD_DYLIB ({dylib_install_name}) into main binary")
    new_binary = inject_lc_load_dylib(str(main_binary), dylib_install_name)
    with open(main_binary, 'wb') as f:
        f.write(new_binary)

    # 3. Remove old code signatures
    for sig_dir in ['_CodeSignature', 'SC_Info']:
        p = app_dir / sig_dir
        if p.exists():
            print(f"Removing {sig_dir}")
            shutil.rmtree(p)
    for fw_dylib in frameworks_dir.iterdir():
        for sig_dir in ['_CodeSignature', 'SC_Info']:
            p = fw_dylib / sig_dir
            if p.exists():
                shutil.rmtree(p)

    # 4. Remove .DS_Store etc.
    for f in extracted.rglob('.DS_Store'):
        f.unlink(missing_ok=True)

    # 5. Package as IPA
    print(f"Packaging -> {output_path}")
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for fpath in sorted(extracted.rglob('*'), key=lambda p: str(p)):
            if fpath.is_file():
                arcname = fpath.relative_to(extracted)
                zf.write(fpath, arcname)

    size = os.path.getsize(output_path)
    print(f"Done: {output_path} ({size:,} bytes)")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <extracted_ipa_dir> <dylib_path> [output_ipaa]")
        sys.exit(1)
    extracted_dir = sys.argv[1]
    dylib_path = sys.argv[2]
    output_path = sys.argv[3] if len(sys.argv) > 3 else 'MalumMenu.ipa'
    build_ipa(extracted_dir, dylib_path, output_path)
