module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  op,
    output logic [31:0] result
);
    timeunit 1ns;
    timeprecision 1ps;
    // Teaching interface: this is a local control encoding, not an opcode.
    localparam logic [3:0] ADD = 4'd0, SUB = 4'd1, AND_OP = 4'd2,
        OR_OP = 4'd3, XOR_OP = 4'd4, SLT = 4'd5, SLTU = 4'd6,
        SLL = 4'd7, SRL = 4'd8, SRA = 4'd9;

    always_comb begin
        case (op)
            ADD:    result = a + b;
            SUB:    result = a - b;
            AND_OP: result = a & b;
            OR_OP:  result = a | b;
            XOR_OP: result = a ^ b;
            SLT:    result = {31'b0, ($signed(a) < $signed(b))};
            SLTU:   result = {31'b0, (a < b)};
            SLL:    result = a << b[4:0];
            SRL:    result = a >> b[4:0];
            SRA:    result = $unsigned($signed(a) >>> b[4:0]);
            default: result = 32'b0;
        endcase
    end
endmodule
