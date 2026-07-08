"""
Build a complete modified IPA:
1. Copy dylib to Frameworks/
2. Add LC_LOAD_DYLIB to main binary (in the 12KB gap)
3. Remove old code signatures
4. Package as IPA
Usage: python build_ipa_final.py <extracted_ipa_dir> <dylib_path> <output_ipa_path>
"""
import struct, shutil, os, sys, pathlib, zipfile

def build_ipa(extracted_dir, dylib_path, output_path):
    extracted = pathlib.Path(extracted_dir)
    payload = extracted / 'Payload'
    apps = list(payload.glob('*.app'))
    assert len(apps) == 1
    app_dir = apps[0]
    frameworks_dir = app_dir / 'Frameworks'
    main_binary = app_dir / 'AmongUs'

    dylib_name = pathlib.Path(dylib_path).name
    
    # 1. Copy dylib into Frameworks/
    print(f"Copying {dylib_name} -> {frameworks_dir}")
    shutil.copy2(dylib_path, frameworks_dir / dylib_name)

    # 2. Add LC_LOAD_DYLIB to main binary
    print(f"Patching main binary...")
    with open(main_binary, 'rb') as f:
        b = bytearray(f.read())

    magic, cpu, sub, ftype, ncmds, sizeofcmds, flags, reserved = struct.unpack_from('<IIIIIIII', b, 0)
    assert magic == 0xFEEDFACF, "Not a thin 64-bit Mach-O"
    
    lc_end = 32 + sizeofcmds
    
    # Build LC_LOAD_DYLIB command
    path_bytes = f'@executable_path/Frameworks/{dylib_name}\x00'.encode('ascii')
    while len(path_bytes) % 8:
        path_bytes += b'\x00'
    lc_size = 24 + len(path_bytes)
    
    lc_data = struct.pack('<II', 0xC, lc_size)  # LC_LOAD_DYLIB
    lc_data += struct.pack('<IIII', 24, 2, 0x10000, 0x10000)  # dylib header
    lc_data += path_bytes
    
    # Insert new LC at the end of existing load commands
    assert lc_end + lc_size < 0x4000, "LC would overflow into section data!"
    
    # Shift everything after lc_end by lc_size
    new_b = bytearray(len(b) + lc_size)
    new_b[:lc_end] = b[:lc_end]
    new_b[lc_end:lc_end+lc_size] = lc_data
    new_b[lc_end+lc_size:] = b[lc_end:]
    
    # Update header
    new_ncmds = ncmds + 1
    new_sizeofcmds = sizeofcmds + lc_size
    struct.pack_into('<IIIIIIII', new_b, 0, magic, cpu, sub, ftype, new_ncmds, new_sizeofcmds, flags, reserved)
    
    # Update all file offsets in sections and LINKEDIT (they all shift by lc_size)
    # Only update offsets that are >= lc_end (the insertion point)
    pos = 32
    for i in range(ncmds):
        cmd = struct.unpack_from('<I', new_b, pos)[0]
        base = cmd & 0x7FFFFFFF
        sz = struct.unpack_from('<I', new_b, pos+4)[0]
        
        if base == 0x19:  # LC_SEGMENT_64
            segname = new_b[pos+8:pos+24].split(b'\x00')[0].decode()
            fo = struct.unpack_from('<Q', new_b, pos+40)[0]
            if fo >= lc_end and fo != 0:
                struct.pack_into('<Q', new_b, pos+40, fo + lc_size)
            # If this segment (__TEXT) contains the insertion point, update filesize
            fs = struct.unpack_from('<Q', new_b, pos+48)[0]
            if fo <= lc_end and fo + fs > lc_end:
                struct.pack_into('<Q', new_b, pos+48, fs + lc_size)
            nsects = struct.unpack_from('<I', new_b, pos+64)[0]
            so = pos + 72
            for _ in range(nsects):
                sf = struct.unpack_from('<I', new_b, so+48)[0]
                if sf >= lc_end and sf != 0:
                    struct.pack_into('<I', new_b, so+48, sf + lc_size)
                so += 80
                
        elif base == 0x22:  # LC_DYLD_INFO_ONLY
            for off in (8, 16, 24, 32, 40):
                v = struct.unpack_from('<I', new_b, pos+off)[0]
                if v >= lc_end and v != 0:
                    struct.pack_into('<I', new_b, pos+off, v + lc_size)
                    
        elif base == 2:  # LC_SYMTAB
            for off in (8, 16):
                v = struct.unpack_from('<I', new_b, pos+off)[0]
                if v >= lc_end:
                    struct.pack_into('<I', new_b, pos+off, v + lc_size)
                    
        elif base == 0x0B:  # LC_DYSYMTAB
            for off in (60, 64, 68):
                v = struct.unpack_from('<I', new_b, pos+off)[0]
                if v >= lc_end and v != 0:
                    struct.pack_into('<I', new_b, pos+off, v + lc_size)
                    
        elif base in (0x26, 0x29, 0x1D):  # FUNCTION_STARTS, DATA_IN_CODE, CODE_SIGNATURE
            v = struct.unpack_from('<I', new_b, pos+8)[0]
            if v >= lc_end:
                struct.pack_into('<I', new_b, pos+8, v + lc_size)
                
        pos += sz
    
    with open(main_binary, 'wb') as f:
        f.write(new_b)
    
    new_size = len(new_b)
    print(f"  Main binary: {len(b)} -> {new_size} bytes (+{new_size-len(b)})")

    # 3. Remove old code signatures
    for sig_dir in ['_CodeSignature', 'SC_Info']:
        for root, dirs, files in os.walk(app_dir):
            if os.path.basename(root) in (sig_dir,):
                print(f"  Removing {root}")
                shutil.rmtree(root, ignore_errors=True)
            for d in dirs:
                if d in (sig_dir,):
                    dp = os.path.join(root, d)
                    print(f"  Removing {dp}")
                    shutil.rmtree(dp, ignore_errors=True)

    # 4. Remove .DS_Store
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
    extracted = sys.argv[1]
    dylib = sys.argv[2]
    output = sys.argv[3] if len(sys.argv) > 3 else 'MalumMenu.ipa'
    build_ipa(extracted, dylib, output)
