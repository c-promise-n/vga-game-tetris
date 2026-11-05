`timescale 1ns / 1ps
module render(
input [8:0]px_log,
//input [8:0]py_log,remain for expansion
input [4:0]col_idx,
input [4:0]row_idx,
input [3:0]col_px,
input [3:0]row_px,
input [2:0]p_type,
input [4:0]p_x,
input [4:0]p_y,
input [15:0]shape_mask,
input [9:0]field_occ_row,
input [29:0]field_type_row,
output reg[3:0]color_idx
    );

    localparam [8:0]well_end  = 119;
    localparam [8:0]panel_begin=132;


    wire in_field,in_border,in_panel;
    assign in_field =(px_log <= well_end);
    assign in_border=(px_log < panel_begin)&&(px_log > well_end);
    assign in_panel =(px_log>=panel_begin);

    wire hit_piece,occ,grid;

    assign grid =((col_px==4'd0)||(row_px==4'd0));

    wire [2:0]cell_type;
    wire [4:0]cell_c;
    assign cell_c=(col_idx<=4'd9)?col_idx:5'd0;
    assign occ=field_occ_row[cell_c];
    assign cell_type=field_type_row[3*cell_c+:3];


    wire [5:0]drow,dcol;
    assign drow={1'b0,row_idx}-{1'b0,p_y};
    assign dcol={1'b0,col_idx}-{1'b0,p_x}+6'd2;
    wire inbox;
    assign inbox=(drow<=6'd3)&&(dcol<=6'd3);
    assign hit_piece=inbox && shape_mask[{drow[1:0],dcol[1:0]}];


    always @(*) begin
         if(in_field)begin
            if(hit_piece)begin
                color_idx = p_type +4'h2;
            end else if(occ)begin
                color_idx = cell_type + 4'h2;
            end else if(grid)begin
                color_idx= 4'h1;
            end else begin
                color_idx= 4'hE;
            end
        end else if(in_border)begin
            color_idx=  4'hD;
        end else if(in_panel)begin
            color_idx=4'hF;
        end else begin
            color_idx=4'h0;
        end
    end
endmodule
