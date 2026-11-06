`timescale 1ns / 1ps
module fontlay(
input st_idle,
input st_pause,
input st_over,
input [8:0]px_log,
input [8:0]py_log,
output text_px,
output dim

    );

    //char_codes
    localparam [5:0] CH_SP = 6'd0;
    localparam [5:0] CH_A  = 6'd1;
    localparam [5:0] CH_E  = 6'd5;
    localparam [5:0] CH_G  = 6'd7;
    localparam [5:0] CH_M  = 6'd13;
    localparam [5:0] CH_O  = 6'd15;
    localparam [5:0] CH_P  = 6'd16;
    localparam [5:0] CH_R  = 6'd18;
    localparam [5:0] CH_S  = 6'd19;
    localparam [5:0] CH_T  = 6'd20;
    localparam [5:0] CH_U  = 6'd21;
    localparam [5:0] CH_V  = 6'd22;

    localparam [5:0]MSG_ROW =6'd14 ;

    wire [5:0] char_col=px_log[8:3];
    wire [5:0] char_row=py_log[8:3];
    wire [2:0] char_x=px_log[2:0];
    wire [2:0] char_y=py_log[2:0];

    reg [5:0]msg_col_start;
    reg [5:0]msg_len;
    reg msg_show;

    always @(*) begin
        msg_show=1'b1;
        if(st_idle)begin//start
            msg_col_start=6'd18;
            msg_len=6'd5;
        end else if(st_pause)begin//pause
            msg_col_start=6'd18;
            msg_len=6'd5;
        end else if(st_over)begin//game over
            msg_col_start=6'd16;
            msg_len=6'd9;
        end else begin
            msg_col_start=6'd0;
            msg_len=6'd0;
            msg_show=1'd0;
        end
    end
wire in_msg_row = (char_row==MSG_ROW);
wire in_msg_col =(char_col>=msg_col_start)&&(char_col<msg_col_start+msg_len);

wire [5:0]msg_idx=char_col-msg_col_start;

reg [5:0]char_code;
always @(*) begin
    char_code=CH_SP;
    if(msg_show && in_msg_row && in_msg_col)begin
        if(st_idle)begin
            case(msg_idx)
                6'd0:char_code=CH_S;
                6'd1:char_code=CH_T;
                6'd2:char_code=CH_A;
                6'd3:char_code=CH_R;
                6'd4:char_code=CH_T;
                default:char_code=CH_SP;
            endcase
        end else if(st_pause)begin
            case(msg_idx)
                6'd0:char_code=CH_P;
                6'd1:char_code=CH_A;
                6'd2:char_code=CH_U;
                6'd3:char_code=CH_S;
                6'd4:char_code=CH_E;
                default:char_code=CH_SP;
            endcase
        end else if(st_over)begin
            case(msg_idx)
                6'd0:char_code=CH_G;
                6'd1:char_code=CH_A;
                6'd2:char_code=CH_M;
                6'd3:char_code=CH_E;
                6'd4:char_code=CH_SP;
                6'd5:char_code=CH_O;
                6'd6:char_code=CH_V;
                6'd7:char_code=CH_E;
                6'd8:char_code=CH_R;
                default:char_code=CH_SP;
            endcase
        end
    end
end
wire [7:0]row_bits;
font_rom u_font (
    .char_code(char_code),
    .glyph_row(char_y),
    .row_bits (row_bits)
);

wire glyph_px=row_bits[3'd7 - char_x];

assign text_px=msg_show && in_msg_col && in_msg_row && glyph_px;
assign dim=(st_idle|st_pause|st_over)&&!text_px;
endmodule
