`timescale 1ns / 1ps
module pixel_pipe(
input clk,
input rst_n,
input hsync_i,
input vsync_i,
input de_i,
input dim,
input [11:0]rgb_i,
output reg hsync_o,
output reg vsync_o,
output reg [11:0]rgb_o
    );

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        hsync_o<=1'b1;
        vsync_o<=1'b1;
        rgb_o<=12'b0;
    end else begin
        hsync_o<=hsync_i;
        vsync_o<=vsync_i;
        rgb_o<= de_i?(dim?({1'b0,rgb_i[11:1]}):rgb_i):12'h000;
    end
end

endmodule
