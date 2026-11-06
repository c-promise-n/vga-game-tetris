`timescale 1ns / 1ps
module tetris_core(
input clk,
input rst_n,

input frame_tick,

input [7:0]key_edge,
input [7:0]key_pressed,
input move_left,
input move_right,

input [4:0]row_idx,
output [9:0]occ_row,
output [29:0]type_row,

output reg [2:0]p_type,
output reg [1:0]p_rot,
output reg [4:0]p_x,
output reg [4:0]p_y,
output wire [15:0]p_mask,

output reg[2:0]next_type,
output wire[15:0]next_mask,


output reg[15:0]score,
output reg [2:0]level,
output reg [6:0]lines,

output st_idle,
output st_pause,
output st_over

  );

  shape_rom u_shape_rom (
    .bricktype(p_type),
    .rot      (p_rot),
    .mask     (p_mask)
  );
  shape_rom u_shape_rom_nx (
    .bricktype(next_type),
    .rot      (2'd0),
    .mask     (next_mask)
  );

  reg [9:0] field_occ [0:19];
  reg [29:0]field_type[0:19];

  assign occ_row=field_occ[row_idx];
  assign type_row=field_type[row_idx];

  reg   pr_spawn;
  wire[2:0]pr_type;
  piece_random u_pr (
    .clk       (clk),
    .rst_n     (rst_n),
    .spawn     (pr_spawn),
    .piece_type(pr_type)
  );
  wire [1:0]rot_nx=p_rot+2'd1;
  wire[15:0]mask_try;
  shape_rom u_rom_try (
    .bricktype(p_type),
    .rot      (rot_nx),
    .mask     (mask_try)
  );
 //b_x is biased by+2
  function automatic collide;
    input[4:0]b_x;
    input[4:0]b_y;
    input [15:0]b_mask;
    integer i;
    reg[19:0]row_i;
    begin
      collide=1'b0;
      if(b_x>5'd15)begin
        collide=1'b1;
      end else begin
      for(i=0;i<4;i=i+1)begin
        row_i={16'd0,b_mask[i*4 +: 4]};
        row_i=row_i <<b_x;
        if(row_i!=20'd0)begin
        if((b_y + i)>19)
        collide=1'd1;
        else if(row_i[1:0]!=2'b00)
        collide=1'b1;
        else if(row_i>20'h00FFC)
        collide=1'b1;
        else if((row_i[11:2]&field_occ[b_y+i])!=10'b0)
        collide=1'b1;
        end
      end
    end
    end
  endfunction

  function [29:0]type_expand;
  input[9:0]occ_mask;
  input[2:0]b_type;
  integer i;
  begin
    type_expand=30'd0;
    for(i=0;i<10;i=i+1)begin
      if(occ_mask[i]) type_expand[3*i+:3]=b_type;
    end
  end
  endfunction

  localparam IDLE =2'd0 ,
             PLAY=2'd1 ,
             PAUSE=2'd2,
             OVER=2'd3;
  reg game_over;
  wire drop,down;
  reg [1:0]cur_state,next_state;
  wire start_paulse,restart_paulse,pause_pulse;
  assign start_paulse=key_edge[7]|key_edge[6];
  assign restart_paulse=key_edge[6];
  assign pause_pulse=key_edge[5];
  assign drop=key_edge[4];
  assign down=key_pressed[2];
  wire rotate;
  assign rotate=key_edge[3];
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
      cur_state<=IDLE;
    end else begin
      cur_state<=next_state;
    end
  end

  always @(*) begin
    next_state=cur_state;
    case (cur_state)
      IDLE:if(start_paulse) next_state=PLAY;

      PLAY:if(pause_pulse) next_state=PAUSE;
        else if(game_over) next_state=OVER;

      PAUSE:if(pause_pulse)next_state=PLAY;

      OVER:if(restart_paulse)next_state=PLAY;
      default:next_state=IDLE;
    endcase
  end

  integer r,j;
  wire landed;


  reg[19:0]row_j;
  assign landed=collide(p_x, p_y +5'd1/* logic[4:0] */, p_mask /* logic[15:0] */);
  wire [7:0]grave_level[3
  :0];
  assign grave_level[0]=8'd30;
  assign grave_level[1]=8'd22;
  assign grave_level[2]=8'd16;
  assign grave_level[3]=8'd10;

  wire [7:0]GRAV =grave_level[level];
 reg [7:0]grav_cnt;

 localparam P_FALL = 2'd0,P_TOUCH=2'd1,P_DROP=2'd2,P_SETTLE=2'd3;
 parameter lock_delay = 5'd30;
 reg [1:0]phase;
  wire piece_active=(cur_state==PLAY)&&((phase==P_FALL)||(phase==P_TOUCH));

  reg lc_issued,lc_start,lc_done;

  reg [4:0]lock_cnt;

  task do_lock;
  begin
          for(j=0;j<4;j=j+1)begin
            row_j={16'd0,p_mask[j*4 +: 4]};
            row_j=row_j<<p_x;
            if((p_y+j<=19)&&(row_j<=20'h00FFC)&&(row_j[1:0]==2'b00))begin
              field_occ[p_y+j]<=field_occ[p_y+j] | row_j[11:2];
              field_type[p_y+j]<=field_type[p_y+j]|type_expand(row_j[11:2] /* logic[9:0] */, p_type /* logic[2:0] */);
            end
          end
  end
  endtask

  task do_spawn;
  begin
          p_type<=next_type;
          p_rot<=2'b0;
          p_x<=5'd5;
          p_y<=5'd0;
          next_type<=pr_type;
          pr_spawn<=1'b1;
          grav_cnt<=8'd0;
          lock_cnt<=5'd0;
          phase<=P_FALL;
          if(collide(5'd5, 5'd0 /* logic[4:0] */, next_mask /* logic[15:0] */)) game_over<=1'b1;
  end
  endtask

localparam L_IDLE = 2'd0,
            L_COLL=2'd1,
            L_FILL=2'd2;

reg [1:0]lc_state;
reg [4:0]rp,wp;
wire [19:0]full_now;
reg [19:0] full_lat;
reg [2:0]lc_n;
genvar gi;
reg [4:0]pre_cnt;
reg     pre_done;
generate
  for(gi=0;gi<20;gi=gi+1)begin:g_full
    assign full_now[gi]={field_occ[gi]==10'h3FF};
  end
endgenerate
  always@(posedge clk or negedge rst_n)begin
      if(!rst_n)begin
        for(r=0;r<20;r=r+1)begin
          field_occ[r]<=10'd0;
          field_type[r]<=30'd0;
        end
        p_type  <=3'd0;
        p_rot   <=2'd0;
        p_x     <=5'd5;
        p_y     <=5'd0;
        next_type<=3'd0;
        pr_spawn<=1'b0;
        lock_cnt<=5'd0;
        lc_issued<=1'd0;
        grav_cnt<=8'b0;
        level<=3'd0;
        lines<=7'd0;
        game_over<=1'b0;
        pre_cnt<=5'd0;
        pre_done<=1'd0;
        phase<=P_FALL;
        lc_start<=1'b0;
        lc_done<=1'b0;
        lc_state<=L_IDLE;
        rp<=5'd19;
        wp<=5'd19;
        lc_n<=3'd0;
        lc_issued<=1'b0;
        score<=16'b0;
    end else begin
      pr_spawn<=1'b0;
      game_over<=1'b0;
      lc_start<=1'b0;
      lc_done<=1'b0;

      if(restart_paulse)begin
        for(r=0;r<20;r=r+1)begin
          field_occ[r]<=10'd0;
          field_type[r]<=30'd0;
        end
        p_type  <=3'd0;
        p_rot   <=2'd0;
        p_x     <=5'd5;
        p_y     <=5'd0;
        next_type<=3'd0;
        pr_spawn<=1'b0;
        lock_cnt<=5'd0;
        lc_issued<=1'd0;
        grav_cnt<=8'b0;
        level<=3'd0;
        lines<=7'd0;
        game_over<=1'b0;
        pre_cnt<=5'd0;
        pre_done<=1'd0;
        phase<=P_FALL;
        lc_start<=1'b0;
        lc_done<=1'b0;
        lc_state<=L_IDLE;
        rp<=5'd19;
        wp<=5'd19;
        lc_n<=3'd0;
        lc_issued<=1'b0;
        score<=16'b0;
      end else begin
        if(!pre_done&&!start_paulse)begin
          if(pre_cnt==5'd8)begin
            p_type<=pr_type;
            pr_spawn<=1'b1;
          end else if(pre_cnt==5'd20)begin
            next_type<=pr_type;
            pre_done<=1'b1;
            pr_spawn<=1'b1;
          end
          pre_cnt<=pre_cnt+1'b1;
        end

        if(start_paulse)begin
        pre_cnt<=5'd0;
        pre_done<=1'd0;
        end

      if(piece_active && move_left && !move_right)begin
        if(!collide(p_x-5'd1 /* logic[4:0] */, p_y /* logic[4:0] */, p_mask /* logic[15:0] */))begin
          p_x<=p_x-1'b1;
        end
      end

      if(piece_active && !move_left && move_right)begin
        if(!collide(p_x+5'd1 /* logic[4:0] */, p_y /* logic[4:0] */, p_mask /* logic[15:0] */))begin
          p_x<=p_x+1'b1;
        end
      end

      if(piece_active && rotate)begin
        if(!collide(p_x /* logic[4:0] */, p_y /* logic[4:0] */, mask_try/* logic[15:0] */))begin
          p_rot<=rot_nx;
        end
            else if(!collide(p_x-5'd1 /* logic[4:0] */, p_y /* logic[4:0] */, mask_try/* logic[15:0] */))begin
              p_rot<=rot_nx;
              p_x<=p_x-5'd1;
            end
            else if(!collide(p_x+5'd1 /* logic[4:0] */, p_y /* logic[4:0] */, mask_try/* logic[15:0] */))begin
              p_rot<=rot_nx;
              p_x<=p_x+5'd1;
            end
            else if(!collide(p_x-5'd2 /* logic[4:0] */, p_y /* logic[4:0] */, mask_try/* logic[15:0] */))begin
              p_rot<=rot_nx;
              p_x<=p_x-5'd2;
            end
            else if(!collide(p_x+5'd2 /* logic[4:0] */, p_y /* logic[4:0] */, mask_try/* logic[15:0] */))begin
              p_rot<=rot_nx;
              p_x<=p_x+5'd2;
            end
      end

      if(piece_active && drop)begin
        phase<=P_DROP;
      end

      if(cur_state==PLAY&&phase==P_DROP)begin
        if(!collide(p_x /* logic[4:0] */, p_y+5'd1 /* logic[4:0] */, p_mask /* logic[15:0] */))begin
          p_y<=p_y+5'd1;
          score<=score+16'd2;
        end else begin
          do_lock();
          lc_issued<=1'd0;
          phase<=P_SETTLE;
        end
      end

      if(frame_tick && (cur_state==PLAY))begin
        case(phase)

          P_FALL:begin
            if(down)begin
              if(!landed)begin
                p_y<=p_y+5'd1;
                score<=score+16'd1;
              end else begin
                lock_cnt<=5'd0;
                phase<=P_TOUCH;
              end
            end else if(!landed)begin
            if(grav_cnt == GRAV-1'b1)begin
              grav_cnt<=8'd0;
              p_y<=p_y+5'd1;
            end else begin
              grav_cnt<=grav_cnt+8'd1;
            end
            end else begin
            lock_cnt<=5'd0;
            phase<=P_TOUCH;
            grav_cnt<=8'd0;
            end
          end

          P_TOUCH:begin
            if(!landed)begin
              lock_cnt<=5'd0;
              phase<=P_FALL;
              grav_cnt<=8'd0;
            end else if(lock_cnt==lock_delay)begin
              do_lock();
              lc_issued<=1'd0;
              phase<=P_SETTLE;
            end else begin
              lock_cnt<=lock_cnt+5'd1;
            end
          end

          P_SETTLE:begin
            if((lc_state==IDLE)&&(!lc_issued))begin
              if(|full_now)begin
                lc_start<=1'b1;
                lc_issued<=1'b1;
              end else begin
                do_spawn;
              end
            end
          end

        endcase
      end

      if(lc_done)begin
        case (lc_n)
          3'd1:begin
            score<=score+16'd10;
            lines<=lines+7'd1;
            end
          3'd2:begin
            score<=score+16'd30;
            lines<=lines+7'd2;
            end
          3'd3:begin
            score<=score+16'd60;
            lines<=lines+7'd3;
          end
          3'd4:begin
            score<=score+16'd100;
            lines<=lines+7'd4;
          end
          default:begin
            score<=score;
            lines<=lines;
          end
        endcase
          if(lines<9)begin
            level<=3'b0;
          end else if(lines<19)begin
            level<=3'b1;
          end else if(lines<29)begin
            level<=3'd2;
          end else begin
            level<=3'd3;
          end
        do_spawn;
        lc_issued<=1'b0;
      end

      case(lc_state)

      L_IDLE:begin
        rp<=5'd19;
        wp<=5'd19;
        lc_n<=3'd0;
        if(lc_start&&(|full_now))begin
          full_lat<=full_now;
          lc_state<=L_COLL;
        end
      end

      L_COLL:begin
        if(full_lat[rp])begin
        lc_n<=lc_n+3'b1;
        end else begin
          field_occ[wp]<=field_occ[rp];
          field_type[wp]<=field_type[rp];
          wp<=wp-5'd1;
        end
        if(rp==5'd0) lc_state<=L_FILL;
        else rp<=rp-5'd1;
      end

      L_FILL:begin
        field_occ[wp]<=10'd0;
        field_type[wp]<=30'd0;
        if(wp==5'd0)begin
          lc_state<=L_IDLE;
          lc_done<=1'b1;
        end else begin
          wp<=wp-5'd1;
        end
      end
      endcase
    end
  end
  end
  assign st_idle=(cur_state==IDLE);
  assign st_pause=(cur_state==PAUSE);
  assign st_over=(cur_state==OVER);
endmodule
