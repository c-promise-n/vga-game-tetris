`timescale 1ns / 1ps
module panel(
input [8:0]px_log,
input [8:0]py_log,
input [2:0]next_type,
input [15:0]next_mask,
input [15:0]score,
input [2:0]level,
input [6:0]lines,
output reg [3:0]color_idx_panel
    );

    //char_codes
    localparam [5:0] CH_SP = 6'd0;
    localparam [5:0] CH_C  = 6'd3;
    localparam [5:0] CH_E  = 6'd5;
    localparam [5:0] CH_I  = 6'd9;
    localparam [5:0] CH_L  = 6'd12;
    localparam [5:0] CH_N  = 6'd14;
    localparam [5:0] CH_O  = 6'd15;
    localparam [5:0] CH_R  = 6'd18;
    localparam [5:0] CH_S  = 6'd19;
    localparam [5:0] CH_V  = 6'd22;
    localparam [5:0] CH_0  = 6'd27;


wire [3:0]score_h,score_t,score_o;
wire [3:0]lines_h,lines_t,lines_o;
bin_to_bcd u_score (
    .bin     (score),
    .hundreds(score_h),
    .tens    (score_t),
    .ones    (score_o)
);

bin_to_bcd u_lines (
    .bin     ({9'd0,lines}),
    .hundreds(lines_h),
    .tens    (lines_t),
    .ones    (lines_o)
);
localparam [8:0]NEXT_X0 = 9'd194;
localparam [8:0]NEXT_Y0=9'd52;

wire in_next=(px_log>=NEXT_X0)&&(px_log<NEXT_X0+9'd64)&&
            (py_log>=NEXT_Y0)&&(py_log<NEXT_Y0+9'd64);
wire [8:0]offset_x=(next_type<=3'd1)?9'd0:9'd8;
wire [8:0]offset_y=(next_type==3'd0)?9'd8:9'd0;

wire [8:0]next_x0=NEXT_X0+offset_x;
wire [8:0]next_y0=NEXT_Y0+offset_y;
wire [8:0]next_pos_x=px_log-next_x0;
wire [8:0]next_pos_y=py_log-next_y0;

wire [1:0]next_col=next_pos_x[5:4];
wire [1:0]next_row=next_pos_y[5:4];
wire next_cell=in_next && next_mask[{next_row,next_col}];
wire next_edge=(px_log==NEXT_X0)||(px_log==NEXT_X0+9'd63)||
            (py_log==NEXT_Y0)||(py_log==NEXT_Y0+9'd63);


localparam [8:0]LABLE_X0 =9'd206;
wire in_lable_x=(px_log>=LABLE_X0)&&(px_log<246);
wire [8:0]label_pos_x=px_log-LABLE_X0;
wire [2:0]label_idx=label_pos_x[5:3];
wire [2:0]label_glyph_x=label_pos_x[2:0];

wire label_score_row=(py_log>=9'd116)&&(py_log<124);
wire label_level_row=(py_log>=9'd140)&&(py_log<148);
wire label_lines_row=(py_log>=9'd164)&&(py_log<172);
wire in_label_y=label_score_row|label_level_row|label_lines_row;

wire label_region=in_label_y&&in_lable_x;

reg[8:0]label_y0;
always @(*) begin
    label_y0=9'd116;
    if(label_level_row)label_y0=9'd140;
    else if(label_lines_row)label_y0=9'd164;
end
wire [8:0]label_pos_y=py_log-label_y0;
wire [2:0]label_glyph_y=label_pos_y[2:0];

reg[5:0]label_char;
always @(*) begin
    label_char=CH_SP;
    case (label_idx)
        3'd0: label_char=label_score_row?CH_S:
                         label_level_row?CH_L:
                         CH_L;
        3'd1: label_char=label_score_row?CH_C:
                         label_level_row?CH_E:
                         CH_I;
        3'd2: label_char=label_score_row?CH_O:
                         label_level_row?CH_V:
                         CH_N;
        3'd3: label_char=label_score_row?CH_R:
                         label_level_row?CH_E:
                         CH_E;
        3'd4: label_char=label_score_row?CH_E:
                         label_level_row?CH_L:
                         CH_S;
        default: label_char=CH_SP;
    endcase
end


wire dig_score_row=(py_log>=9'd124)&&(py_log<9'd140);
wire dig_level_row=(py_log>=9'd148)&&(py_log<9'd164);
wire dig_lines_row=(py_log>=9'd172)&&(py_log<9'd188);
reg[8:0]dig_x0,dig_y0;
always @(*) begin
    dig_x0 =9'd202;
    dig_y0=9'd124;
    if(dig_level_row)begin
        dig_x0=9'd218;
        dig_y0=9'd148;
    end else if(dig_lines_row)begin
        dig_y0=9'd172;
    end
end
wire in_dig_x = (px_log>=dig_x0)&&(px_log<dig_x0+48);
wire [8:0]dig_pos_x=px_log-dig_x0;
wire [8:0]dig_pos_y=py_log-dig_y0;

wire[1:0]dig_idx=dig_pos_x[5:4];
wire [2:0]dig_glyph_x=dig_pos_x[3:1];
wire [2:0]dig_glyph_y=dig_pos_y[3:1];

wire in_dig_y=dig_level_row|dig_level_row|dig_lines_row;
wire dig_region=in_dig_x && in_dig_y;
reg [3:0]dig_val;
always@(*)begin
    dig_val=4'hF;
    if(dig_score_row)begin
        case(dig_idx)
        2'd0:dig_val=score_h;
        2'd1:dig_val=score_t;
        2'd2:dig_val=score_o;
        default:dig_val=score_o;
        endcase
    end else if(label_level_row)begin
        if(dig_idx==2'd0)dig_val={1'b0,level};
    end else if(dig_lines_row)begin
        case(dig_idx)
        2'd0:dig_val=lines_h;
        2'd1:dig_val=lines_t;
        2'd2:dig_val=lines_o;
        default:dig_val=lines_o;
        endcase
    end
end

wire[5:0]glyph_ch=label_region?label_char:
                    (dig_val==4'hF)?CH_SP:(CH_0+{2'b00,dig_val});
wire [2:0]glyph_y=label_region?label_glyph_y:dig_glyph_y;
wire[7:0]glyph_bits;
font_rom u_font (
    .char_code(glyph_ch),
    .glyph_row(glyph_y),
    .row_bits (glyph_bits)
);
wire [2:0]glyph_x=label_region?label_glyph_x:dig_glyph_x;
wire glyph_px=glyph_bits[3'd7-glyph_x];
wire text_px=(label_region||dig_region)&&glyph_px;
always@(*)begin
    color_idx_panel=4'hF;
    if(text_px)begin
        color_idx_panel=4'h9;
    end else if(in_next)begin
        if(next_edge)color_idx_panel=4'hD;
        else if(next_cell)color_idx_panel=4'h2+{1'b0,next_type};
        else    color_idx_panel=4'hE;
    end
end
endmodule
