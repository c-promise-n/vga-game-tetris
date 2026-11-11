`timescale 1ns / 1ps
// Palette testbench: all 16 color indices and their 12-bit RGB values
module palette_tb;

    reg [3:0] index;
    wire [11:0] rgb;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg [11:0] exp [0:15];

    palette dut (
        .index(index),
        .rgb(rgb)
    );

    task check(input [8*40-1:0] name, input integer got, input integer exp_val);
        begin
            checks = checks + 1;
            if (got !== exp_val) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL %0s: got %0h, expected %0h", name, got, exp_val);
            end
        end
    endtask

    initial begin
        #1000;
        $display("FAIL palette_tb: timeout");
        $finish;
    end

    initial begin
        exp[0]  = 12'h112;
        exp[1]  = 12'h336;
        exp[2]  = 12'h0DD;
        exp[3]  = 12'hFD3;
        exp[4]  = 12'hA4E;
        exp[5]  = 12'h3D7;
        exp[6]  = 12'hF45;
        exp[7]  = 12'h37F;
        exp[8]  = 12'hF91;
        exp[9]  = 12'hFFF;
        exp[10] = 12'h003;
        exp[11] = 12'h159;
        exp[12] = 12'hFFB;
        exp[13] = 12'h66A;
        exp[14] = 12'h002;
        exp[15] = 12'h000;

        index = 4'h0;
        #1;
        for (i = 0; i < 16; i = i + 1) begin
            index = i[3:0];
            #1;
            checks = checks + 1;
            if (rgb !== exp[i]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL palette index %0d: got %0h, expected %0h", i, rgb, exp[i]);
            end
        end

        // unknown index must resolve to black
        index = 4'bxxxx;
        #1;
        check("palette x index", rgb, 12'h000);

        if (errors == 0)
            $display("PASS palette_tb (%0d checks)", checks);
        else
            $display("FAIL palette_tb (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

endmodule
