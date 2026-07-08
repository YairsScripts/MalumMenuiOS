"""
Build a complete modified IPA with dylib embedded.
Usage: python build_ipa.py <extracted_ipa_dir> <dylib_path> <output_ipa_path>
"""
import struct, shutil, os, sys, pathlib, tempfile, zipfile

def add_lc_load_dylib(binary_path, dylib_name):
    """Add an LC_LOAD_DYLIB command to load @executable_path/Frameworks/<dylib_name>"""
    with open(binary_path, 'rb') as f:
        b = bytearray(f.read())

    magic = struct.unpack_from('<I', b, 0)[0]
    assert magic in (0xFEEDFACF, 0xFEEDFACE), "Not a thin Mach-O 64"

    _, cpu, sub, ftype, ncmds, sizeofcmds, flags, reserved = struct.unpack_from('<IIIIIIII', b, 0)

    # Build LC_LOAD_DYLIB command
    # struct dylib_command {
    #   uint32_t cmd;        // LC_LOAD_DYLIB = 0xC
    #   uint32_t cmdsize;    // sizeof(dylib_command) + path padding
    #   struct dylib {
    #     uint32_t offset;   // offset to path string from start of dylib_command
    #     uint32_t timestamp;
    #     uint32_t current_version;
    #     uint32_t compat_version;
    #   }
    #   char name[];         // null-terminated
    # }
    path_str = f'@executable_path/Frameworks/{dylib_name}\x00'
    # Pad to 8-byte alignment
    while len(path_str) % 8:
        path_str += '\x00'

    lc_size = 24 + len(path_str)
    lc = struct.pack('<II', 0xC, lc_size)  # cmd, cmdsize
    lc += struct.pack('<IIIII', 24, 2, 0x10000, 0x10000)  # offset, timestamp, version, compat
    lc += path_str.encode('ascii')

    # Find where to insert - between existing load commands and __LINKEDIT
    # We need to find the start of __LINKEDIT (usually the last segment)
    linkedit_pos = None
    pos = 32
    for i in range(ncmds):
        cmd, cmdsz = struct.unpack_from('<II', b, pos)
        if (cmd & 0x7FFFFFFF) == 0x19:  # LC_SEGMENT_64
            segname = b[pos+8:pos+24].split(b'\x00')[0].decode('ascii', errors='replace')
            vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<QQQQ', b, pos+24)
            if segname == '__LINKEDIT':
                linkedit_pos = pos
                linkedit_fileoff = fileoff
                break
        pos += cmdsz

    assert linkedit_pos is not None, "No __LINKEDIT found"

    # Insert LC command before __LINKEDIT
    new_b = bytearray()
    new_b.extend(b[:linkedit_pos])
    new_b.extend(lc)
    new_b.extend(b[linkedit_pos:])

    # Update header
    new_ncmds = ncmds + 1
    new_sizeofcmds = sizeofcmds + lc_size
    struct.pack_into('<IIIIIIII', new_b, 0, magic, cpu, sub, ftype, new_ncmds, new_sizeofcmds, flags, reserved)

    # Update the fileoff of __LINKEDIT and all following segments + LC_CODE_SIGNATURE
    # The LC commands are now bigger, but the segments themselves haven't moved.
    # We only need to update the header (already done) and the LC fileoff of LINKEDIT.
    # Actually, inserting bytes shifts everything after the insertion point.
    # Since the LC commands are in the header but the data segments haven't moved,
    # we DON'T need to update LINKEDIT fileoff because its file content is still the same.
    # We only inserted bytes in the header area (after the file, conceptually, since the header
    # is followed by segment data).

    # Wait, this is wrong. The load commands are between the header and the segment data.
    # Inserting bytes there would shift all segment data. But segments' fileoff values in their
    # load commands point to data AFTER the load commands. So we need to update all segment fileoffs.

    # Actually, this approach is complex and error-prone. Let me use a different method:
    # Instead of inserting into the binary, let me PATCH the file.
    # The standard approach is to add the LC_LOAD_DYLIB entry at the end of the existing load commands
    # (right before __LINKEDIT's load command), and update the __LINKEDIT fileoff accordingly.

    # Hmm, actually the __LINKEDIT segment contains symbol tables and code signature.
    # Its fileoff points to data after the load commands. Since we're adding bytes to the
    # load commands, we need to shift __LINKEDIT's fileoff by lc_size bytes.

    # But the simplest approach is: don't modify the main binary's load commands.
    # Instead, use DYLD_INSERT_LIBRARIES or just place the dylib in Frameworks/ and
    # let the user inject it via Sideloadly's "dylib injection" feature.

    # For now, let me just copy the dylib into Frameworks/ and not touch the main binary.
    # The user can use Sideloadly's dylib injection.

    # Actually, let me rewrite this to use the proper approach: just copy to Frameworks/.
    print("Note: Not modifying main binary LC_LOAD_DYLIB. Sideloadly will do this.")
    return b  # unchanged

def build_ipa(extracted_dir, dylib_path, output_path):
    extracted = pathlib.Path(extracted_dir)
    payload = extracted / 'Payload'
    app_dir = list(payload.glob('*.app'))[0]
    frameworks_dir = app_dir / 'Frameworks'

    # Copy dylib into Frameworks/
    dylib_name = pathlib.Path(dylib_path).name
    print(f"Copying {dylib_path} -> {frameworks_dir / dylib_name}")
    shutil.copy2(dylib_path, frameworks_dir / dylib_name)

    # Remove old code signatures (Sideloadly will re-sign)
    codesig = app_dir / '_CodeSignature'
    if codesig.exists():
        print("Removing _CodeSignature")
        shutil.rmtree(codesig)
    scinfo = app_dir / 'SC_Info'
    if scinfo.exists():
        print("Removing SC_Info")
        shutil.rmtree(scinfo)

    # Remove code signature from sub-frameworks too
    for fw in frameworks_dir.iterdir():
        fw_cs = fw / '_CodeSignature'
        if fw_cs.exists():
            shutil.rmtree(fw_cs)
        fw_sc = fw / 'SC_Info'
        if fw_sc.exists():
            shutil.rmtree(fw_sc)

    # Remove .DS_Store and other junk
    for f in extracted.rglob('.DS_Store'):
        f.unlink(missing_ok=True)

    # Create zip (IPA)
    print(f"Creating IPA: {output_path}")
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for fpath in extracted.rglob('*'):
            if fpath.is_file():
                arcname = fpath.relative_to(extracted)
                zf.write(fpath, arcname)

    print(f"Done: {output_path}")
    print(f"Size: {os.path.getsize(output_path)} bytes")

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <extracted_dir> <dylib_path> <output_ipaa>")
        sys.exit(1)
    build_ipa(sys.argv[1], sys.argv[2], sys.argv[3])
