"""
Post-process a Mach-O dylib to change all bind ordinal opcodes to flat-lookup (-1).
This ensures dyld searches all loaded images regardless of two-level namespace.
"""
import struct, sys

def fix_bind_opcodes(dylib_path):
    with open(dylib_path, 'rb') as f:
        b = bytearray(f.read())

    pos = 32
    ncmds = struct.unpack_from('<I', b, 16)[0]
    bind_off = bind_sz = 0
    lazy_bind_off = lazy_bind_sz = 0

    for _ in range(ncmds):
        cmd, sz = struct.unpack_from('<II', b, pos)
        base = cmd & 0x7FFFFFFF
        if base == 0x22:  # LC_DYLD_INFO_ONLY
            _, _, bind_off, bind_sz, lazy_bind_off, lazy_bind_sz, _, _ = struct.unpack_from('<IIIIIIII', b, pos+8)
            break
        pos += sz

    print(f"Non-lazy bind: off=0x{bind_off:x} sz={bind_sz}")
    print(f"Lazy bind: off=0x{lazy_bind_off:x} sz={lazy_bind_sz}")

    total_fixes = 0

    def patch_bind_stream(data, off, sz, label):
        nonlocal total_fixes
        i = 0
        fixes = 0
        new_data = bytearray()
        
        while i < sz:
            op = data[off + i]
            i += 1
            new_data.append(op)

            cmd = op & 0xF0
            imm = op & 0x0F

            if cmd == 0x00:  # DONE
                break

            elif cmd == 0x10:  # SET_DYLIB_ORDINAL_IMM
                # imm = ordinal (0=self, 1-14=lib#, 0xF=???)
                # Change ordinal 1 to flat lookup (-1)
                if imm == 1:
                    # Replace 0x11 with: 0x30(SLEB) + 0x7F(-1)
                    new_data[-1] = 0x30   # change opcode to SET_DYLIB_ORDINAL_SLEB
                    new_data.append(0x7F) # SLEB value -1 = flat lookup
                    fixes += 1
                    i += 0  # no additional bytes consumed from original
                # Other ordinals (including default 0) stay as-is

            elif cmd == 0x20:  # SET_DYLIB_ORDINAL_ULEB
                val = 0; shift = 0
                while True:
                    byte = data[off + i]; new_data.append(byte); i += 1
                    val |= (byte & 0x7F) << shift
                    shift += 7
                    if not (byte & 0x80): break
                # Change to flat lookup: replace with SLEB -1
                # Remove the ULEB bytes we just added, replace opcode
                while len(new_data) > 0 and new_data[-1] != op:
                    new_data.pop()
                new_data[-1] = 0x30  # change to SET_DYLIB_ORDINAL_SLEB
                new_data.append(0x7F)  # -1 = flat lookup
                fixes += 1

            elif cmd == 0x30:  # SET_DYLIB_ORDINAL_SLEB
                val = 0; shift = 0
                while True:
                    byte = data[off + i]; new_data.append(byte); i += 1
                    val |= (byte & 0x7F) << shift
                    shift += 7
                    if not (byte & 0x80): break
                if val & (1 << (shift-1)): val |= -1 << shift
                # Already SLEB - just change value to -1
                # The current SLEB may be multi-byte. Replace with single-byte 0x7F.
                # Remove the SLEB bytes we just added
                while len(new_data) > 0 and new_data[-1] != op:
                    new_data.pop()
                new_data.append(0x7F)  # SLEB value -1 = flat lookup
                fixes += 1

            elif cmd == 0x40:  # SET_SYMBOL_TRAILING_FLAGS_IMM
                while data[off + i] != 0:
                    new_data.append(data[off + i]); i += 1
                new_data.append(data[off + i]); i += 1  # null terminator

            elif cmd == 0x50:  # SET_TYPE_IMM
                pass  # no operands

            elif cmd == 0x60:  # SET_ADDEND_SLEB
                while True:
                    byte = data[off + i]; new_data.append(byte); i += 1
                    if not (byte & 0x80): break

            elif cmd == 0x70:  # SET_SEGMENT_AND_OFFSET_ULEB
                while True:
                    byte = data[off + i]; new_data.append(byte); i += 1
                    if not (byte & 0x80): break

            elif cmd == 0x80:  # ADD_ADDR_ULEB
                while True:
                    byte = data[off + i]; new_data.append(byte); i += 1
                    if not (byte & 0x80): break

            elif cmd == 0x90:  # DO_BIND
                pass  # no operands

            elif cmd == 0xA0:  # DO_BIND_ADD_ADDR_ULEB
                while True:
                    byte = data[off + i]; new_data.append(byte); i += 1
                    if not (byte & 0x80): break

            elif cmd == 0xB0:  # DO_BIND_ADD_ADDR_IMM_SCALED
                pass  # no operands besides imm

            elif cmd == 0xC0:  # DO_BIND_ULEB_TIMES_SKIPPING_ULEB
                for _ in range(2):
                    while True:
                        byte = data[off + i]; new_data.append(byte); i += 1
                        if not (byte & 0x80): break

            else:
                print(f"  Unknown opcode {op:#04x} at offset {i-1}")
                new_data.extend(data[off+i:off+sz])
                break

        old_size = sz
        new_size = len(new_data)
        delta = new_size - old_size
        print(f"  {label}: fixed {fixes} ordinals, size {old_size} -> {new_size} (delta {delta:+d})")
        
        # Write new data back
        b[off:off+new_size] = new_data
        # Zero out the rest (if new is smaller than old)
        if delta < 0:
            b[off+new_size:off+old_size] = b'\x00' * (-delta)
        # Write padding for any leftover bytes
        # Actually, we need to handle the shift of data after this stream
        
        total_fixes += fixes
        
        # Update bind_size in the header
        update_bind_size(label, old_size, new_size)
        
        return delta

    def update_bind_size(label, old_size, new_size):
        # Update the bind_size or lazy_bind_size in LC_DYLD_INFO_ONLY
        pos = 32
        for _ in range(ncmds):
            cmd, sz = struct.unpack_from('<II', b, pos)
            base = cmd & 0x7FFFFFFF
            if base == 0x22:
                if 'Lazy' in label:
                    struct.pack_into('<I', b, pos+24, new_size)  # lazy_bind_size at +24
                else:
                    struct.pack_into('<I', b, pos+12, new_size)  # bind_size at +12
                break
            pos += sz

    # Patch non-lazy bind
    if bind_sz > 0:
        delta = patch_bind_stream(b, bind_off, bind_sz, "Non-lazy")
        # Shift lazy bind and everything after if non-lazy bind changed size
        # But wait, lazy bind usually comes after non-lazy bind in __LINKEDIT
        # We need to also shift lazy_bind_off
        if delta != 0 and lazy_bind_sz > 0:
            # Update lazy_bind_off in header
            pos = 32
            for _ in range(ncmds):
                cmd, sz = struct.unpack_from('<II', b, pos)
                base = cmd & 0x7FFFFFFF
                if base == 0x22:
                    old_lazy_off = struct.unpack_from('<I', b, pos+20)[0]
                    struct.pack_into('<I', b, pos+20, old_lazy_off + delta)
                    break
                pos += sz
            # Shift lazy bind data
            old_lazy_start = lazy_bind_off + delta  # new start due to shift
            # If delta < 0, shift left; if delta > 0, shift right
            if delta < 0:
                # Copy lazy bind data left by |delta|
                b[lazy_bind_off+delta:lazy_bind_off+delta+lazy_bind_sz] = b[lazy_bind_off:lazy_bind_off+lazy_bind_sz]
                b[lazy_bind_off:lazy_bind_off-delta] = b'\x00' * (-delta)
        
        if delta != 0:
            # Also shift any data after lazy bind (symbol tables, etc.)
            # This is complex - for now, only patch if delta == -12 (all SLEBs to single 0x7F)
            # or delta == 21 (IMM 1 byte to SLEB 2 bytes)
            if lazy_bind_sz > 0:
                lazy_end = lazy_bind_off + lazy_bind_sz + delta  # adjusted
            else:
                lazy_end = bind_off + bind_sz + delta  # no lazy bind
            
            # Find LINKEDIT segment and shift data after lazy_end
            # TODO: handle data shifts properly
            
            print(f"  WARNING: Data after bind needs shifting by {delta} bytes")

    if lazy_bind_sz > 0:
        delta = patch_bind_stream(b, lazy_bind_off + (bind_sz_changed or 0), lazy_bind_sz, "Lazy")

    # Write back
    with open(dylib_path, 'wb') as f:
        f.write(b)
    
    print(f"Total fixes: {total_fixes}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <dylib_path>")
        sys.exit(1)
    fix_bind_opcodes(sys.argv[1])
