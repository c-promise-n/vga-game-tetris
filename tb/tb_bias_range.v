`timescale 1ns / 1ps
// exhaustive check of the "+2 biased" column scheme.
// real column = biased p_x - 2 + dcol
module tb_bias_range;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg frame_tick = 1'b0;
    reg [7:0] key_edge = 8'h00;
    reg [7:0] key_pressed = 8'h00;
    reg move_left = 1'b0;
    reg move_right = 1'b0;
    reg [4:0] row_idx = 5'd0;

    wire [9:0]  occ_row;
    wire [29:0] type_row;
    wire [2:0]  p_type, next_type;
    wire [1:0]  p_rot;
    wire [4:0]  p_x, p_y;
    wire [15:0] p_mask, next_mask;
    wire [19:0] flash_rows;
    wire [4:0]  ghost_y;
    wire        ghost_on;
    wire [3:0]  score_h, score_t, score_o;
    wire [3:0]  lines_h, lines_t, lines_o;
    wire [2:0]  level;
    wire        st_idle, st_pause, st_over;

    always #5 clk = ~clk;

    tetris_core u_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_tick (frame_tick),
        .key_edge   (key_edge),
        .key_pressed(key_pressed),
        .move_left  (move_left),
        .move_right (move_right),
        .row_idx    (row_idx),
        .occ_row    (occ_row),
        .type_row   (type_row),
        .p_type     (p_type),
        .p_rot      (p_rot),
        .p_x        (p_x),
        .p_y        (p_y),
        .p_mask     (p_mask),
        .next_type  (next_type),
        .next_mask  (next_mask),
        .flash_rows (flash_rows),
        .ghost_y    (ghost_y),
        .ghost_on   (ghost_on),
        .score_h    (score_h),
        .score_t    (score_t),
        .score_o    (score_o),
        .lines_h    (lines_h),
        .lines_t    (lines_t),
        .lines_o    (lines_o),
        .level      (level),
        .st_idle    (st_idle),
        .st_pause   (st_pause),
        .st_over    (st_over)
    );

    reg [31:0] errors, checks;
    reg [3:0]  tp, rot;
    reg [4:0]  xv, k;
    reg [31:0] xmin, xmax, ld, rd, real_l, real_r;
    reg        found;
    reg [15:0] m;

    task check(input [8*44-1:0] name, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 32'd1;
            if (got !== exp) begin
                errors = errors + 32'd1;
                $display("FAIL %0s : got %0d, expected %0d", name, got, exp);
            end
        end
    endtask

    initial begin
        errors = 32'd0;
        checks = 32'd0;
        $display("tb_bias_range");
        $display("real column = biased p_x - 2 + dcol");

        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        for (tp = 4'd0; tp < 4'd7; tp = tp + 4'd1) begin
            for (rot = 4'd0; rot < 4'd4; rot = rot + 4'd1) begin
                // hold the piece at row 0 and probe p_x over the whole field
                force u_core.p_type = tp[2:0];
                force u_core.p_rot  = rot[1:0];
                force u_core.p_y    = 5'd0;
                force u_core.p_x    = 5'd0;
                #1;

                xmin = 32'hFFFFFFFF;
                xmax = 32'hFFFFFFFF;
                found = 1'b0;
                for (xv = 5'd0; xv < 5'd16; xv = xv + 5'd1) begin
                    force u_core.p_x = xv[4:0];
                    #1;
                    if (!u_core.landed) begin
                        if (!found) begin
                            xmin = {27'd0, xv};
                            found = 1'b1;
                        end
                        xmax = {27'd0, xv};
                    end
                end

                m = u_core.p_mask;
                ld = 32'd3;
                rd = 32'd0;
                for (k = 5'd0; k < 5'd16; k = k + 5'd1) begin
                    if (m[k[3:0]]) begin
                        if ({28'd0, k[1:0]} < ld) ld = {28'd0, k[1:0]};
                        if ({28'd0, k[1:0]} > rd) rd = {28'd0, k[1:0]};
                    end
                end

                real_l = xmin - 32'd2 + ld;
                real_r = xmax - 32'd2 + rd;

                checks = checks + 32'd2;
                if ((real_l !== 32'd0) || (real_r !== 32'd9)) begin
                    errors = errors + 32'd1;
                    $display("FAIL type=%0d rot=%0d legal p_x %0d..%0d real columns %0d..%0d",
                             tp, rot, xmin, xmax, real_l, real_r);
                end else begin
                    $display("ok type=%0d rot=%0d p_x %0d..%0d real columns 0..9",
                             tp, rot, xmin, xmax);
                end

                if (!found) begin
                    errors = errors + 32'd1;
                    $display("FAIL type=%0d rot=%0d : no legal p_x", tp, rot);
                end

                release u_core.p_type;
                release u_core.p_rot;
                release u_core.p_x;
                release u_core.p_y;
                repeat (2) @(negedge clk);
            end
        end

        if (errors == 0)
            $display("PASS tb_bias_range (%0d checks)", checks);
        else
            $display("FAIL tb_bias_range (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

    initial begin
        #1000000;
        $display("FAIL tb_bias_range: timeout");
        $finish;
    end

endmodule
