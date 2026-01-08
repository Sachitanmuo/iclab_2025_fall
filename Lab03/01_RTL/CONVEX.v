/**************************************************************************/
// Copyright (c) 2025, OASIS Lab
// MODULE: CONVEX
// FILE NAME: CONVEX.v
// VERSRION: 1.0
// DATE: August 15, 2025
// AUTHOR: Chao-En Kuo, NYCU IAIS
// DESCRIPTION: ICLAB2025FALL / LAB3 / CONVEX
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/
module CONVEX (
	// Input
	rst_n,
	clk,
	in_valid,
	pt_num,
	in_x,
	in_y,
	// Output
	out_valid,
	out_x,
	out_y,
	drop_num
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input				rst_n;
input				clk;
input				in_valid;
input		[8:0]	pt_num;
input		[9:0]	in_x;
input		[9:0]	in_y;

output reg			out_valid;
output reg	[9:0]	out_x;
output reg 	[9:0]	out_y;
output reg	[6:0]	drop_num;


//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
parameter IDLE     = 3'd0,
		  INPUT    = 3'd1,
		  CROSS    = 3'd2,
		  INSERT   = 3'd3,
		  SHIFT    = 3'd4;


integer i, j, k;
parameter MAX_HULL_SIZE = 128;
//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg  [2:0]       cs, ns;
reg              cross_done;
reg	 		     out_valid_n;
reg	 [9:0]	     out_x_n;
reg  [9:0]	     out_y_n;
reg	 [6:0]	     drop_num_n;
reg  [8:0]       step_cnt, step_cnt_n;
reg  [7:0]       cross_cnt, cross_cnt_n;
reg  [7:0]       hull_size, hull_size_n;
reg  [9:0]       hull_x   [0:MAX_HULL_SIZE - 1];
reg  [9:0]       hull_y   [0:MAX_HULL_SIZE - 1];
reg  [9:0]       hull_x_n [0:MAX_HULL_SIZE - 1];
reg  [9:0]       hull_y_n [0:MAX_HULL_SIZE - 1];
reg  [8:0]       total_pt_num, total_pt_num_n;
reg  [9:0]       curr_x, curr_y, curr_x_n, curr_y_n;
reg  [1:0]       sign_bit;
reg  [9:0]       ax, ay, bx, by, cx, cy;
reg  [7:0]       c_idx;
reg  [7:0]       start_idx, start_idx_n, end_idx, end_idx_n;
reg              started, started_n;
reg              go_drop;
reg  [7:0]       insert_cnt, insert_cnt_n;
reg              insert_done, shift_done;
reg  [1:0]       cross_sign_first, cross_sign_first_n, cross_sign_prev, cross_sign_prev_n;
cross_ n_cross(.ax(ax), .ay(ay), .bx(bx), .by(by), .cx(cx), .cy(cy), .sign_bit(sign_bit));
    
//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------

// FSM

always@(negedge rst_n or posedge clk) begin
	if(!rst_n) begin
		cs  <= IDLE;
	end else begin
		cs  <= ns;
	end
end

always@ (*) begin
	ns = cs;
	case (cs)
		IDLE: begin
			if(in_valid) begin
				ns = CROSS;
			end else begin
				ns = cs;
			end
		end 

		INPUT: begin
			if(in_valid) begin
				ns = CROSS;
			end else begin
				ns = cs;
			end
		end

		CROSS: begin
			if(go_drop) begin
				if(step_cnt == total_pt_num - 1) begin
					ns = IDLE;
				end else begin
					ns = INPUT;
				end
			end else begin
				if(cross_cnt == hull_size) begin
					if(end_idx < start_idx) begin
						ns = SHIFT;						
					end else begin
						ns = INSERT;
					end
				end else begin
					ns = cs;
				end
			end
		end

		SHIFT: begin
			if(shift_done) begin
				ns = INSERT;
			end else begin
				ns = cs;
			end
		end

		INSERT: begin
			if(insert_done) begin
				if(step_cnt == total_pt_num - 1) begin
					ns = IDLE;
				end else begin
					ns = INPUT;
				end
			end else begin
				ns = cs;
			end
		end

	endcase
end

// Sequential 
always @(negedge rst_n or posedge clk) begin
	if(!rst_n) begin
		out_valid         <= 0;
		out_x             <= 0;
		out_y             <= 0;
		drop_num          <= 0;
		step_cnt          <= 0;
		total_pt_num      <= 0;
		curr_x            <= 0;
		curr_y            <= 0;
		cross_cnt         <= 0;
		hull_size         <= 0;
		start_idx         <= 0;
	    end_idx           <= 0;
		started           <= 0;
		insert_cnt        <= 0;
		cross_sign_first  <= 0;
		cross_sign_prev   <= 0;
		for(i = 0; i      < MAX_HULL_SIZE; i = i + 1) begin
			hull_x[i]     <= 0;
			hull_y[i]     <= 0;
		end
	end else begin
		out_valid        <= out_valid_n;
		out_x            <= out_x_n;
		out_y            <= out_y_n;
		drop_num         <= drop_num_n;
		step_cnt         <= step_cnt_n;
		hull_x           <= hull_x_n;
		hull_y           <= hull_y_n;
		total_pt_num     <= total_pt_num_n;
		curr_x           <= curr_x_n;
		curr_y           <= curr_y_n;
		cross_cnt        <= cross_cnt_n;
		hull_size        <= hull_size_n;
		start_idx        <= start_idx_n;
		end_idx          <= end_idx_n;
		started          <= started_n;
		insert_cnt       <= insert_cnt_n;
		cross_sign_first <= cross_sign_first_n;
		cross_sign_prev  <= cross_sign_prev_n;
	end
end

// Combinational
always @(*) begin
	out_valid_n        = 0;
	out_x_n            = 0;
	out_y_n            = 0;
	drop_num_n         = 0;
	step_cnt_n         = step_cnt;
	hull_x_n           = hull_x;
	hull_y_n           = hull_y;
	hull_size_n        = hull_size;
	total_pt_num_n     = total_pt_num;
	curr_x_n           = curr_x;
	curr_y_n           = curr_y;
	cross_cnt_n        = cross_cnt;
	start_idx_n        = start_idx;
    end_idx_n          = end_idx;
	started_n          = started;
	insert_cnt_n       = insert_cnt;
	cross_sign_first_n = cross_sign_first;
	cross_sign_prev_n  = cross_sign_prev;
	cross_done         = 0;
	shift_done         = 0;
	insert_done        = 0;
	go_drop            = 0;
	ax                 = 0;
	ay                 = 0;
	bx                 = 0;
	by                 = 0;
	cx                 = 0;
	cy                 = 0;
	if(cs == IDLE) begin
		cross_cnt_n  = 0;
		hull_size_n  = 0;
		start_idx_n  = 0;
		end_idx_n    = 0;
		started_n    = 0;
		go_drop      = 0;
		insert_cnt_n = 0;
		cross_sign_first_n = 0;
		cross_sign_prev_n  = 0;
		for(i = 0; i < MAX_HULL_SIZE; i = i + 1) begin
			hull_x_n[i]     = 0;
			hull_y_n[i]     = 0;
		end
		if(in_valid) begin
			step_cnt_n     = 0;
			curr_x_n       = in_x;
			curr_y_n       = in_y; 
			total_pt_num_n = pt_num;
		end
		
	end

	if(cs == INPUT) begin
		if(in_valid) begin
			curr_x_n         = in_x;
			curr_y_n         = in_y;
		end
		//step_cnt_n       = step_cnt + 1;
		cross_cnt_n        = 0;
		start_idx_n        = 0;
		end_idx_n          = 0;
		started_n          = 0;
		go_drop            = 0;
		out_valid_n        = 0;
		out_x_n            = 0;
		out_y_n            = 0;
		drop_num_n         = 0;
		cross_sign_first_n = 0;
		cross_sign_prev_n  = 0;
	end

	if(cs == CROSS) begin
		if(step_cnt == 0) begin
			hull_x_n[0] = curr_x;
			hull_y_n[0] = curr_y;
			hull_size_n = 1;
			cross_done  = 1;
			out_valid_n = 1;
			out_x_n     = 0;
			out_y_n     = 0;
			drop_num_n  = 0;
			go_drop     = 1;
			step_cnt_n  = 1;
		end else if(step_cnt == 1) begin
			hull_x_n[1] = curr_x;
			hull_y_n[1] = curr_y;
			hull_size_n = 2;
			cross_done  = 1;
			out_valid_n = 1;
			out_x_n     = 0;
			out_y_n     = 0;
			drop_num_n  = 0;
			go_drop     = 1;
			step_cnt_n  = 2;
		end else if(step_cnt == 2) begin
			ax = hull_x[0];
			ay = hull_y[0];
			bx = hull_x[1];
			by = hull_y[1];
			cx = curr_x;
			cy = curr_y;
			
			if(sign_bit == 2'b00) begin //positive: counter-clockwise, no need to change order
				hull_x_n[2] = curr_x;
				hull_y_n[2] = curr_y;
				hull_x_n[1] = hull_x[1];
				hull_y_n[1] = hull_y[1];
			end else if(sign_bit == 2'b01) begin //negative: clockwise, need to change order
				hull_x_n[1] = curr_x;
				hull_y_n[1] = curr_y;
				hull_x_n[2] = hull_x[1];
				hull_y_n[2] = hull_y[1];
			end
			hull_size_n  = 3;
			cross_done   = 1;
			out_valid_n  = 1;
			out_x_n      = 0;
			out_y_n      = 0;
			drop_num_n   = 0;
			go_drop      = 1;
			step_cnt_n   = 3;

		end else if(cross_cnt < hull_size) begin
			//cross calculation
			c_idx = cross_cnt + 1 == hull_size ? 0 : cross_cnt + 1;
			ax = hull_x[cross_cnt];
			ay = hull_y[cross_cnt];
			bx = hull_x[c_idx];
			by = hull_y[c_idx];
			cx = curr_x;
			cy = curr_y;
			cross_sign_prev_n   = sign_bit;
			if(cross_cnt == 0) cross_sign_first_n = sign_bit;
			cross_cnt_n = cross_cnt + 1;
			if(sign_bit == 2'b10) begin //drop the new point
				drop_num_n  = 1;
				out_x_n     = curr_x;
				out_y_n     = curr_y;
				go_drop     = 1;
				out_valid_n = 1;
				step_cnt_n  = step_cnt + 1;
			end else if(sign_bit[0] == 1) begin //drop the old points
				started_n = 1;
				if(cross_cnt != 0) begin
					if(sign_bit[0] == 1 && cross_sign_prev == 0) begin //twist point, let it  be starter
						start_idx_n = c_idx;
					end
				end
			end else if(sign_bit == 0) begin
				if(cross_cnt != 0) begin
					if(sign_bit[0] == 0 && cross_sign_prev[0] == 1) begin //twist point, let it be end // 1 -> 0
						end_idx_n = cross_cnt;
						started_n = 1;
					end
				end
			end

			if(cross_cnt == hull_size - 1) begin // all sign calculation done, should do the final check. (until now we know cross_sign[0])
				insert_cnt_n = start_idx;
				if(sign_bit[0] == 1 && cross_sign_first == 0) begin // idx 0 is the end_idx
					end_idx_n    = 0;
				end else if(sign_bit == 0 && cross_sign_first[0] == 1) begin
					start_idx_n  = 1;
					insert_cnt_n = 1;
				end else if(!started) begin // drop the new point
					drop_num_n  = 1;
					out_x_n     = curr_x;
					out_y_n     = curr_y;
					go_drop     = 1;
					out_valid_n = 1;
					step_cnt_n  = step_cnt + 1;
				end
				// the insert_cnt will start from the start_idx, iterate until the end_idx		
			end
		end else begin
			cross_done = 1;
		end
	end

	if(cs ==SHIFT) begin //shift until start_idx to zero
		if(start_idx <= end_idx) begin
			shift_done = 1;
			insert_cnt_n = 0;
		end else begin
			start_idx_n = start_idx + 1 == hull_size ? 0 : start_idx + 1;
			end_idx_n = (end_idx + 1 == hull_size) ? 0 : (end_idx + 1);
			for(i = 1; i < MAX_HULL_SIZE;i = i + 1) begin
				hull_x_n[i] = hull_x[i - 1];
				hull_y_n[i] = hull_y[i - 1];
			end
			hull_x_n[0] = hull_x[hull_size - 1];
			hull_y_n[0] = hull_y[hull_size - 1];
			if(hull_size < MAX_HULL_SIZE) begin
				hull_x_n[hull_size] = 0;
				hull_y_n[hull_size] = 0;
			end
			
		end
		
	end


	if(cs == INSERT) begin
		if(start_idx == end_idx) begin // only insert the current point, do not need to pop any point.
			for(i = 1; i < MAX_HULL_SIZE; i = i + 1) begin
				hull_x_n[i] = i <= start_idx ? hull_x[i] : hull_x[i-1]; //right push one  
				hull_y_n[i] = i <= start_idx ? hull_y[i] : hull_y[i-1];
			end
			hull_x_n[start_idx] = curr_x;
			hull_y_n[start_idx] = curr_y;
			insert_cnt_n        = insert_cnt + 1; //after shift, it will now overflow (maybe?)
			step_cnt_n          = step_cnt   + 1;
			hull_size_n = hull_size + 1;
			insert_done = 1;
			out_valid_n = 1;
			out_x_n     = 0;
			out_y_n     = 0;
			drop_num_n  = 0;
		end else if(end_idx - start_idx == 1) begin //replace the dropped point to be the new point
			hull_x_n[start_idx] = curr_x;
			hull_y_n[start_idx] = curr_y;
			drop_num_n          = 1;
			out_x_n             = hull_x[start_idx];
			out_y_n             = hull_y[start_idx];
			out_valid_n         = 1;
			insert_cnt_n        = insert_cnt + 1;
			insert_done         = 1;
			step_cnt_n          = step_cnt + 1;
		end else begin
			out_valid_n   = 1;
			drop_num_n    = end_idx - start_idx;
			out_x_n       = hull_x[start_idx];
			out_y_n       = hull_y[start_idx];
			insert_cnt_n  = insert_cnt + 1;
			
			if(insert_cnt == end_idx - 1) begin
				insert_done         = 1;
				step_cnt_n          = step_cnt + 1;
				hull_x_n[start_idx] = curr_x;
				hull_y_n[start_idx] = curr_y;
				hull_size_n         = hull_size - (end_idx - start_idx) + 1;
				step_cnt_n          = step_cnt + 1;
			end else begin
				for(i = 0; i < MAX_HULL_SIZE - 1; i = i + 1) begin
					hull_x_n[i] = i < start_idx ? hull_x[i] : hull_x[i+1];
					hull_y_n[i] = i < start_idx ? hull_y[i] : hull_y[i+1];
				end
				hull_x_n[MAX_HULL_SIZE - 1] = 0;
				hull_y_n[MAX_HULL_SIZE - 1] = 0;

			end
		end
	end
end

endmodule

module cross_ (
	input      [9:0] ax,
	input      [9:0] ay,
	input      [9:0] bx,
	input      [9:0] by,
	input      [9:0] cx,
	input      [9:0] cy,
	output reg [1:0] sign_bit
);
	// 00: positive
	// 01: negative
	// 10: cross = 0, and the new added point is between two original points on the hull -> pop the new point
	// 11: cross = 0, and the new added point can cause a point on the hull to be on the vertax -> drop that point

	wire signed [10:0] dx_ab = $signed({1'b0, bx}) - $signed({1'b0, ax});
	wire signed [10:0] dy_ab = $signed({1'b0, by}) - $signed({1'b0, ay});
	wire signed [10:0] dx_ac = $signed({1'b0, cx}) - $signed({1'b0, ax});
	wire signed [10:0] dy_ac = $signed({1'b0, cy}) - $signed({1'b0, ay});

	wire signed [22:0] cross_val = dx_ab * dy_ac - dy_ab * dx_ac;
	
	wire [9:0] minx     = (ax < bx) ? ax : bx;
    wire [9:0] maxx     = (ax > bx) ? ax : bx;
    wire [9:0] miny     = (ay < by) ? ay : by;
    wire [9:0] maxy     = (ay > by) ? ay : by;
	wire       c_on_seg = (cx>=minx && cx<=maxx && cy>=miny && cy<=maxy);

    always @(*) begin
        if      (cross_val > 0) sign_bit = 2'b00;        // left turn
        else if (cross_val < 0) sign_bit = 2'b01;        // right turn
        else begin
            sign_bit = c_on_seg ? 2'b10
                                 : 2'b11;
        end
    end
	
endmodule