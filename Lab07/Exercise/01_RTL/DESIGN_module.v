/**************************************************************************
 * Copyright (c) 2025, OASIS Lab
 * MODULE: CLK_1_MODULE, CLK_2_MODULE, CLK_3_MODULE
 * FILE NAME: DESIGN_module.v
 * VERSRION: 1.0
 * DATE: Oct 29, 2025
 * AUTHOR: Chao-En Kuo, NYCU IAIS
 * DESCRIPTION: ICLAB2025FALL / LAB7 / DESIGN_module
 * MODIFICATION HISTORY:
 * Date                 Description
 * 
 *************************************************************************/
module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
    in_data,
    out_idle,
    out_valid,
    out_data,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             in_valid;
input      [31:0] in_data;
input             out_idle;
output reg        out_valid;
output reg [31:0] out_data;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;
output flag_clk1_to_handshake;


// PARAM

parameter DEPTH = 16,
          WIDTH = 32,
          PTR_WIDTH = 4,
          CNT_WIDTH = 5;

parameter IDLE  = 3'd0,
          TRANS = 3'd1;

integer  i, j, k;


wire push;
wire pop;
// REGISTER & WIRE
reg [WIDTH-1:0] fifo_mem [0:DEPTH-1];
reg [WIDTH-1:0] fifo_mem_n [0:DEPTH-1];
reg [PTR_WIDTH-1:0] wptr;     // Write pointer
reg [PTR_WIDTH-1:0] rptr;     // Read pointer
reg [CNT_WIDTH-1:0] count;    // Number of items in FIFO
reg [PTR_WIDTH-1:0] wptr_n;   // Write pointer
reg [PTR_WIDTH-1:0] rptr_n;   // Read pointer
reg [CNT_WIDTH-1:0] count_n;  // Number of items in FIFO
reg [2:0] cs;
reg [2:0] ns;
reg write_done;
reg write_done_n;
reg fifo_empty;
reg fifo_full;

reg out_valid_n;
reg [31:0] out_data_n;

reg        hold_valid, hold_valid_n;
reg [31:0] hold_data;
reg [31:0] hold_data_n;
reg        out_idle_d;
wire       taken;  
assign taken = hold_valid && (out_idle_d==1'b1) && (out_idle==1'b0);

always @(posedge clk or negedge rst_n) begin
  if(!rst_n) out_idle_d <= 1'b0;
  else       out_idle_d <= out_idle;
end

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
          if(in_valid) begin
            ns = TRANS;
          end else begin
            ns = cs;
          end
        end
        TRANS: begin
          if(write_done && fifo_empty) begin
            ns = IDLE;
          end else begin
            ns = cs;
          end
        end 
    endcase
end

genvar gi;
generate
    for(gi = 0; gi < DEPTH; gi = gi + 1) begin
        always @(posedge clk) begin
              fifo_mem[gi] <= fifo_mem_n[gi];
        end
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      wptr       <= 0;
      rptr       <= 0;
      count      <= 0;
      write_done <= 0;
      out_valid  <= 0;
      out_data   <= 0;
      hold_valid <= 0;
      hold_data  <= 0;
    end else begin
      wptr       <= wptr_n;
      rptr       <= rptr_n;
      count      <= count_n;
      write_done <= write_done_n;
      out_data   <= hold_data_n;
      out_valid  <= hold_valid_n;
      hold_valid <= hold_valid_n;
      hold_data  <= hold_data_n;
    end
end


always @(*) begin
    wptr_n       = wptr;
    rptr_n       = rptr;
    count_n      = count;
    write_done_n = write_done;
    fifo_empty  = (count == 0);
    fifo_full   = (count == DEPTH);
    //out_valid_n = !fifo_empty;
    hold_valid_n = hold_valid;
    hold_data_n  = hold_data;
    //out_data_n = out_valid_n ? fifo_mem[rptr] : 0;
    for(i = 0; i < DEPTH; i = i + 1) begin
        fifo_mem_n[i] = fifo_mem[i];
    end

    if (!hold_valid && !fifo_empty && out_idle) begin
        hold_valid_n = 1'b1;
        hold_data_n  = fifo_mem[rptr];
    end
    if(cs == IDLE) begin
        count_n      = 0;
        wptr_n       = 0;
        rptr_n       = 0;
        write_done_n = 0;
        count_n      = 0;
        for(i = 0; i < DEPTH; i = i + 1) begin
            fifo_mem_n[i] = 0;
        end
        if(in_valid) begin
            fifo_mem_n[0] = in_data;
            wptr_n        = 1;
            count_n       = 1;
        end
    end

    if(cs == TRANS) begin
        if(push && !taken) begin
            fifo_mem_n[wptr] = in_data;
            wptr_n           = wptr + 1;
            count_n          = count + 1;
        end else if(!push && taken) begin
            rptr_n           = rptr + 1;
            count_n          = count - 1;
            hold_valid_n = 1'b0;
        end else if(push && taken) begin
            fifo_mem_n[wptr] = in_data;
            wptr_n           = wptr + 1;
            rptr_n           = rptr + 1;
            hold_valid_n = 1'b0;
        end
            
        if(push && wptr == DEPTH - 1) begin
            write_done_n = 1;
        end
    end
end

assign push = (cs == TRANS) && !write_done;
assign pop  = !fifo_empty && out_idle;
assign flag_clk1_to_handshake = 1'b0;

endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    in_data,
    fifo_full,
    out_valid,
    out_data,
    busy,
    
    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             in_valid;
input             fifo_full;
input      [31:0] in_data;
output reg        out_valid;
output reg [15:0] out_data;
output            busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;
//---------------------------------------------------------------------
//   Parameters
//---------------------------------------------------------------------
localparam INPUT_COUNT = 16;     // 128 coeffs / 8 per clock = 16 clocks
localparam OUTPUT_COUNT = 128;   // 128-degree NTT
integer i, j, k;
// FSM States
localparam IDLE      = 3'd0; 
localparam CALC      = 3'd1;
localparam LOAD      = 3'd3;
localparam SEND      = 3'd2;

//---------------------------------------------------------------------
//   Registers & Wires
//---------------------------------------------------------------------
reg [2:0] cs, ns;

// Input Storage
reg [31:0] input_buffer   [0:INPUT_COUNT-1];
reg [31:0] input_buffer_n [0:INPUT_COUNT-1];
reg [4:0]  input_ctr;
reg [4:0]  input_ctr_n;
reg [7:0]  output_ctr;
reg [7:0]  output_ctr_n;
reg        out_valid_n;
reg [15:0] out_data_n;

wire ready_to_receive = (cs == IDLE);
assign busy = !ready_to_receive;
wire push_input = in_valid && ready_to_receive;
reg [15:0] result   [0:OUTPUT_COUNT-1];
reg [15:0] result_n [0:OUTPUT_COUNT-1];
reg [3:0]  coeffs   [0:OUTPUT_COUNT-1];
reg [3:0]  coeffs_n [0:OUTPUT_COUNT-1];
reg [2:0]  stage_ctr;
reg [2:0]  stage_ctr_n;
reg [8:0]  data_ctr;
reg [8:0]  data_ctr_n;
reg        ntt_done;
reg        ntt_done_n;
reg [13:0] bf_in_u      [0:6];
reg [13:0] bf_in_v      [0:6];
reg [13:0] bf_gmb       [0:6];
reg [13:0] bf_out_add   [0:6];
reg [13:0] bf_out_sub   [0:6];

reg [13:0] buffer0 [0:63];
reg [13:0] buffer1 [0:31];
reg [13:0] buffer2 [0:15];
reg [13:0] buffer3 [0:7];
reg [13:0] buffer4 [0:3];
reg [13:0] buffer5 [0:1];
reg [13:0] buffer6;

reg [13:0] buffer0_n [0:63];
reg [13:0] buffer1_n [0:31];
reg [13:0] buffer2_n [0:15];
reg [13:0] buffer3_n [0:7];
reg [13:0] buffer4_n [0:3];
reg [13:0] buffer5_n [0:1];
reg [13:0] buffer6_n;
reg [13:0] stage_reg [0:6];
reg [13:0] stage_reg_n [0:6];

reg [7:0] stage1_start;
reg [7:0] stage2_start;
reg [7:0] stage3_start;
reg [7:0] stage4_start;
reg [7:0] stage5_start;
reg [7:0] stage6_start;
reg fifo_full_reg;

wire stage0_is_mult_result, stage1_is_mult_result, push_sub_into_buffer;
assign stage0_is_mult_result = data_ctr[6];
assign stage1_is_mult_result = data_ctr[5];


assign push_sub_into_buffer = data_ctr[5];


//assign stage1_start = data_ctr - 96 - 1;
//assign stage2_start = data_ctr - 112 - 2;
//assign stage3_start = data_ctr - 120 - 3;
//assign stage4_start = data_ctr - 124 - 4;
//assign stage5_start = data_ctr - 126 - 5;
//assign stage6_start = data_ctr - 127 - 6;

reg [8:0]  data_ctr_stage1;
reg [8:0]  data_ctr_stage2;
reg [8:0]  data_ctr_stage3;
reg [8:0]  data_ctr_stage4;
reg [8:0]  data_ctr_stage5;
reg [8:0]  data_ctr_stage6;


//assign data_ctr_stage1 = data_ctr - 1;
//assign data_ctr_stage2 = data_ctr - 2;
//assign data_ctr_stage3 = data_ctr - 3;
//assign data_ctr_stage4 = data_ctr - 4;
//assign data_ctr_stage5 = data_ctr - 5;
//assign data_ctr_stage6 = data_ctr - 6;

//---------------------------------------------------------------------
//   GMb Look-Up Table (ROM) Function
//   Input:  [6:0] addr
//   Output: [13:0] data
//   All values sourced from GMb.txt 
//---------------------------------------------------------------------
function [13:0] get_gmb;
    input [6:0] addr;
    begin
        case (addr)
            7'd0:   get_gmb = 14'd4091;
            7'd1:   get_gmb = 14'd7888;
            7'd2:   get_gmb = 14'd11060;
            7'd3:   get_gmb = 14'd11208;
            7'd4:   get_gmb = 14'd6960;
            7'd5:   get_gmb = 14'd4342;
            7'd6:   get_gmb = 14'd6275;
            7'd7:   get_gmb = 14'd9759;
            7'd8:   get_gmb = 14'd1591;
            7'd9:   get_gmb = 14'd6399;
            7'd10:  get_gmb = 14'd9477;
            7'd11:  get_gmb = 14'd5266;
            7'd12:  get_gmb = 14'd586;
            7'd13:  get_gmb = 14'd5825;
            7'd14:  get_gmb = 14'd7538;
            7'd15:  get_gmb = 14'd9710;
            7'd16:  get_gmb = 14'd1134;
            7'd17:  get_gmb = 14'd6407;
            7'd18:  get_gmb = 14'd1711;
            7'd19:  get_gmb = 14'd965;
            7'd20:  get_gmb = 14'd7099;
            7'd21:  get_gmb = 14'd7674;
            7'd22:  get_gmb = 14'd3743;
            7'd23:  get_gmb = 14'd6442;
            7'd24:  get_gmb = 14'd10414;
            7'd25:  get_gmb = 14'd8100;
            7'd26:  get_gmb = 14'd1885;
            7'd27:  get_gmb = 14'd1688;
            7'd28:  get_gmb = 14'd1364;
            7'd29:  get_gmb = 14'd10329;
            7'd30:  get_gmb = 14'd10164;
            7'd31:  get_gmb = 14'd9180;
            7'd32:  get_gmb = 14'd12210;
            7'd33:  get_gmb = 14'd6240;
            7'd34:  get_gmb = 14'd997;
            7'd35:  get_gmb = 14'd117;
            7'd36:  get_gmb = 14'd4783;
            7'd37:  get_gmb = 14'd4407;
            7'd38:  get_gmb = 14'd1549;
            7'd39:  get_gmb = 14'd7072;
            7'd40:  get_gmb = 14'd2829;
            7'd41:  get_gmb = 14'd6458;
            7'd42:  get_gmb = 14'd4431;
            7'd43:  get_gmb = 14'd8877;
            7'd44:  get_gmb = 14'd7144;
            7'd45:  get_gmb = 14'd2564;
            7'd46:  get_gmb = 14'd5664;
            7'd47:  get_gmb = 14'd4042;
            7'd48:  get_gmb = 14'd12189;
            7'd49:  get_gmb = 14'd432;
            7'd50:  get_gmb = 14'd10751;
            7'd51:  get_gmb = 14'd1237;
            7'd52:  get_gmb = 14'd7610;
            7'd53:  get_gmb = 14'd1534;
            7'd54:  get_gmb = 14'd3983;
            7'd55:  get_gmb = 14'd7863;
            7'd56:  get_gmb = 14'd2181;
            7'd57:  get_gmb = 14'd6308;
            7'd58:  get_gmb = 14'd8720;
            7'd59:  get_gmb = 14'd6570;
            7'd60:  get_gmb = 14'd4843;
            7'd61:  get_gmb = 14'd1690;
            7'd62:  get_gmb = 14'd14;
            7'd63:  get_gmb = 14'd3872;
            7'd64:  get_gmb = 14'd5569;
            7'd65:  get_gmb = 14'd9368;
            7'd66:  get_gmb = 14'd12163;
            7'd67:  get_gmb = 14'd2019;
            7'd68:  get_gmb = 14'd7543;
            7'd69:  get_gmb = 14'd2315;
            7'd70:  get_gmb = 14'd4673;
            7'd71:  get_gmb = 14'd7340;
            7'd72:  get_gmb = 14'd1553;
            7'd73:  get_gmb = 14'd1156;
            7'd74:  get_gmb = 14'd8401;
            7'd75:  get_gmb = 14'd11389;
            7'd76:  get_gmb = 14'd1020;
            7'd77:  get_gmb = 14'd2967;
            7'd78:  get_gmb = 14'd10772;
            7'd79:  get_gmb = 14'd7045;
            7'd80:  get_gmb = 14'd3316;
            7'd81:  get_gmb = 14'd11236;
            7'd82:  get_gmb = 14'd5285;
            7'd83:  get_gmb = 14'd11578;
            7'd84:  get_gmb = 14'd10637;
            7'd85:  get_gmb = 14'd10086;
            7'd86:  get_gmb = 14'd9493;
            7'd87:  get_gmb = 14'd6180;
            7'd88:  get_gmb = 14'd9277;
            7'd89:  get_gmb = 14'd6130;
            7'd90:  get_gmb = 14'd3323;
            7'd91:  get_gmb = 14'd883;
            7'd92:  get_gmb = 14'd10469;
            7'd93:  get_gmb = 14'd489;
            7'd94:  get_gmb = 14'd1502;
            7'd95:  get_gmb = 14'd2851;
            7'd96:  get_gmb = 14'd11061;
            7'd97:  get_gmb = 14'd9729;
            7'd98:  get_gmb = 14'd2742;
            7'd99:  get_gmb = 14'd12241;
            7'd100: get_gmb = 14'd4970;
            7'd101: get_gmb = 14'd10481;
            7'd102: get_gmb = 14'd10078;
            7'd103: get_gmb = 14'd1195;
            7'd104: get_gmb = 14'd730;
            7'd105: get_gmb = 14'd1762;
            7'd106: get_gmb = 14'd3854;
            7'd107: get_gmb = 14'd2030;
            7'd108: get_gmb = 14'd5892;
            7'd109: get_gmb = 14'd10922;
            7'd110: get_gmb = 14'd9020;
            7'd111: get_gmb = 14'd5274;
            7'd112: get_gmb = 14'd9179;
            7'd113: get_gmb = 14'd3604;
            7'd114: get_gmb = 14'd3782;
            7'd115: get_gmb = 14'd10206;
            7'd116: get_gmb = 14'd3180;
            7'd117: get_gmb = 14'd3467;
            7'd118: get_gmb = 14'd4668;
            7'd119: get_gmb = 14'd2446;
            7'd120: get_gmb = 14'd7613;
            7'd121: get_gmb = 14'd9386;
            7'd122: get_gmb = 14'd834;
            7'd123: get_gmb = 14'd7703;
            7'd124: get_gmb = 14'd6836;
            7'd125: get_gmb = 14'd3403;
            7'd126: get_gmb = 14'd5351;
            7'd127: get_gmb = 14'd12276;
            default: get_gmb = 14'd0;
        endcase
    end
endfunction

//unpack the input_buffer to coeffsh 
genvar gi, gj;

generate
    for(gi = 0; gi < 7; gi = gi + 1) begin
      NTT_Butterfly_Unit #(
            .DATA_WIDTH(14),
            .Q(12289),
            .QOI(12287)
        ) u_NTT_Butterfly (
            .in_u       (bf_in_u[gi]),
            .in_v       (bf_in_v[gi]),
            .gmb        (bf_gmb[gi]),
            .out_uv_add (bf_out_add[gi]),
            .out_uv_sub (bf_out_sub[gi])
        );
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cs <= IDLE;
    else
        cs <= ns;
end

always @(*) begin
    ns = cs;
    case (cs)
        IDLE: begin
            if(push_input && (input_ctr == INPUT_COUNT - 1)) begin
                ns = LOAD;
            end
        end            
        LOAD: begin
            ns = CALC;
        end
        CALC: begin
            if(data_ctr == 261) begin
                ns = SEND;
            end
        end            
        SEND: begin
            if(output_ctr == OUTPUT_COUNT && !fifo_full) begin
                ns = IDLE;
            end
        end
    endcase
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        input_ctr           <= 0;
        //out_valid           <= 0;
        //out_data            <= 0;
        output_ctr          <= 0;
        data_ctr            <= 0;
        
        for(i = 0; i < INPUT_COUNT; i = i + 1) begin
            input_buffer[i] <= 0;
        end
        for(i = 0; i < OUTPUT_COUNT; i = i + 1) begin
            result[i]       <= 0;
            coeffs[i]       <= 0;
        end
        /*
        for(i = 0; i < 64; i = i + 1) begin
            buffer0[i]      <= 0;
        end
        for(i = 0; i < 32; i = i + 1) begin
            buffer1[i]      <= 0;
        end
        for(i = 0; i < 16; i = i + 1) begin
            buffer2[i]      <= 0;
        end
        for(i = 0; i <  8; i = i + 1) begin
            buffer3[i]      <= 0;
        end
        for(i = 0; i <  4; i = i + 1) begin
            buffer4[i]      <= 0;
        end
        for(i = 0; i <  2; i = i + 1) begin
            buffer5[i]      <= 0;
        end
        buffer6             <= 0;
        

        for(i = 0; i <  7; i = i + 1) begin
            stage_reg[i]    <= 0;
        end
        */
        
        data_ctr_stage1     <= 0;
        data_ctr_stage2     <= 0;
        data_ctr_stage3     <= 0;
        data_ctr_stage4     <= 0;
        data_ctr_stage5     <= 0;
        data_ctr_stage6     <= 0;
        stage1_start        <= 0;
        stage2_start        <= 0;
        stage3_start        <= 0;
        stage4_start        <= 0;
        stage5_start        <= 0;
        stage6_start        <= 0;

        fifo_full_reg       <= 0;
    end else begin
        input_ctr           <= input_ctr_n;
        //out_valid           <= out_valid_n;
        //out_data            <= out_data_n;
        result              <= result_n;
        output_ctr          <= output_ctr_n;
        input_buffer        <= input_buffer_n;
        coeffs              <= coeffs_n;
        buffer0             <= buffer0_n;
        buffer1             <= buffer1_n;
        buffer2             <= buffer2_n;
        buffer3             <= buffer3_n;
        buffer4             <= buffer4_n;
        buffer5             <= buffer5_n;
        buffer6             <= buffer6_n;
        data_ctr            <= data_ctr_n;
        stage_reg           <= stage_reg_n;
        data_ctr_stage1     <= data_ctr_n - 1;
        data_ctr_stage2     <= data_ctr_n - 2;
        data_ctr_stage3     <= data_ctr_n - 3;
        data_ctr_stage4     <= data_ctr_n - 4;
        data_ctr_stage5     <= data_ctr_n - 5;
        data_ctr_stage6     <= data_ctr_n - 6;
        stage1_start        <= data_ctr_n - 96 - 1;
        stage2_start        <= data_ctr_n - 112 - 2;
        stage3_start        <= data_ctr_n - 120 - 3;
        stage4_start        <= data_ctr_n - 124 - 4;
        stage5_start        <= data_ctr_n - 126 - 5;
        stage6_start        <= data_ctr_n - 127 - 6;
        fifo_full_reg       <= fifo_full;
    end
end

always @(*) begin
    out_valid  = 0;
    out_data   = 0;
    input_ctr_n  = input_ctr;
    output_ctr_n = output_ctr;
    result_n     = result;
    coeffs_n     = coeffs;
    buffer0_n    = buffer0;
    buffer1_n    = buffer1;
    buffer2_n    = buffer2;
    buffer3_n    = buffer3;
    buffer4_n    = buffer4;
    buffer5_n    = buffer5;
    buffer6_n    = buffer6;
    data_ctr_n   = data_ctr;
    stage_reg_n  = stage_reg;
    input_buffer_n = input_buffer;
    for(i = 0; i < 7;i = i + 1) begin
        bf_gmb[i]  = 0;
        bf_in_u[i] = 0;
        bf_in_v[i] = 0;
    end

    if(cs == IDLE) begin
        for(i = 0; i < INPUT_COUNT; i = i + 1) begin
                input_buffer_n[i] = 0;
            end
            for(i = 0; i < OUTPUT_COUNT; i = i + 1) begin
                result_n[i]       = 0;
                coeffs_n[i]       = 0;
            end
            for(i = 0; i < 64; i = i + 1) begin
                buffer0_n[i]      = 0;
            end
            for(i = 0; i < 32; i = i + 1) begin
                buffer1_n[i]      = 0;
            end
            for(i = 0; i < 16; i = i + 1) begin
                buffer2_n[i]      = 0;
            end
            for(i = 0; i <  8; i = i + 1) begin
                buffer3_n[i]      = 0;
            end
            for(i = 0; i <  4; i = i + 1) begin
                buffer4_n[i]      = 0;
            end
            for(i = 0; i <  2; i = i + 1) begin
                buffer5_n[i]      = 0;
            end
            buffer6_n             = 0;

            for(i = 0; i <  7; i = i + 1) begin
                stage_reg_n[i]    = 0;
            end            
      if(push_input) begin
        input_ctr_n = input_ctr + 1;
        for(i = 0; i < INPUT_COUNT - 1; i = i + 1) begin
            input_buffer_n[i] = input_buffer[i+1];
        end
        input_buffer_n[INPUT_COUNT - 1] = in_data; 
      end else begin
        input_buffer_n = input_buffer;
      end
    end

    if(cs == LOAD) begin
      for (i = 0; i < INPUT_COUNT; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            coeffs_n[(i*8) + j] = input_buffer[i][(j*4) +: 4];
        end
       end
       for(i = 0; i < 64; i = i + 1) begin
         buffer0_n[i] = coeffs_n[i];
       end
       data_ctr_n = 64;
    end

    if(cs == CALC) begin
        for(i = 0; i < OUTPUT_COUNT - 1; i = i + 1) begin
          coeffs_n[i] = coeffs[i+1];
        end
        coeffs_n[OUTPUT_COUNT - 1] = 0;
        for (i = 0; i < 63; i = i + 1) begin buffer0_n[i] = buffer0[i+1]; end
        for (i = 0; i < 31; i = i + 1) begin buffer1_n[i] = buffer1[i+1]; end
        for (i = 0; i < 15; i = i + 1) begin buffer2_n[i] = buffer2[i+1]; end
        for (i = 0; i < 7;  i = i + 1) begin buffer3_n[i] = buffer3[i+1]; end
        for (i = 0; i < 3;  i = i + 1) begin buffer4_n[i] = buffer4[i+1]; end
        buffer5_n[0] = buffer5[1];

        bf_in_u[0]      = buffer0[0];
        bf_in_u[1]      = buffer1[0];
        bf_in_u[2]      = buffer2[0];
        bf_in_u[3]      = buffer3[0];
        bf_in_u[4]      = buffer4[0];
        bf_in_u[5]      = buffer5[0]; 
        bf_in_u[6]      = buffer6;
     
        
        bf_in_v[0]      = coeffs[64];
        stage_reg_n[0] = data_ctr[6] ? bf_out_add[0] : buffer0[0];
        bf_in_v[1]      = stage_reg[0];
        stage_reg_n[1] = data_ctr_stage1[5] ? bf_out_add[1] : buffer1[0];
        bf_in_v[2]      = stage_reg[1];
        stage_reg_n[2] = data_ctr_stage2[4] ? bf_out_add[2] : buffer2[0];
        bf_in_v[3]      = stage_reg[2];
        stage_reg_n[3] = data_ctr_stage3[3] ? bf_out_add[3] : buffer3[0];
        bf_in_v[4]      = stage_reg[3];
        stage_reg_n[4] = data_ctr_stage4[2] ? bf_out_add[4] : buffer4[0];
        bf_in_v[5]      = stage_reg[4];
        stage_reg_n[5] = data_ctr_stage5[1] ? bf_out_add[5] : buffer5[0];
        bf_in_v[6]      = stage_reg[5];
        stage_reg_n[6] = data_ctr_stage6[0] ? bf_out_add[6] : buffer6;

        buffer0_n[63] = data_ctr[6] ? bf_out_sub[0] : coeffs[64];
        buffer1_n[31] = data_ctr_stage1[5] ? bf_out_sub[1] : stage_reg[0];
        buffer2_n[15] = data_ctr_stage2[4] ? bf_out_sub[2] : stage_reg[1];
        buffer3_n[7]  = data_ctr_stage3[3] ? bf_out_sub[3] : stage_reg[2];
        buffer4_n[3]  = data_ctr_stage4[2] ? bf_out_sub[4] : stage_reg[3];
        buffer5_n[1]  = data_ctr_stage5[1] ? bf_out_sub[5] : stage_reg[4];
        buffer6_n     = data_ctr_stage6[0] ? bf_out_sub[6] : stage_reg[5];


    
        bf_gmb[0]       = get_gmb({6'b0,                  1});
        bf_gmb[1]       = get_gmb({5'b0, 2  + stage1_start[6]});
        bf_gmb[2]       = get_gmb({4'b0, 4  + stage2_start[6:5]});
        bf_gmb[3]       = get_gmb({3'b0, 8  + stage3_start[6:4]});
        bf_gmb[4]       = get_gmb({2'b0, 16 + stage4_start[6:3]});
        bf_gmb[5]       = get_gmb({1'b0, 32 + stage5_start[6:2]});
        bf_gmb[6]       = get_gmb(64 + stage6_start[6:1]);
        data_ctr_n = data_ctr + 1;
        
        if(data_ctr > 133) begin
            result_n[127] = stage_reg[6];
            for(i = 0; i < OUTPUT_COUNT - 1; i = i + 1) begin
                result_n[i] = result[i+1];
            end
        end
    end

    if(cs == SEND) begin
        input_ctr_n = 0;
        if(!fifo_full) begin
            out_valid    = 1;
            out_data     = result[0];
            output_ctr_n = output_ctr + 1;
            for(i = 0; i < OUTPUT_COUNT - 1; i = i + 1) begin
                result_n[i] = result[i+1];
            end
            result_n[127] = 0;
        end else begin //stall
            out_valid     = 0;
            out_data      = result[0];
            output_ctr_n  = output_ctr;
        end
        if(output_ctr == OUTPUT_COUNT && !fifo_full) begin
            input_ctr_n           = 0;
            out_valid_n           = 0;
            out_data_n            = 0;
            output_ctr_n          = 0;
            data_ctr_n            = 0;
            for(i = 0; i < INPUT_COUNT; i = i + 1) begin
                input_buffer_n[i] = 0;
            end
            for(i = 0; i < OUTPUT_COUNT; i = i + 1) begin
                result_n[i]       = 0;
                coeffs_n[i]       = 0;
            end
            for(i = 0; i < 64; i = i + 1) begin
                buffer0_n[i]      = 0;
            end
            for(i = 0; i < 32; i = i + 1) begin
                buffer1_n[i]      = 0;
            end
            for(i = 0; i < 16; i = i + 1) begin
                buffer2_n[i]      = 0;
            end
            for(i = 0; i <  8; i = i + 1) begin
                buffer3_n[i]      = 0;
            end
            for(i = 0; i <  4; i = i + 1) begin
                buffer4_n[i]      = 0;
            end
            for(i = 0; i <  2; i = i + 1) begin
                buffer5_n[i]      = 0;
            end
            buffer6_n             = 0;

            for(i = 0; i <  7; i = i + 1) begin
                stage_reg_n[i]    = 0;
            end        
        end
    end


end
// Tie off unused flags
assign flag_clk2_to_handshake = 1'b0;
assign flag_clk2_to_fifo = 1'b0;

endmodule

module CLK_3_MODULE (
    clk,
    rst_n,
    fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_data,

    flag_fifo_to_clk3,
    flag_clk3_to_fifo
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             fifo_empty;
input      [15:0] fifo_rdata;
output reg        fifo_rinc;
output reg        out_valid;
output reg [15:0] out_data;

// You can change the input / output of the custom flag ports
input  flag_fifo_to_clk3;
output flag_clk3_to_fifo;

assign flag_clk3_to_fifo = 0;

parameter IDLE = 1'd0,
          SEND = 1'd1;

reg        out_valid_n, out_valid_nn;
reg [15:0] out_data_n;
reg        fifo_rinc_n;
reg [7:0] count;
reg [7:0] count_n;
reg cs, ns; 


always@(posedge clk or negedge rst_n) begin
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
            if(!flag_fifo_to_clk3) begin
                ns = SEND;
            end else begin
                ns = cs;
            end
        end

        SEND: begin
            if(count == 128) begin
                ns = IDLE;
            end else begin
                ns = cs;
            end
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      out_valid       <= 0;
      out_data        <= 0;
      fifo_rinc       <= 0;
      count           <= 0;
      out_valid_n     <= 0;
      out_valid_nn    <= 0;
    end else begin
      out_valid       <= count == 128 ? 0 : out_valid_n;
      out_valid_n     <= count == 128 ? 0 : out_valid_nn;
      out_valid_nn    <= count == 128 ? 0 : fifo_rinc;
      out_data        <= out_data_n;
      fifo_rinc       <= fifo_rinc_n;
      count           <= count_n;
    end
end

always @(*) begin
    count_n     = count;
    fifo_rinc_n = 0;
    if(cs == IDLE) begin
        //out_valid_nn = 0;
        out_data_n  = 0;
        fifo_rinc_n = 0;
        count_n     = 0;
    end

    if(cs == SEND) begin
        if(out_valid_n) begin
            //out_valid_n = 1;
            out_data_n  = out_valid_n ? fifo_rdata : 0;
            fifo_rinc_n = 1;
            count_n     = count + 1;
        end else begin
            //out_valid_n = 0;
            out_data_n  = 0;
            fifo_rinc_n = 0;
            count_n     = count;
        end
        if(!flag_fifo_to_clk3) begin
            fifo_rinc_n = 1;
        end else begin
            fifo_rinc_n = 0;
        end
        if(count == 128) begin
            out_data_n = 0;
        end
    end
end

endmodule


module NTT_Butterfly_Unit #(
    parameter DATA_WIDTH = 14,
    parameter Q          = 12289,
    parameter QOI        = 12287,
    parameter R_SHIFT    = 16
) (
    input      [DATA_WIDTH-1:0]   in_u, 
    input      [DATA_WIDTH-1:0]   in_v, 
    input      [DATA_WIDTH-1:0]   gmb, 
    
    output reg [DATA_WIDTH-1:0]   out_uv_add, 
    output reg [DATA_WIDTH-1:0]   out_uv_sub
);
    wire [27:0] modq_x;
    assign modq_x = in_v * gmb;
    wire [15:0] modq_y;
    //assign modq_y = modq_x * QOI;
    assign modq_y = (modq_x << 14) - modq_x - (modq_x << 12);
    wire [14:0] modq_z_unnorm;
    wire [30:0] modq_y_mult;
    assign modq_y_mult =  (modq_y << 14) + modq_y - (modq_y << 12);
    assign modq_z_unnorm = (modq_x + (modq_y_mult)) >> R_SHIFT;
    wire [DATA_WIDTH-1:0] v_result;
    assign v_result = (modq_z_unnorm >= Q) ? (modq_z_unnorm - Q) : modq_z_unnorm;

    
    always @(*) begin
        if (in_u + v_result >= Q)
            out_uv_add = in_u + v_result - Q;
        else
            out_uv_add = in_u + v_result;
        if (in_u >= v_result)
            out_uv_sub = in_u - v_result;
        else
            out_uv_sub = in_u - v_result + Q;
    end

endmodule



