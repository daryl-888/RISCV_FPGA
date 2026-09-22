module alu_tb;
    timeunit 1ns;
    timeprecision 1ps;
    logic [31:0] a, b, result;
    logic [3:0] op;
    int checks = 0;
    alu dut (.*);

    task automatic check(input logic [3:0] operation,
                         input logic [31:0] left, right, expected);
        op = operation;
        a = left;
        b = right;
        #1;
        if (result !== expected)
            $fatal(1, "op=%0d a=%08x b=%08x expected=%08x got=%08x",
                   op, a, b, expected, result);
        checks++;
    endtask

    initial begin
        if ($test$plusargs("trace")) begin
            $dumpfile("build/waves/alu.vcd");
            $dumpvars(0, alu_tb);
        end
        check(0, 32'd7, 32'd5, 32'd12);
        check(0, 32'hffffffff, 32'd1, 32'd0);
        check(0, 32'h7fffffff, 32'd1, 32'h80000000);
        check(1, 32'd0, 32'd1, 32'hffffffff);
        check(1, 32'd12, 32'd5, 32'd7);
        check(2, 32'hf0f0f0f0, 32'h0ff00ff0, 32'h00f000f0);
        check(3, 32'hf0f0f0f0, 32'h0ff00ff0, 32'hfff0fff0);
        check(4, 32'haaaaaaaa, 32'h55555555, 32'hffffffff);
        check(5, 32'hffffffff, 32'd1, 32'd1);
        check(5, 32'h80000000, 32'h7fffffff, 32'd1);
        check(5, 32'd1, 32'hffffffff, 32'd0);
        check(5, 32'd3, 32'd3, 32'd0);
        check(6, 32'hffffffff, 32'd1, 32'd0);
        check(6, 32'd1, 32'hffffffff, 32'd1);
        check(7, 32'd1, 32'd31, 32'h80000000);
        check(7, 32'd1, 32'd32, 32'd1);
        check(8, 32'h80000000, 32'd1, 32'h40000000);
        check(9, 32'h80000000, 32'd1, 32'hc0000000);
        check(9, 32'h80000000, 32'd31, 32'hffffffff);
        check(9, 32'h80000000, 32'd32, 32'h80000000);
        check(15, 32'hffffffff, 32'hffffffff, 32'd0);
        $display("PASS: %0d ALU checks", checks);
        $finish;
    end
endmodule
