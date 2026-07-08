"""
Build complete modified IPA by overwriting the 12KB gap in the main binary
with a new LC_LOAD_DYLIB command - no data shifting needed.
"""
import struct, shutil, os, sys, pathlib, zipfile

def build_ipa(extracted_dir, dylib_path, output_path):
    extracted = pathlib.Path(extracted_dir)
    payload = extracted / 'Payload'
    apps = list(payload.glob('*.app'))
    assert len(apps) == 1, 'Need exactly one .app'
    app_dir = apps[0]
    frameworks_dir = app_dir / 'Frameworks'
    main_binary = app_dir / 'AmongUs'

    dylib_name = pathlib.Path(dylib_path).name

    # 1. Copy dylib into Frameworks/
    print(f'Copying {dylib_name} -> {frameworks_dir}')
    shutil.copy2(dylib_path, frameworks_dir / dylib_name)

    # 2. Add LC_LOAD_DYLIB to main binary (overwrites into gap, no data shift)
    print('Patching main binary...')
    with open(main_binary, 'rb') as f:
        b = bytearray(f.read())

    magic, cpu, sub, ftype, ncmds, sizeofcmds, flags, reserved = (
        struct.unpack_from('<IIIIIIII', b, 0))
    assert magic == 0xFEEDFACF, 'Not a thin 64-bit Mach-O'

    lc_end = 32 + sizeofcmds
    assert lc_end < 0x4000, 'No gap for insertion'

    # Build LC_LOAD_DYLIB command
    path_bytes = f'@executable_path/Frameworks/{dylib_name}\x00'.encode('ascii')
    while len(path_bytes) % 8:
        path_bytes += b'\x00'
    lc_size = 24 + len(path_bytes)

    assert lc_end + lc_size < 0x4000, 'LC would overflow gap'
    assert b[lc_end:lc_end + lc_size] == b'\x00' * lc_size, 'Gap not zero at insert point'

    lc_data = struct.pack('<II', 0xC, lc_size)
    lc_data += struct.pack('<IIII', 24, 2, 0x10000, 0x10000)  # name_off, ts, cur_ver, compat_ver
    lc_data += path_bytes

    # Overwrite the gap - no data shift needed
    b[lc_end:lc_end + lc_size] = lc_data
    struct.pack_into('<IIIIIIII', b, 0, magic, cpu, sub, ftype,
                     ncmds + 1, sizeofcmds + lc_size, flags, reserved)

    with open(main_binary, 'wb') as f:
        f.write(b)

    print(f'  {len(b)} bytes (gap write, no data shift)')

    # 3. Remove old code signatures
    for sig_dir in ['_CodeSignature', 'SC_Info']:
        target = app_dir / sig_dir
        if target.exists():
            print(f'  Removing {target}')
            shutil.rmtree(target, ignore_errors=True)

    # 4. Remove .DS_Store
    for f in extracted.rglob('.DS_Store'):
        f.unlink(missing_ok=True)

    # 5. Package as IPA
    print(f'Packaging -> {output_path}')
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for fpath in sorted(extracted.rglob('*'), key=str):
            if fpath.is_file():
                zf.write(fpath, fpath.relative_to(extracted))

    print(f'Done: {output_path} ({os.path.getsize(output_path):,} bytes)')

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f'Usage: {sys.argv[0]} <extracted_ipa_dir> <dylib_path> [output.ipa]')
        sys.exit(1)
    build_ipa(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'MalumMenu.ipa')
