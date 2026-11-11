`timescale 1ns / 1ps
// tb_tetris_core - 11 cases for the game core
// case 1 reset
// case 2 START, first piece settles
// case 3 gravity: one row per 30 frame ticks
// case 4 hard drop, lock, new piece spawns
// case 5 single line clear (score +10)
// case 6 four line clear with a vertical I piece (score +100)
// case 7 left wall: leftmost occupied column reaches real column 0
// case 8 right wall: rightmost occupied column reaches real column 9
// case 9 stack up to the top: PLAY -> OVER
// case 10 restart from OVER with btnC, field and score are cleared
// case 11 pause: state holds for many clocks, gravity stops, resume works
module tb_tetris_core;

    localparam FRAME_DIV = 20;              // 20 clk * 10 ns = 200 ns per frame
    localparam P_FALL  = 3'd0;
    localparam P_TOUCH = 3'd1;
    localparam P_DROP  = 3'd2;
    localparam P_LOCK  = 3'd3;
    localparam P_WRITE = 3'd4;
    localparam P_SETTLE= 3'd5;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    reg frame_tick = 1'b0;
    reg [15:0] ftimer = 16'd0;
    always @(posedge clk) begin
        if (ftimer == FRAME_DIV - 1) begin
            ftimer <= 16'd0;
            frame_tick <= 1'b1;
        end else begin
            ftimer <= ftimer + 16'd1;
            frame_tick <= 1'b0;
        end
    end

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

    reg [31:0] n_fail, n_checks, n_frames, fail_base;
    reg [31:0] guard, g_spawn, g_case, g_frm, tgt;
    reg [31:0] g_clr, g_wait, g_fall;
    reg [4:0]  y_save, y_drop, cap_ly, cap_x, col5;
    reg [3:0]  cap_dm;
    reg [15:0] cap_mask, m1;
    reg [9:0]  gap10, got_occ;
    reg [15:0] s_before, l_before;
    reg [3:0]  fv;

    // one frame tick per FRAME_DIV clocks
    always @(posedge clk)
        if (frame_tick) n_frames <= n_frames + 32'd1;

    //in the line-clear FSM the write pointer must never run past the read pointer
    always @(posedge clk) begin
        if (rst_n && (u_core.lc_state != 2'd0)) begin
            if (u_core.wp < u_core.rp) begin
                n_fail <= n_fail + 32'd1;
                $display("FAIL : invariant wp >= rp violated");
            end
        end
    end

    task check(input [15:0] cond, input [8*52-1:0] msg);
        begin
            n_checks = n_checks + 32'd1;
            if (cond !== 16'd1) begin
                n_fail = n_fail + 32'd1;
                $display("FAIL : %0s", msg);
            end
        end
    endtask

    task case_done(input [3:0] n);
        begin
            if (n_fail == fail_base)
                $display("case %0d PASS", n);
            else
                $display("case %0d FAIL", n);
            fail_base = n_fail;
        end
    endtask

    task wait_clk(input [15:0] n);
        begin
            for (g_wait = 32'd0; g_wait < n; g_wait = g_wait + 32'd1)
                @(negedge clk);
        end
    endtask

    task press_key(input [3:0] bit);
        begin
            @(negedge clk);
            key_edge = 8'h01 << bit;
            @(negedge clk);
            key_edge = 8'h00;
        end
    endtask

    task press_move(input dir);
        begin
            @(negedge clk);
            if (dir != 0)
                move_right = 1'b1;
            else
                move_left = 1'b1;
            @(negedge clk);
            move_left = 1'b0;
            move_right = 1'b0;
        end
    endtask

    task wait_frames(input [15:0] n);
        begin
            tgt = n_frames + n;
            g_frm = 32'd0;
            while ((n_frames < tgt) && (g_frm < 32'd100000)) begin
                @(negedge clk);
                g_frm = g_frm + 32'd1;
            end
        end
    endtask

    task reset_dut;
        begin
            rst_n = 1'b0;
            key_edge = 8'h00;
            key_pressed = 8'h00;
            move_left = 1'b0;
            move_right = 1'b0;
            repeat (10) @(negedge clk);
            rst_n = 1'b1;
            repeat (5) @(negedge clk);
        end
    endtask

    task start_game;
        begin
            press_key(7);
            repeat (25) @(negedge clk);
        end
    endtask

    task clear_field;
        begin
            for (g_clr = 32'd0; g_clr < 32'd20; g_clr = g_clr + 32'd1) begin
                u_core.field_occ[g_clr[4:0]] = 10'd0;
                u_core.field_type[g_clr[4:0]] = 30'd0;
            end
        end
    endtask

    // wait for the spawn that follows a lock (FALL phase, piece at the top)
    task wait_spawn;
        begin
            wait_clk(16'd6);
            g_spawn = 32'd0;
            while (!((u_core.phase == P_FALL) && (p_y == 5'd0)) && (g_spawn < 32'd500)) begin
                @(negedge clk);
                g_spawn = g_spawn + 32'd1;
            end
            check((g_spawn < 32'd500) ? 16'd1 : 16'd0, "spawn timeout");
        end
    endtask

    task drop_piece;
        begin
            press_key(4);
            wait_spawn;
        end
    endtask

    // press the drop key right after a frame tick, so no gravity tick can slip
    // between capturing p_y and the drop; y_drop is the row the piece falls from
    task begin_drop;
        begin
            wait_clk(16'd1);
            g_spawn = 32'd0;
            while (frame_tick && (g_spawn < 32'd100)) begin
                @(negedge clk);
                g_spawn = g_spawn + 32'd1;
            end
            y_drop = p_y;
            @(negedge clk);
            key_edge = 8'h01 << 4;
            @(negedge clk);
            key_edge = 8'h00;
        end
    endtask

    function [15:0] mask_of(input [2:0] t, input [1:0] rot);
        case ({t, rot})
            5'd0:  mask_of = 16'h00F0;
            5'd1:  mask_of = 16'h2222;
            5'd2:  mask_of = 16'h00F0;
            5'd3:  mask_of = 16'h2222;
            5'd4:  mask_of = 16'h0660;
            5'd5:  mask_of = 16'h0660;
            5'd6:  mask_of = 16'h0660;
            5'd7:  mask_of = 16'h0660;
            5'd8:  mask_of = 16'h0720;
            5'd9:  mask_of = 16'h0262;
            5'd10: mask_of = 16'h0270;
            5'd11: mask_of = 16'h0464;
            5'd12: mask_of = 16'h0360;
            5'd13: mask_of = 16'h0462;
            5'd14: mask_of = 16'h0360;
            5'd15: mask_of = 16'h0462;
            5'd16: mask_of = 16'h0630;
            5'd17: mask_of = 16'h0264;
            5'd18: mask_of = 16'h0630;
            5'd19: mask_of = 16'h0264;
            5'd20: mask_of = 16'h0710;
            5'd21: mask_of = 16'h0226;
            5'd22: mask_of = 16'h0470;
            5'd23: mask_of = 16'h0644;
            5'd24: mask_of = 16'h0740;
            5'd25: mask_of = 16'h0622;
            5'd26: mask_of = 16'h0170;
            5'd27: mask_of = 16'h0446;
            default: mask_of = 16'h0000;
        endcase
    endfunction

    function [3:0] dmax_of(input [15:0] m);
        begin
            dmax_of = 4'd0;
            for (fv = 4'd0; fv < 4'd4; fv = fv + 4'd1)
                if (m[fv*4 +: 4] != 4'd0)
                    dmax_of = fv;
        end
    endfunction

    function [9:0] row_occ(input [15:0] m, input [4:0] bx, input [3:0] dr);
        begin
            row_occ = 10'd0;
            for (fv = 4'd0; fv < 4'd4; fv = fv + 4'd1) begin
                if (m[dr*4 + fv]) begin
                    col5 = bx - 5'd2 + {1'b0, fv};
                    if (col5 <= 5'd9)
                        row_occ[col5[3:0]] = 1'b1;
                end
            end
        end
    endfunction

    initial begin
        n_fail = 32'd0;
        n_checks = 32'd0;
        n_frames = 32'd0;
        fail_base = 32'd0;
        $display("tb_tetris_core");
        $display("frame_tick every %0d clocks (200 ns), GRAV = 30 frames", FRAME_DIV);

        // case 1: reset
        reset_dut;
        check(u_core.field_occ[0] == 10'd0, "field not cleared");
        check(u_core.field_occ[10] == 10'd0, "field row 10 not cleared");
        check(u_core.field_occ[19] == 10'd0, "field row 19 not cleared");
        check(u_core.score == 16'd0, "score not cleared");
        check(u_core.lines == 7'd0, "lines not cleared");
        check(u_core.level == 3'd0, "level not cleared");
        check(st_idle == 1'b1, "reset is not IDLE");
        check(st_pause == 1'b0, "reset is pausing");
        check(st_over == 1'b0, "reset is OVER");
        case_done(1);

        // case 2: START, first piece settles (the core redraws it on START)
        start_game;
        check(st_idle == 1'b0, "did not enter PLAY");
        check(p_x == 5'd5, "piece did not start at x = 5");
        check(p_y == 5'd0, "piece did not start at y = 0");
        check(p_rot == 2'd0, "piece did not start unrotated");
        check(p_type <= 3'd6, "piece type out of range");
        check(p_mask == mask_of(p_type, p_rot), "shape mask mismatch");
        check(next_mask == mask_of(next_type, 2'd0), "next mask mismatch");
        wait_clk(16'd40);
        check(p_type <= 3'd6, "piece type unstable after start");
        check(p_y == 5'd0, "piece fell without frame ticks");
        case_done(2);

        // case 3: gravity, one row per 30 frames at level 0
        reset_dut;
        clear_field;
        start_game;
        wait_clk(16'd40);
        y_save = p_y;
        g_fall = 32'd0;
        while ((p_y == y_save) && (g_fall < 32'd2000)) begin
            @(negedge clk);
            g_fall = g_fall + 32'd1;
        end
        check(p_y == y_save + 5'd1, "first gravity step missing");
        y_save = p_y;
        g_fall = 32'd0;
        tgt = n_frames;
        while ((p_y == y_save) && (g_fall < 32'd2000)) begin
            @(negedge clk);
            g_fall = g_fall + 32'd1;
        end
        check(p_y == y_save + 5'd1, "second gravity step missing");
        g_case = n_frames - tgt;
        check((g_case >= 32'd29) && (g_case <= 32'd31), "gravity period is not 30 frames");
        case_done(3);

        // case 4: hard drop, lock, new piece spawns at the top
        reset_dut;
        clear_field;
        start_game;
        wait_clk(16'd40);
        cap_mask = p_mask;
        cap_x = p_x;
        cap_dm = dmax_of(cap_mask);
        cap_ly = 5'd19 - {1'b0, cap_dm};
        begin_drop;
        wait_spawn;
        got_occ = row_occ(cap_mask, cap_x, cap_dm);
        check(u_core.field_occ[19] == got_occ, "locked cells missing at row 19");
        check(u_core.field_occ[19] != 10'd0, "nothing was written to row 19");
        check(p_y == 5'd0, "new piece did not spawn at y = 0");
        check(p_x == 5'd5, "new piece did not spawn at x = 5");
        check(p_rot == 2'd0, "new piece is rotated");
        check(st_idle == 1'b0, "lock left PLAY");
        case_done(4);

        // case 5: single line clear, score +10 (plus 2 per dropped row)
        reset_dut;
        clear_field;
        start_game;
        wait_clk(16'd40);
        cap_mask = p_mask;
        cap_x = p_x;
        cap_dm = dmax_of(cap_mask);
        cap_ly = 5'd19 - {1'b0, cap_dm};
        // row 19 is full except the cells the piece is about to fill
        gap10 = 10'h3FF;
        for (g_case = 32'd0; g_case < 32'd4; g_case = g_case + 32'd1) begin
            if (cap_mask[cap_dm*4 + g_case[1:0]]) begin
                col5 = cap_x - 5'd2 + g_case[4:0];
                if (col5 <= 5'd9)
                    gap10[col5[3:0]] = 1'b0;
            end
        end
        u_core.field_occ[19] = gap10;
        u_core.field_type[19] = 30'd0;
        s_before = u_core.score;
        l_before = {9'd0, u_core.lines};
        begin_drop;
        guard = 32'd0;
        while (({9'd0, u_core.lines} == l_before) && (guard < 32'd6000)) begin
            @(negedge clk);
            guard = guard + 32'd1;
        end
        check({9'd0, u_core.lines} == l_before + 16'd1, "single line was not cleared");
        check((u_core.score - s_before) == (2*({11'd0, cap_ly} - {11'd0, y_drop}) + 32'd10),
              "score for single line");
        got_occ = 10'd0;
        if (cap_dm >= 4'd1)
            got_occ = row_occ(cap_mask, cap_x, cap_dm - 4'd1);
        check(u_core.field_occ[19] == got_occ, "row 19 wrong after single clear");
        case_done(5);

        // case 6: four line clear with a vertical I piece, score +100
        reset_dut;
        clear_field;
        start_game;
        // advance to an I piece (type 0): the 7-bag guarantees one within 7 draws
        g_case = 32'd0;
        while ((p_type != 3'd0) && (g_case < 32'd14)) begin
            drop_piece;
            clear_field;
            g_case = g_case + 32'd1;
        end
        check(p_type == 3'd0, "I piece not reached");
        press_key(3);                       // rotate: I horizontal -> vertical
        wait_clk(16'd3);
        check(p_rot == 2'd1, "I piece did not rotate to vertical");
        check(p_mask == 16'h2222, "I vertical mask mismatch");
        cap_mask = p_mask;
        cap_x = p_x;
        cap_dm = dmax_of(cap_mask);
        cap_ly = 5'd19 - {1'b0, cap_dm};
        col5 = cap_x - 5'd2 + 5'd1;         // the vertical I occupies dcol 1
        clear_field;
        gap10 = 10'h3FF;
        if (col5 <= 5'd9)
            gap10[col5[3:0]] = 1'b0;
        for (g_case = 32'd16; g_case < 32'd20; g_case = g_case + 32'd1) begin
            u_core.field_occ[g_case[4:0]] = gap10;
            u_core.field_type[g_case[4:0]] = 30'd0;
        end
        s_before = u_core.score;
        l_before = {9'd0, u_core.lines};
        begin_drop;
        guard = 32'd0;
        while (({9'd0, u_core.lines} == l_before) && (guard < 32'd6000)) begin
            @(negedge clk);
            guard = guard + 32'd1;
        end
        check({9'd0, u_core.lines} == l_before + 16'd4, "four lines were not cleared");
        check((u_core.score - s_before) == (2*({11'd0, cap_ly} - {11'd0, y_drop}) + 32'd100),
              "score for four lines");
        check(u_core.field_occ[16] == 10'd0, "field not empty after four line clear");
        check(u_core.field_occ[19] == 10'd0, "row 19 not empty after four line clear");
        case_done(6);

        // case 7/8: push against both walls, the real occupied columns must be 0 (left wall) and 9 (right wall)
        reset_dut;
        clear_field;
        start_game;
        wait_clk(16'd40);
        for (g_case = 32'd0; g_case < 32'd20; g_case = g_case + 32'd1)
            press_move(0);
        wait_clk(16'd3);
        cap_mask = p_mask;
        cap_x = p_x;
        col5 = 5'd3;
        for (g_case = 32'd0; g_case < 32'd16; g_case = g_case + 32'd1)
            if (cap_mask[g_case[3:0]]) begin
                if ({3'd0, g_case[1:0]} < col5) col5 = {3'd0, g_case[1:0]};
            end
        check((cap_x - 5'd2 + col5) == 5'd0, "left wall: leftmost column is not 0");
        case_done(7);

        for (g_case = 32'd0; g_case < 32'd20; g_case = g_case + 32'd1)
            press_move(1);
        wait_clk(16'd3);
        cap_mask = p_mask;
        cap_x = p_x;
        col5 = 5'd0;
        for (g_case = 32'd0; g_case < 32'd16; g_case = g_case + 32'd1)
            if (cap_mask[g_case[3:0]]) begin
                if ({3'd0, g_case[1:0]} > col5) col5 = {3'd0, g_case[1:0]};
            end
        check((cap_x - 5'd2 + col5) == 5'd9, "right wall: rightmost column is not 9");
        case_done(8);

        // case 9: stack up to the top, PLAY must go to OVER col 0 is left empty so no line can be completed
        reset_dut;
        clear_field;
        start_game;
        wait_clk(16'd40);
        for (g_case = 32'd0; g_case < 32'd4; g_case = g_case + 32'd1) begin
            u_core.field_occ[g_case[4:0]] = 10'h3FE;
            u_core.field_type[g_case[4:0]] = 30'd0;
        end
        press_key(4);
        g_case = 32'd0;
        while ((st_over == 1'b0) && (g_case < 32'd1000)) begin
            @(negedge clk);
            g_case = g_case + 32'd1;
        end
        check(st_over == 1'b1, "stack to the top did not enter OVER");
        check(st_pause == 1'b0, "top-out state is pausing");
        case_done(9);

        // case 10: restart from OVER with btnC (key_edge[4] in OVER)
        press_key(4);
        wait_clk(16'd5);
        check(st_over == 1'b0, "restart did not leave OVER");
        check(st_idle == 1'b0, "restart did not return to PLAY");
        check(u_core.score == 16'd0, "restart did not clear score");
        check(u_core.lines == 7'd0, "restart did not clear lines");
        check(u_core.field_occ[0] == 10'd0, "restart did not clear field row 0");
        check(u_core.field_occ[19] == 10'd0, "restart did not clear field row 19");
        check(p_y == 5'd0, "restart did not spawn at y = 0");
        case_done(10);

        // case 11: pause holds for many clocks, gravity stops, resume works
        key_pressed[5] = 1'b1;
        wait_clk(16'd5);
        check(st_pause == 1'b1, "pause was not entered");
        for (g_case = 32'd0; g_case < 32'd10; g_case = g_case + 32'd1) begin
            wait_clk(16'd1);
            check(st_pause == 1'b1, "pause state is not stable for 10 clocks");
        end
        y_save = p_y;
        wait_frames(16'd5);
        check(p_y == y_save, "piece moved while paused");
        key_pressed[5] = 1'b0;
        wait_clk(16'd5);
        check(st_pause == 1'b0, "resume failed");
        wait_frames(16'd30);
        check(p_y > y_save, "gravity did not resume after pause");
        case_done(11);

        $display("%0d checks, %0d failures", n_checks, n_fail);
        if (n_fail == 0)
            $display("PASS tb_tetris_core (%0d checks)", n_checks);
        else
            $display("FAIL tb_tetris_core (%0d errors / %0d checks)", n_fail, n_checks);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL tb_tetris_core: timeout");
        $finish;
    end

endmodule
