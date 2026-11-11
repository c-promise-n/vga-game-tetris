`timescale 1ns / 1ps
// check all 37 glyphs and print five as real
// 8x8 matrices (report figure 6). Each glyph is printed as eight rows of eight
// characters instead of one long line, which is far easier to read.
module tb_font_rom;

    reg  [5:0] char_code;
    reg  [2:0] glyph_row;
    wire [7:0] row_bits;

    reg [5:0] cd;
    reg [3:0] rw;
    reg [3:0] cx;
    reg [2:0] gi;
    reg [15:0] errors;
    reg [15:0] checks;
    reg [7:0] rows [0:7];
    reg [5:0] gcodes [0:4];

    font_rom dut (
        .char_code (char_code),
        .glyph_row (glyph_row),
        .row_bits  (row_bits)
    );

    task check(input [8*44-1:0] name, input [15:0] got, input [15:0] exp);
        begin
            checks = checks + 16'd1;
            if (got !== exp) begin
                errors = errors + 16'd1;
                $display("FAIL %0s : got %0d, expected %0d", name, got, exp);
            end
        end
    endtask

    initial begin
        errors = 16'd0;
        checks = 16'd0;
        $display("tb_font_rom");
        $display("check all 37 glyphs, print A / T / S / 0 / 9 as 8x8 matrices (# = on)");

        // check every glyph
        for (cd = 6'd0; cd < 6'd37; cd = cd + 6'd1) begin
            for (rw = 4'd0; rw < 4'd8; rw = rw + 4'd1) begin
                char_code = cd;
                glyph_row = rw[2:0];
                #1;
                rows[rw] = row_bits;
            end
            check("row7 blank", rows[3'd7], 8'h00);
            if (cd == 6'd0)
                check("space all blank",
                      (rows[0] | rows[1] | rows[2] | rows[3] |
                       rows[4] | rows[5] | rows[6]), 8'h00);
            else
                check("glyph non-empty",
                      ((rows[0] | rows[1] | rows[2] | rows[3] |
                        rows[4] | rows[5] | rows[6]) != 8'h00) ? 16'd1 : 16'd0, 16'd1);
        end
        $display("%0d glyph checks done", checks);

        // print five representative glyphs
        gcodes[0] = 6'd1;    // A
        gcodes[1] = 6'd20;   // T
        gcodes[2] = 6'd19;   // S
        gcodes[3] = 6'd27;   // 0
        gcodes[4] = 6'd36;   // 9


        // label row
        $write("     ");
        for (gi = 3'd0; gi < 3'd5; gi = gi + 3'd1) begin
            if (gcodes[gi] < 6'd27)
                $write("      %c  ", 8'h40 + gcodes[gi]);
            else
                $write("      %c  ", 8'h30 + gcodes[gi] - 6'd27);
        end
        $display("");

        // eight glyph rows
        for (rw = 4'd0; rw < 4'd8; rw = rw + 4'd1) begin
            $write("     ");
            for (gi = 3'd0; gi < 3'd5; gi = gi + 3'd1) begin
                char_code = gcodes[gi];
                glyph_row = rw[2:0];
                #1;
                $write("      ");
                for (cx = 4'd0; cx < 4'd8; cx = cx + 4'd1) begin
                    if (row_bits[7 - cx])
                        $write("#");
                    else
                        $write(".");
                end
            end
            $display("");
        end

        if (errors == 0)
            $display("PASS tb_font_rom (%0d checks)", checks);
        else
            $display("FAIL tb_font_rom (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

    initial begin
        #1000000;
        $display("FAIL tb_font_rom: timeout");
        $finish;
    end

endmodule
