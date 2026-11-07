`timescale 1ns / 1ps
module bin_to_bcd(
input[15:0]bin,
output [3:0]hundreds,
output [3:0]tens,
output [3:0]ones
    );
    wire[9:0] bin_sat = (bin > 16'd999) ? 10'd999 : bin[9:0];
    integer i;
    reg [21:0]shift_reg;
    reg[11:0]bcd_r;
    always @(*) begin
        shift_reg={12'd0,bin_sat};
        for(i=0;i<10;i=i+1)begin
            if (shift_reg[21:18] > 4'd4)
                shift_reg[21:18] = shift_reg[21:18] + 4'd3;
            if (shift_reg[17:14] > 4'd4)
                shift_reg[17:14] = shift_reg[17:14] + 4'd3;
            if (shift_reg[13:10] > 4'd4)
                shift_reg[13:10] = shift_reg[13:10] + 4'd3;

            shift_reg=shift_reg<<1;
        end
        bcd_r=shift_reg[21:10];
    end
    assign hundreds=bcd_r[11:8];
    assign tens=bcd_r[7:4];
    assign ones=bcd_r[3:0];
endmodule
