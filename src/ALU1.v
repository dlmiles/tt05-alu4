//
//
//
//
//
//

module ALU1 (
  output wire        s,       // operation sum
  output wire        c,       // carry-out (only for sumation)

  input  wire        a,
  input  wire        b,
  //input  wire        b_zero,  // force b input to zero
  input  wire        b_inv,   // invert b path
                              // effective_b = (b_inv ? (b_zero ? 0 : b)
                              // i z b  effective_b  (b_inv, b_zero, b)
                              // 0 0 0  0  normal
                              // 0 0 1  1  normal
                              // 0 1 0  0  forced to 0
                              // 0 1 0  0  forced to 0
                              // 1 0 0  1  inverted
                              // 1 0 1  0  inverted
                              // 1 1 0  1  forced to 1
                              // 1 1 1  1  forced to 1
                              
  input  wire        y,       // carry-in (only for sumation, input only affects carry-out state)

  input  wire  [1:0] op       // operation mode:
                              // 2'b00 = SUM (addition)
                              // 2'b01 = AND (logical and)
                              // 2'b10 = OR  (logical or)
                              // 2'b11 = XOR (logical exclusive-or)
  // Side note, I ask myself the question, "does the op order matter?" I come up with
  // maybe we reduce the number of bit transitions needed to change state between
  // the most popular operations and we put the most popular operation on the
  // dominanant/easier gate state.
  // So lets say the most dominant gate state is 2'b00 as it is easier to pull-down
  // than to pull-up (climb the capacitance hill) and maintain against leakage.
  // So I run objdump -d on a few executables to establish what base operations are
  // used most often in real code.  If I remove XOR to zero a register on i686/x86_64
  // the order came back ADD/SUB (most used), AND, OR, XOR (least used).
  // In my experience this makes sense (plus the adder is used inside the CPU for
  // many other things target address computation, increment/decrement, etc...)
  // Then AND is used for bitmask isolation, condition testing, computing products
  // all on read operations so it also makes sense at rank number 2.  While the OR
  // and XOR are generally involved in a write operation (a less common task of a CPU,
  // than read and interpretion of data).
  // So finally which order to put the two operations OR, AND, we have a single bit
  // transition from the most popular resolved.  We specify explicitly the MUX2 layout
  // and the resulting network is a 4-to-1 made out of 3 x MUX2s.  So lets put the most
  // popular (SUM) and next most popular (AND) switchable by only changing state at one
  // MUX (the one nearest the output pin 's').
  // This decision process maybe based on folklore but at least there is a story to it
  // with a method, and the synthesis tool might tear it all up anyway.
  // So that set the order I choose.
);

  // This ALU has a Full Adder but the logic lines are fetched out to
  //   obtain access for other logic operations
  // The Binv was added for subtraction (already had carry_in).
  // The OR_AB was added to complete the logic set (also priving 4 outputs now
  //   a nice round number of full utilization of MUX2s).
  // The Bzero was added for utility (allowing all zeros, all ones)

  // The intention here is to help out the synthesis, but maybe synthesis is
  //   so good already it can optimize through it anyway.  So it is expected
  //   to have low gate/cell count for
  
  // The arrangment allows the following operations to occur:
  //   AND
  //   OR
  //   XOR
  //   one's complement (invert)
  //   two's complement (negate)
  //   addition (without carry)
  //   addition (with carry)
  //   subtraction (without borrow)
  //   subtraction (with borrow)
  //   clear-bits (AND Binv)
  //   set-inverted-bits (OR Binv) maybe not that useful ?
  //   toggle-inverted-bits (XOR Binv) maybe not that useful ?
  //   logical-shift-left (ADD where A and B are identical, output bit is in carry_out)
  // from 4 bits of OP_CONTRL


  // resolve effective_b first action: b_zero
  wire b_with_zero;
  assign b_with_zero = /*b_zero ? 1'b0 : */ b;

  // resolve effective_b second action: invert
  wire effective_b;
  assign effective_b = b_inv ? ~b_with_zero : b_with_zero;	// b_inv XOR b_with_zero

  wire or_ab;
  assign or_ab = a | effective_b;

  wire and_ab;
  assign and_ab = a & effective_b;

  wire xor_ab;
  assign xor_ab = a ^ effective_b;

  // Half Adder
  wire ha_mid_carry;	// and_y_xor_ab
  assign ha_mid_carry = xor_ab & y;	// and_ab AND carry_in
  wire ha_s;
  assign ha_s = xor_ab ^ y;		// xor_ab XOR carry_in
  wire ha_c;
  assign ha_c = and_ab | ha_mid_carry;	// and_ab AND mid
  
  // We control the MUX order in verilog, maybe there is a reason to use a different op mapping
  wire s_sum_or;
  assign s_sum_or = op[1] ? or_ab : ha_s;
  wire s_and_xor;
  assign s_and_xor = op[1] ? xor_ab : and_ab;

  // finally
  assign s = op[0] ? s_and_xor : s_sum_or;
  assign c = ha_c;

endmodule

