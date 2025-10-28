import ida_idd, ida_kernwin, ctypes
ebp=ida_dbg.get_reg_val("ebp")
obj_addr = int.from_bytes(ida_idd.dbg_read_memory(ebp - 0x18, 4), "little")

if obj_addr == 0:
    ida_kernwin.msg("no obj\n")
    return True

p = int.from_bytes(ida_idd.dbg_read_memory(obj_addr + 0x98, 4), "little")

s=b""
while True:
    c = ida_idd.dbg_read_memory(p,2)
    if not c or c == b"\x00\x00": break
    s += c; p+=2

ida_kernwin.msg("ULinkerLoad: " + s.decode('utf-16-le')+"\n")

return True
