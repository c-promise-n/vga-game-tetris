`timescale 1ns / 1ps
// field/border/panel regions, grid, occupied cells, falling piece, ghost piece, line-clear flash and panel next-box pass-through.
// Piece x is biased by +2 in the core: actual columns are (p_x - 2 + dcol).
module render_tb;

    reg [8:0] px_log;
    reg [8:0] py_log;
    reg [4:0] col_idx;
    reg [4:0] row_idx;
    reg [3:0] col_px;
    reg [3:0] row_px;
    reg [2:0] p_type;
    reg [4:0] p_x;
    reg [4:0] p_y;
    reg [15:0] shape_mask;
    reg [2:0] next_type;
    reg [15:0] next_mask;
    reg [19:0] flash_rows;
    reg [4:0] ghost_y;
    reg ghost_on;
    reg [3:0] score_h, score_t, score_o;
    reg [2:0] level;
    reg [3:0] lines_h, lines_t, lines_o;
    reg [9:0] field_occ_row;
    reg [29:0] field_type_row;
    wire [3:0] color_idx;

    integer errors = 0;
    integer checks = 0;
    integer i, c, r;

    render dut (
        .px_log(px_log),
        .py_log(py_log),
        .col_idx(col_idx),
        .row_idx(row_idx),
        .col_px(col_px),
        .row_px(row_px),
        .p_type(p_type),
        .p_x(p_x),
        .p_y(p_y),
        .shape_mask(shape_mask),
        .next_type(next_type),
        .next_mask(next_mask),
        .flash_rows(flash_rows),
        .ghost_y(ghost_y),
        .ghost_on(ghost_on),
        .score_h(score_h),
        .score_t(score_t),
        .score_o(score_o),
        .level(level),
        .lines_h(lines_h),
        .lines_t(lines_t),
        .lines_o(lines_o),
        .field_occ_row(field_occ_row),
        .field_type_row(field_type_row),
        .color_idx(color_idx)
    );

    task check(input [8*40-1:0] name, input integer got, input integer exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL %0s: got %0h, expected %0h", name, got, exp);
            end
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

    initial begin
        #200000;
        $display("FAIL render_tb: timeout");
        $finish;
    end

    initial begin
        // defaults: inside the field, no content at all
        py_log = 9'd10;
        px_log = 9'd50;
        col_idx = 5'd5;
        row_idx = 5'd5;
        col_px = 4'd5;
        row_px = 4'd5;
        p_type = 3'd0;
        p_x = 5'd5;
        p_y = 5'd0;
        shape_mask = 16'h0000;
        next_type = 3'd0;
        next_mask = 16'h0000;
        flash_rows = 20'd0;
        ghost_y = 5'd0;
        ghost_on = 1'b0;
        score_h = 4'd0;
        score_t = 4'd0;
        score_o = 4'd0;
        level = 3'd0;
        lines_h = 4'd0;
        lines_t = 4'd0;
        lines_o = 4'd0;
        field_occ_row = 10'd0;
        field_type_row = 30'd0;
        #1;

        // region sweep: field, border, panel background
        for (i = 0; i < 512; i = i + 1) begin
            px_log = i[8:0];
            #1;
            if (i <= 119) c = 4'hE;
            else if (i < 132) c = 4'hD;
            else c = 4'hF;
            check("region color", color_idx, c);
        end

        // grid lines inside the field
        px_log = 9'd50;
        for (i = 0; i < 16; i = i + 1) begin
            col_px = i[3:0];
            #1;
            check("column grid", color_idx, (i == 0) ? 4'h1 : 4'hE);
        end
        col_px = 4'd5;
        for (i = 0; i < 16; i = i + 1) begin
            row_px = i[3:0];
            #1;
            check("row grid", color_idx, (i == 0) ? 4'h1 : 4'hE);
        end
        row_px = 4'd5;

        // occupied cells: color = stored cell type + 2 (index above 9 clamps to 0)
        field_occ_row = 10'h3FF;
        field_type_row = 30'd0;
        for (c = 0; c < 10; c = c + 1)
            field_type_row[3*c +: 3] = c[2:0];
        for (i = 0; i < 32; i = i + 1) begin
            col_idx = i[4:0];
            #1;
            check("occupied cell", color_idx, ((i <= 9) ? (i & 7) : 0) + 2);
        end
        field_occ_row = 10'd0;
        field_type_row = 30'd0;

        // falling piece: full mask covers rows p_y..p_y+3, columns p_x-2..p_x+1
        p_type = 3'd2;
        p_x = 5'd5;
        p_y = 5'd7;
        shape_mask = 16'hFFFF;
        for (r = 0; r < 32; r = r + 1) begin
            row_idx = r[4:0];
            for (c = 0; c < 32; c = c + 1) begin
                col_idx = c[4:0];
                #1;
                if ((r >= 7) && (r <= 10) && (c >= 3) && (c <= 6))
                    check("piece hit", color_idx, 4'h4);
                else
                    check("piece miss", color_idx, 4'hE);
            end
        end

        // single cell mask: only (p_x-2, p_y) is lit
        p_type = 3'd2;
        p_x = 5'd5;
        p_y = 5'd5;
        shape_mask = 16'h0001;
        row_idx = 5'd5;
        col_idx = 5'd3;
        #1;
        check("single mask hit", color_idx, 4'h4);
        col_idx = 5'd4;
        #1;
        check("single mask miss", color_idx, 4'hE);
        col_idx = 5'd3;
        row_idx = 5'd6;
        #1;
        check("single mask miss row", color_idx, 4'hE);

        // line-clear flash has the highest priority inside the field
        p_x = 5'd5;
        p_y = 5'd5;
        shape_mask = 16'hFFFF;
        row_idx = 5'd5;
        col_idx = 5'd5;
        flash_rows = 20'd0;
        flash_rows[5] = 1'b1;
        #1;
        check("flash priority", color_idx, 4'hC);
        flash_rows = 20'd0;

        // ghost piece below the falling piece, occupancy wins over ghost
        shape_mask = 16'h00F0;
        p_x = 5'd5;
        p_y = 5'd0;
        ghost_y = 5'd18;
        ghost_on = 1'b1;
        row_idx = 5'd19;
        col_idx = 5'd3;
        #1;
        check("ghost hit", color_idx, 4'hA);
        row_idx = 5'd19;
        col_idx = 5'd2;
        #1;
        check("ghost miss", color_idx, 4'hE);
        row_idx = 5'd18;
        col_idx = 5'd3;
        #1;
        check("ghost row 0 empty", color_idx, 4'hE);
        field_occ_row = 10'h008;
        field_type_row[9 +: 3] = 3'd5;
        row_idx = 5'd19;
        col_idx = 5'd3;
        #1;
        check("occupied wins over ghost", color_idx, 4'h7);
        field_occ_row = 10'd0;
        field_type_row = 30'd0;
        ghost_on = 1'b0;

        // panel next-box pass-through: fixed border, preview inside the box
        py_log = 9'd60;
        px_log = 9'd194;
        #1;
        check("next box border left", color_idx, 4'hD);
        px_log = 9'd257;
        #1;
        check("next box border right", color_idx, 4'hD);
        px_log = 9'd220;
        py_log = 9'd52;
        #1;
        check("next box border top", color_idx, 4'hD);
        next_type = 3'd2;                 // offset_x = 8, next_x0 = 202
        next_mask = mask_of(3'd2, 2'd0);
        px_log = 9'd207;                  // cell (row 2, col 0) is set in the T mask
        py_log = 9'd89;
        #1;
        check("next box piece cell", color_idx, 4'h4);
        px_log = 9'd207;
        py_log = 9'd73;                   // cell (row 0, col 0) is empty
        #1;
        check("next box empty cell", color_idx, 4'hE);

        if (errors == 0)
            $display("PASS render_tb (%0d checks)", checks);
        else
            $display("FAIL render_tb (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

endmodule
