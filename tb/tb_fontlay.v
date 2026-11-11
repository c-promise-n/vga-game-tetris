`timescale 1ns / 1ps
//print the font layer as ASCII art and check the fontlay rules.
module tb_fontlay;

    reg  st_idle, st_pause, st_over;
    reg  [8:0] px_log, py_log;
    wire text_px, dim;

    reg [31:0] x, y, n, tx, bad;
    reg [31:0] errors, checks;
    reg [15:0] sx, sy;

    fontlay dut (
        .st_idle  (st_idle),
        .st_pause (st_pause),
        .st_over  (st_over),
        .px_log   (px_log),
        .py_log   (py_log),
        .text_px  (text_px),
        .dim      (dim)
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

    // print the message band x 96..224, y 96..132, two pixels per character
    task show;
        input [8*16-1:0] name;
        begin
            $display("%0s", name);
            for (sy = 16'd96; sy < 16'd132; sy = sy + 16'd2) begin
                $write("      ");
                for (sx = 16'd96; sx < 16'd224; sx = sx + 16'd2) begin
                    px_log = sx[8:0];
                    py_log = sy[8:0];
                    #1;
                    if (text_px)     $write("#");   // glyph pixel
                    else if (dim)    $write(".");   // dimmed background
                    else             $write(" ");   // normal background
                end
                $write("\n");
            end
        end
    endtask

    initial begin
        errors = 32'd0;
        checks = 32'd0;
        $display("tb_fontlay");

        // no state: no text, no dim
        st_idle = 1'b0;
        st_pause = 1'b0;
        st_over = 1'b0;
        n = 32'd0;
        for (y = 32'd0; y < 32'd240; y = y + 32'd1)
            for (x = 32'd0; x < 32'd320; x = x + 32'd1) begin
                px_log = x[8:0];
                py_log = y[8:0];
                #1;
                if (text_px) n = n + 32'd1;
                if (dim) n = n + 32'd1;
            end
        $display("PLAY: text+dim pixels = %0d", n);
        check("PLAY has no overlay", n, 32'd0);

        // START
        st_idle = 1'b1;
        show("START");
        n = 32'd0;
        tx = 32'd0;
        bad = 32'd0;
        for (y = 32'd0; y < 32'd240; y = y + 32'd1)
            for (x = 32'd0; x < 32'd320; x = x + 32'd1) begin
                px_log = x[8:0];
                py_log = y[8:0];
                #1;
                if (text_px) begin
                    n = n + 32'd1;
                    if ((y < 32'd112) || (y > 32'd119) || (x < 32'd144) || (x > 32'd183))
                        bad = bad + 32'd1;
                end else begin
                    tx = tx + 32'd1;
                    if (!dim) bad = bad + 32'd1;
                end
            end
        $display("START: text pixels = %0d, bad pixels = %0d", n, bad);
        check("START text exists", (n > 0) ? 32'd1 : 32'd0, 32'd1);
        check("START text in band", bad, 32'd0);
        st_idle = 1'b0;

        // PAUSE
        st_pause = 1'b1;
        show("PAUSE");
        n = 32'd0;
        bad = 32'd0;
        for (y = 32'd0; y < 32'd240; y = y + 32'd1)
            for (x = 32'd0; x < 32'd320; x = x + 32'd1) begin
                px_log = x[8:0];
                py_log = y[8:0];
                #1;
                if (text_px) begin
                    n = n + 32'd1;
                    if ((y < 32'd112) || (y > 32'd119) || (x < 32'd144) || (x > 32'd183))
                        bad = bad + 32'd1;
                end else if (!dim)
                    bad = bad + 32'd1;
            end
        $display("PAUSE: text pixels = %0d, bad pixels = %0d", n, bad);
        check("PAUSE text exists", (n > 0) ? 32'd1 : 32'd0, 32'd1);
        check("PAUSE text in band", bad, 32'd0);
        st_pause = 1'b0;

        // GAME OVER
        st_over = 1'b1;
        show("GAME OVER");
        n = 32'd0;
        bad = 32'd0;
        for (y = 32'd0; y < 32'd240; y = y + 32'd1)
            for (x = 32'd0; x < 32'd320; x = x + 32'd1) begin
                px_log = x[8:0];
                py_log = y[8:0];
                #1;
                if (text_px) begin
                    n = n + 32'd1;
                    if ((y < 32'd112) || (y > 32'd119) || (x < 32'd128) || (x > 32'd199))
                        bad = bad + 32'd1;
                end else if (!dim)
                    bad = bad + 32'd1;
            end
        $display("GAME OVER: text pixels = %0d, bad pixels = %0d", n, bad);
        check("GAME OVER text exists", (n > 0) ? 32'd1 : 32'd0, 32'd1);
        check("GAME OVER text in band", bad, 32'd0);
        st_over = 1'b0;

        if (errors == 0)
            $display("PASS tb_fontlay (%0d checks)", checks);
        else
            $display("FAIL tb_fontlay (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL tb_fontlay: timeout");
        $finish;
    end

endmodule
