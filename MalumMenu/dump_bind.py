"""Dump bind opcodes from a Mach-O dylib"""
import struct, sys

path = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\Yairsabn\Documents\amg\MalumMenu\libMalumMenu.dylib"
with open(path, 'rb') as f:
    b = f.read()

magic = struct.unpack_from('<I', b, 0)[0]
assert magic == 0xFEEDFACF

pos = 32
ncmds = struct.unpack_from('<I', b, 16)[0]
bind_off = bind_sz = 0
lazy_bind_off = lazy_bind_sz = 0
export_off = export_sz = 0

for i in range(ncmds):
    cmd, sz = struct.unpack_from('<II', b, pos)
    base = cmd & 0x7FFFFFFF
    if base == 0x22:  # LC_DYLD_INFO_ONLY
        rebase_off, rebase_sz, bind_off, bind_sz, lazy_bind_off, lazy_bind_sz, export_off, export_sz = struct.unpack_from('<IIIIIIII', b, pos+8)
    pos += sz

print(f"Non-lazy bind: off={bind_off:#x} sz={bind_sz}")
print(f"Lazy bind:     off={lazy_bind_off:#x} sz={lazy_bind_sz}")
print()

def dump_bind(data, label):
    print(f"--- {label} ---")
    i = 0
    ordinal = 0
    sym_name = ""
    addend = 0
    seg_idx = 0
    seg_off = 0
    done = False
    while i < len(data) and not done:
        op = data[i]
        imm = op & 0x0F
        cmd = op & 0xF0
        desc = ""
        i += 1

        if cmd == 0x00:  # BIND_OPCODE_DONE
            desc = f"DONE at {i-1}"
            done = True
        elif cmd == 0x10:  # SET_DYLIB_ORDINAL_IMM
            ordinal = imm
            desc = f"ORDINAL_IMM = {ordinal} ({'self' if ordinal==0 else 'flat' if ordinal==0xF else ordinal-1})"
        elif cmd == 0x20:  # SET_DYLIB_ORDINAL_ULEB
            val = 0; shift = 0
            while True:
                byte = data[i]; i += 1
                val |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80): break
            ordinal = val
            desc = f"ORDINAL_ULEB = {ordinal}"
        elif cmd == 0x30:  # SET_DYLIB_ORDINAL_SLEB (actually not standard, but...)
            val = 0; shift = 0
            while True:
                byte = data[i]; i += 1
                val |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80): break
            if val & (1 << (shift-1)): val |= -1 << shift  # sign extend
            ordinal = val
            desc = f"ORDINAL_SLEB = {val}"
        elif cmd == 0x40:  # SET_DYLIB_ORDINAL_IMM
            # Actually, let me re-read. cmd=0x40 is... wait
            # 0x40 = BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM
            flags = imm
            name_bytes = []
            while i < len(data) and data[i] != 0:
                name_bytes.append(data[i]); i += 1
            sym_name = bytes(name_bytes).decode('ascii', errors='replace')
            i += 1  # skip null
            desc = f"SYMBOL = '{sym_name}' flags={flags}"
        elif cmd == 0x50:  # SET_TYPE_IMM
            desc = f"TYPE = {'pointer' if imm==1 else 'pointer64' if imm==0 else imm}"
        elif cmd == 0x60:  # SET_ADDEND_SLEB
            val = 0; shift = 0
            while True:
                byte = data[i]; i += 1
                val |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80): break
            if val & (1 << (shift-1)): val |= -1 << shift
            addend = val
            desc = f"ADDEND = {addend}"
        elif cmd == 0x70:  # SET_SEGMENT_AND_OFFSET_ULEB
            seg_idx = imm
            val = 0; shift = 0
            while True:
                byte = data[i]; i += 1
                val |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80): break
            seg_off = val
            desc = f"SEG({seg_idx}) + 0x{seg_off:x}"
        elif cmd == 0x80:  # ADD_ADDR_ULEB
            val = 0; shift = 0
            while True:
                byte = data[i]; i += 1
                val |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80): break
            seg_off += val
            desc = f"ADD_ADDR +0x{val:x} = 0x{seg_off:x}"
        elif cmd == 0x90:  # DO_BIND
            desc = f"BIND at seg({seg_idx})+0x{seg_off:x} (ordinal {ordinal}, '{sym_name}' + {addend})"
            if sym_name:
                seg_off += 8  # pointer size
        elif cmd == 0xA0:  # DO_BIND_ADD_ADDR_ULEB
            val = 0; shift = 0
            while True:
                byte = data[i]; i += 1
                val |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80): break
            desc = f"BIND + ADD_ADDR +0x{val:x} (ordinal {ordinal}, '{sym_name}' + {addend})"
            seg_off += val + 8
        elif cmd == 0xB0:  # DO_BIND_ADD_ADDR_IMM_SCALED
            desc = f"BIND + ADD_ADDR_IMM {imm}*8 (ordinal {ordinal}, '{sym_name}' + {addend})"
            seg_off += imm * 8 + 8
        elif cmd == 0xC0:  # DO_BIND_ULEB_TIMES_SKIPPING_ULEB
            count = 0; shift = 0
            while True:
                byte = data[i]; i += 1
                count |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80): break
            skip = 0; shift = 0
            while True:
                byte = data[i]; i += 1
                skip |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80): break
            desc = f"DO_BIND_TIMES {count} SKIP {skip}"
        else:
            desc = f"UNKNOWN op={op:#04x} cmd={cmd:#04x} imm={imm}"

        print(f"  [{i-1:4d}] {' '.join(f'{x:02x}' for x in data[max(0,i-5):i])} -> {desc}")

if bind_sz:
    dump_bind(b[bind_off:bind_off+bind_sz], "NON-LAZY BIND")
if lazy_bind_sz:
    dump_bind(b[lazy_bind_off:lazy_bind_off+lazy_bind_sz], "LAZY BIND")
