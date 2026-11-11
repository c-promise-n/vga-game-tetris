`timescale 1ns / 1ps
//  print the 28 shape masks as 4x4 dot matrices
module tb_shape_rom;

    reg  [2:0] bt;
    reg  [2:0] rt;
    reg  [2:0] row;
    reg  [2:0] col;
    wire [15:0] mask;
    reg  [15:0] m;

    reg [15:0] errors;
    reg [15:0] checks;

    shape_rom dut (
        .bricktype(bt),
        .rot      (rt[1:0]),
        .mask     (mask)
    );

    // piece index to its letter
    function [7:0] pname(input [2:0] t);
        case (t)
            3'd0: pname = "I";
            3'd1: pname = "O";
            3'd2: pname = "T";
            3'd3: pname = "S";
            3'd4: pname = "Z";
            3'd5: pname = "J";
            3'd6: pname = "L";
            default: pname = "?";
        endcase
    endfunction

    initial begin
        errors = 16'd0;
        checks = 16'd0;
        $display("tb_shape_rom");
        $display("shape masks: # = occupied cell, each mask is a 4x4 block (row 0 on top)");

        for (bt = 3'd0; bt < 3'd7; bt = bt + 3'd1) begin
            // check the four masks are all non-zero
            for (rt = 2'd0; rt < 3'd4; rt = rt + 2'd1) begin
                #1;
                checks = checks + 16'd1;
                if (mask == 16'h0000) begin
                    errors = errors + 16'd1;
                    $display("FAIL mask is zero: type=%0d rot=%0d", bt, rt);
                end
            end

            $write("   %c  ", pname(bt));
            for (rt = 3'd0; rt < 3'd4; rt = rt + 3'd1)
                $write("   rot%0d     ", rt);
            $display("");

            for (row = 3'd0; row < 3'd4; row = row + 3'd1) begin
                $write("       ");
                for (rt = 2'd0; rt < 3'd4; rt = rt + 2'd1) begin
                    #1;
                    m = mask;
                    $write("   ");
                    for (col = 3'd0; col < 3'd4; col = col + 3'd1) begin
                        if (m[row*4 + col])
                            $write("#");
                        else
                            $write(".");
                    end
                    $write("     ");
                end
                $display("");
            end
            $display("");
        end

        if (errors == 0)
            $display("PASS tb_shape_rom (%0d checks)", checks);
        else
            $display("FAIL tb_shape_rom (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

    initial begin
        #1000000;
        $display("FAIL tb_shape_rom: timeout");
        $finish;
    end

endmodule
