//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2025 ICLAB FALL Course
//   Lab08       : SAD
//   Author      : Ying-Yu (Inyi) Wang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : SAD.v
//   Module Name : SAD
//   Release version : v1.0
//   Note : Design w/ CG
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module SAD(
    //Input signals
    clk,
    rst_n,
    in_valid,
	in_data1,
    T,
    in_data2,
    w_Q,
    w_K,
    w_V,

    //Output signals
    out_valid,
    out_data
    );

input clk;
input rst_n;
input in_valid;
input signed [5:0] in_data1;
input [3:0] T;
input signed [7:0] in_data2;
input signed [7:0] w_Q;
input signed [7:0] w_K;
input signed [7:0] w_V;

output reg out_valid;
output reg signed [91:0] out_data;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
parameter d_model = 'd8;

parameter IDLE    = 3'd0,
          INPUT   = 3'd1,
          CALC_1  = 3'd2,
          CALC_4  = 3'd3,
          CALC_8  = 3'd4,
          OUTPUT  = 3'd5;
integer i, j;
genvar gi, gj;
//==============================================//
//           reg & wire declaration             //
//==============================================//
reg [2:0] cs, ns;

reg signed [18:0] Q        [0:7][0:7];
reg signed [18:0] K        [0:7][0:7];
reg signed [18:0] V        [0:7][0:7];
reg signed [18:0] Q_n      [0:7][0:7];
reg signed [18:0] K_n      [0:7][0:7];
reg signed [18:0] V_n      [0:7][0:7];
reg signed [ 7:0] IN       [0:7][0:7];
reg signed [ 7:0] WEIGHT   [0:7][0:7];
reg signed [ 7:0] IN_n     [0:7][0:7];
reg signed [ 7:0] WEIGHT_n [0:7][0:7];
reg               out_valid_n;
reg signed [91:0] out_data_n;
reg signed [ 5:0] Y        [0:3][0:3];
reg signed [ 5:0] Y_n      [0:3][0:3];
reg signed [40:0] QK       [0:7][0:7];
reg signed [40:0] QK_n     [0:7][0:7];
reg        [ 3:0] T_reg;
reg        [ 3:0] T_reg_n;
reg        [ 8:0] in_idx, in_idx_n;
reg        [ 7:0] pe_in_a  [0:7][0:7];
reg        [ 7:0] pe_in_b  [0:7][0:7];
reg        [18:0] pe_out   [0:7][0:7];

reg        [18:0] qk_pe_in_a  [0:7];
reg        [18:0] qk_pe_in_b  [0:7];
reg        [40:0] qk_pe_out   [0:7];

reg        [40:0] sv_pe_in_s  [0:7];
reg        [18:0] sv_pe_in_v  [0:7];
reg        [59:0] sv_pe_out   [0:7];


wire       [ 8:0] in_idx_1;
wire signed[18:0] sum8[0:7];
wire signed[40:0] qk_sum8;
wire signed[59:0] sv_sum8;

assign in_idx_1 = in_idx - 1;

// ===== Top-level signals =====
reg signed [5:0] a[0:3][0:3];

wire signed [24:0] det_out;
reg  signed [24:0] det_out_reg;
reg  signed [24:0] det_out_reg_n;

reg [3:0] x_idx;
reg [3:0] x_idx_n;
reg [3:0] y_idx;
reg [3:0] y_idx_n;


generate
    for(gi = 0; gi < 8; gi = gi + 1) begin
        for(gj = 0; gj < 8; gj = gj + 1) begin
            PE u_pe(.mult_a(pe_in_a[gi][gj]), .mult_b(pe_in_b[gi][gj]), .out(pe_out[gi][gj]));
        end
        assign sum8[gi] = pe_out[gi][0] + pe_out[gi][1] + pe_out[gi][2] + pe_out[gi][3] +
                           pe_out[gi][4] + pe_out[gi][5] + pe_out[gi][6] + pe_out[gi][7];
    end
endgenerate

generate
    for(gi = 0; gi < 8; gi = gi + 1) begin
        QKPE u_qkpe(.mult_a(qk_pe_in_a[gi]), .mult_b(qk_pe_in_b[gi]), .out(qk_pe_out[gi]));
    end
endgenerate

assign qk_sum8 = qk_pe_out[0] + qk_pe_out[1] + qk_pe_out[2] + qk_pe_out[3] + 
                 qk_pe_out[4] + qk_pe_out[5] + qk_pe_out[6] + qk_pe_out[7];

generate
    for(gi = 0; gi < 8; gi = gi + 1) begin
        SVPE u_svpe(.mult_a(sv_pe_in_s[gi]), .mult_b(sv_pe_in_v[gi]), .out(sv_pe_out[gi]));
    end
endgenerate

assign sv_sum8 = sv_pe_out[0] + sv_pe_out[1] + sv_pe_out[2] + sv_pe_out[3] + 
                 sv_pe_out[4] + sv_pe_out[5] + sv_pe_out[6] + sv_pe_out[7];

DET4x4 #(
    .OUT_W(25)
) u_det4x4 (
    .a00(a[0][0]), .a01(a[0][1]), .a02(a[0][2]), .a03(a[0][3]),
    .a10(a[1][0]), .a11(a[1][1]), .a12(a[1][2]), .a13(a[1][3]),
    .a20(a[2][0]), .a21(a[2][1]), .a22(a[2][2]), .a23(a[2][3]),
    .a30(a[3][0]), .a31(a[3][1]), .a32(a[3][2]), .a33(a[3][3]),
    .det(det_out)
);

//==============================================//
//                 GATED_OR                     //
//==============================================//



//==============================================//
//                  design                      //
//==============================================//
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
                case (T)
                    'd1:     ns = CALC_1;
                    'd4:     ns = CALC_4;
                    'd8:     ns = CALC_8;
                    default: ns = cs;
                endcase
            end else begin
                ns = cs;
            end
        end

        CALC_1: begin
            if(in_idx == 199) ns = IDLE;
            else              ns = cs;
        end
        
        CALC_4: begin
            if(in_idx == 223) ns = IDLE;
            else              ns = cs;            
        end
        
        CALC_8: begin
            if(in_idx == 255) ns = IDLE;
            else              ns = cs;
        end
   
    endcase
end



always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_data     <= 0;
        out_valid    <= 0;
        in_idx       <= 0;
        det_out_reg  <= 0;
        x_idx        <= 0;
        y_idx        <= 0;
        T_reg        <= 0;
    end else begin
        out_valid    <= out_valid_n;
        out_data     <= out_data_n;
        in_idx       <= in_idx_n;
        det_out_reg  <= det_out_reg_n;
        x_idx        <= x_idx_n;
        y_idx        <= y_idx_n;
        T_reg        <= T_reg_n;
    end
end


generate
    for(gi = 0; gi < 8; gi = gi + 1) begin
        for(gj = 0; gj < 8; gj = gj + 1) begin
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    Q     [gi][gj]     <= 0;
                    K     [gi][gj]     <= 0;
                    V     [gi][gj]     <= 0;
                    QK    [gi][gj]     <= 0;
                    WEIGHT[gi][gj]     <= 0;
                    IN    [gi][gj]     <= 0;
                end else begin
                    Q     [gi][gj]     <= Q_n [gi][gj];
                    K     [gi][gj]     <= K_n [gi][gj];
                    V     [gi][gj]     <= V_n [gi][gj];
                    QK    [gi][gj]     <= QK_n[gi][gj];
                    WEIGHT[gi][gj]     <= WEIGHT_n[gi][gj];
                    IN    [gi][gj]     <= IN_n[gi][gj];
                end
            end
        end
    end

    for(gi = 0; gi < 4; gi = gi + 1) begin
        for(gj = 0; gj < 4; gj = gj + 1) begin
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    Y     [gi][gj]     <= 0;
                end else begin
                    Y     [gi][gj]     <= Y_n [gi][gj];
                end
            end
        end
    end
endgenerate







always @(*) begin
    out_valid_n       = 0;
    out_data_n        = 0;
    in_idx_n          = in_idx;
    IN_n              = IN;
    WEIGHT_n          = WEIGHT;
    Q_n               = Q;
    K_n               = K;
    V_n               = V;
    QK_n              = QK;
    Y_n               = Y;
    x_idx_n           = x_idx;
    y_idx_n           = y_idx;
    det_out_reg_n     = det_out_reg;
    for(i = 0; i < 8; i = i + 1) begin
        for(j = 0; j < 8; j = j + 1) begin
            pe_in_a[i][j] = 0;
            pe_in_b[i][j] = 0;
            qk_pe_in_a[i] = 0;
            qk_pe_in_b[i] = 0;
            sv_pe_in_s[i] = 0;
            sv_pe_in_v[i] = 0;
        end
    end
    
    for(i = 0; i < 4; i = i + 1) begin
        for(j = 0; j < 4; j = j + 1) begin
            a[i][j] = 0;
        end
    end
    if(cs == IDLE) begin
        for(i = 0; i < 8; i = i + 1) begin
            for(j = 0; j < 8; j = j + 1) begin
                Q_n     [i][j]     = 0;
                K_n     [i][j]     = 0;
                V_n     [i][j]     = 0;
                QK_n    [i][j]     = 0;
                WEIGHT_n[i][j]     = 0;
                IN_n    [i][j]     = 0;
            end
        end

        for(i = 0; i < 4; i = i + 1) begin
            for(j = 0; j < 4; j = j + 1) begin
                Y_n [i][j] = 0;
            end
        end
        x_idx_n    = 0;
        y_idx_n    = 0;
        in_idx_n   = 0;
        T_reg_n    = 0;

        if(in_valid) begin
            in_idx_n        = 1;
            T_reg_n         = T;
            Y_n      [0][0] = in_data1;
            IN_n     [0][0] = in_data2;
            WEIGHT_n [0][0] = w_Q;
            
        end
    end

    if(cs == CALC_1) begin
        in_idx_n = in_idx + 1;
        if(in_idx < 16) begin// if in_idx < 16
            Y_n[ in_idx[3:2]][in_idx[1:0]] = in_data1;
        end

        if(in_idx < 8) begin// if in_idx < 64
            IN_n[0][in_idx[2:0]] = in_data2;
        end

        case (in_idx[7:6])
            2'b00: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_Q;
            end
            2'b01: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_K;
            end
            2'b10: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_V;
            end
            default: begin
                WEIGHT_n = WEIGHT;
            end 
        endcase

        //calculate the determinant
        if(in_idx == 16) begin
            for(i = 0; i < 4; i = i + 1) begin
                for(j = 0; j < 4; j = j + 1) begin
                    a[i][j]       = Y[i][j];
                    det_out_reg_n = det_out;
                end
            end
        end

        if(in_idx >= 64 && in_idx < 72 ) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx[2:0]];
                end
                Q_n[i][in_idx[2:0]] = sum8[i];
            end
        end

        if(in_idx >= 121 && in_idx < 129 ) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx_1[2:0]];
                end
                K_n[i][in_idx_1[2:0]] = sum8[i];
            end
        end

        if(in_idx >= 185 && in_idx < 193) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx_1[2:0]];
                end
                V_n[i][in_idx_1[2:0]] = sum8[i];
            end
        end

        // Calculate QK Matrix
        if(in_idx >= 128 && in_idx < 128 + 64) begin
            for(i = 0; i < 8; i = i + 1) begin
                qk_pe_in_a[i] = Q[in_idx_1[5:3]][i];
                qk_pe_in_b[i] = K[in_idx_1[2:0]][i];
            end
            QK_n[in_idx_1[5:3]][in_idx_1[2:0]] = qk_sum8 > 0 ? qk_sum8 / 3 : 0; 
        end

        // Calculate SV Matrix (output)
        if(in_idx >= 192 && in_idx < 192 + 8) begin
            //update idx;
            if(x_idx == 7) begin
                x_idx_n = 0;
                if(y_idx_n == 3) begin
                    y_idx_n = 0;
                end else begin
                    y_idx_n = y_idx + 1;
                end
            end else begin
                    x_idx_n = x_idx + 1;
            end
            for(i = 0; i < 8; i = i + 1) begin
                sv_pe_in_s[i] = QK[y_idx][i];
                sv_pe_in_v[i] = V[i][x_idx];
            end
            out_data_n    = $signed(sv_sum8) * $signed(det_out_reg);
            out_valid_n = 1;
        end

        
        
    end

    if(cs == CALC_4) begin
        in_idx_n = in_idx + 1;
        if(in_idx < 16) begin// if in_idx < 16
            Y_n[ in_idx[3:2]][in_idx[1:0]] = in_data1;
        end

        if(in_idx < 32) begin// if in_idx < 16
            IN_n[in_idx[4:3]][in_idx[2:0]] = in_data2;
        end

        case (in_idx[7:6])
            2'b00: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_Q;
            end
            2'b01: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_K;
            end
            2'b10: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_V;
            end
            default: begin
                WEIGHT_n = WEIGHT;
            end 
        endcase

        //calculate the determinant
        if(in_idx == 16) begin
            for(i = 0; i < 4; i = i + 1) begin
                for(j = 0; j < 4; j = j + 1) begin
                    a[i][j]       = Y[i][j];
                    det_out_reg_n = det_out;
                end
            end
        end

        if(in_idx >= 64 && in_idx < 72 ) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx[2:0]];
                end
                Q_n[i][in_idx[2:0]] = sum8[i];
            end
        end

        if(in_idx >= 121 && in_idx < 129 ) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx_1[2:0]];
                end
                K_n[i][in_idx_1[2:0]] = sum8[i];
            end
        end

        if(in_idx >= 185 && in_idx < 193) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx_1[2:0]];
                end
                V_n[i][in_idx_1[2:0]] = sum8[i];
            end
        end

        // Calculate QK Matrix
        if(in_idx >= 128 && in_idx < 128 + 64) begin
            for(i = 0; i < 8; i = i + 1) begin
                qk_pe_in_a[i] = Q[in_idx_1[5:3]][i];
                qk_pe_in_b[i] = K[in_idx_1[2:0]][i];
            end
            QK_n[in_idx_1[5:3]][in_idx_1[2:0]] = qk_sum8 > 0 ? qk_sum8 / 3 : 0; 
        end

        // Calculate SV Matrix (output)
        if(in_idx >= 192 && in_idx < 192 + 32) begin
            //update idx;
            if(x_idx == 7) begin
                x_idx_n = 0;
                if(y_idx_n == 3) begin
                    y_idx_n = 0;
                end else begin
                    y_idx_n = y_idx + 1;
                end
            end else begin
                    x_idx_n = x_idx + 1;
            end
            for(i = 0; i < 8; i = i + 1) begin
                sv_pe_in_s[i] = QK[y_idx][i];
                sv_pe_in_v[i] = V[i][x_idx];
            end
            out_data_n    = $signed(sv_sum8) * $signed(det_out_reg);
            out_valid_n = 1;
        end
    end

    if(cs == CALC_8) begin
        in_idx_n = in_idx + 1;
        if(!in_idx[4]) begin// if in_idx < 16
            Y_n[ in_idx[3:2]][in_idx[1:0]] = in_data1;
        end

        if(in_idx < 64) begin// if in_idx < 64
            IN_n[in_idx[5:3]][in_idx[2:0]] = in_data2;
        end

        case (in_idx[7:6])
            2'b00: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_Q;
            end
            2'b01: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_K;
            end
            2'b10: begin
                WEIGHT_n[in_idx[5:3]][in_idx[2:0]] = w_V;
            end
            default: begin
                WEIGHT_n = WEIGHT;
            end 
        endcase

        //calculate the determinant
        if(in_idx == 16) begin
            for(i = 0; i < 4; i = i + 1) begin
                for(j = 0; j < 4; j = j + 1) begin
                    a[i][j]       = Y[i][j];
                    det_out_reg_n = det_out;
                end
            end
        end

        if(in_idx >= 64 && in_idx < 72 ) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx[2:0]];
                end
                Q_n[i][in_idx[2:0]] = sum8[i];
            end
        end

        if(in_idx >= 121 && in_idx < 129 ) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx_1[2:0]];
                end
                K_n[i][in_idx_1[2:0]] = sum8[i];
            end
        end

        if(in_idx >= 185 && in_idx < 193) begin
            for(i = 0; i < 8; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    pe_in_a[i][j] = IN[i][j];
                    pe_in_b[i][j] = WEIGHT[j][in_idx_1[2:0]];
                end
                V_n[i][in_idx_1[2:0]] = sum8[i];
            end
        end

        // Calculate QK Matrix
        if(in_idx >= 128 && in_idx < 128 + 65) begin
            for(i = 0; i < 8; i = i + 1) begin
                qk_pe_in_a[i] = Q[in_idx_1[5:3]][i];
                qk_pe_in_b[i] = K[in_idx_1[2:0]][i];
                
            end
            QK_n[in_idx_1[5:3]][in_idx_1[2:0]] = qk_sum8 > 0 ? qk_sum8 / 3 : 0; 
        end

        // Calculate SV Matrix (output)
        if(in_idx >= 192 && in_idx < 192 + 64) begin
            //update idx;
            if(x_idx == 7) begin
                x_idx_n = 0;
                if(y_idx_n == 7) begin
                    y_idx_n = 0;
                end else begin
                    y_idx_n = y_idx + 1;
                end
            end else begin
                    x_idx_n = x_idx + 1;
            end
            for(i = 0; i < 8; i = i + 1) begin
                sv_pe_in_s[i] = QK[y_idx][i];
                sv_pe_in_v[i] = V[i][x_idx];
            end
            out_data_n    = $signed(sv_sum8) * $signed(det_out_reg);
            out_valid_n = 1;
        end
    end

end


endmodule


module PE(
    input      signed [ 7:0] mult_a,
    input      signed [ 7:0] mult_b,
    output reg signed [18:0] out
);

    always @(*) begin
        if(mult_a == 0 || mult_b == 0) begin
            out = 0;
        end else begin
            out = mult_a * mult_b;
        end
    end

endmodule

module QKPE(
    input      signed [18:0] mult_a,
    input      signed [18:0] mult_b,
    output reg signed [40:0] out
);
    always @(*) begin
        if(mult_a == 0 || mult_b == 0) begin
            out = 0;
        end else begin
            out = mult_a * mult_b;
        end
    end

endmodule

module SVPE(
    input      signed [40:0] mult_a,
    input      signed [18:0] mult_b,
    output reg signed [59:0] out
);
    always @(*) begin
        if(mult_a == 0 || mult_b == 0) begin
            out = 0;
        end else begin
            out = mult_a * mult_b;
        end
    end

endmodule

module DET4x4 #(
    parameter OUT_W = 25  // must be >= 25 to cover worst-case ±2^24
)(
    input  signed [5:0] a00, input signed [5:0] a01, input signed [5:0] a02, input signed [5:0] a03,
    input  signed [5:0] a10, input signed [5:0] a11, input signed [5:0] a12, input signed [5:0] a13,
    input  signed [5:0] a20, input signed [5:0] a21, input signed [5:0] a22, input signed [5:0] a23,
    input  signed [5:0] a30, input signed [5:0] a31, input signed [5:0] a32, input signed [5:0] a33,
    output signed [OUT_W-1:0] det
);

    // 3x3 determinant via Sarrus rule.
    function automatic signed [31:0] det3 (
        input signed [5:0] b00, input signed [5:0] b01, input signed [5:0] b02,
        input signed [5:0] b10, input signed [5:0] b11, input signed [5:0] b12,
        input signed [5:0] b20, input signed [5:0] b21, input signed [5:0] b22
    );
        // Use 32-bit temps for triple products (safe for 6-bit inputs)
        reg signed [31:0] t1, t2, t3, t4, t5, t6;
        begin
            // positive diagonals
            t1 = b00 * b11; t1 = t1 * b22;
            t2 = b01 * b12; t2 = t2 * b20;
            t3 = b02 * b10; t3 = t3 * b21;
            // negative diagonals
            t4 = b02 * b11; t4 = t4 * b20;
            t5 = b01 * b10; t5 = t5 * b22;
            t6 = b00 * b12; t6 = t6 * b21;
            det3 = (t1 + t2 + t3) - (t4 + t5 + t6);
        end
    endfunction

    // 3x3 minors (remove row 0, col j)
    wire signed [31:0] m0 = det3(
        a11, a12, a13,
        a21, a22, a23,
        a31, a32, a33
    );
    wire signed [31:0] m1 = det3(
        a10, a12, a13,
        a20, a22, a23,
        a30, a32, a33
    );
    wire signed [31:0] m2 = det3(
        a10, a11, a13,
        a20, a21, a23,
        a30, a31, a33
    );
    wire signed [31:0] m3 = det3(
        a10, a11, a12,
        a20, a21, a22,
        a30, a31, a32
    );

    // Use 64-bit accumulation for top-level combination to avoid truncation
    wire signed [63:0] term0 = $signed(a00) * $signed(m0);
    wire signed [63:0] term1 = $signed(a01) * $signed(m1);
    wire signed [63:0] term2 = $signed(a02) * $signed(m2);
    wire signed [63:0] term3 = $signed(a03) * $signed(m3);

    wire signed [63:0] det64 = term0 - term1 + term2 - term3;

    // Truncate/fit to OUT_W (caller should choose OUT_W >= 25 for safety)
    assign det = det64[OUT_W-1:0];

endmodule

