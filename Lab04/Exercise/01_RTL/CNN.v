//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2025 Fall
//   Lab04 Exercise		: Convolution Neural Network 
//   Author     		: Chung-Shuo Lee
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V 1.0
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CNN(
    // Input Port
    clk,
    rst_n,
    in_valid,
    Image,
    Kernel_ch1,
    Kernel_ch2,
	Weight_Bias,
    task_number,
    mode,
    capacity_cost,
    // Output Port
    out_valid,
    out
    );

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point parameter (You can't modify these parameters)
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

input           clk, rst_n, in_valid;
input   [31:0]  Image;
input   [31:0]  Kernel_ch1;
input   [31:0]  Kernel_ch2;
input   [31:0]  Weight_Bias;
input           task_number;
input   [1:0]   mode;
input   [3:0]   capacity_cost;
output  reg         out_valid;
output  reg [31:0]  out;



// PARAMETER & INTERGER
parameter   IDLE    = 2'd0,
            TASK0   = 2'd1,
            TASK1   = 2'd2;

parameter NUM_ADD   = 19,
          NUM_MULT  = 18;

parameter CONV_START = 8, ACT_START = 86, LINEAR_START = 96, LINEAR_START_2 = 102, SOFT_MAX_START = 105;
parameter [31:0] FP32_ONE     = 32'b00111111100000000000000000000000;
parameter [31:0] FP32_NEG_ONE = 32'b10111111100000000000000000000000;
parameter [31:0] LEAKY_ALPHA  = 32'b00111100001000111101011100001010;
parameter [31:0] ZERO         = 32'b00000000000000000000000000000000;
integer i, j, k;
integer r0, r1, r2, c0, c1, c2;

// REG & WIRE
reg [1:0]  cs, ns;
reg        out_valid_n;
reg [31:0] out_n;

reg [31:0] Image_Map       [0:5][0:5];
reg [31:0] Image_Map_n     [0:5][0:5];
reg [31:0] CONV_result     [0:1][0:5][0:5];
reg [31:0] CONV_result_n   [0:1][0:5][0:5];
reg [31:0] Kernel_A        [0:8];
reg [31:0] Kernel_A_n      [0:8];
reg [31:0] Kernel_B        [0:8];
reg [31:0] Kernel_B_n      [0:8];
reg [31:0] Kernel_C        [0:8];
reg [31:0] Kernel_C_n      [0:8];
reg [31:0] Kernel_D        [0:8];
reg [31:0] Kernel_D_n      [0:8];
reg [6:0]  input_idx, input_idx_n;  
reg [2:0]  row_idx, row_idx_n, col_idx, col_idx_n;
reg [2:0]  conv_row, conv_col, conv_row_n, conv_col_n;
reg [2:0]  conv_row2, conv_col2, conv_row2_n, conv_col2_n;
reg [31:0] Pooling_MAP   [0:1][0:1][0:1];
reg [31:0] Pooling_MAP_n [0:1][0:1][0:1];
reg [31:0] mult_a        [0:NUM_MULT - 1];
reg [31:0] mult_b        [0:NUM_MULT - 1];
reg [31:0] mult_out      [0:NUM_MULT - 1]; 
reg [7:0]  status_inst;
reg [1:0]  mode_n, mode_reg;
wire[2:0]  rnd_all = 3'b000;
reg [31:0] multi_result   [0:17];
reg [31:0] multi_result_n [0:17];

reg [31:0] add_a        [0:NUM_ADD - 1];
reg [31:0] add_b        [0:NUM_ADD - 1];
reg [31:0] add_out      [0:NUM_ADD - 1];
reg        add_op       [0:NUM_ADD - 1];
reg [31:0] stage2_reg    [0:9];
reg [31:0] stage2_reg_n  [0:9];

reg [31:0] stage3_reg    [0:5];
reg [31:0] stage3_reg_n  [0:5];

reg [31:0] stage4_reg    [0:3];
reg [31:0] stage4_reg_n  [0:3];

reg [31:0] exp_in, exp_out;
reg [31:0] div_a, div_b, div_out;

reg [31:0] denominator   [0:3];
reg [31:0] denominator_n [0:3];
reg [31:0] numerator     [0:3];
reg [31:0] numerator_n   [0:3];

reg [31:0] W1   [0:4][0:7];
reg [31:0] B1;
reg [31:0] W2   [0:2][0:4];
reg [31:0] B2;

reg [31:0] W1_n [0:4][0:7];
reg [31:0] B1_n;
reg [31:0] W2_n [0:2][0:4];
reg [31:0] B2_n;

reg [31:0] Linear_Map1   [0:7];
reg [31:0] Linear_Map1_n [0:7];
reg [31:0] Linear_Map2   [0:7];
reg [31:0] Linear_Map2_n [0:7];

reg [31:0] leaky_relu_out[0:2];

reg [3:0]  combination, combination_n;
reg [5:0]  cap_cost      [0:4];
reg [5:0]  cap_cost_n    [0:4];

reg [31:0] cmp_a;
reg [31:0] cmp_b;
wire agtb, aeqb;
reg no_candidate, no_candidat_n;
reg can_pre_count, can_pre_count_n;
// DESIGNWARE
genvar gi;
generate
  for (gi = 0; gi < NUM_MULT; gi = gi + 1) begin : G_MULT
    DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance) u_mult ( .a(mult_a[gi]), .b(mult_b[gi]), .rnd(rnd_all), .z(mult_out[gi]), .status() );
  end

  for (gi = 0; gi < NUM_ADD; gi = gi + 1) begin : G_ADD
    DW_fp_addsub #(inst_sig_width, inst_exp_width, inst_ieee_compliance) u_add ( .a(add_a[gi]), .b(add_b[gi]), .rnd(rnd_all), .z(add_out[gi]), .op(add_op[gi]), .status() );
  end
endgenerate

DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) u_exp (.a(exp_in),.z(exp_out),.status());
DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_faithful_round) u_div( .a(div_a), .b(div_b), .rnd(rnd_all), .z(div_out), .status());
DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance) u_cmp(.a(cmp_a), .b(cmp_b), .zctr(1'b1), .aeqb(aeqb), .altb(), .agtb(agtb), .unordered(), .z0(), .z1(), .status0(), .status1());

genvar ch, Pr, Pc;
reg [31:0] Pooling_out  [0:1][0:1][0:1];
generate
  for (ch=0; ch<2; ch=ch+1) begin: GCH
    for (Pr=0; Pr<2; Pr=Pr+1) begin: GR
      for (Pc=0; Pc<2; Pc=Pc+1) begin: GC
        wire [2:0] gr0 = Pr*3;
        wire [2:0] gc0 = Pc*3;

        wire [31:0] w00 = CONV_result[ch][gr0+0][gc0+0];
        wire [31:0] w01 = CONV_result[ch][gr0+0][gc0+1];
        wire [31:0] w02 = CONV_result[ch][gr0+0][gc0+2];
        wire [31:0] w10 = CONV_result[ch][gr0+1][gc0+0];
        wire [31:0] w11 = CONV_result[ch][gr0+1][gc0+1];
        wire [31:0] w12 = CONV_result[ch][gr0+1][gc0+2];
        wire [31:0] w20 = CONV_result[ch][gr0+2][gc0+0];
        wire [31:0] w21 = CONV_result[ch][gr0+2][gc0+1];
        wire [31:0] w22 = CONV_result[ch][gr0+2][gc0+2];

        wire [31:0] m0, m1, m2, m3, m4, m5, m6, m7;

        FP_MAX2 #(inst_sig_width,inst_exp_width,inst_ieee_compliance) M0 (.a(w00), .b(w01), .z(m0));
        FP_MAX2 #(inst_sig_width,inst_exp_width,inst_ieee_compliance) M1 (.a(w02), .b(w10), .z(m1));
        FP_MAX2 #(inst_sig_width,inst_exp_width,inst_ieee_compliance) M2 (.a(w11), .b(w12), .z(m2));
        FP_MAX2 #(inst_sig_width,inst_exp_width,inst_ieee_compliance) M3 (.a(w20), .b(w21), .z(m3));

        FP_MAX2 #(inst_sig_width,inst_exp_width,inst_ieee_compliance) M4 (.a(m0), .b(m1), .z(m4));
        FP_MAX2 #(inst_sig_width,inst_exp_width,inst_ieee_compliance) M5 (.a(m2), .b(m3), .z(m5));
        FP_MAX2 #(inst_sig_width,inst_exp_width,inst_ieee_compliance) M6 (.a(m4), .b(m5), .z(m6));
        FP_MAX2 #(inst_sig_width,inst_exp_width,inst_ieee_compliance) M7 (.a(m6), .b(w22), .z(m7)); // 9th

        always @(*) begin
          Pooling_out[ch][Pr][Pc] = m7;
        end
      end
    end
  end
endgenerate

// =================== FSM ======================
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
                if(task_number == 0) begin
                    ns = TASK0;
                end else begin
                    ns = TASK1;
                end
            end
        end 

        TASK0: begin
            if(input_idx == 111) begin
                ns = IDLE;    
            end else begin
                ns = cs;
            end
        end

        TASK1: begin
            if(input_idx == 96 || (input_idx == 36 && no_candidate) || (input_idx == 51 && can_pre_count)) begin
                ns = IDLE;
            end else begin
                ns = cs;
            end
        end
        default: ns = IDLE; 
    endcase
end

// ===============================================


// =============== Sequential ====================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        
        for(i = 0; i < 6; i = i + 1) begin
           for(j = 0; j < 6; j = j + 1) begin
             Image_Map[i][j]      <= 0;
             CONV_result[0][i][j] <= 0;
             CONV_result[1][i][j] <= 0;
           end
        end

        for(i = 0; i < 9; i = i + 1) begin
           Kernel_A[i]  <= 0;
           Kernel_B[i]  <= 0;
           Kernel_C[i]  <= 0;
           Kernel_D[i]  <= 0;
        end

        for(i = 0; i < NUM_MULT; i = i + 1) begin
           multi_result[i] <= 0;
        end
        

        for(i = 0; i < 10; i = i + 1) begin
           stage2_reg[i]   <= 0;
        end

        for(i = 0; i < 6; i = i + 1) begin
           stage3_reg[i]   <= 0;
        end

        for(i = 0; i < 4; i = i + 1) begin
           stage4_reg[i]   <= 0;
        end

        for(i = 0; i < 5; i = i + 1) begin
          for(j = 0; j < 8; j = j + 1) begin
                W1[i][j]   <= 0;
          end
        end

        for(i = 0; i < 3; i = i + 1) begin
          for(j = 0; j < 5; j = j + 1) begin
                W2[i][j]   <= 0;
          end
        end

        B1                  <= 0;
        B2                  <= 0;
        input_idx           <= 0;
        row_idx             <= 0;
        col_idx             <= 0;
        mode_reg            <= 0;
        combination         <= 0;
        conv_col            <= 0;
        conv_row            <= 0;
        conv_col2           <= 0;
        conv_row2           <= 0;
        for(i = 0; i < 5; i = i + 1) begin
            cap_cost[i]     <= 0;
        end
        for(i = 0; i < 4; i = i + 1) begin
            denominator[i]  <= 0;
            numerator[i]    <= 0;
        end
        for(i = 0; i < 2; i = i + 1) begin
          for(j = 0; j < 2; j = j + 1) begin
            Pooling_MAP[0][i][j] <= 0;
            Pooling_MAP[1][i][j] <= 0;
          end
        end

        for(i = 0; i < 8; i = i + 1) begin
            Linear_Map1[i]  <= 0;
            Linear_Map2[i]  <= 0;
        end
        
        out_valid           <= 0;
        out                 <= 0;
    end else begin
        Image_Map        <= Image_Map_n;
        Kernel_A         <= Kernel_A_n;
        Kernel_B         <= Kernel_B_n;
        Kernel_C         <= Kernel_C_n;
        Kernel_D         <= Kernel_D_n;
        input_idx        <= input_idx_n;
        row_idx          <= row_idx_n;
        col_idx          <= col_idx_n;
        conv_row         <= conv_row_n;
        conv_col2        <= conv_col2_n;
        conv_row2        <= conv_row2_n;
        conv_col         <= conv_col_n;
        CONV_result      <= CONV_result_n;
        mode_reg         <= mode_n;
        multi_result     <= multi_result_n;
        stage2_reg       <= stage2_reg_n;
        stage3_reg       <= stage3_reg_n;
        stage4_reg       <= stage4_reg_n;
        out_valid        <= out_valid_n;
        out              <= out_n;
        Pooling_MAP      <= Pooling_MAP_n;
        denominator      <= denominator_n;
        numerator        <= numerator_n;
        W1               <= W1_n;
        W2               <= W2_n;
        B1               <= B1_n;
        B2               <= B2_n;
        Linear_Map1      <= Linear_Map1_n;
        Linear_Map2      <= Linear_Map2_n;
        combination      <= combination_n;
        cap_cost         <= cap_cost_n;
        no_candidate     <= no_candidat_n;
        can_pre_count    <= can_pre_count_n;
    end
end
// ===============================================

// ============== Combinational ==================
always @(*) begin
    Image_Map_n     = Image_Map;
    Kernel_A_n      = Kernel_A;
    Kernel_B_n      = Kernel_B;
    Kernel_C_n      = Kernel_C;
    Kernel_D_n      = Kernel_D;
    input_idx_n     = input_idx;
    row_idx_n       = row_idx;
    col_idx_n       = col_idx;
    conv_row_n      = conv_row;
    conv_col_n      = conv_col;
    conv_row2_n     = conv_row2;
    conv_col2_n     = conv_col2;
    CONV_result_n   = CONV_result;
    mode_n          = mode_reg;
    multi_result_n  = multi_result;
    stage2_reg_n    = stage2_reg;
    stage3_reg_n    = stage3_reg;
    stage4_reg_n    = stage4_reg;
    Pooling_MAP_n   = Pooling_MAP;
    out_n           = 0;
    out_valid_n     = 0;
    denominator_n   = denominator;
    numerator_n     = numerator;
    W1_n            = W1;
    W2_n            = W2;
    B1_n            = B1;
    B2_n            = B2;
    Linear_Map1_n   = Linear_Map1;
    Linear_Map2_n   = Linear_Map2;
    exp_in          = 0;
    div_a           = 0;
    div_b           = 0;
    combination_n   = combination;
    cap_cost_n      = cap_cost;
    cmp_a           = 0;
    cmp_b           = 0;
    no_candidat_n   = no_candidate;
    can_pre_count_n = can_pre_count;

    for(i = 0; i < 3; i = i + 1) begin
        leaky_relu_out[i] = 0;
    end
    for (i = 0; i < NUM_MULT; i = i + 1) begin
        mult_a[i]  = 0;
        mult_b[i]  = 0;
    end
    for (i = 0; i < NUM_ADD; i = i + 1) begin
        add_a[i]   = 0;
        add_b[i]   = 0;
        add_op[i]  = 0;
    end
    
    if(cs == IDLE) begin
        for(i = 0; i < 6; i = i + 1) begin
            for(j = 0; j < 6; j = j + 1) begin
              Image_Map_n[i][j]      = 0;
              CONV_result_n[0][i][j] = 0;
              CONV_result_n[1][i][j] = 0;
            end
        end
        for(i = 0; i < 9; i = i + 1) begin
            Kernel_A_n[i]  = 0;
            Kernel_B_n[i]  = 0;
            Kernel_C_n[i]  = 0;
            Kernel_D_n[i]  = 0;
        end
        for(i = 0; i < 10; i = i + 1) begin
           stage2_reg_n[i] = 0;
        end

        for(i = 0; i < 6; i = i + 1) begin
           stage3_reg_n[i] = 0;
        end

        for(i = 0; i < 4; i = i + 1) begin
           stage4_reg_n[i] = 0;
        end
        for(i = 0; i < 2; i = i + 1) begin
          for(j = 0; j < 2; j = j + 1) begin
            Pooling_MAP_n[0][i][j] = 0;
            Pooling_MAP_n[1][i][j] = 0;
          end
        end

        for(i = 0; i < 8; i = i + 1) begin
            Linear_Map1_n[i]  = 0;
            Linear_Map2_n[i]  = 0;
        end
        input_idx_n = 0;
        mode_n      = 0;
        out_valid_n = 0;
        out_n       = 0;
        if(in_valid) begin
            Image_Map_n[0][0] = Image;
            Kernel_A_n [8]    = Kernel_ch1;
            Kernel_B_n [8]    = Kernel_ch2;
            input_idx_n     = 1;
            row_idx_n       = 0;
            col_idx_n       = 1;
            conv_row_n      = 0;
            conv_col_n      = 0;
            conv_row2_n     = 0;
            conv_col2_n     = 0;
            mode_n          = mode;
            B2_n            = Weight_Bias;
            combination_n   = 0;
            cap_cost_n[4]   = capacity_cost;
            no_candidat_n   = 1;
            can_pre_count_n = 0;
        end
    end

    if(cs == TASK0 || cs == TASK1) begin
        input_idx_n  = input_idx + 1;
        col_idx_n    = col_idx == 5 ? 0 : col_idx + 1;
        row_idx_n    = col_idx == 5 ? row_idx + 1 : row_idx;
        if (row_idx == 5 && col_idx == 5) begin
            row_idx_n = 0;
            col_idx_n = 0;
        end

        
        
        if (input_idx == 43) begin
            conv_row_n = 0;
            conv_col_n = 0;
        end
        
        if(input_idx < 9) begin
            Kernel_A_n[8] = Kernel_ch1;
            Kernel_B_n[8] = Kernel_ch2;
            for(i = 0; i < 8; i = i + 1) begin
                Kernel_A_n[i] = Kernel_A[i + 1];
                Kernel_B_n[i] = Kernel_B[i + 1];
            end
        end else if(input_idx < 18) begin
            Kernel_C_n[8] = Kernel_ch1;
            Kernel_D_n[8] = Kernel_ch2;
            for(i = 0; i < 8; i = i + 1) begin
                Kernel_C_n[i] = Kernel_C[i + 1];
                Kernel_D_n[i] = Kernel_D[i + 1];
            end
        end

        // 1st convolution
        if(input_idx > CONV_START && input_idx < CONV_START + 37) begin //after 8 cycles of input, the kernel is done.
            conv_col_n = conv_col == 5 ? 0 : conv_col + 1;
            conv_row_n = conv_col == 5 ? conv_row == 5 ? 0: conv_row + 1 : conv_row;
            mult_a[ 0] = Kernel_A[ 0];
            mult_a[ 1] = Kernel_A[ 1];
            mult_a[ 2] = Kernel_A[ 2];
            mult_a[ 3] = Kernel_A[ 3];
            mult_a[ 4] = Kernel_A[ 4];
            mult_a[ 5] = Kernel_A[ 5];
            mult_a[ 6] = Kernel_A[ 6];
            mult_a[ 7] = Kernel_A[ 7];
            mult_a[ 8] = Kernel_A[ 8];
            mult_a[ 9] = Kernel_B[ 0];
            mult_a[10] = Kernel_B[ 1];
            mult_a[11] = Kernel_B[ 2];
            mult_a[12] = Kernel_B[ 3];
            mult_a[13] = Kernel_B[ 4];
            mult_a[14] = Kernel_B[ 5];
            mult_a[15] = Kernel_B[ 6];
            mult_a[16] = Kernel_B[ 7];
            mult_a[17] = Kernel_B[ 8];
            
            // 0, 1, 2
            // 3, 4, 5
            // 6, 7, 8
            r1 = conv_row;  c1 = conv_col;

            if (mode_reg[1] == 1'b0) begin
                // replicate
                r0 = (conv_row == 0) ? 0 : (conv_row - 1);
                r2 = (conv_row == 5) ? 5 : (conv_row + 1);
                c0 = (conv_col == 0) ? 0 : (conv_col - 1);
                c2 = (conv_col == 5) ? 5 : (conv_col + 1);
            end else begin
                // reflect
                r0 = (conv_row == 0) ? 1 : (conv_row - 1);
                r2 = (conv_row == 5) ? 4 : (conv_row + 1);
                c0 = (conv_col == 0) ? 1 : (conv_col - 1);
                c2 = (conv_col == 5) ? 4 : (conv_col + 1);
            end

            // ====== Pipeline Stage1 =======

            mult_b[0]          = Image_Map[r0][c0];
            mult_b[1]          = Image_Map[r0][c1];
            mult_b[2]          = Image_Map[r0][c2];
            mult_b[3]          = Image_Map[r1][c0];
            mult_b[4]          = Image_Map[r1][c1];
            mult_b[5]          = Image_Map[r1][c2];
            mult_b[6]          = Image_Map[r2][c0];
            mult_b[7]          = Image_Map[r2][c1];
            mult_b[8]          = Image_Map[r2][c2];

            mult_b[ 9]         = mult_b[0];
            mult_b[10]         = mult_b[1];
            mult_b[11]         = mult_b[2];
            mult_b[12]         = mult_b[3];
            mult_b[13]         = mult_b[4];
            mult_b[14]         = mult_b[5];
            mult_b[15]         = mult_b[6];
            mult_b[16]         = mult_b[7];
            mult_b[17]         = mult_b[8];
            
            multi_result_n[ 0] = mult_out[ 0];
            multi_result_n[ 1] = mult_out[ 1]; 
            multi_result_n[ 2] = mult_out[ 2]; 
            multi_result_n[ 3] = mult_out[ 3]; 
            multi_result_n[ 4] = mult_out[ 4]; 
            multi_result_n[ 5] = mult_out[ 5]; 
            multi_result_n[ 6] = mult_out[ 6]; 
            multi_result_n[ 7] = mult_out[ 7]; 
            multi_result_n[ 8] = mult_out[ 8]; 
            multi_result_n[ 9] = mult_out[ 9]; 
            multi_result_n[10] = mult_out[10]; 
            multi_result_n[11] = mult_out[11]; 
            multi_result_n[12] = mult_out[12]; 
            multi_result_n[13] = mult_out[13]; 
            multi_result_n[14] = mult_out[14]; 
            multi_result_n[15] = mult_out[15]; 
            multi_result_n[16] = mult_out[16];
            multi_result_n[17] = mult_out[17];
            // ==============================

            // ====== Pipeline Stage2 =======
            add_a[ 0]          = multi_result[ 0];
            add_b[ 0]          = multi_result[ 1];
            add_a[ 1]          = multi_result[ 2];
            add_b[ 1]          = multi_result[ 3];
            add_a[ 2]          = multi_result[ 4];
            add_b[ 2]          = multi_result[ 5];
            add_a[ 3]          = multi_result[ 6];
            add_b[ 3]          = multi_result[ 7];

            
            add_a[ 4]          = multi_result[ 9];
            add_b[ 4]          = multi_result[10];
            add_a[ 5]          = multi_result[11];
            add_b[ 5]          = multi_result[12];
            add_a[ 6]          = multi_result[13];
            add_b[ 6]          = multi_result[14];
            add_a[ 7]          = multi_result[15];
            add_b[ 7]          = multi_result[16];


            stage2_reg_n[0]    = add_out[0];
            stage2_reg_n[1]    = add_out[1];
            stage2_reg_n[2]    = add_out[2];
            stage2_reg_n[3]    = add_out[3];

            stage2_reg_n[4]    = add_out[4];
            stage2_reg_n[5]    = add_out[5];
            stage2_reg_n[6]    = add_out[6];
            stage2_reg_n[7]    = add_out[7];

            stage2_reg_n[8]    = multi_result[ 8];
            stage2_reg_n[9]    = multi_result[17];
            
            // ==============================

            // ====== Pipeline Stage3 =======
            add_a[ 8]          = stage2_reg[0];
            add_b[ 8]          = stage2_reg[1];
            add_a[ 9]          = stage2_reg[2];
            add_b[ 9]          = stage2_reg[3];

            add_a[10]          = stage2_reg[4];
            add_b[10]          = stage2_reg[5];
            add_a[11]          = stage2_reg[6];
            add_b[11]          = stage2_reg[7];
            
            stage3_reg_n[0]    = add_out[ 8];
            stage3_reg_n[1]    = add_out[ 9];
            stage3_reg_n[2]    = add_out[10];
            stage3_reg_n[3]    = add_out[11];

            stage3_reg_n[4]    = stage2_reg[ 8];
            stage3_reg_n[5]    = stage2_reg[ 9];
    
            // ==============================

            // ====== Pipeline Stage4 =======
            add_a[12]          = stage3_reg[0];
            add_b[12]          = stage3_reg[1];
            add_a[13]          = stage3_reg[2];
            add_b[13]          = stage3_reg[3];

            stage4_reg_n[0]    = add_out[12];
            stage4_reg_n[1]    = add_out[13];
            stage4_reg_n[2]    = stage3_reg[4];
            stage4_reg_n[3]    = stage3_reg[5];
            // ==============================

            // ====== Pipeline Stage5 =======
            add_a[14]          = stage4_reg[0];
            add_b[14]          = stage4_reg[2];
            add_a[15]          = stage4_reg[1];
            add_b[15]          = stage4_reg[3];
            // ==============================

        end
        
        
    end

    if(cs == TASK0) begin
        
        if(input_idx < 72) Image_Map_n[row_idx][col_idx] = Image;

        //weight
        if (input_idx < 57) begin

            B2_n = Weight_Bias;
            for (j = 0; j < 4; j = j + 1)  W2_n[2][j] = W2[2][j+1];
            W2_n[2][4] = B2;                // last of W2 takes previous B2
            for (j = 0; j < 4; j = j + 1)  W2_n[1][j] = W2[1][j+1];
            W2_n[1][4] = W2[2][0];
            for (j = 0; j < 4; j = j + 1)  W2_n[0][j] = W2[0][j+1];
            W2_n[0][4] = W2[1][0];
            B1_n = W2[0][0];
            for (j = 0; j < 7; j = j + 1)  W1_n[4][j] = W1[4][j+1];
            W1_n[4][7] = B1;
            for (j = 0; j < 7; j = j + 1)  W1_n[3][j] = W1[3][j+1];
            W1_n[3][7] = W1[4][0];
            for (j = 0; j < 7; j = j + 1)  W1_n[2][j] = W1[2][j+1];
            W1_n[2][7] = W1[3][0];
            for (j = 0; j < 7; j = j + 1)  W1_n[1][j] = W1[1][j+1];
            W1_n[1][7] = W1[2][0];
            for (j = 0; j < 7; j = j + 1)  W1_n[0][j] = W1[0][j+1];
            W1_n[0][7] = W1[1][0];
        end

        // to store the 1st conv result
        if(input_idx > CONV_START + 4 && input_idx < CONV_START + 41) begin
          for(i = 0; i < 6; i = i + 1) begin
            for(j = 0; j < 5; j = j + 1) begin
                CONV_result_n[0][i][j] = CONV_result[0][i][j+1];
                CONV_result_n[1][i][j] = CONV_result[1][i][j+1];
            end
          end
          for(i = 0; i < 5; i = i + 1) begin
            CONV_result_n[0][i][5] = CONV_result[0][i + 1][0];
            CONV_result_n[1][i][5] = CONV_result[1][i + 1][0];   
          end

          CONV_result_n[0][5][5] = add_out[14];
          CONV_result_n[1][5][5] = add_out[15];
        end

        
        // image 1 convolution
        if (input_idx > 44 && input_idx < 85) begin
            // === S1: feed multipliers ===
            conv_col_n = (conv_col == 5) ? 0 : (conv_col + 1);
            conv_row_n = (conv_col == 5) ? (conv_row + 1) :  conv_row;

            mult_a[ 0] = Kernel_C[ 0];
            mult_a[ 1] = Kernel_C[ 1];
            mult_a[ 2] = Kernel_C[ 2];
            mult_a[ 3] = Kernel_C[ 3];
            mult_a[ 4] = Kernel_C[ 4];
            mult_a[ 5] = Kernel_C[ 5];
            mult_a[ 6] = Kernel_C[ 6];
            mult_a[ 7] = Kernel_C[ 7];
            mult_a[ 8] = Kernel_C[ 8];
            mult_a[ 9] = Kernel_D[ 0];
            mult_a[10] = Kernel_D[ 1];
            mult_a[11] = Kernel_D[ 2];
            mult_a[12] = Kernel_D[ 3];
            mult_a[13] = Kernel_D[ 4];
            mult_a[14] = Kernel_D[ 5];
            mult_a[15] = Kernel_D[ 6];
            mult_a[16] = Kernel_D[ 7];
            mult_a[17] = Kernel_D[ 8];

            r1 = conv_row;  c1 = conv_col;
            if (mode_reg[1] == 1'b0) begin
                // replicate
                r0 = (conv_row == 0) ? 0 : (conv_row - 1);
                r2 = (conv_row == 5) ? 5 : (conv_row + 1);
                c0 = (conv_col == 0) ? 0 : (conv_col - 1);
                c2 = (conv_col == 5) ? 5 : (conv_col + 1);
            end else begin
                // reflect
                r0 = (conv_row == 0) ? 1 : (conv_row - 1);
                r2 = (conv_row == 5) ? 4 : (conv_row + 1);
                c0 = (conv_col == 0) ? 1 : (conv_col - 1);
                c2 = (conv_col == 5) ? 4 : (conv_col + 1);
            end

            mult_b[0]  = Image_Map[r0][c0];
            mult_b[1]  = Image_Map[r0][c1];
            mult_b[2]  = Image_Map[r0][c2];
            mult_b[3]  = Image_Map[r1][c0];
            mult_b[4]  = Image_Map[r1][c1];
            mult_b[5]  = Image_Map[r1][c2];
            mult_b[6]  = Image_Map[r2][c0];
            mult_b[7]  = Image_Map[r2][c1];
            mult_b[8]  = Image_Map[r2][c2];

            mult_b[ 9] = mult_b[0];
            mult_b[10] = mult_b[1];
            mult_b[11] = mult_b[2];
            mult_b[12] = mult_b[3];
            mult_b[13] = mult_b[4];
            mult_b[14] = mult_b[5];
            mult_b[15] = mult_b[6];
            mult_b[16] = mult_b[7];
            mult_b[17] = mult_b[8];


            multi_result_n[ 0] = mult_out[ 0];
            multi_result_n[ 1] = mult_out[ 1];
            multi_result_n[ 2] = mult_out[ 2];
            multi_result_n[ 3] = mult_out[ 3];
            multi_result_n[ 4] = mult_out[ 4];
            multi_result_n[ 5] = mult_out[ 5];
            multi_result_n[ 6] = mult_out[ 6];
            multi_result_n[ 7] = mult_out[ 7];
            multi_result_n[ 8] = mult_out[ 8];
            multi_result_n[ 9] = mult_out[ 9];
            multi_result_n[10] = mult_out[10];
            multi_result_n[11] = mult_out[11];
            multi_result_n[12] = mult_out[12];
            multi_result_n[13] = mult_out[13];
            multi_result_n[14] = mult_out[14];
            multi_result_n[15] = mult_out[15];
            multi_result_n[16] = mult_out[16];
            multi_result_n[17] = mult_out[17];


            add_a[ 0] = multi_result[ 0];  add_b[ 0] = multi_result[ 1];
            add_a[ 1] = multi_result[ 2];  add_b[ 1] = multi_result[ 3];
            add_a[ 2] = multi_result[ 4];  add_b[ 2] = multi_result[ 5];
            add_a[ 3] = multi_result[ 6];  add_b[ 3] = multi_result[ 7];

            add_a[ 4] = multi_result[ 9];  add_b[ 4] = multi_result[10];
            add_a[ 5] = multi_result[11];  add_b[ 5] = multi_result[12];
            add_a[ 6] = multi_result[13];  add_b[ 6] = multi_result[14];
            add_a[ 7] = multi_result[15];  add_b[ 7] = multi_result[16];

            stage2_reg_n[0] = add_out[0];
            stage2_reg_n[1] = add_out[1];
            stage2_reg_n[2] = add_out[2];
            stage2_reg_n[3] = add_out[3];

            stage2_reg_n[4] = add_out[4];
            stage2_reg_n[5] = add_out[5];
            stage2_reg_n[6] = add_out[6];
            stage2_reg_n[7] = add_out[7];

            stage2_reg_n[8] = multi_result[ 8];
            stage2_reg_n[9] = multi_result[17];


            add_a[ 8]  = stage2_reg[0];  add_b[ 8]  = stage2_reg[1];
            add_a[ 9]  = stage2_reg[2];  add_b[ 9]  = stage2_reg[3];
            add_a[10]  = stage2_reg[4];  add_b[10]  = stage2_reg[5];
            add_a[11]  = stage2_reg[6];  add_b[11]  = stage2_reg[7];

            stage3_reg_n[0] = add_out[ 8];
            stage3_reg_n[1] = add_out[ 9];
            stage3_reg_n[2] = add_out[10];
            stage3_reg_n[3] = add_out[11];

            stage3_reg_n[4] = stage2_reg[ 8];
            stage3_reg_n[5] = stage2_reg[ 9];


            add_a[12]  = stage3_reg[0];  add_b[12] = stage3_reg[1];
            add_a[13]  = stage3_reg[2];  add_b[13] = stage3_reg[3];

            stage4_reg_n[0] = add_out[12];
            stage4_reg_n[1] = add_out[13];
            stage4_reg_n[2] = stage3_reg[4];
            stage4_reg_n[3] = stage3_reg[5];


            add_a[14]  = stage4_reg[0];  add_b[14] = stage4_reg[2];
            add_a[15]  = stage4_reg[1];  add_b[15] = stage4_reg[3];
        end

        if(input_idx > 48 && input_idx < 85) begin
            add_a[16] = add_out[14];
            add_b[16] = CONV_result[0][0][0];
            add_a[17] = add_out[15];
            add_b[17] = CONV_result[1][0][0];
          for(i = 0; i < 6; i = i + 1) begin
            for(j = 0; j < 5; j = j + 1) begin
                CONV_result_n[0][i][j] = CONV_result[0][i][j+1];
                CONV_result_n[1][i][j] = CONV_result[1][i][j+1];
            end
          end
          for(i = 0; i < 5; i = i + 1) begin
            CONV_result_n[0][i][5] = CONV_result[0][i + 1][0];
            CONV_result_n[1][i][5] = CONV_result[1][i + 1][0];   
          end

          CONV_result_n[0][5][5] = add_out[16];
          CONV_result_n[1][5][5] = add_out[17];
        end
      
        // ====== Max Pooling =======
        if(input_idx == 85) begin
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    Pooling_MAP_n[0][i][j] = Pooling_out[0][i][j]; // channel 0
                    Pooling_MAP_n[1][i][j] = Pooling_out[1][i][j]; // channel 1
                end
            end
        end
        // ==========================

        // ====== MULT 2 if mode[0] = 1 ==========


        // ====== Activation Function =======
        if(input_idx == ACT_START) begin
            if(mode_reg[0] == 1) begin
                exp_in           = {~Pooling_MAP[0][0][0][31], Pooling_MAP[0][0][0][30:0]};
                numerator_n[0]   = Pooling_MAP[0][0][0];
                denominator_n[0] = exp_out;
            end else begin
                exp_in           = {Pooling_MAP[0][0][0][31], Pooling_MAP[0][0][0][30:23] + 8'd1, Pooling_MAP[0][0][0][22:0]};
                numerator_n[0]   = exp_out;
                denominator_n[0] = exp_out;
            end
        end

        if(input_idx == ACT_START + 1) begin
            if(mode_reg[0] == 1) begin
                exp_in           = {~Pooling_MAP[0][0][1][31], Pooling_MAP[0][0][1][30:0]};
                numerator_n[0]   = Pooling_MAP[0][0][1];
                denominator_n[0] = exp_out;

            end else begin
                exp_in           = {Pooling_MAP[0][0][1][31], Pooling_MAP[0][0][1][30:23] + 8'd1, Pooling_MAP[0][0][1][22:0]};
                numerator_n[0]   = exp_out;
                denominator_n[0] = exp_out;


            end
        end

        if(input_idx == ACT_START + 2) begin
            if(mode_reg[0] == 1) begin
                exp_in           = {~Pooling_MAP[0][1][0][31], Pooling_MAP[0][1][0][30:0]};
                numerator_n[0]   = Pooling_MAP[0][1][0];
                denominator_n[0] = exp_out;
                
            end else begin
                exp_in           = {Pooling_MAP[0][1][0][31], Pooling_MAP[0][1][0][30:23] + 8'd1, Pooling_MAP[0][1][0][22:0]};
                numerator_n[0]   = exp_out;
                denominator_n[0] = exp_out;
            end
        end

        if(input_idx == ACT_START + 3) begin
            if(mode_reg[0] == 1) begin
                exp_in           = {~Pooling_MAP[0][1][1][31], Pooling_MAP[0][1][1][30:0]};
                numerator_n[0]   = Pooling_MAP[0][1][1];
                denominator_n[0] = exp_out;
            end else begin
                exp_in           = {Pooling_MAP[0][1][1][31], Pooling_MAP[0][1][1][30:23] + 8'd1, Pooling_MAP[0][1][1][22:0]};
                numerator_n[0]   = exp_out;
                denominator_n[0] = exp_out;
            end
        end

        if(input_idx == ACT_START + 4) begin
            if(mode_reg[0] == 1) begin
                exp_in           = {~Pooling_MAP[1][0][0][31], Pooling_MAP[1][0][0][30:0]};
                numerator_n[0]   = Pooling_MAP[1][0][0];
                denominator_n[0] = exp_out;
            end else begin
                exp_in           = {Pooling_MAP[1][0][0][31], Pooling_MAP[1][0][0][30:23] + 8'd1, Pooling_MAP[1][0][0][22:0]};
                numerator_n[0]   = exp_out;
                denominator_n[0] = exp_out;
            end
        end

        if(input_idx == ACT_START + 5) begin
            if(mode_reg[0] == 1) begin
                exp_in           = {~Pooling_MAP[1][0][1][31], Pooling_MAP[1][0][1][30:0]};
                numerator_n[0]   = Pooling_MAP[1][0][1];
                denominator_n[0] = exp_out;
            end else begin
                exp_in           = {Pooling_MAP[1][0][1][31], Pooling_MAP[1][0][1][30:23] + 8'd1, Pooling_MAP[1][0][1][22:0]};
                numerator_n[0]   = exp_out;
                denominator_n[0] = exp_out;
            end
        end

        if(input_idx == ACT_START + 6) begin
            if(mode_reg[0] == 1) begin
                exp_in           = {~Pooling_MAP[1][1][0][31], Pooling_MAP[1][1][0][30:0]};
                numerator_n[0]   = Pooling_MAP[1][1][0];
                denominator_n[0] = exp_out;
            end else begin
                exp_in           = {Pooling_MAP[1][1][0][31], Pooling_MAP[1][1][0][30:23] + 8'd1, Pooling_MAP[1][1][0][22:0]};
                numerator_n[0]   = exp_out;
                denominator_n[0] = exp_out;
            end
        end

        if(input_idx == ACT_START + 7) begin
            if(mode_reg[0] == 1) begin
                exp_in           = {~Pooling_MAP[1][1][1][31], Pooling_MAP[1][1][1][30:0]};
                numerator_n[0]   = Pooling_MAP[1][1][1];
                denominator_n[0] = exp_out;
            end else begin
                exp_in           = {Pooling_MAP[1][1][1][31], Pooling_MAP[1][1][1][30:23] + 8'd1, Pooling_MAP[1][1][1][22:0]};
                numerator_n[0]   = exp_out;
                denominator_n[0] = exp_out;
            end
        end

        if(input_idx > ACT_START && input_idx < ACT_START + 10) begin
            if(mode_reg[0] == 1) begin
                // pipe stage 2
                numerator_n[1]   = numerator[0];
                add_a[1]         = denominator[0];
                add_b[1]         = FP32_ONE;
                denominator_n[1] = add_out[1];

                //pipe stage 3
                div_a            = numerator[1];
                div_b            = denominator[1];
            end else begin
                //pipe stage 2
                add_a[0]         = numerator[0];
                add_b[0]         = FP32_NEG_ONE;
                add_a[1]         = denominator[0];
                add_b[1]         = FP32_ONE;
                numerator_n[1]   = add_out[0];
                denominator_n[1] = add_out[1];
                //pipe stage 3
                div_a            = numerator[1];
                div_b            = denominator[1];
            end
        end

        // add 
        if(input_idx == ACT_START + 2) begin
            Pooling_MAP_n[0][0][0] = div_out;
        end
        if(input_idx == ACT_START + 3) begin
            Pooling_MAP_n[0][0][1] = div_out;
        end
        if(input_idx == ACT_START + 4) begin
            Pooling_MAP_n[0][1][0] = div_out;
        end
        if(input_idx == ACT_START + 5) begin
            Pooling_MAP_n[0][1][1] = div_out;
        end
        if(input_idx == ACT_START + 6) begin
            Pooling_MAP_n[1][0][0] = div_out;
        end
        if(input_idx == ACT_START + 7) begin
            Pooling_MAP_n[1][0][1] = div_out;
        end
        if(input_idx == ACT_START + 8) begin
            Pooling_MAP_n[1][1][0] = div_out;
        end
        if(input_idx == ACT_START + 9) begin
            Pooling_MAP_n[1][1][1] = div_out;
        end
        // ===================================

        // =========== Linear 1================
        if(input_idx == LINEAR_START) begin
            mult_a[ 0] = W1[0][0];
            mult_a[ 1] = W1[0][1];
            mult_a[ 2] = W1[0][2];
            mult_a[ 3] = W1[0][3];
            mult_a[ 4] = W1[0][4];
            mult_a[ 5] = W1[0][5];
            mult_a[ 6] = W1[0][6];
            mult_a[ 7] = W1[0][7];
            mult_a[ 8] = W1[1][0];
            mult_a[ 9] = W1[1][1];
            mult_a[10] = W1[1][2];
            mult_a[11] = W1[1][3];
            mult_a[12] = W1[1][4];
            mult_a[13] = W1[1][5];
            mult_a[14] = W1[1][6];
            mult_a[15] = W1[1][7];

            mult_b[ 0] = Pooling_MAP[0][0][0];
            mult_b[ 1] = Pooling_MAP[0][0][1];
            mult_b[ 2] = Pooling_MAP[0][1][0];
            mult_b[ 3] = Pooling_MAP[0][1][1];
            mult_b[ 4] = Pooling_MAP[1][0][0];
            mult_b[ 5] = Pooling_MAP[1][0][1];
            mult_b[ 6] = Pooling_MAP[1][1][0];
            mult_b[ 7] = Pooling_MAP[1][1][1];
            mult_b[ 8] = Pooling_MAP[0][0][0];
            mult_b[ 9] = Pooling_MAP[0][0][1];
            mult_b[10] = Pooling_MAP[0][1][0];
            mult_b[11] = Pooling_MAP[0][1][1];
            mult_b[12] = Pooling_MAP[1][0][0];
            mult_b[13] = Pooling_MAP[1][0][1];
            mult_b[14] = Pooling_MAP[1][1][0];
            mult_b[15] = Pooling_MAP[1][1][1];

            multi_result_n[ 0] = mult_out[ 0];
            multi_result_n[ 1] = mult_out[ 1]; 
            multi_result_n[ 2] = mult_out[ 2]; 
            multi_result_n[ 3] = mult_out[ 3]; 
            multi_result_n[ 4] = mult_out[ 4]; 
            multi_result_n[ 5] = mult_out[ 5]; 
            multi_result_n[ 6] = mult_out[ 6]; 
            multi_result_n[ 7] = mult_out[ 7]; 
            multi_result_n[ 8] = mult_out[ 8]; 
            multi_result_n[ 9] = mult_out[ 9]; 
            multi_result_n[10] = mult_out[10]; 
            multi_result_n[11] = mult_out[11]; 
            multi_result_n[12] = mult_out[12]; 
            multi_result_n[13] = mult_out[13]; 
            multi_result_n[14] = mult_out[14]; 
            multi_result_n[15] = mult_out[15]; 
        end

        if(input_idx == LINEAR_START + 1) begin
            mult_a[ 0] = W1[2][0];
            mult_a[ 1] = W1[2][1];
            mult_a[ 2] = W1[2][2];
            mult_a[ 3] = W1[2][3];
            mult_a[ 4] = W1[2][4];
            mult_a[ 5] = W1[2][5];
            mult_a[ 6] = W1[2][6];
            mult_a[ 7] = W1[2][7];
            mult_a[ 8] = W1[3][0];
            mult_a[ 9] = W1[3][1];
            mult_a[10] = W1[3][2];
            mult_a[11] = W1[3][3];
            mult_a[12] = W1[3][4];
            mult_a[13] = W1[3][5];
            mult_a[14] = W1[3][6];
            mult_a[15] = W1[3][7];

            mult_b[ 0] = Pooling_MAP[0][0][0];
            mult_b[ 1] = Pooling_MAP[0][0][1];
            mult_b[ 2] = Pooling_MAP[0][1][0];
            mult_b[ 3] = Pooling_MAP[0][1][1];
            mult_b[ 4] = Pooling_MAP[1][0][0];
            mult_b[ 5] = Pooling_MAP[1][0][1];
            mult_b[ 6] = Pooling_MAP[1][1][0];
            mult_b[ 7] = Pooling_MAP[1][1][1];
            mult_b[ 8] = Pooling_MAP[0][0][0];
            mult_b[ 9] = Pooling_MAP[0][0][1];
            mult_b[10] = Pooling_MAP[0][1][0];
            mult_b[11] = Pooling_MAP[0][1][1];
            mult_b[12] = Pooling_MAP[1][0][0];
            mult_b[13] = Pooling_MAP[1][0][1];
            mult_b[14] = Pooling_MAP[1][1][0];
            mult_b[15] = Pooling_MAP[1][1][1];

            multi_result_n[ 0] = mult_out[ 0];
            multi_result_n[ 1] = mult_out[ 1]; 
            multi_result_n[ 2] = mult_out[ 2]; 
            multi_result_n[ 3] = mult_out[ 3]; 
            multi_result_n[ 4] = mult_out[ 4]; 
            multi_result_n[ 5] = mult_out[ 5]; 
            multi_result_n[ 6] = mult_out[ 6]; 
            multi_result_n[ 7] = mult_out[ 7]; 
            multi_result_n[ 8] = mult_out[ 8]; 
            multi_result_n[ 9] = mult_out[ 9]; 
            multi_result_n[10] = mult_out[10]; 
            multi_result_n[11] = mult_out[11]; 
            multi_result_n[12] = mult_out[12]; 
            multi_result_n[13] = mult_out[13]; 
            multi_result_n[14] = mult_out[14]; 
            multi_result_n[15] = mult_out[15]; 
        end

        if(input_idx == LINEAR_START + 2) begin
            mult_a[ 0] = W1[4][0];
            mult_a[ 1] = W1[4][1];
            mult_a[ 2] = W1[4][2];
            mult_a[ 3] = W1[4][3];
            mult_a[ 4] = W1[4][4];
            mult_a[ 5] = W1[4][5];
            mult_a[ 6] = W1[4][6];
            mult_a[ 7] = W1[4][7];
            mult_a[ 8] = W1[3][0];
            mult_a[ 9] = 0;
            mult_a[10] = 0;
            mult_a[11] = 0;
            mult_a[12] = 0;
            mult_a[13] = 0;
            mult_a[14] = 0;
            mult_a[15] = 0;

            mult_b[ 0] = Pooling_MAP[0][0][0];
            mult_b[ 1] = Pooling_MAP[0][0][1];
            mult_b[ 2] = Pooling_MAP[0][1][0];
            mult_b[ 3] = Pooling_MAP[0][1][1];
            mult_b[ 4] = Pooling_MAP[1][0][0];
            mult_b[ 5] = Pooling_MAP[1][0][1];
            mult_b[ 6] = Pooling_MAP[1][1][0];
            mult_b[ 7] = Pooling_MAP[1][1][1];
            multi_result_n[ 8] = 0;
            multi_result_n[ 9] = 0;
            multi_result_n[10] = 0;
            multi_result_n[11] = 0;
            multi_result_n[12] = 0;
            multi_result_n[13] = 0;
            multi_result_n[14] = 0;
            multi_result_n[15] = 0;

            multi_result_n[ 0] = mult_out[ 0];
            multi_result_n[ 1] = mult_out[ 1]; 
            multi_result_n[ 2] = mult_out[ 2]; 
            multi_result_n[ 3] = mult_out[ 3]; 
            multi_result_n[ 4] = mult_out[ 4]; 
            multi_result_n[ 5] = mult_out[ 5]; 
            multi_result_n[ 6] = mult_out[ 6]; 
            multi_result_n[ 7] = mult_out[ 7]; 
            multi_result_n[ 8] = mult_out[ 8]; 
            multi_result_n[ 9] = mult_out[ 9]; 
            multi_result_n[10] = mult_out[10]; 
            multi_result_n[11] = mult_out[11]; 
            multi_result_n[12] = mult_out[12]; 
            multi_result_n[13] = mult_out[13]; 
            multi_result_n[14] = mult_out[14]; 
            multi_result_n[15] = mult_out[15]; 
        end

        if(input_idx > LINEAR_START  && input_idx < LINEAR_START + 6) begin

            // stage 2
            add_a[ 0]   = multi_result[ 0];
            add_b[ 0]   = multi_result[ 1];
            add_a[ 1]   = multi_result[ 2];
            add_b[ 1]   = multi_result[ 3];
            add_a[ 2]   = multi_result[ 4];
            add_b[ 2]   = multi_result[ 5];
            add_a[ 3]   = multi_result[ 6];
            add_b[ 3]   = multi_result[ 7];
            add_a[ 4]   = multi_result[ 8];
            add_b[ 4]   = multi_result[ 9];
            add_a[ 5]   = multi_result[10];
            add_b[ 5]   = multi_result[11];
            add_a[ 6]   = multi_result[12];
            add_b[ 6]   = multi_result[13];
            add_a[ 7]   = multi_result[14];
            add_b[ 7]   = multi_result[15];

            add_a[ 8]   = add_out[ 0];
            add_b[ 8]   = add_out[ 1];
            add_a[ 9]   = add_out[ 2];
            add_b[ 9]   = add_out[ 3];
            add_a[10]   = add_out[ 4];
            add_b[10]   = add_out[ 5];
            add_a[11]   = add_out[ 6];
            add_b[11]   = add_out[ 7];

            stage2_reg_n[0] = add_out[ 8];
            stage2_reg_n[1] = add_out[ 9];
            stage2_reg_n[2] = add_out[10];
            stage2_reg_n[3] = add_out[11];

            //stage 3
            add_a[12]   = stage2_reg[0];
            add_b[12]   = stage2_reg[1];
            add_a[13]   = stage2_reg[2];
            add_b[13]   = stage2_reg[3];
            add_a[14]   = add_out[12];
            add_b[14]   = B1;
            add_a[15]   = add_out[13];
            add_b[15]   = B1;

            stage3_reg_n[0] = add_out[14];
            stage3_reg_n[1] = add_out[15];

            //stage 4 leaky relu

            mult_a[16] = stage3_reg[0];
            mult_b[16] = LEAKY_ALPHA;
            mult_a[17] = stage3_reg[1];
            mult_b[17] = LEAKY_ALPHA;

            leaky_relu_out[0] = ((stage3_reg[0][31]) && !(stage3_reg[0][30:0] == 31'b0) && !(&stage3_reg[0][30:23]) && (stage3_reg[0][22:0]!=0)) ? mult_out[16] : stage3_reg[0];
            leaky_relu_out[1] = ((stage3_reg[1][31]) && !(stage3_reg[1][30:0] == 31'b0) && !(&stage3_reg[1][30:23]) && (stage3_reg[1][22:0]!=0)) ? mult_out[17] : stage3_reg[1];
        end

        if(input_idx == LINEAR_START + 3) begin
            Linear_Map1_n[0] = leaky_relu_out[0];
            Linear_Map1_n[1] = leaky_relu_out[1];
        end

        if(input_idx == LINEAR_START + 4) begin
            Linear_Map1_n[2] = leaky_relu_out[0];
            Linear_Map1_n[3] = leaky_relu_out[1];
        end

        if(input_idx == LINEAR_START + 5) begin
            Linear_Map1_n[4] = leaky_relu_out[0];
        end

        // =========== Linear 2 ================
        if(input_idx == LINEAR_START_2) begin
            mult_a[ 0] = W2[0][0];
            mult_a[ 1] = W2[0][1];
            mult_a[ 2] = W2[0][2];
            mult_a[ 3] = W2[0][3];
            mult_a[ 4] = W2[0][4];
            mult_a[ 5] = W2[1][0];
            mult_a[ 6] = W2[1][1];
            mult_a[ 7] = W2[1][2];
            mult_a[ 8] = W2[1][3];
            mult_a[ 9] = W2[1][4];
            mult_a[10] = W2[2][0];
            mult_a[11] = W2[2][1];
            mult_a[12] = W2[2][2];
            mult_a[13] = W2[2][3];
            mult_a[14] = W2[2][4];

            mult_b[ 0] = Linear_Map1[0];
            mult_b[ 1] = Linear_Map1[1];
            mult_b[ 2] = Linear_Map1[2];
            mult_b[ 3] = Linear_Map1[3];
            mult_b[ 4] = Linear_Map1[4];
            mult_b[ 5] = Linear_Map1[0];
            mult_b[ 6] = Linear_Map1[1];
            mult_b[ 7] = Linear_Map1[2];
            mult_b[ 8] = Linear_Map1[3];
            mult_b[ 9] = Linear_Map1[4];
            mult_b[10] = Linear_Map1[0];
            mult_b[11] = Linear_Map1[1];
            mult_b[12] = Linear_Map1[2];
            mult_b[13] = Linear_Map1[3];
            mult_b[14] = Linear_Map1[4];

            multi_result_n[ 0] = mult_out[ 0];
            multi_result_n[ 1] = mult_out[ 1]; 
            multi_result_n[ 2] = mult_out[ 2]; 
            multi_result_n[ 3] = mult_out[ 3]; 
            multi_result_n[ 4] = mult_out[ 4]; 
            multi_result_n[ 5] = mult_out[ 5]; 
            multi_result_n[ 6] = mult_out[ 6]; 
            multi_result_n[ 7] = mult_out[ 7]; 
            multi_result_n[ 8] = mult_out[ 8]; 
            multi_result_n[ 9] = mult_out[ 9]; 
            multi_result_n[10] = mult_out[10]; 
            multi_result_n[11] = mult_out[11]; 
            multi_result_n[12] = mult_out[12]; 
            multi_result_n[13] = mult_out[13]; 
            multi_result_n[14] = mult_out[14]; 
        end

        if(input_idx > LINEAR_START_2  && input_idx < LINEAR_START_2 + 5) begin

            // stage 2
            add_a[ 0]   = multi_result[ 0];
            add_b[ 0]   = multi_result[ 1];
            add_a[ 1]   = multi_result[ 2];
            add_b[ 1]   = multi_result[ 3];
            add_a[ 2]   = multi_result[ 4];
            add_b[ 2]   = B2;
            add_a[ 3]   = multi_result[ 5];
            add_b[ 3]   = multi_result[ 6];
            add_a[ 4]   = multi_result[ 7];
            add_b[ 4]   = multi_result[ 8];
            add_a[ 5]   = multi_result[ 9];
            add_b[ 5]   = B2;
            add_a[ 6]   = multi_result[10];
            add_b[ 6]   = multi_result[11];
            add_a[ 7]   = multi_result[12];
            add_b[ 7]   = multi_result[13];
            add_a[ 8]   = multi_result[14];
            add_b[ 8]   = B2;

            add_a[ 9]   = add_out[0];
            add_b[ 9]   = add_out[1];
            add_a[10]   = add_out[3];
            add_b[10]   = add_out[4];
            add_a[11]   = add_out[6];
            add_b[11]   = add_out[7];

            stage2_reg_n[0] = add_out[ 9];
            stage2_reg_n[1] = add_out[10];
            stage2_reg_n[2] = add_out[11];
            stage2_reg_n[3] = add_out[2];
            stage2_reg_n[4] = add_out[5];
            stage2_reg_n[5] = add_out[8];

            //stage 3
            add_a[12]   = stage2_reg[0];
            add_b[12]   = stage2_reg[3];
            add_a[13]   = stage2_reg[1];
            add_b[13]   = stage2_reg[4];
            add_a[14]   = stage2_reg[2];
            add_b[14]   = stage2_reg[5];



            

        end

        if(input_idx == LINEAR_START_2 + 2) begin
            Linear_Map2_n[0] = add_out[12];
            Linear_Map2_n[1] = add_out[13];
            Linear_Map2_n[2] = add_out[14];
        end
        
        

        // ===================================

        // =========== Softmax ===============
        if(input_idx == SOFT_MAX_START) begin
            exp_in = Linear_Map2[0];
            Linear_Map2_n[0] = exp_out;
            
        end
        if(input_idx == SOFT_MAX_START + 1) begin
            exp_in = Linear_Map2[1];
            Linear_Map2_n[1]       = exp_out;
            Pooling_MAP_n[0][0][0] = Linear_Map2[0]; //use pooling map as register renaming
        end
        if(input_idx == SOFT_MAX_START + 2) begin
            exp_in           = Linear_Map2[2];
            Linear_Map2_n[2] = exp_out;
            add_a[0]         = Pooling_MAP[0][0][0];
            add_b[0]         = Linear_Map2[1];
            Pooling_MAP_n[0][0][0] = add_out[0];
        end
        if(input_idx == SOFT_MAX_START + 3) begin
            add_a[0]               = Pooling_MAP[0][0][0];
            add_b[0]               = Linear_Map2[2];
            Pooling_MAP_n[0][0][0] = add_out[0];
        end
        if(input_idx == SOFT_MAX_START + 4) begin
            div_a       = Linear_Map2[0];
            div_b       = Pooling_MAP[0][0][0];
            out_valid_n = 1;
            out_n       = div_out;
        end
        if(input_idx == SOFT_MAX_START + 5) begin
            div_a = Linear_Map2[1];
            div_b = Pooling_MAP[0][0][0];
            out_valid_n = 1;
            out_n       = div_out;
        end
        if(input_idx == SOFT_MAX_START + 6) begin
            div_a = Linear_Map2[2];
            div_b = Pooling_MAP[0][0][0];
            out_valid_n = 1;
            out_n       = div_out;
        end
        
        // ===================================
    end

    if(cs == TASK1) begin

        //check if capacity is enough
        if(input_idx == 5) begin
            if(cap_cost[1] <= cap_cost[0]) begin
                no_candidat_n = 0;
            end
        end
        if(input_idx == 6) begin
            if(cap_cost[2] <= cap_cost[0]) begin
                no_candidat_n = 0;
            end
        end
        if(input_idx == 7) begin
            if(cap_cost[3] <= cap_cost[0]) begin
                no_candidat_n = 0;
            end
        end
        if(input_idx == 8) begin
            if(cap_cost[4] <= cap_cost[0]) begin
                no_candidat_n   = 0;
            end
            if(cap_cost[2] > cap_cost[0] && cap_cost[4] > cap_cost[0]) begin
                can_pre_count_n = 1;
            end
        end

        if(input_idx == 36 && no_candidate) begin
            out_n       = 32'b0;
            out_valid_n = 1;
        end

        if(input_idx == 49 && can_pre_count) begin
            cmp_a = CONV_result[0][0][0];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[1] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = CONV_result[0][0][0];
                combination_n = 4'b1000;
            end
        end

        if(input_idx == 50 && can_pre_count) begin
            cmp_a = CONV_result[0][0][1];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[3] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = CONV_result[0][0][1];
                combination_n = 4'b0010;
            end
        end

        if(input_idx == 51 && can_pre_count) begin
            add_a[18] = CONV_result[0][0][0];
            add_b[18] = CONV_result[0][0][1];
            cmp_a = add_out[18];
            cmp_b = CONV_result[0][5][5];
            out_valid_n   = 1;
            if(cap_cost[1] + cap_cost[3] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[18];
                combination_n = 4'b1010;
                out_n         = 4'b1010;
            end else begin
                out_n         = combination;
            end
        end


        if(input_idx < 36) Image_Map_n[row_idx][col_idx] = Image;

        if (input_idx < 5) begin
            cap_cost_n[4]   = capacity_cost;
            cap_cost_n[3]   = cap_cost[4];
            cap_cost_n[2]   = cap_cost[3];
            cap_cost_n[1]   = cap_cost[2];
            cap_cost_n[0]   = cap_cost[1];
        end

        // to store the 1st conv result (task1: sum up)
        if(input_idx > CONV_START + 4 && input_idx < CONV_START + 41) begin
          add_a[16]              = add_out[14];
          add_b[16]              = CONV_result[0][0][0];
          add_a[17]              = add_out[15];
          add_b[17]              = CONV_result[0][0][1];
          CONV_result_n[0][0][0] = add_out[16];
          CONV_result_n[0][0][1] = add_out[17];
        end


        // image 1 convolution
        // if (input_idx > 44 && input_idx < 85) begin
        if (input_idx > 44 && input_idx < 85) begin
            // === S1: feed multipliers ===
            conv_col2_n = (conv_col2 == 5) ? 0 : (conv_col2 + 1);
            conv_row2_n = (conv_col2 == 5) ? (conv_row2 + 1) :  conv_row2;

            mult_a[ 0]  = Kernel_C[ 0];
            mult_a[ 1]  = Kernel_C[ 1];
            mult_a[ 2]  = Kernel_C[ 2];
            mult_a[ 3]  = Kernel_C[ 3];
            mult_a[ 4]  = Kernel_C[ 4];
            mult_a[ 5]  = Kernel_C[ 5];
            mult_a[ 6]  = Kernel_C[ 6];
            mult_a[ 7]  = Kernel_C[ 7];
            mult_a[ 8]  = Kernel_C[ 8];
            mult_a[ 9]  = Kernel_D[ 0];
            mult_a[10]  = Kernel_D[ 1];
            mult_a[11]  = Kernel_D[ 2];
            mult_a[12]  = Kernel_D[ 3];
            mult_a[13]  = Kernel_D[ 4];
            mult_a[14]  = Kernel_D[ 5];
            mult_a[15]  = Kernel_D[ 6];
            mult_a[16]  = Kernel_D[ 7];
            mult_a[17]  = Kernel_D[ 8];

            r1 = conv_row2;  c1 = conv_col2;
            if (mode_reg[1] == 1'b0) begin
                // replicate
                r0 = (conv_row2 == 0) ? 0 : (conv_row2 - 1);
                r2 = (conv_row2 == 5) ? 5 : (conv_row2 + 1);
                c0 = (conv_col2 == 0) ? 0 : (conv_col2 - 1);
                c2 = (conv_col2 == 5) ? 5 : (conv_col2 + 1);
            end else begin
                // reflect
                r0 = (conv_row2 == 0) ? 1 : (conv_row2 - 1);
                r2 = (conv_row2 == 5) ? 4 : (conv_row2 + 1);
                c0 = (conv_col2 == 0) ? 1 : (conv_col2 - 1);
                c2 = (conv_col2 == 5) ? 4 : (conv_col2 + 1);
            end

            mult_b[0]  = Image_Map[r0][c0];
            mult_b[1]  = Image_Map[r0][c1];
            mult_b[2]  = Image_Map[r0][c2];
            mult_b[3]  = Image_Map[r1][c0];
            mult_b[4]  = Image_Map[r1][c1];
            mult_b[5]  = Image_Map[r1][c2];
            mult_b[6]  = Image_Map[r2][c0];
            mult_b[7]  = Image_Map[r2][c1];
            mult_b[8]  = Image_Map[r2][c2];

            mult_b[ 9] = mult_b[0];
            mult_b[10] = mult_b[1];
            mult_b[11] = mult_b[2];
            mult_b[12] = mult_b[3];
            mult_b[13] = mult_b[4];
            mult_b[14] = mult_b[5];
            mult_b[15] = mult_b[6];
            mult_b[16] = mult_b[7];
            mult_b[17] = mult_b[8];


            multi_result_n[ 0] = mult_out[ 0];
            multi_result_n[ 1] = mult_out[ 1];
            multi_result_n[ 2] = mult_out[ 2];
            multi_result_n[ 3] = mult_out[ 3];
            multi_result_n[ 4] = mult_out[ 4];
            multi_result_n[ 5] = mult_out[ 5];
            multi_result_n[ 6] = mult_out[ 6];
            multi_result_n[ 7] = mult_out[ 7];
            multi_result_n[ 8] = mult_out[ 8];
            multi_result_n[ 9] = mult_out[ 9];
            multi_result_n[10] = mult_out[10];
            multi_result_n[11] = mult_out[11];
            multi_result_n[12] = mult_out[12];
            multi_result_n[13] = mult_out[13];
            multi_result_n[14] = mult_out[14];
            multi_result_n[15] = mult_out[15];
            multi_result_n[16] = mult_out[16];
            multi_result_n[17] = mult_out[17];


            add_a[ 0] = multi_result[ 0];  add_b[ 0] = multi_result[ 1];
            add_a[ 1] = multi_result[ 2];  add_b[ 1] = multi_result[ 3];
            add_a[ 2] = multi_result[ 4];  add_b[ 2] = multi_result[ 5];
            add_a[ 3] = multi_result[ 6];  add_b[ 3] = multi_result[ 7];

            add_a[ 4] = multi_result[ 9];  add_b[ 4] = multi_result[10];
            add_a[ 5] = multi_result[11];  add_b[ 5] = multi_result[12];
            add_a[ 6] = multi_result[13];  add_b[ 6] = multi_result[14];
            add_a[ 7] = multi_result[15];  add_b[ 7] = multi_result[16];

            stage2_reg_n[0] = add_out[0];
            stage2_reg_n[1] = add_out[1];
            stage2_reg_n[2] = add_out[2];
            stage2_reg_n[3] = add_out[3];

            stage2_reg_n[4] = add_out[4];
            stage2_reg_n[5] = add_out[5];
            stage2_reg_n[6] = add_out[6];
            stage2_reg_n[7] = add_out[7];

            stage2_reg_n[8] = multi_result[ 8];
            stage2_reg_n[9] = multi_result[17];


            add_a[ 8]  = stage2_reg[0];  add_b[ 8]  = stage2_reg[1];
            add_a[ 9]  = stage2_reg[2];  add_b[ 9]  = stage2_reg[3];
            add_a[10]  = stage2_reg[4];  add_b[10]  = stage2_reg[5];
            add_a[11]  = stage2_reg[6];  add_b[11]  = stage2_reg[7];

            stage3_reg_n[0] = add_out[ 8];
            stage3_reg_n[1] = add_out[ 9];
            stage3_reg_n[2] = add_out[10];
            stage3_reg_n[3] = add_out[11];

            stage3_reg_n[4] = stage2_reg[ 8];
            stage3_reg_n[5] = stage2_reg[ 9];


            add_a[12]  = stage3_reg[0];  add_b[12] = stage3_reg[1];
            add_a[13]  = stage3_reg[2];  add_b[13] = stage3_reg[3];

            stage4_reg_n[0] = add_out[12];
            stage4_reg_n[1] = add_out[13];
            stage4_reg_n[2] = stage3_reg[4];
            stage4_reg_n[3] = stage3_reg[5];


            add_a[14]  = stage4_reg[0];  add_b[14] = stage4_reg[2];
            add_a[15]  = stage4_reg[1];  add_b[15] = stage4_reg[3];
        end

        if(input_idx > 48 && input_idx < 85) begin
        //if(input_idx > 21 && input_idx < 58) begin
            add_a[16]              = add_out[14];
            add_b[16]              = CONV_result[0][0][2];
            add_a[17]              = add_out[15];
            add_b[17]              = CONV_result[0][0][3];
            CONV_result_n[0][0][2] = add_out[16];
            CONV_result_n[0][0][3] = add_out[17];
        end

        // [ 0] : {1}
        // [ 1] : {2}
        // [ 2] : {3}
        // [ 3] : {4}
        // [ 4] : {1, 2}
        // [ 5] : {1, 3}
        // [ 6] : {1, 4}
        // [ 7] : {2, 3}
        // [ 8] : {2, 4}
        // [ 9] : {3, 4}
        // [10] : {1, 2, 3}
        // [11] : {1, 2, 4}
        // [12] : {1, 3, 4}
        // [13] : {2, 3, 4}
        // A : 1
        // B : 3
        // C : 2
        // D : 4
        //use CONV_result[0][5][5] to be the current max score

        // set size = 1
        if(input_idx == 83) begin
            cmp_a = CONV_result[0][0][0];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[1] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = CONV_result[0][0][0];
                combination_n = 4'b1000;
            end
        end

        if(input_idx == 84) begin
            cmp_a = CONV_result[0][0][1];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[3] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = CONV_result[0][0][1];
                combination_n = 4'b0010;
            end
        end
        
        if(input_idx == 85) begin
            cmp_a = CONV_result[0][0][2];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[2] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = CONV_result[0][0][2];
                combination_n = 4'b0100;
            end
        end


        if(input_idx == 86) begin
            cmp_a = CONV_result[0][0][3];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[4] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = CONV_result[0][0][3];
                combination_n = 4'b0001;
            end
        end

        // set size = 2
        if(input_idx == 87) begin
            add_a[0] = CONV_result[0][0][0];
            add_b[0] = CONV_result[0][0][1];
            cmp_a = add_out[0];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[1] + cap_cost[3] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[0];
                combination_n = 4'b1010;
            end
        end

        if(input_idx == 88) begin
            add_a[0] = CONV_result[0][0][0];
            add_b[0] = CONV_result[0][0][2];
            cmp_a = add_out[0];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[1] + cap_cost[2] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[0];
                combination_n = 4'b1100;
            end
        end

        if(input_idx == 89) begin
            add_a[0] = CONV_result[0][0][0];
            add_b[0] = CONV_result[0][0][3];
            cmp_a = add_out[0];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[1] + cap_cost[4] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[0];
                combination_n = 4'b1001;
            end
        end

        if(input_idx == 90) begin
            add_a[0] = CONV_result[0][0][1];
            add_b[0] = CONV_result[0][0][2];
            cmp_a = add_out[0];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[2] + cap_cost[3] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[0];
                combination_n = 4'b0110;
            end
        end

        if(input_idx == 91) begin
            add_a[0] = CONV_result[0][0][1];
            add_b[0] = CONV_result[0][0][3];
            cmp_a = add_out[0];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[3] + cap_cost[4] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[0];
                combination_n = 4'b0011;
            end
        end

        if(input_idx == 92) begin
            add_a[0] = CONV_result[0][0][2];
            add_b[0] = CONV_result[0][0][3];
            cmp_a = add_out[0];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[2] + cap_cost[4] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[0];
                combination_n = 4'b0101;
            end
        end

        // set size = 3

        if(input_idx == 93) begin
            add_a[0] = CONV_result[0][0][0];
            add_b[0] = CONV_result[0][0][1];
            add_a[1] = CONV_result[0][0][2];
            add_b[1] = add_out[0];
            cmp_a = add_out[1];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[1] + cap_cost[2] + cap_cost[3] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[1];
                combination_n = 4'b1110;
            end
        end


        if(input_idx == 94) begin
            add_a[0] = CONV_result[0][0][0];
            add_b[0] = CONV_result[0][0][1];
            add_a[1] = CONV_result[0][0][3];
            add_b[1] = add_out[0];
            cmp_a = add_out[1];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[1] + cap_cost[3] + cap_cost[4] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[1];
                combination_n = 4'b1011;
            end
        end

        if(input_idx == 95) begin
            add_a[0] = CONV_result[0][0][0];
            add_b[0] = CONV_result[0][0][2];
            add_a[1] = CONV_result[0][0][3];
            add_b[1] = add_out[0];
            cmp_a = add_out[1];
            cmp_b = CONV_result[0][5][5];
            if(cap_cost[1] + cap_cost[2] + cap_cost[4] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[1];
                combination_n = 4'b1101;
            end
        end

        if(input_idx == 96) begin
            add_a[0] = CONV_result[0][0][1];
            add_b[0] = CONV_result[0][0][2];
            add_a[1] = CONV_result[0][0][3];
            add_b[1] = add_out[0];
            cmp_a = add_out[1];
            cmp_b = CONV_result[0][5][5];
            out_valid_n = 1;
            if(cap_cost[2] + cap_cost[3] + cap_cost[4] <= cap_cost[0] && agtb) begin
                CONV_result_n[0][5][5] = add_out[1];
                combination_n = 4'b0111;
                out_n         = {28'b0, 4'b0111};
            end else begin
                out_n         = {28'b0, combination};
            end
        end
    end


end

// ===============================================
endmodule

module FP_MAX2 #(parameter sig_width=23, parameter exp_width=8, parameter ieee_compliance=0)(
  input  [sig_width+exp_width:0] a,
  input  [sig_width+exp_width:0] b,
  output [sig_width+exp_width:0] z
);
  wire aeqb, altb, agtb, unordered;
  DW_fp_cmp #(sig_width, exp_width, ieee_compliance)
    U_CMP(.a(a), .b(b), .zctr(1'b1), .aeqb(aeqb), .altb(altb), .agtb(agtb), .unordered(unordered), .z0(), .z1(), .status0(), .status1());
  assign z = agtb ? a : b;
endmodule
