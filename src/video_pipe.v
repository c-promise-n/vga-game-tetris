`timescale 1ns / 1ps
module video_pipe(
input clk,
input rst_n,
input hsync_i,
input vsync_i,
input de_i,
input dim_i,
input [3:0]color_idx_i,
output  hsync_o,
output  vsync_o,
output  [11:0]rgb_o
    );
reg [3:0]color_idx_r0;
reg dim_r0;
reg hsync_r0,hsync_r1;
reg vsync_r0,vsync_r1;
reg de_r0;

wire [11:0]rgb_game;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        hsync_r0<=1'b1;
        vsync_r0<=1'b1;
        color_idx_r0<=4'd0;
        dim_r0<=1'd0;
        de_r0<=1'b0;
    end else begin
        hsync_r0<=hsync_i;
        vsync_r0<=vsync_i;
        color_idx_r0<=color_idx_i;
        dim_r0<=dim_i;
        de_r0<=de_i;
    end
end

palette u_pal (
    .index(color_idx_r0),
    .rgb  (rgb_game)
);
wire [11:0]rgb_r0=dim_r0?({1'b0,rgb_game[11:1]}):rgb_game;
reg [11:0]rgb_r1;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        hsync_r1<=1'b1;
        vsync_r1<=1'b1;
        rgb_r1<=12'b0;
    end else begin
        hsync_r1<=hsync_r0;
        vsync_r1<=vsync_r0;
        rgb_r1<= de_r0?rgb_r0:12'h000;
    end
end

assign hsync_o=hsync_r1;
assign vsync_o=vsync_r1;
assign rgb_o=rgb_r1;
endmodule
