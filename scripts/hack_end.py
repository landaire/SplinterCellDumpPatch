import ida_dbg, ida_idd, ida_kernwin, ctypes, time

flags=ida_dbg.get_reg_val("eax")
linker=ida_dbg.get_reg_val("edi")

filename = int.from_bytes(ida_idd.dbg_read_memory(linker + 0x98, 4), "little")

p=filename
s=b""
while True:
    c = ida_idd.dbg_read_memory(p,2)
    if not c or c == b"\x00\x00": break
    s += c; p+=2

ida_kernwin.msg("Save File: " + "flags=" + hex(flags) + " filename=" + s.decode('utf-16-le')+"\n")
