`timescale 1ns / 1ps
// print the side panel as ASCII art and check the layout rules.
module tb_panel;

    reg  [8:0]  px_log, py_log;
    reg  [2:0]  next_type;
    reg  [15:0] next_mask;
    reg  [3:0]  score_h, score_t, score_o;
    reg  [2:0]  level;
    reg  [3:0]  lines_h, lines_t, lines_o;
    wire [3:0]  color_idx;

    reg [31:0] x, y, n, lit;
    reg [31:0] errors, checks;
    reg [15:0] sx, sy;
    reg [3:0]  c;

    panel dut (
        .px_log         (px_log),
        .py_log         (py_log),
        .next_type      (next_type),
        .next_mask      (next_mask),
        .score_h        (score_h),
        .score_t        (score_t),
        .score_o        (score_o),
        .level          (level),
        .lines_h        (lines_h),
        .lines_t        (lines_t),
        .lines_o        (lines_o),
        .color_idx_panel(color_idx)
    );

    task check(input [8*44-1:0] name, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 32'd1;
            if (got !== exp) begin
                errors = errors + 32'd1;
                $display("FAIL %0s : got %0d, expected %0d", name, got, exp);
            end
        end
    endtask

    function [15:0] mask_of(input [2:0] t);
        case (t)
            3'd0: mask_of = 16'h2222;
            3'd1: mask_of = 16'h0660;
            3'd2: mask_of = 16'h0720;
            3'd3: mask_of = 16'h0360;
            3'd4: mask_of = 16'h0630;
            3'd5: mask_of = 16'h0710;
            3'd6: mask_of = 16'h0740;
            default: mask_of = 16'h0000;
        endcase
    endfunction

    // print x 184..262, y 44..190: two pixel block -> one character
    task show;
        input [8*20-1:0] name;
        begin
            $display("%0s next_type=%0d next_mask=%h score=%0d%0d%0d level=%0d lines=%0d%0d%0d",
                     name, next_type, next_mask,
                     score_h, score_t, score_o, level,
                     lines_h, lines_t, lines_o);
            for (sy = 16'd44; sy < 16'd190; sy = sy + 16'd2) begin
                $write("      ");
                for (sx = 16'd184; sx < 16'd262; sx = sx + 16'd2) begin
                    px_log = sx[8:0];
                    py_log = sy[8:0];
                    #1;
                    c = color_idx;
                    if (c == 4'h9)      $write("#");   // text
                    else if (c == 4'hD) $write("+");   // frame
                    else if (c == 4'hE) $write(":");   // preview interior
                    else if (c == 4'hF) $write(" ");   // background
                    else begin
                        $write("O");                   // piece cell
                        lit = lit + 32'd1;
                    end
                end
                $write("\n");
            end
            $display("block pixels seen = %0d", lit);
        end
    endtask

    initial begin
        errors = 32'd0;
        checks = 32'd0;
        $display("tb_panel");

        lit = 32'd0;
        next_type = 3'd2; next_mask = mask_of(3'd2);
        score_h = 4'd1; score_t = 4'd2; score_o = 4'd0;   // 120
        level = 3'd1;
        lines_h = 4'd0; lines_t = 4'd4; lines_o = 4'd2;   // 42
        show("T / 120 / 1 / 42");

        lit = 32'd0;
        next_type = 3'd0; next_mask = mask_of(3'd0);
        score_h = 4'd9; score_t = 4'd9; score_o = 4'd9;   // 999
        level = 3'd3;
        lines_h = 4'd1; lines_t = 4'd2; lines_o = 4'd7;   // 127
        show("I / 999 / 3 / 127");

        lit = 32'd0;
        next_type = 3'd1; next_mask = mask_of(3'd1);
        score_h = 4'd0; score_t = 4'd0; score_o = 4'd0;
        level = 3'd0;
        lines_h = 4'd0; lines_t = 4'd0; lines_o = 4'd0;
        show("O / 0 / 0 / 0");

        // panel must not draw left of x=132
        n = 32'd0;
        next_type = 3'd2;
        next_mask = mask_of(3'd2);
        for (y = 32'd0; y < 32'd240; y = y + 32'd1) begin
            for (x = 32'd0; x < 32'd132; x = x + 32'd1) begin
                px_log = x[8:0];
                py_log = y[8:0];
                #1;
                if (color_idx !== 4'hF)
                    n = n + 32'd1;
            end
        end
        $display("lit pixels left of x=132 : %0d", n);
        check("panel stays in its area", n, 32'd0);

        // NEXT box frame is closed
        for (n = 32'd0; n < 32'd7; n = n + 32'd1) begin
            next_type = n[2:0];
            next_mask = mask_of(n[2:0]);
            px_log = 9'd194; py_log = 9'd60;  #1;
            check("frame left",   color_idx, 4'hD);
            px_log = 9'd257; py_log = 9'd60;  #1;
            check("frame right",  color_idx, 4'hD);
            px_log = 9'd220; py_log = 9'd52;  #1;
            check("frame top",    color_idx, 4'hD);
            px_log = 9'd220; py_log = 9'd115; #1;
            check("frame bottom", color_idx, 4'hD);
        end

        // text rows light up
        score_h = 4'd1; score_t = 4'd2; score_o = 4'd0;
        level = 3'd1;
        lines_h = 4'd0; lines_t = 4'd4; lines_o = 4'd2;

        // score digits: x 202..249, y 124..139
        n = 32'd0;
        for (y = 32'd124; y < 32'd140; y = y + 32'd1)
            for (x = 32'd202; x < 32'd250; x = x + 32'd1) begin
                px_log = x[8:0]; py_log = y[8:0]; #1;
                if (color_idx === 4'h9) n = n + 32'd1;
            end
        $display("score text pixels = %0d", n);
        check("score digits visible", (n > 0) ? 32'd1 : 32'd0, 32'd1);

        // level digit: x 218..233, y 148..163
        n = 32'd0;
        for (y = 32'd148; y < 32'd164; y = y + 32'd1)
            for (x = 32'd218; x < 32'd234; x = x + 32'd1) begin
                px_log = x[8:0]; py_log = y[8:0]; #1;
                if (color_idx === 4'h9) n = n + 32'd1;
            end
        $display("level text pixels = %0d", n);
        check("level digit visible", (n > 0) ? 32'd1 : 32'd0, 32'd1);

        // lines digits: x 202..249, y 172..187
        n = 32'd0;
        for (y = 32'd172; y < 32'd188; y = y + 32'd1)
            for (x = 32'd202; x < 32'd250; x = x + 32'd1) begin
                px_log = x[8:0]; py_log = y[8:0]; #1;
                if (color_idx === 4'h9) n = n + 32'd1;
            end
        $display("lines text pixels = %0d", n);
        check("lines digits visible", (n > 0) ? 32'd1 : 32'd0, 32'd1);

        // label rows light up: SCORE at y 116, LEVEL at 140, LINES at 164
        n = 32'd0;
        for (y = 32'd116; y < 32'd124; y = y + 32'd1)
            for (x = 32'd206; x < 32'd246; x = x + 32'd1) begin
                px_log = x[8:0]; py_log = y[8:0]; #1;
                if (color_idx === 4'h9) n = n + 32'd1;
            end
        $display("SCORE label pixels = %0d", n);
        check("SCORE label visible", (n > 0) ? 32'd1 : 32'd0, 32'd1);

        n = 32'd0;
        for (y = 32'd140; y < 32'd148; y = y + 32'd1)
            for (x = 32'd206; x < 32'd246; x = x + 32'd1) begin
                px_log = x[8:0]; py_log = y[8:0]; #1;
                if (color_idx === 4'h9) n = n + 32'd1;
            end
        $display("LEVEL label pixels = %0d", n);
        check("LEVEL label visible", (n > 0) ? 32'd1 : 32'd0, 32'd1);

        n = 32'd0;
        for (y = 32'd164; y < 32'd172; y = y + 32'd1)
            for (x = 32'd206; x < 32'd246; x = x + 32'd1) begin
                px_log = x[8:0]; py_log = y[8:0]; #1;
                if (color_idx === 4'h9) n = n + 32'd1;
            end
        $display("LINES label pixels = %0d", n);
        check("LINES label visible", (n > 0) ? 32'd1 : 32'd0, 32'd1);

        if (errors == 0)
            $display("PASS tb_panel (%0d checks)", checks);
        else
            $display("FAIL tb_panel (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

    initial begin
        #1000000;
        $display("FAIL tb_panel: timeout");
        $finish;
    end

endmodule
