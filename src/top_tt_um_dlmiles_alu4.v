`default_nettype none

//// uio_out
// uio_out[7:0] n/c

//// uio_in
// uio_in[5:0] a
`define UI0_CARRY_BITID 0
`define UI1_BINV_BITID 1
// 6 bits width
`define UI2_OP_BITID 2

`define OP_WIDTH 6

// uio_in[3:2]
`define OP_A_0_SUM    0
`define OP_A_1_OR     1
`define OP_A_2_AND    2
`define OP_A_3_XOR    3
// uio_in[5:4]
`define OP_Y_0_NORMAL 0
`define OP_Y_1_LSB    1
`define OP_Y_2_RESET  2
`define OP_Y_3_MSB    3
// uio_in[7:6]
`define OP_B_0_NORMAL 0
`define OP_B_1_ONE    1
`define OP_B_2_RESET  2
`define OP_B_3_LSR    3


//// ui_in
// ui_in[3:0] a
// ui_in[7:4] b

// uo_out
`define O5_OVERFLOW_BITID 5
`define O6_ZERO_BITID 6
`define O7_CARRYOUT_BITID 7


module tt_um_dlmiles_alu4 (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    localparam WIDTH = 4;
    localparam MSB = WIDTH-1;

    // backtick notation is not nice to work with, so making it a localparam let us use it without backtick :)
    localparam OP_WIDTH           = `OP_WIDTH;

    localparam UI0_CARRY_BITID    = `UI0_CARRY_BITID;
    localparam UI1_BINV_BITID     = `UI1_BINV_BITID;
    localparam UI2_OP_BITID       = `UI2_OP_BITID;

    localparam O5_OVERFLOW_BITID  = `O5_OVERFLOW_BITID;
    localparam O6_ZERO_BITID      = `O6_ZERO_BITID;
    localparam O7_CARRYOUT_BITID  = `O7_CARRYOUT_BITID;

    // bidirectionals fixed direction
    //  0  nc (set as input)
    //  1  nc (set as input)
    //  2  nc (set as input)
    //  3  nc (set as input)
    //  4  nc (set as input)
    //  5  nc (set as input)
    //  6  nc (set as input)
    //  7  nc (set as input)
    assign uio_oe = 8'b00000000;

    assign uio_out = 8'b00000000;	// n/c tie-down

    wire [WIDTH-1:0]        a;
    wire [WIDTH-1:0]        b;
    wire                    b_inv;
    wire                    y;
    wire [OP_WIDTH-1:0]     op;

    assign a      = ui_in[0 +: WIDTH];
    assign b      = ui_in[WIDTH +: WIDTH];
    assign y      = uio_in[UI0_CARRY_BITID];
    assign b_inv  = uio_in[UI1_BINV_BITID];
    assign op     = uio_in[UI2_OP_BITID +: OP_WIDTH];

    // setup nets for outputs
    wire              overflow;
    wire              zero;
    wire              c;
    wire [WIDTH-1:0]  s;


    // FIXME experiment if zero->lsr->inv is a better order


    // CARRY_IN (control)
    wire              y_after_op;

    wire              y_after_op_NORMAL;
    wire              y_after_op_ONE;
    wire              y_after_op_ZERO;
    wire              y_after_op_MSB;
    wire              y_after_op_LSB;

    assign y_after_op_NORMAL = y;
    assign y_after_op_ONE    = 1'b1;
    assign y_after_op_ZERO   = 1'b0;
    assign y_after_op_MSB    = a[MSB];	// ASR, ROL?, set-sign-from-carry
    assign y_after_op_LSB    = a[0];	// ROR?

    wire              y_after_op_MSBLSB;

    // lets see if we can use this b_inv control bit more
    assign y_after_op_MSBLSB = b_inv ? y_after_op_LSB : y_after_op_MSB;

    assign y_after_op = op[3] ?
      (op[2] ? y_after_op_MSBLSB : y_after_op_ZERO) :	// 2'b11  :  2'b10
      (op[2] ? y_after_op_ONE    : y_after_op_NORMAL)	// 2'b01  :  2'b00
    ;


    // B operand (control)
    wire [WIDTH-1:0]  b_after_op;

    wire [WIDTH-1:0]  b_after_op_NORMAL;
    wire [WIDTH-1:0]  b_after_op_LSB;
    wire [WIDTH-1:0]  b_after_op_CLEAR;
    wire [WIDTH-1:0]  b_after_op_LSR;		// not used

    assign b_after_op_NORMAL = b;
    // This is interesting, we needed the value ONE (at B) mainly for DECREMENT (while also
    //   making the CARRY_IN=1 and Binvert) but at that time the CARRY_IN is always set
    // INCREMENT-by-ONE is easier by using the CARRY_IN to provide +1.
    assign b_after_op_LSB    = {{WIDTH-1{1'b0}},y_after_op};
    // So can we remove CLEAR and use LSB above when freeing up a mode? 
    assign b_after_op_CLEAR  = {WIDTH{1'b0}};
    //assign b_after_op_LSR    = {y_after_op,b[WIDTH-1:1]};	// not used

    ///wire           b_after_op_LSLLSR;

    // When in LSLLSR mode want:
    //  ROR: CLEAR to invert to 0xff op=AND  (b_mode=LSLLSR, y_mode=MSBLSB,        b_inv=1)
    //  ASR: CLEAR to 0x00 op=OR             (b_mode=LSLLSR, y_mode=MSBLSB,        b_inv=0)
    //  LSR: CLEAR to 0x00 op=OR             (b_mode=LSLLSR, y_mode=NORM|ZERO|ONE, b_inv=0)
    //  ROL: n/a op=SUM(add) with A==B Y=MSB (b_mode=NORM,   y_mode=MSBLSB,        b_inv=0)
    //  LSL: n/a op=SUM(add) with A==B and Y (b_mode=NORM,   y_mode=NORM|ZERO|ONE, b_inv=0)
    ///assign b_after_op_LSLLSR = b_inv ? b_after_op_CLEAR : b_after_op_NORMAL;

    // TODO optimize this order, seems arbitrary, 2'b11 case is attached to special handling of a_after_op
    assign b_after_op = op[5] ?
      (op[4] ? b_after_op_CLEAR  : b_after_op_CLEAR) :     // 2'b11  :  2'b10
      (op[4] ? b_after_op_LSB    : b_after_op_NORMAL)      // 2'b01  :  2'b00
    ;

    // A operand (control)
    wire [WIDTH-1:0]  a_after_op;

    wire [WIDTH-1:0]  a_after_op_LSR;

    assign a_after_op_LSR    = {y_after_op,a[WIDTH-1:1]};

    assign a_after_op = (op[4] & op[5]) ? a_after_op_LSR : a;	// when shifting: special case


    alu4 #(
        .WIDTH     (WIDTH)
    ) alu4 (
        .s         (s),         // o
        .c         (c),         // o
        .zero      (zero),      // o
        .overflow  (overflow),  // o

        .a         (a_after_op),// i
        .b         (b_after_op),// i
        .b_inv     (b_inv),     // i
        .y         (y_after_op),// i
        .op        (op[1:0])    // i
    );

    assign uo_out[WIDTH-1:0]         = s;
    assign uo_out[4:WIDTH]           = 1'b0;  // unused tie-down
    assign uo_out[O5_OVERFLOW_BITID] = overflow;
    assign uo_out[O6_ZERO_BITID]     = zero;
    assign uo_out[O7_CARRYOUT_BITID] = c;

endmodule
