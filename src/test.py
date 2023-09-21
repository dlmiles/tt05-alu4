import cocotb
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

OP_A_MASK   = 0x0c	# 0x08|0x04
OP_Y_MASK   = 0x30	# 0x80|0x40
OP_B_MASK   = 0xc0

OP_A_SUM    = 0x00
OP_A_OR     = 0x04
OP_A_AND    = 0x08
OP_A_XOR    = 0x0c

OP_Y_NORM   = 0x00
OP_Y_SET    = 0x10
OP_Y_CLEAR  = 0x20
OP_Y_MSB    = 0x30

OP_B_NORM   = 0x00
OP_B_ONELSB = 0x40
OP_B_CLEAR  = 0x80
OP_B_LSR    = 0xc0




def report(dut, ui_in, uio_in):
    uio_out = dut.uio_out.value
    uo_out = dut.uo_out.value

    s_eover = 'EOVER' if(uo_out.is_resolvable and uo_out & 0x20) else '     '
    s_ezero = 'EZERO' if(uo_out.is_resolvable and uo_out & 0x40) else '     '
    s_carry = 'CARRY' if(uo_out.is_resolvable and uo_out & 0x80) else '     '
    carry_out = True  if(uo_out.is_resolvable and uo_out & 0x80) else False


    carry_in = True if(uio_in.is_resolvable and uio_in & 0x01) else False
    binv     = True if(uio_in.is_resolvable and uio_in & 0x02) else False
    ymnorm   = True if(uio_in.is_resolvable and uio_in & OP_Y_MASK == OP_Y_NORM)   else False
    ymset    = True if(uio_in.is_resolvable and uio_in & OP_Y_MASK == OP_Y_SET)    else False
    ymclear  = True if(uio_in.is_resolvable and uio_in & OP_Y_MASK == OP_Y_CLEAR)  else False
    ymmsb    = True if(uio_in.is_resolvable and uio_in & OP_Y_MASK == OP_Y_MSB)    else False
    bmnorm   = True if(uio_in.is_resolvable and uio_in & OP_B_MASK == OP_B_NORM)   else False
    bmone    = True if(uio_in.is_resolvable and uio_in & OP_B_MASK == OP_B_ONELSB) else False
    bmclear  = True if(uio_in.is_resolvable and uio_in & OP_B_MASK == OP_B_CLEAR)  else False
    bmlsr    = True if(uio_in.is_resolvable and uio_in & OP_B_MASK == OP_B_LSR)    else False

    s_op_kind = ''
    s_op_kind += 'C ' if carry_in else '  '
    s_op_kind += 'BI' if binv else '  '

    s_op_ymode = ''
    if ymnorm:
        s_op_ymode = 'NORM '
    elif ymset:
        s_op_ymode = 'SET  '
    elif ymclear:
        s_op_ymode = 'CLEAR'
    elif ymmsb:
        s_op_ymode = 'MSB  '

    s_op_bmode = ''
    if bmnorm:
        s_op_bmode = 'NORM '
    elif bmone:
        s_op_bmode = 'ONE  '
    elif bmclear:
        s_op_bmode = 'CLEAR'
    elif bmlsr:
        s_op_bmode = 'LSR  '

    if uio_in & OP_A_MASK == 0x00:
        s_op = 'SUM'
        s_op_symbol = '+'
        if binv & carry_in:
            s_op = 'SUB'
            s_op_symbol = '-'
    elif uio_in & OP_A_MASK == 0x04:
        s_op = 'AND'
        s_op_symbol = '&'
    elif uio_in & OP_A_MASK == 0x08:
        s_op = 'OR'
        s_op_symbol = '|'
    else: # OP_A_MASK
        s_op = 'XOR'
        s_op_symbol = '^'

    a = ui_in & 0xf
    b = (ui_in >> 4) & 0xf
    s = int(uo_out & 0xf)
    a_signed = a if(a < 8) else a - 16
    b_signed = b if(b < 8) else b - 16
    s_signed = s if(s < 8) else s - 16

    a16 = a & 0xf
    b16 = b & 0xf
    s16 = s & 0xf

    s_extra = ''
    if s16 == ~a16:
        s_extra += 'ONE(a)'	# ones
    if s16 == -a16:
        s_extra += 'TWO(a)'	# twos
    if s16 == ~b16:
        s_extra += 'ONE(b)'
    if s16 == -b16:
        s_extra += 'TWO(b)'
    if s16 == a16 & ~b16 and a16 & b16 == b16:
        s_extra += 'CLB(b)'	# clear bits (full)
    elif s16 == a16 & ~b16 and a16 & b16 != 0:
        s_extra += 'clb(b)'	# clear bits
    if s16 == a16 ^ ~b16:
        s_extra += 'TOB(b)'	# toggle bits inverted
    if s16 == a16 | ~b16:
        s_extra += 'SEB(b)'	# set bits inverted
    if s16 == a16 >> 1 and carry_out == a16 & 0x1 != 0:
        s_extra += '>>1(a)'
    elif s16 == a16 >> 1:
        s_extra += '>>(a)'
    if s16 == a16 << 1 and carry_out == a16 & 0x8 != 0:
        s_extra += '<<1(a)'
    elif s16 == a16 << 1:
        s_extra += '<<(a)'
    if s16 == a16:
        s_extra += 'EQ(a)'
    if s16 == b16:
        s_extra += 'EQ(b)'
    if s16 == 0xf:
        s_extra += '111()'

    dut._log.info(f"in={str(ui_in)} {str(uio_in)}  out={str(uo_out)} {str(uio_out)}   {s_op_kind} {s_op} {s_op_ymode} {s_op_bmode} {a:3d} {s_op_symbol} {b:3d} [{a_signed:4d} {s_op_symbol} {b_signed:4d}]  =  {s:3d} [{s_signed:4d}] {s_carry} {s_ezero} {s_eover} {s_extra}")


@cocotb.test()
async def test_alu(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    await ClockCycles(dut.clk, 2)	# show X

    # ena=0 state
    dut.ena.value = 0
    dut.rst_n.value = 0
    dut.clk.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 2)	# show muted inputs ena=0

    dut._log.info("ena (active)")
    dut.ena.value = 1		# ena=1
    await ClockCycles(dut.clk, 2)

    dut._log.info("reset (inactive)")
    dut.rst_n.value = 1		# come out of reset
    await ClockCycles(dut.clk, 2)

    A_MODES = [
        OP_A_SUM, OP_A_OR, OP_A_AND, OP_A_OR
    ]

    YB_MODES = [
        OP_Y_NORM|OP_B_NORM,   OP_Y_SET|OP_B_NORM,    OP_Y_CLEAR|OP_B_NORM,   OP_Y_MSB|OP_B_NORM,
        OP_Y_NORM|OP_B_ONELSB, OP_Y_SET|OP_B_ONELSB,  OP_Y_CLEAR|OP_B_ONELSB, OP_Y_MSB|OP_B_ONELSB,
        OP_Y_NORM|OP_B_CLEAR,  OP_Y_SET|OP_B_CLEAR,   OP_Y_CLEAR|OP_B_CLEAR,  OP_Y_MSB|OP_B_CLEAR,
        OP_Y_NORM|OP_B_LSR,    OP_Y_SET|OP_B_LSR,     OP_Y_CLEAR|OP_B_LSR,    OP_Y_MSB|OP_B_LSR
    ]

    # SUM XOR AND OR
    for uio_in_op in A_MODES:
        # NOR Bzero Binv Bzero&Binv ... Bnorm Bone Bclear Blsr
        for uio_in_mode in YB_MODES:
            for uio_in_carry in [0, 1]:	# uio_in bit0
                uio_in = uio_in_carry
                uio_in |= uio_in_mode
                uio_in |= uio_in_op
                dut.uio_in.value = uio_in

                for ui_in in range(255+1):
                    dut.ui_in.value = ui_in

                    await ClockCycles(dut.clk, 2)
                    report(dut, BinaryValue(ui_in, bigEndian=False, n_bits=8), BinaryValue(uio_in, bigEndian=False, n_bits=8))
