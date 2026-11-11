`timescale 1ns / 1ps
// dump one full frame of top_tetris to a PPM image.
// frame period should be 16 800 000 ns (= 800*525*4 * 10 ns)
// visible pixels per frame should be 307 200 (= 640*480)
// If either differs, the timing parameters are wrong; fix that before looking at the picture itself.
module tb_frame;

    reg clk   = 1'b0;
    reg btn_c = 1'b0;
    reg btn_u = 1'b0;
    reg btn_l = 1'b0;
    reg btn_r = 1'b0;
    reg btn_d = 1'b0;
    always #5 clk = ~clk;               // 100 MHz, period 10 ns

    // sw[15] = reset (active high), sw[12] = START
    reg [15:0] sw = 16'h8000;

    wire [15:0] led;
    wire [3:0]  vga_r, vga_g, vga_b;
    wire        vga_hs, vga_vs;
    wire [6:0]  seg;
    wire        dp;
    wire [3:0]  an;

    top_tetris u_top (
        .clk    (clk),
        .btn_c  (btn_c),
        .btn_u  (btn_u),
        .btn_l  (btn_l),
        .btn_r  (btn_r),
        .btn_d  (btn_d),
        .sw     (sw),
        .led    (led),
        .vga_r  (vga_r),
        .vga_g  (vga_g),
        .vga_b  (vga_b),
        .vga_hs (vga_hs),
        .vga_vs (vga_vs),
        .seg    (seg),
        .dp     (dp),
        .an     (an)
    );

    reg        vs_d = 1'b1;
    reg [31:0] frame = 32'd0;
    reg [31:0] n_pixels = 32'd0;
    reg [31:0] fd;
    reg [63:0] t_prev = 64'd0;
    reg [63:0] period_t;
    reg        finished = 1'b0;
    reg        period_bad = 1'b0;

    initial begin
        fd = $fopen("frame.ppm", "w");
        if (fd == 0) begin
            $display("ERROR: cannot create frame.ppm");
            $finish;
        end
        $fdisplay(fd, "P3");
        $fdisplay(fd, "640 480");
        $fdisplay(fd, "255");
        $display("Start simulation, frame 2 will be dumped ...");
    end

    // release reset after 200 ns and request START (debounced ~20 ms)
    initial begin
        #200;
        sw[15] = 1'b0;
        sw[12] = 1'b1;
    end

    // one sample per physical pixel: pixel_ce is the 25 MHz strobe and de_r is
    // the registered data-enable, so this yields exactly 640x480 samples/frame
    always @(posedge clk) begin
        vs_d <= vga_vs;

        if (vs_d && !vga_vs) begin
            frame <= frame + 32'd1;
            if (t_prev != 64'd0) begin
                period_t = $time - t_prev;
                $display("frame %0d, period = %0d ns (expect 16800000) led=%h",
                         frame, period_t, led);
                if (period_t != 64'd16800000)
                    period_bad <= 1'b1;
            end
            t_prev = $time;
        end

        if ((frame == 32'd2) && u_top.u_vga.pixel_ce && u_top.de_r) begin
            $fdisplay(fd, "%0d %0d %0d",
                      vga_r * 17, vga_g * 17, vga_b * 17);
            n_pixels <= n_pixels + 32'd1;
        end

        if ((frame == 32'd3) && !finished) begin
            finished <= 1'b1;
            $fclose(fd);
            $display("pixels per frame = %0d (expect 307200)", n_pixels);
            if (n_pixels != 640*480)
                $display("FAIL tb_frame (pixel count %0d)", n_pixels);
            else if (period_bad)
                $display("FAIL tb_frame (frame period wrong)");
            else
                $display("PASS tb_frame (%0d pixels, frame.ppm)", n_pixels);
            $finish;
        end
    end

    initial begin
        #150_000_000;
        $display("FAIL tb_frame: timeout");
        $finish;
    end

endmodule
