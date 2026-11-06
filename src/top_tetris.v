`timescale 1ns / 1ps
//======================================================================
// top_tetris - board top level for the integrated game
//
// Instantiates, from left to right:
//   vga_timing -> cell_map -> render -> palette -> pixel_pipe   (video)
//   input_subsystem                                            (input)
//   tetris_core                                                (game)
//   score_display                                              (7-seg)
//
// Control mapping (must match input_subsystem / btn_sync)
//   btnL  LEFT        btnR  RIGHT      btnU  ROTATE
//   btnD  DOWN        btnC  HARD DROP
//   sw[14] PAUSE      sw[13] RESTART    sw[12] START
//   sw[15] RESET      (drives rst_n, so it is not a key)
//
// The session FSM powers up in IDLE and waits for START or RESTART, so
// after programming flip sw[12] (or sw[13]) once to begin playing.
//
// LED map (bring-up aids)
//   led[7:0]   key_pressed level map
//   led[8]     any key event, stretched to about 100 ms
//   led[9]     sw[12] START level
//   led[10]    sw[13] RESTART level
//   led[11]    sw[14] PAUSE level
//   led[13]    ON while the design is held in reset  (sw[15] up)
//   led[14]    sw[11] colour bar mode
//   led[15]    1 Hz heartbeat from frame_tick
//
// Bring-up bisect
//   led[13] on            -> sw[15] is up, the whole design is in reset
//   led[15] blinking      -> clock, vga_timing and frame_tick are alive
//   sw[11] up shows bars  -> video pins / cable / monitor are fine
//======================================================================
module top_tetris (
    input  wire        clk,        // W5   100 MHz
    input  wire        btn_c,      // U18  hard drop
    input  wire        btn_u,      // T18  rotate
    input  wire        btn_l,      // W19  left
    input  wire        btn_r,      // T17  right
    input  wire        btn_d,      // U17  down / soft drop
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an
);

    //------------------------------------------------------------------
    // reset : switch driven, active high on sw[15] -> rst_n active low
    //------------------------------------------------------------------
    wire rst_n = ~sw[15];

    //------------------------------------------------------------------
    // video timing
    //------------------------------------------------------------------
    wire [9:0] px, py;
    wire       de, pixel_ce, hsync, vsync, frame_tick;

    vga_timing u_vga (
        .clk        (clk),
        .rst_n      (rst_n),
        .de         (de),
        .pixel_ce   (pixel_ce),
        .frame_tick (frame_tick),
        .px         (px),
        .py         (py),
        .hsync      (hsync),
        .vsync      (vsync)
    );

    wire [8:0] px_log = px[9:1];
    wire [8:0] py_log = py[9:1];

    //------------------------------------------------------------------
    // cell coordinates
    //------------------------------------------------------------------
    wire [4:0] col_idx, row_idx;
    wire [3:0] col_px,  row_px;

    cell_map u_cell (
        .clk      (clk),
        .rst_n    (rst_n),
        .de       (de),
        .pixel_ce (pixel_ce),
        .px       (px),
        .py       (py),
        .col_idx  (col_idx),
        .row_idx  (row_idx),
        .col_px   (col_px),
        .row_px   (row_px)
    );

    //------------------------------------------------------------------
    // input chain
    //------------------------------------------------------------------
    wire [7:0] key_pressed, key_edge;
    wire       move_left, move_right;

    input_subsystem u_in (
        .clk         (clk),
        .rst_n       (rst_n),
        .btn_l       (btn_l),
        .btn_r       (btn_r),
        .btn_u       (btn_u),
        .btn_d       (btn_d),
        .btn_c       (btn_c),
        .sw_pause    (sw[14]),
        .sw_restart  (sw[13]),
        .sw_start    (sw[12]),
        .frame_tick  (frame_tick),
        .key_pressed (key_pressed),
        .key_edge    (key_edge),
        .move_right  (move_right),
        .move_left   (move_left)
    );

    //------------------------------------------------------------------
    // game core
    //------------------------------------------------------------------
    wire [9:0]  field_occ_row;
    wire [29:0] field_type_row;
    wire [2:0]  p_type, next_type;
    wire [1:0]  p_rot;
    wire [4:0]  p_x, p_y;
    wire [15:0] p_mask, next_mask;
    wire [15:0] score;
    wire st_idle,st_pause,st_over;
    wire [2:0]level;
    wire [6:0]lines;

    tetris_core u_core (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_tick   (frame_tick),
        .key_edge     (key_edge),
        .key_pressed    (key_pressed),
        .move_left    (move_left),
        .move_right   (move_right),
        .row_idx      (row_idx),
        .occ_row      (field_occ_row),
        .type_row     (field_type_row),
        .p_type       (p_type),
        .p_rot        (p_rot),
        .p_x          (p_x),
        .p_y          (p_y),
        .p_mask       (p_mask),
        .next_type    (next_type),
        .next_mask    (next_mask),
        .score        (score),
        .st_idle       (st_idle),
        .st_pause       (st_pause),
        .st_over        (st_over),
        .level          (level),
        .lines          (lines)
    );

    //------------------------------------------------------------------
    // renderer
    //------------------------------------------------------------------
    wire [3:0] color_idx;

    render u_render (
        .px_log         (px_log),
        .col_idx        (col_idx),
        .row_idx        (row_idx),
        .col_px         (col_px),
        .row_px         (row_px),
        .p_type         (p_type),
        .p_x            (p_x),
        .p_y            (p_y),
        .shape_mask     (p_mask),
        .field_occ_row  (field_occ_row),
        .field_type_row (field_type_row),
        .color_idx      (color_idx)
    );

    localparam [3:0]COL_TEXT=4'h9;
    wire text_px,dim;

    fontlay u_fontlay(
        .st_idle        (st_idle),
        .st_pause       (st_pause),
        .st_over        (st_over),
        .px_log         (px_log),
        .py_log         (py_log),
        .text_px        (text_px),
        .dim            (dim)
    );

    wire [11:0] rgb_game;
    palette u_pal (
        .index (color_idx),
        .rgb   (rgb_game)
    );

    //------------------------------------------------------------------
    // VGA self test : sw[11] up replaces the game image with 8 colour bars
    //
    //   bars visible  -> timing, pins, cable and monitor are all fine, so
    //                    a missing game image is a render or core problem
    //   bars missing  -> the video path itself is wrong (reset, pins, cable)
    //
    // This costs a handful of LUTs and removes all guessing.
    //------------------------------------------------------------------
    wire [11:0] rgb_bar =
        (px < 10'd80 ) ? 12'hF00 :      // red
        (px < 10'd160) ? 12'h0F0 :      // green
        (px < 10'd240) ? 12'h00F :      // blue
        (px < 10'd320) ? 12'hFF0 :      // yellow
        (px < 10'd400) ? 12'hF0F :      // magenta
        (px < 10'd480) ? 12'h0FF :      // cyan
        (px < 10'd560) ? 12'hFFF : 12'h888;

    wire [11:0] rgb = sw[11] ? rgb_bar : rgb_game;

    wire [11:0] rgb_o;

    pixel_pipe u_pipe (
        .clk     (clk),
        .rst_n   (rst_n),
        .hsync_i (hsync),
        .vsync_i (vsync),
        .de_i    (de),
        .rgb_i   (rgb),
        .hsync_o (vga_hs),
        .vsync_o (vga_vs),
        .rgb_o   (rgb_o),
        .dim     (dim)
    );

    assign vga_r = rgb_o[11:8];
    assign vga_g = rgb_o[7:4];
    assign vga_b = rgb_o[3:0];

    //------------------------------------------------------------------
    // 7-segment score display
    //
    // score_display takes the three digits already split, so the binary to
    // BCD conversion lives here. Saturate at 999 because only three digits
    // are driven.
    //------------------------------------------------------------------
    wire [9:0] score_sat = (score > 16'd999) ? 10'd999 : score[9:0];

    wire [3:0] bcd_h = score_sat / 10'd100;                // hundreds
    wire [3:0] bcd_t = (score_sat % 10'd100) / 10'd10;     // tens
    wire [3:0] bcd_o = score_sat % 10'd10;                 // ones

    score_display u_seg (
        .clk      (clk),
        .rst_n    (rst_n),
        .hundrens (bcd_h),
        .tens     (bcd_t),
        .ones     (bcd_o),
        .seg      (seg),
        .dp       (dp),
        .an       (an)
    );

    //------------------------------------------------------------------
    // LEDs : key state plus a heartbeat
    //------------------------------------------------------------------
    reg [20:0] st_act;
    wire       any_edge = |key_edge;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                 st_act <= 21'd0;
        else if (any_edge)          st_act <= 21'd10_000_000;
        else if (st_act != 21'd0)   st_act <= st_act - 21'd1;
    end

    reg [4:0] hb_cnt;
    reg       hb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hb_cnt <= 5'd0;
            hb     <= 1'b0;
        end else if (frame_tick) begin
            if (hb_cnt == 5'd29) begin
                hb_cnt <= 5'd0;
                hb     <= ~hb;
            end else begin
                hb_cnt <= hb_cnt + 5'd1;
            end
        end
    end

    assign led[7:0]   = key_pressed;
    assign led[8]     = (st_act != 21'd0);
    assign led[9]     = sw[12];              // START level
    assign led[10]    = sw[13];              // RESTART level
    assign led[11]    = sw[14];              // PAUSE level
    assign led[12]    = 1'b0;
    assign led[13]    = ~rst_n;              // on while held in reset
    assign led[14]    = sw[11];              // colour bar mode
    assign led[15]    = hb;                  // 1 Hz heartbeat

endmodule
