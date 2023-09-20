`default_nettype none

//// uio_out
// uio_out[7:0] n/c

//// uio_in
// uio_in[5:0] a
`define UI0_CARRY_BITID 0
`define UI1_BZERO_BITID 1
`define UI2_BINV_BITID 2
// 4 bits width
`define UI3_OP_BITID 3
`define OP_WIDTH 4
`define UI5_LSR_BITID 5

`define OP_0_NORMAL 0
`define OP_1_ONE 1
`define OP_2_RESET 2
`define OP_3_LSR 3


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

    // backtick notation is not nice to work with, so making it a localparam let us use it without backtick :)
    localparam OP_WIDTH           = `OP_WIDTH;

    localparam UI0_CARRY_BITID    = `UI0_CARRY_BITID;
    localparam UI1_BZERO_BITID    = `UI1_BZERO_BITID;
    localparam UI2_BINV_BITID     = `UI2_BINV_BITID;
    localparam UI3_OP_BITID       = `UI3_OP_BITID;
    localparam UI5_LSR_BITID      = `UI5_LSR_BITID;

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
    wire                    b_zero;
    wire                    b_lsr;
    wire                    y;
    wire [OP_WIDTH-1:0]     op;

    assign a      = ui_in[0 +: WIDTH];
    assign b      = ui_in[WIDTH +: WIDTH];
    assign y      = uio_in[UI0_CARRY_BITID];
    assign b_zero = uio_in[UI1_BZERO_BITID];
    assign b_inv  = uio_in[UI2_BINV_BITID];
    assign op     = uio_in[UI3_OP_BITID +: OP_WIDTH];
    assign b_lsr  = uio_in[UI5_LSR_BITID];

    // setup nets for outputs
    wire              overflow;
    wire              zero;
    wire              c;
    wire [WIDTH-1:0]  s;

    // FIXME experiment if zero->lsr->inv is a better order
    wire [WIDTH-1:0]  b_after_op;

    wire [WIDTH-1:0] b_after_op_NORMAL;
    wire [WIDTH-1:0] b_after_op_ONE;
    wire [WIDTH-1:0] b_after_op_CLEAR;
    wire [WIDTH-1:0] b_after_op_LSR;

    assign b_after_op_NORMAL = b;
    assign b_after_op_ONE    = {{WIDTH-1{1'b0}},1'b1};
    assign b_after_op_CLEAR  = {WIDTH{1'b0}};
    assign b_after_op_LSR    = {y,b[WIDTH-1:1]};

    assign b_after_op = op[3] ?
      (op[2] ? b_after_op_LSR : b_after_op_CLEAR) :     // 2'b11  :  2'b10
      (op[2] ? b_after_op_ONE : b_after_op_NORMAL)      // 2'b01  :  2'b00
    ;

//    wire [1:0] op_b_mode;
//    assign op_b_mode = op[3:2];
//
//    always @(op_b_mode/* or b or y*/) begin
//       case (op_b_mode)
//          // NORMAL
//          2'b00: b_after_op <= b;
//          // ONE (value 0x01)
//          2'b01: b_after_op <= {{WIDTH-1{1'b0}},1'b1};
//          // CLEAR (all bits clear)
//          2'b10: b_after_op <= {WIDTH{1'b0}};
//          // LSR (logical-shift-right)
//          2'b11: b_after_op <= {y,b[WIDTH-1:1]};
//       endcase
//    end
    //assign b_after_op = b_lsr ? {y,b[WIDTH-1:1]} : b;

    alu4 #(
        .WIDTH     (WIDTH)
    ) alu4 (
        .s         (s),         // o
        .c         (c),         // o
        .zero      (zero),      // o
        .overflow  (overflow),  // o

        .a         (a),         // i
        .b         (b_after_op),// i
        .b_zero    (1'b0),      // i (was: b_zero, redundant feature, set op[1:0] = 2'b10)
        .b_inv     (b_inv),     // i
        .y         (y),         // i
        .op        (op[1:0])    // i
    );

    assign uo_out[WIDTH-1:0]         = s;
    assign uo_out[4:WIDTH]           = 1'b0;  // unused tie-down
    assign uo_out[O5_OVERFLOW_BITID] = overflow;
    assign uo_out[O6_ZERO_BITID]     = zero;
    assign uo_out[O7_CARRYOUT_BITID] = c;

endmodule
