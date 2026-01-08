`ifdef RTL
    `define CYCLE_TIME 10.0
`endif
`ifdef GATE
    `define CYCLE_TIME 10.0
`endif
`ifdef POST
    `define CYCLE_TIME 11.2
`endif

//`define CYCLE_TIME 11.2
integer SEED = 8787;
parameter PATNUM = 10;
// test 123
module PATTERN(
    clk,
    rst_n,
    in_valid,
    in_valid2,
    in_data,
    out_valid,
    out_sad
);
output reg clk, rst_n, in_valid, in_valid2;
output reg [8:0] in_data;
input out_valid;
input out_sad;

// ========================================
// clock
// ========================================
real CYCLE = `CYCLE_TIME;
always	#(CYCLE/2.0) clk = ~clk; //clock

// ========================================
// integer & parameter
// ========================================
integer SEED = 8787;
integer PATNUM = 1;
parameter MAX_EXECUTION_CYCLE = 1000;

integer total_lat;
integer i, j, k;
integer delay_cnt;
integer ii, jj;
integer pixel;
integer execution_lat;

integer L0 [0:127][0:127];
integer L1 [0:127][0:127];

integer tmp;
integer dx, dy;

integer mvx_l0_p1_i, mvy_l0_p1_i;
integer mvx_l0_p2_i, mvy_l0_p2_i;
integer mvx_l1_p1_i, mvy_l1_p1_i;
integer mvx_l1_p2_i, mvy_l1_p2_i;

reg frac;

reg fracx_l0_p1, fracy_l0_p1;
reg fracx_l1_p1, fracy_l1_p1;
reg fracx_l0_p2, fracy_l0_p2;
reg fracx_l1_p2, fracy_l1_p2;

integer satd_p1[0:8];  
integer satd_p2[0:8];   
integer min_cost_p1, min_idx_p1;
integer min_cost_p2, min_idx_p2;

reg [55:0] golden_out; 

// ========================================
// wire & reg
// ========================================

reg[9*8:1]  reset_color       = "\033[1;0m";
reg[10*8:1] txt_black_prefix  = "\033[1;30m";
reg[10*8:1] txt_red_prefix    = "\033[1;31m";
reg[10*8:1] txt_green_prefix  = "\033[1;32m";
reg[10*8:1] txt_yellow_prefix = "\033[1;33m";
reg[10*8:1] txt_blue_prefix   = "\033[1;34m";

reg[10*8:1] bkg_black_prefix  = "\033[40;1m";
reg[10*8:1] bkg_red_prefix    = "\033[41;1m";
reg[10*8:1] bkg_green_prefix  = "\033[42;1m";
reg[10*8:1] bkg_yellow_prefix = "\033[43;1m";
reg[10*8:1] bkg_blue_prefix   = "\033[44;1m";
reg[10*8:1] bkg_white_prefix  = "\033[47;1m";
//================================================================
// design
//================================================================
initial begin
    reset_task;
    for(i = 0; i < PATNUM; i = i + 1) begin
        input_image;
        for(j = 0; j < 64; j = j + 1) begin
            wait_random_3_to_6;
            input_mv;
            calc_golden_for_one_pair;
            wait_output; 
            check_task;
        end
        wait_random_3_to_6;
    end
    display_pass;
    $finish;
end

task reset_task; begin
    force clk = 0;
    rst_n = 1;
    in_valid  = 0;
    in_valid2 = 0;
    in_data = 'dx;

    void'($urandom(SEED));
    total_lat = 0;

    #(CYCLE * 5) rst_n = 0;
    #(CYCLE * 5) rst_n = 1;
    if (out_valid !== 0 || out_sad !== 0) begin
        display_fail;
        $display("      Output signal should be 0 at %-12d ps  ", $time*1000);
        $finish;
    end
    #(CYCLE * 5) release clk;
end endtask

task wait_random_3_to_6; begin
    delay_cnt = ( $unsigned($random(SEED)) % 4 ) + 2;
    @(negedge clk);
    total_lat = total_lat + 1;
    in_valid  = 1'b0;
    in_valid2 = 1'b0;
    in_data   = 9'bx;
    if(out_valid !== 0 || out_sad !== 0) begin
        display_fail;
        $display("      Output signal should be 0 at %-12d ps  ", $time*1000);
        $finish;
    end
    for(k = 0; k < delay_cnt; k = k + 1) begin
        @(negedge clk);
        total_lat = total_lat + 1;
    end
end
endtask


task input_image; begin 
    for (ii = 0; ii < 128; ii = ii + 1) begin
        for (jj = 0; jj < 128; jj = jj + 1) begin
            @(negedge clk);
            total_lat = total_lat + 1;
            in_valid  = 1'b1;
            in_valid2 = 1'b0;
            pixel = $random(SEED);
            in_data[8:1] = pixel[7:0];
            in_data[0]   = 1'bx;
            L0[ii][jj] = pixel[7:0];
        end
    end

    for (ii = 0; ii < 128; ii = ii + 1) begin
        for (jj = 0; jj < 128; jj = jj + 1) begin
            @(negedge clk);
            total_lat = total_lat + 1;
            pixel = $random(SEED);
            in_data[8:1] = pixel[7:0];
            in_data[0]   = 1'bx;
            L1[ii][jj] = pixel[7:0];
        end
    end
end
endtask

task input_mv; begin

    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    mvx_l0_p1_i = tmp % 117;  

    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    mvy_l0_p1_i = tmp % 117;

    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    mvx_l1_p1_i = tmp % 117;

 
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    mvy_l1_p1_i = tmp % 117;

    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    dx  = tmp % 11;      
    dx  = dx - 5;        
    mvx_l0_p2_i = mvx_l0_p1_i + dx;
    if (mvx_l0_p2_i < 0)   mvx_l0_p2_i = 0;
    else if (mvx_l0_p2_i > 116) mvx_l0_p2_i = 116;

    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    dy  = tmp % 11;     
    dy  = dy - 5;        
    mvy_l0_p2_i = mvy_l0_p1_i + dy;
    if (mvy_l0_p2_i < 0)   mvy_l0_p2_i = 0;
    else if (mvy_l0_p2_i > 116) mvy_l0_p2_i = 116;

    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    dx  = tmp % 11;
    dx  = dx - 5;
    mvx_l1_p2_i = mvx_l1_p1_i + dx;
    if (mvx_l1_p2_i < 0)   mvx_l1_p2_i = 0;
    else if (mvx_l1_p2_i > 116) mvx_l1_p2_i = 116;

    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    dy  = tmp % 11;
    dy  = dy - 5;
    mvy_l1_p2_i = mvy_l1_p1_i + dy;
    if (mvy_l1_p2_i < 0)   mvy_l1_p2_i = 0;
    else if (mvy_l1_p2_i > 116) mvy_l1_p2_i = 116;

    @(negedge clk);
    total_lat = total_lat + 1;
    in_valid  = 1'b0;
    in_valid2 = 1'b1;
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    frac = tmp[0];                     
    in_data[8:1] = mvx_l0_p1_i[7:0];
    in_data[0]   = frac;
    fracx_l0_p1 = frac;

    @(negedge clk);
    total_lat = total_lat + 1;
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    frac = tmp[0];                      
    in_data[8:1] = mvy_l0_p1_i[7:0];
    in_data[0]   = frac;
    fracy_l0_p1 = frac;

    @(negedge clk);
    total_lat = total_lat + 1;
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    frac = tmp[0];                       
    in_data[8:1] = mvx_l1_p1_i[7:0];
    in_data[0]   = frac;
    fracx_l1_p1 = frac;

    @(negedge clk);
    total_lat = total_lat + 1;
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    frac = tmp[0];                    
    in_data[8:1] = mvy_l1_p1_i[7:0];
    in_data[0]   = frac;
    fracy_l1_p1 = frac;

    @(negedge clk);
    total_lat = total_lat + 1;
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    frac = tmp[0];                  
    in_data[8:1] = mvx_l0_p2_i[7:0];
    in_data[0]   = frac;
    fracx_l0_p2 = frac;

    @(negedge clk);
    total_lat = total_lat + 1;
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    frac = tmp[0];                      
    in_data[8:1] = mvy_l0_p2_i[7:0];
    in_data[0]   = frac;
    fracy_l0_p2 = frac;

    @(negedge clk);
    total_lat = total_lat + 1;
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    frac = tmp[0];                      
    in_data[8:1] = mvx_l1_p2_i[7:0];
    in_data[0]   = frac;
    fracx_l1_p2 = frac;

    @(negedge clk);
    total_lat = total_lat + 1;
    tmp = $random(SEED); if (tmp < 0) tmp = -tmp;
    frac = tmp[0];                       
    in_data[8:1] = mvy_l1_p2_i[7:0];
    in_data[0]   = frac;
    fracy_l1_p2 = frac;

    @(negedge clk);
    total_lat = total_lat + 1;
    in_valid2 = 1'b0;
    in_data   = 9'bx;   
end
endtask

task wait_output; begin
    execution_lat = -1;
    while (out_valid !== 1) begin
        if (out_sad !== 0) begin
            display_fail;
            $display("      Output signal should be 0 at %-12d ps  ", $time*1000);
            $finish;
        end
        if (execution_lat == MAX_EXECUTION_CYCLE) begin
            display_fail;
            $display("      The execution latency at %-12d ps is over %5d cycles  ", $time*1000, MAX_EXECUTION_CYCLE);
            $finish; 
        end
        execution_lat = execution_lat + 1;
        @(negedge clk);
        total_lat = total_lat + 1;
    end
end endtask;

function integer clip_coord;
    input integer c;
begin
    if (c < 0)      clip_coord = 0;
    else if (c > 127) clip_coord = 127;
    else            clip_coord = c;
end
endfunction

function [7:0] clip8;
    input integer v;
begin
    if (v < 0)       clip8 = 8'd0;
    else if (v > 255) clip8 = 8'd255;
    else             clip8 = v[7:0];
end
endfunction

function [7:0] get_L0_pix;
    input integer y, x;
    integer cy, cx;
begin
    cy = clip_coord(y);
    cx = clip_coord(x);
    get_L0_pix = L0[cy][cx][7:0];  
end
endfunction

function [7:0] get_L1_pix;
    input integer y, x;
    integer cy, cx;
begin
    cy = clip_coord(y);
    cx = clip_coord(x);
    get_L1_pix = L1[cy][cx][7:0];
end
endfunction

function integer fir6_1d;
    input integer p_m2, p_m1, p0, p1, p2, p3; 
    integer val;
begin
    val =   ( 1 * p_m2)
          + (-5 * p_m1)
          + (20 * p0)
          + (20 * p1)
          + (-5 * p2)
          + ( 1 * p3);
    fir6_1d = val;
end
endfunction

function [7:0] get_L0_bi_pixel;
    input integer base_y, base_x;   
    input        frac_x;         
    input        frac_y;           

    integer val, tmp;
    integer i_2, i_1, i0, i1, i2, i3;
    integer v_2, v_1, v0, v1, v2, v3;

    integer h_m2, h_m1, h0, h1, h2, h3; 
begin
    if (!frac_x && !frac_y) begin
        get_L0_bi_pixel = get_L0_pix(base_y, base_x);
    end
    else if (frac_x && !frac_y) begin
        i_2 = get_L0_pix(base_y, base_x-2);
        i_1 = get_L0_pix(base_y, base_x-1);
        i0  = get_L0_pix(base_y, base_x  );
        i1  = get_L0_pix(base_y, base_x+1);
        i2  = get_L0_pix(base_y, base_x+2);
        i3  = get_L0_pix(base_y, base_x+3);

        val = fir6_1d(i_2, i_1, i0, i1, i2, i3);
        tmp = (val + 16) >>> 5;
        get_L0_bi_pixel = clip8(tmp);
    end
    else if (!frac_x && frac_y) begin
        v_2 = get_L0_pix(base_y-2, base_x);
        v_1 = get_L0_pix(base_y-1, base_x);
        v0  = get_L0_pix(base_y,   base_x);
        v1  = get_L0_pix(base_y+1, base_x);
        v2  = get_L0_pix(base_y+2, base_x);
        v3  = get_L0_pix(base_y+3, base_x);

        val = fir6_1d(v_2, v_1, v0, v1, v2, v3);
        tmp = (val + 16) >>> 5;
        get_L0_bi_pixel = clip8(tmp);

        // $display("idx: %d %d", base_y, base_x);
        // $display("%d %d %d %d %d %d", get_L0_pix(base_y-2, base_x), get_L0_pix(base_y-1, base_x), get_L0_pix(base_y,   base_x), get_L0_pix(base_y+1, base_x), get_L0_pix(base_y+2, base_x), get_L0_pix(base_y+3, base_x));
    end
    else begin
        i_2 = get_L0_pix(base_y-2, base_x-2);
        i_1 = get_L0_pix(base_y-2, base_x-1);
        i0  = get_L0_pix(base_y-2, base_x  );
        i1  = get_L0_pix(base_y-2, base_x+1);
        i2  = get_L0_pix(base_y-2, base_x+2);
        i3  = get_L0_pix(base_y-2, base_x+3);
        h_m2 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L0_pix(base_y-1, base_x-2);
        i_1 = get_L0_pix(base_y-1, base_x-1);
        i0  = get_L0_pix(base_y-1, base_x  );
        i1  = get_L0_pix(base_y-1, base_x+1);
        i2  = get_L0_pix(base_y-1, base_x+2);
        i3  = get_L0_pix(base_y-1, base_x+3);
        h_m1 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L0_pix(base_y, base_x-2);
        i_1 = get_L0_pix(base_y, base_x-1);
        i0  = get_L0_pix(base_y, base_x  );
        i1  = get_L0_pix(base_y, base_x+1);
        i2  = get_L0_pix(base_y, base_x+2);
        i3  = get_L0_pix(base_y, base_x+3);
        h0 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L0_pix(base_y+1, base_x-2);
        i_1 = get_L0_pix(base_y+1, base_x-1);
        i0  = get_L0_pix(base_y+1, base_x  );
        i1  = get_L0_pix(base_y+1, base_x+1);
        i2  = get_L0_pix(base_y+1, base_x+2);
        i3  = get_L0_pix(base_y+1, base_x+3);
        h1 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L0_pix(base_y+2, base_x-2);
        i_1 = get_L0_pix(base_y+2, base_x-1);
        i0  = get_L0_pix(base_y+2, base_x  );
        i1  = get_L0_pix(base_y+2, base_x+1);
        i2  = get_L0_pix(base_y+2, base_x+2);
        i3  = get_L0_pix(base_y+2, base_x+3);
        h2 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L0_pix(base_y+3, base_x-2);
        i_1 = get_L0_pix(base_y+3, base_x-1);
        i0  = get_L0_pix(base_y+3, base_x  );
        i1  = get_L0_pix(base_y+3, base_x+1);
        i2  = get_L0_pix(base_y+3, base_x+2);
        i3  = get_L0_pix(base_y+3, base_x+3);
        h3 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        val = fir6_1d(h_m2, h_m1, h0, h1, h2, h3);

        tmp = (val + 512) >>> 10;
        get_L0_bi_pixel = clip8(tmp);
    end
end
endfunction

function [7:0] get_L1_bi_pixel;
    input integer base_y, base_x;   
    input        frac_x;         
    input        frac_y;           

    integer val, tmp;
    integer i_2, i_1, i0, i1, i2, i3;
    integer v_2, v_1, v0, v1, v2, v3;

    integer h_m2, h_m1, h0, h1, h2, h3; 
begin
    if (!frac_x && !frac_y) begin
        get_L1_bi_pixel = get_L1_pix(base_y, base_x);
    end
    else if (frac_x && !frac_y) begin
        i_2 = get_L1_pix(base_y, base_x-2);
        i_1 = get_L1_pix(base_y, base_x-1);
        i0  = get_L1_pix(base_y, base_x  );
        i1  = get_L1_pix(base_y, base_x+1);
        i2  = get_L1_pix(base_y, base_x+2);
        i3  = get_L1_pix(base_y, base_x+3);

        val = fir6_1d(i_2, i_1, i0, i1, i2, i3);
        tmp = (val + 16) >>> 5;
        get_L1_bi_pixel = clip8(tmp);
    end
    else if (!frac_x && frac_y) begin
        v_2 = get_L1_pix(base_y-2, base_x);
        v_1 = get_L1_pix(base_y-1, base_x);
        v0  = get_L1_pix(base_y,   base_x);
        v1  = get_L1_pix(base_y+1, base_x);
        v2  = get_L1_pix(base_y+2, base_x);
        v3  = get_L1_pix(base_y+3, base_x);

        val = fir6_1d(v_2, v_1, v0, v1, v2, v3);
        tmp = (val + 16) >>> 5;
        get_L1_bi_pixel = clip8(tmp);
        // $display("idx: %d %d", base_y, base_x);
        // $display("%d %d %d %d %d %d", get_L1_pix(base_y-2, base_x), get_L1_pix(base_y-1, base_x), get_L1_pix(base_y,   base_x), get_L1_pix(base_y+1, base_x), get_L1_pix(base_y+2, base_x), get_L1_pix(base_y+3, base_x));
    end
    else begin
        // $display("idx: %d %d", base_y, base_x);
        i_2 = get_L1_pix(base_y-2, base_x-2);
        i_1 = get_L1_pix(base_y-2, base_x-1);
        i0  = get_L1_pix(base_y-2, base_x  );
        i1  = get_L1_pix(base_y-2, base_x+1);
        i2  = get_L1_pix(base_y-2, base_x+2);
        i3  = get_L1_pix(base_y-2, base_x+3);
        h_m2 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        // $display("%d %d %d %d %d %d", i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L1_pix(base_y-1, base_x-2);
        i_1 = get_L1_pix(base_y-1, base_x-1);
        i0  = get_L1_pix(base_y-1, base_x  );
        i1  = get_L1_pix(base_y-1, base_x+1);
        i2  = get_L1_pix(base_y-1, base_x+2);
        i3  = get_L1_pix(base_y-1, base_x+3);
        h_m1 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        // $display("%d %d %d %d %d %d", i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L1_pix(base_y, base_x-2);
        i_1 = get_L1_pix(base_y, base_x-1);
        i0  = get_L1_pix(base_y, base_x  );
        i1  = get_L1_pix(base_y, base_x+1);
        i2  = get_L1_pix(base_y, base_x+2);
        i3  = get_L1_pix(base_y, base_x+3);
        h0 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        // $display("%d %d %d %d %d %d", i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L1_pix(base_y+1, base_x-2);
        i_1 = get_L1_pix(base_y+1, base_x-1);
        i0  = get_L1_pix(base_y+1, base_x  );
        i1  = get_L1_pix(base_y+1, base_x+1);
        i2  = get_L1_pix(base_y+1, base_x+2);
        i3  = get_L1_pix(base_y+1, base_x+3);
        h1 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        // $display("%d %d %d %d %d %d", i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L1_pix(base_y+2, base_x-2);
        i_1 = get_L1_pix(base_y+2, base_x-1);
        i0  = get_L1_pix(base_y+2, base_x  );
        i1  = get_L1_pix(base_y+2, base_x+1);
        i2  = get_L1_pix(base_y+2, base_x+2);
        i3  = get_L1_pix(base_y+2, base_x+3);
        h2 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        // $display("%d %d %d %d %d %d", i_2, i_1, i0, i1, i2, i3);

        i_2 = get_L1_pix(base_y+3, base_x-2);
        i_1 = get_L1_pix(base_y+3, base_x-1);
        i0  = get_L1_pix(base_y+3, base_x  );
        i1  = get_L1_pix(base_y+3, base_x+1);
        i2  = get_L1_pix(base_y+3, base_x+2);
        i3  = get_L1_pix(base_y+3, base_x+3);
        h3 = fir6_1d(i_2, i_1, i0, i1, i2, i3);

        // $display("%d %d %d %d %d %d", i_2, i_1, i0, i1, i2, i3);

        val = fir6_1d(h_m2, h_m1, h0, h1, h2, h3);

        tmp = (val + 512) >>> 10;
        get_L1_bi_pixel = clip8(tmp);
        // $display("%d %d %d %d %d %d", h_m2, h_m1, h0, h1, h2, h3);
    end
end
endfunction

task satd4x4;
    input  integer d[0:3][0:3];
    output integer satd_val;
    integer h[0:3][0:3];
    integer v[0:3][0:3];
    integer i, j;
    integer s0, s1, s2, s3;
begin
    for (i = 0; i < 4; i = i + 1) begin
        s0 = d[i][0] + d[i][1];
        s1 = d[i][0] - d[i][1];
        s2 = d[i][2] + d[i][3];
        s3 = d[i][2] - d[i][3];

        h[i][0] = s0 + s2;
        h[i][1] = s1 + s3;
        h[i][2] = s0 - s2;
        h[i][3] = s1 - s3;
    end

    for (j = 0; j < 4; j = j + 1) begin
        s0 = h[0][j] + h[1][j];
        s1 = h[0][j] - h[1][j];
        s2 = h[2][j] + h[3][j];
        s3 = h[2][j] - h[3][j];

        v[0][j] = s0 + s2;
        v[1][j] = s1 + s3;
        v[2][j] = s0 - s2;
        v[3][j] = s1 - s3;
    end

    satd_val = 0;
    for (i = 0; i < 4; i = i + 1)
        for (j = 0; j < 4; j = j + 1)
            if (v[i][j] < 0)
                satd_val = satd_val - v[i][j];
            else
                satd_val = satd_val + v[i][j];
end
endtask

task satd8x8;
    input  integer y0_L0, x0_L0;   
    input  integer y0_L1, x0_L1;   
    input  reg     frac_x_L0, frac_y_L0; 
    input  reg     frac_x_L1, frac_y_L1;
    output integer satd_total;
    integer i, j;
    integer diff[0:7][0:7];
    integer blk4[0:3][0:3];
    integer satd_sub;
begin
    // $display("L0");
    for(i = 0; i < 8; i = i + 1) begin
        // $display("%d %d %d %d %d %d %d %d", get_L0_bi_pixel(y0_L0 + i, x0_L0 + 0, frac_x_L0, frac_y_L0) ,get_L0_bi_pixel(y0_L0 + i, x0_L0 + 1, frac_x_L0, frac_y_L0) ,get_L0_bi_pixel(y0_L0 + i, x0_L0 + 2, frac_x_L0, frac_y_L0), get_L0_bi_pixel(y0_L0 + i, x0_L0 + 3, frac_x_L0, frac_y_L0), get_L0_bi_pixel(y0_L0 + i, x0_L0 + 4, frac_x_L0, frac_y_L0), get_L0_bi_pixel(y0_L0 + i, x0_L0 + 5, frac_x_L0, frac_y_L0),get_L0_bi_pixel(y0_L0 + i, x0_L0 + 6, frac_x_L0, frac_y_L0),get_L0_bi_pixel(y0_L0 + i, x0_L0 + 7, frac_x_L0, frac_y_L0) );
    end

    // $display("L1");
    for(i = 0; i < 8; i = i + 1) begin
        // $display("%d %d %d %d %d %d %d %d", get_L1_bi_pixel(y0_L1 + i, x0_L1 + 0, frac_x_L1, frac_y_L1) ,get_L1_bi_pixel(y0_L1 + i, x0_L1 + 1, frac_x_L1, frac_y_L1) ,get_L1_bi_pixel(y0_L1 + i, x0_L1 + 2, frac_x_L1, frac_y_L1), get_L1_bi_pixel(y0_L1 + i, x0_L1 + 3, frac_x_L1, frac_y_L1), get_L1_bi_pixel(y0_L1 + i, x0_L1 + 4, frac_x_L1, frac_y_L1), get_L1_bi_pixel(y0_L1 + i, x0_L1 + 5, frac_x_L1, frac_y_L1),get_L1_bi_pixel(y0_L1 + i, x0_L1 + 6, frac_x_L1, frac_y_L1),get_L1_bi_pixel(y0_L1 + i, x0_L1 + 7, frac_x_L1, frac_y_L1) );
    end

    for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            diff[i][j] =
                get_L0_bi_pixel(y0_L0 + i, x0_L0 + j, frac_x_L0, frac_y_L0)
              - get_L1_bi_pixel(y0_L1 + i, x0_L1 + j, frac_x_L1, frac_y_L1);
        end
    end

    satd_total = 0;

    for (i = 0; i < 4; i = i + 1)
        for (j = 0; j < 4; j = j + 1)
            blk4[i][j] = diff[i][j];
    satd4x4(blk4, satd_sub);
    satd_total = satd_total + satd_sub;

    // $display("LU: %d", satd_sub);

    for (i = 0; i < 4; i = i + 1)
        for (j = 0; j < 4; j = j + 1)
            blk4[i][j] = diff[i][j+4];
    satd4x4(blk4, satd_sub);
    satd_total = satd_total + satd_sub;

    // $display("RU: %d", satd_sub);

    for (i = 0; i < 4; i = i + 1)
        for (j = 0; j < 4; j = j + 1)
            blk4[i][j] = diff[i+4][j];
    satd4x4(blk4, satd_sub);
    satd_total = satd_total + satd_sub;

    // $display("LD: %d", satd_sub);

    for (i = 0; i < 4; i = i + 1)
        for (j = 0; j < 4; j = j + 1)
            blk4[i][j] = diff[i+4][j+4];
    satd4x4(blk4, satd_sub);
    satd_total = satd_total + satd_sub;

    // $display("RD: %d", satd_sub);
end
endtask

task calc_golden_for_one_pair;
    integer sp;
    integer dx_sp[0:8];
    integer dy_sp[0:8];

    integer y0_l0_p1, x0_l0_p1;
    integer y0_l1_p1, x0_l1_p1;
    integer y0_l0_p2, x0_l0_p2;
    integer y0_l1_p2, x0_l1_p2;
begin
    dx_sp[0] = 0; dy_sp[0] = 0;
    dx_sp[1] = 0; dy_sp[1] = 1;
    dx_sp[2] = 0; dy_sp[2] = 2;
    dx_sp[3] = 1; dy_sp[3] = 0;
    dx_sp[4] = 1; dy_sp[4] = 1;
    dx_sp[5] = 1; dy_sp[5] = 2;
    dx_sp[6] = 2; dy_sp[6] = 0;
    dx_sp[7] = 2; dy_sp[7] = 1;
    dx_sp[8] = 2; dy_sp[8] = 2;

    y0_l0_p1 = mvy_l0_p1_i;
    x0_l0_p1 = mvx_l0_p1_i;
    y0_l1_p1 = mvy_l1_p1_i + 2; 
    x0_l1_p1 = mvx_l1_p1_i + 2;

    y0_l0_p2 = mvy_l0_p2_i;
    x0_l0_p2 = mvx_l0_p2_i;
    y0_l1_p2 = mvy_l1_p2_i + 2;
    x0_l1_p2 = mvx_l1_p2_i + 2;

    for (sp = 0; sp < 9; sp = sp + 1) begin
        // $display("SATD_P0_idx_%d: ", sp);
        
        satd8x8(
            y0_l0_p1 + dy_sp[sp],              
            x0_l0_p1 + dx_sp[sp],              
            y0_l1_p1 - dy_sp[sp],              
            x0_l1_p1 - dx_sp[sp],              
            fracx_l0_p1, fracy_l0_p1,          
            fracx_l1_p1, fracy_l1_p1,          
            satd_p1[sp]
        );
    end

    min_cost_p1 = satd_p1[0];
    min_idx_p1  = 0;
    for (sp = 1; sp < 9; sp = sp + 1) begin
        if (satd_p1[sp] < min_cost_p1) begin
            min_cost_p1 = satd_p1[sp];
            min_idx_p1  = sp;
        end
    end

    for (sp = 0; sp < 9; sp = sp + 1) begin
        // $display("SATD_P0_idx_%d: ", sp);

        satd8x8(
            y0_l0_p2 + dy_sp[sp],
            x0_l0_p2 + dx_sp[sp],
            y0_l1_p2 - dy_sp[sp],
            x0_l1_p2 - dx_sp[sp],
            fracx_l0_p2, fracy_l0_p2,
            fracx_l1_p2, fracy_l1_p2,
            satd_p2[sp]
        );
    end

    min_cost_p2 = satd_p2[0];
    min_idx_p2  = 0;
    for (sp = 0; sp < 9; sp = sp + 1) begin
        if (satd_p2[sp] < min_cost_p2) begin
            min_cost_p2 = satd_p2[sp];
            min_idx_p2  = sp;

            // $display("%d, %d", min_idx_p2, min_cost_p2);
        end
    end
    // $display("%d, %d", min_idx_p2, min_cost_p2);
    golden_out[55:52] = min_idx_p2[3:0];
    golden_out[51:28] = min_cost_p2[23:0];
    golden_out[27:24] = min_idx_p1[3:0];
    golden_out[23: 0] = min_cost_p1[23:0];
end
endtask


task check_task; begin

    for (ii = 0; ii < 56; ii = ii + 1) begin
        if (out_valid !== 1'b1) begin
            display_fail;
            $display("ERROR at %t: out_valid dropped before 56 cycles (%0d).", $time, ii);
            $finish;
        end

        if (out_sad !== golden_out[ii]) begin
            display_fail;
            $display("ERROR at %t: out_sad mismatch at bit %0d. DUT = %0d, GOLD = %0d",
                     $time, ii, out_sad, golden_out[ii]);
            $finish;
        end

        @(negedge clk);
        total_lat = total_lat + 1;
    end
    $display("%0sPASS PATTERN NO.%4d/Set NO.%4d, %0sCycles: %3d%0s",txt_blue_prefix, i, j, txt_green_prefix, execution_lat, reset_color);
end
endtask

task display_pass; begin
//$display("[38;2;246;242;233m█[0m[38;2;246;242;233m█[0m[38;2;244;242;231m█[0m[38;2;243;241;230m█[0m[38;2;243;240;230m█[0m[38;2;242;240;229m█[0m[38;2;244;240;229m█[0m[38;2;244;240;229m█[0m[38;2;244;241;229m█[0m[38;2;244;240;232m█[0m[38;2;245;241;234m█[0m[38;2;244;241;233m█[0m[38;2;244;241;233m█[0m[38;2;243;239;232m█[0m[38;2;243;239;231m█[0m[38;2;242;239;229m█[0m[38;2;243;241;229m█[0m[38;2;241;240;229m█[0m[38;2;241;239;230m█[0m[38;2;241;239;232m█[0m[38;2;242;238;230m█[0m[38;2;242;238;231m█[0m[38;2;241;238;230m█[0m[38;2;239;238;229m█[0m[38;2;239;238;229m█[0m[38;2;239;237;228m█[0m[38;2;236;235;227m█[0m[38;2;232;233;223m█[0m[38;2;223;225;216m█[0m[38;2;210;212;205m█[0m[38;2;197;201;197m█[0m[38;2;186;191;192m█[0m[38;2;185;189;189m█[0m[38;2;181;182;179m█[0m[38;2;168;166;156m█[0m[38;2;152;148;132m█[0m[38;2;138;130;110m█[0m[38;2;116;105;81m█[0m[38;2;93;81;55m█[0m[38;2;82;67;41m█[0m[38;2;82;63;37m█[0m[38;2;86;65;37m█[0m[38;2;93;69;39m█[0m[38;2;99;75;40m█[0m[38;2;113;87;50m█[0m[38;2;115;90;52m█[0m[38;2;101;77;42m█[0m[38;2;100;79;46m█[0m[38;2;92;75;45m█[0m[38;2;82;68;41m█[0m[38;2;69;57;36m█[0m[38;2;73;65;50m█[0m[38;2;84;79;69m█[0m[38;2;118;118;112m█[0m[38;2;141;145;145m█[0m[38;2;150;156;161m█[0m[38;2;152;162;166m█[0m[38;2;159;169;173m█[0m[38;2;163;172;177m█[0m[38;2;163;174;179m█[0m[38;2;161;173;179m█[0m[38;2;163;173;180m█[0m[38;2;165;175;181m█[0m[38;2;166;176;179m█[0m[38;2;162;172;175m█[0m[38;2;162;172;176m█[0m[38;2;168;177;181m█[0m[38;2;170;179;184m█[0m[38;2;167;176;181m█[0m[38;2;168;177;182m█[0m[38;2;170;179;185m█[0m[38;2;170;179;185m█[0m[38;2;171;181;185m█[0m[38;2;173;183;186m█[0m[38;2;172;181;184m█[0m[38;2;171;182;184m█[0m[38;2;171;183;185m█[0m[38;2;173;181;186m█[0m[38;2;174;182;186m█[0m[38;2;174;181;185m█[0m");
//$display("[38;2;251;248;243m█[0m[38;2;250;247;241m█[0m[38;2;250;248;240m█[0m[38;2;251;249;240m█[0m[38;2;251;249;240m█[0m[38;2;250;248;239m█[0m[38;2;247;247;239m█[0m[38;2;243;243;236m█[0m[38;2;241;239;234m█[0m[38;2;238;236;231m█[0m[38;2;236;233;227m█[0m[38;2;234;233;226m█[0m[38;2;238;237;230m█[0m[38;2;237;236;228m█[0m[38;2;235;234;226m█[0m[38;2;237;235;227m█[0m[38;2;239;237;230m█[0m[38;2;241;240;233m█[0m[38;2;239;238;233m█[0m[38;2;231;230;227m█[0m[38;2;221;221;218m█[0m[38;2;209;210;208m█[0m[38;2;199;203;200m█[0m[38;2;199;205;201m█[0m[38;2;200;206;204m█[0m[38;2;200;205;204m█[0m[38;2;193;198;198m█[0m[38;2;182;188;189m█[0m[38;2;170;175;179m█[0m[38;2;153;161;164m█[0m[38;2;144;152;156m█[0m[38;2;138;145;146m█[0m[38;2;131;132;125m█[0m[38;2;121;112;97m█[0m[38;2;109;94;70m█[0m[38;2;95;75;48m█[0m[38;2;84;64;36m█[0m[38;2;79;59;30m█[0m[38;2;77;57;30m█[0m[38;2;73;54;26m█[0m[38;2;75;55;27m█[0m[38;2;79;59;32m█[0m[38;2;79;59;34m█[0m[38;2;78;58;32m█[0m[38;2;86;66;40m█[0m[38;2;92;72;45m█[0m[38;2;95;75;48m█[0m[38;2;92;75;47m█[0m[38;2;95;79;52m█[0m[38;2;84;70;46m█[0m[38;2;59;44;26m█[0m[38;2;55;42;28m█[0m[38;2;50;39;29m█[0m[38;2;50;44;34m█[0m[38;2;69;69;63m█[0m[38;2;91;96;94m█[0m[38;2;115;122;128m█[0m[38;2;126;136;144m█[0m[38;2;127;139;148m█[0m[38;2;126;141;154m█[0m[38;2;127;141;156m█[0m[38;2;130;141;156m█[0m[38;2;132;143;155m█[0m[38;2;132;143;153m█[0m[38;2;131;142;152m█[0m[38;2;130;141;152m█[0m[38;2;130;142;152m█[0m[38;2;131;144;151m█[0m[38;2;130;143;149m█[0m[38;2;130;143;149m█[0m[38;2;131;143;153m█[0m[38;2;131;143;155m█[0m[38;2;131;143;154m█[0m[38;2;129;142;152m█[0m[38;2;129;139;149m█[0m[38;2;125;140;148m█[0m[38;2;128;142;149m█[0m[38;2;139;148;155m█[0m[38;2;153;162;166m█[0m[38;2;162;170;174m█[0m");
//$display("[38;2;177;183;186m█[0m[38;2;173;180;184m█[0m[38;2;183;190;193m█[0m[38;2;193;201;202m█[0m[38;2;193;201;201m█[0m[38;2;185;194;194m█[0m[38;2;176;183;187m█[0m[38;2;170;178;184m█[0m[38;2;165;173;179m█[0m[38;2;158;168;172m█[0m[38;2;154;164;170m█[0m[38;2;154;163;170m█[0m[38;2;157;167;173m█[0m[38;2;158;170;174m█[0m[38;2;157;167;171m█[0m[38;2;161;171;175m█[0m[38;2;167;177;182m█[0m[38;2;173;182;187m█[0m[38;2;170;178;183m█[0m[38;2;159;168;174m█[0m[38;2;150;159;168m█[0m[38;2;144;156;164m█[0m[38;2;142;154;162m█[0m[38;2;142;154;161m█[0m[38;2;143;155;164m█[0m[38;2;144;156;165m█[0m[38;2;144;154;165m█[0m[38;2;143;153;163m█[0m[38;2;142;153;161m█[0m[38;2;141;148;154m█[0m[38;2;128;131;128m█[0m[38;2;113;108;91m█[0m[38;2;100;88;62m█[0m[38;2;84;66;38m█[0m[38;2;86;65;38m█[0m[38;2;87;65;39m█[0m[38;2;86;65;38m█[0m[38;2;95;75;46m█[0m[38;2;100;81;53m█[0m[38;2;93;72;46m█[0m[38;2;95;75;47m█[0m[38;2;94;77;52m█[0m[38;2;73;60;42m█[0m[38;2;56;46;31m█[0m[38;2;50;39;26m█[0m[38;2;55;45;29m█[0m[38;2;62;53;34m█[0m[38;2;67;57;37m█[0m[38;2;72;60;40m█[0m[38;2;75;59;44m█[0m[38;2;76;60;42m█[0m[38;2;73;56;38m█[0m[38;2;72;56;38m█[0m[38;2;63;50;31m█[0m[38;2;65;57;37m█[0m[38;2;61;57;39m█[0m[38;2;56;56;48m█[0m[38;2;76;82;80m█[0m[38;2;105;116;123m█[0m[38;2;119;133;145m█[0m[38;2;127;141;154m█[0m[38;2;132;145;158m█[0m[38;2;132;145;155m█[0m[38;2;132;144;154m█[0m[38;2;132;143;155m█[0m[38;2;131;143;154m█[0m[38;2;129;141;153m█[0m[38;2;128;141;152m█[0m[38;2;127;141;152m█[0m[38;2;124;138;150m█[0m[38;2;122;135;147m█[0m[38;2;119;133;143m█[0m[38;2;119;133;143m█[0m[38;2;117;131;142m█[0m[38;2;116;128;142m█[0m[38;2;116;129;143m█[0m[38;2;116;129;142m█[0m[38;2;112;123;137m█[0m[38;2;111;122;135m█[0m[38;2;114;124;135m█[0m");
//$display("[38;2;134;146;160m█[0m[38;2;134;147;162m█[0m[38;2;133;145;162m█[0m[38;2;131;145;160m█[0m[38;2;130;146;159m█[0m[38;2;131;146;159m█[0m[38;2;130;145;159m█[0m[38;2;130;143;158m█[0m[38;2;130;143;158m█[0m[38;2;131;144;158m█[0m[38;2;131;143;158m█[0m[38;2;127;140;156m█[0m[38;2;126;140;154m█[0m[38;2;127;143;156m█[0m[38;2;127;143;156m█[0m[38;2;128;145;156m█[0m[38;2;129;146;156m█[0m[38;2;129;145;157m█[0m[38;2;133;147;160m█[0m[38;2;136;149;162m█[0m[38;2;140;152;164m█[0m[38;2;144;155;167m█[0m[38;2;144;155;165m█[0m[38;2;146;157;167m█[0m[38;2;149;161;169m█[0m[38;2;145;157;164m█[0m[38;2;140;153;159m█[0m[38;2;137;149;154m█[0m[38;2;134;142;142m█[0m[38;2;123;121;113m█[0m[38;2;116;105;89m█[0m[38;2;112;95;68m█[0m[38;2;105;86;51m█[0m[38;2;113;91;57m█[0m[38;2;116;93;62m█[0m[38;2;112;89;59m█[0m[38;2;107;87;59m█[0m[38;2;106;84;60m█[0m[38;2;98;77;52m█[0m[38;2;102;79;55m█[0m[38;2;94;73;49m█[0m[38;2;74;57;34m█[0m[38;2;64;49;29m█[0m[38;2;58;46;29m█[0m[38;2;48;36;23m█[0m[38;2;47;37;24m█[0m[38;2;55;46;29m█[0m[38;2;65;55;37m█[0m[38;2;67;55;36m█[0m[38;2;61;45;28m█[0m[38;2;70;52;34m█[0m[38;2;82;61;40m█[0m[38;2;86;64;40m█[0m[38;2;95;72;47m█[0m[38;2;93;71;46m█[0m[38;2;99;79;55m█[0m[38;2;75;61;41m█[0m[38;2;55;46;34m█[0m[38;2;58;55;53m█[0m[38;2;94;97;102m█[0m[38;2;118;127;136m█[0m[38;2;127;137;148m█[0m[38;2;126;141;152m█[0m[38;2;127;142;154m█[0m[38;2;128;141;153m█[0m[38;2;127;141;154m█[0m[38;2;126;139;152m█[0m[38;2;125;138;149m█[0m[38;2;121;135;146m█[0m[38;2;118;132;146m█[0m[38;2;116;130;144m█[0m[38;2;116;130;143m█[0m[38;2;115;129;142m█[0m[38;2;114;128;141m█[0m[38;2;112;125;139m█[0m[38;2;110;123;138m█[0m[38;2;108;123;138m█[0m[38;2;106;121;137m█[0m[38;2;106;120;135m█[0m[38;2;105;117;131m█[0m");
//$display("[38;2;131;148;159m█[0m[38;2;131;148;160m█[0m[38;2;134;148;161m█[0m[38;2;135;148;162m█[0m[38;2;135;148;160m█[0m[38;2;133;148;160m█[0m[38;2;133;149;161m█[0m[38;2;134;150;162m█[0m[38;2;132;149;160m█[0m[38;2;131;148;159m█[0m[38;2;130;147;159m█[0m[38;2;131;148;161m█[0m[38;2;130;147;162m█[0m[38;2;131;147;163m█[0m[38;2;131;147;163m█[0m[38;2;132;148;162m█[0m[38;2;131;147;162m█[0m[38;2;130;146;161m█[0m[38;2;129;146;161m█[0m[38;2;130;145;161m█[0m[38;2;133;146;160m█[0m[38;2;133;145;159m█[0m[38;2;133;145;159m█[0m[38;2;134;146;160m█[0m[38;2;134;147;160m█[0m[38;2;132;145;158m█[0m[38;2;129;141;151m█[0m[38;2;126;134;136m█[0m[38;2;119;118;105m█[0m[38;2;124;112;83m█[0m[38;2;132;111;77m█[0m[38;2;131;108;72m█[0m[38;2;131;108;71m█[0m[38;2;140;117;82m█[0m[38;2;126;103;73m█[0m[38;2;117;96;68m█[0m[38;2;116;97;71m█[0m[38;2;119;97;75m█[0m[38;2;120;96;74m█[0m[38;2;128;104;81m█[0m[38;2;129;105;81m█[0m[38;2;122;98;74m█[0m[38;2;116;93;68m█[0m[38;2;120;97;72m█[0m[38;2;90;69;47m█[0m[38;2;73;54;33m█[0m[38;2;85;67;44m█[0m[38;2;96;77;52m█[0m[38;2;100;79;53m█[0m[38;2;113;88;63m█[0m[38;2;126;102;77m█[0m[38;2;122;97;76m█[0m[38;2;115;90;67m█[0m[38;2;117;93;69m█[0m[38;2;119;95;71m█[0m[38;2;109;86;58m█[0m[38;2;101;82;56m█[0m[38;2;95;80;59m█[0m[38;2;74;64;49m█[0m[38;2;53;51;43m█[0m[38;2;80;85;86m█[0m[38;2;118;128;134m█[0m[38;2;125;138;148m█[0m[38;2;127;141;153m█[0m[38;2;127;142;154m█[0m[38;2;127;142;154m█[0m[38;2;126;141;153m█[0m[38;2;125;140;152m█[0m[38;2;122;136;148m█[0m[38;2;119;133;147m█[0m[38;2;116;130;145m█[0m[38;2;115;130;144m█[0m[38;2;114;128;143m█[0m[38;2;115;129;143m█[0m[38;2;113;127;140m█[0m[38;2;111;127;139m█[0m[38;2;111;128;142m█[0m[38;2;110;127;141m█[0m[38;2;108;125;137m█[0m[38;2;107;123;134m█[0m");
//$display("[38;2;146;160;168m█[0m[38;2;146;159;169m█[0m[38;2;147;159;170m█[0m[38;2;147;159;169m█[0m[38;2;139;152;161m█[0m[38;2;137;150;160m█[0m[38;2;139;152;162m█[0m[38;2;138;151;162m█[0m[38;2;138;151;161m█[0m[38;2;142;155;165m█[0m[38;2;142;155;165m█[0m[38;2;141;154;166m█[0m[38;2;141;153;167m█[0m[38;2;143;155;168m█[0m[38;2;143;156;169m█[0m[38;2;144;156;168m█[0m[38;2;143;155;168m█[0m[38;2;141;154;166m█[0m[38;2;141;153;166m█[0m[38;2;141;153;166m█[0m[38;2;141;153;166m█[0m[38;2;141;153;167m█[0m[38;2;141;153;167m█[0m[38;2;138;149;164m█[0m[38;2;137;149;161m█[0m[38;2;137;149;155m█[0m[38;2;137;138;142m█[0m[38;2;130;123;109m█[0m[38;2;144;127;94m█[0m[38;2;157;134;89m█[0m[38;2;167;142;95m█[0m[38;2;164;139;94m█[0m[38;2;153;129;89m█[0m[38;2;142;118;87m█[0m[38;2;123;99;74m█[0m[38;2;116;95;72m█[0m[38;2;121;100;78m█[0m[38;2;137;114;93m█[0m[38;2;150;125;105m█[0m[38;2;159;134;113m█[0m[38;2;160;135;111m█[0m[38;2;162;136;113m█[0m[38;2;164;136;114m█[0m[38;2;157;130;108m█[0m[38;2;117;90;66m█[0m[38;2;114;87;63m█[0m[38;2;125;99;74m█[0m[38;2;121;94;69m█[0m[38;2;129;101;76m█[0m[38;2;152;124;101m█[0m[38;2;166;138;116m█[0m[38;2;167;140;118m█[0m[38;2;161;134;112m█[0m[38;2;163;135;115m█[0m[38;2;153;126;105m█[0m[38;2;125;100;74m█[0m[38;2;116;97;70m█[0m[38;2;113;96;69m█[0m[38;2;107;88;64m█[0m[38;2;76;63;45m█[0m[38;2;49;47;38m█[0m[38;2;77;84;85m█[0m[38;2;112;123;129m█[0m[38;2;124;136;145m█[0m[38;2;127;139;150m█[0m[38;2;127;139;149m█[0m[38;2;125;137;148m█[0m[38;2;125;136;148m█[0m[38;2;124;136;147m█[0m[38;2;124;136;147m█[0m[38;2;122;134;145m█[0m[38;2;119;132;143m█[0m[38;2;119;131;143m█[0m[38;2;120;132;143m█[0m[38;2;117;130;140m█[0m[38;2;117;130;139m█[0m[38;2;116;128;141m█[0m[38;2;113;126;140m█[0m[38;2;112;128;140m█[0m[38;2;114;129;138m█[0m");
//$display("[38;2;135;146;158m█[0m[38;2;134;146;157m█[0m[38;2;133;145;157m█[0m[38;2;133;144;158m█[0m[38;2;131;142;156m█[0m[38;2;130;141;154m█[0m[38;2;129;142;154m█[0m[38;2;126;141;151m█[0m[38;2;126;141;151m█[0m[38;2;129;143;154m█[0m[38;2;125;139;151m█[0m[38;2;119;133;146m█[0m[38;2;122;135;148m█[0m[38;2;121;135;146m█[0m[38;2;122;133;145m█[0m[38;2;123;135;146m█[0m[38;2;130;143;154m█[0m[38;2;128;142;156m█[0m[38;2;128;142;154m█[0m[38;2;129;144;155m█[0m[38;2;128;143;157m█[0m[38;2;130;143;159m█[0m[38;2;130;143;158m█[0m[38;2;130;143;156m█[0m[38;2;130;141;152m█[0m[38;2;129;134;136m█[0m[38;2;140;130;119m█[0m[38;2;151;130;99m█[0m[38;2;185;160;114m█[0m[38;2;192;164;115m█[0m[38;2;179;154;108m█[0m[38;2;151;127;85m█[0m[38;2;128;105;71m█[0m[38;2;115;93;68m█[0m[38;2;125;102;79m█[0m[38;2;138;116;93m█[0m[38;2;127;109;86m█[0m[38;2;123;103;81m█[0m[38;2;125;104;87m█[0m[38;2;132;111;94m█[0m[38;2;140;119;101m█[0m[38;2;150;124;104m█[0m[38;2;155;128;107m█[0m[38;2;164;136;116m█[0m[38;2;140;113;91m█[0m[38;2;128;102;76m█[0m[38;2;119;93;67m█[0m[38;2;145;115;93m█[0m[38;2;159;129;107m█[0m[38;2;145;119;98m█[0m[38;2;133;108;90m█[0m[38;2;139;115;95m█[0m[38;2;144;118;96m█[0m[38;2;147;121;97m█[0m[38;2;163;136;112m█[0m[38;2;145;119;94m█[0m[38;2;109;89;62m█[0m[38;2;111;90;62m█[0m[38;2;112;90;65m█[0m[38;2;102;85;61m█[0m[38;2;70;61;43m█[0m[38;2;44;45;40m█[0m[38;2;80;86;94m█[0m[38;2;107;118;128m█[0m[38;2;116;128;137m█[0m[38;2;120;132;142m█[0m[38;2;122;132;144m█[0m[38;2;125;133;145m█[0m[38;2;124;132;144m█[0m[38;2;120;130;141m█[0m[38;2;117;130;140m█[0m[38;2;116;129;139m█[0m[38;2;114;129;139m█[0m[38;2;102;116;126m█[0m[38;2;103;116;128m█[0m[38;2;102;116;128m█[0m[38;2;98;112;125m█[0m[38;2;99;112;126m█[0m[38;2;101;114;127m█[0m[38;2;104;115;126m█[0m");
//$display("[38;2;129;142;157m█[0m[38;2;128;141;156m█[0m[38;2;126;140;155m█[0m[38;2;124;140;155m█[0m[38;2;124;140;155m█[0m[38;2;124;139;154m█[0m[38;2;123;138;154m█[0m[38;2;123;139;155m█[0m[38;2;122;138;154m█[0m[38;2;121;137;153m█[0m[38;2;121;137;153m█[0m[38;2;121;137;152m█[0m[38;2;120;136;151m█[0m[38;2;120;137;151m█[0m[38;2;121;137;152m█[0m[38;2;118;135;149m█[0m[38;2;118;134;149m█[0m[38;2;114;131;147m█[0m[38;2;115;131;146m█[0m[38;2;117;133;146m█[0m[38;2;117;133;146m█[0m[38;2;121;135;144m█[0m[38;2;122;131;134m█[0m[38;2;121;127;127m█[0m[38;2;117;120;114m█[0m[38;2;124;117;99m█[0m[38;2;146;127;93m█[0m[38;2;180;157;112m█[0m[38;2;202;178;127m█[0m[38;2;177;153;106m█[0m[38;2;136;117;79m█[0m[38;2;104;88;59m█[0m[38;2;82;67;46m█[0m[38;2;99;81;63m█[0m[38;2;128;106;84m█[0m[38;2;124;99;77m█[0m[38;2;82;59;41m█[0m[38;2;63;40;26m█[0m[38;2;55;37;24m█[0m[38;2;57;43;29m█[0m[38;2;74;56;42m█[0m[38;2;126;102;86m█[0m[38;2;113;87;67m█[0m[38;2;110;86;62m█[0m[38;2;108;81;58m█[0m[38;2;120;92;67m█[0m[38;2;126;99;73m█[0m[38;2;131;103;78m█[0m[38;2;122;96;73m█[0m[38;2;74;54;38m█[0m[38;2;52;35;23m█[0m[38;2;64;47;33m█[0m[38;2;69;50;34m█[0m[38;2;87;66;46m█[0m[38;2;114;88;68m█[0m[38;2;146;119;97m█[0m[38;2;149;120;98m█[0m[38;2;118;94;70m█[0m[38;2;99;81;57m█[0m[38;2;94;77;54m█[0m[38;2;77;63;44m█[0m[38;2;48;44;35m█[0m[38;2;51;57;61m█[0m[38;2;94;106;113m█[0m[38;2;114;127;137m█[0m[38;2;115;129;144m█[0m[38;2;115;130;145m█[0m[38;2;115;130;146m█[0m[38;2;113;129;145m█[0m[38;2;109;126;143m█[0m[38;2;106;123;141m█[0m[38;2;107;124;141m█[0m[38;2;106;124;138m█[0m[38;2;100;118;132m█[0m[38;2;99;117;133m█[0m[38;2;99;117;133m█[0m[38;2;98;115;132m█[0m[38;2;98;115;131m█[0m[38;2;98;113;128m█[0m[38;2;97;112;123m█[0m");
//$display("[38;2;121;136;153m█[0m[38;2;121;136;153m█[0m[38;2;120;136;152m█[0m[38;2;121;137;153m█[0m[38;2;121;137;154m█[0m[38;2;121;137;154m█[0m[38;2;122;138;155m█[0m[38;2;122;138;154m█[0m[38;2;121;137;154m█[0m[38;2;118;135;151m█[0m[38;2;118;134;151m█[0m[38;2;118;135;151m█[0m[38;2;119;135;151m█[0m[38;2;118;134;151m█[0m[38;2;117;133;149m█[0m[38;2;115;132;148m█[0m[38;2;114;131;146m█[0m[38;2;112;129;145m█[0m[38;2;113;129;145m█[0m[38;2;114;129;145m█[0m[38;2;113;126;137m█[0m[38;2;122;128;127m█[0m[38;2;115;112;97m█[0m[38;2;103;94;73m█[0m[38;2;103;90;61m█[0m[38;2;138;115;76m█[0m[38;2;177;148;105m█[0m[38;2;188;162;120m█[0m[38;2;154;132;93m█[0m[38;2;114;95;63m█[0m[38;2;80;67;42m█[0m[38;2;55;48;31m█[0m[38;2;51;43;30m█[0m[38;2;73;58;41m█[0m[38;2;100;80;57m█[0m[38;2;113;90;68m█[0m[38;2;115;90;71m█[0m[38;2;114;86;69m█[0m[38;2;107;81;62m█[0m[38;2;108;84;64m█[0m[38;2;120;96;76m█[0m[38;2;135;112;90m█[0m[38;2;115;93;69m█[0m[38;2;84;62;39m█[0m[38;2;89;65;42m█[0m[38;2;97;69;46m█[0m[38;2;107;79;55m█[0m[38;2;97;70;47m█[0m[38;2;89;63;39m█[0m[38;2;105;81;56m█[0m[38;2;96;73;49m█[0m[38;2;98;73;50m█[0m[38;2;101;74;51m█[0m[38;2;106;79;55m█[0m[38;2;115;88;63m█[0m[38;2;124;96;69m█[0m[38;2;116;90;65m█[0m[38;2;93;75;54m█[0m[38;2;60;49;32m█[0m[38;2;58;49;32m█[0m[38;2;69;59;39m█[0m[38;2;58;50;37m█[0m[38;2;34;34;31m█[0m[38;2;51;59;62m█[0m[38;2;94;107;117m█[0m[38;2;104;121;137m█[0m[38;2;106;122;138m█[0m[38;2;104;121;141m█[0m[38;2;102;119;140m█[0m[38;2;101;119;139m█[0m[38;2;99;118;137m█[0m[38;2;98;119;137m█[0m[38;2;97;118;137m█[0m[38;2;97;118;137m█[0m[38;2;96;117;136m█[0m[38;2;95;115;134m█[0m[38;2;95;114;133m█[0m[38;2;95;113;132m█[0m[38;2;95;110;128m█[0m[38;2;94;110;126m█[0m");
//$display("[38;2;120;136;152m█[0m[38;2;121;137;153m█[0m[38;2;121;136;153m█[0m[38;2;120;136;153m█[0m[38;2;117;133;150m█[0m[38;2;121;136;152m█[0m[38;2;120;135;149m█[0m[38;2;120;135;149m█[0m[38;2;123;137;152m█[0m[38;2;124;138;153m█[0m[38;2;123;137;152m█[0m[38;2;122;136;152m█[0m[38;2;120;135;150m█[0m[38;2;119;134;148m█[0m[38;2;118;133;147m█[0m[38;2;118;132;148m█[0m[38;2;117;131;147m█[0m[38;2;116;130;147m█[0m[38;2;115;128;144m█[0m[38;2;114;127;142m█[0m[38;2;118;125;131m█[0m[38;2;136;131;123m█[0m[38;2;128;112;89m█[0m[38;2;100;77;49m█[0m[38;2;122;96;61m█[0m[38;2;168;140;96m█[0m[38;2;182;155;115m█[0m[38;2;137;115;79m█[0m[38;2;97;79;49m█[0m[38;2;69;57;36m█[0m[38;2;47;41;27m█[0m[38;2;38;36;25m█[0m[38;2;55;49;35m█[0m[38;2;83;70;53m█[0m[38;2;99;80;62m█[0m[38;2;98;78;58m█[0m[38;2;104;82;60m█[0m[38;2;122;96;73m█[0m[38;2;133;107;82m█[0m[38;2;140;114;88m█[0m[38;2;140;115;89m█[0m[38;2;114;92;67m█[0m[38;2;81;60;39m█[0m[38;2;83;61;40m█[0m[38;2;83;60;37m█[0m[38;2;92;67;42m█[0m[38;2;100;76;50m█[0m[38;2;85;62;37m█[0m[38;2;78;55;30m█[0m[38;2;110;84;58m█[0m[38;2;141;112;85m█[0m[38;2;142;109;81m█[0m[38;2;144;110;83m█[0m[38;2;145;111;84m█[0m[38;2;144;112;84m█[0m[38;2;135;105;75m█[0m[38;2;122;97;68m█[0m[38;2;95;78;55m█[0m[38;2;52;44;30m█[0m[38;2;28;25;18m█[0m[38;2;38;32;22m█[0m[38;2;42;34;23m█[0m[38;2;27;23;16m█[0m[38;2;22;22;20m█[0m[38;2;54;63;71m█[0m[38;2;92;108;122m█[0m[38;2;100;118;133m█[0m[38;2;101;119;139m█[0m[38;2;101;119;139m█[0m[38;2;101;119;139m█[0m[38;2;100;118;138m█[0m[38;2;99;118;138m█[0m[38;2;96;117;136m█[0m[38;2;95;116;135m█[0m[38;2;94;116;135m█[0m[38;2;92;114;132m█[0m[38;2;93;110;131m█[0m[38;2;92;110;130m█[0m[38;2;91;110;130m█[0m[38;2;91;110;128m█[0m");
//$display("[38;2;120;134;151m█[0m[38;2;121;135;152m█[0m[38;2;118;133;146m█[0m[38;2;104;118;129m█[0m[38;2;89;102;114m█[0m[38;2;93;105;117m█[0m[38;2;89;99;111m█[0m[38;2;95;105;116m█[0m[38;2;98;108;119m█[0m[38;2;99;109;120m█[0m[38;2;97;108;118m█[0m[38;2;88;99;107m█[0m[38;2;87;98;107m█[0m[38;2;89;102;111m█[0m[38;2;90;102;113m█[0m[38;2;90;100;112m█[0m[38;2;89;99;110m█[0m[38;2;86;97;110m█[0m[38;2;103;114;127m█[0m[38;2;110;123;134m█[0m[38;2;111;119;120m█[0m[38;2;127;120;108m█[0m[38;2;120;100;73m█[0m[38;2;115;90;55m█[0m[38;2;154;128;88m█[0m[38;2;178;153;111m█[0m[38;2;154;133;94m█[0m[38;2;109;92;58m█[0m[38;2;81;67;42m█[0m[38;2;51;46;29m█[0m[38;2;34;34;24m█[0m[38;2;39;38;28m█[0m[38;2;47;42;28m█[0m[38;2;59;50;34m█[0m[38;2;63;51;35m█[0m[38;2;65;51;34m█[0m[38;2;74;57;39m█[0m[38;2;93;72;51m█[0m[38;2;111;86;64m█[0m[38;2;112;90;67m█[0m[38;2;94;77;55m█[0m[38;2;73;56;36m█[0m[38;2;67;50;33m█[0m[38;2;73;55;36m█[0m[38;2;74;56;35m█[0m[38;2;84;65;40m█[0m[38;2;93;72;45m█[0m[38;2;80;59;35m█[0m[38;2;69;52;30m█[0m[38;2;64;46;27m█[0m[38;2;83;63;41m█[0m[38;2;108;85;60m█[0m[38;2;124;99;73m█[0m[38;2;122;96;69m█[0m[38;2;111;85;58m█[0m[38;2;102;77;49m█[0m[38;2;101;80;52m█[0m[38;2;92;73;50m█[0m[38;2;64;52;38m█[0m[38;2;30;24;19m█[0m[38;2;20;15;11m█[0m[38;2;32;26;21m█[0m[38;2;24;21;13m█[0m[38;2;12;11;6m█[0m[38;2;17;23;26m█[0m[38;2;67;81;93m█[0m[38;2;94;113;130m█[0m[38;2;99;118;135m█[0m[38;2;100;119;136m█[0m[38;2;99;118;136m█[0m[38;2;100;118;137m█[0m[38;2;98;116;136m█[0m[38;2;96;115;134m█[0m[38;2;95;113;133m█[0m[38;2;94;112;132m█[0m[38;2;91;110;130m█[0m[38;2;91;109;129m█[0m[38;2;91;110;130m█[0m[38;2;89;110;131m█[0m[38;2;88;108;127m█[0m");
//$display("[38;2;119;135;150m█[0m[38;2;118;135;149m█[0m[38;2;113;129;142m█[0m[38;2;83;100;111m█[0m[38;2;66;80;92m█[0m[38;2;66;79;90m█[0m[38;2;67;80;90m█[0m[38;2;68;82;91m█[0m[38;2;70;83;93m█[0m[38;2;70;85;95m█[0m[38;2;72;87;98m█[0m[38;2;71;86;97m█[0m[38;2;72;87;98m█[0m[38;2;76;89;100m█[0m[38;2;78;90;102m█[0m[38;2;78;90;102m█[0m[38;2;76;91;100m█[0m[38;2;78;94;103m█[0m[38;2;98;111;123m█[0m[38;2;107;120;132m█[0m[38;2;111;118;122m█[0m[38;2;115;113;100m█[0m[38;2;124;107;78m█[0m[38;2;127;100;62m█[0m[38;2;168;140;101m█[0m[38;2;168;141;101m█[0m[38;2;126;106;71m█[0m[38;2;84;69;39m█[0m[38;2;62;49;26m█[0m[38;2;51;42;24m█[0m[38;2;52;46;29m█[0m[38;2;51;44;29m█[0m[38;2;50;42;28m█[0m[38;2;54;46;33m█[0m[38;2;57;47;34m█[0m[38;2;62;49;35m█[0m[38;2;71;56;40m█[0m[38;2;78;62;42m█[0m[38;2;79;60;39m█[0m[38;2;75;57;37m█[0m[38;2;62;48;33m█[0m[38;2;56;43;28m█[0m[38;2;56;41;21m█[0m[38;2;78;58;34m█[0m[38;2;95;70;40m█[0m[38;2;114;86;54m█[0m[38;2;120;92;59m█[0m[38;2;106;79;50m█[0m[38;2;91;69;42m█[0m[38;2;65;50;28m█[0m[38;2;49;37;21m█[0m[38;2;65;50;32m█[0m[38;2;82;64;41m█[0m[38;2;90;70;47m█[0m[38;2;90;70;47m█[0m[38;2;83;63;39m█[0m[38;2;76;57;35m█[0m[38;2;68;50;32m█[0m[38;2;58;46;30m█[0m[38;2;38;34;21m█[0m[38;2;23;20;12m█[0m[38;2;22;18;12m█[0m[38;2;20;16;10m█[0m[38;2;14;9;5m█[0m[38;2;14;17;17m█[0m[38;2;56;68;77m█[0m[38;2;89;107;123m█[0m[38;2;96;115;132m█[0m[38;2;99;118;135m█[0m[38;2;99;118;135m█[0m[38;2;99;118;135m█[0m[38;2;98;116;136m█[0m[38;2;98;116;135m█[0m[38;2;96;114;134m█[0m[38;2;95;113;133m█[0m[38;2;95;113;133m█[0m[38;2;93;111;131m█[0m[38;2;90;108;129m█[0m[38;2;85;107;127m█[0m[38;2;85;105;124m█[0m");
//$display("[38;2;119;136;151m█[0m[38;2;120;136;151m█[0m[38;2;118;134;150m█[0m[38;2;111;127;144m█[0m[38;2;107;122;138m█[0m[38;2;107;121;136m█[0m[38;2;110;124;138m█[0m[38;2;112;127;140m█[0m[38;2;111;127;139m█[0m[38;2;110;124;138m█[0m[38;2;111;124;140m█[0m[38;2;111;124;141m█[0m[38;2;113;125;142m█[0m[38;2;113;125;143m█[0m[38;2;110;126;141m█[0m[38;2;109;125;140m█[0m[38;2;109;126;141m█[0m[38;2;109;125;141m█[0m[38;2;108;122;137m█[0m[38;2;109;120;134m█[0m[38;2;107;117;126m█[0m[38;2;110;110;106m█[0m[38;2;122;107;82m█[0m[38;2;143;118;79m█[0m[38;2;158;135;91m█[0m[38;2;139;113;75m█[0m[38;2;99;77;45m█[0m[38;2;72;57;30m█[0m[38;2;65;50;27m█[0m[38;2;67;51;30m█[0m[38;2;69;55;34m█[0m[38;2;69;55;34m█[0m[38;2;65;52;30m█[0m[38;2;64;52;32m█[0m[38;2;69;56;38m█[0m[38;2;76;60;42m█[0m[38;2;71;57;39m█[0m[38;2;60;48;31m█[0m[38;2;55;44;27m█[0m[38;2;67;52;34m█[0m[38;2;67;50;30m█[0m[38;2;68;53;29m█[0m[38;2;90;69;43m█[0m[38;2;96;69;39m█[0m[38;2;120;87;56m█[0m[38;2;134;100;64m█[0m[38;2;124;90;52m█[0m[38;2;123;88;53m█[0m[38;2;126;93;59m█[0m[38;2;100;76;46m█[0m[38;2;74;57;33m█[0m[38;2;63;47;28m█[0m[38;2;65;47;27m█[0m[38;2;71;51;30m█[0m[38;2;85;63;42m█[0m[38;2;87;65;43m█[0m[38;2;75;57;35m█[0m[38;2;61;43;23m█[0m[38;2;57;41;24m█[0m[38;2;60;49;31m█[0m[38;2;43;36;23m█[0m[38;2;21;14;11m█[0m[38;2;14;9;4m█[0m[38;2;14;9;7m█[0m[38;2;14;13;16m█[0m[38;2;44;52;62m█[0m[38;2;86;103;121m█[0m[38;2;94;114;131m█[0m[38;2;94;113;130m█[0m[38;2;95;114;131m█[0m[38;2;97;116;133m█[0m[38;2;97;116;133m█[0m[38;2;97;115;133m█[0m[38;2;94;113;130m█[0m[38;2;92;111;131m█[0m[38;2;90;110;131m█[0m[38;2;90;108;130m█[0m[38;2;89;108;129m█[0m[38;2;87;107;126m█[0m[38;2;85;105;123m█[0m");
//$display("[38;2;105;113;123m█[0m[38;2;104;112;122m█[0m[38;2;103;111;120m█[0m[38;2;101;107;118m█[0m[38;2;100;105;116m█[0m[38;2;100;105;115m█[0m[38;2;100;106;112m█[0m[38;2;96;104;109m█[0m[38;2;95;105;113m█[0m[38;2;113;125;135m█[0m[38;2;117;130;143m█[0m[38;2;115;128;143m█[0m[38;2;115;126;142m█[0m[38;2;115;127;143m█[0m[38;2;112;126;143m█[0m[38;2;110;126;142m█[0m[38;2;110;125;141m█[0m[38;2;108;124;140m█[0m[38;2;107;121;136m█[0m[38;2;105;118;131m█[0m[38;2;105;115;123m█[0m[38;2;109;109;107m█[0m[38;2;119;106;85m█[0m[38;2;145;127;88m█[0m[38;2;161;139;93m█[0m[38;2;137;112;72m█[0m[38;2;105;82;50m█[0m[38;2;87;68;40m█[0m[38;2;77;60;34m█[0m[38;2;71;54;28m█[0m[38;2;72;54;30m█[0m[38;2;77;60;35m█[0m[38;2;73;56;31m█[0m[38;2;72;55;32m█[0m[38;2;80;62;40m█[0m[38;2;89;72;49m█[0m[38;2;73;57;37m█[0m[38;2;57;41;26m█[0m[38;2;66;52;36m█[0m[38;2;61;47;27m█[0m[38;2;77;55;32m█[0m[38;2;105;78;53m█[0m[38;2;130;100;73m█[0m[38;2;120;89;64m█[0m[38;2;104;72;46m█[0m[38;2;139;106;74m█[0m[38;2;121;87;54m█[0m[38;2;137;103;69m█[0m[38;2;121;87;55m█[0m[38;2;118;85;52m█[0m[38;2;116;87;54m█[0m[38;2;84;62;34m█[0m[38;2;64;46;23m█[0m[38;2;60;42;20m█[0m[38;2;78;60;36m█[0m[38;2;85;66;41m█[0m[38;2;84;66;41m█[0m[38;2;78;61;36m█[0m[38;2;71;54;29m█[0m[38;2;79;63;36m█[0m[38;2;74;59;33m█[0m[38;2;44;34;19m█[0m[38;2;17;11;5m█[0m[38;2;11;7;6m█[0m[38;2;15;13;16m█[0m[38;2;46;54;64m█[0m[38;2;77;94;111m█[0m[38;2;90;110;127m█[0m[38;2;93;112;129m█[0m[38;2;91;110;128m█[0m[38;2;91;110;128m█[0m[38;2;90;110;129m█[0m[38;2;91;111;130m█[0m[38;2;90;110;129m█[0m[38;2;87;108;129m█[0m[38;2;86;107;128m█[0m[38;2;85;105;127m█[0m[38;2;84;104;125m█[0m[38;2;85;105;123m█[0m[38;2;84;104;123m█[0m");
//$display("[38;2;60;65;70m█[0m[38;2;59;64;69m█[0m[38;2;58;65;70m█[0m[38;2;58;65;69m█[0m[38;2;57;64;69m█[0m[38;2;57;65;69m█[0m[38;2;59;67;69m█[0m[38;2;58;68;72m█[0m[38;2;71;82;89m█[0m[38;2;108;120;131m█[0m[38;2;114;127;139m█[0m[38;2;114;127;141m█[0m[38;2;113;126;141m█[0m[38;2;112;126;141m█[0m[38;2;111;125;141m█[0m[38;2;109;125;140m█[0m[38;2;108;124;138m█[0m[38;2;106;123;136m█[0m[38;2;107;121;134m█[0m[38;2;103;117;128m█[0m[38;2;99;111;118m█[0m[38;2;103;108;107m█[0m[38;2;121;115;100m█[0m[38;2;154;140;106m█[0m[38;2;178;156;113m█[0m[38;2;166;144;100m█[0m[38;2;144;121;80m█[0m[38;2;112;89;55m█[0m[38;2;90;67;36m█[0m[38;2;87;66;34m█[0m[38;2;93;71;40m█[0m[38;2;95;73;41m█[0m[38;2;88;66;35m█[0m[38;2;88;66;38m█[0m[38;2;95;73;46m█[0m[38;2;98;81;56m█[0m[38;2;77;59;39m█[0m[38;2;72;54;35m█[0m[38;2;78;58;37m█[0m[38;2;78;58;34m█[0m[38;2;102;77;50m█[0m[38;2;124;96;65m█[0m[38;2;137;105;74m█[0m[38;2;143;111;81m█[0m[38;2;121;90;61m█[0m[38;2;130;97;65m█[0m[38;2;122;88;56m█[0m[38;2;135;101;68m█[0m[38;2;125;91;60m█[0m[38;2;139;105;69m█[0m[38;2;128;95;61m█[0m[38;2;105;78;47m█[0m[38;2;87;67;38m█[0m[38;2;63;46;22m█[0m[38;2;77;60;36m█[0m[38;2;103;83;55m█[0m[38;2;97;77;47m█[0m[38;2;93;73;43m█[0m[38;2;86;65;35m█[0m[38;2;87;64;31m█[0m[38;2;86;65;32m█[0m[38;2;72;56;30m█[0m[38;2;43;34;20m█[0m[38;2;24;21;13m█[0m[38;2;21;24;24m█[0m[38;2;34;45;53m█[0m[38;2;59;78;92m█[0m[38;2;82;102;119m█[0m[38;2;89;108;126m█[0m[38;2;90;109;129m█[0m[38;2;89;110;128m█[0m[38;2;87;109;126m█[0m[38;2;87;108;126m█[0m[38;2;86;107;125m█[0m[38;2;84;105;124m█[0m[38;2;80;101;123m█[0m[38;2;78;100;122m█[0m[38;2;76;96;120m█[0m[38;2;74;96;117m█[0m[38;2;73;96;115m█[0m");
//$display("[38;2;96;108;122m█[0m[38;2;95;107;122m█[0m[38;2;95;107;121m█[0m[38;2;95;108;121m█[0m[38;2;94;107;120m█[0m[38;2;95;108;122m█[0m[38;2;96;109;123m█[0m[38;2;97;111;124m█[0m[38;2;101;116;128m█[0m[38;2;109;124;137m█[0m[38;2;111;127;140m█[0m[38;2;112;128;141m█[0m[38;2;111;126;141m█[0m[38;2;108;124;140m█[0m[38;2;108;124;139m█[0m[38;2;107;123;138m█[0m[38;2;106;122;136m█[0m[38;2;104;120;134m█[0m[38;2;106;122;134m█[0m[38;2;104;118;128m█[0m[38;2;101;114;123m█[0m[38;2;106;113;120m█[0m[38;2;119;115;107m█[0m[38;2;152;139;110m█[0m[38;2;190;173;131m█[0m[38;2;179;158;116m█[0m[38;2;154;131;90m█[0m[38;2;121;98;58m█[0m[38;2;105;81;43m█[0m[38;2;103;80;42m█[0m[38;2;104;81;41m█[0m[38;2;103;80;39m█[0m[38;2;101;78;39m█[0m[38;2;101;77;43m█[0m[38;2;105;82;50m█[0m[38;2;100;82;57m█[0m[38;2;73;55;37m█[0m[38;2;71;54;33m█[0m[38;2;79;61;37m█[0m[38;2;98;76;50m█[0m[38;2;113;84;57m█[0m[38;2;129;98;67m█[0m[38;2;138;108;76m█[0m[38;2;144;111;80m█[0m[38;2;146;111;81m█[0m[38;2;146;111;80m█[0m[38;2;139;104;72m█[0m[38;2;151;116;84m█[0m[38;2;154;119;88m█[0m[38;2;152;116;84m█[0m[38;2;137;106;72m█[0m[38;2;130;101;67m█[0m[38;2;119;93;61m█[0m[38;2;86;65;39m█[0m[38;2;71;54;28m█[0m[38;2;102;84;54m█[0m[38;2;105;85;51m█[0m[38;2;105;83;48m█[0m[38;2;99;75;40m█[0m[38;2;100;77;38m█[0m[38;2;100;74;35m█[0m[38;2;101;74;41m█[0m[38;2;92;73;48m█[0m[38;2;73;67;53m█[0m[38;2;59;67;67m█[0m[38;2;65;82;94m█[0m[38;2;67;85;101m█[0m[38;2;75;95;111m█[0m[38;2;82;101;119m█[0m[38;2;84;105;124m█[0m[38;2;86;106;126m█[0m[38;2;84;105;123m█[0m[38;2;82;103;121m█[0m[38;2;79;100;118m█[0m[38;2;77;98;117m█[0m[38;2;73;93;116m█[0m[38;2;73;93;118m█[0m[38;2;71;92;117m█[0m[38;2;65;90;113m█[0m[38;2;62;88;110m█[0m");
//$display("[38;2;115;129;146m█[0m[38;2;115;128;145m█[0m[38;2;113;126;142m█[0m[38;2;112;125;141m█[0m[38;2;112;125;141m█[0m[38;2;112;125;141m█[0m[38;2;112;125;141m█[0m[38;2;112;125;141m█[0m[38;2;111;125;139m█[0m[38;2;109;125;139m█[0m[38;2;108;125;138m█[0m[38;2;111;125;138m█[0m[38;2;109;123;135m█[0m[38;2;109;124;135m█[0m[38;2;109;124;136m█[0m[38;2;109;124;136m█[0m[38;2;108;122;135m█[0m[38;2;112;124;134m█[0m[38;2;110;122;129m█[0m[38;2;104;116;120m█[0m[38;2;108;118;123m█[0m[38;2;110;116;121m█[0m[38;2;119;116;107m█[0m[38;2;161;150;119m█[0m[38;2;204;188;145m█[0m[38;2;209;189;147m█[0m[38;2;187;164;122m█[0m[38;2;146;122;79m█[0m[38;2;122;98;55m█[0m[38;2;115;90;50m█[0m[38;2;116;92;51m█[0m[38;2;118;95;53m█[0m[38;2;120;98;56m█[0m[38;2;113;89;53m█[0m[38;2;101;80;47m█[0m[38;2;84;68;41m█[0m[38;2;65;48;28m█[0m[38;2;69;53;31m█[0m[38;2;74;57;33m█[0m[38;2;91;72;45m█[0m[38;2;106;78;51m█[0m[38;2;120;90;61m█[0m[38;2;137;108;76m█[0m[38;2;132;101;70m█[0m[38;2;131;100;68m█[0m[38;2;137;105;71m█[0m[38;2;138;105;72m█[0m[38;2;147;114;80m█[0m[38;2;155;121;88m█[0m[38;2;152;118;86m█[0m[38;2;148;119;87m█[0m[38;2;145;118;87m█[0m[38;2;129;106;75m█[0m[38;2;107;87;58m█[0m[38;2;82;62;34m█[0m[38;2;94;76;42m█[0m[38;2;105;87;49m█[0m[38;2;111;87;49m█[0m[38;2;106;81;41m█[0m[38;2;110;83;42m█[0m[38;2;111;83;42m█[0m[38;2;113;84;47m█[0m[38;2;109;88;55m█[0m[38;2;109;99;82m█[0m[38;2;88;95;94m█[0m[38;2;77;96;107m█[0m[38;2;83;105;120m█[0m[38;2;85;105;123m█[0m[38;2;86;106;126m█[0m[38;2;86;107;128m█[0m[38;2;83;103;127m█[0m[38;2;77;98;122m█[0m[38;2;78;99;124m█[0m[38;2;75;98;121m█[0m[38;2;71;93;117m█[0m[38;2;69;90;114m█[0m[38;2;63;85;110m█[0m[38;2;61;85;108m█[0m[38;2;57;83;105m█[0m[38;2;56;83;103m█[0m");
//$display("[38;2;116;129;143m█[0m[38;2;115;128;142m█[0m[38;2;112;125;140m█[0m[38;2;110;123;139m█[0m[38;2;112;125;141m█[0m[38;2;112;125;141m█[0m[38;2;112;124;141m█[0m[38;2;112;125;141m█[0m[38;2;112;125;141m█[0m[38;2;108;124;139m█[0m[38;2;107;124;137m█[0m[38;2;108;124;137m█[0m[38;2;110;123;134m█[0m[38;2;100;110;120m█[0m[38;2;93;103;109m█[0m[38;2;98;105;110m█[0m[38;2;96;102;106m█[0m[38;2;104;109;113m█[0m[38;2;89;91;95m█[0m[38;2;99;101;105m█[0m[38;2;113;118;120m█[0m[38;2;112;113;112m█[0m[38;2;122;115;100m█[0m[38;2;176;163;128m█[0m[38;2;214;196;153m█[0m[38;2;217;197;154m█[0m[38;2;206;185;140m█[0m[38;2;185;162;116m█[0m[38;2;155;131;84m█[0m[38;2;135;109;66m█[0m[38;2;133;105;64m█[0m[38;2;132;104;61m█[0m[38;2;136;110;69m█[0m[38;2;135;111;71m█[0m[38;2;120;98;62m█[0m[38;2;103;82;50m█[0m[38;2;96;72;44m█[0m[38;2;93;69;42m█[0m[38;2;90;65;39m█[0m[38;2;104;79;52m█[0m[38;2;100;75;45m█[0m[38;2;102;77;46m█[0m[38;2;105;78;48m█[0m[38;2;100;71;42m█[0m[38;2;106;77;47m█[0m[38;2;113;81;51m█[0m[38;2;118;83;53m█[0m[38;2;124;89;59m█[0m[38;2;124;89;58m█[0m[38;2;130;95;64m█[0m[38;2;134;101;68m█[0m[38;2;131;102;70m█[0m[38;2;125;99;68m█[0m[38;2;120;97;66m█[0m[38;2;118;95;65m█[0m[38;2;122;100;65m█[0m[38;2;131;109;73m█[0m[38;2;129;104;64m█[0m[38;2;126;99;57m█[0m[38;2;129;99;56m█[0m[38;2;132;102;60m█[0m[38;2;131;104;64m█[0m[38;2;125;103;67m█[0m[38;2;119;107;87m█[0m[38;2;100;104;102m█[0m[38;2;78;96;108m█[0m[38;2;76;97;116m█[0m[38;2;77;98;120m█[0m[38;2;77;99;122m█[0m[38;2;78;99;124m█[0m[38;2;78;98;123m█[0m[38;2;76;98;122m█[0m[38;2;75;97;121m█[0m[38;2;71;95;119m█[0m[38;2;70;95;118m█[0m[38;2;69;93;116m█[0m[38;2;66;89;112m█[0m[38;2;65;87;110m█[0m[38;2;64;87;108m█[0m[38;2;65;87;106m█[0m");
//$display("[38;2;114;129;142m█[0m[38;2;114;129;142m█[0m[38;2;113;128;141m█[0m[38;2;111;126;140m█[0m[38;2;111;126;140m█[0m[38;2;110;124;139m█[0m[38;2;109;124;137m█[0m[38;2;109;125;137m█[0m[38;2;110;125;137m█[0m[38;2;109;124;138m█[0m[38;2;111;124;138m█[0m[38;2;110;122;136m█[0m[38;2;109;121;132m█[0m[38;2;102;110;116m█[0m[38;2;78;81;82m█[0m[38;2;84;86;85m█[0m[38;2;76;79;78m█[0m[38;2;87;90;90m█[0m[38;2;74;74;75m█[0m[38;2;85;85;85m█[0m[38;2;93;94;93m█[0m[38;2;97;95;85m█[0m[38;2;124;116;91m█[0m[38;2;183;169;131m█[0m[38;2;221;203;159m█[0m[38;2;215;197;152m█[0m[38;2;202;181;135m█[0m[38;2;185;162;114m█[0m[38;2;167;143;96m█[0m[38;2;154;129;84m█[0m[38;2;145;119;75m█[0m[38;2;136;112;67m█[0m[38;2;140;114;73m█[0m[38;2;142;119;80m█[0m[38;2;144;122;85m█[0m[38;2;138;115;81m█[0m[38;2;121;95;64m█[0m[38;2;110;85;55m█[0m[38;2;121;96;66m█[0m[38;2;119;92;64m█[0m[38;2;112;83;56m█[0m[38;2;114;84;53m█[0m[38;2;115;84;55m█[0m[38;2;125;92;65m█[0m[38;2;131;99;72m█[0m[38;2;142;109;81m█[0m[38;2;148;114;84m█[0m[38;2;150;116;85m█[0m[38;2;139;106;73m█[0m[38;2;142;108;75m█[0m[38;2;137;104;71m█[0m[38;2;125;92;61m█[0m[38;2;132;101;69m█[0m[38;2;134;106;73m█[0m[38;2;129;103;71m█[0m[38;2;138;115;77m█[0m[38;2;147;123;85m█[0m[38;2;141;114;76m█[0m[38;2;139;113;73m█[0m[38;2;142;114;72m█[0m[38;2;148;119;77m█[0m[38;2;151;125;85m█[0m[38;2;140;120;86m█[0m[38;2;124;116;97m█[0m[38;2;99;104;103m█[0m[38;2;70;85;94m█[0m[38;2;68;86;98m█[0m[38;2;72;89;107m█[0m[38;2;73;91;109m█[0m[38;2;73;91;109m█[0m[38;2;78;97;111m█[0m[38;2;79;97;110m█[0m[38;2;75;93;106m█[0m[38;2;68;87;101m█[0m[38;2;62;82;98m█[0m[38;2;58;78;95m█[0m[38;2;58;78;94m█[0m[38;2;56;76;93m█[0m[38;2;52;73;91m█[0m[38;2;53;73;90m█[0m");
//$display("[38;2;112;126;136m█[0m[38;2;114;127;137m█[0m[38;2;114;125;135m█[0m[38;2;113;124;134m█[0m[38;2;112;124;133m█[0m[38;2;112;124;132m█[0m[38;2;109;123;129m█[0m[38;2;107;122;126m█[0m[38;2;110;123;128m█[0m[38;2;112;124;131m█[0m[38;2;111;122;130m█[0m[38;2;107;117;124m█[0m[38;2;103;114;119m█[0m[38;2;100;108;106m█[0m[38;2;75;78;72m█[0m[38;2;83;83;77m█[0m[38;2;61;63;60m█[0m[38;2;70;71;71m█[0m[38;2;89;88;86m█[0m[38;2;66;66;62m█[0m[38;2;53;52;47m█[0m[38;2;87;84;69m█[0m[38;2;125;115;85m█[0m[38;2;182;165;125m█[0m[38;2;216;197;152m█[0m[38;2;212;191;145m█[0m[38;2;194;172;125m█[0m[38;2;175;152;102m█[0m[38;2;162;138;90m█[0m[38;2;150;126;80m█[0m[38;2;141;119;74m█[0m[38;2;138;116;72m█[0m[38;2;143;119;78m█[0m[38;2;143;120;78m█[0m[38;2;147;126;86m█[0m[38;2;147;124;90m█[0m[38;2;133;109;77m█[0m[38;2;116;92;61m█[0m[38;2;130;106;73m█[0m[38;2;122;96;66m█[0m[38;2;127;98;69m█[0m[38;2;129;99;69m█[0m[38;2;130;97;67m█[0m[38;2;130;96;67m█[0m[38;2;131;100;70m█[0m[38;2;145;112;84m█[0m[38;2;146;113;84m█[0m[38;2;145;113;80m█[0m[38;2;145;113;80m█[0m[38;2;147;116;82m█[0m[38;2;146;114;81m█[0m[38;2;149;119;86m█[0m[38;2;142;114;79m█[0m[38;2;151;125;91m█[0m[38;2;157;131;98m█[0m[38;2;155;131;94m█[0m[38;2;156;132;92m█[0m[38;2;150;127;85m█[0m[38;2;140;116;74m█[0m[38;2;143;118;76m█[0m[38;2;143;119;77m█[0m[38;2;146;121;82m█[0m[38;2;133;115;85m█[0m[38;2;115;107;93m█[0m[38;2;82;85;83m█[0m[38;2;59;65;70m█[0m[38;2;61;66;72m█[0m[38;2;61;66;73m█[0m[38;2;49;55;61m█[0m[38;2;42;50;54m█[0m[38;2;62;68;70m█[0m[38;2;62;68;68m█[0m[38;2;52;60;62m█[0m[38;2;46;56;63m█[0m[38;2;43;56;66m█[0m[38;2;40;54;64m█[0m[38;2;40;54;65m█[0m[38;2;36;51;62m█[0m[38;2;40;53;64m█[0m[38;2;37;49;59m█[0m");
//$display("[38;2;94;97;96m█[0m[38;2;85;88;87m█[0m[38;2;84;88;87m█[0m[38;2;84;89;89m█[0m[38;2;83;89;88m█[0m[38;2;82;87;86m█[0m[38;2;80;84;85m█[0m[38;2;79;82;82m█[0m[38;2;93;97;94m█[0m[38;2;95;99;97m█[0m[38;2;86;89;90m█[0m[38;2;74;76;77m█[0m[38;2;82;84;83m█[0m[38;2;90;91;82m█[0m[38;2;90;89;77m█[0m[38;2;101;99;87m█[0m[38;2;68;68;60m█[0m[38;2;64;66;62m█[0m[38;2;73;73;67m█[0m[38;2;61;60;53m█[0m[38;2;52;49;43m█[0m[38;2;84;78;63m█[0m[38;2;132;118;88m█[0m[38;2;187;168;126m█[0m[38;2;214;196;151m█[0m[38;2;211;190;144m█[0m[38;2;192;170;121m█[0m[38;2;174;151;99m█[0m[38;2;160;136;88m█[0m[38;2;155;131;85m█[0m[38;2;154;130;85m█[0m[38;2;151;127;83m█[0m[38;2;153;129;89m█[0m[38;2;157;134;93m█[0m[38;2;157;133;94m█[0m[38;2;152;128;94m█[0m[38;2;146;120;91m█[0m[38;2;135;111;78m█[0m[38;2;140;117;82m█[0m[38;2;135;111;77m█[0m[38;2;135;111;77m█[0m[38;2;138;111;78m█[0m[38;2;128;99;67m█[0m[38;2;130;99;68m█[0m[38;2;128;95;66m█[0m[38;2;134;100;71m█[0m[38;2;142;109;79m█[0m[38;2;142;110;78m█[0m[38;2;147;116;82m█[0m[38;2;145;116;82m█[0m[38;2;143;114;80m█[0m[38;2;143;117;82m█[0m[38;2;141;115;81m█[0m[38;2;149;124;91m█[0m[38;2;168;143;110m█[0m[38;2;170;146;113m█[0m[38;2;163;139;100m█[0m[38;2;153;130;87m█[0m[38;2;147;124;78m█[0m[38;2;146;122;76m█[0m[38;2;144;120;78m█[0m[38;2;140;116;78m█[0m[38;2;134;119;93m█[0m[38;2;109;105;95m█[0m[38;2;60;67;69m█[0m[38;2;43;55;65m█[0m[38;2;59;71;84m█[0m[38;2;61;74;88m█[0m[38;2;47;62;76m█[0m[38;2;42;57;70m█[0m[38;2;49;63;75m█[0m[38;2;48;62;73m█[0m[38;2;43;58;71m█[0m[38;2;47;64;79m█[0m[38;2;56;72;90m█[0m[38;2;57;74;93m█[0m[38;2;53;72;90m█[0m[38;2;51;71;89m█[0m[38;2;55;73;93m█[0m[38;2;54;73;91m█[0m");
//$display("[38;2;96;97;91m█[0m[38;2;75;81;84m█[0m[38;2;80;88;96m█[0m[38;2;82;90;98m█[0m[38;2;85;93;100m█[0m[38;2;86;93;101m█[0m[38;2;87;96;103m█[0m[38;2;90;99;105m█[0m[38;2;91;100;105m█[0m[38;2;85;94;97m█[0m[38;2;83;93;97m█[0m[38;2;86;94;102m█[0m[38;2;100;107;111m█[0m[38;2;95;101;101m█[0m[38;2;92;93;87m█[0m[38;2;110;109;98m█[0m[38;2;67;67;56m█[0m[38;2;75;76;70m█[0m[38;2;74;73;67m█[0m[38;2;61;59;52m█[0m[38;2;57;56;48m█[0m[38;2;77;70;54m█[0m[38;2;121;106;76m█[0m[38;2;185;165;121m█[0m[38;2;215;193;146m█[0m[38;2;204;180;130m█[0m[38;2;184;159;109m█[0m[38;2;164;138;88m█[0m[38;2;156;128;81m█[0m[38;2;153;125;81m█[0m[38;2;151;124;79m█[0m[38;2;152;127;81m█[0m[38;2;156;133;89m█[0m[38;2;156;133;94m█[0m[38;2;158;135;98m█[0m[38;2;159;135;102m█[0m[38;2;154;130;99m█[0m[38;2;155;132;98m█[0m[38;2;152;129;95m█[0m[38;2;153;130;96m█[0m[38;2;145;120;87m█[0m[38;2;132;106;73m█[0m[38;2;123;98;65m█[0m[38;2;110;84;53m█[0m[38;2;108;79;50m█[0m[38;2;121;92;64m█[0m[38;2;116;88;59m█[0m[38;2;114;86;55m█[0m[38;2;122;94;63m█[0m[38;2;120;93;63m█[0m[38;2;125;99;69m█[0m[38;2;130;105;73m█[0m[38;2;146;122;89m█[0m[38;2;165;143;109m█[0m[38;2;168;147;113m█[0m[38;2;167;146;111m█[0m[38;2;163;140;102m█[0m[38;2;155;131;89m█[0m[38;2;148;123;77m█[0m[38;2;151;124;79m█[0m[38;2;150;124;84m█[0m[38;2;145;124;87m█[0m[38;2;133;122;96m█[0m[38;2;107;106;100m█[0m[38;2;73;84;94m█[0m[38;2;70;90;105m█[0m[38;2;79;101;113m█[0m[38;2;80;101;114m█[0m[38;2;78;97;115m█[0m[38;2;79;96;118m█[0m[38;2;76;96;116m█[0m[38;2;71;93;111m█[0m[38;2;69;91;110m█[0m[38;2;68;91;111m█[0m[38;2;68;89;112m█[0m[38;2;66;87;110m█[0m[38;2;62;84;107m█[0m[38;2;62;84;106m█[0m[38;2;62;84;105m█[0m[38;2;62;83;102m█[0m");
//$display("[38;2;72;82;87m█[0m[38;2;97;110;121m█[0m[38;2;106;121;133m█[0m[38;2;108;122;134m█[0m[38;2;109;122;134m█[0m[38;2;110;124;135m█[0m[38;2;110;124;136m█[0m[38;2;111;125;137m█[0m[38;2;110;124;136m█[0m[38;2;109;122;134m█[0m[38;2;108;121;133m█[0m[38;2;107;119;131m█[0m[38;2;105;117;128m█[0m[38;2;97;107;112m█[0m[38;2;90;97;97m█[0m[38;2;76;79;75m█[0m[38;2;49;52;47m█[0m[38;2;61;65;61m█[0m[38;2;62;66;63m█[0m[38;2;45;49;45m█[0m[38;2;54;55;52m█[0m[38;2;81;75;63m█[0m[38;2;126;111;82m█[0m[38;2;192;171;128m█[0m[38;2;208;186;137m█[0m[38;2;199;175;122m█[0m[38;2;191;163;113m█[0m[38;2;169;140;91m█[0m[38;2;147;118;70m█[0m[38;2;138;109;62m█[0m[38;2;135;106;60m█[0m[38;2;141;114;66m█[0m[38;2;151;126;80m█[0m[38;2;153;128;88m█[0m[38;2;153;130;93m█[0m[38;2;155;135;100m█[0m[38;2;154;133;98m█[0m[38;2;159;139;103m█[0m[38;2;165;145;109m█[0m[38;2;165;145;109m█[0m[38;2;160;139;104m█[0m[38;2;149;129;93m█[0m[38;2;140;120;84m█[0m[38;2;125;104;68m█[0m[38;2;115;92;59m█[0m[38;2;124;101;67m█[0m[38;2;114;91;58m█[0m[38;2;112;88;53m█[0m[38;2;120;96;60m█[0m[38;2;126;101;68m█[0m[38;2;144;119;87m█[0m[38;2;162;138;104m█[0m[38;2;174;151;117m█[0m[38;2;176;156;121m█[0m[38;2;173;155;118m█[0m[38;2;168;147;109m█[0m[38;2;165;139;101m█[0m[38;2;153;127;85m█[0m[38;2;148;122;79m█[0m[38;2;147;122;78m█[0m[38;2;146;122;83m█[0m[38;2;144;123;92m█[0m[38;2;140;124;100m█[0m[38;2;127;121;108m█[0m[38;2;93;101;103m█[0m[38;2;80;97;109m█[0m[38;2;76;95;110m█[0m[38;2;72;94;108m█[0m[38;2;70;91;108m█[0m[38;2;72;93;113m█[0m[38;2;71;92;113m█[0m[38;2;69;90;111m█[0m[38;2;68;90;111m█[0m[38;2;68;91;110m█[0m[38;2;70;93;110m█[0m[38;2;69;91;111m█[0m[38;2;65;87;109m█[0m[38;2;62;84;107m█[0m[38;2;61;84;104m█[0m[38;2;60;81;100m█[0m");
//$display("[38;2;110;122;133m█[0m[38;2;111;124;136m█[0m[38;2;112;126;137m█[0m[38;2;112;126;137m█[0m[38;2;110;124;135m█[0m[38;2;111;124;135m█[0m[38;2;110;124;135m█[0m[38;2;110;124;135m█[0m[38;2;107;121;132m█[0m[38;2;107;120;131m█[0m[38;2;108;121;132m█[0m[38;2;106;119;131m█[0m[38;2;102;116;127m█[0m[38;2;95;107;114m█[0m[38;2;86;96;99m█[0m[38;2;76;83;85m█[0m[38;2;59;63;64m█[0m[38;2;76;80;81m█[0m[38;2;77;81;82m█[0m[38;2;53;57;57m█[0m[38;2;62;65;63m█[0m[38;2;88;85;73m█[0m[38;2;128;114;83m█[0m[38;2;196;175;133m█[0m[38;2;217;195;146m█[0m[38;2;207;186;133m█[0m[38;2;190;164;114m█[0m[38;2;170;140;92m█[0m[38;2;150;119;72m█[0m[38;2;132;101;54m█[0m[38;2;124;93;48m█[0m[38;2;127;99;51m█[0m[38;2;136;111;66m█[0m[38;2;140;115;75m█[0m[38;2;143;119;81m█[0m[38;2;144;122;85m█[0m[38;2;146;125;87m█[0m[38;2;150;128;89m█[0m[38;2;158;136;97m█[0m[38;2;167;145;106m█[0m[38;2;169;146;108m█[0m[38;2;165;143;105m█[0m[38;2;166;145;107m█[0m[38;2;164;142;104m█[0m[38;2;160;137;102m█[0m[38;2;155;133;96m█[0m[38;2;152;130;92m█[0m[38;2;158;135;97m█[0m[38;2;159;136;95m█[0m[38;2;161;139;98m█[0m[38;2;164;141;101m█[0m[38;2;166;142;103m█[0m[38;2;169;146;105m█[0m[38;2;167;145;104m█[0m[38;2;162;141;102m█[0m[38;2;159;136;99m█[0m[38;2;154;129;93m█[0m[38;2;148;125;85m█[0m[38;2;143;119;78m█[0m[38;2;142;118;77m█[0m[38;2;142;118;81m█[0m[38;2;145;125;89m█[0m[38;2;148;128;94m█[0m[38;2;146;131;98m█[0m[38;2;131;125;101m█[0m[38;2;111;112;101m█[0m[38;2;95;101;101m█[0m[38;2;79;93;101m█[0m[38;2;69;91;103m█[0m[38;2;68;92;109m█[0m[38;2;69;92;112m█[0m[38;2;69;90;110m█[0m[38;2;67;89;108m█[0m[38;2;65;89;107m█[0m[38;2;66;88;106m█[0m[38;2;64;85;107m█[0m[38;2;59;81;104m█[0m[38;2;58;80;104m█[0m[38;2;58;80;104m█[0m[38;2;57;77;99m█[0m");
//$display("[38;2;109;122;134m█[0m[38;2;109;123;135m█[0m[38;2;108;124;135m█[0m[38;2;107;121;132m█[0m[38;2;107;118;129m█[0m[38;2;106;116;125m█[0m[38;2;102;111;120m█[0m[38;2;98;107;120m█[0m[38;2;99;111;124m█[0m[38;2;103;116;126m█[0m[38;2;104;118;127m█[0m[38;2;103;118;129m█[0m[38;2;101;115;128m█[0m[38;2;97;110;120m█[0m[38;2;88;99;105m█[0m[38;2;82;91;95m█[0m[38;2;75;81;82m█[0m[38;2;78;83;81m█[0m[38;2;73;77;78m█[0m[38;2;65;69;68m█[0m[38;2;76;75;68m█[0m[38;2;107;102;76m█[0m[38;2;172;159;116m█[0m[38;2;215;192;146m█[0m[38;2;215;193;141m█[0m[38;2;197;175;122m█[0m[38;2;181;157;103m█[0m[38;2;160;132;82m█[0m[38;2;143;113;66m█[0m[38;2;126;96;52m█[0m[38;2;107;80;40m█[0m[38;2;100;74;32m█[0m[38;2;102;76;35m█[0m[38;2;111;85;45m█[0m[38;2;122;95;56m█[0m[38;2;130;104;65m█[0m[38;2;132;107;66m█[0m[38;2;137;112;69m█[0m[38;2;143;120;76m█[0m[38;2;148;127;82m█[0m[38;2;150;128;83m█[0m[38;2;152;126;83m█[0m[38;2;150;124;83m█[0m[38;2;151;127;85m█[0m[38;2;154;130;90m█[0m[38;2;155;130;89m█[0m[38;2;149;124;83m█[0m[38;2;144;118;76m█[0m[38;2;148;120;76m█[0m[38;2;156;127;82m█[0m[38;2;156;127;81m█[0m[38;2;152;123;77m█[0m[38;2;148;120;72m█[0m[38;2;149;124;79m█[0m[38;2;140;118;84m█[0m[38;2;98;79;53m█[0m[38;2;68;51;29m█[0m[38;2;84;67;39m█[0m[38;2;128;109;72m█[0m[38;2;137;118;78m█[0m[38;2;145;123;85m█[0m[38;2;151;128;90m█[0m[38;2;151;128;89m█[0m[38;2;145;123;83m█[0m[38;2;141;122;83m█[0m[38;2;142;125;92m█[0m[38;2;141;128;100m█[0m[38;2;126;121;104m█[0m[38;2;101;105;100m█[0m[38;2;78;92;95m█[0m[38;2;65;84;94m█[0m[38;2;64;86;101m█[0m[38;2;65;86;105m█[0m[38;2;61;83;102m█[0m[38;2;59;80;101m█[0m[38;2;57;79;100m█[0m[38;2;55;77;98m█[0m[38;2;53;74;97m█[0m[38;2;54;73;98m█[0m[38;2;55;74;97m█[0m");
//$display("[38;2;111;122;133m█[0m[38;2;110;123;134m█[0m[38;2;109;123;134m█[0m[38;2;108;121;133m█[0m[38;2;103;115;126m█[0m[38;2;85;96;105m█[0m[38;2;68;77;86m█[0m[38;2;95;104;117m█[0m[38;2;105;117;129m█[0m[38;2;105;117;127m█[0m[38;2;104;117;127m█[0m[38;2;104;116;129m█[0m[38;2;102;114;128m█[0m[38;2;97;109;121m█[0m[38;2;93;104;113m█[0m[38;2;88;97;103m█[0m[38;2;85;90;95m█[0m[38;2;80;85;88m█[0m[38;2;75;79;80m█[0m[38;2;83;81;65m█[0m[38;2;130;117;87m█[0m[38;2;186;170;125m█[0m[38;2;211;192;140m█[0m[38;2;214;190;140m█[0m[38;2;206;180;126m█[0m[38;2;194;169;114m█[0m[38;2;182;154;102m█[0m[38;2;165;135;86m█[0m[38;2;147;119;71m█[0m[38;2;130;102;58m█[0m[38;2;118;90;51m█[0m[38;2;110;81;42m█[0m[38;2;105;76;37m█[0m[38;2;106;77;37m█[0m[38;2;110;78;38m█[0m[38;2;117;84;43m█[0m[38;2;121;90;47m█[0m[38;2;126;95;51m█[0m[38;2;125;94;50m█[0m[38;2;126;98;52m█[0m[38;2;134;106;61m█[0m[38;2;135;105;60m█[0m[38;2;135;106;62m█[0m[38;2;129;101;56m█[0m[38;2;125;98;53m█[0m[38;2;127;99;55m█[0m[38;2;130;97;54m█[0m[38;2;126;93;50m█[0m[38;2;130;99;55m█[0m[38;2;136;104;59m█[0m[38;2;142;111;65m█[0m[38;2;146;115;70m█[0m[38;2;141;113;69m█[0m[38;2;145;120;86m█[0m[38;2;115;91;66m█[0m[38;2;83;63;39m█[0m[38;2;84;63;40m█[0m[38;2;74;51;29m█[0m[38;2;106;85;52m█[0m[38;2;148;126;85m█[0m[38;2;150;127;89m█[0m[38;2;151;127;88m█[0m[38;2;148;124;84m█[0m[38;2;145;121;80m█[0m[38;2;143;119;78m█[0m[38;2;140;116;74m█[0m[38;2;135;113;70m█[0m[38;2;138;117;77m█[0m[38;2;140;122;85m█[0m[38;2;134;121;94m█[0m[38;2;113;110;95m█[0m[38;2;86;96;96m█[0m[38;2;68;84;99m█[0m[38;2;58;78;93m█[0m[38;2;57;79;96m█[0m[38;2;55;78;95m█[0m[38;2;52;73;92m█[0m[38;2;49;70;90m█[0m[38;2;48;68;90m█[0m[38;2;49;69;88m█[0m");
//$display("[38;2;110;122;129m█[0m[38;2;108;119;129m█[0m[38;2;108;119;131m█[0m[38;2;108;120;132m█[0m[38;2;105;119;130m█[0m[38;2;99;112;123m█[0m[38;2;82;95;105m█[0m[38;2;102;114;125m█[0m[38;2;102;116;130m█[0m[38;2;103;115;129m█[0m[38;2;104;116;129m█[0m[38;2;106;117;130m█[0m[38;2;105;116;128m█[0m[38;2;101;112;124m█[0m[38;2;97;107;116m█[0m[38;2;91;101;106m█[0m[38;2;84;94;98m█[0m[38;2;83;87;88m█[0m[38;2;95;90;80m█[0m[38;2;145;129;99m█[0m[38;2;199;180;134m█[0m[38;2;212;192;137m█[0m[38;2;210;185;132m█[0m[38;2;206;178;126m█[0m[38;2;196;165;113m█[0m[38;2;178;145;95m█[0m[38;2;163;131;81m█[0m[38;2;147;116;67m█[0m[38;2;137;106;58m█[0m[38;2;128;97;54m█[0m[38;2;118;87;48m█[0m[38;2;114;82;43m█[0m[38;2;114;82;42m█[0m[38;2;119;86;45m█[0m[38;2;121;86;45m█[0m[38;2;124;87;45m█[0m[38;2;123;87;44m█[0m[38;2;121;86;44m█[0m[38;2;118;84;42m█[0m[38;2;117;84;41m█[0m[38;2;116;83;42m█[0m[38;2;117;85;45m█[0m[38;2;119;88;47m█[0m[38;2;120;88;48m█[0m[38;2;122;91;50m█[0m[38;2;130;99;57m█[0m[38;2;131;100;58m█[0m[38;2;133;104;62m█[0m[38;2;137;110;67m█[0m[38;2;141;114;72m█[0m[38;2;144;119;76m█[0m[38;2;143;118;75m█[0m[38;2;145;122;84m█[0m[38;2;126;105;73m█[0m[38;2;94;66;43m█[0m[38;2;114;85;63m█[0m[38;2;117;90;65m█[0m[38;2;92;64;43m█[0m[38;2;113;89;59m█[0m[38;2;153;131;92m█[0m[38;2;144;121;81m█[0m[38;2;139;116;75m█[0m[38;2;134;111;70m█[0m[38;2;132;109;66m█[0m[38;2;130;106;64m█[0m[38;2;130;103;63m█[0m[38;2;127;102;60m█[0m[38;2;123;99;59m█[0m[38;2;123;100;60m█[0m[38;2;126;104;61m█[0m[38;2;129;109;72m█[0m[38;2;117;107;86m█[0m[38;2;91;94;94m█[0m[38;2;67;80;91m█[0m[38;2;51;72;88m█[0m[38;2;46;68;83m█[0m[38;2;43;64;82m█[0m[38;2;42;62;83m█[0m[38;2;42;63;84m█[0m[38;2;42;62;81m█[0m");
//$display("[38;2;106;117;126m█[0m[38;2;105;116;123m█[0m[38;2;106;117;125m█[0m[38;2;107;118;128m█[0m[38;2;105;116;127m█[0m[38;2;99;109;121m█[0m[38;2;81;92;103m█[0m[38;2;101;112;124m█[0m[38;2;102;114;127m█[0m[38;2;101;113;126m█[0m[38;2;102;114;125m█[0m[38;2;102;113;126m█[0m[38;2;99;112;124m█[0m[38;2;97;112;118m█[0m[38;2;95;106;111m█[0m[38;2;92;97;102m█[0m[38;2;95;95;89m█[0m[38;2;120;112;87m█[0m[38;2;169;153;112m█[0m[38;2;211;189;140m█[0m[38;2;215;193;139m█[0m[38;2;212;187;132m█[0m[38;2;206;179;127m█[0m[38;2;196;165;114m█[0m[38;2;178;146;94m█[0m[38;2;156;124;76m█[0m[38;2;143;112;66m█[0m[38;2;128;97;52m█[0m[38;2;117;86;41m█[0m[38;2;114;82;41m█[0m[38;2;112;80;39m█[0m[38;2;116;83;42m█[0m[38;2;120;87;45m█[0m[38;2;123;90;46m█[0m[38;2;125;90;48m█[0m[38;2;129;92;50m█[0m[38;2;127;90;48m█[0m[38;2;122;86;44m█[0m[38;2;122;88;46m█[0m[38;2;128;95;54m█[0m[38;2;137;105;64m█[0m[38;2;149;118;77m█[0m[38;2;151;119;80m█[0m[38;2;143;114;74m█[0m[38;2;135;107;67m█[0m[38;2;148;120;79m█[0m[38;2;142;114;74m█[0m[38;2;145;118;78m█[0m[38;2;147;123;82m█[0m[38;2;141;116;76m█[0m[38;2;139;114;73m█[0m[38;2;138;113;73m█[0m[38;2;140;117;78m█[0m[38;2;113;91;58m█[0m[38;2;98;71;46m█[0m[38;2;110;86;61m█[0m[38;2;95;73;49m█[0m[38;2;64;41;19m█[0m[38;2;109;86;56m█[0m[38;2;146;120;82m█[0m[38;2;133;108;71m█[0m[38;2;124;99;61m█[0m[38;2;119;94;54m█[0m[38;2;117;93;52m█[0m[38;2;117;92;53m█[0m[38;2;116;91;50m█[0m[38;2;113;89;49m█[0m[38;2;102;78;40m█[0m[38;2;109;85;46m█[0m[38;2;118;92;52m█[0m[38;2;128;104;64m█[0m[38;2;132;115;80m█[0m[38;2;116;111;94m█[0m[38;2;78;87;91m█[0m[38;2;48;69;82m█[0m[38;2;40;61;79m█[0m[38;2;40;61;81m█[0m[38;2;39;60;79m█[0m[38;2;35;56;76m█[0m[38;2;35;55;73m█[0m");
//$display("[38;2;121;123;116m█[0m[38;2;119;122;115m█[0m[38;2;110;114;109m█[0m[38;2;101;107;105m█[0m[38;2;103;110;109m█[0m[38;2;96;103;103m█[0m[38;2;78;85;86m█[0m[38;2;100;105;106m█[0m[38;2;104;109;111m█[0m[38;2;101;109;112m█[0m[38;2;98;107;115m█[0m[38;2;97;108;119m█[0m[38;2;94;106;115m█[0m[38;2;90;104;107m█[0m[38;2;92;99;95m█[0m[38;2;105;101;85m█[0m[38;2;148;134;102m█[0m[38;2;196;174;125m█[0m[38;2;213;188;133m█[0m[38;2;209;184;128m█[0m[38;2;205;178;121m█[0m[38;2;200;170;113m█[0m[38;2;189;159;103m█[0m[38;2;171;140;86m█[0m[38;2;148;118;69m█[0m[38;2;127;96;51m█[0m[38;2;107;76;36m█[0m[38;2;104;73;35m█[0m[38;2;103;73;34m█[0m[38;2;108;76;37m█[0m[38;2;113;80;40m█[0m[38;2;116;83;41m█[0m[38;2;120;87;43m█[0m[38;2;119;86;43m█[0m[38;2;124;88;46m█[0m[38;2;127;90;47m█[0m[38;2;125;88;45m█[0m[38;2;129;92;49m█[0m[38;2;135;100;57m█[0m[38;2;144;113;70m█[0m[38;2;160;133;90m█[0m[38;2;175;150;106m█[0m[38;2;165;138;94m█[0m[38;2;148;120;77m█[0m[38;2;154;122;84m█[0m[38;2;159;128;89m█[0m[38;2;153;125;86m█[0m[38;2;146;119;82m█[0m[38;2;143;118;81m█[0m[38;2;141;115;80m█[0m[38;2;137;111;76m█[0m[38;2;135;110;74m█[0m[38;2;135;110;73m█[0m[38;2;115;91;56m█[0m[38;2;102;78;47m█[0m[38;2;99;76;49m█[0m[38;2;85;66;41m█[0m[38;2;59;41;19m█[0m[38;2;70;49;24m█[0m[38;2;115;91;58m█[0m[38;2;127;103;68m█[0m[38;2;126;100;64m█[0m[38;2;122;94;55m█[0m[38;2;118;89;50m█[0m[38;2;115;86;47m█[0m[38;2;118;90;50m█[0m[38;2;118;90;50m█[0m[38;2;110;84;42m█[0m[38;2;115;86;45m█[0m[38;2;112;82;40m█[0m[38;2;115;89;44m█[0m[38;2;126;102;63m█[0m[38;2;127;115;91m█[0m[38;2;89;92;88m█[0m[38;2;52;66;77m█[0m[38;2;37;57;70m█[0m[38;2;33;55;72m█[0m[38;2;32;52;72m█[0m[38;2;30;49;68m█[0m[38;2;29;49;65m█[0m");
//$display("[38;2;123;109;89m█[0m[38;2;123;110;90m█[0m[38;2;121;108;87m█[0m[38;2;106;95;73m█[0m[38;2;102;96;74m█[0m[38;2;78;74;54m█[0m[38;2;73;67;49m█[0m[38;2;114;104;85m█[0m[38;2;124;116;98m█[0m[38;2;88;87;77m█[0m[38;2;83;89;90m█[0m[38;2;98;106;114m█[0m[38;2;94;103;106m█[0m[38;2;100;100;94m█[0m[38;2;127;118;95m█[0m[38;2;181;163;122m█[0m[38;2;211;191;138m█[0m[38;2;209;184;129m█[0m[38;2;201;173;117m█[0m[38;2;197;168;112m█[0m[38;2;195;165;108m█[0m[38;2;185;154;99m█[0m[38;2;167;134;81m█[0m[38;2;144;111;62m█[0m[38;2;132;100;56m█[0m[38;2;114;84;44m█[0m[38;2;93;66;34m█[0m[38;2;89;62;30m█[0m[38;2;98;69;32m█[0m[38;2;102;71;33m█[0m[38;2;107;76;37m█[0m[38;2;111;79;38m█[0m[38;2;113;80;38m█[0m[38;2;122;88;47m█[0m[38;2;127;92;51m█[0m[38;2;125;88;46m█[0m[38;2;126;89;46m█[0m[38;2;130;94;50m█[0m[38;2;138;103;59m█[0m[38;2;142;109;65m█[0m[38;2;150;121;76m█[0m[38;2;151;123;79m█[0m[38;2;151;122;79m█[0m[38;2;149;118;77m█[0m[38;2;159;127;87m█[0m[38;2;168;138;100m█[0m[38;2;175;146;109m█[0m[38;2;157;129;94m█[0m[38;2;140;112;78m█[0m[38;2;138;109;75m█[0m[38;2;137;107;73m█[0m[38;2;137;108;72m█[0m[38;2;137;110;73m█[0m[38;2;103;80;46m█[0m[38;2;93;70;38m█[0m[38;2;95;71;40m█[0m[38;2;86;63;34m█[0m[38;2;66;46;25m█[0m[38;2;37;20;5m█[0m[38;2;43;26;11m█[0m[38;2;79;60;35m█[0m[38;2;107;83;47m█[0m[38;2;116;88;48m█[0m[38;2;115;85;45m█[0m[38;2;112;84;45m█[0m[38;2;110;82;43m█[0m[38;2;108;80;41m█[0m[38;2;108;80;39m█[0m[38;2;111;81;40m█[0m[38;2;116;85;44m█[0m[38;2;116;85;44m█[0m[38;2;120;90;49m█[0m[38;2;133;115;83m█[0m[38;2;110;106;93m█[0m[38;2;58;71;76m█[0m[38;2;35;54;67m█[0m[38;2;31;50;65m█[0m[38;2;27;45;64m█[0m[38;2;27;45;64m█[0m[38;2;28;46;62m█[0m");
//$display("[38;2;69;67;57m█[0m[38;2;68;66;55m█[0m[38;2;83;78;66m█[0m[38;2;80;75;64m█[0m[38;2;71;69;59m█[0m[38;2;58;57;48m█[0m[38;2;60;57;45m█[0m[38;2;78;73;60m█[0m[38;2;81;76;64m█[0m[38;2;55;54;45m█[0m[38;2;80;82;78m█[0m[38;2;97;97;92m█[0m[38;2;107;102;86m█[0m[38;2;147;136;107m█[0m[38;2;210;193;153m█[0m[38;2;224;202;153m█[0m[38;2;215;191;138m█[0m[38;2;201;173;117m█[0m[38;2;189;158;103m█[0m[38;2;186;156;100m█[0m[38;2;180;150;95m█[0m[38;2;162;131;80m█[0m[38;2;133;101;59m█[0m[38;2;113;80;45m█[0m[38;2;110;78;42m█[0m[38;2;102;72;38m█[0m[38;2;83;58;27m█[0m[38;2;84;59;28m█[0m[38;2;83;57;25m█[0m[38;2;86;58;27m█[0m[38;2;92;64;31m█[0m[38;2;94;64;29m█[0m[38;2;98;67;31m█[0m[38;2;110;77;41m█[0m[38;2;117;83;45m█[0m[38;2;126;90;50m█[0m[38;2;130;95;54m█[0m[38;2;131;96;53m█[0m[38;2;136;101;56m█[0m[38;2;141;108;63m█[0m[38;2;143;112;68m█[0m[38;2;150;118;74m█[0m[38;2;160;129;85m█[0m[38;2;159;127;86m█[0m[38;2;162;129;90m█[0m[38;2;172;140;105m█[0m[38;2;183;149;118m█[0m[38;2;182;149;116m█[0m[38;2;169;136;102m█[0m[38;2;158;127;91m█[0m[38;2;150;121;84m█[0m[38;2;144;117;78m█[0m[38;2;145;120;81m█[0m[38;2;120;96;62m█[0m[38;2;115;91;58m█[0m[38;2;110;86;53m█[0m[38;2;100;75;47m█[0m[38;2;75;54;31m█[0m[38;2;36;21;8m█[0m[38;2;20;6;5m█[0m[38;2;25;10;4m█[0m[38;2;50;31;13m█[0m[38;2;95;72;39m█[0m[38;2;120;92;53m█[0m[38;2;119;92;52m█[0m[38;2;115;90;49m█[0m[38;2;111;86;45m█[0m[38;2;111;85;42m█[0m[38;2;114;85;43m█[0m[38;2;119;88;47m█[0m[38;2;125;94;53m█[0m[38;2;123;94;50m█[0m[38;2;129;108;66m█[0m[38;2;127;116;89m█[0m[38;2;79;86;83m█[0m[38;2;36;53;64m█[0m[38;2;29;47;59m█[0m[38;2;28;45;63m█[0m[38;2;26;43;64m█[0m[38;2;27;46;63m█[0m");
//$display("[38;2;60;61;56m█[0m[38;2;68;69;65m█[0m[38;2;63;63;59m█[0m[38;2;57;57;51m█[0m[38;2;62;62;55m█[0m[38;2;59;58;51m█[0m[38;2;59;60;54m█[0m[38;2;65;66;62m█[0m[38;2;55;57;50m█[0m[38;2;68;68;58m█[0m[38;2;84;79;62m█[0m[38;2;98;85;59m█[0m[38;2;153;137;103m█[0m[38;2;210;194;154m█[0m[38;2;233;217;173m█[0m[38;2;221;201;151m█[0m[38;2;204;179;124m█[0m[38;2;194;164;108m█[0m[38;2;189;157;102m█[0m[38;2;177;145;93m█[0m[38;2;144;112;67m█[0m[38;2;124;92;54m█[0m[38;2;114;82;49m█[0m[38;2;102;72;40m█[0m[38;2;104;77;44m█[0m[38;2;95;70;39m█[0m[38;2;86;63;31m█[0m[38;2;76;52;24m█[0m[38;2;77;51;25m█[0m[38;2;78;52;27m█[0m[38;2;76;49;23m█[0m[38;2;86;59;28m█[0m[38;2;89;60;27m█[0m[38;2;96;66;31m█[0m[38;2;102;71;32m█[0m[38;2;115;83;43m█[0m[38;2;125;92;51m█[0m[38;2;132;97;55m█[0m[38;2;129;94;50m█[0m[38;2;134;100;56m█[0m[38;2;142;109;65m█[0m[38;2;148;116;71m█[0m[38;2;159;128;84m█[0m[38;2;165;133;90m█[0m[38;2;166;135;94m█[0m[38;2;169;137;99m█[0m[38;2;173;145;107m█[0m[38;2;170;145;111m█[0m[38;2;159;134;101m█[0m[38;2;153;129;93m█[0m[38;2;145;121;86m█[0m[38;2;148;127;89m█[0m[38;2;156;135;94m█[0m[38;2;152;126;88m█[0m[38;2;130;105;70m█[0m[38;2;93;70;45m█[0m[38;2;61;43;26m█[0m[38;2;43;27;13m█[0m[38;2;31;15;7m█[0m[38;2;24;12;8m█[0m[38;2;14;5;3m█[0m[38;2;14;5;1m█[0m[38;2;43;30;16m█[0m[38;2;79;58;31m█[0m[38;2;107;82;47m█[0m[38;2;119;91;51m█[0m[38;2;123;95;52m█[0m[38;2;126;98;54m█[0m[38;2;127;96;53m█[0m[38;2;129;97;54m█[0m[38;2;135;104;60m█[0m[38;2;136;105;59m█[0m[38;2;136;110;63m█[0m[38;2;133;114;74m█[0m[38;2;112;107;90m█[0m[38;2;56;64;69m█[0m[38;2;32;47;61m█[0m[38;2;29;45;61m█[0m[38;2;26;43;58m█[0m[38;2;24;41;55m█[0m");
//$display("[38;2;71;70;66m█[0m[38;2;62;61;59m█[0m[38;2;72;71;68m█[0m[38;2;66;66;62m█[0m[38;2;61;60;54m█[0m[38;2;70;69;61m█[0m[38;2;60;63;55m█[0m[38;2;60;62;58m█[0m[38;2;74;75;65m█[0m[38;2;76;72;55m█[0m[38;2;98;85;58m█[0m[38;2;155;141;100m█[0m[38;2;219;204;162m█[0m[38;2;232;218;175m█[0m[38;2;226;207;161m█[0m[38;2;211;188;136m█[0m[38;2;200;173;117m█[0m[38;2;195;165;110m█[0m[38;2;164;134;82m█[0m[38;2;145;115;68m█[0m[38;2;123;94;54m█[0m[38;2;105;77;44m█[0m[38;2;110;81;51m█[0m[38;2;99;74;42m█[0m[38;2;87;64;33m█[0m[38;2;82;59;29m█[0m[38;2;78;54;26m█[0m[38;2;78;54;26m█[0m[38;2;79;54;27m█[0m[38;2;72;49;23m█[0m[38;2;78;53;28m█[0m[38;2;85;58;31m█[0m[38;2;85;58;27m█[0m[38;2;93;66;32m█[0m[38;2;98;69;30m█[0m[38;2;105;74;34m█[0m[38;2;113;81;41m█[0m[38;2;121;86;45m█[0m[38;2;121;87;46m█[0m[38;2;123;89;47m█[0m[38;2;129;97;53m█[0m[38;2;139;107;63m█[0m[38;2;151;119;75m█[0m[38;2;159;128;84m█[0m[38;2;157;129;89m█[0m[38;2;163;140;100m█[0m[38;2;147;124;89m█[0m[38;2;114;92;62m█[0m[38;2;107;86;55m█[0m[38;2;111;91;58m█[0m[38;2;109;88;56m█[0m[38;2;114;93;61m█[0m[38;2;114;92;58m█[0m[38;2;115;90;55m█[0m[38;2;99;72;41m█[0m[38;2;61;39;19m█[0m[38;2;32;19;8m█[0m[38;2;19;10;3m█[0m[38;2;19;8;3m█[0m[38;2;17;7;3m█[0m[38;2;15;6;3m█[0m[38;2;12;4;2m█[0m[38;2;9;4;1m█[0m[38;2;21;10;4m█[0m[38;2;47;26;15m█[0m[38;2;69;44;22m█[0m[38;2;95;71;39m█[0m[38;2;121;97;55m█[0m[38;2;134;104;58m█[0m[38;2;140;108;60m█[0m[38;2;141;111;64m█[0m[38;2;139;109;63m█[0m[38;2;135;107;59m█[0m[38;2;138;115;72m█[0m[38;2;137;122;91m█[0m[38;2;110;108;96m█[0m[38;2;47;60;64m█[0m[38;2;29;45;56m█[0m[38;2;27;45;56m█[0m[38;2;25;42;52m█[0m");
//$display("[38;2;52;53;48m█[0m[38;2;46;47;43m█[0m[38;2;55;56;52m█[0m[38;2;50;51;47m█[0m[38;2;51;52;46m█[0m[38;2;50;52;45m█[0m[38;2;46;48;43m█[0m[38;2;49;50;44m█[0m[38;2;64;59;46m█[0m[38;2;95;82;58m█[0m[38;2;153;138;101m█[0m[38;2;218;203;158m█[0m[38;2;234;220;176m█[0m[38;2;230;216;170m█[0m[38;2;214;194;143m█[0m[38;2;201;174;123m█[0m[38;2;185;157;108m█[0m[38;2;155;127;78m█[0m[38;2;150;123;75m█[0m[38;2;134;108;64m█[0m[38;2;99;72;35m█[0m[38;2;94;68;34m█[0m[38;2;98;73;40m█[0m[38;2;82;58;29m█[0m[38;2;71;49;20m█[0m[38;2;81;59;27m█[0m[38;2;83;62;32m█[0m[38;2;72;51;24m█[0m[38;2;76;55;26m█[0m[38;2;77;57;29m█[0m[38;2;79;57;29m█[0m[38;2;78;54;26m█[0m[38;2;73;49;20m█[0m[38;2;78;53;23m█[0m[38;2;85;58;23m█[0m[38;2;94;64;26m█[0m[38;2;106;74;36m█[0m[38;2;111;78;40m█[0m[38;2;112;79;40m█[0m[38;2;120;88;48m█[0m[38;2;120;88;47m█[0m[38;2;120;88;47m█[0m[38;2;133;101;58m█[0m[38;2;137;105;62m█[0m[38;2;142;115;74m█[0m[38;2;136;119;81m█[0m[38;2;79;63;36m█[0m[38;2;67;48;27m█[0m[38;2;73;55;33m█[0m[38;2;76;60;35m█[0m[38;2;82;64;38m█[0m[38;2;90;69;43m█[0m[38;2;102;79;50m█[0m[38;2;117;92;57m█[0m[38;2;103;77;46m█[0m[38;2;70;49;28m█[0m[38;2;41;27;12m█[0m[38;2;27;15;5m█[0m[38;2;22;9;4m█[0m[38;2;18;6;3m█[0m[38;2;18;8;4m█[0m[38;2;12;3;1m█[0m[38;2;11;5;2m█[0m[38;2;11;7;4m█[0m[38;2;15;7;3m█[0m[38;2;21;9;4m█[0m[38;2;28;14;7m█[0m[38;2;43;28;14m█[0m[38;2;66;48;26m█[0m[38;2;111;88;53m█[0m[38;2;136;111;66m█[0m[38;2;138;110;63m█[0m[38;2;140;113;64m█[0m[38;2;132;110;65m█[0m[38;2;138;118;78m█[0m[38;2;142;130;104m█[0m[38;2;98;99;92m█[0m[38;2;37;49;53m█[0m[38;2;28;43;52m█[0m[38;2;25;41;50m█[0m");
//$display("[38;2;59;60;55m█[0m[38;2;64;65;59m█[0m[38;2;55;56;50m█[0m[38;2;51;52;46m█[0m[38;2;60;62;56m█[0m[38;2;53;54;49m█[0m[38;2;48;49;44m█[0m[38;2;56;57;49m█[0m[38;2;73;66;48m█[0m[38;2;126;110;78m█[0m[38;2;200;185;142m█[0m[38;2;231;216;173m█[0m[38;2;228;214;173m█[0m[38;2;225;208;164m█[0m[38;2;210;188;138m█[0m[38;2;188;162;112m█[0m[38;2;162;135;87m█[0m[38;2;162;134;86m█[0m[38;2;145;118;73m█[0m[38;2;108;82;44m█[0m[38;2;103;76;41m█[0m[38;2;103;77;41m█[0m[38;2;92;67;33m█[0m[38;2;88;63;31m█[0m[38;2;85;61;29m█[0m[38;2;87;62;31m█[0m[38;2;80;56;26m█[0m[38;2;76;53;25m█[0m[38;2;83;59;29m█[0m[38;2;81;56;27m█[0m[38;2;87;61;31m█[0m[38;2;81;57;26m█[0m[38;2;76;54;23m█[0m[38;2;79;54;24m█[0m[38;2;89;62;29m█[0m[38;2;97;69;32m█[0m[38;2;100;71;33m█[0m[38;2;104;74;35m█[0m[38;2;107;77;38m█[0m[38;2;107;75;37m█[0m[38;2;111;80;39m█[0m[38;2;114;82;40m█[0m[38;2;122;91;47m█[0m[38;2;127;97;55m█[0m[38;2;148;124;83m█[0m[38;2;160;143;107m█[0m[38;2;118;100;69m█[0m[38;2;96;76;49m█[0m[38;2;91;71;42m█[0m[38;2;90;69;40m█[0m[38;2;96;73;43m█[0m[38;2;107;83;52m█[0m[38;2;113;88;54m█[0m[38;2;121;94;57m█[0m[38;2;97;72;39m█[0m[38;2;66;46;25m█[0m[38;2;39;23;9m█[0m[38;2;30;16;6m█[0m[38;2;27;14;7m█[0m[38;2;21;10;5m█[0m[38;2;18;10;3m█[0m[38;2;16;7;4m█[0m[38;2;16;7;5m█[0m[38;2;13;7;4m█[0m[38;2;11;5;2m█[0m[38;2;13;5;3m█[0m[38;2;13;4;2m█[0m[38;2;14;4;2m█[0m[38;2;14;6;2m█[0m[38;2;30;20;10m█[0m[38;2;73;57;33m█[0m[38;2;115;91;53m█[0m[38;2;132;104;60m█[0m[38;2;136;112;67m█[0m[38;2;137;115;70m█[0m[38;2;145;126;94m█[0m[38;2;126;121;106m█[0m[38;2;61;68;66m█[0m[38;2;24;38;43m█[0m[38;2;21;37;45m█[0m");
//$display("[38;2;84;85;80m█[0m[38;2;77;78;73m█[0m[38;2;57;58;52m█[0m[38;2;76;77;70m█[0m[38;2;69;70;63m█[0m[38;2;49;51;45m█[0m[38;2;65;66;62m█[0m[38;2;74;71;61m█[0m[38;2;78;68;46m█[0m[38;2;159;142;109m█[0m[38;2;227;212;172m█[0m[38;2;232;218;176m█[0m[38;2;227;211;172m█[0m[38;2;218;201;156m█[0m[38;2;202;181;133m█[0m[38;2;188;162;115m█[0m[38;2;182;156;108m█[0m[38;2;149;122;77m█[0m[38;2;123;94;54m█[0m[38;2;118;88;52m█[0m[38;2;113;84;50m█[0m[38;2;93;67;32m█[0m[38;2;97;71;37m█[0m[38;2;100;73;39m█[0m[38;2;92;69;32m█[0m[38;2;87;63;30m█[0m[38;2;83;60;28m█[0m[38;2;88;65;33m█[0m[38;2;90;66;33m█[0m[38;2;93;66;33m█[0m[38;2;94;68;34m█[0m[38;2;98;73;38m█[0m[38;2;91;67;33m█[0m[38;2;94;69;35m█[0m[38;2;97;72;38m█[0m[38;2;100;75;39m█[0m[38;2;102;76;38m█[0m[38;2;107;79;40m█[0m[38;2;110;82;43m█[0m[38;2;107;77;39m█[0m[38;2;113;81;43m█[0m[38;2;115;83;44m█[0m[38;2;120;88;49m█[0m[38;2;105;77;39m█[0m[38;2;134;112;75m█[0m[38;2;140;119;83m█[0m[38;2;139;118;81m█[0m[38;2;152;129;89m█[0m[38;2;144;118;76m█[0m[38;2;134;105;63m█[0m[38;2;138;111;70m█[0m[38;2;132;106;66m█[0m[38;2;115;89;53m█[0m[38;2;116;92;55m█[0m[38;2;107;83;49m█[0m[38;2;85;63;32m█[0m[38;2;66;45;21m█[0m[38;2;42;25;10m█[0m[38;2;21;9;2m█[0m[38;2;13;5;1m█[0m[38;2;15;10;2m█[0m[38;2;16;7;5m█[0m[38;2;18;8;6m█[0m[38;2;12;5;2m█[0m[38;2;10;5;2m█[0m[38;2;11;3;2m█[0m[38;2;15;5;3m█[0m[38;2;13;6;3m█[0m[38;2;12;7;3m█[0m[38;2;10;4;4m█[0m[38;2;15;4;2m█[0m[38;2;53;37;16m█[0m[38;2;94;72;35m█[0m[38;2;118;93;51m█[0m[38;2;130;107;64m█[0m[38;2;136;115;77m█[0m[38;2;130;117;87m█[0m[38;2;102;98;81m█[0m[38;2;44;50;46m█[0m[38;2;15;26;32m█[0m");
//$display("[38;2;51;56;50m█[0m[38;2;54;57;52m█[0m[38;2;66;68;63m█[0m[38;2;70;73;67m█[0m[38;2;67;69;63m█[0m[38;2;60;62;57m█[0m[38;2;54;54;50m█[0m[38;2;71;65;51m█[0m[38;2;109;96;66m█[0m[38;2;192;178;140m█[0m[38;2;233;220;181m█[0m[38;2;232;218;179m█[0m[38;2;222;206;165m█[0m[38;2;215;198;151m█[0m[38;2;211;190;143m█[0m[38;2;184;161;114m█[0m[38;2;149;122;78m█[0m[38;2;122;96;55m█[0m[38;2;123;95;56m█[0m[38;2;117;89;50m█[0m[38;2;107;79;41m█[0m[38;2;104;77;40m█[0m[38;2;103;77;39m█[0m[38;2;106;82;45m█[0m[38;2;101;78;42m█[0m[38;2;93;70;34m█[0m[38;2;88;65;30m█[0m[38;2;90;68;34m█[0m[38;2;93;71;35m█[0m[38;2;98;73;34m█[0m[38;2;103;76;35m█[0m[38;2;107;79;38m█[0m[38;2;103;77;37m█[0m[38;2;103;80;40m█[0m[38;2;109;85;47m█[0m[38;2;105;81;43m█[0m[38;2;104;79;39m█[0m[38;2;110;83;44m█[0m[38;2;112;83;44m█[0m[38;2;107;78;40m█[0m[38;2;107;78;40m█[0m[38;2;106;78;39m█[0m[38;2;108;81;44m█[0m[38;2;96;69;38m█[0m[38;2;88;64;35m█[0m[38;2;93;71;43m█[0m[38;2;88;66;37m█[0m[38;2;79;55;26m█[0m[38;2;78;53;24m█[0m[38;2;87;61;33m█[0m[38;2;93;68;37m█[0m[38;2;98;74;40m█[0m[38;2;104;83;47m█[0m[38;2;106;84;47m█[0m[38;2;110;82;46m█[0m[38;2;109;82;45m█[0m[38;2;87;63;35m█[0m[38;2;50;32;17m█[0m[38;2;21;10;5m█[0m[38;2;13;6;3m█[0m[38;2;13;7;3m█[0m[38;2;13;5;3m█[0m[38;2;15;6;4m█[0m[38;2;9;3;1m█[0m[38;2;9;5;2m█[0m[38;2;10;5;2m█[0m[38;2;14;6;4m█[0m[38;2;15;7;3m█[0m[38;2;15;9;3m█[0m[38;2;14;9;4m█[0m[38;2;14;6;5m█[0m[38;2;20;8;3m█[0m[38;2;42;25;11m█[0m[38;2;60;39;16m█[0m[38;2;85;62;29m█[0m[38;2;103;79;41m█[0m[38;2;111;86;46m█[0m[38;2;117;98;62m█[0m[38;2;100;89;63m█[0m[38;2;60;58;44m█[0m");
//$display("[38;2;39;41;36m█[0m[38;2;29;30;25m█[0m[38;2;46;47;45m█[0m[38;2;51;51;50m█[0m[38;2;54;55;53m█[0m[38;2;52;54;51m█[0m[38;2;50;48;39m█[0m[38;2;76;65;42m█[0m[38;2;144;129;89m█[0m[38;2;219;205;160m█[0m[38;2;233;218;176m█[0m[38;2;222;207;164m█[0m[38;2;222;206;160m█[0m[38;2;218;199;151m█[0m[38;2;193;169;121m█[0m[38;2;154;128;82m█[0m[38;2;129;103;60m█[0m[38;2;126;103;62m█[0m[38;2;120;96;57m█[0m[38;2;112;88;49m█[0m[38;2;110;86;48m█[0m[38;2;109;85;46m█[0m[38;2;110;87;49m█[0m[38;2;112;88;53m█[0m[38;2;106;82;49m█[0m[38;2;99;76;42m█[0m[38;2;101;77;42m█[0m[38;2;101;78;43m█[0m[38;2;102;78;43m█[0m[38;2;103;79;43m█[0m[38;2;109;83;45m█[0m[38;2;109;85;44m█[0m[38;2;110;85;47m█[0m[38;2;108;82;46m█[0m[38;2;118;91;55m█[0m[38;2;113;86;49m█[0m[38;2;110;85;45m█[0m[38;2;111;84;45m█[0m[38;2;112;83;44m█[0m[38;2;108;80;41m█[0m[38;2;110;86;45m█[0m[38;2;110;87;46m█[0m[38;2;105;82;42m█[0m[38;2;103;77;40m█[0m[38;2;103;78;40m█[0m[38;2;155;131;90m█[0m[38;2;150;126;84m█[0m[38;2;112;88;49m█[0m[38;2;114;90;51m█[0m[38;2;120;95;57m█[0m[38;2;121;96;56m█[0m[38;2;124;98;56m█[0m[38;2;123;95;55m█[0m[38;2;118;89;51m█[0m[38;2;115;86;51m█[0m[38;2;101;75;40m█[0m[38;2;74;51;25m█[0m[38;2;46;26;13m█[0m[38;2;24;12;5m█[0m[38;2;14;7;2m█[0m[38;2;15;9;4m█[0m[38;2;16;7;3m█[0m[38;2;17;4;2m█[0m[38;2;13;4;3m█[0m[38;2;10;3;1m█[0m[38;2;12;5;3m█[0m[38;2;12;3;2m█[0m[38;2;14;3;2m█[0m[38;2;18;8;6m█[0m[38;2;15;8;3m█[0m[38;2;16;10;6m█[0m[38;2;20;11;7m█[0m[38;2;27;15;7m█[0m[38;2;34;19;6m█[0m[38;2;49;30;10m█[0m[38;2;71;48;21m█[0m[38;2;80;53;21m█[0m[38;2;92;65;28m█[0m[38;2;107;82;39m█[0m[38;2;114;94;56m█[0m");
//$display("[38;2;48;48;43m█[0m[38;2;53;51;44m█[0m[38;2;56;54;47m█[0m[38;2;54;51;44m█[0m[38;2;37;36;28m█[0m[38;2;29;28;21m█[0m[38;2;43;35;18m█[0m[38;2;98;81;49m█[0m[38;2;186;169;127m█[0m[38;2;230;216;172m█[0m[38;2;225;211;165m█[0m[38;2;226;209;162m█[0m[38;2;215;195;146m█[0m[38;2;186;162;111m█[0m[38;2;165;138;91m█[0m[38;2;149;123;80m█[0m[38;2;141;116;75m█[0m[38;2;124;101;62m█[0m[38;2;124;102;65m█[0m[38;2;112;90;55m█[0m[38;2;110;87;51m█[0m[38;2;108;84;49m█[0m[38;2;115;92;57m█[0m[38;2;106;83;49m█[0m[38;2;102;79;47m█[0m[38;2;105;82;49m█[0m[38;2;110;87;53m█[0m[38;2;112;89;54m█[0m[38;2;110;86;51m█[0m[38;2;117;93;57m█[0m[38;2;121;93;57m█[0m[38;2;119;94;53m█[0m[38;2;120;94;57m█[0m[38;2;117;91;56m█[0m[38;2;120;95;60m█[0m[38;2;118;92;57m█[0m[38;2;117;91;55m█[0m[38;2;118;90;51m█[0m[38;2;114;88;48m█[0m[38;2;114;89;49m█[0m[38;2;120;96;55m█[0m[38;2;123;101;59m█[0m[38;2;109;86;46m█[0m[38;2;95;70;34m█[0m[38;2;93;69;33m█[0m[38;2;117;90;52m█[0m[38;2;132;102;63m█[0m[38;2;140;108;68m█[0m[38;2;128;96;55m█[0m[38;2;130;99;57m█[0m[38;2;133;103;61m█[0m[38;2;142;112;69m█[0m[38;2;128;98;55m█[0m[38;2;116;87;45m█[0m[38;2;110;80;44m█[0m[38;2;105;76;40m█[0m[38;2;88;62;30m█[0m[38;2;67;45;20m█[0m[38;2;44;27;10m█[0m[38;2;23;11;4m█[0m[38;2;19;10;5m█[0m[38;2;22;13;7m█[0m[38;2;21;11;7m█[0m[38;2;19;8;5m█[0m[38;2;21;9;4m█[0m[38;2;19;7;2m█[0m[38;2;17;5;2m█[0m[38;2;17;8;6m█[0m[38;2;16;8;6m█[0m[38;2;17;9;5m█[0m[38;2;14;7;3m█[0m[38;2;19;11;6m█[0m[38;2;26;12;5m█[0m[38;2;40;22;13m█[0m[38;2;45;23;11m█[0m[38;2;48;25;9m█[0m[38;2;61;36;18m█[0m[38;2;67;43;21m█[0m[38;2;77;51;21m█[0m[38;2;93;68;34m█[0m");
//$display("[38;2;35;36;31m█[0m[38;2;43;44;38m█[0m[38;2;51;50;43m█[0m[38;2;52;51;42m█[0m[38;2;36;34;25m█[0m[38;2;33;29;14m█[0m[38;2;64;52;27m█[0m[38;2;137;121;82m█[0m[38;2;217;202;159m█[0m[38;2;229;215;173m█[0m[38;2;226;212;166m█[0m[38;2;213;194;146m█[0m[38;2;195;172;121m█[0m[38;2;173;147;97m█[0m[38;2;156;128;80m█[0m[38;2;145;120;77m█[0m[38;2;123;99;58m█[0m[38;2;122;99;62m█[0m[38;2;126;104;69m█[0m[38;2;111;88;54m█[0m[38;2;111;87;54m█[0m[38;2;105;81;49m█[0m[38;2;100;78;46m█[0m[38;2;105;82;50m█[0m[38;2;106;84;52m█[0m[38;2;110;89;56m█[0m[38;2;112;91;56m█[0m[38;2;116;94;59m█[0m[38;2;118;94;59m█[0m[38;2;124;100;63m█[0m[38;2;125;99;62m█[0m[38;2;122;97;56m█[0m[38;2;127;101;62m█[0m[38;2;124;99;64m█[0m[38;2;120;94;61m█[0m[38;2;124;99;65m█[0m[38;2;123;97;62m█[0m[38;2;123;96;58m█[0m[38;2;123;97;58m█[0m[38;2;119;95;54m█[0m[38;2;126;102;61m█[0m[38;2;123;100;59m█[0m[38;2;119;96;56m█[0m[38;2;105;81;45m█[0m[38;2;84;60;29m█[0m[38;2;74;52;22m█[0m[38;2;78;57;26m█[0m[38;2;90;68;34m█[0m[38;2;97;75;38m█[0m[38;2;100;78;38m█[0m[38;2;107;85;43m█[0m[38;2;113;87;47m█[0m[38;2;109;83;41m█[0m[38;2;111;86;43m█[0m[38;2;120;89;49m█[0m[38;2;119;86;46m█[0m[38;2;106;77;38m█[0m[38;2;88;63;29m█[0m[38;2;62;40;18m█[0m[38;2;40;23;12m█[0m[38;2;22;10;6m█[0m[38;2;21;9;7m█[0m[38;2;22;12;5m█[0m[38;2;27;11;3m█[0m[38;2;32;13;5m█[0m[38;2;38;20;11m█[0m[38;2;29;14;7m█[0m[38;2;19;7;4m█[0m[38;2;16;6;3m█[0m[38;2;16;7;3m█[0m[38;2;15;6;2m█[0m[38;2;24;13;9m█[0m[38;2;30;16;10m█[0m[38;2;37;20;11m█[0m[38;2;49;27;18m█[0m[38;2;47;24;15m█[0m[38;2;45;26;17m█[0m[38;2;41;24;15m█[0m[38;2;41;23;8m█[0m[38;2;58;37;15m█[0m");
//$display("[38;2;39;39;34m█[0m[38;2;41;41;36m█[0m[38;2;27;26;22m█[0m[38;2;26;26;21m█[0m[38;2;28;24;16m█[0m[38;2;50;40;19m█[0m[38;2;108;93;58m█[0m[38;2;192;178;135m█[0m[38;2;227;213;169m█[0m[38;2;222;209;164m█[0m[38;2;216;198;151m█[0m[38;2;196;174;126m█[0m[38;2;191;165;115m█[0m[38;2;167;140;92m█[0m[38;2;158;132;87m█[0m[38;2;140;116;73m█[0m[38;2;131;108;67m█[0m[38;2;136;113;78m█[0m[38;2;114;92;61m█[0m[38;2;105;84;53m█[0m[38;2;101;80;49m█[0m[38;2;96;74;46m█[0m[38;2;101;81;52m█[0m[38;2;109;89;60m█[0m[38;2;110;89;60m█[0m[38;2;113;92;62m█[0m[38;2;115;91;61m█[0m[38;2;118;95;60m█[0m[38;2;124;102;68m█[0m[38;2;125;101;68m█[0m[38;2;123;100;63m█[0m[38;2;129;105;66m█[0m[38;2;129;103;66m█[0m[38;2;132;106;69m█[0m[38;2;130;104;67m█[0m[38;2;129;102;66m█[0m[38;2;131;104;66m█[0m[38;2;128;103;63m█[0m[38;2;129;104;64m█[0m[38;2;129;104;64m█[0m[38;2;135;110;70m█[0m[38;2;137;112;72m█[0m[38;2;130;105;65m█[0m[38;2;119;95;55m█[0m[38;2;109;84;48m█[0m[38;2;89;66;33m█[0m[38;2;70;48;19m█[0m[38;2;81;60;33m█[0m[38;2;82;63;36m█[0m[38;2;91;73;44m█[0m[38;2;88;69;38m█[0m[38;2;92;68;37m█[0m[38;2;91;66;33m█[0m[38;2;97;73;35m█[0m[38;2;117;89;48m█[0m[38;2;129;99;54m█[0m[38;2;125;94;48m█[0m[38;2;106;77;38m█[0m[38;2;82;54;27m█[0m[38;2;63;39;21m█[0m[38;2;32;14;6m█[0m[38;2;28;9;3m█[0m[38;2;52;31;15m█[0m[38;2;59;35;13m█[0m[38;2;74;49;24m█[0m[38;2;69;43;22m█[0m[38;2;45;21;9m█[0m[38;2;37;19;9m█[0m[38;2;28;10;3m█[0m[38;2;25;10;6m█[0m[38;2;17;7;3m█[0m[38;2;15;6;1m█[0m[38;2;31;15;8m█[0m[38;2;45;25;13m█[0m[38;2;51;31;15m█[0m[38;2;58;36;22m█[0m[38;2;53;33;23m█[0m[38;2;31;15;8m█[0m[38;2;27;13;7m█[0m[38;2;36;18;10m█[0m");
//$display("[38;2;79;79;71m█[0m[38;2;57;57;49m█[0m[38;2;24;24;18m█[0m[38;2;24;22;16m█[0m[38;2;42;33;20m█[0m[38;2;91;78;48m█[0m[38;2;168;152;109m█[0m[38;2;216;199;154m█[0m[38;2;226;209;163m█[0m[38;2;216;198;150m█[0m[38;2;205;184;136m█[0m[38;2;189;168;117m█[0m[38;2;180;157;106m█[0m[38;2;180;156;109m█[0m[38;2;158;134;91m█[0m[38;2;131;109;69m█[0m[38;2;129;107;70m█[0m[38;2;113;91;58m█[0m[38;2;103;83;51m█[0m[38;2;103;84;52m█[0m[38;2;96;78;48m█[0m[38;2;102;83;56m█[0m[38;2;102;82;56m█[0m[38;2;108;88;61m█[0m[38;2;116;95;68m█[0m[38;2;117;97;69m█[0m[38;2;120;96;67m█[0m[38;2;126;103;72m█[0m[38;2;134;113;81m█[0m[38;2;131;108;77m█[0m[38;2;133;109;75m█[0m[38;2;130;105;71m█[0m[38;2;137;109;73m█[0m[38;2;137;110;72m█[0m[38;2;136;110;71m█[0m[38;2;138;111;73m█[0m[38;2;136;111;71m█[0m[38;2;136;111;71m█[0m[38;2;136;111;71m█[0m[38;2;138;113;72m█[0m[38;2;142;116;77m█[0m[38;2;142;116;77m█[0m[38;2;138;113;74m█[0m[38;2;130;106;65m█[0m[38;2;129;104;64m█[0m[38;2;120;97;57m█[0m[38;2;93;71;35m█[0m[38;2;80;58;26m█[0m[38;2;73;52;22m█[0m[38;2;70;49;23m█[0m[38;2;72;50;27m█[0m[38;2;83;61;39m█[0m[38;2;77;56;31m█[0m[38;2;78;57;28m█[0m[38;2;100;75;41m█[0m[38;2;118;89;48m█[0m[38;2;124;93;49m█[0m[38;2;125;95;49m█[0m[38;2;116;84;43m█[0m[38;2;94;66;30m█[0m[38;2;71;45;17m█[0m[38;2;84;57;27m█[0m[38;2;104;75;40m█[0m[38;2;113;84;44m█[0m[38;2;104;72;34m█[0m[38;2;91;57;26m█[0m[38;2;83;52;27m█[0m[38;2;66;41;19m█[0m[38;2;48;27;10m█[0m[38;2;40;22;9m█[0m[38;2;40;24;12m█[0m[38;2;42;25;14m█[0m[38;2;37;20;10m█[0m[38;2;42;22;12m█[0m[38;2;57;37;16m█[0m[38;2;70;48;29m█[0m[38;2;56;33;23m█[0m[38;2;43;24;17m█[0m[38;2;31;18;10m█[0m[38;2;30;16;10m█[0m");
//$display("[38;2;81;79;70m█[0m[38;2;62;61;51m█[0m[38;2;21;22;12m█[0m[38;2;30;25;16m█[0m[38;2;69;54;34m█[0m[38;2;129;111;73m█[0m[38;2;197;177;133m█[0m[38;2;226;209;162m█[0m[38;2;219;202;153m█[0m[38;2;211;189;139m█[0m[38;2;201;178;127m█[0m[38;2;190;168;117m█[0m[38;2;173;149;103m█[0m[38;2;148;124;81m█[0m[38;2;126;103;61m█[0m[38;2;121;99;61m█[0m[38;2;120;97;62m█[0m[38;2;116;94;61m█[0m[38;2;106;86;53m█[0m[38;2;94;75;43m█[0m[38;2;96;77;47m█[0m[38;2;99;80;50m█[0m[38;2;98;79;50m█[0m[38;2;105;85;56m█[0m[38;2;115;95;64m█[0m[38;2;121;100;70m█[0m[38;2;124;99;70m█[0m[38;2;133;110;80m█[0m[38;2;138;115;84m█[0m[38;2;133;110;78m█[0m[38;2;133;110;76m█[0m[38;2;135;111;76m█[0m[38;2;136;110;74m█[0m[38;2;135;109;72m█[0m[38;2;139;113;77m█[0m[38;2;140;116;79m█[0m[38;2;142;116;78m█[0m[38;2;143;119;78m█[0m[38;2;144;120;80m█[0m[38;2;144;121;80m█[0m[38;2;149;124;86m█[0m[38;2;146;122;85m█[0m[38;2;144;121;83m█[0m[38;2;141;118;79m█[0m[38;2;138;113;74m█[0m[38;2;137;113;75m█[0m[38;2;122;97;61m█[0m[38;2;105;81;46m█[0m[38;2;101;77;41m█[0m[38;2;89;66;31m█[0m[38;2;79;57;26m█[0m[38;2;75;52;25m█[0m[38;2;73;53;27m█[0m[38;2;61;41;16m█[0m[38;2;66;41;16m█[0m[38;2;85;57;27m█[0m[38;2;99;70;36m█[0m[38;2;114;86;44m█[0m[38;2;122;91;48m█[0m[38;2;120;88;46m█[0m[38;2;120;89;46m█[0m[38;2;119;88;44m█[0m[38;2;128;96;51m█[0m[38;2;131;99;54m█[0m[38;2;113;79;38m█[0m[38;2;109;74;36m█[0m[38;2;101;70;34m█[0m[38;2;83;56;25m█[0m[38;2;72;46;25m█[0m[38;2;56;33;13m█[0m[38;2;74;49;29m█[0m[38;2;68;43;24m█[0m[38;2;62;38;21m█[0m[38;2;53;28;12m█[0m[38;2;64;39;19m█[0m[38;2;59;37;17m█[0m[38;2;48;26;11m█[0m[38;2;49;28;16m█[0m[38;2;37;21;12m█[0m[38;2;28;12;4m█[0m");
$display("\033[0;32m \033[5m    //   ) )     // | |     //   ) )     //   ) )\033[m");
$display("\033[0;32m \033[5m   //___/ /     //__| |    ((           ((\033[m");
$display("\033[0;32m \033[5m  / ____ /     / ___  |      \\           \\\033[m");
$display("\033[0;32m \033[5m //           //    | |        ) )          ) )\033[m");
$display("\033[0;32m \033[5m//           //     | | ((___ / /    ((___ / /\033[m");
$display("**************************************************");
$display("                  Congratulations!                ");
$display("              execution cycles = %7d", total_lat);
$display("              clock period = %4fns", CYCLE);
$display("**************************************************");
end endtask

task display_fail; begin
$display("[38;2;184;177;171m█[0m[38;2;184;177;171m█[0m[38;2;185;178;172m█[0m[38;2;185;178;172m█[0m[38;2;186;179;173m█[0m[38;2;187;180;174m█[0m[38;2;187;181;175m█[0m[38;2;187;181;175m█[0m[38;2;188;182;176m█[0m[38;2;188;183;177m█[0m[38;2;188;183;177m█[0m[38;2;188;183;177m█[0m[38;2;189;184;178m█[0m[38;2;189;184;178m█[0m[38;2;189;184;178m█[0m[38;2;189;184;178m█[0m[38;2;189;184;178m█[0m[38;2;189;184;178m█[0m[38;2;190;185;178m█[0m[38;2;190;185;178m█[0m[38;2;190;185;179m█[0m[38;2;190;184;179m█[0m[38;2;189;183;178m█[0m[38;2;188;183;176m█[0m[38;2;188;183;176m█[0m[38;2;188;183;177m█[0m[38;2;188;183;175m█[0m[38;2;188;184;174m█[0m[38;2;188;183;174m█[0m[38;2;187;183;175m█[0m[38;2;187;183;174m█[0m[38;2;187;183;175m█[0m[38;2;187;183;174m█[0m[38;2;186;182;174m█[0m[38;2;186;182;174m█[0m[38;2;186;182;173m█[0m[38;2;186;182;174m█[0m[38;2;186;181;174m█[0m[38;2;186;181;174m█[0m[38;2;185;181;171m█[0m[38;2;184;181;169m█[0m[38;2;184;181;169m█[0m[38;2;183;182;168m█[0m[38;2;184;181;169m█[0m[38;2;183;180;169m█[0m[38;2;183;179;167m█[0m[38;2;184;178;166m█[0m[38;2;184;177;166m█[0m[38;2;183;177;166m█[0m[38;2;183;176;166m█[0m[38;2;182;176;166m█[0m[38;2;182;175;167m█[0m[38;2;181;174;168m█[0m[38;2;181;174;168m█[0m[38;2;181;173;167m█[0m[38;2;180;173;167m█[0m[38;2;178;172;166m█[0m[38;2;177;172;166m█[0m[38;2;177;172;166m█[0m[38;2;176;171;165m█[0m");
$display("[38;2;187;180;174m█[0m[38;2;187;180;174m█[0m[38;2;188;181;175m█[0m[38;2;188;182;176m█[0m[38;2;189;183;177m█[0m[38;2;189;184;178m█[0m[38;2;190;185;179m█[0m[38;2;190;185;179m█[0m[38;2;191;186;180m█[0m[38;2;192;187;181m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;194;189;183m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;187;181m█[0m[38;2;193;187;181m█[0m[38;2;193;188;182m█[0m[38;2;192;187;181m█[0m[38;2;192;187;180m█[0m[38;2;192;187;179m█[0m[38;2;191;187;180m█[0m[38;2;191;186;180m█[0m[38;2;191;186;180m█[0m[38;2;191;186;180m█[0m[38;2;190;185;179m█[0m[38;2;190;185;179m█[0m[38;2;190;185;179m█[0m[38;2;190;185;179m█[0m[38;2;189;184;178m█[0m[38;2;189;184;178m█[0m[38;2;189;184;177m█[0m[38;2;189;183;174m█[0m[38;2;188;183;172m█[0m[38;2;187;183;174m█[0m[38;2;187;183;173m█[0m[38;2;186;181;173m█[0m[38;2;185;180;174m█[0m[38;2;184;180;172m█[0m[38;2;185;179;172m█[0m[38;2;186;179;170m█[0m[38;2;185;179;169m█[0m[38;2;183;178;169m█[0m[38;2;183;177;170m█[0m[38;2;183;176;169m█[0m[38;2;183;176;169m█[0m[38;2;182;175;169m█[0m[38;2;181;175;169m█[0m[38;2;181;174;168m█[0m[38;2;180;173;167m█[0m[38;2;179;173;167m█[0m[38;2;178;173;167m█[0m[38;2;178;173;167m█[0m");
$display("[38;2;189;183;177m█[0m[38;2;190;184;178m█[0m[38;2;191;185;179m█[0m[38;2;191;186;180m█[0m[38;2;192;187;181m█[0m[38;2;193;188;182m█[0m[38;2;194;189;183m█[0m[38;2;194;189;183m█[0m[38;2;195;190;184m█[0m[38;2;196;191;185m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;198;193;187m█[0m[38;2;198;193;187m█[0m[38;2;198;193;187m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;196;191;185m█[0m[38;2;196;192;186m█[0m[38;2;196;191;185m█[0m[38;2;196;191;185m█[0m[38;2;196;191;185m█[0m[38;2;196;191;185m█[0m[38;2;195;190;185m█[0m[38;2;195;190;184m█[0m[38;2;195;190;184m█[0m[38;2;195;190;184m█[0m[38;2;194;189;183m█[0m[38;2;194;189;183m█[0m[38;2;193;188;182m█[0m[38;2;193;188;183m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;193;188;182m█[0m[38;2;192;187;181m█[0m[38;2;191;187;179m█[0m[38;2;192;186;178m█[0m[38;2;192;185;178m█[0m[38;2;191;185;177m█[0m[38;2;189;185;176m█[0m[38;2;188;183;176m█[0m[38;2;187;182;176m█[0m[38;2;186;181;175m█[0m[38;2;186;181;175m█[0m[38;2;187;180;173m█[0m[38;2;186;180;172m█[0m[38;2;186;180;173m█[0m[38;2;186;179;173m█[0m[38;2;186;179;172m█[0m[38;2;184;178;172m█[0m[38;2;182;177;171m█[0m[38;2;181;176;170m█[0m[38;2;182;175;169m█[0m[38;2;182;175;169m█[0m[38;2;182;175;169m█[0m[38;2;180;174;168m█[0m[38;2;179;174;168m█[0m");
$display("[38;2;192;187;181m█[0m[38;2;194;188;182m█[0m[38;2;194;189;183m█[0m[38;2;195;190;184m█[0m[38;2;195;190;184m█[0m[38;2;196;191;185m█[0m[38;2;198;193;187m█[0m[38;2;198;193;187m█[0m[38;2;200;195;189m█[0m[38;2;200;195;189m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;200;195;189m█[0m[38;2;200;195;189m█[0m[38;2;200;195;189m█[0m[38;2;199;194;188m█[0m[38;2;199;194;188m█[0m[38;2;199;194;188m█[0m[38;2;199;194;188m█[0m[38;2;199;194;188m█[0m[38;2;199;194;188m█[0m[38;2;199;194;188m█[0m[38;2;198;193;187m█[0m[38;2;198;193;187m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;197;192;186m█[0m[38;2;198;192;186m█[0m[38;2;197;191;185m█[0m[38;2;194;189;183m█[0m[38;2;192;187;181m█[0m[38;2;190;184;178m█[0m[38;2;188;183;176m█[0m[38;2;187;181;175m█[0m[38;2;186;180;174m█[0m[38;2;186;180;174m█[0m[38;2;187;180;174m█[0m[38;2;187;180;174m█[0m[38;2;187;180;174m█[0m[38;2;185;179;173m█[0m[38;2;184;178;172m█[0m[38;2;183;178;172m█[0m[38;2;183;177;171m█[0m[38;2;184;177;171m█[0m[38;2;183;176;170m█[0m[38;2;181;176;170m█[0m[38;2;180;175;169m█[0m[38;2;180;175;169m█[0m");
$display("[38;2;197;192;186m█[0m[38;2;197;193;187m█[0m[38;2;198;193;187m█[0m[38;2;199;194;188m█[0m[38;2;200;195;189m█[0m[38;2;201;196;190m█[0m[38;2;202;197;191m█[0m[38;2;203;198;192m█[0m[38;2;204;199;193m█[0m[38;2;205;200;194m█[0m[38;2;206;201;195m█[0m[38;2;205;200;194m█[0m[38;2;205;200;194m█[0m[38;2;205;200;194m█[0m[38;2;205;200;194m█[0m[38;2;205;200;194m█[0m[38;2;204;199;193m█[0m[38;2;204;199;193m█[0m[38;2;204;199;193m█[0m[38;2;203;198;192m█[0m[38;2;203;198;192m█[0m[38;2;203;198;192m█[0m[38;2;203;198;192m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;201;196;190m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;205;200;194m█[0m[38;2;206;201;195m█[0m[38;2;197;192;185m█[0m[38;2;186;181;175m█[0m[38;2;179;175;169m█[0m[38;2;177;172;166m█[0m[38;2;179;174;168m█[0m[38;2;184;180;174m█[0m[38;2;188;185;179m█[0m[38;2;189;186;182m█[0m[38;2;190;186;182m█[0m[38;2;189;185;180m█[0m[38;2;187;183;176m█[0m[38;2;185;180;173m█[0m[38;2;184;179;172m█[0m[38;2;185;179;173m█[0m[38;2;185;180;174m█[0m[38;2;186;179;173m█[0m[38;2;186;179;173m█[0m[38;2;186;179;173m█[0m[38;2;186;179;173m█[0m[38;2;184;178;172m█[0m[38;2;182;177;171m█[0m[38;2;181;176;170m█[0m[38;2;182;177;171m█[0m");
$display("[38;2;200;195;189m█[0m[38;2;201;196;190m█[0m[38;2;203;198;192m█[0m[38;2;204;199;193m█[0m[38;2;205;200;194m█[0m[38;2;206;201;195m█[0m[38;2;207;202;196m█[0m[38;2;208;203;197m█[0m[38;2;209;204;198m█[0m[38;2;210;205;199m█[0m[38;2;210;205;199m█[0m[38;2;210;205;199m█[0m[38;2;210;205;199m█[0m[38;2;209;204;198m█[0m[38;2;209;204;198m█[0m[38;2;209;204;198m█[0m[38;2;209;204;198m█[0m[38;2;208;203;197m█[0m[38;2;208;203;197m█[0m[38;2;207;202;196m█[0m[38;2;207;202;196m█[0m[38;2;207;202;196m█[0m[38;2;206;201;195m█[0m[38;2;206;201;195m█[0m[38;2;206;201;195m█[0m[38;2;205;200;194m█[0m[38;2;205;200;194m█[0m[38;2;204;199;193m█[0m[38;2;204;199;193m█[0m[38;2;204;199;193m█[0m[38;2;204;199;193m█[0m[38;2;205;200;194m█[0m[38;2;205;200;194m█[0m[38;2;206;201;195m█[0m[38;2;210;205;199m█[0m[38;2;180;176;170m█[0m[38;2;133;130;123m█[0m[38;2;124;120;113m█[0m[38;2;127;123;116m█[0m[38;2;134;129;123m█[0m[38;2;143;138;134m█[0m[38;2;153;150;148m█[0m[38;2;169;169;168m█[0m[38;2;193;193;194m█[0m[38;2;197;197;198m█[0m[38;2;199;200;201m█[0m[38;2;202;203;205m█[0m[38;2;203;204;206m█[0m[38;2;202;201;202m█[0m[38;2;197;196;195m█[0m[38;2;190;188;184m█[0m[38;2;185;180;174m█[0m[38;2;187;181;175m█[0m[38;2;188;182;176m█[0m[38;2;188;181;175m█[0m[38;2;186;181;175m█[0m[38;2;185;180;174m█[0m[38;2;185;180;174m█[0m[38;2;184;179;173m█[0m[38;2;183;178;172m█[0m");
$display("[38;2;202;197;191m█[0m[38;2;204;199;193m█[0m[38;2;205;200;194m█[0m[38;2;206;201;195m█[0m[38;2;207;202;196m█[0m[38;2;208;203;197m█[0m[38;2;209;204;198m█[0m[38;2;210;205;199m█[0m[38;2;211;206;200m█[0m[38;2;211;206;200m█[0m[38;2;212;207;201m█[0m[38;2;213;208;202m█[0m[38;2;213;208;202m█[0m[38;2;213;208;202m█[0m[38;2;213;208;202m█[0m[38;2;213;208;202m█[0m[38;2;213;208;202m█[0m[38;2;212;208;201m█[0m[38;2;212;207;201m█[0m[38;2;211;206;200m█[0m[38;2;211;206;200m█[0m[38;2;211;206;200m█[0m[38;2;211;206;200m█[0m[38;2;210;205;199m█[0m[38;2;210;205;199m█[0m[38;2;209;204;198m█[0m[38;2;209;204;198m█[0m[38;2;208;203;197m█[0m[38;2;208;203;197m█[0m[38;2;208;203;197m█[0m[38;2;208;203;197m█[0m[38;2;208;203;197m█[0m[38;2;209;204;198m█[0m[38;2;210;205;200m█[0m[38;2;197;193;187m█[0m[38;2;160;154;147m█[0m[38;2;151;143;137m█[0m[38;2;161;155;148m█[0m[38;2;169;164;158m█[0m[38;2;179;175;169m█[0m[38;2;189;186;183m█[0m[38;2;196;199;198m█[0m[38;2;203;203;203m█[0m[38;2;205;202;203m█[0m[38;2;206;208;212m█[0m[38;2;206;210;216m█[0m[38;2;206;210;218m█[0m[38;2;208;212;221m█[0m[38;2;210;215;223m█[0m[38;2;209;214;221m█[0m[38;2;207;211;216m█[0m[38;2;207;211;215m█[0m[38;2;178;177;175m█[0m[38;2;177;173;165m█[0m[38;2;187;182;175m█[0m[38;2;185;180;174m█[0m[38;2;185;180;174m█[0m[38;2;186;181;175m█[0m[38;2;185;180;174m█[0m[38;2;185;180;174m█[0m");
$display("[38;2;205;200;194m█[0m[38;2;205;200;194m█[0m[38;2;205;200;194m█[0m[38;2;206;201;195m█[0m[38;2;208;203;197m█[0m[38;2;209;204;198m█[0m[38;2;210;205;199m█[0m[38;2;210;205;199m█[0m[38;2;211;206;200m█[0m[38;2;212;207;201m█[0m[38;2;212;207;202m█[0m[38;2;213;208;202m█[0m[38;2;213;208;202m█[0m[38;2;213;208;202m█[0m[38;2;214;209;203m█[0m[38;2;214;208;202m█[0m[38;2;214;209;203m█[0m[38;2;214;210;204m█[0m[38;2;215;209;204m█[0m[38;2;214;209;203m█[0m[38;2;214;209;203m█[0m[38;2;214;209;203m█[0m[38;2;214;209;203m█[0m[38;2;214;209;203m█[0m[38;2;213;209;202m█[0m[38;2;213;208;202m█[0m[38;2;213;208;202m█[0m[38;2;212;207;201m█[0m[38;2;212;207;201m█[0m[38;2;211;206;200m█[0m[38;2;211;206;200m█[0m[38;2;212;206;200m█[0m[38;2;213;209;203m█[0m[38;2;188;186;181m█[0m[38;2;161;157;151m█[0m[38;2;160;152;146m█[0m[38;2;163;152;146m█[0m[38;2;166;156;151m█[0m[38;2;172;162;160m█[0m[38;2;175;170;171m█[0m[38;2;171;164;170m█[0m[38;2;171;117;105m█[0m[38;2;133;106;87m█[0m[38;2;92;82;70m█[0m[38;2;157;124;107m█[0m[38;2;201;200;207m█[0m[38;2;211;220;233m█[0m[38;2;208;220;232m█[0m[38;2;210;223;236m█[0m[38;2;211;224;237m█[0m[38;2;213;223;235m█[0m[38;2;207;214;224m█[0m[38;2;102;104;103m█[0m[38;2;167;173;176m█[0m[38;2;194;193;191m█[0m[38;2;183;177;171m█[0m[38;2;183;178;172m█[0m[38;2;185;180;174m█[0m[38;2;185;180;174m█[0m[38;2;185;180;174m█[0m");
$display("[38;2;208;203;197m█[0m[38;2;208;203;197m█[0m[38;2;207;202;196m█[0m[38;2;207;202;196m█[0m[38;2;207;202;196m█[0m[38;2;209;204;198m█[0m[38;2;209;204;198m█[0m[38;2;209;204;198m█[0m[38;2;209;204;198m█[0m[38;2;210;205;199m█[0m[38;2;210;205;200m█[0m[38;2;211;206;200m█[0m[38;2;211;206;200m█[0m[38;2;212;207;201m█[0m[38;2;212;207;202m█[0m[38;2;212;209;206m█[0m[38;2;213;212;210m█[0m[38;2;215;214;211m█[0m[38;2;215;211;206m█[0m[38;2;216;211;205m█[0m[38;2;216;211;205m█[0m[38;2;217;212;206m█[0m[38;2;218;213;207m█[0m[38;2;217;212;206m█[0m[38;2;217;212;206m█[0m[38;2;216;211;205m█[0m[38;2;216;211;205m█[0m[38;2;215;210;204m█[0m[38;2;215;210;203m█[0m[38;2;214;209;203m█[0m[38;2;214;209;203m█[0m[38;2;215;211;206m█[0m[38;2;200;196;177m█[0m[38;2;177;141;88m█[0m[38;2;178;103;61m█[0m[38;2;184;89;70m█[0m[38;2;194;83;80m█[0m[38;2;202;83;89m█[0m[38;2;199;87;97m█[0m[38;2;141;83;93m█[0m[38;2;116;110;127m█[0m[38;2;162;83;95m█[0m[38;2;99;48;51m█[0m[38;2;86;55;58m█[0m[38;2;138;106;97m█[0m[38;2;194;193;199m█[0m[38;2;211;221;235m█[0m[38;2;210;224;236m█[0m[38;2;224;238;244m█[0m[38;2;211;227;241m█[0m[38;2;206;220;234m█[0m[38;2;191;201;211m█[0m[38;2;199;207;220m█[0m[38;2;203;208;215m█[0m[38;2;188;185;181m█[0m[38;2;187;182;176m█[0m[38;2;190;185;179m█[0m[38;2;192;187;181m█[0m[38;2;193;188;181m█[0m[38;2;193;188;182m█[0m");
$display("[38;2;207;202;196m█[0m[38;2;207;202;196m█[0m[38;2;206;201;195m█[0m[38;2;205;200;194m█[0m[38;2;204;199;193m█[0m[38;2;205;200;194m█[0m[38;2;205;201;195m█[0m[38;2;206;201;195m█[0m[38;2;206;201;195m█[0m[38;2;206;201;195m█[0m[38;2;206;201;195m█[0m[38;2;206;201;195m█[0m[38;2;206;201;195m█[0m[38;2;207;202;196m█[0m[38;2;207;202;196m█[0m[38;2;208;206;203m█[0m[38;2;211;212;212m█[0m[38;2;215;216;217m█[0m[38;2;214;213;212m█[0m[38;2;214;212;207m█[0m[38;2;217;212;207m█[0m[38;2;219;215;209m█[0m[38;2;220;215;209m█[0m[38;2;220;215;209m█[0m[38;2;219;214;208m█[0m[38;2;218;213;207m█[0m[38;2;218;213;208m█[0m[38;2;217;212;208m█[0m[38;2;217;212;206m█[0m[38;2;216;211;206m█[0m[38;2;216;211;206m█[0m[38;2;217;212;209m█[0m[38;2;196;190;181m█[0m[38;2;183;151;123m█[0m[38;2;185;122;97m█[0m[38;2;194;87;73m█[0m[38;2;218;63;62m█[0m[38;2;216;51;63m█[0m[38;2;207;48;65m█[0m[38;2;103;23;34m█[0m[38;2;86;64;74m█[0m[38;2;167;155;175m█[0m[38;2;159;142;154m█[0m[38;2;193;171;177m█[0m[38;2;202;203;214m█[0m[38;2;203;208;220m█[0m[38;2;202;209;222m█[0m[38;2;205;217;229m█[0m[38;2;213;223;228m█[0m[38;2;177;186;194m█[0m[38;2;184;192;203m█[0m[38;2;199;207;219m█[0m[38;2;189;190;192m█[0m[38;2;184;179;172m█[0m[38;2;183;177;171m█[0m[38;2;181;176;170m█[0m[38;2;161;156;151m█[0m[38;2;133;130;126m█[0m[38;2;121;120;118m█[0m[38;2;126;125;121m█[0m");
$display("[38;2;205;200;193m█[0m[38;2;204;199;193m█[0m[38;2;204;199;193m█[0m[38;2;203;198;192m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;202;197;190m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;202;196;191m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;202;196;190m█[0m[38;2;202;197;191m█[0m[38;2;204;199;194m█[0m[38;2;206;204;201m█[0m[38;2;208;207;206m█[0m[38;2;210;209;207m█[0m[38;2;211;209;204m█[0m[38;2;215;210;204m█[0m[38;2;218;213;207m█[0m[38;2;219;214;208m█[0m[38;2;218;214;208m█[0m[38;2;218;213;207m█[0m[38;2;218;213;209m█[0m[38;2;218;213;210m█[0m[38;2;218;213;210m█[0m[38;2;217;213;210m█[0m[38;2;216;212;209m█[0m[38;2;217;213;210m█[0m[38;2;214;211;207m█[0m[38;2;186;184;184m█[0m[38;2;181;187;198m█[0m[38;2;176;197;207m█[0m[38;2;206;156;156m█[0m[38;2;239;103;104m█[0m[38;2;231;70;81m█[0m[38;2;217;58;74m█[0m[38;2;92;37;47m█[0m[38;2;95;102;108m█[0m[38;2;168;176;182m█[0m[38;2;185;189;194m█[0m[38;2;191;195;200m█[0m[38;2;193;196;206m█[0m[38;2;196;199;211m█[0m[38;2;197;202;213m█[0m[38;2;200;210;222m█[0m[38;2;215;228;234m█[0m[38;2;216;227;236m█[0m[38;2;204;212;226m█[0m[38;2;175;177;186m█[0m[38;2;104;99;95m█[0m[38;2;101;97;92m█[0m[38;2;99;95;92m█[0m[38;2;70;69;66m█[0m[38;2;82;83;83m█[0m[38;2;136;134;132m█[0m[38;2;134;131;127m█[0m[38;2;137;133;130m█[0m");
$display("[38;2;201;196;190m█[0m[38;2;200;195;189m█[0m[38;2;199;194;188m█[0m[38;2;199;193;187m█[0m[38;2;198;192;186m█[0m[38;2;196;190;184m█[0m[38;2;196;189;183m█[0m[38;2;196;188;183m█[0m[38;2;195;188;182m█[0m[38;2;195;188;181m█[0m[38;2;195;187;179m█[0m[38;2;194;187;178m█[0m[38;2;194;187;178m█[0m[38;2;194;186;180m█[0m[38;2;194;187;181m█[0m[38;2;195;189;182m█[0m[38;2;197;191;185m█[0m[38;2;200;194;189m█[0m[38;2;204;199;194m█[0m[38;2;208;203;197m█[0m[38;2;211;206;200m█[0m[38;2;214;209;203m█[0m[38;2;215;210;204m█[0m[38;2;214;210;203m█[0m[38;2;214;210;204m█[0m[38;2;214;210;205m█[0m[38;2;215;211;207m█[0m[38;2;215;212;209m█[0m[38;2;216;216;211m█[0m[38;2;216;215;211m█[0m[38;2;217;216;212m█[0m[38;2;211;210;208m█[0m[38;2;184;176;170m█[0m[38;2;202;154;132m█[0m[38;2;218;146;150m█[0m[38;2;199;96;96m█[0m[38;2;199;86;84m█[0m[38;2;181;82;82m█[0m[38;2;165;98;97m█[0m[38;2;125;111;111m█[0m[38;2;139;140;141m█[0m[38;2;124;123;126m█[0m[38;2;85;85;87m█[0m[38;2;64;65;65m█[0m[38;2;61;63;66m█[0m[38;2;138;143;149m█[0m[38;2;205;210;222m█[0m[38;2;210;219;231m█[0m[38;2;215;225;236m█[0m[38;2;211;218;229m█[0m[38;2;201;207;221m█[0m[38;2;126;127;132m█[0m[38;2;58;56;51m█[0m[38;2;79;78;74m█[0m[38;2;64;63;61m█[0m[38;2;53;54;57m█[0m[38;2;149;147;146m█[0m[38;2;213;208;202m█[0m[38;2;203;199;195m█[0m[38;2;201;200;195m█[0m");
$display("[38;2;197;192;186m█[0m[38;2;195;190;184m█[0m[38;2;194;188;182m█[0m[38;2;192;184;179m█[0m[38;2;190;182;175m█[0m[38;2;189;179;171m█[0m[38;2;187;177;168m█[0m[38;2;185;175;166m█[0m[38;2;184;173;164m█[0m[38;2;183;172;163m█[0m[38;2;183;172;162m█[0m[38;2;182;172;162m█[0m[38;2;182;172;161m█[0m[38;2;182;172;162m█[0m[38;2;182;173;164m█[0m[38;2;184;176;166m█[0m[38;2;188;180;172m█[0m[38;2;191;183;177m█[0m[38;2;194;188;182m█[0m[38;2;199;194;188m█[0m[38;2;204;199;193m█[0m[38;2;208;203;197m█[0m[38;2;208;203;197m█[0m[38;2;207;202;196m█[0m[38;2;206;204;199m█[0m[38;2;207;207;202m█[0m[38;2;211;210;205m█[0m[38;2;214;213;209m█[0m[38;2;217;217;213m█[0m[38;2;218;218;214m█[0m[38;2;220;219;217m█[0m[38;2;202;202;197m█[0m[38;2;137;116;92m█[0m[38;2;109;64;38m█[0m[38;2;134;93;88m█[0m[38;2;138;115;114m█[0m[38;2;136;127;124m█[0m[38;2;140;139;135m█[0m[38;2;143;143;140m█[0m[38;2;134;129;127m█[0m[38;2;55;52;51m█[0m[38;2;17;16;16m█[0m[38;2;20;19;20m█[0m[38;2;21;21;25m█[0m[38;2;8;9;11m█[0m[38;2;57;61;64m█[0m[38;2;119;123;131m█[0m[38;2;114;119;128m█[0m[38;2;97;101;109m█[0m[38;2;70;73;78m█[0m[38;2;60;61;62m█[0m[38;2;77;79;79m█[0m[38;2;67;66;62m█[0m[38;2;60;60;57m█[0m[38;2;32;31;31m█[0m[38;2;105;104;106m█[0m[38;2;207;204;200m█[0m[38;2;200;197;194m█[0m[38;2;197;196;192m█[0m[38;2;197;196;192m█[0m");
$display("[38;2;191;185;179m█[0m[38;2;188;181;175m█[0m[38;2;185;178;170m█[0m[38;2;183;173;164m█[0m[38;2;180;169;160m█[0m[38;2;178;166;156m█[0m[38;2;176;164;153m█[0m[38;2;174;162;151m█[0m[38;2;174;162;149m█[0m[38;2;174;161;149m█[0m[38;2;174;161;149m█[0m[38;2;174;161;150m█[0m[38;2;173;161;148m█[0m[38;2;173;162;149m█[0m[38;2;174;162;150m█[0m[38;2;175;164;154m█[0m[38;2;180;170;159m█[0m[38;2;183;173;163m█[0m[38;2;186;179;172m█[0m[38;2;193;188;182m█[0m[38;2;200;195;189m█[0m[38;2;205;200;194m█[0m[38;2;203;198;192m█[0m[38;2;202;197;191m█[0m[38;2;202;197;191m█[0m[38;2;203;200;195m█[0m[38;2;205;204;200m█[0m[38;2;213;212;208m█[0m[38;2;219;218;216m█[0m[38;2;221;221;219m█[0m[38;2;224;223;221m█[0m[38;2;189;188;185m█[0m[38;2;63;62;63m█[0m[38;2;110;109;109m█[0m[38;2;148;143;141m█[0m[38;2;147;138;137m█[0m[38;2;144;135;134m█[0m[38;2;143;134;133m█[0m[38;2;145;137;135m█[0m[38;2;142;136;133m█[0m[38;2;125;117;116m█[0m[38;2;95;90;90m█[0m[38;2;74;73;76m█[0m[38;2;44;44;47m█[0m[38;2;29;27;29m█[0m[38;2;29;26;28m█[0m[38;2;33;27;28m█[0m[38;2;53;41;38m█[0m[38;2;55;49;46m█[0m[38;2;80;79;77m█[0m[38;2;74;73;71m█[0m[38;2;58;58;55m█[0m[38;2;50;50;47m█[0m[38;2;41;40;37m█[0m[38;2;12;11;11m█[0m[38;2;95;96;94m█[0m[38;2;210;208;204m█[0m[38;2;200;198;195m█[0m[38;2;198;197;193m█[0m[38;2;199;198;195m█[0m");
$display("[38;2;185;176;169m█[0m[38;2;181;171;161m█[0m[38;2;176;165;154m█[0m[38;2;174;162;150m█[0m[38;2;172;160;147m█[0m[38;2;173;161;147m█[0m[38;2;173;161;147m█[0m[38;2;173;161;147m█[0m[38;2;174;161;147m█[0m[38;2;174;161;147m█[0m[38;2;174;162;148m█[0m[38;2;173;161;147m█[0m[38;2;175;161;148m█[0m[38;2;177;164;150m█[0m[38;2;175;163;148m█[0m[38;2;175;163;149m█[0m[38;2;177;167;156m█[0m[38;2;180;170;160m█[0m[38;2;184;175;167m█[0m[38;2;191;185;179m█[0m[38;2;199;193;187m█[0m[38;2;202;197;191m█[0m[38;2;198;193;186m█[0m[38;2;195;191;184m█[0m[38;2;196;191;185m█[0m[38;2;201;196;193m█[0m[38;2;207;206;203m█[0m[38;2;217;216;214m█[0m[38;2;224;223;221m█[0m[38;2;229;229;228m█[0m[38;2;135;133;132m█[0m[38;2;65;65;64m█[0m[38;2;96;95;94m█[0m[38;2;91;87;84m█[0m[38;2;129;119;117m█[0m[38;2;139;130;128m█[0m[38;2;130;122;120m█[0m[38;2;114;107;105m█[0m[38;2;94;85;84m█[0m[38;2;63;60;60m█[0m[38;2;40;38;39m█[0m[38;2;28;24;25m█[0m[38;2;37;26;23m█[0m[38;2;53;37;32m█[0m[38;2;58;41;34m█[0m[38;2;55;38;31m█[0m[38;2;67;47;39m█[0m[38;2;73;51;43m█[0m[38;2;79;59;49m█[0m[38;2;119;106;98m█[0m[38;2;166;159;154m█[0m[38;2;200;195;192m█[0m[38;2;201;196;193m█[0m[38;2;159;155;152m█[0m[38;2;35;35;34m█[0m[38;2;164;162;159m█[0m[38;2;212;206;203m█[0m[38;2;205;199;196m█[0m[38;2;201;198;195m█[0m[38;2;200;198;196m█[0m");
$display("[38;2;180;169;160m█[0m[38;2;176;163;153m█[0m[38;2;172;160;147m█[0m[38;2;172;160;146m█[0m[38;2;173;161;147m█[0m[38;2;175;163;149m█[0m[38;2;176;164;150m█[0m[38;2;177;165;151m█[0m[38;2;177;164;150m█[0m[38;2;178;163;150m█[0m[38;2;177;162;148m█[0m[38;2;178;164;150m█[0m[38;2;168;156;144m█[0m[38;2;131;122;113m█[0m[38;2;138;130;122m█[0m[38;2;167;156;145m█[0m[38;2;177;166;153m█[0m[38;2;177;167;156m█[0m[38;2;182;172;162m█[0m[38;2;188;179;171m█[0m[38;2;192;185;179m█[0m[38;2;191;185;179m█[0m[38;2;189;183;177m█[0m[38;2;192;186;180m█[0m[38;2;197;192;187m█[0m[38;2;205;201;197m█[0m[38;2;212;212;209m█[0m[38;2;222;222;221m█[0m[38;2;225;225;223m█[0m[38;2;228;228;228m█[0m[38;2;198;198;197m█[0m[38;2;103;102;101m█[0m[38;2;87;86;85m█[0m[38;2;80;79;77m█[0m[38;2;120;117;115m█[0m[38;2;83;76;72m█[0m[38;2;44;34;29m█[0m[38;2;16;12;10m█[0m[38;2;20;16;17m█[0m[38;2;19;20;23m█[0m[38;2;18;18;20m█[0m[38;2;30;20;17m█[0m[38;2;52;34;29m█[0m[38;2;50;33;29m█[0m[38;2;48;31;26m█[0m[38;2;53;35;29m█[0m[38;2;51;33;28m█[0m[38;2;47;29;25m█[0m[38;2;42;26;20m█[0m[38;2;40;23;16m█[0m[38;2;51;31;23m█[0m[38;2;91;71;61m█[0m[38;2;158;131;116m█[0m[38;2;97;85;79m█[0m[38;2;87;73;65m█[0m[38;2;184;147;131m█[0m[38;2;175;138;122m█[0m[38;2;170;133;117m█[0m[38;2;165;129;114m█[0m[38;2;163;127;112m█[0m");
$display("[38;2;181;170;160m█[0m[38;2;179;166;156m█[0m[38;2;178;165;154m█[0m[38;2;178;166;153m█[0m[38;2;178;166;153m█[0m[38;2;180;168;155m█[0m[38;2;180;167;153m█[0m[38;2;180;167;153m█[0m[38;2;181;169;154m█[0m[38;2;178;165;151m█[0m[38;2;179;166;152m█[0m[38;2;176;162;150m█[0m[38;2;99;80;77m█[0m[38;2;69;47;48m█[0m[38;2;66;58;58m█[0m[38;2;62;57;56m█[0m[38;2;165;153;141m█[0m[38;2;177;165;151m█[0m[38;2;177;165;153m█[0m[38;2;177;167;157m█[0m[38;2;180;171;161m█[0m[38;2;184;176;169m█[0m[38;2;187;181;175m█[0m[38;2;192;187;181m█[0m[38;2;194;189;184m█[0m[38;2;199;196;192m█[0m[38;2;212;211;209m█[0m[38;2;221;221;220m█[0m[38;2;224;224;224m█[0m[38;2;225;225;224m█[0m[38;2;229;229;228m█[0m[38;2;223;223;222m█[0m[38;2;228;228;228m█[0m[38;2;227;227;226m█[0m[38;2;129;121;115m█[0m[38;2;46;32;24m█[0m[38;2;32;19;14m█[0m[38;2;20;17;14m█[0m[38;2;26;26;27m█[0m[38;2;27;27;30m█[0m[38;2;21;18;20m█[0m[38;2;29;19;19m█[0m[38;2;33;21;18m█[0m[38;2;36;21;18m█[0m[38;2;38;21;18m█[0m[38;2;35;20;17m█[0m[38;2;33;18;16m█[0m[38;2;30;16;14m█[0m[38;2;32;17;14m█[0m[38;2;35;19;16m█[0m[38;2;39;22;18m█[0m[38;2;42;24;18m█[0m[38;2;57;35;24m█[0m[38;2;73;53;41m█[0m[38;2;101;83;74m█[0m[38;2;112;92;82m█[0m[38;2;132;107;95m█[0m[38;2;156;124;109m█[0m[38;2;179;141;124m█[0m[38;2;174;136;120m█[0m");
$display("[38;2;143;136;128m█[0m[38;2;134;126;119m█[0m[38;2;123;116;110m█[0m[38;2;118;111;106m█[0m[38;2;118;112;106m█[0m[38;2;117;112;106m█[0m[38;2;94;93;85m█[0m[38;2;67;64;61m█[0m[38;2;133;124;116m█[0m[38;2;183;170;156m█[0m[38;2;181;168;155m█[0m[38;2;153;136;124m█[0m[38;2;87;69;60m█[0m[38;2;80;70;66m█[0m[38;2;74;65;61m█[0m[38;2;30;17;15m█[0m[38;2;114;98;90m█[0m[38;2;177;163;147m█[0m[38;2;172;160;148m█[0m[38;2;174;163;153m█[0m[38;2;177;168;158m█[0m[38;2;184;177;170m█[0m[38;2;187;181;175m█[0m[38;2;188;184;177m█[0m[38;2;186;181;176m█[0m[38;2;194;192;189m█[0m[38;2;213;212;211m█[0m[38;2;221;221;221m█[0m[38;2;223;223;223m█[0m[38;2;224;224;224m█[0m[38;2;229;230;230m█[0m[38;2;228;228;229m█[0m[38;2;191;187;187m█[0m[38;2;83;71;66m█[0m[38;2;30;15;10m█[0m[38;2;39;25;18m█[0m[38;2;37;25;20m█[0m[38;2;38;27;25m█[0m[38;2;27;24;24m█[0m[38;2;21;16;15m█[0m[38;2;19;13;11m█[0m[38;2;31;19;16m█[0m[38;2;36;22;19m█[0m[38;2;35;21;18m█[0m[38;2;25;15;12m█[0m[38;2;22;14;11m█[0m[38;2;27;15;13m█[0m[38;2;35;20;17m█[0m[38;2;41;24;20m█[0m[38;2;46;29;21m█[0m[38;2;48;31;23m█[0m[38;2;48;30;22m█[0m[38;2;45;28;20m█[0m[38;2;51;31;21m█[0m[38;2;58;41;31m█[0m[38;2;51;45;41m█[0m[38;2;56;52;48m█[0m[38;2;50;47;44m█[0m[38;2;121;103;90m█[0m[38;2;183;147;130m█[0m");
$display("[38;2;47;42;39m█[0m[38;2;40;38;35m█[0m[38;2;38;38;35m█[0m[38;2;35;35;34m█[0m[38;2;33;33;33m█[0m[38;2;36;36;37m█[0m[38;2;44;41;40m█[0m[38;2;42;42;44m█[0m[38;2;41;40;41m█[0m[38;2;161;139;123m█[0m[38;2;173;134;111m█[0m[38;2;180;132;104m█[0m[38;2;202;148;118m█[0m[38;2;204;154;126m█[0m[38;2;189;144;119m█[0m[38;2;182;138;114m█[0m[38;2;168;129;107m█[0m[38;2;163;127;110m█[0m[38;2;173;151;137m█[0m[38;2;174;162;152m█[0m[38;2;175;166;157m█[0m[38;2;178;170;163m█[0m[38;2;177;171;164m█[0m[38;2;177;170;163m█[0m[38;2;177;172;165m█[0m[38;2;199;198;194m█[0m[38;2;220;220;221m█[0m[38;2;226;226;226m█[0m[38;2;227;227;227m█[0m[38;2;221;222;221m█[0m[38;2;154;145;141m█[0m[38;2;92;78;73m█[0m[38;2;48;31;26m█[0m[38;2;39;22;15m█[0m[38;2;48;31;24m█[0m[38;2;43;27;20m█[0m[38;2;33;22;18m█[0m[38;2;51;29;24m█[0m[38;2;32;21;18m█[0m[38;2;32;20;17m█[0m[38;2;30;19;17m█[0m[38;2;32;19;16m█[0m[38;2;35;20;18m█[0m[38;2;26;15;12m█[0m[38;2;29;18;14m█[0m[38;2;40;24;19m█[0m[38;2;43;26;21m█[0m[38;2;44;26;21m█[0m[38;2;44;26;21m█[0m[38;2;45;28;22m█[0m[38;2;45;28;22m█[0m[38;2;46;29;21m█[0m[38;2;48;31;23m█[0m[38;2;52;33;24m█[0m[38;2;52;32;22m█[0m[38;2;67;51;40m█[0m[38;2;61;54;47m█[0m[38;2;43;41;38m█[0m[38;2;70;62;57m█[0m[38;2;185;148;129m█[0m");
$display("[38;2;46;42;39m█[0m[38;2;41;40;37m█[0m[38;2;41;40;39m█[0m[38;2;35;34;34m█[0m[38;2;32;32;33m█[0m[38;2;20;21;21m█[0m[38;2;15;15;15m█[0m[38;2;37;37;38m█[0m[38;2;79;58;49m█[0m[38;2;155;109;83m█[0m[38;2;163;114;86m█[0m[38;2;186;133;105m█[0m[38;2;198;144;116m█[0m[38;2;198;146;118m█[0m[38;2;205;151;123m█[0m[38;2;206;153;123m█[0m[38;2;203;150;118m█[0m[38;2;172;124;100m█[0m[38;2;127;96;83m█[0m[38;2;138;118;104m█[0m[38;2;149;134;123m█[0m[38;2;149;136;125m█[0m[38;2;150;137;127m█[0m[38;2;161;148;139m█[0m[38;2;176;169;162m█[0m[38;2;190;188;187m█[0m[38;2;198;197;197m█[0m[38;2;205;204;204m█[0m[38;2;218;218;218m█[0m[38;2;188;186;184m█[0m[38;2;42;25;17m█[0m[38;2;35;18;12m█[0m[38;2;47;30;22m█[0m[38;2;53;35;26m█[0m[38;2;46;29;20m█[0m[38;2;44;28;20m█[0m[38;2;49;32;23m█[0m[38;2;43;29;21m█[0m[38;2;35;22;17m█[0m[38;2;28;17;13m█[0m[38;2;31;19;15m█[0m[38;2;37;22;17m█[0m[38;2;41;25;20m█[0m[38;2;41;24;20m█[0m[38;2;42;24;21m█[0m[38;2;40;23;20m█[0m[38;2;39;23;18m█[0m[38;2;39;22;19m█[0m[38;2;40;23;19m█[0m[38;2;42;24;21m█[0m[38;2;43;26;23m█[0m[38;2;45;28;23m█[0m[38;2;48;31;23m█[0m[38;2;51;32;24m█[0m[38;2;53;34;25m█[0m[38;2;54;36;26m█[0m[38;2;51;45;39m█[0m[38;2;26;25;23m█[0m[38;2;83;70;62m█[0m[38;2;183;144;123m█[0m");
$display("[38;2;39;38;36m█[0m[38;2;37;36;35m█[0m[38;2;36;36;36m█[0m[38;2;35;35;36m█[0m[38;2;29;29;30m█[0m[38;2;14;14;14m█[0m[38;2;9;9;10m█[0m[38;2;35;28;26m█[0m[38;2;131;91;74m█[0m[38;2;147;104;80m█[0m[38;2;154;109;83m█[0m[38;2;170;122;95m█[0m[38;2;177;129;102m█[0m[38;2;184;135;107m█[0m[38;2;191;141;111m█[0m[38;2;196;144;112m█[0m[38;2;160;112;84m█[0m[38;2;85;56;41m█[0m[38;2;60;39;30m█[0m[38;2;65;42;31m█[0m[38;2;70;47;34m█[0m[38;2;71;49;37m█[0m[38;2;68;47;36m█[0m[38;2;67;49;39m█[0m[38;2;75;58;49m█[0m[38;2;65;49;40m█[0m[38;2;61;43;36m█[0m[38;2;64;47;40m█[0m[38;2;62;47;43m█[0m[38;2;68;56;53m█[0m[38;2;35;21;17m█[0m[38;2;39;24;19m█[0m[38;2;41;26;21m█[0m[38;2;38;24;19m█[0m[38;2;36;23;17m█[0m[38;2;34;21;17m█[0m[38;2;29;17;14m█[0m[38;2;26;16;12m█[0m[38;2;30;18;14m█[0m[38;2;48;31;25m█[0m[38;2;57;38;31m█[0m[38;2;55;36;29m█[0m[38;2;55;36;30m█[0m[38;2;56;37;30m█[0m[38;2;56;36;29m█[0m[38;2;56;36;29m█[0m[38;2;56;37;29m█[0m[38;2;54;36;27m█[0m[38;2;54;36;27m█[0m[38;2;54;35;28m█[0m[38;2;54;35;28m█[0m[38;2;55;36;29m█[0m[38;2;53;35;27m█[0m[38;2;54;36;28m█[0m[38;2;55;37;28m█[0m[38;2;59;42;34m█[0m[38;2;33;28;24m█[0m[38;2;14;14;13m█[0m[38;2;135;120;102m█[0m[38;2;152;142;126m█[0m");
$display("[38;2;28;28;28m█[0m[38;2;30;31;30m█[0m[38;2;31;31;32m█[0m[38;2;32;32;34m█[0m[38;2;26;27;29m█[0m[38;2;12;13;13m█[0m[38;2;9;9;9m█[0m[38;2;23;19;18m█[0m[38;2;53;39;33m█[0m[38;2;59;45;38m█[0m[38;2;59;43;33m█[0m[38;2;113;82;63m█[0m[38;2;147;108;85m█[0m[38;2;156;116;92m█[0m[38;2;161;120;95m█[0m[38;2;147;106;82m█[0m[38;2;96;65;49m█[0m[38;2;49;31;25m█[0m[38;2;55;36;29m█[0m[38;2;57;37;30m█[0m[38;2;55;36;28m█[0m[38;2;58;37;26m█[0m[38;2;66;43;32m█[0m[38;2;71;46;34m█[0m[38;2;69;45;32m█[0m[38;2;70;46;33m█[0m[38;2;69;45;32m█[0m[38;2;66;42;31m█[0m[38;2;59;38;29m█[0m[38;2;50;32;25m█[0m[38;2;48;33;26m█[0m[38;2;28;18;14m█[0m[38;2;19;12;10m█[0m[38;2;16;9;7m█[0m[38;2;18;11;8m█[0m[38;2;27;17;13m█[0m[38;2;33;20;15m█[0m[38;2;35;22;16m█[0m[38;2;30;18;13m█[0m[38;2;30;17;12m█[0m[38;2;35;21;16m█[0m[38;2;40;24;19m█[0m[38;2;45;27;21m█[0m[38;2;57;38;30m█[0m[38;2;67;45;36m█[0m[38;2;68;45;37m█[0m[38;2;64;43;36m█[0m[38;2;61;42;34m█[0m[38;2;59;40;32m█[0m[38;2;58;39;32m█[0m[38;2;59;39;32m█[0m[38;2;62;42;34m█[0m[38;2;62;43;33m█[0m[38;2;67;47;36m█[0m[38;2;73;54;42m█[0m[38;2;41;34;28m█[0m[38;2;2;3;3m█[0m[38;2;98;97;88m█[0m[38;2;190;181;162m█[0m[38;2;178;169;153m█[0m");
$display("[38;2;27;27;27m█[0m[38;2;30;30;31m█[0m[38;2;32;32;34m█[0m[38;2;32;32;34m█[0m[38;2;31;31;33m█[0m[38;2;20;21;23m█[0m[38;2;9;10;11m█[0m[38;2;18;18;18m█[0m[38;2;30;31;32m█[0m[38;2;34;33;32m█[0m[38;2;40;39;37m█[0m[38;2;65;61;57m█[0m[38;2;32;28;27m█[0m[38;2;34;28;26m█[0m[38;2;40;36;35m█[0m[38;2;49;44;44m█[0m[38;2;43;27;21m█[0m[38;2;54;38;30m█[0m[38;2;53;35;27m█[0m[38;2;51;34;26m█[0m[38;2;43;27;20m█[0m[38;2;35;20;16m█[0m[38;2;39;23;18m█[0m[38;2;55;35;27m█[0m[38;2;66;44;33m█[0m[38;2;63;42;32m█[0m[38;2;61;40;32m█[0m[38;2;60;39;32m█[0m[38;2;59;39;32m█[0m[38;2;61;41;33m█[0m[38;2;65;44;34m█[0m[38;2;62;42;32m█[0m[38;2;50;33;23m█[0m[38;2;49;31;23m█[0m[38;2;43;27;20m█[0m[38;2;52;35;26m█[0m[38;2;54;36;29m█[0m[38;2;37;22;17m█[0m[38;2;36;21;16m█[0m[38;2;39;24;18m█[0m[38;2;40;25;19m█[0m[38;2;42;25;20m█[0m[38;2;44;27;20m█[0m[38;2;49;33;24m█[0m[38;2;59;40;32m█[0m[38;2;58;39;32m█[0m[38;2;57;38;31m█[0m[38;2;59;40;33m█[0m[38;2;60;40;34m█[0m[38;2;58;39;32m█[0m[38;2;58;39;32m█[0m[38;2;62;42;35m█[0m[38;2;69;48;39m█[0m[38;2;65;47;38m█[0m[38;2;39;32;27m█[0m[38;2;4;5;4m█[0m[38;2;63;66;62m█[0m[38;2;193;200;186m█[0m[38;2;205;198;178m█[0m[38;2;195;187;167m█[0m");
$display("[38;2;27;27;28m█[0m[38;2;29;29;31m█[0m[38;2;32;32;34m█[0m[38;2;32;32;34m█[0m[38;2;30;30;35m█[0m[38;2;24;25;28m█[0m[38;2;13;14;16m█[0m[38;2;31;31;31m█[0m[38;2;53;53;53m█[0m[38;2;53;53;52m█[0m[38;2;81;77;71m█[0m[38;2;139;129;117m█[0m[38;2;34;34;34m█[0m[38;2;15;16;17m█[0m[38;2;15;17;18m█[0m[38;2;26;27;30m█[0m[38;2;38;26;20m█[0m[38;2;59;45;37m█[0m[38;2;54;38;30m█[0m[38;2;47;30;22m█[0m[38;2;43;26;20m█[0m[38;2;39;22;18m█[0m[38;2;42;25;20m█[0m[38;2;39;22;18m█[0m[38;2;49;30;23m█[0m[38;2;61;41;32m█[0m[38;2;63;43;35m█[0m[38;2;59;39;32m█[0m[38;2;56;36;29m█[0m[38;2;54;35;29m█[0m[38;2;54;36;28m█[0m[38;2;58;39;29m█[0m[38;2;54;36;26m█[0m[38;2;44;26;18m█[0m[38;2;49;31;22m█[0m[38;2;40;26;18m█[0m[38;2;50;34;27m█[0m[38;2;55;37;30m█[0m[38;2;39;23;19m█[0m[38;2;31;16;13m█[0m[38;2;32;17;14m█[0m[38;2;36;20;16m█[0m[38;2;41;24;19m█[0m[38;2;45;27;21m█[0m[38;2;50;32;25m█[0m[38;2;53;35;28m█[0m[38;2;52;34;27m█[0m[38;2;49;32;24m█[0m[38;2;51;33;25m█[0m[38;2;53;34;27m█[0m[38;2;55;37;29m█[0m[38;2;63;43;36m█[0m[38;2;55;38;31m█[0m[38;2;34;28;24m█[0m[38;2;14;13;12m█[0m[38;2;36;42;42m█[0m[38;2;149;160;154m█[0m[38;2;151;143;129m█[0m[38;2;83;78;67m█[0m[38;2;48;45;41m█[0m");
$display("[38;2;15;16;18m█[0m[38;2;16;17;19m█[0m[38;2;15;16;18m█[0m[38;2;14;15;17m█[0m[38;2;12;12;15m█[0m[38;2;11;12;14m█[0m[38;2;15;16;17m█[0m[38;2;21;22;22m█[0m[38;2;29;29;29m█[0m[38;2;82;77;72m█[0m[38;2;145;134;120m█[0m[38;2;156;143;127m█[0m[38;2;100;93;84m█[0m[38;2;14;16;18m█[0m[38;2;13;14;14m█[0m[38;2;18;20;19m█[0m[38;2;39;38;35m█[0m[38;2;106;94;85m█[0m[38;2;104;90;81m█[0m[38;2;66;51;43m█[0m[38;2;48;31;23m█[0m[38;2;45;28;20m█[0m[38;2;46;30;21m█[0m[38;2;45;28;20m█[0m[38;2;45;28;20m█[0m[38;2;50;31;24m█[0m[38;2;57;38;31m█[0m[38;2;59;40;33m█[0m[38;2;55;36;29m█[0m[38;2;52;34;27m█[0m[38;2;50;33;25m█[0m[38;2;48;31;24m█[0m[38;2;51;35;26m█[0m[38;2;36;23;17m█[0m[38;2;36;20;15m█[0m[38;2;44;27;19m█[0m[38;2;48;31;23m█[0m[38;2;53;36;28m█[0m[38;2;55;38;30m█[0m[38;2;49;32;25m█[0m[38;2;39;22;18m█[0m[38;2;31;16;14m█[0m[38;2;31;16;14m█[0m[38;2;35;19;17m█[0m[38;2;41;24;20m█[0m[38;2;46;29;22m█[0m[38;2;49;32;24m█[0m[38;2;48;31;23m█[0m[38;2;48;31;23m█[0m[38;2;50;33;25m█[0m[38;2;51;35;27m█[0m[38;2;41;26;21m█[0m[38;2;28;18;15m█[0m[38;2;16;14;14m█[0m[38;2;20;21;21m█[0m[38;2;63;63;60m█[0m[38;2;62;59;58m█[0m[38;2;32;30;31m█[0m[38;2;3;2;4m█[0m[38;2;9;7;11m█[0m");
$display("[38;2;7;8;10m█[0m[38;2;7;7;9m█[0m[38;2;6;7;9m█[0m[38;2;7;8;10m█[0m[38;2;8;9;11m█[0m[38;2;8;9;11m█[0m[38;2;7;8;10m█[0m[38;2;22;22;23m█[0m[38;2;85;79;72m█[0m[38;2;142;130;116m█[0m[38;2;142;130;116m█[0m[38;2;142;128;115m█[0m[38;2;146;131;118m█[0m[38;2;86;75;68m█[0m[38;2;40;31;29m█[0m[38;2;42;39;36m█[0m[38;2;109;102;93m█[0m[38;2;156;143;129m█[0m[38;2;154;140;126m█[0m[38;2;142;125;113m█[0m[38;2;78;61;52m█[0m[38;2;42;25;17m█[0m[38;2;46;29;20m█[0m[38;2;49;32;22m█[0m[38;2;50;32;23m█[0m[38;2;49;31;22m█[0m[38;2;50;32;24m█[0m[38;2;53;35;27m█[0m[38;2;54;36;28m█[0m[38;2;53;36;28m█[0m[38;2;51;34;29m█[0m[38;2;47;29;27m█[0m[38;2;45;27;24m█[0m[38;2;47;30;25m█[0m[38;2;32;18;15m█[0m[38;2;32;18;14m█[0m[38;2;40;24;18m█[0m[38;2;44;27;22m█[0m[38;2;46;29;23m█[0m[38;2;48;31;23m█[0m[38;2;48;31;23m█[0m[38;2;43;26;20m█[0m[38;2;38;21;17m█[0m[38;2;34;18;16m█[0m[38;2;34;19;16m█[0m[38;2;38;21;18m█[0m[38;2;44;27;20m█[0m[38;2;47;30;22m█[0m[38;2;47;30;23m█[0m[38;2;42;27;21m█[0m[38;2;32;19;16m█[0m[38;2;27;17;14m█[0m[38;2;10;8;8m█[0m[38;2;15;15;16m█[0m[38;2;68;69;68m█[0m[38;2;82;83;85m█[0m[38;2;81;79;86m█[0m[38;2;81;79;86m█[0m[38;2;71;69;76m█[0m[38;2;45;44;48m█[0m");
$display("[38;2;17;19;21m█[0m[38;2;13;16;18m█[0m[38;2;12;15;16m█[0m[38;2;12;14;16m█[0m[38;2;12;13;15m█[0m[38;2;12;14;16m█[0m[38;2;20;21;23m█[0m[38;2;53;50;47m█[0m[38;2;134;122;107m█[0m[38;2;134;121;108m█[0m[38;2;136;122;108m█[0m[38;2;139;123;109m█[0m[38;2;141;125;111m█[0m[38;2;144;128;114m█[0m[38;2;134;120;105m█[0m[38;2;133;118;103m█[0m[38;2;140;123;106m█[0m[38;2;126;109;92m█[0m[38;2;120;102;85m█[0m[38;2;115;98;82m█[0m[38;2;109;92;78m█[0m[38;2;72;56;43m█[0m[38;2;57;41;29m█[0m[38;2;51;34;25m█[0m[38;2;46;28;21m█[0m[38;2;46;29;21m█[0m[38;2;45;27;20m█[0m[38;2;45;27;21m█[0m[38;2;47;29;22m█[0m[38;2;49;31;25m█[0m[38;2;49;31;28m█[0m[38;2;47;29;27m█[0m[38;2;44;26;24m█[0m[38;2;44;25;23m█[0m[38;2;46;28;26m█[0m[38;2;36;21;18m█[0m[38;2;33;18;16m█[0m[38;2;39;23;20m█[0m[38;2;43;25;21m█[0m[38;2;44;26;20m█[0m[38;2;43;25;19m█[0m[38;2;42;24;20m█[0m[38;2;42;24;19m█[0m[38;2;41;23;18m█[0m[38;2;41;23;17m█[0m[38;2;40;22;18m█[0m[38;2;42;25;20m█[0m[38;2;44;27;21m█[0m[38;2;36;24;18m█[0m[38;2;33;22;16m█[0m[38;2;31;21;17m█[0m[38;2;11;8;8m█[0m[38;2;73;75;72m█[0m[38;2;133;135;132m█[0m[38;2;158;161;160m█[0m[38;2;121;125;133m█[0m[38;2;56;59;69m█[0m[38;2;38;38;41m█[0m[38;2;61;61;67m█[0m[38;2;77;75;81m█[0m");
$display("[38;2;26;28;29m█[0m[38;2;19;23;23m█[0m[38;2;18;22;22m█[0m[38;2;20;21;23m█[0m[38;2;21;21;23m█[0m[38;2;32;32;33m█[0m[38;2;51;48;46m█[0m[38;2;80;72;65m█[0m[38;2;136;122;108m█[0m[38;2;134;119;106m█[0m[38;2;130;114;101m█[0m[38;2;124;108;93m█[0m[38;2;120;104;89m█[0m[38;2;117;101;85m█[0m[38;2;120;103;87m█[0m[38;2;123;107;90m█[0m[38;2;113;96;80m█[0m[38;2;112;95;79m█[0m[38;2;111;94;78m█[0m[38;2;109;92;76m█[0m[38;2;105;89;73m█[0m[38;2;114;97;80m█[0m[38;2;128;111;93m█[0m[38;2;97;82;67m█[0m[38;2;37;25;19m█[0m[38;2;29;18;14m█[0m[38;2;38;30;27m█[0m[38;2;39;29;27m█[0m[38;2;35;22;20m█[0m[38;2;35;21;19m█[0m[38;2;39;23;21m█[0m[38;2;42;25;22m█[0m[38;2;43;25;23m█[0m[38;2;42;24;21m█[0m[38;2;43;24;22m█[0m[38;2;45;26;24m█[0m[38;2;41;24;21m█[0m[38;2;39;22;20m█[0m[38;2;43;25;21m█[0m[38;2;44;26;19m█[0m[38;2;42;24;19m█[0m[38;2;40;22;18m█[0m[38;2;37;20;17m█[0m[38;2;37;20;17m█[0m[38;2;33;19;14m█[0m[38;2;33;19;15m█[0m[38;2;33;19;16m█[0m[38;2;32;20;16m█[0m[38;2;33;22;16m█[0m[38;2;32;23;17m█[0m[38;2;21;18;16m█[0m[38;2;64;64;60m█[0m[38;2;150;152;144m█[0m[38;2;137;139;131m█[0m[38;2;109;109;105m█[0m[38;2;74;75;78m█[0m[38;2;54;54;60m█[0m[38;2;65;64;71m█[0m[38;2;71;72;80m█[0m[38;2;57;59;65m█[0m");
$display("[38;2;32;31;31m█[0m[38;2;56;53;50m█[0m[38;2;68;63;58m█[0m[38;2;84;76;70m█[0m[38;2;105;93;85m█[0m[38;2;120;107;96m█[0m[38;2;141;125;112m█[0m[38;2;137;120;107m█[0m[38;2;126;110;97m█[0m[38;2;120;104;91m█[0m[38;2;115;99;86m█[0m[38;2;110;94;81m█[0m[38;2;108;92;79m█[0m[38;2;109;93;78m█[0m[38;2;110;95;79m█[0m[38;2;116;100;83m█[0m[38;2;113;96;80m█[0m[38;2;116;99;83m█[0m[38;2;112;95;79m█[0m[38;2;110;94;77m█[0m[38;2;100;84;68m█[0m[38;2;108;92;76m█[0m[38;2;114;98;82m█[0m[38;2;122;105;89m█[0m[38;2;103;88;74m█[0m[38;2;41;35;31m█[0m[38;2;24;25;25m█[0m[38;2;20;21;20m█[0m[38;2;9;10;11m█[0m[38;2;5;5;7m█[0m[38;2;5;5;6m█[0m[38;2;8;6;7m█[0m[38;2;12;8;8m█[0m[38;2;17;10;10m█[0m[38;2;23;13;12m█[0m[38;2;27;15;14m█[0m[38;2;30;17;15m█[0m[38;2;30;17;15m█[0m[38;2;31;18;15m█[0m[38;2;29;17;12m█[0m[38;2;21;13;9m█[0m[38;2;15;9;8m█[0m[38;2;17;11;9m█[0m[38;2;26;16;12m█[0m[38;2;25;16;11m█[0m[38;2;24;15;11m█[0m[38;2;24;16;13m█[0m[38;2;26;18;14m█[0m[38;2;23;17;14m█[0m[38;2;18;17;16m█[0m[38;2;49;49;45m█[0m[38;2;131;132;123m█[0m[38;2;147;148;139m█[0m[38;2;90;91;88m█[0m[38;2;44;44;48m█[0m[38;2;45;43;46m█[0m[38;2;45;42;44m█[0m[38;2;47;40;41m█[0m[38;2;74;72;78m█[0m[38;2;99;103;116m█[0m");
$display("[38;2;90;81;70m█[0m[38;2;113;100;88m█[0m[38;2;127;112;100m█[0m[38;2;142;125;111m█[0m[38;2;140;123;106m█[0m[38;2;131;115;99m█[0m[38;2;122;106;91m█[0m[38;2;118;102;88m█[0m[38;2;116;100;87m█[0m[38;2;113;97;84m█[0m[38;2;111;95;82m█[0m[38;2;110;94;81m█[0m[38;2;109;93;81m█[0m[38;2;108;92;78m█[0m[38;2;106;90;75m█[0m[38;2;107;91;75m█[0m[38;2;106;90;74m█[0m[38;2;109;93;77m█[0m[38;2;118;101;85m█[0m[38;2;133;115;98m█[0m[38;2;123;105;88m█[0m[38;2;120;103;86m█[0m[38;2;118;100;83m█[0m[38;2;122;104;88m█[0m[38;2;127;108;91m█[0m[38;2;76;67;57m█[0m[38;2;22;23;21m█[0m[38;2;21;21;20m█[0m[38;2;19;19;20m█[0m[38;2;16;17;18m█[0m[38;2;13;14;15m█[0m[38;2;12;12;14m█[0m[38;2;9;10;12m█[0m[38;2;7;8;9m█[0m[38;2;5;6;6m█[0m[38;2;5;5;5m█[0m[38;2;4;5;5m█[0m[38;2;4;4;4m█[0m[38;2;4;4;4m█[0m[38;2;4;5;5m█[0m[38;2;4;5;5m█[0m[38;2;5;5;5m█[0m[38;2;6;6;6m█[0m[38;2;8;8;7m█[0m[38;2;12;10;9m█[0m[38;2;15;13;11m█[0m[38;2;20;16;13m█[0m[38;2;20;16;12m█[0m[38;2;23;23;23m█[0m[38;2;18;18;16m█[0m[38;2;64;63;59m█[0m[38;2;146;147;139m█[0m[38;2;141;142;134m█[0m[38;2;115;116;111m█[0m[38;2;56;56;56m█[0m[38;2;38;36;37m█[0m[38;2;36;34;35m█[0m[38;2;33;32;32m█[0m[38;2;53;52;55m█[0m[38;2;75;76;84m█[0m");
$display("[38;2;86;73;59m█[0m[38;2;120;106;92m█[0m[38;2;140;123;108m█[0m[38;2;120;103;88m█[0m[38;2;125;108;93m█[0m[38;2;102;86;72m█[0m[38;2;107;92;77m█[0m[38;2;110;94;79m█[0m[38;2;104;88;75m█[0m[38;2;100;85;72m█[0m[38;2;99;85;72m█[0m[38;2;99;84;71m█[0m[38;2;101;86;72m█[0m[38;2;106;90;76m█[0m[38;2;115;98;83m█[0m[38;2;117;101;85m█[0m[38;2;126;109;92m█[0m[38;2;135;118;98m█[0m[38;2;144;125;105m█[0m[38;2;142;122;103m█[0m[38;2;133;113;94m█[0m[38;2;134;114;97m█[0m[38;2;132;112;95m█[0m[38;2;126;107;90m█[0m[38;2;119;101;84m█[0m[38;2;115;99;83m█[0m[38;2;83;72;61m█[0m[38;2;36;31;26m█[0m[38;2;20;17;16m█[0m[38;2;24;20;20m█[0m[38;2;23;21;20m█[0m[38;2;22;21;20m█[0m[38;2;21;21;20m█[0m[38;2;20;20;20m█[0m[38;2;19;19;19m█[0m[38;2;18;18;18m█[0m[38;2;17;16;17m█[0m[38;2;15;14;15m█[0m[38;2;14;13;14m█[0m[38;2;13;12;13m█[0m[38;2;13;12;12m█[0m[38;2;12;12;12m█[0m[38;2;12;12;11m█[0m[38;2;11;11;11m█[0m[38;2;11;11;11m█[0m[38;2;13;13;13m█[0m[38;2;16;16;14m█[0m[38;2;21;21;19m█[0m[38;2;42;41;39m█[0m[38;2;24;23;21m█[0m[38;2;59;58;54m█[0m[38;2;135;137;130m█[0m[38;2;145;147;138m█[0m[38;2;138;139;131m█[0m[38;2;107;108;102m█[0m[38;2;59;58;56m█[0m[38;2;35;34;35m█[0m[38;2;41;39;40m█[0m[38;2;47;46;48m█[0m[38;2;64;65;72m█[0m");
$display("[38;2;98;81;70m█[0m[38;2;134;116;101m█[0m[38;2;126;109;94m█[0m[38;2;104;88;74m█[0m[38;2;107;90;76m█[0m[38;2;85;70;58m█[0m[38;2;89;75;62m█[0m[38;2;105;90;75m█[0m[38;2;103;88;75m█[0m[38;2;106;92;77m█[0m[38;2;112;98;81m█[0m[38;2;120;105;87m█[0m[38;2;127;111;93m█[0m[38;2;134;117;99m█[0m[38;2;138;121;102m█[0m[38;2;141;123;104m█[0m[38;2;143;125;105m█[0m[38;2;144;126;104m█[0m[38;2;145;124;105m█[0m[38;2;145;124;105m█[0m[38;2;140;119;100m█[0m[38;2;138;117;98m█[0m[38;2;136;116;98m█[0m[38;2;132;113;95m█[0m[38;2;127;108;91m█[0m[38;2;123;104;88m█[0m[38;2;119;102;86m█[0m[38;2;107;92;78m█[0m[38;2;54;42;35m█[0m[38;2;26;15;13m█[0m[38;2;23;13;10m█[0m[38;2;23;13;10m█[0m[38;2;22;14;12m█[0m[38;2;22;15;14m█[0m[38;2;21;17;16m█[0m[38;2;21;20;19m█[0m[38;2;20;19;18m█[0m[38;2;19;18;18m█[0m[38;2;19;18;17m█[0m[38;2;19;18;17m█[0m[38;2;19;18;17m█[0m[38;2;19;18;17m█[0m[38;2;19;18;16m█[0m[38;2;17;17;15m█[0m[38;2;19;18;17m█[0m[38;2;21;20;18m█[0m[38;2;23;22;20m█[0m[38;2;26;25;23m█[0m[38;2;33;32;28m█[0m[38;2;31;30;26m█[0m[38;2;48;48;43m█[0m[38;2;121;122;114m█[0m[38;2;146;147;139m█[0m[38;2;145;146;138m█[0m[38;2;140;141;133m█[0m[38;2;122;123;116m█[0m[38;2;76;76;73m█[0m[38;2;35;35;34m█[0m[38;2;36;36;36m█[0m[38;2;43;42;42m█[0m");
$display("[38;2;135;118;102m█[0m[38;2;120;103;87m█[0m[38;2;128;112;97m█[0m[38;2;125;109;95m█[0m[38;2;123;107;92m█[0m[38;2;126;110;95m█[0m[38;2;126;110;95m█[0m[38;2;129;113;97m█[0m[38;2;129;113;97m█[0m[38;2;131;115;97m█[0m[38;2;135;117;99m█[0m[38;2;139;120;101m█[0m[38;2;143;124;105m█[0m[38;2;146;126;107m█[0m[38;2;148;128;109m█[0m[38;2;149;128;109m█[0m[38;2;149;127;109m█[0m[38;2;148;126;108m█[0m[38;2;146;125;106m█[0m[38;2;145;124;105m█[0m[38;2;142;121;102m█[0m[38;2;137;116;98m█[0m[38;2;134;113;96m█[0m[38;2;131;111;94m█[0m[38;2;129;109;92m█[0m[38;2;120;101;84m█[0m[38;2;118;100;83m█[0m[38;2;122;105;88m█[0m[38;2;121;105;89m█[0m[38;2;92;79;67m█[0m[38;2;45;36;29m█[0m[38;2;31;23;18m█[0m[38;2;21;12;9m█[0m[38;2;18;8;5m█[0m[38;2;19;11;9m█[0m[38;2;23;20;20m█[0m[38;2;21;19;18m█[0m[38;2;17;15;15m█[0m[38;2;17;16;14m█[0m[38;2;17;16;14m█[0m[38;2;13;11;9m█[0m[38;2;15;13;11m█[0m[38;2;27;24;22m█[0m[38;2;38;32;29m█[0m[38;2;19;17;16m█[0m[38;2;15;13;13m█[0m[38;2;20;18;18m█[0m[38;2;19;18;17m█[0m[38;2;22;21;19m█[0m[38;2;28;27;24m█[0m[38;2;41;41;37m█[0m[38;2;95;96;90m█[0m[38;2;129;131;124m█[0m[38;2;138;139;131m█[0m[38;2;142;145;136m█[0m[38;2;136;139;130m█[0m[38;2;123;125;117m█[0m[38;2;90;91;86m█[0m[38;2;51;51;50m█[0m[38;2;39;36;36m█[0m");
$display("[38;2;141;125;109m█[0m[38;2;141;125;110m█[0m[38;2;141;125;110m█[0m[38;2;138;122;106m█[0m[38;2;135;119;104m█[0m[38;2;136;120;104m█[0m[38;2;139;122;104m█[0m[38;2;141;124;105m█[0m[38;2;143;125;105m█[0m[38;2;144;126;106m█[0m[38;2;147;126;107m█[0m[38;2;150;127;108m█[0m[38;2;151;128;110m█[0m[38;2;151;129;110m█[0m[38;2;150;128;110m█[0m[38;2;149;127;109m█[0m[38;2;147;125;107m█[0m[38;2;145;123;105m█[0m[38;2;142;120;103m█[0m[38;2;139;118;101m█[0m[38;2;135;115;98m█[0m[38;2;131;112;95m█[0m[38;2;126;108;91m█[0m[38;2;123;105;88m█[0m[38;2;121;102;86m█[0m[38;2;121;102;87m█[0m[38;2;108;91;75m█[0m[38;2;105;89;73m█[0m[38;2;104;88;72m█[0m[38;2;102;88;73m█[0m[38;2;91;80;68m█[0m[38;2;85;77;78m█[0m[38;2;58;52;54m█[0m[38;2;33;28;26m█[0m[38;2;26;20;17m█[0m[38;2;24;21;20m█[0m[38;2;18;17;16m█[0m[38;2;15;13;13m█[0m[38;2;16;15;14m█[0m[38;2;20;19;17m█[0m[38;2;16;15;13m█[0m[38;2;21;18;17m█[0m[38;2;32;27;25m█[0m[38;2;57;48;43m█[0m[38;2;48;41;35m█[0m[38;2;19;17;16m█[0m[38;2;44;41;40m█[0m[38;2;27;26;24m█[0m[38;2;26;25;23m█[0m[38;2;36;36;33m█[0m[38;2;57;56;53m█[0m[38;2;73;74;69m█[0m[38;2;94;95;89m█[0m[38;2;115;116;108m█[0m[38;2;131;133;124m█[0m[38;2;139;141;133m█[0m[38;2;136;137;129m█[0m[38;2;124;125;117m█[0m[38;2;95;96;90m█[0m[38;2;57;57;54m█[0m");
$display("[38;2;142;126;110m█[0m[38;2;138;122;106m█[0m[38;2;137;121;105m█[0m[38;2;137;121;105m█[0m[38;2;138;121;105m█[0m[38;2;140;123;105m█[0m[38;2;143;125;107m█[0m[38;2;145;127;107m█[0m[38;2;146;128;107m█[0m[38;2;146;128;107m█[0m[38;2;148;126;108m█[0m[38;2;148;126;107m█[0m[38;2;147;125;107m█[0m[38;2;144;123;105m█[0m[38;2;142;121;103m█[0m[38;2;141;120;102m█[0m[38;2;140;119;102m█[0m[38;2;138;117;100m█[0m[38;2;134;115;98m█[0m[38;2;130;111;95m█[0m[38;2;126;107;91m█[0m[38;2;122;105;88m█[0m[38;2;120;103;87m█[0m[38;2;119;102;85m█[0m[38;2;116;99;83m█[0m[38;2;115;97;81m█[0m[38;2;110;93;77m█[0m[38;2;103;86;71m█[0m[38;2;92;78;64m█[0m[38;2;80;69;56m█[0m[38;2;73;63;54m█[0m[38;2;73;67;68m█[0m[38;2;71;65;70m█[0m[38;2;58;52;54m█[0m[38;2;51;45;45m█[0m[38;2;20;18;16m█[0m[38;2;16;15;14m█[0m[38;2;14;13;13m█[0m[38;2;18;17;14m█[0m[38;2;25;24;21m█[0m[38;2;29;26;24m█[0m[38;2;29;25;23m█[0m[38;2;34;29;26m█[0m[38;2;39;34;31m█[0m[38;2;38;34;30m█[0m[38;2;34;32;29m█[0m[38;2;31;30;28m█[0m[38;2;37;36;33m█[0m[38;2;55;53;49m█[0m[38;2;76;74;70m█[0m[38;2;86;86;84m█[0m[38;2;81;81;79m█[0m[38;2;78;78;76m█[0m[38;2;96;96;92m█[0m[38;2;117;118;110m█[0m[38;2;129;130;122m█[0m[38;2;139;140;132m█[0m[38;2;138;139;131m█[0m[38;2;131;133;124m█[0m[38;2;111;112;105m█[0m");
$display("[38;2;135;119;104m█[0m[38;2;134;118;102m█[0m[38;2;134;117;102m█[0m[38;2;136;119;102m█[0m[38;2;137;119;102m█[0m[38;2;137;118;101m█[0m[38;2;137;118;101m█[0m[38;2;138;119;102m█[0m[38;2;140;119;102m█[0m[38;2;140;120;102m█[0m[38;2;141;120;103m█[0m[38;2;141;121;103m█[0m[38;2;140;120;102m█[0m[38;2;139;118;100m█[0m[38;2;138;119;100m█[0m[38;2;139;119;101m█[0m[38;2;140;119;101m█[0m[38;2;139;118;100m█[0m[38;2;136;115;97m█[0m[38;2;130;111;93m█[0m[38;2;126;107;89m█[0m[38;2;121;103;86m█[0m[38;2;116;99;82m█[0m[38;2;110;94;78m█[0m[38;2;101;86;71m█[0m[38;2;94;81;66m█[0m[38;2;87;75;61m█[0m[38;2;78;66;54m█[0m[38;2;63;54;45m█[0m[38;2;47;41;34m█[0m[38;2;38;33;26m█[0m[38;2;39;35;29m█[0m[38;2;37;34;30m█[0m[38;2;28;27;23m█[0m[38;2;25;24;20m█[0m[38;2;17;16;14m█[0m[38;2;15;15;13m█[0m[38;2;13;13;12m█[0m[38;2;16;16;14m█[0m[38;2;29;27;23m█[0m[38;2;42;37;33m█[0m[38;2;43;38;33m█[0m[38;2;45;40;36m█[0m[38;2;49;44;40m█[0m[38;2;32;30;27m█[0m[38;2;42;41;38m█[0m[38;2;53;50;45m█[0m[38;2;70;67;61m█[0m[38;2;75;74;71m█[0m[38;2;81;80;78m█[0m[38;2;90;90;88m█[0m[38;2;89;89;87m█[0m[38;2;82;82;82m█[0m[38;2;85;85;84m█[0m[38;2;102;102;97m█[0m[38;2;121;122;114m█[0m[38;2;130;131;123m█[0m[38;2;136;137;129m█[0m[38;2;141;142;134m█[0m[38;2;140;141;133m█[0m");
$display("[38;2;128;111;98m█[0m[38;2;132;116;100m█[0m[38;2;135;118;102m█[0m[38;2;138;121;104m█[0m[38;2;141;123;105m█[0m[38;2;143;125;107m█[0m[38;2;141;122;104m█[0m[38;2;141;122;104m█[0m[38;2;142;122;104m█[0m[38;2;141;121;103m█[0m[38;2;138;119;101m█[0m[38;2;137;117;99m█[0m[38;2;135;115;97m█[0m[38;2;132;113;95m█[0m[38;2;125;107;89m█[0m[38;2;126;108;90m█[0m[38;2;120;103;86m█[0m[38;2;104;90;74m█[0m[38;2;91;80;64m█[0m[38;2;77;67;54m█[0m[38;2;67;58;47m█[0m[38;2;65;57;46m█[0m[38;2;66;58;46m█[0m[38;2;66;57;46m█[0m[38;2;65;56;46m█[0m[38;2;65;57;46m█[0m[38;2;59;53;42m█[0m[38;2;52;47;36m█[0m[38;2;47;42;35m█[0m[38;2;44;39;33m█[0m[38;2;40;35;30m█[0m[38;2;37;32;27m█[0m[38;2;30;27;23m█[0m[38;2;23;21;19m█[0m[38;2;18;17;15m█[0m[38;2;15;15;13m█[0m[38;2;15;15;13m█[0m[38;2;13;13;11m█[0m[38;2;15;15;13m█[0m[38;2;20;19;17m█[0m[38;2;21;18;15m█[0m[38;2;20;18;15m█[0m[38;2;21;20;17m█[0m[38;2;21;21;17m█[0m[38;2;35;32;27m█[0m[38;2;67;58;51m█[0m[38;2;73;61;52m█[0m[38;2;64;53;45m█[0m[38;2;77;73;69m█[0m[38;2;86;87;85m█[0m[38;2;82;82;80m█[0m[38;2;87;87;86m█[0m[38;2;90;90;89m█[0m[38;2;93;93;92m█[0m[38;2;91;91;88m█[0m[38;2;102;102;97m█[0m[38;2;120;121;113m█[0m[38;2;131;132;124m█[0m[38;2;137;138;130m█[0m[38;2;139;140;132m█[0m");
$display("\033[31m \033[5m     //   / /     //   ) )     //   ) )     //   ) )     //   ) )\033[0m");
$display("\033[31m \033[5m    //____       //___/ /     //___/ /     //   / /     //___/ /\033[0m");
$display("\033[31m \033[5m   / ____       / ___ (      / ___ (      //   / /     / ___ (\033[0m");
$display("\033[31m \033[5m  //           //   | |     //   | |     //   / /     //   | |\033[0m");
$display("\033[31m \033[5m //____/ /    //    | |    //    | |    ((___/ /     //    | |\033[0m");
end endtask;

endmodule



