//
//
//
//
//

module alu4 #(
  parameter    WIDTH       = 4
) (
  output wire [WIDTH-1:0]  s,
  output wire              c,
  output wire              zero,	// sum has all bits clear
  output wire              overflow,	// the operation changed the output sign

  input wire  [WIDTH-1:0]  a,

  input wire  [WIDTH-1:0]  b,
  input wire               b_inv,

  input wire               y,		// carry-in
  
  input wire  [1:0]        op
);

  localparam MSB = WIDTH-1;

  wire [WIDTH:0] carry;	    // WIDTH+1
  assign carry[0] = y;      // anchor carry-in input

  // We have a net for sum output as we want to attach ZERO sum detect
  //   here as well as module output
  wire [WIDTH-1:0] sum;

  genvar i;
  generate for (i = 0; i < WIDTH; i = i + 1) begin : genbit
        ALU1 alu$ (
          .s      (sum[i]),     // o
          .c      (carry[i+1]), // o

          .a      (a[i]),       // i
          .b      (b[i]),       // i
          .b_inv  (b_inv),      // i
          .y      (carry[i]),   // i
          .op     (op)          // i
        );
    end
  endgenerate

  assign s = sum;
  assign c = carry[WIDTH];  // last index is carry-out

  assign zero = ~|sum;      // NOR: this "~|" is a verilog NOR reduction operator

  wire xnor_overflow;
  assign xnor_overflow = ~(a[MSB] ^ b[MSB]);    // XNOR: ~(a.msb ^ b.msb)
  assign overflow = sum[MSB] ^ xnor_overflow;   // XOR: msb ^ xnor_overflow

endmodule
