`timescale 1ns / 1ps
//7-bag property check.
module tb_piece_random;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg spawn = 1'b0;
    always #5 clk = ~clk;

    wire [2:0] piece_type;

    piece_random dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .spawn      (spawn),
        .piece_type (piece_type)
    );

    localparam NBAG   = 100;
    localparam NPIECE = NBAG * 7;

    reg [2:0] picks [0:NPIECE-1];

    reg [31:0] errors, checks;
    reg [31:0] n, b;
    reg [3:0]  k;
    reg [15:0] cnt [0:6];
    reg [31:0] last_idx [0:6];
    reg [31:0] gap, max_gap;
    reg [2:0]  p;

    task check(input [8*44-1:0] name, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 32'd1;
            if (got !== exp) begin
                errors = errors + 32'd1;
                $display("FAIL %0s : got %0d, expected %0d", name, got, exp);
            end
        end
    endtask

    // read the currently offered piece, then advance the bag
    task do_spawn(output [2:0] got);
        begin
            got = piece_type;
            spawn = 1'b1;
            @(posedge clk);
            spawn = 1'b0;
            repeat (20) @(posedge clk);   // DRAW needs at most 8 cycles
        end
    endtask

    initial begin
        errors = 32'd0;
        checks = 32'd0;
        $display("tb_piece_random");

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (20) @(posedge clk);        // first piece is drawn after reset

        for (n = 32'd0; n < NPIECE; n = n + 32'd1) begin
            do_spawn(picks[n]);
            check("type in range", (picks[n] > 3'd6) ? 32'd1 : 32'd0, 32'd0);
        end

        // every aligned bag is a permutation
        for (b = 32'd0; b < NBAG; b = b + 32'd1) begin
            for (k = 4'd0; k < 4'd7; k = k + 4'd1)
                cnt[k] = 16'd0;
            for (k = 4'd0; k < 4'd7; k = k + 4'd1) begin
                p = picks[b*7 + k];
                if (p <= 3'd6)
                    cnt[p] = cnt[p] + 16'd1;
            end
            for (k = 4'd0; k < 4'd7; k = k + 4'd1) begin
                checks = checks + 32'd1;
                if (cnt[k] != 16'd1) begin
                    errors = errors + 32'd1;
                    $display("FAIL bag %0d : type %0d appears %0d times", b, k, cnt[k]);
                end
            end
        end
        $display("checked %0d bags of 7 pieces", NBAG);

        // drought bound
        max_gap = 32'd0;
        for (k = 4'd0; k < 4'd7; k = k + 4'd1)
            last_idx[k] = 32'hFFFFFFFF;
        for (n = 32'd0; n < NPIECE; n = n + 32'd1) begin
            p = picks[n];
            if (last_idx[p] != 32'hFFFFFFFF) begin
                gap = n - last_idx[p];
                if (gap > max_gap)
                    max_gap = gap;
            end
            last_idx[p] = n;
        end
        $display("longest gap between two identical pieces = %0d (bound 13)", max_gap);
        check("drought bound", (max_gap > 32'd13) ? 32'd1 : 32'd0, 32'd0);

        // show the first bags
        $display("first 6 bags");
        for (b = 32'd0; b < 32'd6; b = b + 32'd1) begin
            $write("  bag %0d :", b);
            for (k = 4'd0; k < 4'd7; k = k + 4'd1)
                $write(" %0d", picks[b*7 + k]);
            $write("\n");
        end

        if (errors == 0)
            $display("PASS tb_piece_random (%0d checks)", checks);
        else
            $display("FAIL tb_piece_random (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL tb_piece_random: timeout");
        $finish;
    end

endmodule
