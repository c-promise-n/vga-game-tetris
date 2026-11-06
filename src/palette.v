`timescale 1ns / 1ps
module palette(
 input [3:0]index,
 output reg[11:0]rgb
    );

    always @(*) begin
        case(index)
        4'h0:rgb={{4'h0},{4'h0},{4'h2}};//background
        4'h1:rgb={{4'h3},{4'h3},{4'h6}};//grid lines
        4'h2:rgb={{4'h0},{4'hE},{4'hE}};//cyan:I
        4'h3:rgb={{4'hF},{4'hE},{4'h0}};//yellow:O
        4'h4:rgb={{4'hC},{4'h0},{4'hE}};//purple:T
        4'h5:rgb={{4'h0},{4'hE},{4'h0}};//green:S
        4'h6:rgb={{4'hF},{4'h0},{4'h0}};//red:Z
        4'h7:rgb={{4'h0},{4'h2},{4'hF}};//blue:J
        4'h8:rgb={{4'hF},{4'h7},{4'h0}};//orange:L
        4'h9:rgb={{4'hF},{4'hF},{4'hF}};//white
        4'hA:rgb={{4'h4},{4'h4},{4'h6}};//landing ghost
        4'hB:rgb={{4'h0},{4'h0},{4'h5}};//incell highlight
        4'hC:rgb={{4'hF},{4'hF},{4'hF}};//line-clear flash
        4'hD:rgb={{4'h8},{4'h8},{4'hA}};//border
        4'hE:rgb={{4'h0},{4'h0},{4'h2}};//well background
        4'hF:rgb={{4'h0},{4'h0},{4'h0}};//panel background
        default:rgb={{4'h0},{4'h0},{4'h0}};//default black
        endcase
    end
endmodule
