//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   ICLAB 2025 Fall 
// Lab11 Exercise : Geometric Transform Engine (GTE)
//      File Name : GTE.v
//    Module Name : GTE
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module GTE(
    // input signals
    clk,
    rst_n,
	
    in_valid_data,
	data,
	
    in_valid_cmd,
    cmd,    
	
    // output signals
    busy
);

input              clk;
input              rst_n;

input              in_valid_data;
input       [7:0]  data;

input              in_valid_cmd;
input      [17:0]  cmd;

output reg         busy;

//==================================================================
// parameter & integer
//==================================================================
parameter IDLE         =  0,
		  INPUT_MEM0   =  1,
		  INPUT_MEM1   =  2,
		  INPUT_MEM2   =  3,
		  INPUT_MEM3   =  4,
		  INPUT_MEM4   =  5,
		  INPUT_MEM5   =  6,
		  INPUT_MEM6   =  7,
		  INPUT_MEM7   =  8,
		  WAIT         =  9,
		  READ         = 10,
		  CALC         = 11,
		  WRITE        = 12,
		  OUT          = 13;

integer i, j, k;

//==================================================================
// reg & wire
//==================================================================
reg [3:0] cs, ns;

reg stall, stall_n;
// -----------------------------------------------------
// MEM
// -----------------------------------------------------

// MEM_0, MEM_1, MEM_2, MEM_3: 8-bit width, 4096 depth
reg        mem0_web, mem1_web, mem2_web, mem3_web;
reg [11:0] mem0_addr, mem1_addr, mem2_addr, mem3_addr;
reg  [7:0] mem0_din, mem1_din, mem2_din, mem3_din;
reg  [7:0] mem0_dout, mem1_dout, mem2_dout, mem3_dout;

// MEM_4, MEM_5: 16-bit width, 2048 depth
reg        mem4_web, mem5_web;
reg [10:0] mem4_addr, mem5_addr;
reg [15:0] mem4_din, mem5_din;
reg [15:0] mem4_dout, mem5_dout;

// MEM_6, MEM_7: 32-bit width, 1024 depth
reg        mem6_web, mem7_web;
reg  [9:0] mem6_addr, mem7_addr;
reg [31:0] mem6_din, mem7_din;
reg [31:0] mem6_dout, mem7_dout;

// MEM_0, MEM_1, MEM_2, MEM_3: 8-bit width, 4096 depth
reg        mem0_web_n, mem1_web_n, mem2_web_n, mem3_web_n;
reg [11:0] mem0_addr_n, mem1_addr_n, mem2_addr_n, mem3_addr_n;
reg  [7:0] mem0_din_n, mem1_din_n, mem2_din_n, mem3_din_n;

// MEM_4, MEM_5: 16-bit width, 2048 depth
reg        mem4_web_n, mem5_web_n;
reg [10:0] mem4_addr_n, mem5_addr_n;
reg [15:0] mem4_din_n, mem5_din_n;

// MEM_6, MEM_7: 32-bit width, 1024 depth
reg        mem6_web_n, mem7_web_n;
reg  [9:0] mem6_addr_n, mem7_addr_n;
reg [31:0] mem6_din_n, mem7_din_n;

reg  [7:0] mem0_dout_reg, mem1_dout_reg, mem2_dout_reg, mem3_dout_reg;
reg [15:0] mem4_dout_reg, mem5_dout_reg;
reg [31:0] mem6_dout_reg, mem7_dout_reg;



reg [11:0] addr_ctr, addr_ctr_n;

reg [17:0] cmd_reg, cmd_reg_n;

reg busy_n;

reg [7:0] IMG  [0:15][0:15];
reg [7:0] IMG_n[0:15][0:15];

//reg [7:0] SRC  [0:15][0:15];
//reg [7:0] SRC_n[0:15][0:15];

wire [1:0] op_code;
wire [1:0] func;
wire [6:0] ms;
wire [6:0] md;

assign op_code = cmd_reg[17:16];
assign func    = cmd_reg[15:14];
assign ms      = cmd_reg[13: 7];
assign md      = cmd_reg[ 6: 0];

reg  [7:0] idx, idx_n;

wire [7:0] idx_plus1;
wire [7:0] idx_plus2;
wire [7:0] idx_plus3;

wire [2:0] debug_num;
assign debug_num = ms[6:4];
assign idx_plus1 = idx + 1;
assign idx_plus2 = idx + 2;
assign idx_plus3 = idx + 3;
genvar gi, gj;
generate
	for(gi = 0; gi < 16;gi = gi + 1) begin
		for(gj = 0; gj < 16; gj = gj + 1) begin
			always @(posedge clk or negedge rst_n) begin
				if(!rst_n) begin
					IMG[gi][gj]   <= 0;
				end else begin
					IMG[gi][gj]   <= IMG_n[gi][gj];
				end
			end
			//always @(posedge clk or negedge rst_n) begin
			//	if(!rst_n) begin
			//		SRC[gi][gj]   <= 0;
			//	end else begin
			//		SRC[gi][gj]   <= SRC_n[gi][gj];
			//	end
			//end
		end
	end
endgenerate

//==================================================================
// design
//==================================================================

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cs <= IDLE;
	end else begin
		cs <= ns;
	end
end

always @(*) begin
	ns = cs;
	case (cs)
		IDLE: begin
			if(in_valid_data) begin
				ns = INPUT_MEM0;
			end
			if(in_valid_cmd) begin
				ns = READ;
				//if(cmd[13:7] == md || cmd[13:7] == ms) begin
				//	ns = CALC;
				//	//$display("HIT!!!!!!!!!!!!!");
				//end
			end
		end

		INPUT_MEM0: begin
			if(addr_ctr == 4095) begin
				ns = INPUT_MEM1;
			end
		end
		INPUT_MEM1: begin
			if(addr_ctr == 4095) begin
				ns = INPUT_MEM2;
			end
		end
		INPUT_MEM2: begin
			if(addr_ctr == 4095) begin
				ns = INPUT_MEM3;
			end
		end
		INPUT_MEM3: begin
			if(mem3_addr == 4094) begin
				ns = INPUT_MEM4;
			end
		end
		INPUT_MEM4: begin
			if(addr_ctr == 4095) begin
				ns = INPUT_MEM5;
			end
		end
		INPUT_MEM5: begin
			if(addr_ctr == 4095) begin
				ns = INPUT_MEM6;
			end
		end
		INPUT_MEM6: begin
			if(addr_ctr == 4095) begin
				ns = INPUT_MEM7;
			end
		end
		INPUT_MEM7: begin
			if(addr_ctr == 4095) begin
				ns = IDLE;
			end
		end
		//WAIT: begin
		//	if(in_valid_cmd) begin
		//		ns = READ;
		//	end
		//end
		READ: begin
			case (ms[6:4])
				0, 1, 2, 3: begin
					if(idx == 255) ns = CALC; 
				end
				4, 5: begin
					if(idx == 254) ns = CALC; 
				end
				6, 7: begin
					if(idx == 252) ns = CALC;
				end
			endcase
		end
		CALC: begin
			ns = WRITE;
		end
		WRITE: begin
			case (md[6:4])
				0, 1, 2, 3: begin
					if(idx == 255) ns = OUT; 
				end
				4, 5: begin
					if(idx == 254) ns = OUT; 
				end
				6, 7: begin
					if(idx == 252) ns = OUT;
				end
			endcase
		end
		OUT: begin
			if(stall) ns = IDLE;
		end
	endcase
end


// SEQUENTIAL
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		mem0_web          <= 1;
		mem1_web          <= 1;
		mem2_web          <= 1;
		mem3_web          <= 1;
		mem4_web          <= 1;
		mem5_web          <= 1;
		mem6_web          <= 1;
		mem7_web          <= 1;

		mem0_addr         <= 0;
		mem1_addr         <= 0;
		mem2_addr         <= 0;
		mem3_addr         <= 0;
		mem4_addr         <= 0;
		mem5_addr         <= 0;
		mem6_addr         <= 0;
		mem7_addr         <= 0;

		mem0_din          <= 0;
		mem1_din          <= 0;
		mem2_din          <= 0;
		mem3_din          <= 0;
		mem4_din          <= 0;
		mem5_din          <= 0;
		mem6_din          <= 0;
		mem7_din          <= 0;

		addr_ctr          <= 0;
		cmd_reg           <= 0;
		busy              <= 1;

		mem0_dout_reg     <= 0;
		mem1_dout_reg     <= 0;
		mem2_dout_reg     <= 0;
		mem3_dout_reg     <= 0;
		mem4_dout_reg     <= 0;
		mem5_dout_reg     <= 0;
		mem6_dout_reg     <= 0;
		mem7_dout_reg     <= 0;
		idx               <= 0;
		stall             <= 0;
	end else begin
		mem0_web          <= mem0_web_n;
		mem1_web          <= mem1_web_n;
		mem2_web          <= mem2_web_n;
		mem3_web          <= mem3_web_n;
		mem4_web          <= mem4_web_n;
		mem5_web          <= mem5_web_n;
		mem6_web          <= mem6_web_n;
		mem7_web          <= mem7_web_n;

		mem0_addr         <= mem0_addr_n;
		mem1_addr         <= mem1_addr_n;
		mem2_addr         <= mem2_addr_n;
		mem3_addr         <= mem3_addr_n;
		mem4_addr         <= mem4_addr_n;
		mem5_addr         <= mem5_addr_n;
		mem6_addr         <= mem6_addr_n;
		mem7_addr         <= mem7_addr_n;

		mem0_din          <= mem0_din_n;
		mem1_din          <= mem1_din_n;
		mem2_din          <= mem2_din_n;
		mem3_din          <= mem3_din_n;
		mem4_din          <= mem4_din_n;
		mem5_din          <= mem5_din_n;
		mem6_din          <= mem6_din_n;
		mem7_din          <= mem7_din_n;

		addr_ctr          <= addr_ctr_n;
		cmd_reg           <= cmd_reg_n;
		busy              <= busy_n;

		mem0_dout_reg     <= mem0_dout;
		mem1_dout_reg     <= mem1_dout;
		mem2_dout_reg     <= mem2_dout;
		mem3_dout_reg     <= mem3_dout;
		mem4_dout_reg     <= mem4_dout;
		mem5_dout_reg     <= mem5_dout;
		mem6_dout_reg     <= mem6_dout;
		mem7_dout_reg     <= mem7_dout;
		idx               <= idx_n;
		stall             <= stall_n;
	end
end

// COMBINATIONAL
always @(*) begin
	mem0_din_n  = 0;
	mem1_din_n  = 0;
	mem2_din_n  = 0;
	mem3_din_n  = 0;
	mem4_din_n  = 0;
	mem5_din_n  = 0;
	mem6_din_n  = 0;
	mem7_din_n  = 0;
	mem0_addr_n = mem0_addr;
	mem1_addr_n = mem1_addr;
	mem2_addr_n = mem2_addr;
	mem3_addr_n = mem3_addr;
	mem4_addr_n = mem4_addr;
	mem5_addr_n = mem5_addr;
	mem6_addr_n = mem6_addr;
	mem7_addr_n = mem7_addr;
	mem0_web_n  = 1;
	mem1_web_n  = 1;
	mem2_web_n  = 1;
	mem3_web_n  = 1;
	mem4_web_n  = 1;
	mem5_web_n  = 1;
	mem6_web_n  = 1;
	mem7_web_n  = 1;
	addr_ctr_n  = addr_ctr;
	cmd_reg_n   = cmd_reg;
	busy_n      = 1;
	idx_n       = idx;
	IMG_n       = IMG;
	//SRC_n       = SRC;
	stall_n     = 0;

	if(cs == IDLE) begin
		addr_ctr_n     = 0;
		idx_n          = 0;
		if(in_valid_data) begin
			mem0_web_n  = 0;
			mem0_addr_n = 0;
			addr_ctr_n  = 1;
			mem0_din_n  = data;
		end
		if(in_valid_cmd) begin
			cmd_reg_n   = cmd;
			//if(cmd[13: 7] == ms) begin
			//	IMG_n = SRC;
			//end
		end
	end

	if(cs == INPUT_MEM0) begin
		mem0_web_n      = 0;
		mem0_addr_n     = addr_ctr;
		mem0_din_n      = data;
		addr_ctr_n      = addr_ctr + 1;
		if(addr_ctr == 4095) begin
			addr_ctr_n = 0;
			mem0_web_n = 0;
		end
	end
	if(cs == INPUT_MEM1) begin
		mem1_web_n      = 0;
		mem1_addr_n     = addr_ctr;
		mem1_din_n      = data;
		addr_ctr_n      = addr_ctr + 1;
		if(addr_ctr == 4095) begin
			addr_ctr_n = 0;
			mem1_web_n = 0;
		end
	end
	if(cs == INPUT_MEM2) begin
		mem2_web_n      = 0;
		mem2_addr_n     = addr_ctr;
		mem2_din_n      = data;
		addr_ctr_n      = addr_ctr + 1;
		if(addr_ctr == 4095) begin
			addr_ctr_n = 0;
			mem2_web_n = 0;
		end
	end
	if(cs == INPUT_MEM3) begin
		mem3_web_n      = 0;
		mem3_addr_n     = addr_ctr;
		mem3_din_n      = data;
		addr_ctr_n      = addr_ctr + 1;
		if(addr_ctr == 4095) begin
			addr_ctr_n = 0;
			mem3_web_n = 0;
		end
	end
	if(cs == INPUT_MEM4) begin
		addr_ctr_n      = addr_ctr + 1;
		mem4_web_n      = !addr_ctr[0];
		mem4_addr_n     = addr_ctr[11:1];
		if(addr_ctr[0] == 0) begin
			mem4_din_n[15:8] = data;
			mem4_din_n[ 7:0] = mem4_din[7:0]; 
		end else begin
			mem4_din_n[15:8] = mem4_din[15:8];
			mem4_din_n[ 7:0] = data;
		end
		if(addr_ctr == 4095) begin
			addr_ctr_n = 0;
			mem4_web_n = 0;
		end
	end
	if(cs == INPUT_MEM5) begin
		addr_ctr_n      = addr_ctr + 1;
		mem5_web_n      = !addr_ctr[0];
		mem5_addr_n     = addr_ctr[11:1];
		if(addr_ctr[0] == 0) begin
			mem5_din_n[15:8] = data;
			mem5_din_n[ 7:0] = mem5_din[7:0]; 
		end else begin
			mem5_din_n[15:8] = mem5_din[15:8];
			mem5_din_n[ 7:0] = data;
		end
		if(addr_ctr == 4095) begin
			addr_ctr_n = 0;
			mem5_web_n = 0;
		end
	end
	if(cs == INPUT_MEM6) begin
		addr_ctr_n      = addr_ctr + 1;
		mem6_web_n      = !(addr_ctr[1:0] == 2'b11);
		mem6_addr_n     = addr_ctr[11:2];
		case (addr_ctr[1:0])
			2'b00: begin
				mem6_din_n        = mem6_din;
				mem6_din_n[31:24] = data;
			end
			2'b01: begin
				mem6_din_n        = mem6_din;
				mem6_din_n[23:16] = data;
			end
			2'b10: begin
				mem6_din_n        = mem6_din;
				mem6_din_n[15: 8] = data;
			end
			2'b11: begin
				mem6_din_n        = mem6_din;
				mem6_din_n[ 7: 0] = data;
			end
		endcase
		if(addr_ctr == 4095) begin
			addr_ctr_n = 0;
			mem6_web_n = 0;
		end
	end
	if(cs == INPUT_MEM7) begin
		addr_ctr_n      = addr_ctr + 1;
		mem7_web_n      = !(addr_ctr[1:0] == 2'b11);
		mem7_addr_n     = addr_ctr[11:2];
		case (addr_ctr[1:0])
			2'b00: begin
				mem7_din_n        = mem7_din;
				mem7_din_n[31:24] = data;
			end
			2'b01: begin
				mem7_din_n        = mem7_din;
				mem7_din_n[23:16] = data;
			end
			2'b10: begin
				mem7_din_n        = mem7_din;
				mem7_din_n[15: 8] = data;
			end
			2'b11: begin
				mem7_din_n        = mem7_din;
				mem7_din_n[ 7: 0] = data;
			end
		endcase
		if(addr_ctr == 4095) begin
			addr_ctr_n = 0;
			mem7_web_n = 0;
		end
	end

	//if(cs == WAIT) begin
	//	idx_n          = 0;
	//	addr_ctr_n     = 0;
	//	if(in_valid_cmd) begin
	//		cmd_reg_n   = cmd;
	//	end
	//end

	if(cs == READ) begin
		addr_ctr_n  = addr_ctr + 1;
		case (ms[6:4])
			0: begin
				mem0_addr_n = (ms[3:0] << 8) + addr_ctr; 
			end
			1: begin
				mem1_addr_n = (ms[3:0] << 8) + addr_ctr;
			end
			2: begin
				mem2_addr_n = (ms[3:0] << 8) + addr_ctr;
			end
			3: begin
				mem3_addr_n = (ms[3:0] << 8) + addr_ctr;
			end
			4: begin
				mem4_addr_n = (ms[3:0] << 7) + addr_ctr;
			end
			5: begin
				mem5_addr_n = (ms[3:0] << 7) + addr_ctr;
			end
			6: begin
				mem6_addr_n = (ms[3:0] << 6) + addr_ctr;
			end
			7: begin
				mem7_addr_n = (ms[3:0] << 6) + addr_ctr;
			end
		endcase
		if(addr_ctr > 2) begin
			case (ms[6:4])
			0: begin
				idx_n = idx + 1;
				IMG_n[idx[7:4]][idx[3:0]] = mem0_dout_reg;
			end
			1: begin
				idx_n = idx + 1;
				IMG_n[idx[7:4]][idx[3:0]] = mem1_dout_reg;
			end
			2: begin
				idx_n = idx + 1;
				IMG_n[idx[7:4]][idx[3:0]] = mem2_dout_reg;
			end
			3: begin
				idx_n = idx + 1;
				IMG_n[idx[7:4]][idx[3:0]] = mem3_dout_reg;
			end
			4: begin
				idx_n = idx + 2;
				IMG_n[idx      [7:4]][idx      [3:0]] = mem4_dout_reg[15: 8];
				IMG_n[idx_plus1[7:4]][idx_plus1[3:0]] = mem4_dout_reg[ 7: 0];
			end
			5: begin
				idx_n = idx + 2;
				IMG_n[idx      [7:4]][idx      [3:0]] = mem5_dout_reg[15: 8];
				IMG_n[idx_plus1[7:4]][idx_plus1[3:0]] = mem5_dout_reg[ 7: 0];
			end
			6: begin
				idx_n = idx + 4;
				IMG_n[idx      [7:4]][idx      [3:0]] = mem6_dout_reg[31:24];
				IMG_n[idx_plus1[7:4]][idx_plus1[3:0]] = mem6_dout_reg[23:16];
				IMG_n[idx_plus2[7:4]][idx_plus2[3:0]] = mem6_dout_reg[15: 8];
				IMG_n[idx_plus3[7:4]][idx_plus3[3:0]] = mem6_dout_reg[ 7: 0];
			end
			7: begin
				idx_n = idx + 4;
				IMG_n[idx      [7:4]][idx      [3:0]] = mem7_dout_reg[31:24];
				IMG_n[idx_plus1[7:4]][idx_plus1[3:0]] = mem7_dout_reg[23:16];
				IMG_n[idx_plus2[7:4]][idx_plus2[3:0]] = mem7_dout_reg[15: 8];
				IMG_n[idx_plus3[7:4]][idx_plus3[3:0]] = mem7_dout_reg[ 7: 0];
			end
		endcase
		end
	end
	if(cs == CALC) begin
		addr_ctr_n = 0;
		idx_n      = 0;
		//SRC_n      = IMG;
		case ({op_code, func})
			4'b0000: begin
				for(i = 0; i < 16; i = i + 1) begin
					for(j = 0; j < 16; j = j + 1) begin
						IMG_n[i][j] = IMG[15 - i][j];
					end
				end
			end
			4'b0001: begin
				for(i = 0; i < 16; i = i + 1) begin
					for(j = 0; j < 16; j = j + 1) begin
						IMG_n[i][j] = IMG[i][15 - j];
					end
				end
			end
			4'b0010: begin
				for(i = 0; i < 16; i = i + 1) begin
					for(j = 0; j < 16; j = j + 1) begin
						IMG_n[i][j] = IMG[j][i];
					end
				end
			end
			4'b0011: begin
				for(i = 0; i < 16; i = i + 1) begin
					for(j = 0; j < 16; j = j + 1) begin
						IMG_n[i][j] = IMG[15 - j][15 - i];
					end
				end
			end
			4'b0100: begin
				for (i = 0; i < 16; i = i + 1) begin
					for (j = 0; j < 16; j = j + 1) begin
						IMG_n[i][j] = IMG[15 - j][i];
					end
				end
			end
			4'b0101: begin
				for (i = 0; i < 16; i = i + 1) begin
					for (j = 0; j < 16; j = j + 1) begin
						IMG_n[i][j] = IMG[15 - i][15 - j];
					end
				end
			end
			4'b0110: begin
				for (i = 0; i < 16; i = i + 1) begin
					for (j = 0; j < 16; j = j + 1) begin
						IMG_n[i][j] = IMG[j][15 - i];
					end
				end
			end
			4'b0111: begin
				IMG_n = IMG;
			end
			4'b1000: begin // RIGHT SHIFT
				for (i = 0; i < 16; i = i + 1) begin
					for (j = 0; j < 16; j = j + 1) begin
						if (j >= 5) begin
							IMG_n[i][j] = IMG[i][j - 5];
						end
						else begin
							IMG_n[i][j] = IMG[i][4 - j];
						end
					end
				end
			end
			4'b1001: begin // LEFT SHIFT
				for (i = 0; i < 16; i = i + 1) begin
					for (j = 0; j < 16; j = j + 1) begin
						if (j <= 10) begin
							IMG_n[i][j] = IMG[i][j + 5];
						end
						else begin
							IMG_n[i][j] = IMG[i][26 - j];
						end
					end
				end
			end
			4'b1010: begin // UP SHIFT
				for (i = 0; i < 16; i = i + 1) begin
					for (j = 0; j < 16; j = j + 1) begin
						if (i <= 10) begin
							IMG_n[i][j] = IMG[i + 5][j];
						end else begin
							IMG_n[i][j] = IMG[26 - i][j];
						end
					end
				end
			end
			4'b1011: begin // DOWN SHIFT
				for (i = 0; i < 16; i = i + 1) begin
					for (j = 0; j < 16; j = j + 1) begin
						if (i >= 5) begin
							IMG_n[i][j] = IMG[i - 5][j];
						end
						else begin
							IMG_n[i][j] = IMG[4 - i][j];
						end
					end
				end
			end
			4'b1100: begin
				// Block at row 0..3, col 0..3
				IMG_n[ 0][ 0]          = IMG[ 0][ 0];
				IMG_n[ 0][ 1]          = IMG[ 0][ 1];
				IMG_n[ 0][ 2]          = IMG[ 1][ 0];
				IMG_n[ 0][ 3]          = IMG[ 2][ 0];
				IMG_n[ 1][ 0]          = IMG[ 1][ 1];
				IMG_n[ 1][ 1]          = IMG[ 0][ 2];
				IMG_n[ 1][ 2]          = IMG[ 0][ 3];
				IMG_n[ 1][ 3]          = IMG[ 1][ 2];
				IMG_n[ 2][ 0]          = IMG[ 2][ 1];
				IMG_n[ 2][ 1]          = IMG[ 3][ 0];
				IMG_n[ 2][ 2]          = IMG[ 3][ 1];
				IMG_n[ 2][ 3]          = IMG[ 2][ 2];
				IMG_n[ 3][ 0]          = IMG[ 1][ 3];
				IMG_n[ 3][ 1]          = IMG[ 2][ 3];
				IMG_n[ 3][ 2]          = IMG[ 3][ 2];
				IMG_n[ 3][ 3]          = IMG[ 3][ 3];

				// Block at row 0..3, col 4..7
				IMG_n[ 0][ 4]          = IMG[ 0][ 4];
				IMG_n[ 0][ 5]          = IMG[ 0][ 5];
				IMG_n[ 0][ 6]          = IMG[ 1][ 4];
				IMG_n[ 0][ 7]          = IMG[ 2][ 4];
				IMG_n[ 1][ 4]          = IMG[ 1][ 5];
				IMG_n[ 1][ 5]          = IMG[ 0][ 6];
				IMG_n[ 1][ 6]          = IMG[ 0][ 7];
				IMG_n[ 1][ 7]          = IMG[ 1][ 6];
				IMG_n[ 2][ 4]          = IMG[ 2][ 5];
				IMG_n[ 2][ 5]          = IMG[ 3][ 4];
				IMG_n[ 2][ 6]          = IMG[ 3][ 5];
				IMG_n[ 2][ 7]          = IMG[ 2][ 6];
				IMG_n[ 3][ 4]          = IMG[ 1][ 7];
				IMG_n[ 3][ 5]          = IMG[ 2][ 7];
				IMG_n[ 3][ 6]          = IMG[ 3][ 6];
				IMG_n[ 3][ 7]          = IMG[ 3][ 7];

				// Block at row 0..3, col 8..11
				IMG_n[ 0][ 8]          = IMG[ 0][ 8];
				IMG_n[ 0][ 9]          = IMG[ 0][ 9];
				IMG_n[ 0][10]          = IMG[ 1][ 8];
				IMG_n[ 0][11]          = IMG[ 2][ 8];
				IMG_n[ 1][ 8]          = IMG[ 1][ 9];
				IMG_n[ 1][ 9]          = IMG[ 0][10];
				IMG_n[ 1][10]          = IMG[ 0][11];
				IMG_n[ 1][11]          = IMG[ 1][10];
				IMG_n[ 2][ 8]          = IMG[ 2][ 9];
				IMG_n[ 2][ 9]          = IMG[ 3][ 8];
				IMG_n[ 2][10]          = IMG[ 3][ 9];
				IMG_n[ 2][11]          = IMG[ 2][10];
				IMG_n[ 3][ 8]          = IMG[ 1][11];
				IMG_n[ 3][ 9]          = IMG[ 2][11];
				IMG_n[ 3][10]          = IMG[ 3][10];
				IMG_n[ 3][11]          = IMG[ 3][11];

				// Block at row 0..3, col 12..15
				IMG_n[ 0][12]          = IMG[ 0][12];
				IMG_n[ 0][13]          = IMG[ 0][13];
				IMG_n[ 0][14]          = IMG[ 1][12];
				IMG_n[ 0][15]          = IMG[ 2][12];
				IMG_n[ 1][12]          = IMG[ 1][13];
				IMG_n[ 1][13]          = IMG[ 0][14];
				IMG_n[ 1][14]          = IMG[ 0][15];
				IMG_n[ 1][15]          = IMG[ 1][14];
				IMG_n[ 2][12]          = IMG[ 2][13];
				IMG_n[ 2][13]          = IMG[ 3][12];
				IMG_n[ 2][14]          = IMG[ 3][13];
				IMG_n[ 2][15]          = IMG[ 2][14];
				IMG_n[ 3][12]          = IMG[ 1][15];
				IMG_n[ 3][13]          = IMG[ 2][15];
				IMG_n[ 3][14]          = IMG[ 3][14];
				IMG_n[ 3][15]          = IMG[ 3][15];

				// Block at row 4..7, col 0..3
				IMG_n[ 4][ 0]          = IMG[ 4][ 0];
				IMG_n[ 4][ 1]          = IMG[ 4][ 1];
				IMG_n[ 4][ 2]          = IMG[ 5][ 0];
				IMG_n[ 4][ 3]          = IMG[ 6][ 0];
				IMG_n[ 5][ 0]          = IMG[ 5][ 1];
				IMG_n[ 5][ 1]          = IMG[ 4][ 2];
				IMG_n[ 5][ 2]          = IMG[ 4][ 3];
				IMG_n[ 5][ 3]          = IMG[ 5][ 2];
				IMG_n[ 6][ 0]          = IMG[ 6][ 1];
				IMG_n[ 6][ 1]          = IMG[ 7][ 0];
				IMG_n[ 6][ 2]          = IMG[ 7][ 1];
				IMG_n[ 6][ 3]          = IMG[ 6][ 2];
				IMG_n[ 7][ 0]          = IMG[ 5][ 3];
				IMG_n[ 7][ 1]          = IMG[ 6][ 3];
				IMG_n[ 7][ 2]          = IMG[ 7][ 2];
				IMG_n[ 7][ 3]          = IMG[ 7][ 3];

				// Block at row 4..7, col 4..7
				IMG_n[ 4][ 4]          = IMG[ 4][ 4];
				IMG_n[ 4][ 5]          = IMG[ 4][ 5];
				IMG_n[ 4][ 6]          = IMG[ 5][ 4];
				IMG_n[ 4][ 7]          = IMG[ 6][ 4];
				IMG_n[ 5][ 4]          = IMG[ 5][ 5];
				IMG_n[ 5][ 5]          = IMG[ 4][ 6];
				IMG_n[ 5][ 6]          = IMG[ 4][ 7];
				IMG_n[ 5][ 7]          = IMG[ 5][ 6];
				IMG_n[ 6][ 4]          = IMG[ 6][ 5];
				IMG_n[ 6][ 5]          = IMG[ 7][ 4];
				IMG_n[ 6][ 6]          = IMG[ 7][ 5];
				IMG_n[ 6][ 7]          = IMG[ 6][ 6];
				IMG_n[ 7][ 4]          = IMG[ 5][ 7];
				IMG_n[ 7][ 5]          = IMG[ 6][ 7];
				IMG_n[ 7][ 6]          = IMG[ 7][ 6];
				IMG_n[ 7][ 7]          = IMG[ 7][ 7];

				// Block at row 4..7, col 8..11
				IMG_n[ 4][ 8]          = IMG[ 4][ 8];
				IMG_n[ 4][ 9]          = IMG[ 4][ 9];
				IMG_n[ 4][10]          = IMG[ 5][ 8];
				IMG_n[ 4][11]          = IMG[ 6][ 8];
				IMG_n[ 5][ 8]          = IMG[ 5][ 9];
				IMG_n[ 5][ 9]          = IMG[ 4][10];
				IMG_n[ 5][10]          = IMG[ 4][11];
				IMG_n[ 5][11]          = IMG[ 5][10];
				IMG_n[ 6][ 8]          = IMG[ 6][ 9];
				IMG_n[ 6][ 9]          = IMG[ 7][ 8];
				IMG_n[ 6][10]          = IMG[ 7][ 9];
				IMG_n[ 6][11]          = IMG[ 6][10];
				IMG_n[ 7][ 8]          = IMG[ 5][11];
				IMG_n[ 7][ 9]          = IMG[ 6][11];
				IMG_n[ 7][10]          = IMG[ 7][10];
				IMG_n[ 7][11]          = IMG[ 7][11];

				// Block at row 4..7, col 12..15
				IMG_n[ 4][12]          = IMG[ 4][12];
				IMG_n[ 4][13]          = IMG[ 4][13];
				IMG_n[ 4][14]          = IMG[ 5][12];
				IMG_n[ 4][15]          = IMG[ 6][12];
				IMG_n[ 5][12]          = IMG[ 5][13];
				IMG_n[ 5][13]          = IMG[ 4][14];
				IMG_n[ 5][14]          = IMG[ 4][15];
				IMG_n[ 5][15]          = IMG[ 5][14];
				IMG_n[ 6][12]          = IMG[ 6][13];
				IMG_n[ 6][13]          = IMG[ 7][12];
				IMG_n[ 6][14]          = IMG[ 7][13];
				IMG_n[ 6][15]          = IMG[ 6][14];
				IMG_n[ 7][12]          = IMG[ 5][15];
				IMG_n[ 7][13]          = IMG[ 6][15];
				IMG_n[ 7][14]          = IMG[ 7][14];
				IMG_n[ 7][15]          = IMG[ 7][15];

				// Block at row 8..11, col 0..3
				IMG_n[ 8][ 0]          = IMG[ 8][ 0];
				IMG_n[ 8][ 1]          = IMG[ 8][ 1];
				IMG_n[ 8][ 2]          = IMG[ 9][ 0];
				IMG_n[ 8][ 3]          = IMG[10][ 0];
				IMG_n[ 9][ 0]          = IMG[ 9][ 1];
				IMG_n[ 9][ 1]          = IMG[ 8][ 2];
				IMG_n[ 9][ 2]          = IMG[ 8][ 3];
				IMG_n[ 9][ 3]          = IMG[ 9][ 2];
				IMG_n[10][ 0]          = IMG[10][ 1];
				IMG_n[10][ 1]          = IMG[11][ 0];
				IMG_n[10][ 2]          = IMG[11][ 1];
				IMG_n[10][ 3]          = IMG[10][ 2];
				IMG_n[11][ 0]          = IMG[ 9][ 3];
				IMG_n[11][ 1]          = IMG[10][ 3];
				IMG_n[11][ 2]          = IMG[11][ 2];
				IMG_n[11][ 3]          = IMG[11][ 3];

				// Block at row 8..11, col 4..7
				IMG_n[ 8][ 4]          = IMG[ 8][ 4];
				IMG_n[ 8][ 5]          = IMG[ 8][ 5];
				IMG_n[ 8][ 6]          = IMG[ 9][ 4];
				IMG_n[ 8][ 7]          = IMG[10][ 4];
				IMG_n[ 9][ 4]          = IMG[ 9][ 5];
				IMG_n[ 9][ 5]          = IMG[ 8][ 6];
				IMG_n[ 9][ 6]          = IMG[ 8][ 7];
				IMG_n[ 9][ 7]          = IMG[ 9][ 6];
				IMG_n[10][ 4]          = IMG[10][ 5];
				IMG_n[10][ 5]          = IMG[11][ 4];
				IMG_n[10][ 6]          = IMG[11][ 5];
				IMG_n[10][ 7]          = IMG[10][ 6];
				IMG_n[11][ 4]          = IMG[ 9][ 7];
				IMG_n[11][ 5]          = IMG[10][ 7];
				IMG_n[11][ 6]          = IMG[11][ 6];
				IMG_n[11][ 7]          = IMG[11][ 7];

				// Block at row 8..11, col 8..11
				IMG_n[ 8][ 8]          = IMG[ 8][ 8];
				IMG_n[ 8][ 9]          = IMG[ 8][ 9];
				IMG_n[ 8][10]          = IMG[ 9][ 8];
				IMG_n[ 8][11]          = IMG[10][ 8];
				IMG_n[ 9][ 8]          = IMG[ 9][ 9];
				IMG_n[ 9][ 9]          = IMG[ 8][10];
				IMG_n[ 9][10]          = IMG[ 8][11];
				IMG_n[ 9][11]          = IMG[ 9][10];
				IMG_n[10][ 8]          = IMG[10][ 9];
				IMG_n[10][ 9]          = IMG[11][ 8];
				IMG_n[10][10]          = IMG[11][ 9];
				IMG_n[10][11]          = IMG[10][10];
				IMG_n[11][ 8]          = IMG[ 9][11];
				IMG_n[11][ 9]          = IMG[10][11];
				IMG_n[11][10]          = IMG[11][10];
				IMG_n[11][11]          = IMG[11][11];

				// Block at row 8..11, col 12..15
				IMG_n[ 8][12]          = IMG[ 8][12];
				IMG_n[ 8][13]          = IMG[ 8][13];
				IMG_n[ 8][14]          = IMG[ 9][12];
				IMG_n[ 8][15]          = IMG[10][12];
				IMG_n[ 9][12]          = IMG[ 9][13];
				IMG_n[ 9][13]          = IMG[ 8][14];
				IMG_n[ 9][14]          = IMG[ 8][15];
				IMG_n[ 9][15]          = IMG[ 9][14];
				IMG_n[10][12]          = IMG[10][13];
				IMG_n[10][13]          = IMG[11][12];
				IMG_n[10][14]          = IMG[11][13];
				IMG_n[10][15]          = IMG[10][14];
				IMG_n[11][12]          = IMG[ 9][15];
				IMG_n[11][13]          = IMG[10][15];
				IMG_n[11][14]          = IMG[11][14];
				IMG_n[11][15]          = IMG[11][15];

				// Block at row 12..15, col 0..3
				IMG_n[12][ 0]          = IMG[12][ 0];
				IMG_n[12][ 1]          = IMG[12][ 1];
				IMG_n[12][ 2]          = IMG[13][ 0];
				IMG_n[12][ 3]          = IMG[14][ 0];
				IMG_n[13][ 0]          = IMG[13][ 1];
				IMG_n[13][ 1]          = IMG[12][ 2];
				IMG_n[13][ 2]          = IMG[12][ 3];
				IMG_n[13][ 3]          = IMG[13][ 2];
				IMG_n[14][ 0]          = IMG[14][ 1];
				IMG_n[14][ 1]          = IMG[15][ 0];
				IMG_n[14][ 2]          = IMG[15][ 1];
				IMG_n[14][ 3]          = IMG[14][ 2];
				IMG_n[15][ 0]          = IMG[13][ 3];
				IMG_n[15][ 1]          = IMG[14][ 3];
				IMG_n[15][ 2]          = IMG[15][ 2];
				IMG_n[15][ 3]          = IMG[15][ 3];

				// Block at row 12..15, col 4..7
				IMG_n[12][ 4]          = IMG[12][ 4];
				IMG_n[12][ 5]          = IMG[12][ 5];
				IMG_n[12][ 6]          = IMG[13][ 4];
				IMG_n[12][ 7]          = IMG[14][ 4];
				IMG_n[13][ 4]          = IMG[13][ 5];
				IMG_n[13][ 5]          = IMG[12][ 6];
				IMG_n[13][ 6]          = IMG[12][ 7];
				IMG_n[13][ 7]          = IMG[13][ 6];
				IMG_n[14][ 4]          = IMG[14][ 5];
				IMG_n[14][ 5]          = IMG[15][ 4];
				IMG_n[14][ 6]          = IMG[15][ 5];
				IMG_n[14][ 7]          = IMG[14][ 6];
				IMG_n[15][ 4]          = IMG[13][ 7];
				IMG_n[15][ 5]          = IMG[14][ 7];
				IMG_n[15][ 6]          = IMG[15][ 6];
				IMG_n[15][ 7]          = IMG[15][ 7];

				// Block at row 12..15, col 8..11
				IMG_n[12][ 8]          = IMG[12][ 8];
				IMG_n[12][ 9]          = IMG[12][ 9];
				IMG_n[12][10]          = IMG[13][ 8];
				IMG_n[12][11]          = IMG[14][ 8];
				IMG_n[13][ 8]          = IMG[13][ 9];
				IMG_n[13][ 9]          = IMG[12][10];
				IMG_n[13][10]          = IMG[12][11];
				IMG_n[13][11]          = IMG[13][10];
				IMG_n[14][ 8]          = IMG[14][ 9];
				IMG_n[14][ 9]          = IMG[15][ 8];
				IMG_n[14][10]          = IMG[15][ 9];
				IMG_n[14][11]          = IMG[14][10];
				IMG_n[15][ 8]          = IMG[13][11];
				IMG_n[15][ 9]          = IMG[14][11];
				IMG_n[15][10]          = IMG[15][10];
				IMG_n[15][11]          = IMG[15][11];

				// Block at row 12..15, col 12..15
				IMG_n[12][12]          = IMG[12][12];
				IMG_n[12][13]          = IMG[12][13];
				IMG_n[12][14]          = IMG[13][12];
				IMG_n[12][15]          = IMG[14][12];
				IMG_n[13][12]          = IMG[13][13];
				IMG_n[13][13]          = IMG[12][14];
				IMG_n[13][14]          = IMG[12][15];
				IMG_n[13][15]          = IMG[13][14];
				IMG_n[14][12]          = IMG[14][13];
				IMG_n[14][13]          = IMG[15][12];
				IMG_n[14][14]          = IMG[15][13];
				IMG_n[14][15]          = IMG[14][14];
				IMG_n[15][12]          = IMG[13][15];
				IMG_n[15][13]          = IMG[14][15];
				IMG_n[15][14]          = IMG[15][14];
				IMG_n[15][15]          = IMG[15][15];
			end
			4'b1101: begin
				// Block at row 0..7, col 0..7
				IMG_n[ 0][ 0]          = IMG[ 0][ 0];
				IMG_n[ 0][ 1]          = IMG[ 0][ 1];
				IMG_n[ 0][ 2]          = IMG[ 1][ 0];
				IMG_n[ 0][ 3]          = IMG[ 2][ 0];
				IMG_n[ 0][ 4]          = IMG[ 1][ 1];
				IMG_n[ 0][ 5]          = IMG[ 0][ 2];
				IMG_n[ 0][ 6]          = IMG[ 0][ 3];
				IMG_n[ 0][ 7]          = IMG[ 1][ 2];
				IMG_n[ 1][ 0]          = IMG[ 2][ 1];
				IMG_n[ 1][ 1]          = IMG[ 3][ 0];
				IMG_n[ 1][ 2]          = IMG[ 4][ 0];
				IMG_n[ 1][ 3]          = IMG[ 3][ 1];
				IMG_n[ 1][ 4]          = IMG[ 2][ 2];
				IMG_n[ 1][ 5]          = IMG[ 1][ 3];
				IMG_n[ 1][ 6]          = IMG[ 0][ 4];
				IMG_n[ 1][ 7]          = IMG[ 0][ 5];
				IMG_n[ 2][ 0]          = IMG[ 1][ 4];
				IMG_n[ 2][ 1]          = IMG[ 2][ 3];
				IMG_n[ 2][ 2]          = IMG[ 3][ 2];
				IMG_n[ 2][ 3]          = IMG[ 4][ 1];
				IMG_n[ 2][ 4]          = IMG[ 5][ 0];
				IMG_n[ 2][ 5]          = IMG[ 6][ 0];
				IMG_n[ 2][ 6]          = IMG[ 5][ 1];
				IMG_n[ 2][ 7]          = IMG[ 4][ 2];
				IMG_n[ 3][ 0]          = IMG[ 3][ 3];
				IMG_n[ 3][ 1]          = IMG[ 2][ 4];
				IMG_n[ 3][ 2]          = IMG[ 1][ 5];
				IMG_n[ 3][ 3]          = IMG[ 0][ 6];
				IMG_n[ 3][ 4]          = IMG[ 0][ 7];
				IMG_n[ 3][ 5]          = IMG[ 1][ 6];
				IMG_n[ 3][ 6]          = IMG[ 2][ 5];
				IMG_n[ 3][ 7]          = IMG[ 3][ 4];
				IMG_n[ 4][ 0]          = IMG[ 4][ 3];
				IMG_n[ 4][ 1]          = IMG[ 5][ 2];
				IMG_n[ 4][ 2]          = IMG[ 6][ 1];
				IMG_n[ 4][ 3]          = IMG[ 7][ 0];
				IMG_n[ 4][ 4]          = IMG[ 7][ 1];
				IMG_n[ 4][ 5]          = IMG[ 6][ 2];
				IMG_n[ 4][ 6]          = IMG[ 5][ 3];
				IMG_n[ 4][ 7]          = IMG[ 4][ 4];
				IMG_n[ 5][ 0]          = IMG[ 3][ 5];
				IMG_n[ 5][ 1]          = IMG[ 2][ 6];
				IMG_n[ 5][ 2]          = IMG[ 1][ 7];
				IMG_n[ 5][ 3]          = IMG[ 2][ 7];
				IMG_n[ 5][ 4]          = IMG[ 3][ 6];
				IMG_n[ 5][ 5]          = IMG[ 4][ 5];
				IMG_n[ 5][ 6]          = IMG[ 5][ 4];
				IMG_n[ 5][ 7]          = IMG[ 6][ 3];
				IMG_n[ 6][ 0]          = IMG[ 7][ 2];
				IMG_n[ 6][ 1]          = IMG[ 7][ 3];
				IMG_n[ 6][ 2]          = IMG[ 6][ 4];
				IMG_n[ 6][ 3]          = IMG[ 5][ 5];
				IMG_n[ 6][ 4]          = IMG[ 4][ 6];
				IMG_n[ 6][ 5]          = IMG[ 3][ 7];
				IMG_n[ 6][ 6]          = IMG[ 4][ 7];
				IMG_n[ 6][ 7]          = IMG[ 5][ 6];
				IMG_n[ 7][ 0]          = IMG[ 6][ 5];
				IMG_n[ 7][ 1]          = IMG[ 7][ 4];
				IMG_n[ 7][ 2]          = IMG[ 7][ 5];
				IMG_n[ 7][ 3]          = IMG[ 6][ 6];
				IMG_n[ 7][ 4]          = IMG[ 5][ 7];
				IMG_n[ 7][ 5]          = IMG[ 6][ 7];
				IMG_n[ 7][ 6]          = IMG[ 7][ 6];
				IMG_n[ 7][ 7]          = IMG[ 7][ 7];

				// Block at row 0..7, col 8..15
				IMG_n[ 0][ 8]          = IMG[ 0][ 8];
				IMG_n[ 0][ 9]          = IMG[ 0][ 9];
				IMG_n[ 0][10]          = IMG[ 1][ 8];
				IMG_n[ 0][11]          = IMG[ 2][ 8];
				IMG_n[ 0][12]          = IMG[ 1][ 9];
				IMG_n[ 0][13]          = IMG[ 0][10];
				IMG_n[ 0][14]          = IMG[ 0][11];
				IMG_n[ 0][15]          = IMG[ 1][10];
				IMG_n[ 1][ 8]          = IMG[ 2][ 9];
				IMG_n[ 1][ 9]          = IMG[ 3][ 8];
				IMG_n[ 1][10]          = IMG[ 4][ 8];
				IMG_n[ 1][11]          = IMG[ 3][ 9];
				IMG_n[ 1][12]          = IMG[ 2][10];
				IMG_n[ 1][13]          = IMG[ 1][11];
				IMG_n[ 1][14]          = IMG[ 0][12];
				IMG_n[ 1][15]          = IMG[ 0][13];
				IMG_n[ 2][ 8]          = IMG[ 1][12];
				IMG_n[ 2][ 9]          = IMG[ 2][11];
				IMG_n[ 2][10]          = IMG[ 3][10];
				IMG_n[ 2][11]          = IMG[ 4][ 9];
				IMG_n[ 2][12]          = IMG[ 5][ 8];
				IMG_n[ 2][13]          = IMG[ 6][ 8];
				IMG_n[ 2][14]          = IMG[ 5][ 9];
				IMG_n[ 2][15]          = IMG[ 4][10];
				IMG_n[ 3][ 8]          = IMG[ 3][11];
				IMG_n[ 3][ 9]          = IMG[ 2][12];
				IMG_n[ 3][10]          = IMG[ 1][13];
				IMG_n[ 3][11]          = IMG[ 0][14];
				IMG_n[ 3][12]          = IMG[ 0][15];
				IMG_n[ 3][13]          = IMG[ 1][14];
				IMG_n[ 3][14]          = IMG[ 2][13];
				IMG_n[ 3][15]          = IMG[ 3][12];
				IMG_n[ 4][ 8]          = IMG[ 4][11];
				IMG_n[ 4][ 9]          = IMG[ 5][10];
				IMG_n[ 4][10]          = IMG[ 6][ 9];
				IMG_n[ 4][11]          = IMG[ 7][ 8];
				IMG_n[ 4][12]          = IMG[ 7][ 9];
				IMG_n[ 4][13]          = IMG[ 6][10];
				IMG_n[ 4][14]          = IMG[ 5][11];
				IMG_n[ 4][15]          = IMG[ 4][12];
				IMG_n[ 5][ 8]          = IMG[ 3][13];
				IMG_n[ 5][ 9]          = IMG[ 2][14];
				IMG_n[ 5][10]          = IMG[ 1][15];
				IMG_n[ 5][11]          = IMG[ 2][15];
				IMG_n[ 5][12]          = IMG[ 3][14];
				IMG_n[ 5][13]          = IMG[ 4][13];
				IMG_n[ 5][14]          = IMG[ 5][12];
				IMG_n[ 5][15]          = IMG[ 6][11];
				IMG_n[ 6][ 8]          = IMG[ 7][10];
				IMG_n[ 6][ 9]          = IMG[ 7][11];
				IMG_n[ 6][10]          = IMG[ 6][12];
				IMG_n[ 6][11]          = IMG[ 5][13];
				IMG_n[ 6][12]          = IMG[ 4][14];
				IMG_n[ 6][13]          = IMG[ 3][15];
				IMG_n[ 6][14]          = IMG[ 4][15];
				IMG_n[ 6][15]          = IMG[ 5][14];
				IMG_n[ 7][ 8]          = IMG[ 6][13];
				IMG_n[ 7][ 9]          = IMG[ 7][12];
				IMG_n[ 7][10]          = IMG[ 7][13];
				IMG_n[ 7][11]          = IMG[ 6][14];
				IMG_n[ 7][12]          = IMG[ 5][15];
				IMG_n[ 7][13]          = IMG[ 6][15];
				IMG_n[ 7][14]          = IMG[ 7][14];
				IMG_n[ 7][15]          = IMG[ 7][15];

				// Block at row 8..15, col 0..7
				IMG_n[ 8][ 0]          = IMG[ 8][ 0];
				IMG_n[ 8][ 1]          = IMG[ 8][ 1];
				IMG_n[ 8][ 2]          = IMG[ 9][ 0];
				IMG_n[ 8][ 3]          = IMG[10][ 0];
				IMG_n[ 8][ 4]          = IMG[ 9][ 1];
				IMG_n[ 8][ 5]          = IMG[ 8][ 2];
				IMG_n[ 8][ 6]          = IMG[ 8][ 3];
				IMG_n[ 8][ 7]          = IMG[ 9][ 2];
				IMG_n[ 9][ 0]          = IMG[10][ 1];
				IMG_n[ 9][ 1]          = IMG[11][ 0];
				IMG_n[ 9][ 2]          = IMG[12][ 0];
				IMG_n[ 9][ 3]          = IMG[11][ 1];
				IMG_n[ 9][ 4]          = IMG[10][ 2];
				IMG_n[ 9][ 5]          = IMG[ 9][ 3];
				IMG_n[ 9][ 6]          = IMG[ 8][ 4];
				IMG_n[ 9][ 7]          = IMG[ 8][ 5];
				IMG_n[10][ 0]          = IMG[ 9][ 4];
				IMG_n[10][ 1]          = IMG[10][ 3];
				IMG_n[10][ 2]          = IMG[11][ 2];
				IMG_n[10][ 3]          = IMG[12][ 1];
				IMG_n[10][ 4]          = IMG[13][ 0];
				IMG_n[10][ 5]          = IMG[14][ 0];
				IMG_n[10][ 6]          = IMG[13][ 1];
				IMG_n[10][ 7]          = IMG[12][ 2];
				IMG_n[11][ 0]          = IMG[11][ 3];
				IMG_n[11][ 1]          = IMG[10][ 4];
				IMG_n[11][ 2]          = IMG[ 9][ 5];
				IMG_n[11][ 3]          = IMG[ 8][ 6];
				IMG_n[11][ 4]          = IMG[ 8][ 7];
				IMG_n[11][ 5]          = IMG[ 9][ 6];
				IMG_n[11][ 6]          = IMG[10][ 5];
				IMG_n[11][ 7]          = IMG[11][ 4];
				IMG_n[12][ 0]          = IMG[12][ 3];
				IMG_n[12][ 1]          = IMG[13][ 2];
				IMG_n[12][ 2]          = IMG[14][ 1];
				IMG_n[12][ 3]          = IMG[15][ 0];
				IMG_n[12][ 4]          = IMG[15][ 1];
				IMG_n[12][ 5]          = IMG[14][ 2];
				IMG_n[12][ 6]          = IMG[13][ 3];
				IMG_n[12][ 7]          = IMG[12][ 4];
				IMG_n[13][ 0]          = IMG[11][ 5];
				IMG_n[13][ 1]          = IMG[10][ 6];
				IMG_n[13][ 2]          = IMG[ 9][ 7];
				IMG_n[13][ 3]          = IMG[10][ 7];
				IMG_n[13][ 4]          = IMG[11][ 6];
				IMG_n[13][ 5]          = IMG[12][ 5];
				IMG_n[13][ 6]          = IMG[13][ 4];
				IMG_n[13][ 7]          = IMG[14][ 3];
				IMG_n[14][ 0]          = IMG[15][ 2];
				IMG_n[14][ 1]          = IMG[15][ 3];
				IMG_n[14][ 2]          = IMG[14][ 4];
				IMG_n[14][ 3]          = IMG[13][ 5];
				IMG_n[14][ 4]          = IMG[12][ 6];
				IMG_n[14][ 5]          = IMG[11][ 7];
				IMG_n[14][ 6]          = IMG[12][ 7];
				IMG_n[14][ 7]          = IMG[13][ 6];
				IMG_n[15][ 0]          = IMG[14][ 5];
				IMG_n[15][ 1]          = IMG[15][ 4];
				IMG_n[15][ 2]          = IMG[15][ 5];
				IMG_n[15][ 3]          = IMG[14][ 6];
				IMG_n[15][ 4]          = IMG[13][ 7];
				IMG_n[15][ 5]          = IMG[14][ 7];
				IMG_n[15][ 6]          = IMG[15][ 6];
				IMG_n[15][ 7]          = IMG[15][ 7];

				// Block at row 8..15, col 8..15
				IMG_n[ 8][ 8]          = IMG[ 8][ 8];
				IMG_n[ 8][ 9]          = IMG[ 8][ 9];
				IMG_n[ 8][10]          = IMG[ 9][ 8];
				IMG_n[ 8][11]          = IMG[10][ 8];
				IMG_n[ 8][12]          = IMG[ 9][ 9];
				IMG_n[ 8][13]          = IMG[ 8][10];
				IMG_n[ 8][14]          = IMG[ 8][11];
				IMG_n[ 8][15]          = IMG[ 9][10];
				IMG_n[ 9][ 8]          = IMG[10][ 9];
				IMG_n[ 9][ 9]          = IMG[11][ 8];
				IMG_n[ 9][10]          = IMG[12][ 8];
				IMG_n[ 9][11]          = IMG[11][ 9];
				IMG_n[ 9][12]          = IMG[10][10];
				IMG_n[ 9][13]          = IMG[ 9][11];
				IMG_n[ 9][14]          = IMG[ 8][12];
				IMG_n[ 9][15]          = IMG[ 8][13];
				IMG_n[10][ 8]          = IMG[ 9][12];
				IMG_n[10][ 9]          = IMG[10][11];
				IMG_n[10][10]          = IMG[11][10];
				IMG_n[10][11]          = IMG[12][ 9];
				IMG_n[10][12]          = IMG[13][ 8];
				IMG_n[10][13]          = IMG[14][ 8];
				IMG_n[10][14]          = IMG[13][ 9];
				IMG_n[10][15]          = IMG[12][10];
				IMG_n[11][ 8]          = IMG[11][11];
				IMG_n[11][ 9]          = IMG[10][12];
				IMG_n[11][10]          = IMG[ 9][13];
				IMG_n[11][11]          = IMG[ 8][14];
				IMG_n[11][12]          = IMG[ 8][15];
				IMG_n[11][13]          = IMG[ 9][14];
				IMG_n[11][14]          = IMG[10][13];
				IMG_n[11][15]          = IMG[11][12];
				IMG_n[12][ 8]          = IMG[12][11];
				IMG_n[12][ 9]          = IMG[13][10];
				IMG_n[12][10]          = IMG[14][ 9];
				IMG_n[12][11]          = IMG[15][ 8];
				IMG_n[12][12]          = IMG[15][ 9];
				IMG_n[12][13]          = IMG[14][10];
				IMG_n[12][14]          = IMG[13][11];
				IMG_n[12][15]          = IMG[12][12];
				IMG_n[13][ 8]          = IMG[11][13];
				IMG_n[13][ 9]          = IMG[10][14];
				IMG_n[13][10]          = IMG[ 9][15];
				IMG_n[13][11]          = IMG[10][15];
				IMG_n[13][12]          = IMG[11][14];
				IMG_n[13][13]          = IMG[12][13];
				IMG_n[13][14]          = IMG[13][12];
				IMG_n[13][15]          = IMG[14][11];
				IMG_n[14][ 8]          = IMG[15][10];
				IMG_n[14][ 9]          = IMG[15][11];
				IMG_n[14][10]          = IMG[14][12];
				IMG_n[14][11]          = IMG[13][13];
				IMG_n[14][12]          = IMG[12][14];
				IMG_n[14][13]          = IMG[11][15];
				IMG_n[14][14]          = IMG[12][15];
				IMG_n[14][15]          = IMG[13][14];
				IMG_n[15][ 8]          = IMG[14][13];
				IMG_n[15][ 9]          = IMG[15][12];
				IMG_n[15][10]          = IMG[15][13];
				IMG_n[15][11]          = IMG[14][14];
				IMG_n[15][12]          = IMG[13][15];
				IMG_n[15][13]          = IMG[14][15];
				IMG_n[15][14]          = IMG[15][14];
				IMG_n[15][15]          = IMG[15][15];
			end
			4'b1110: begin
				// Block at row 0..3, col 0..3
				IMG_n[ 0][ 0]          = IMG[ 0][ 0];
				IMG_n[ 0][ 1]          = IMG[ 0][ 1];
				IMG_n[ 0][ 2]          = IMG[ 1][ 0];
				IMG_n[ 0][ 3]          = IMG[ 1][ 1];
				IMG_n[ 1][ 0]          = IMG[ 0][ 2];
				IMG_n[ 1][ 1]          = IMG[ 0][ 3];
				IMG_n[ 1][ 2]          = IMG[ 1][ 2];
				IMG_n[ 1][ 3]          = IMG[ 1][ 3];
				IMG_n[ 2][ 0]          = IMG[ 2][ 0];
				IMG_n[ 2][ 1]          = IMG[ 2][ 1];
				IMG_n[ 2][ 2]          = IMG[ 3][ 0];
				IMG_n[ 2][ 3]          = IMG[ 3][ 1];
				IMG_n[ 3][ 0]          = IMG[ 2][ 2];
				IMG_n[ 3][ 1]          = IMG[ 2][ 3];
				IMG_n[ 3][ 2]          = IMG[ 3][ 2];
				IMG_n[ 3][ 3]          = IMG[ 3][ 3];

				// Block at row 0..3, col 4..7
				IMG_n[ 0][ 4]          = IMG[ 0][ 4];
				IMG_n[ 0][ 5]          = IMG[ 0][ 5];
				IMG_n[ 0][ 6]          = IMG[ 1][ 4];
				IMG_n[ 0][ 7]          = IMG[ 1][ 5];
				IMG_n[ 1][ 4]          = IMG[ 0][ 6];
				IMG_n[ 1][ 5]          = IMG[ 0][ 7];
				IMG_n[ 1][ 6]          = IMG[ 1][ 6];
				IMG_n[ 1][ 7]          = IMG[ 1][ 7];
				IMG_n[ 2][ 4]          = IMG[ 2][ 4];
				IMG_n[ 2][ 5]          = IMG[ 2][ 5];
				IMG_n[ 2][ 6]          = IMG[ 3][ 4];
				IMG_n[ 2][ 7]          = IMG[ 3][ 5];
				IMG_n[ 3][ 4]          = IMG[ 2][ 6];
				IMG_n[ 3][ 5]          = IMG[ 2][ 7];
				IMG_n[ 3][ 6]          = IMG[ 3][ 6];
				IMG_n[ 3][ 7]          = IMG[ 3][ 7];

				// Block at row 0..3, col 8..11
				IMG_n[ 0][ 8]          = IMG[ 0][ 8];
				IMG_n[ 0][ 9]          = IMG[ 0][ 9];
				IMG_n[ 0][10]          = IMG[ 1][ 8];
				IMG_n[ 0][11]          = IMG[ 1][ 9];
				IMG_n[ 1][ 8]          = IMG[ 0][10];
				IMG_n[ 1][ 9]          = IMG[ 0][11];
				IMG_n[ 1][10]          = IMG[ 1][10];
				IMG_n[ 1][11]          = IMG[ 1][11];
				IMG_n[ 2][ 8]          = IMG[ 2][ 8];
				IMG_n[ 2][ 9]          = IMG[ 2][ 9];
				IMG_n[ 2][10]          = IMG[ 3][ 8];
				IMG_n[ 2][11]          = IMG[ 3][ 9];
				IMG_n[ 3][ 8]          = IMG[ 2][10];
				IMG_n[ 3][ 9]          = IMG[ 2][11];
				IMG_n[ 3][10]          = IMG[ 3][10];
				IMG_n[ 3][11]          = IMG[ 3][11];

				// Block at row 0..3, col 12..15
				IMG_n[ 0][12]          = IMG[ 0][12];
				IMG_n[ 0][13]          = IMG[ 0][13];
				IMG_n[ 0][14]          = IMG[ 1][12];
				IMG_n[ 0][15]          = IMG[ 1][13];
				IMG_n[ 1][12]          = IMG[ 0][14];
				IMG_n[ 1][13]          = IMG[ 0][15];
				IMG_n[ 1][14]          = IMG[ 1][14];
				IMG_n[ 1][15]          = IMG[ 1][15];
				IMG_n[ 2][12]          = IMG[ 2][12];
				IMG_n[ 2][13]          = IMG[ 2][13];
				IMG_n[ 2][14]          = IMG[ 3][12];
				IMG_n[ 2][15]          = IMG[ 3][13];
				IMG_n[ 3][12]          = IMG[ 2][14];
				IMG_n[ 3][13]          = IMG[ 2][15];
				IMG_n[ 3][14]          = IMG[ 3][14];
				IMG_n[ 3][15]          = IMG[ 3][15];

				// Block at row 4..7, col 0..3
				IMG_n[ 4][ 0]          = IMG[ 4][ 0];
				IMG_n[ 4][ 1]          = IMG[ 4][ 1];
				IMG_n[ 4][ 2]          = IMG[ 5][ 0];
				IMG_n[ 4][ 3]          = IMG[ 5][ 1];
				IMG_n[ 5][ 0]          = IMG[ 4][ 2];
				IMG_n[ 5][ 1]          = IMG[ 4][ 3];
				IMG_n[ 5][ 2]          = IMG[ 5][ 2];
				IMG_n[ 5][ 3]          = IMG[ 5][ 3];
				IMG_n[ 6][ 0]          = IMG[ 6][ 0];
				IMG_n[ 6][ 1]          = IMG[ 6][ 1];
				IMG_n[ 6][ 2]          = IMG[ 7][ 0];
				IMG_n[ 6][ 3]          = IMG[ 7][ 1];
				IMG_n[ 7][ 0]          = IMG[ 6][ 2];
				IMG_n[ 7][ 1]          = IMG[ 6][ 3];
				IMG_n[ 7][ 2]          = IMG[ 7][ 2];
				IMG_n[ 7][ 3]          = IMG[ 7][ 3];

				// Block at row 4..7, col 4..7
				IMG_n[ 4][ 4]          = IMG[ 4][ 4];
				IMG_n[ 4][ 5]          = IMG[ 4][ 5];
				IMG_n[ 4][ 6]          = IMG[ 5][ 4];
				IMG_n[ 4][ 7]          = IMG[ 5][ 5];
				IMG_n[ 5][ 4]          = IMG[ 4][ 6];
				IMG_n[ 5][ 5]          = IMG[ 4][ 7];
				IMG_n[ 5][ 6]          = IMG[ 5][ 6];
				IMG_n[ 5][ 7]          = IMG[ 5][ 7];
				IMG_n[ 6][ 4]          = IMG[ 6][ 4];
				IMG_n[ 6][ 5]          = IMG[ 6][ 5];
				IMG_n[ 6][ 6]          = IMG[ 7][ 4];
				IMG_n[ 6][ 7]          = IMG[ 7][ 5];
				IMG_n[ 7][ 4]          = IMG[ 6][ 6];
				IMG_n[ 7][ 5]          = IMG[ 6][ 7];
				IMG_n[ 7][ 6]          = IMG[ 7][ 6];
				IMG_n[ 7][ 7]          = IMG[ 7][ 7];

				// Block at row 4..7, col 8..11
				IMG_n[ 4][ 8]          = IMG[ 4][ 8];
				IMG_n[ 4][ 9]          = IMG[ 4][ 9];
				IMG_n[ 4][10]          = IMG[ 5][ 8];
				IMG_n[ 4][11]          = IMG[ 5][ 9];
				IMG_n[ 5][ 8]          = IMG[ 4][10];
				IMG_n[ 5][ 9]          = IMG[ 4][11];
				IMG_n[ 5][10]          = IMG[ 5][10];
				IMG_n[ 5][11]          = IMG[ 5][11];
				IMG_n[ 6][ 8]          = IMG[ 6][ 8];
				IMG_n[ 6][ 9]          = IMG[ 6][ 9];
				IMG_n[ 6][10]          = IMG[ 7][ 8];
				IMG_n[ 6][11]          = IMG[ 7][ 9];
				IMG_n[ 7][ 8]          = IMG[ 6][10];
				IMG_n[ 7][ 9]          = IMG[ 6][11];
				IMG_n[ 7][10]          = IMG[ 7][10];
				IMG_n[ 7][11]          = IMG[ 7][11];

				// Block at row 4..7, col 12..15
				IMG_n[ 4][12]          = IMG[ 4][12];
				IMG_n[ 4][13]          = IMG[ 4][13];
				IMG_n[ 4][14]          = IMG[ 5][12];
				IMG_n[ 4][15]          = IMG[ 5][13];
				IMG_n[ 5][12]          = IMG[ 4][14];
				IMG_n[ 5][13]          = IMG[ 4][15];
				IMG_n[ 5][14]          = IMG[ 5][14];
				IMG_n[ 5][15]          = IMG[ 5][15];
				IMG_n[ 6][12]          = IMG[ 6][12];
				IMG_n[ 6][13]          = IMG[ 6][13];
				IMG_n[ 6][14]          = IMG[ 7][12];
				IMG_n[ 6][15]          = IMG[ 7][13];
				IMG_n[ 7][12]          = IMG[ 6][14];
				IMG_n[ 7][13]          = IMG[ 6][15];
				IMG_n[ 7][14]          = IMG[ 7][14];
				IMG_n[ 7][15]          = IMG[ 7][15];

				// Block at row 8..11, col 0..3
				IMG_n[ 8][ 0]          = IMG[ 8][ 0];
				IMG_n[ 8][ 1]          = IMG[ 8][ 1];
				IMG_n[ 8][ 2]          = IMG[ 9][ 0];
				IMG_n[ 8][ 3]          = IMG[ 9][ 1];
				IMG_n[ 9][ 0]          = IMG[ 8][ 2];
				IMG_n[ 9][ 1]          = IMG[ 8][ 3];
				IMG_n[ 9][ 2]          = IMG[ 9][ 2];
				IMG_n[ 9][ 3]          = IMG[ 9][ 3];
				IMG_n[10][ 0]          = IMG[10][ 0];
				IMG_n[10][ 1]          = IMG[10][ 1];
				IMG_n[10][ 2]          = IMG[11][ 0];
				IMG_n[10][ 3]          = IMG[11][ 1];
				IMG_n[11][ 0]          = IMG[10][ 2];
				IMG_n[11][ 1]          = IMG[10][ 3];
				IMG_n[11][ 2]          = IMG[11][ 2];
				IMG_n[11][ 3]          = IMG[11][ 3];

				// Block at row 8..11, col 4..7
				IMG_n[ 8][ 4]          = IMG[ 8][ 4];
				IMG_n[ 8][ 5]          = IMG[ 8][ 5];
				IMG_n[ 8][ 6]          = IMG[ 9][ 4];
				IMG_n[ 8][ 7]          = IMG[ 9][ 5];
				IMG_n[ 9][ 4]          = IMG[ 8][ 6];
				IMG_n[ 9][ 5]          = IMG[ 8][ 7];
				IMG_n[ 9][ 6]          = IMG[ 9][ 6];
				IMG_n[ 9][ 7]          = IMG[ 9][ 7];
				IMG_n[10][ 4]          = IMG[10][ 4];
				IMG_n[10][ 5]          = IMG[10][ 5];
				IMG_n[10][ 6]          = IMG[11][ 4];
				IMG_n[10][ 7]          = IMG[11][ 5];
				IMG_n[11][ 4]          = IMG[10][ 6];
				IMG_n[11][ 5]          = IMG[10][ 7];
				IMG_n[11][ 6]          = IMG[11][ 6];
				IMG_n[11][ 7]          = IMG[11][ 7];

				// Block at row 8..11, col 8..11
				IMG_n[ 8][ 8]          = IMG[ 8][ 8];
				IMG_n[ 8][ 9]          = IMG[ 8][ 9];
				IMG_n[ 8][10]          = IMG[ 9][ 8];
				IMG_n[ 8][11]          = IMG[ 9][ 9];
				IMG_n[ 9][ 8]          = IMG[ 8][10];
				IMG_n[ 9][ 9]          = IMG[ 8][11];
				IMG_n[ 9][10]          = IMG[ 9][10];
				IMG_n[ 9][11]          = IMG[ 9][11];
				IMG_n[10][ 8]          = IMG[10][ 8];
				IMG_n[10][ 9]          = IMG[10][ 9];
				IMG_n[10][10]          = IMG[11][ 8];
				IMG_n[10][11]          = IMG[11][ 9];
				IMG_n[11][ 8]          = IMG[10][10];
				IMG_n[11][ 9]          = IMG[10][11];
				IMG_n[11][10]          = IMG[11][10];
				IMG_n[11][11]          = IMG[11][11];

				// Block at row 8..11, col 12..15
				IMG_n[ 8][12]          = IMG[ 8][12];
				IMG_n[ 8][13]          = IMG[ 8][13];
				IMG_n[ 8][14]          = IMG[ 9][12];
				IMG_n[ 8][15]          = IMG[ 9][13];
				IMG_n[ 9][12]          = IMG[ 8][14];
				IMG_n[ 9][13]          = IMG[ 8][15];
				IMG_n[ 9][14]          = IMG[ 9][14];
				IMG_n[ 9][15]          = IMG[ 9][15];
				IMG_n[10][12]          = IMG[10][12];
				IMG_n[10][13]          = IMG[10][13];
				IMG_n[10][14]          = IMG[11][12];
				IMG_n[10][15]          = IMG[11][13];
				IMG_n[11][12]          = IMG[10][14];
				IMG_n[11][13]          = IMG[10][15];
				IMG_n[11][14]          = IMG[11][14];
				IMG_n[11][15]          = IMG[11][15];

				// Block at row 12..15, col 0..3
				IMG_n[12][ 0]          = IMG[12][ 0];
				IMG_n[12][ 1]          = IMG[12][ 1];
				IMG_n[12][ 2]          = IMG[13][ 0];
				IMG_n[12][ 3]          = IMG[13][ 1];
				IMG_n[13][ 0]          = IMG[12][ 2];
				IMG_n[13][ 1]          = IMG[12][ 3];
				IMG_n[13][ 2]          = IMG[13][ 2];
				IMG_n[13][ 3]          = IMG[13][ 3];
				IMG_n[14][ 0]          = IMG[14][ 0];
				IMG_n[14][ 1]          = IMG[14][ 1];
				IMG_n[14][ 2]          = IMG[15][ 0];
				IMG_n[14][ 3]          = IMG[15][ 1];
				IMG_n[15][ 0]          = IMG[14][ 2];
				IMG_n[15][ 1]          = IMG[14][ 3];
				IMG_n[15][ 2]          = IMG[15][ 2];
				IMG_n[15][ 3]          = IMG[15][ 3];

				// Block at row 12..15, col 4..7
				IMG_n[12][ 4]          = IMG[12][ 4];
				IMG_n[12][ 5]          = IMG[12][ 5];
				IMG_n[12][ 6]          = IMG[13][ 4];
				IMG_n[12][ 7]          = IMG[13][ 5];
				IMG_n[13][ 4]          = IMG[12][ 6];
				IMG_n[13][ 5]          = IMG[12][ 7];
				IMG_n[13][ 6]          = IMG[13][ 6];
				IMG_n[13][ 7]          = IMG[13][ 7];
				IMG_n[14][ 4]          = IMG[14][ 4];
				IMG_n[14][ 5]          = IMG[14][ 5];
				IMG_n[14][ 6]          = IMG[15][ 4];
				IMG_n[14][ 7]          = IMG[15][ 5];
				IMG_n[15][ 4]          = IMG[14][ 6];
				IMG_n[15][ 5]          = IMG[14][ 7];
				IMG_n[15][ 6]          = IMG[15][ 6];
				IMG_n[15][ 7]          = IMG[15][ 7];

				// Block at row 12..15, col 8..11
				IMG_n[12][ 8]          = IMG[12][ 8];
				IMG_n[12][ 9]          = IMG[12][ 9];
				IMG_n[12][10]          = IMG[13][ 8];
				IMG_n[12][11]          = IMG[13][ 9];
				IMG_n[13][ 8]          = IMG[12][10];
				IMG_n[13][ 9]          = IMG[12][11];
				IMG_n[13][10]          = IMG[13][10];
				IMG_n[13][11]          = IMG[13][11];
				IMG_n[14][ 8]          = IMG[14][ 8];
				IMG_n[14][ 9]          = IMG[14][ 9];
				IMG_n[14][10]          = IMG[15][ 8];
				IMG_n[14][11]          = IMG[15][ 9];
				IMG_n[15][ 8]          = IMG[14][10];
				IMG_n[15][ 9]          = IMG[14][11];
				IMG_n[15][10]          = IMG[15][10];
				IMG_n[15][11]          = IMG[15][11];

				// Block at row 12..15, col 12..15
				IMG_n[12][12]          = IMG[12][12];
				IMG_n[12][13]          = IMG[12][13];
				IMG_n[12][14]          = IMG[13][12];
				IMG_n[12][15]          = IMG[13][13];
				IMG_n[13][12]          = IMG[12][14];
				IMG_n[13][13]          = IMG[12][15];
				IMG_n[13][14]          = IMG[13][14];
				IMG_n[13][15]          = IMG[13][15];
				IMG_n[14][12]          = IMG[14][12];
				IMG_n[14][13]          = IMG[14][13];
				IMG_n[14][14]          = IMG[15][12];
				IMG_n[14][15]          = IMG[15][13];
				IMG_n[15][12]          = IMG[14][14];
				IMG_n[15][13]          = IMG[14][15];
				IMG_n[15][14]          = IMG[15][14];
				IMG_n[15][15]          = IMG[15][15];
			end
			4'b1111: begin
				// Block at row 0..7, col 0..7
				IMG_n[ 0][ 0]          = IMG[ 0][ 0];
				IMG_n[ 0][ 1]          = IMG[ 0][ 1];
				IMG_n[ 0][ 2]          = IMG[ 1][ 0];
				IMG_n[ 0][ 3]          = IMG[ 1][ 1];
				IMG_n[ 0][ 4]          = IMG[ 0][ 2];
				IMG_n[ 0][ 5]          = IMG[ 0][ 3];
				IMG_n[ 0][ 6]          = IMG[ 1][ 2];
				IMG_n[ 0][ 7]          = IMG[ 1][ 3];
				IMG_n[ 1][ 0]          = IMG[ 2][ 0];
				IMG_n[ 1][ 1]          = IMG[ 2][ 1];
				IMG_n[ 1][ 2]          = IMG[ 3][ 0];
				IMG_n[ 1][ 3]          = IMG[ 3][ 1];
				IMG_n[ 1][ 4]          = IMG[ 2][ 2];
				IMG_n[ 1][ 5]          = IMG[ 2][ 3];
				IMG_n[ 1][ 6]          = IMG[ 3][ 2];
				IMG_n[ 1][ 7]          = IMG[ 3][ 3];
				IMG_n[ 2][ 0]          = IMG[ 0][ 4];
				IMG_n[ 2][ 1]          = IMG[ 0][ 5];
				IMG_n[ 2][ 2]          = IMG[ 1][ 4];
				IMG_n[ 2][ 3]          = IMG[ 1][ 5];
				IMG_n[ 2][ 4]          = IMG[ 0][ 6];
				IMG_n[ 2][ 5]          = IMG[ 0][ 7];
				IMG_n[ 2][ 6]          = IMG[ 1][ 6];
				IMG_n[ 2][ 7]          = IMG[ 1][ 7];
				IMG_n[ 3][ 0]          = IMG[ 2][ 4];
				IMG_n[ 3][ 1]          = IMG[ 2][ 5];
				IMG_n[ 3][ 2]          = IMG[ 3][ 4];
				IMG_n[ 3][ 3]          = IMG[ 3][ 5];
				IMG_n[ 3][ 4]          = IMG[ 2][ 6];
				IMG_n[ 3][ 5]          = IMG[ 2][ 7];
				IMG_n[ 3][ 6]          = IMG[ 3][ 6];
				IMG_n[ 3][ 7]          = IMG[ 3][ 7];
				IMG_n[ 4][ 0]          = IMG[ 4][ 0];
				IMG_n[ 4][ 1]          = IMG[ 4][ 1];
				IMG_n[ 4][ 2]          = IMG[ 5][ 0];
				IMG_n[ 4][ 3]          = IMG[ 5][ 1];
				IMG_n[ 4][ 4]          = IMG[ 4][ 2];
				IMG_n[ 4][ 5]          = IMG[ 4][ 3];
				IMG_n[ 4][ 6]          = IMG[ 5][ 2];
				IMG_n[ 4][ 7]          = IMG[ 5][ 3];
				IMG_n[ 5][ 0]          = IMG[ 6][ 0];
				IMG_n[ 5][ 1]          = IMG[ 6][ 1];
				IMG_n[ 5][ 2]          = IMG[ 7][ 0];
				IMG_n[ 5][ 3]          = IMG[ 7][ 1];
				IMG_n[ 5][ 4]          = IMG[ 6][ 2];
				IMG_n[ 5][ 5]          = IMG[ 6][ 3];
				IMG_n[ 5][ 6]          = IMG[ 7][ 2];
				IMG_n[ 5][ 7]          = IMG[ 7][ 3];
				IMG_n[ 6][ 0]          = IMG[ 4][ 4];
				IMG_n[ 6][ 1]          = IMG[ 4][ 5];
				IMG_n[ 6][ 2]          = IMG[ 5][ 4];
				IMG_n[ 6][ 3]          = IMG[ 5][ 5];
				IMG_n[ 6][ 4]          = IMG[ 4][ 6];
				IMG_n[ 6][ 5]          = IMG[ 4][ 7];
				IMG_n[ 6][ 6]          = IMG[ 5][ 6];
				IMG_n[ 6][ 7]          = IMG[ 5][ 7];
				IMG_n[ 7][ 0]          = IMG[ 6][ 4];
				IMG_n[ 7][ 1]          = IMG[ 6][ 5];
				IMG_n[ 7][ 2]          = IMG[ 7][ 4];
				IMG_n[ 7][ 3]          = IMG[ 7][ 5];
				IMG_n[ 7][ 4]          = IMG[ 6][ 6];
				IMG_n[ 7][ 5]          = IMG[ 6][ 7];
				IMG_n[ 7][ 6]          = IMG[ 7][ 6];
				IMG_n[ 7][ 7]          = IMG[ 7][ 7];

				// Block at row 0..7, col 8..15
				IMG_n[ 0][ 8]          = IMG[ 0][ 8];
				IMG_n[ 0][ 9]          = IMG[ 0][ 9];
				IMG_n[ 0][10]          = IMG[ 1][ 8];
				IMG_n[ 0][11]          = IMG[ 1][ 9];
				IMG_n[ 0][12]          = IMG[ 0][10];
				IMG_n[ 0][13]          = IMG[ 0][11];
				IMG_n[ 0][14]          = IMG[ 1][10];
				IMG_n[ 0][15]          = IMG[ 1][11];
				IMG_n[ 1][ 8]          = IMG[ 2][ 8];
				IMG_n[ 1][ 9]          = IMG[ 2][ 9];
				IMG_n[ 1][10]          = IMG[ 3][ 8];
				IMG_n[ 1][11]          = IMG[ 3][ 9];
				IMG_n[ 1][12]          = IMG[ 2][10];
				IMG_n[ 1][13]          = IMG[ 2][11];
				IMG_n[ 1][14]          = IMG[ 3][10];
				IMG_n[ 1][15]          = IMG[ 3][11];
				IMG_n[ 2][ 8]          = IMG[ 0][12];
				IMG_n[ 2][ 9]          = IMG[ 0][13];
				IMG_n[ 2][10]          = IMG[ 1][12];
				IMG_n[ 2][11]          = IMG[ 1][13];
				IMG_n[ 2][12]          = IMG[ 0][14];
				IMG_n[ 2][13]          = IMG[ 0][15];
				IMG_n[ 2][14]          = IMG[ 1][14];
				IMG_n[ 2][15]          = IMG[ 1][15];
				IMG_n[ 3][ 8]          = IMG[ 2][12];
				IMG_n[ 3][ 9]          = IMG[ 2][13];
				IMG_n[ 3][10]          = IMG[ 3][12];
				IMG_n[ 3][11]          = IMG[ 3][13];
				IMG_n[ 3][12]          = IMG[ 2][14];
				IMG_n[ 3][13]          = IMG[ 2][15];
				IMG_n[ 3][14]          = IMG[ 3][14];
				IMG_n[ 3][15]          = IMG[ 3][15];
				IMG_n[ 4][ 8]          = IMG[ 4][ 8];
				IMG_n[ 4][ 9]          = IMG[ 4][ 9];
				IMG_n[ 4][10]          = IMG[ 5][ 8];
				IMG_n[ 4][11]          = IMG[ 5][ 9];
				IMG_n[ 4][12]          = IMG[ 4][10];
				IMG_n[ 4][13]          = IMG[ 4][11];
				IMG_n[ 4][14]          = IMG[ 5][10];
				IMG_n[ 4][15]          = IMG[ 5][11];
				IMG_n[ 5][ 8]          = IMG[ 6][ 8];
				IMG_n[ 5][ 9]          = IMG[ 6][ 9];
				IMG_n[ 5][10]          = IMG[ 7][ 8];
				IMG_n[ 5][11]          = IMG[ 7][ 9];
				IMG_n[ 5][12]          = IMG[ 6][10];
				IMG_n[ 5][13]          = IMG[ 6][11];
				IMG_n[ 5][14]          = IMG[ 7][10];
				IMG_n[ 5][15]          = IMG[ 7][11];
				IMG_n[ 6][ 8]          = IMG[ 4][12];
				IMG_n[ 6][ 9]          = IMG[ 4][13];
				IMG_n[ 6][10]          = IMG[ 5][12];
				IMG_n[ 6][11]          = IMG[ 5][13];
				IMG_n[ 6][12]          = IMG[ 4][14];
				IMG_n[ 6][13]          = IMG[ 4][15];
				IMG_n[ 6][14]          = IMG[ 5][14];
				IMG_n[ 6][15]          = IMG[ 5][15];
				IMG_n[ 7][ 8]          = IMG[ 6][12];
				IMG_n[ 7][ 9]          = IMG[ 6][13];
				IMG_n[ 7][10]          = IMG[ 7][12];
				IMG_n[ 7][11]          = IMG[ 7][13];
				IMG_n[ 7][12]          = IMG[ 6][14];
				IMG_n[ 7][13]          = IMG[ 6][15];
				IMG_n[ 7][14]          = IMG[ 7][14];
				IMG_n[ 7][15]          = IMG[ 7][15];

				// Block at row 8..15, col 0..7
				IMG_n[ 8][ 0]          = IMG[ 8][ 0];
				IMG_n[ 8][ 1]          = IMG[ 8][ 1];
				IMG_n[ 8][ 2]          = IMG[ 9][ 0];
				IMG_n[ 8][ 3]          = IMG[ 9][ 1];
				IMG_n[ 8][ 4]          = IMG[ 8][ 2];
				IMG_n[ 8][ 5]          = IMG[ 8][ 3];
				IMG_n[ 8][ 6]          = IMG[ 9][ 2];
				IMG_n[ 8][ 7]          = IMG[ 9][ 3];
				IMG_n[ 9][ 0]          = IMG[10][ 0];
				IMG_n[ 9][ 1]          = IMG[10][ 1];
				IMG_n[ 9][ 2]          = IMG[11][ 0];
				IMG_n[ 9][ 3]          = IMG[11][ 1];
				IMG_n[ 9][ 4]          = IMG[10][ 2];
				IMG_n[ 9][ 5]          = IMG[10][ 3];
				IMG_n[ 9][ 6]          = IMG[11][ 2];
				IMG_n[ 9][ 7]          = IMG[11][ 3];
				IMG_n[10][ 0]          = IMG[ 8][ 4];
				IMG_n[10][ 1]          = IMG[ 8][ 5];
				IMG_n[10][ 2]          = IMG[ 9][ 4];
				IMG_n[10][ 3]          = IMG[ 9][ 5];
				IMG_n[10][ 4]          = IMG[ 8][ 6];
				IMG_n[10][ 5]          = IMG[ 8][ 7];
				IMG_n[10][ 6]          = IMG[ 9][ 6];
				IMG_n[10][ 7]          = IMG[ 9][ 7];
				IMG_n[11][ 0]          = IMG[10][ 4];
				IMG_n[11][ 1]          = IMG[10][ 5];
				IMG_n[11][ 2]          = IMG[11][ 4];
				IMG_n[11][ 3]          = IMG[11][ 5];
				IMG_n[11][ 4]          = IMG[10][ 6];
				IMG_n[11][ 5]          = IMG[10][ 7];
				IMG_n[11][ 6]          = IMG[11][ 6];
				IMG_n[11][ 7]          = IMG[11][ 7];
				IMG_n[12][ 0]          = IMG[12][ 0];
				IMG_n[12][ 1]          = IMG[12][ 1];
				IMG_n[12][ 2]          = IMG[13][ 0];
				IMG_n[12][ 3]          = IMG[13][ 1];
				IMG_n[12][ 4]          = IMG[12][ 2];
				IMG_n[12][ 5]          = IMG[12][ 3];
				IMG_n[12][ 6]          = IMG[13][ 2];
				IMG_n[12][ 7]          = IMG[13][ 3];
				IMG_n[13][ 0]          = IMG[14][ 0];
				IMG_n[13][ 1]          = IMG[14][ 1];
				IMG_n[13][ 2]          = IMG[15][ 0];
				IMG_n[13][ 3]          = IMG[15][ 1];
				IMG_n[13][ 4]          = IMG[14][ 2];
				IMG_n[13][ 5]          = IMG[14][ 3];
				IMG_n[13][ 6]          = IMG[15][ 2];
				IMG_n[13][ 7]          = IMG[15][ 3];
				IMG_n[14][ 0]          = IMG[12][ 4];
				IMG_n[14][ 1]          = IMG[12][ 5];
				IMG_n[14][ 2]          = IMG[13][ 4];
				IMG_n[14][ 3]          = IMG[13][ 5];
				IMG_n[14][ 4]          = IMG[12][ 6];
				IMG_n[14][ 5]          = IMG[12][ 7];
				IMG_n[14][ 6]          = IMG[13][ 6];
				IMG_n[14][ 7]          = IMG[13][ 7];
				IMG_n[15][ 0]          = IMG[14][ 4];
				IMG_n[15][ 1]          = IMG[14][ 5];
				IMG_n[15][ 2]          = IMG[15][ 4];
				IMG_n[15][ 3]          = IMG[15][ 5];
				IMG_n[15][ 4]          = IMG[14][ 6];
				IMG_n[15][ 5]          = IMG[14][ 7];
				IMG_n[15][ 6]          = IMG[15][ 6];
				IMG_n[15][ 7]          = IMG[15][ 7];

				// Block at row 8..15, col 8..15
				IMG_n[ 8][ 8]          = IMG[ 8][ 8];
				IMG_n[ 8][ 9]          = IMG[ 8][ 9];
				IMG_n[ 8][10]          = IMG[ 9][ 8];
				IMG_n[ 8][11]          = IMG[ 9][ 9];
				IMG_n[ 8][12]          = IMG[ 8][10];
				IMG_n[ 8][13]          = IMG[ 8][11];
				IMG_n[ 8][14]          = IMG[ 9][10];
				IMG_n[ 8][15]          = IMG[ 9][11];
				IMG_n[ 9][ 8]          = IMG[10][ 8];
				IMG_n[ 9][ 9]          = IMG[10][ 9];
				IMG_n[ 9][10]          = IMG[11][ 8];
				IMG_n[ 9][11]          = IMG[11][ 9];
				IMG_n[ 9][12]          = IMG[10][10];
				IMG_n[ 9][13]          = IMG[10][11];
				IMG_n[ 9][14]          = IMG[11][10];
				IMG_n[ 9][15]          = IMG[11][11];
				IMG_n[10][ 8]          = IMG[ 8][12];
				IMG_n[10][ 9]          = IMG[ 8][13];
				IMG_n[10][10]          = IMG[ 9][12];
				IMG_n[10][11]          = IMG[ 9][13];
				IMG_n[10][12]          = IMG[ 8][14];
				IMG_n[10][13]          = IMG[ 8][15];
				IMG_n[10][14]          = IMG[ 9][14];
				IMG_n[10][15]          = IMG[ 9][15];
				IMG_n[11][ 8]          = IMG[10][12];
				IMG_n[11][ 9]          = IMG[10][13];
				IMG_n[11][10]          = IMG[11][12];
				IMG_n[11][11]          = IMG[11][13];
				IMG_n[11][12]          = IMG[10][14];
				IMG_n[11][13]          = IMG[10][15];
				IMG_n[11][14]          = IMG[11][14];
				IMG_n[11][15]          = IMG[11][15];
				IMG_n[12][ 8]          = IMG[12][ 8];
				IMG_n[12][ 9]          = IMG[12][ 9];
				IMG_n[12][10]          = IMG[13][ 8];
				IMG_n[12][11]          = IMG[13][ 9];
				IMG_n[12][12]          = IMG[12][10];
				IMG_n[12][13]          = IMG[12][11];
				IMG_n[12][14]          = IMG[13][10];
				IMG_n[12][15]          = IMG[13][11];
				IMG_n[13][ 8]          = IMG[14][ 8];
				IMG_n[13][ 9]          = IMG[14][ 9];
				IMG_n[13][10]          = IMG[15][ 8];
				IMG_n[13][11]          = IMG[15][ 9];
				IMG_n[13][12]          = IMG[14][10];
				IMG_n[13][13]          = IMG[14][11];
				IMG_n[13][14]          = IMG[15][10];
				IMG_n[13][15]          = IMG[15][11];
				IMG_n[14][ 8]          = IMG[12][12];
				IMG_n[14][ 9]          = IMG[12][13];
				IMG_n[14][10]          = IMG[13][12];
				IMG_n[14][11]          = IMG[13][13];
				IMG_n[14][12]          = IMG[12][14];
				IMG_n[14][13]          = IMG[12][15];
				IMG_n[14][14]          = IMG[13][14];
				IMG_n[14][15]          = IMG[13][15];
				IMG_n[15][ 8]          = IMG[14][12];
				IMG_n[15][ 9]          = IMG[14][13];
				IMG_n[15][10]          = IMG[15][12];
				IMG_n[15][11]          = IMG[15][13];
				IMG_n[15][12]          = IMG[14][14];
				IMG_n[15][13]          = IMG[14][15];
				IMG_n[15][14]          = IMG[15][14];
				IMG_n[15][15]          = IMG[15][15];
			end
		endcase
	end
	if(cs == WRITE) begin
		addr_ctr_n  = addr_ctr + 1;
		case (md[6:4])
			0: begin
				mem0_addr_n        = (md[3:0] << 8) + addr_ctr;
				mem0_din_n         = IMG[idx[7:4]][idx[3:0]];
				mem0_web_n         = 0;
				idx_n              = idx + 1;
			end
			1: begin
				mem1_addr_n        = (md[3:0] << 8) + addr_ctr;
				mem1_din_n         = IMG[idx[7:4]][idx[3:0]];
				mem1_web_n         = 0;
				idx_n              = idx + 1;
			end
			2: begin
				mem2_addr_n        = (md[3:0] << 8) + addr_ctr;
				mem2_din_n         = IMG[idx[7:4]][idx[3:0]];
				mem2_web_n         = 0;
				idx_n              = idx + 1;
			end
			3: begin
				mem3_addr_n        = (md[3:0] << 8) + addr_ctr;
				mem3_din_n         = IMG[idx[7:4]][idx[3:0]];
				mem3_web_n         = 0;
				idx_n              = idx + 1;
			end
			4: begin
				mem4_addr_n        = (md[3:0] << 7) + addr_ctr;
				mem4_din_n[15: 8]  = IMG[idx      [7:4]][idx      [3:0]];
				mem4_din_n[ 7: 0]  = IMG[idx_plus1[7:4]][idx_plus1[3:0]];
				mem4_web_n         = 0;
				idx_n              = idx + 2;
			end
			5: begin
				mem5_addr_n        = (md[3:0] << 7) + addr_ctr;
				mem5_din_n[15: 8]  = IMG[idx      [7:4]][idx      [3:0]];
				mem5_din_n[ 7: 0]  = IMG[idx_plus1[7:4]][idx_plus1[3:0]];
				mem5_web_n         = 0;
				idx_n              = idx + 2;
			end
			6: begin
				mem6_addr_n        = (md[3:0] << 6) + addr_ctr;
				mem6_din_n[31:24]  = IMG[idx      [7:4]][idx      [3:0]];
				mem6_din_n[23:16]  = IMG[idx_plus1[7:4]][idx_plus1[3:0]];
				mem6_din_n[15: 8]  = IMG[idx_plus2[7:4]][idx_plus2[3:0]];
				mem6_din_n[ 7: 0]  = IMG[idx_plus3[7:4]][idx_plus3[3:0]];
				mem6_web_n         = 0;
				idx_n              = idx + 4;
			end
			7: begin
				mem7_addr_n        = (md[3:0] << 6) + addr_ctr;
				mem7_din_n[31:24]  = IMG[idx      [7:4]][idx      [3:0]];
				mem7_din_n[23:16]  = IMG[idx_plus1[7:4]][idx_plus1[3:0]];
				mem7_din_n[15: 8]  = IMG[idx_plus2[7:4]][idx_plus2[3:0]];
				mem7_din_n[ 7: 0]  = IMG[idx_plus3[7:4]][idx_plus3[3:0]];
				mem7_web_n         = 0;
				idx_n              = idx + 4;
			end
		endcase
	end
	
	if(cs == OUT) begin
		stall_n = 1;
		if(stall) busy_n = 0;
	end
end



//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/* 
  There are eight SRAMs in your GTE. You should not change the name of those SRAMs.
  TA will check the value in each SRAMs when your GTE is not busy.
  If you change the name of SRAMs below, you must get the fail in this lab.
  
  You should finish SRAM-related signals assignments for each SRAM.
*/
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


// MEM_0, MEM_1, MEM_2, MEM_3, MEM_4, MEM_5, MEM_6, MEM_7 instantiation
SUMA180_4096X8X1BM4 MEM0(
    .A0(mem0_addr[0]), .A1(mem0_addr[1]), .A2(mem0_addr[2]), .A3(mem0_addr[3]), .A4(mem0_addr[4]), .A5(mem0_addr[5]), .A6(mem0_addr[6]), .A7(mem0_addr[7]), 
    .A8(mem0_addr[8]), .A9(mem0_addr[9]), .A10(mem0_addr[10]), .A11(mem0_addr[11]),
    .DO0(mem0_dout[0]), .DO1(mem0_dout[1]), .DO2(mem0_dout[2]), .DO3(mem0_dout[3]), .DO4(mem0_dout[4]), .DO5(mem0_dout[5]), .DO6(mem0_dout[6]), .DO7(mem0_dout[7]),
    .DI0(mem0_din[0]), .DI1(mem0_din[1]), .DI2(mem0_din[2]), .DI3(mem0_din[3]), .DI4(mem0_din[4]), .DI5(mem0_din[5]), .DI6(mem0_din[6]), .DI7(mem0_din[7]),
    .CK(clk), .WEB(mem0_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM1(
    .A0(mem1_addr[0]), .A1(mem1_addr[1]), .A2(mem1_addr[2]), .A3(mem1_addr[3]), .A4(mem1_addr[4]), .A5(mem1_addr[5]), .A6(mem1_addr[6]), .A7(mem1_addr[7]), 
    .A8(mem1_addr[8]), .A9(mem1_addr[9]), .A10(mem1_addr[10]), .A11(mem1_addr[11]),
    .DO0(mem1_dout[0]), .DO1(mem1_dout[1]), .DO2(mem1_dout[2]), .DO3(mem1_dout[3]), .DO4(mem1_dout[4]), .DO5(mem1_dout[5]), .DO6(mem1_dout[6]), .DO7(mem1_dout[7]),
    .DI0(mem1_din[0]), .DI1(mem1_din[1]), .DI2(mem1_din[2]), .DI3(mem1_din[3]), .DI4(mem1_din[4]), .DI5(mem1_din[5]), .DI6(mem1_din[6]), .DI7(mem1_din[7]),
    .CK(clk), .WEB(mem1_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM2 (
    .A0(mem2_addr[0]), .A1(mem2_addr[1]), .A2(mem2_addr[2]), .A3(mem2_addr[3]), .A4(mem2_addr[4]), .A5(mem2_addr[5]), .A6(mem2_addr[6]), .A7(mem2_addr[7]),
    .A8(mem2_addr[8]), .A9(mem2_addr[9]), .A10(mem2_addr[10]), .A11(mem2_addr[11]),
    .DO0(mem2_dout[0]), .DO1(mem2_dout[1]), .DO2(mem2_dout[2]), .DO3(mem2_dout[3]), .DO4(mem2_dout[4]), .DO5(mem2_dout[5]), .DO6(mem2_dout[6]), .DO7(mem2_dout[7]),
    .DI0(mem2_din[0]), .DI1(mem2_din[1]), .DI2(mem2_din[2]), .DI3(mem2_din[3]), .DI4(mem2_din[4]), .DI5(mem2_din[5]), .DI6(mem2_din[6]), .DI7(mem2_din[7]),
    .CK(clk), .WEB(mem2_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM3(
    .A0(mem3_addr[0]), .A1(mem3_addr[1]), .A2(mem3_addr[2]), .A3(mem3_addr[3]), .A4(mem3_addr[4]), .A5(mem3_addr[5]), .A6(mem3_addr[6]), .A7(mem3_addr[7]), 
    .A8(mem3_addr[8]), .A9(mem3_addr[9]), .A10(mem3_addr[10]), .A11(mem3_addr[11]),
    .DO0(mem3_dout[0]), .DO1(mem3_dout[1]), .DO2(mem3_dout[2]), .DO3(mem3_dout[3]), .DO4(mem3_dout[4]), .DO5(mem3_dout[5]), .DO6(mem3_dout[6]), .DO7(mem3_dout[7]),
    .DI0(mem3_din[0]), .DI1(mem3_din[1]), .DI2(mem3_din[2]), .DI3(mem3_din[3]), .DI4(mem3_din[4]), .DI5(mem3_din[5]), .DI6(mem3_din[6]), .DI7(mem3_din[7]),
    .CK(clk), .WEB(mem3_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_2048X16X1BM1 MEM4(
	.A0(mem4_addr[0]), .A1(mem4_addr[1]), .A2(mem4_addr[2]), .A3(mem4_addr[3]), .A4(mem4_addr[4]), .A5(mem4_addr[5]), .A6(mem4_addr[6]), .A7(mem4_addr[7]), 
	.A8(mem4_addr[8]), .A9(mem4_addr[9]), .A10(mem4_addr[10]),
	.DO0(mem4_dout[0]), .DO1(mem4_dout[1]), .DO2(mem4_dout[2]), .DO3(mem4_dout[3]), .DO4(mem4_dout[4]), .DO5(mem4_dout[5]), .DO6(mem4_dout[6]), .DO7(mem4_dout[7]), 
	.DO8(mem4_dout[8]), .DO9(mem4_dout[9]), .DO10(mem4_dout[10]), .DO11(mem4_dout[11]), .DO12(mem4_dout[12]), .DO13(mem4_dout[13]), .DO14(mem4_dout[14]), .DO15(mem4_dout[15]),
	.DI0(mem4_din[0]), .DI1(mem4_din[1]), .DI2(mem4_din[2]), .DI3(mem4_din[3]), .DI4(mem4_din[4]), .DI5(mem4_din[5]), .DI6(mem4_din[6]), .DI7(mem4_din[7]), 
	.DI8(mem4_din[8]), .DI9(mem4_din[9]), .DI10(mem4_din[10]), .DI11(mem4_din[11]), .DI12(mem4_din[12]), .DI13(mem4_din[13]), .DI14(mem4_din[14]), .DI15(mem4_din[15]),
	.CK(clk), .WEB(mem4_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_2048X16X1BM1 MEM5(
	.A0(mem5_addr[0]), .A1(mem5_addr[1]), .A2(mem5_addr[2]), .A3(mem5_addr[3]), .A4(mem5_addr[4]), .A5(mem5_addr[5]), .A6(mem5_addr[6]), .A7(mem5_addr[7]), 
	.A8(mem5_addr[8]), .A9(mem5_addr[9]), .A10(mem5_addr[10]),
	.DO0(mem5_dout[0]), .DO1(mem5_dout[1]), .DO2(mem5_dout[2]), .DO3(mem5_dout[3]), .DO4(mem5_dout[4]), .DO5(mem5_dout[5]), .DO6(mem5_dout[6]), .DO7(mem5_dout[7]), 
	.DO8(mem5_dout[8]), .DO9(mem5_dout[9]), .DO10(mem5_dout[10]), .DO11(mem5_dout[11]), .DO12(mem5_dout[12]), .DO13(mem5_dout[13]), .DO14(mem5_dout[14]), .DO15(mem5_dout[15]),
	.DI0(mem5_din[0]), .DI1(mem5_din[1]), .DI2(mem5_din[2]), .DI3(mem5_din[3]), .DI4(mem5_din[4]), .DI5(mem5_din[5]), .DI6(mem5_din[6]), .DI7(mem5_din[7]), 
	.DI8(mem5_din[8]), .DI9(mem5_din[9]), .DI10(mem5_din[10]), .DI11(mem5_din[11]), .DI12(mem5_din[12]), .DI13(mem5_din[13]), .DI14(mem5_din[14]), .DI15(mem5_din[15]),
	.CK(clk), .WEB(mem5_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_1024X32X1BM2 MEM6(
	.A0(mem6_addr[0]), .A1(mem6_addr[1]), .A2(mem6_addr[2]), .A3(mem6_addr[3]), .A4(mem6_addr[4]), .A5(mem6_addr[5]), .A6(mem6_addr[6]), .A7(mem6_addr[7]), 
	.A8(mem6_addr[8]), .A9(mem6_addr[9]),
	.DO0(mem6_dout[0]), .DO1(mem6_dout[1]), .DO2(mem6_dout[2]), .DO3(mem6_dout[3]), .DO4(mem6_dout[4]), .DO5(mem6_dout[5]), .DO6(mem6_dout[6]), .DO7(mem6_dout[7]), 
	.DO8(mem6_dout[8]), .DO9(mem6_dout[9]), .DO10(mem6_dout[10]), .DO11(mem6_dout[11]), .DO12(mem6_dout[12]), .DO13(mem6_dout[13]), .DO14(mem6_dout[14]), .DO15(mem6_dout[15]), 
	.DO16(mem6_dout[16]), .DO17(mem6_dout[17]), .DO18(mem6_dout[18]), .DO19(mem6_dout[19]), .DO20(mem6_dout[20]), .DO21(mem6_dout[21]), .DO22(mem6_dout[22]), .DO23(mem6_dout[23]), 
	.DO24(mem6_dout[24]), .DO25(mem6_dout[25]), .DO26(mem6_dout[26]), .DO27(mem6_dout[27]), .DO28(mem6_dout[28]), .DO29(mem6_dout[29]), .DO30(mem6_dout[30]), .DO31(mem6_dout[31]),
	.DI0(mem6_din[0]), .DI1(mem6_din[1]), .DI2(mem6_din[2]), .DI3(mem6_din[3]), .DI4(mem6_din[4]), .DI5(mem6_din[5]), .DI6(mem6_din[6]), .DI7(mem6_din[7]), 
	.DI8(mem6_din[8]), .DI9(mem6_din[9]), .DI10(mem6_din[10]), .DI11(mem6_din[11]), .DI12(mem6_din[12]), .DI13(mem6_din[13]), .DI14(mem6_din[14]), .DI15(mem6_din[15]), 
	.DI16(mem6_din[16]), .DI17(mem6_din[17]), .DI18(mem6_din[18]), .DI19(mem6_din[19]), .DI20(mem6_din[20]), .DI21(mem6_din[21]), .DI22(mem6_din[22]), .DI23(mem6_din[23]), 
	.DI24(mem6_din[24]), .DI25(mem6_din[25]), .DI26(mem6_din[26]), .DI27(mem6_din[27]), .DI28(mem6_din[28]), .DI29(mem6_din[29]), .DI30(mem6_din[30]), .DI31(mem6_din[31]),
	.CK(clk), .WEB(mem6_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_1024X32X1BM2 MEM7(
	.A0(mem7_addr[0]), .A1(mem7_addr[1]), .A2(mem7_addr[2]), .A3(mem7_addr[3]), .A4(mem7_addr[4]), .A5(mem7_addr[5]), .A6(mem7_addr[6]), .A7(mem7_addr[7]), 
	.A8(mem7_addr[8]), .A9(mem7_addr[9]),
	.DO0(mem7_dout[0]), .DO1(mem7_dout[1]), .DO2(mem7_dout[2]), .DO3(mem7_dout[3]), .DO4(mem7_dout[4]), .DO5(mem7_dout[5]), .DO6(mem7_dout[6]), .DO7(mem7_dout[7]), 
	.DO8(mem7_dout[8]), .DO9(mem7_dout[9]), .DO10(mem7_dout[10]), .DO11(mem7_dout[11]), .DO12(mem7_dout[12]), .DO13(mem7_dout[13]), .DO14(mem7_dout[14]), .DO15(mem7_dout[15]), 
	.DO16(mem7_dout[16]), .DO17(mem7_dout[17]), .DO18(mem7_dout[18]), .DO19(mem7_dout[19]), .DO20(mem7_dout[20]), .DO21(mem7_dout[21]), .DO22(mem7_dout[22]), .DO23(mem7_dout[23]), 
	.DO24(mem7_dout[24]), .DO25(mem7_dout[25]), .DO26(mem7_dout[26]), .DO27(mem7_dout[27]), .DO28(mem7_dout[28]), .DO29(mem7_dout[29]), .DO30(mem7_dout[30]), .DO31(mem7_dout[31]),
	.DI0(mem7_din[0]), .DI1(mem7_din[1]), .DI2(mem7_din[2]), .DI3(mem7_din[3]), .DI4(mem7_din[4]), .DI5(mem7_din[5]), .DI6(mem7_din[6]), .DI7(mem7_din[7]), 
	.DI8(mem7_din[8]), .DI9(mem7_din[9]), .DI10(mem7_din[10]), .DI11(mem7_din[11]), .DI12(mem7_din[12]), .DI13(mem7_din[13]), .DI14(mem7_din[14]), .DI15(mem7_din[15]), 
	.DI16(mem7_din[16]), .DI17(mem7_din[17]), .DI18(mem7_din[18]), .DI19(mem7_din[19]), .DI20(mem7_din[20]), .DI21(mem7_din[21]), .DI22(mem7_din[22]), .DI23(mem7_din[23]), 
	.DI24(mem7_din[24]), .DI25(mem7_din[25]), .DI26(mem7_din[26]), .DI27(mem7_din[27]), .DI28(mem7_din[28]), .DI29(mem7_din[29]), .DI30(mem7_din[30]), .DI31(mem7_din[31]),
	.CK(clk), .WEB(mem7_web), .OE(1'b1), .CS(1'b1)
);

endmodule