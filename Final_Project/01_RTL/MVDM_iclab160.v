module MVDM(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    in_data,
    // output signals
    out_valid,
    out_sad
    );

input clk;
input rst_n;
input in_valid;
input in_valid2;
input [8:0] in_data;

output reg out_valid;
output reg out_sad;

//=======================================================
//                   PARAM & INT
//=======================================================
parameter IDLE        = 4'd0,
          IN_IMG      = 4'd1,
          WAIT        = 4'd2,
          IN_INST     = 4'd3,
          FETCH       = 4'd4,
          ARBITRATION = 4'd5,
          SATD        = 4'd6,
          OUTPUT      = 4'd7;

integer i, j, k;
//=======================================================
//                   Reg/Wire
//=======================================================
reg [3:0] cs, ns;
reg out_valid_n;
reg out_sad_n;
reg [14:0] img_ctr, img_ctr_n;
//reg [7:0] L0Point1x;
//reg [7:0] L0Point1x_n;
//reg [7:0] L0Point1y;
//reg [7:0] L0Point1y_n;
//reg [7:0] L1Point1x;
//reg [7:0] L1Point1x_n;
//reg [7:0] L1Point1y;
//reg [7:0] L1Point1y_n;
//reg [7:0] L0Point2x;
//reg [7:0] L0Point2x_n;
//reg [7:0] L0Point2y;
//reg [7:0] L0Point2y_n;
//reg [7:0] L1Point2x;
//reg [7:0] L1Point2x_n;
//reg [7:0] L1Point2y;
//reg [7:0] L1Point2y_n;
//reg       FxL0P1;
//reg       FyL0P1;
//reg       FxL1P1;
//reg       FyL1P1;
//reg       FxL0P2;
//reg       FyL0P2;
//reg       FxL1P2;
//reg       FyL1P2;

//reg       FxL0P1_n;
//reg       FyL0P1_n;
//reg       FxL1P1_n;
//reg       FyL1P1_n;
//reg       FxL0P2_n;
//reg       FyL0P2_n;
//reg       FxL1P2_n;
//reg       FyL1P2_n;

reg       Fx  [0:1][0:1];
reg       Fy  [0:1][0:1];
reg       Fx_n[0:1][0:1];
reg       Fy_n[0:1][0:1];
reg [7:0] X   [0:1][0:1];
reg [7:0] Y   [0:1][0:1];
reg [7:0] X_n [0:1][0:1];
reg [7:0] Y_n [0:1][0:1];
reg [1:0] PointL;
reg [1:0] PointL_n;
//for mem
reg [9:0]    L0_addr;
reg [9:0]    L0_addr_n;
reg [9:0]    L1_addr;
reg [9:0]    L1_addr_n;
reg [127:0]  L0_din;
reg [127:0]  L0_din_n;
reg [127:0]  L1_din;
reg [127:0]  L1_din_n;
reg [127:0]  L0_dout;
reg [127:0]  L1_dout;

reg          L0_web, L0_web_n;
reg          L1_web, L1_web_n;

reg [5:0] pat_cnt, pat_cnt_n;

wire [7:0] input_data;
assign input_data = in_data[8:1];

reg [ 2:0] inst_ctr;
reg [ 2:0] inst_ctr_n;

reg [5:0] output_ctr, output_ctr_n;

reg signed [20:0] BUF    [0:1][0:9][0:9];
reg signed [20:0] BUF_n  [0:1][0:9][0:9];

reg signed [8:0] D      [0:3][0:3];
reg signed [8:0] D_n    [0:3][0:3];
reg signed [10:0] D2    [0:3][0:3];
reg signed [10:0] D2_n  [0:3][0:3];
reg signed [12:0] D3    [0:3][0:3];
reg signed [12:0] D3_n  [0:3][0:3];

reg        [12:0] D3_abs[0:3][0:3];

reg signed [20:0] VER    [0:5][0:9];
reg signed [20:0] VER_n  [0:5][0:9];

reg [23:0] SATD_SUM;
reg [23:0] SATD_SUM_n;
reg [23:0] BEST_SUM     [0:1];
reg [23:0] BEST_SUM_n   [0:1];
reg [ 3:0] BEST_POINT   [0:1];
reg [ 3:0] BEST_POINT_n [0:1];  

reg [7:0] ROW   [0:14];
reg [7:0] ROW_n [0:14];
reg [4:0] fetch_ctr;
reg [4:0] fetch_ctr_n;
reg signed [8:0] left_bound;
reg signed [8:0] l1_left_bound;
reg [9:0] fetch_addr;

reg [5:0] satd_cnt, satd_cnt_n;

reg signed [8:0] row_idx;
reg signed [8:0] row_idx_n; 
assign left_bound   = $signed(X[PointL[1]][PointL[0]] - 2) >= 0 ? X[PointL[1]][PointL[0]] - 2 : 0;
//assign l1_bottom_bound = $signed(L1Point1y + 3) >= 0 ? L1Point1y - 2 : 0;

wire [255:0] fetch_bus;

reg  [3:0] x_idx   [0:1];
reg  [3:0] y_idx   [0:1];
reg  [3:0] x_idx_n [0:1];
reg  [3:0] y_idx_n [0:1];

assign fetch_bus = left_bound[4] ? {L0_dout, L1_dout} : {L1_dout, L0_dout};

genvar gi, gj;
generate
    for(gi = 0; gi < 10; gi = gi + 1) begin
        for(gj = 0; gj < 10; gj = gj + 1) begin
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    BUF[0][gi][gj] <= 0;
                    BUF[1][gi][gj] <= 0;
                end else begin
                    BUF[0][gi][gj] <= BUF_n[0][gi][gj];
                    BUF[1][gi][gj] <= BUF_n[1][gi][gj];
                end
            end
        end
    end
    for(gi = 0; gi < 15;gi = gi + 1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                ROW[gi] <= 0;
            end else begin
                ROW[gi] <= ROW_n[gi];
            end
        end
    end
    for(gi = 0; gi < 6; gi = gi + 1) begin
        for(gj = 0; gj < 10; gj = gj + 1) begin
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    VER[gi][gj] <= 0;
                end else begin
                    VER[gi][gj] <= VER_n[gi][gj];
                end
            end
        end
    end
    for(gi = 0; gi < 4; gi = gi + 1) begin
        for(gj = 0; gj < 4; gj = gj + 1) begin
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    D[gi][gj] <= 0;
                end else begin
                    D[gi][gj] <= D_n[gi][gj];
                end
            end
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    D2[gi][gj] <= 0;
                end else begin
                    D2[gi][gj] <= D2_n[gi][gj];
                end
            end
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    D3[gi][gj] <= 0;
                end else begin
                    D3[gi][gj] <= D3_n[gi][gj];
                end
            end
        end
    end
endgenerate

reg signed [20:0] interp_in  [0:9][0:5];
reg signed [20:0] interp_out [0:9];

generate
    for(gi = 0; gi < 10; gi = gi + 1) begin :INTERP_UNIT
        INTERP u_interp(.IN0(interp_in[gi][0]), .IN1(interp_in[gi][1]), .IN2(interp_in[gi][2]), .IN3(interp_in[gi][3]), .IN4(interp_in[gi][4]), .IN5(interp_in[gi][5]), .OUT(interp_out[gi]));
    end
endgenerate

//=======================================================
//                   MEM
//=======================================================

IMG L0(.A(L0_addr), .DI(L0_din), .DO(L0_dout), .CK(clk), .WEB(L0_web));
IMG L1(.A(L1_addr), .DI(L1_din), .DO(L1_dout), .CK(clk), .WEB(L1_web));
//=======================================================
//                   FUNCTION
//=======================================================
function [6:0] clip128;
    input signed [9:0] v;
    begin
        if (v < 0)
            clip128 = 7'd0;
        else if (v > 7'd127)
            clip128 = 7'd127;
        else
            clip128 = v[6:0];
    end
endfunction

//=======================================================
//                   FSM
//=======================================================
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
                ns = IN_IMG;
            end
        end 
        IN_IMG: begin
            if(img_ctr == 15'b111111111111111) begin
                ns = WAIT;
            end
        end 

        WAIT: begin
            if(in_valid2) ns = IN_INST;
        end
        IN_INST: begin
            if(inst_ctr == 7) begin
                ns = FETCH;
            end
        end
        FETCH: begin
            case ({Fx[PointL[1]][PointL[0]], Fy[PointL[1]][PointL[0]]})
                2'b00: begin
                    if(fetch_ctr == 11) ns = ARBITRATION;
                end
                2'b01: begin
                    if(fetch_ctr == 17) ns = ARBITRATION; 
                end
                2'b10: begin
                    if(fetch_ctr == 12) ns = ARBITRATION;
                end
                2'b11: begin
                    if(fetch_ctr == 27) ns = ARBITRATION;
                end  
            endcase
        end
        ARBITRATION: begin
            if(inst_ctr == 1) begin
                if(PointL == 2'b01 || PointL == 2'b11) begin
                    ns = FETCH;
                end else begin
                    ns = SATD;
                end
            end
        end
        SATD: begin
            if(satd_cnt == 40) begin
                if(PointL[1] == 1) begin
                    ns = FETCH;
                end else begin
                    ns = OUTPUT;
                end
            end
        end

        OUTPUT: begin
            if(output_ctr == 27) begin
                if(pat_cnt == 0) begin
                    ns = IDLE;
                end else begin
                    ns = WAIT;
                end
            end
        end
    endcase
end
//=======================================================
//                   Design
//=======================================================


// SEQUENTIAL
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid         <= 0;
        out_sad           <= 0;
        img_ctr           <= 0;
        L0_addr           <= 0;
        L1_addr           <= 0;
        L0_din            <= 0;
        L1_din            <= 0;
        L0_web            <= 1;
        L1_web            <= 1;
        Fx[0][0]          <= 0;
        Fx[0][1]          <= 0;
        Fx[1][0]          <= 0;
        Fx[1][1]          <= 0;
        Fy[0][0]          <= 0;
        Fy[0][1]          <= 0;
        Fy[1][0]          <= 0;
        Fy[1][1]          <= 0;

        X[0][0]           <= 0;
        X[0][1]           <= 0;
        X[1][0]           <= 0;
        X[1][1]           <= 0;
        Y[0][0]           <= 0;
        Y[0][1]           <= 0;
        Y[1][0]           <= 0;
        Y[1][1]           <= 0;

        inst_ctr          <= 0;
        fetch_ctr         <= 0;
        row_idx           <= 0;
        PointL            <= 0;
        x_idx[0]          <= 0;
        y_idx[0]          <= 0;
        x_idx[1]          <= 0;
        y_idx[1]          <= 0;
        satd_cnt          <= 0;
        SATD_SUM          <= 0;
        BEST_SUM[0]       <= 0;
        BEST_SUM[1]       <= 0;
        BEST_POINT[0]     <= 0;
        BEST_POINT[1]     <= 0;
        output_ctr        <= 0;
        pat_cnt           <= 0;
    end else begin
        out_valid         <= out_valid_n;
        out_sad           <= out_sad_n;
        img_ctr           <= img_ctr_n;
        L0_addr           <= L0_addr_n;
        L1_addr           <= L1_addr_n;
        L0_din            <= L0_din_n;
        L1_din            <= L1_din_n;
        L0_web            <= L0_web_n;
        L1_web            <= L1_web_n;
        Fx                <= Fx_n;
        Fy                <= Fy_n;
        X                 <= X_n;
        Y                 <= Y_n;
        inst_ctr          <= inst_ctr_n;
        fetch_ctr         <= fetch_ctr_n;
        row_idx           <= row_idx_n;
        PointL            <= PointL_n;
        x_idx             <= x_idx_n;
        y_idx             <= y_idx_n;
        satd_cnt          <= satd_cnt_n;
        SATD_SUM          <= SATD_SUM_n;
        BEST_SUM          <= BEST_SUM_n;
        BEST_POINT        <= BEST_POINT_n;
        output_ctr        <= output_ctr_n;
        pat_cnt           <= pat_cnt_n;
    end
end

// COMBINATIONAL
always @(*) begin
    out_valid_n   = 0;
    out_sad_n     = 0;
    img_ctr_n     = img_ctr;
    inst_ctr_n    = inst_ctr;
    fetch_ctr_n   = fetch_ctr;
    L0_addr_n     = L0_addr;
    L1_addr_n     = L1_addr;
    L0_din_n      = L0_din;
    L1_din_n      = L1_din;
    L0_web_n      = 1;
    L1_web_n      = 1;
    Fx_n          = Fx;
    Fy_n          = Fy;
    X_n           = X;
    Y_n           = Y;
    fetch_addr    = 0;
    ROW_n         = ROW;
    row_idx_n     = row_idx;
    PointL_n      = PointL;
    D_n           = D;
    D2_n          = D2;
    D3_n          = D3;
    x_idx_n       = x_idx;
    y_idx_n       = y_idx;
    satd_cnt_n    = satd_cnt;
    SATD_SUM_n    = SATD_SUM;
    BEST_SUM_n    = BEST_SUM;
    BEST_POINT_n  = BEST_POINT;
    output_ctr_n  = output_ctr;
    pat_cnt_n     = pat_cnt;

    for(i = 0; i < 10; i = i + 1) begin
        for(j = 0; j < 10; j = j + 1) begin
            for(k = 0; k < 2; k = k + 1) begin
                BUF_n[k][i][j] = BUF[k][i][j];
            end
        end
    end
    VER_n         = VER;
    for(i = 0; i < 10; i = i + 1) begin
        for(j = 0; j < 6; j = j + 1) begin
            interp_in[i][j] = 0;
        end
    end
    if(cs == IDLE) begin
        img_ctr_n = 0;
        fetch_ctr_n = 0;
        if(in_valid) begin
            img_ctr_n = 1;
            L0_din_n = {120'b0, in_data[8:1]};
        end
    end

    if(cs == IN_IMG) begin
        img_ctr_n = img_ctr + 1;
        if(img_ctr[4] == 0) begin
            case (img_ctr[3:0])
                 0: begin
                    L0_din_n[ 7: 0] = in_data[8:1];
                end
                 1: begin
                    L0_din_n[15: 8] = in_data[8:1];
                end
                 2: begin
                    L0_din_n[23:16] = in_data[8:1];
                end
                 3: begin
                    L0_din_n[31:24] = in_data[8:1];
                end
                 4: begin
                    L0_din_n[39:32] = in_data[8:1];
                end
                 5: begin
                    L0_din_n[47:40] = in_data[8:1];
                end
                 6: begin
                    L0_din_n[55:48] = in_data[8:1];
                end
                 7: begin
                    L0_din_n[63:56] = in_data[8:1];
                end
                 8: begin
                    L0_din_n[71:64] = in_data[8:1];
                end
                 9: begin
                    L0_din_n[79:72] = in_data[8:1];
                end
                10: begin
                    L0_din_n[87:80] = in_data[8:1];
                end
                11: begin
                    L0_din_n[95:88] = in_data[8:1];
                end
                12: begin
                    L0_din_n[103:96] = in_data[8:1];
                end
                13: begin
                    L0_din_n[111:104] = in_data[8:1];
                end
                14: begin
                    L0_din_n[119:112] = in_data[8:1];
                end
                15: begin
                    L0_din_n[127:120] = in_data[8:1];
                    L0_web_n          = 0;
                    L0_addr_n         = img_ctr[14:5];
                end
            endcase
        end else begin
            case (img_ctr[3:0])
                 0: begin
                    L1_din_n[ 7: 0] = in_data[8:1];
                end
                 1: begin
                    L1_din_n[15: 8] = in_data[8:1];
                end
                 2: begin
                    L1_din_n[23:16] = in_data[8:1];
                end
                 3: begin
                    L1_din_n[31:24] = in_data[8:1];
                end
                 4: begin
                    L1_din_n[39:32] = in_data[8:1];
                end
                 5: begin
                    L1_din_n[47:40] = in_data[8:1];
                end
                 6: begin
                    L1_din_n[55:48] = in_data[8:1];
                end
                 7: begin
                    L1_din_n[63:56] = in_data[8:1];
                end
                 8: begin
                    L1_din_n[71:64] = in_data[8:1];
                end
                 9: begin
                    L1_din_n[79:72] = in_data[8:1];
                end
                10: begin
                    L1_din_n[87:80] = in_data[8:1];
                end
                11: begin
                    L1_din_n[95:88] = in_data[8:1];
                end
                12: begin
                    L1_din_n[103:96] = in_data[8:1];
                end
                13: begin
                    L1_din_n[111:104] = in_data[8:1];
                end
                14: begin
                    L1_din_n[119:112] = in_data[8:1];
                end
                15: begin
                    L1_din_n[127:120] = in_data[8:1];
                    L1_web_n          = 0;
                    L1_addr_n         = img_ctr[14:5];
                end
            endcase
        end
    end

    if(cs == WAIT) begin
        fetch_ctr_n  = 0;
        output_ctr_n = 0;
        inst_ctr_n   = 0;
        PointL_n     = 2'b0;
        if(in_valid2) begin
            X_n [0][0]    = in_data[8:1];
            Fx_n[0][0]    = in_data[0];
            inst_ctr_n    = 1;
            pat_cnt_n     = pat_cnt + 1;
        end
    end

    if(cs == IN_INST) begin
        inst_ctr_n = inst_ctr + 1;
        case (inst_ctr)
            1: begin
                Y_n [0][0]    = in_data[8:1];
                Fy_n[0][0]    = in_data[0];
            end
            2: begin
                X_n [0][1]    = in_data[8:1];
                Fx_n[0][1]    = in_data[0];
            end
            3: begin
                Y_n [0][1]    = in_data[8:1];
                Fy_n[0][1]    = in_data[0];
            end
            4: begin
                X_n [1][0]    = in_data[8:1];
                Fx_n[1][0]    = in_data[0];
            end
            5: begin
                Y_n [1][0]    = in_data[8:1];
                Fy_n[1][0]    = in_data[0];
            end
            6: begin
                X_n [1][1]    = in_data[8:1];
                Fx_n[1][1]    = in_data[0];
            end
            7: begin
                Y_n [1][1]    = in_data[8:1];
                Fy_n[1][1]    = in_data[0];
            end
        endcase
        if(inst_ctr == 6) begin
            row_idx_n   = Fy[0][0] ? Y[0][0] - 2 : Y[0][0];
        end
        if(inst_ctr == 7) begin
            fetch_ctr_n = 1;
            if(row_idx < 0) begin
                fetch_addr = {PointL[0], 7'b0, left_bound[6:5]};
            end else begin
                fetch_addr =  {PointL[0], row_idx[6:0], left_bound[6:5]};
            end
            if(left_bound[4]) begin
                //SRAM 1 first
                L1_addr_n = fetch_addr;
                L0_addr_n = fetch_addr + 1;
            end else begin
                //SRAM 0 first
                L0_addr_n = fetch_addr;
                L1_addr_n = fetch_addr;
            end
            row_idx_n = row_idx + 1;
        end
    end

    if(cs == FETCH) begin
        inst_ctr_n  = 0;
        fetch_ctr_n = fetch_ctr + 1;
        row_idx_n = row_idx + 1;
        if(row_idx < 0) begin
            fetch_addr =  {PointL[0], 7'b0, left_bound[6:5]};
        end else if(row_idx > 127) begin
            fetch_addr =  {PointL[0], 7'b1111111, left_bound[6:5]};
        end else begin
            fetch_addr =  {PointL[0], row_idx[6:0], left_bound[6:5]};
        end
        if(left_bound[4]) begin
            //SRAM 1 first
            L1_addr_n = fetch_addr;
            L0_addr_n = fetch_addr + 1;
        end else begin
            //SRAM 0 first
            L0_addr_n = fetch_addr;
            L1_addr_n = fetch_addr;
        end
        for(i = 0; i < 9; i = i + 1) begin
            BUF_n[PointL[0]][i] = BUF[PointL[0]][i+1];
        end
        
        case ({Fx[PointL[1]][PointL[0]], Fy[PointL[1]][PointL[0]]})
            2'b00: begin // do nothing
                if(fetch_ctr >= 2 && fetch_ctr < 12) begin
                    if(X[PointL[1]][PointL[0]] == 0) begin
                        BUF_n[PointL[0]][9][0] =    fetch_bus[  7:  0];
                        BUF_n[PointL[0]][9][1] =    fetch_bus[ 15:  8];
                        BUF_n[PointL[0]][9][2] =    fetch_bus[ 23: 16];
                        BUF_n[PointL[0]][9][3] =    fetch_bus[ 31: 24];
                        BUF_n[PointL[0]][9][4] =    fetch_bus[ 39: 32];
                        BUF_n[PointL[0]][9][5] =    fetch_bus[ 47: 40];
                        BUF_n[PointL[0]][9][6] =    fetch_bus[ 55: 48];
                        BUF_n[PointL[0]][9][7] =    fetch_bus[ 63: 56];
                        BUF_n[PointL[0]][9][8] =    fetch_bus[ 71: 64];
                        BUF_n[PointL[0]][9][9] =    fetch_bus[ 79: 72];
                    end else if(X[PointL[1]][PointL[0]] == 1) begin
                        BUF_n[PointL[0]][9][0] =    fetch_bus[ 15:  8];
                        BUF_n[PointL[0]][9][1] =    fetch_bus[ 23: 16];
                        BUF_n[PointL[0]][9][2] =    fetch_bus[ 31: 24];
                        BUF_n[PointL[0]][9][3] =    fetch_bus[ 39: 32];
                        BUF_n[PointL[0]][9][4] =    fetch_bus[ 47: 40];
                        BUF_n[PointL[0]][9][5] =    fetch_bus[ 55: 48];
                        BUF_n[PointL[0]][9][6] =    fetch_bus[ 63: 56];
                        BUF_n[PointL[0]][9][7] =    fetch_bus[ 71: 64];
                        BUF_n[PointL[0]][9][8] =    fetch_bus[ 79: 72];
                        BUF_n[PointL[0]][9][9] =    fetch_bus[ 87: 80];
                    end else begin
                        BUF_n[PointL[0]][9][0] =    left_bound >=126 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 16 +: 8];
                        BUF_n[PointL[0]][9][1] =    left_bound >=125 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 24 +: 8];
                        BUF_n[PointL[0]][9][2] =    left_bound >=124 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 32 +: 8];
                        BUF_n[PointL[0]][9][3] =    left_bound >=123 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 40 +: 8];
                        BUF_n[PointL[0]][9][4] =    left_bound >=122 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 48 +: 8];
                        BUF_n[PointL[0]][9][5] =    left_bound >=121 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 56 +: 8];
                        BUF_n[PointL[0]][9][6] =    left_bound >=120 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 64 +: 8];
                        BUF_n[PointL[0]][9][7] =    left_bound >=119 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 72 +: 8];
                        BUF_n[PointL[0]][9][8] =    left_bound >=118 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 80 +: 8];
                        BUF_n[PointL[0]][9][9] =    left_bound >=117 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 88 +: 8];
                    end
                end
                if(fetch_ctr == 11) begin
                    fetch_ctr_n = 0;
                    //PointL_n = PointL + 1;
                end
            end
            2'b01: begin // vertical
                if(fetch_ctr >= 2 && fetch_ctr < 17) begin
                    if(X[PointL[1]][PointL[0]] == 0) begin
                        VER_n[5][0] =    fetch_bus[  7:  0];
                        VER_n[5][1] =    fetch_bus[ 15:  8];
                        VER_n[5][2] =    fetch_bus[ 23: 16];
                        VER_n[5][3] =    fetch_bus[ 31: 24];
                        VER_n[5][4] =    fetch_bus[ 39: 32];
                        VER_n[5][5] =    fetch_bus[ 47: 40];
                        VER_n[5][6] =    fetch_bus[ 55: 48];
                        VER_n[5][7] =    fetch_bus[ 63: 56];
                        VER_n[5][8] =    fetch_bus[ 71: 64];
                        VER_n[5][9] =    fetch_bus[ 79: 72];
                    end else if(X[PointL[1]][PointL[0]] == 1) begin
                        VER_n[5][0] =    fetch_bus[ 15:  8];
                        VER_n[5][1] =    fetch_bus[ 23: 16];
                        VER_n[5][2] =    fetch_bus[ 31: 24];
                        VER_n[5][3] =    fetch_bus[ 39: 32];
                        VER_n[5][4] =    fetch_bus[ 47: 40];
                        VER_n[5][5] =    fetch_bus[ 55: 48];
                        VER_n[5][6] =    fetch_bus[ 63: 56];
                        VER_n[5][7] =    fetch_bus[ 71: 64];
                        VER_n[5][8] =    fetch_bus[ 79: 72];
                        VER_n[5][9] =    fetch_bus[ 87: 80];
                    end else begin
                        VER_n[5][0] =    left_bound >=126 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 16 +: 8];
                        VER_n[5][1] =    left_bound >=125 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 24 +: 8];
                        VER_n[5][2] =    left_bound >=124 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 32 +: 8];
                        VER_n[5][3] =    left_bound >=123 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 40 +: 8];
                        VER_n[5][4] =    left_bound >=122 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 48 +: 8];
                        VER_n[5][5] =    left_bound >=121 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 56 +: 8];
                        VER_n[5][6] =    left_bound >=120 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 64 +: 8];
                        VER_n[5][7] =    left_bound >=119 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 72 +: 8];
                        VER_n[5][8] =    left_bound >=118 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 80 +: 8];
                        VER_n[5][9] =    left_bound >=117 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 88 +: 8];
                    end
                    for(i = 0; i < 5; i = i + 1) begin
                        VER_n[i] = VER[i+1];
                    end
                end
                if(fetch_ctr >= 8 && fetch_ctr < 18) begin
                    for(i = 0; i < 10; i = i + 1) begin
                        for(j = 0; j < 6; j = j + 1) begin
                            interp_in[i][j] = VER[j][i];
                        end
                        BUF_n[PointL[0]][9][i] = ((interp_out[i] + 16) >>> 5) > 255? 255 : ((interp_out[i] + 16) >>> 5) < 0 ? 0 : ((interp_out[i] + 16) >>> 5);
                    end
                end
                if(fetch_ctr == 17) begin
                    fetch_ctr_n = 0;
                    //PointL_n = PointL + 1;
                end
            end
            2'b10: begin // horizontal
                if(fetch_ctr >= 2 && fetch_ctr < 12) begin
                    if(X[PointL[1]][PointL[0]] == 0) begin
                        ROW_n[ 0] = fetch_bus[  7:  0];
                        ROW_n[ 1] = fetch_bus[  7:  0];
                        ROW_n[ 2] = fetch_bus[  7:  0];
                        ROW_n[ 3] = fetch_bus[ 15:  8];
                        ROW_n[ 4] = fetch_bus[ 23: 16];
                        ROW_n[ 5] = fetch_bus[ 31: 24];
                        ROW_n[ 6] = fetch_bus[ 39: 32];
                        ROW_n[ 7] = fetch_bus[ 47: 40];
                        ROW_n[ 8] = fetch_bus[ 55: 48];
                        ROW_n[ 9] = fetch_bus[ 63: 56];
                        ROW_n[10] = fetch_bus[ 71: 64];
                        ROW_n[11] = fetch_bus[ 79: 72];
                        ROW_n[12] = fetch_bus[ 87: 80];
                        ROW_n[13] = fetch_bus[ 95: 88];
                        ROW_n[14] = fetch_bus[103: 96];
                    end else if(X[PointL[1]][PointL[0]] == 1) begin
                        ROW_n[ 0] = fetch_bus[  7:  0];
                        ROW_n[ 1] = fetch_bus[  7:  0];
                        ROW_n[ 2] = fetch_bus[ 15:  8];
                        ROW_n[ 3] = fetch_bus[ 23: 16];
                        ROW_n[ 4] = fetch_bus[ 31: 24];
                        ROW_n[ 5] = fetch_bus[ 39: 32];
                        ROW_n[ 6] = fetch_bus[ 47: 40];
                        ROW_n[ 7] = fetch_bus[ 55: 48];
                        ROW_n[ 8] = fetch_bus[ 63: 56];
                        ROW_n[ 9] = fetch_bus[ 71: 64];
                        ROW_n[10] = fetch_bus[ 79: 72];
                        ROW_n[11] = fetch_bus[ 87: 80];
                        ROW_n[12] = fetch_bus[ 95: 88];
                        ROW_n[13] = fetch_bus[103: 96];
                        ROW_n[14] = fetch_bus[111:104];
                    end else begin
                        ROW_n[ 0] = fetch_bus[8*left_bound[3:0]       +: 8];
                        ROW_n[ 1] = fetch_bus[8*left_bound[3:0]  +  8 +: 8];
                        ROW_n[ 2] = left_bound >=126 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 16 +: 8];
                        ROW_n[ 3] = left_bound >=125 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 24 +: 8];
                        ROW_n[ 4] = left_bound >=124 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 32 +: 8];
                        ROW_n[ 5] = left_bound >=123 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 40 +: 8];
                        ROW_n[ 6] = left_bound >=122 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 48 +: 8];
                        ROW_n[ 7] = left_bound >=121 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 56 +: 8];
                        ROW_n[ 8] = left_bound >=120 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 64 +: 8];
                        ROW_n[ 9] = left_bound >=119 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 72 +: 8];
                        ROW_n[10] = left_bound >=118 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 80 +: 8];
                        ROW_n[11] = left_bound >=117 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 88 +: 8];
                        ROW_n[12] = left_bound >=116 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 96 +: 8];
                        ROW_n[13] = left_bound >=115 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] +104 +: 8];
                        ROW_n[14] = left_bound >=114 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] +112 +: 8];
                    end
                end
                if(fetch_ctr >= 3 && fetch_ctr < 13) begin
                    // interppolation
                    for(i = 0; i < 10; i = i + 1) begin
                        for(j = 0; j < 6; j = j + 1) begin
                            interp_in[i][j] = ROW[i + j];
                        end
                        BUF_n[PointL[0]][9][i] = ((interp_out[i] + 16) >>> 5) > 255? 255 : ((interp_out[i] + 16) >>> 5) < 0 ? 0 : ((interp_out[i] + 16) >>> 5);
                    end
                end
                if(fetch_ctr == 12) begin
                    fetch_ctr_n = 0;
                    //PointL_n = PointL + 1;
                end
            end
            2'b11: begin
                if(fetch_ctr >= 2 && fetch_ctr < 17) begin
                    if(X[PointL[1]][PointL[0]] == 0) begin
                        ROW_n[ 0] = fetch_bus[  7:  0];
                        ROW_n[ 1] = fetch_bus[  7:  0];
                        ROW_n[ 2] = fetch_bus[  7:  0];
                        ROW_n[ 3] = fetch_bus[ 15:  8];
                        ROW_n[ 4] = fetch_bus[ 23: 16];
                        ROW_n[ 5] = fetch_bus[ 31: 24];
                        ROW_n[ 6] = fetch_bus[ 39: 32];
                        ROW_n[ 7] = fetch_bus[ 47: 40];
                        ROW_n[ 8] = fetch_bus[ 55: 48];
                        ROW_n[ 9] = fetch_bus[ 63: 56];
                        ROW_n[10] = fetch_bus[ 71: 64];
                        ROW_n[11] = fetch_bus[ 79: 72];
                        ROW_n[12] = fetch_bus[ 87: 80];
                        ROW_n[13] = fetch_bus[ 95: 88];
                        ROW_n[14] = fetch_bus[103: 96];
                    end else if(X[PointL[1]][PointL[0]] == 1) begin
                        ROW_n[ 0] = fetch_bus[  7:  0];
                        ROW_n[ 1] = fetch_bus[  7:  0];
                        ROW_n[ 2] = fetch_bus[ 15:  8];
                        ROW_n[ 3] = fetch_bus[ 23: 16];
                        ROW_n[ 4] = fetch_bus[ 31: 24];
                        ROW_n[ 5] = fetch_bus[ 39: 32];
                        ROW_n[ 6] = fetch_bus[ 47: 40];
                        ROW_n[ 7] = fetch_bus[ 55: 48];
                        ROW_n[ 8] = fetch_bus[ 63: 56];
                        ROW_n[ 9] = fetch_bus[ 71: 64];
                        ROW_n[10] = fetch_bus[ 79: 72];
                        ROW_n[11] = fetch_bus[ 87: 80];
                        ROW_n[12] = fetch_bus[ 95: 88];
                        ROW_n[13] = fetch_bus[103: 96];
                        ROW_n[14] = fetch_bus[111:104];
                    end else begin
                        ROW_n[ 0] = fetch_bus[8*left_bound[3:0]       +: 8];
                        ROW_n[ 1] = fetch_bus[8*left_bound[3:0]  +  8 +: 8];
                        ROW_n[ 2] = left_bound >=126 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 16 +: 8];
                        ROW_n[ 3] = left_bound >=125 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 24 +: 8];
                        ROW_n[ 4] = left_bound >=124 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 32 +: 8];
                        ROW_n[ 5] = left_bound >=123 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 40 +: 8];
                        ROW_n[ 6] = left_bound >=122 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 48 +: 8];
                        ROW_n[ 7] = left_bound >=121 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 56 +: 8];
                        ROW_n[ 8] = left_bound >=120 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 64 +: 8];
                        ROW_n[ 9] = left_bound >=119 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 72 +: 8];
                        ROW_n[10] = left_bound >=118 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 80 +: 8];
                        ROW_n[11] = left_bound >=117 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 88 +: 8];
                        ROW_n[12] = left_bound >=116 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] + 96 +: 8];
                        ROW_n[13] = left_bound >=115 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] +104 +: 8];
                        ROW_n[14] = left_bound >=114 ?  fetch_bus[127:120] : fetch_bus[8*left_bound[3:0] +112 +: 8];
                    end
                end
                if(fetch_ctr >= 3 && fetch_ctr < 18) begin
                    // interppolation
                    for(i = 0; i < 10; i = i + 1) begin
                        for(j = 0; j < 6; j = j + 1) begin
                            interp_in[i][j] = ROW[i + j];
                        end
                        BUF_n[PointL[0]][9][i] = interp_out[i];
                    end
                    VER_n[5]    = BUF[PointL[0]][0];
                    for(i = 0; i < 5; i = i + 1) begin
                        VER_n[i] = VER[i+1];
                    end
                end

                if(fetch_ctr >= 18 && fetch_ctr < 28) begin
                    for(i = 0; i < 10; i = i + 1) begin
                        for(j = 0; j < 5; j = j + 1) begin
                            interp_in[i][j] = VER[j+1][i];
                        end
                        interp_in[i][5] = BUF[PointL[0]][0][i];
                        BUF_n[PointL[0]][9][i] = ((interp_out[i] + 512) >>> 10) > 255 ? 255 : ((interp_out[i] + 512) >>> 10) < 0 ? 0 : ((interp_out[i] + 512) >>> 10);
                    end
                    VER_n[5]    = BUF[PointL[0]][0];
                    for(i = 0; i < 5; i = i + 1) begin
                        VER_n[i] = VER[i+1];
                    end
                end
                if(fetch_ctr == 27) begin
                    fetch_ctr_n = 0;
                    //PointL_n = PointL + 1;
                end
            end
        endcase
    end

    if(cs == ARBITRATION) begin
        satd_cnt_n = 0;
        SATD_SUM_n = 0;
        if(inst_ctr == 0) begin
            inst_ctr_n  = 1;
            //if(row_idx < 0) begin
            //    fetch_addr = {PointL[1], 7'b0, left_bound[6:5]};
            //end else begin
            //    fetch_addr =  {PointL[1], row_idx[6:0], left_bound[6:5]};
            //end
            PointL_n   = PointL + 1;
            row_idx_n   = Fy[PointL_n[1]][PointL_n[0]] ? Y[PointL_n[1]][PointL_n[0]] - 2 : Y[PointL_n[1]][PointL_n[0]];
        end
        if(inst_ctr == 1) begin
            fetch_ctr_n = 1;
            if(row_idx < 0) begin
                fetch_addr = {PointL[0], 7'b0, left_bound[6:5]};
            end else begin
                fetch_addr =  {PointL[0], row_idx[6:0], left_bound[6:5]};
            end
            if(left_bound[4]) begin
                //SRAM 1 first
                L1_addr_n = fetch_addr;
                L0_addr_n = fetch_addr + 1;
            end else begin
                //SRAM 0 first
                L0_addr_n = fetch_addr;
                L1_addr_n = fetch_addr;
            end
            row_idx_n = row_idx + 1;
        end
    end

    if(cs == SATD) begin
        inst_ctr_n = 0;
        satd_cnt_n = satd_cnt + 1;
        if(satd_cnt == 0) BEST_SUM_n[~PointL[1]] = 24'b111111111111111111111111;
        case (satd_cnt[5:2])
            0: begin
                x_idx_n[0] = 0 + (satd_cnt[0] << 2);
                y_idx_n[0] = 0 + (satd_cnt[1] << 2);
                x_idx_n[1] = 2 + (satd_cnt[0] << 2);
                y_idx_n[1] = 2 + (satd_cnt[1] << 2);
            end
            1: begin
                x_idx_n[0] = 0 + (satd_cnt[0] << 2);
                y_idx_n[0] = 1 + (satd_cnt[1] << 2);
                x_idx_n[1] = 2 + (satd_cnt[0] << 2);
                y_idx_n[1] = 1 + (satd_cnt[1] << 2);
            end
            2: begin
                x_idx_n[0] = 0 + (satd_cnt[0] << 2);
                y_idx_n[0] = 2 + (satd_cnt[1] << 2);
                x_idx_n[1] = 2 + (satd_cnt[0] << 2);
                y_idx_n[1] = 0 + (satd_cnt[1] << 2);
            end 
            3: begin
                x_idx_n[0] = 1 + (satd_cnt[0] << 2);
                y_idx_n[0] = 0 + (satd_cnt[1] << 2);
                x_idx_n[1] = 1 + (satd_cnt[0] << 2);
                y_idx_n[1] = 2 + (satd_cnt[1] << 2);
            end 
            4: begin
                x_idx_n[0] = 1 + (satd_cnt[0] << 2);
                y_idx_n[0] = 1 + (satd_cnt[1] << 2);
                x_idx_n[1] = 1 + (satd_cnt[0] << 2);
                y_idx_n[1] = 1 + (satd_cnt[1] << 2);
            end 
            5: begin
                x_idx_n[0] = 1 + (satd_cnt[0] << 2);
                y_idx_n[0] = 2 + (satd_cnt[1] << 2);
                x_idx_n[1] = 1 + (satd_cnt[0] << 2);
                y_idx_n[1] = 0 + (satd_cnt[1] << 2);
            end 
            6: begin
                x_idx_n[0] = 2 + (satd_cnt[0] << 2);
                y_idx_n[0] = 0 + (satd_cnt[1] << 2);
                x_idx_n[1] = 0 + (satd_cnt[0] << 2);
                y_idx_n[1] = 2 + (satd_cnt[1] << 2);
            end 
            7: begin
                x_idx_n[0] = 2 + (satd_cnt[0] << 2);
                y_idx_n[0] = 1 + (satd_cnt[1] << 2);
                x_idx_n[1] = 0 + (satd_cnt[0] << 2);
                y_idx_n[1] = 1 + (satd_cnt[1] << 2);
            end 
            8: begin
                x_idx_n[0] = 2 + (satd_cnt[0] << 2);
                y_idx_n[0] = 2 + (satd_cnt[1] << 2);
                x_idx_n[1] = 0 + (satd_cnt[0] << 2);
                y_idx_n[1] = 0 + (satd_cnt[1] << 2);
            end  
        endcase
        // PIPE 1
        for(i = 0; i < 4; i = i + 1) begin
            for(j = 0; j < 4; j = j + 1) begin
                D_n[i][j] = BUF[0][y_idx[0] + i][x_idx[0] + j] - BUF[1][y_idx[1] + i][x_idx[1] + j];
            end
        end

        // PIPE 2
        D2_n[0][0] = D[0][0] + D[1][0] + D[2][0] + D[3][0];
        D2_n[0][1] = D[0][1] + D[1][1] + D[2][1] + D[3][1];
        D2_n[0][2] = D[0][2] + D[1][2] + D[2][2] + D[3][2];
        D2_n[0][3] = D[0][3] + D[1][3] + D[2][3] + D[3][3];
        D2_n[1][0] = D[0][0] - D[1][0] + D[2][0] - D[3][0];
        D2_n[1][1] = D[0][1] - D[1][1] + D[2][1] - D[3][1];
        D2_n[1][2] = D[0][2] - D[1][2] + D[2][2] - D[3][2];
        D2_n[1][3] = D[0][3] - D[1][3] + D[2][3] - D[3][3];
        D2_n[2][0] = D[0][0] + D[1][0] - D[2][0] - D[3][0];
        D2_n[2][1] = D[0][1] + D[1][1] - D[2][1] - D[3][1];
        D2_n[2][2] = D[0][2] + D[1][2] - D[2][2] - D[3][2];
        D2_n[2][3] = D[0][3] + D[1][3] - D[2][3] - D[3][3];
        D2_n[3][0] = D[0][0] - D[1][0] - D[2][0] + D[3][0];
        D2_n[3][1] = D[0][1] - D[1][1] - D[2][1] + D[3][1];
        D2_n[3][2] = D[0][2] - D[1][2] - D[2][2] + D[3][2];
        D2_n[3][3] = D[0][3] - D[1][3] - D[2][3] + D[3][3];

        // PIPE 3
        D3_n[0][0] = D2[0][0] + D2[0][1] + D2[0][2] + D2[0][3];
        D3_n[0][1] = D2[0][0] - D2[0][1] + D2[0][2] - D2[0][3];
        D3_n[0][2] = D2[0][0] + D2[0][1] - D2[0][2] - D2[0][3];
        D3_n[0][3] = D2[0][0] - D2[0][1] - D2[0][2] + D2[0][3];
        D3_n[1][0] = D2[1][0] + D2[1][1] + D2[1][2] + D2[1][3];
        D3_n[1][1] = D2[1][0] - D2[1][1] + D2[1][2] - D2[1][3];
        D3_n[1][2] = D2[1][0] + D2[1][1] - D2[1][2] - D2[1][3];
        D3_n[1][3] = D2[1][0] - D2[1][1] - D2[1][2] + D2[1][3];
        D3_n[2][0] = D2[2][0] + D2[2][1] + D2[2][2] + D2[2][3];
        D3_n[2][1] = D2[2][0] - D2[2][1] + D2[2][2] - D2[2][3];
        D3_n[2][2] = D2[2][0] + D2[2][1] - D2[2][2] - D2[2][3];
        D3_n[2][3] = D2[2][0] - D2[2][1] - D2[2][2] + D2[2][3];
        D3_n[3][0] = D2[3][0] + D2[3][1] + D2[3][2] + D2[3][3];
        D3_n[3][1] = D2[3][0] - D2[3][1] + D2[3][2] - D2[3][3];
        D3_n[3][2] = D2[3][0] + D2[3][1] - D2[3][2] - D2[3][3];
        D3_n[3][3] = D2[3][0] - D2[3][1] - D2[3][2] + D2[3][3];

        for(i = 0; i < 4; i = i + 1) begin
            for(j = 0; j < 4; j = j + 1) begin
                D3_abs[i][j] = D3[i][j] >= 0 ? D3[i][j] : -D3[i][j];
            end
        end

        // PIPE 4
        if(satd_cnt >= 4) begin        
            SATD_SUM_n = SATD_SUM + D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                                  + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                                  + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                                  + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  8) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 0;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  12) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 1;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  16) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 2;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  20) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 3;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  24) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 4;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  28) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 5;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  32) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 6;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  36) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 7;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end
        if(satd_cnt ==  40) begin
                if(SATD_SUM < BEST_SUM[~PointL[1]]) begin
                    BEST_SUM_n[~PointL[1]] = SATD_SUM;
                    BEST_POINT_n[~PointL[1]] = 8;
                end
                SATD_SUM_n =  D3_abs[0][0] + D3_abs[0][1] + D3_abs[0][2] + D3_abs[0][3]
                            + D3_abs[1][0] + D3_abs[1][1] + D3_abs[1][2] + D3_abs[1][3]
                            + D3_abs[2][0] + D3_abs[2][1] + D3_abs[2][2] + D3_abs[2][3]
                            + D3_abs[3][0] + D3_abs[3][1] + D3_abs[3][2] + D3_abs[3][3];
        end

        //this is for point 2 to pre fetch the data.

        if(PointL[1] == 0 && satd_cnt >= 13) begin //pre output point 1 result.
            out_valid_n = 1;
            out_sad_n   = BEST_SUM[0][0];
            for(i = 0; i < 23; i = i + 1) begin
                BEST_SUM_n[0][i]   = BEST_SUM[0][i+1];
            end
            BEST_SUM_n[0][23] = BEST_POINT[0][0];
            for(i = 0; i < 3; i = i + 1) begin
                BEST_POINT_n[0][i] = BEST_POINT[0][i+1];
            end
            BEST_POINT_n[0][3] = 0;
        end
    end

    if(cs == OUTPUT) begin
        output_ctr_n = output_ctr + 1;
        out_valid_n = 1;
        out_sad_n   = BEST_SUM[1][0];
        for(i = 0; i < 23; i = i + 1) begin
            BEST_SUM_n[1][i]   = BEST_SUM[1][i+1];
        end
        BEST_SUM_n[1][23] = BEST_POINT[1][0];
        for(i = 0; i < 3; i = i + 1) begin
            BEST_POINT_n[1][i] = BEST_POINT[1][i+1];
        end
        BEST_POINT_n[1][3] = 0;
    end
end 



endmodule


module IMG (
    input  [9:0]  A,      // A0~A8
    input  [127:0] DI,    // DI0~DI127
    output [127:0] DO,    // DO0~DO127
    input          CK,
    input          WEB
);

    wire OE = 1'b1;
    wire CS = 1'b1;

    IMG_MEM u_mem (
        // Address
        .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .A4(A[4]),
        .A5(A[5]), .A6(A[6]), .A7(A[7]), .A8(A[8]), .A9(A[9]),

        // Data Output
        .DO0(DO[0]),   .DO1(DO[1]),   .DO2(DO[2]),   .DO3(DO[3]),
        .DO4(DO[4]),   .DO5(DO[5]),   .DO6(DO[6]),   .DO7(DO[7]),
        .DO8(DO[8]),   .DO9(DO[9]),   .DO10(DO[10]), .DO11(DO[11]),
        .DO12(DO[12]), .DO13(DO[13]), .DO14(DO[14]), .DO15(DO[15]),
        .DO16(DO[16]), .DO17(DO[17]), .DO18(DO[18]), .DO19(DO[19]),
        .DO20(DO[20]), .DO21(DO[21]), .DO22(DO[22]), .DO23(DO[23]),
        .DO24(DO[24]), .DO25(DO[25]), .DO26(DO[26]), .DO27(DO[27]),
        .DO28(DO[28]), .DO29(DO[29]), .DO30(DO[30]), .DO31(DO[31]),
        .DO32(DO[32]), .DO33(DO[33]), .DO34(DO[34]), .DO35(DO[35]),
        .DO36(DO[36]), .DO37(DO[37]), .DO38(DO[38]), .DO39(DO[39]),
        .DO40(DO[40]), .DO41(DO[41]), .DO42(DO[42]), .DO43(DO[43]),
        .DO44(DO[44]), .DO45(DO[45]), .DO46(DO[46]), .DO47(DO[47]),
        .DO48(DO[48]), .DO49(DO[49]), .DO50(DO[50]), .DO51(DO[51]),
        .DO52(DO[52]), .DO53(DO[53]), .DO54(DO[54]), .DO55(DO[55]),
        .DO56(DO[56]), .DO57(DO[57]), .DO58(DO[58]), .DO59(DO[59]),
        .DO60(DO[60]), .DO61(DO[61]), .DO62(DO[62]), .DO63(DO[63]),
        .DO64(DO[64]), .DO65(DO[65]), .DO66(DO[66]), .DO67(DO[67]),
        .DO68(DO[68]), .DO69(DO[69]), .DO70(DO[70]), .DO71(DO[71]),
        .DO72(DO[72]), .DO73(DO[73]), .DO74(DO[74]), .DO75(DO[75]),
        .DO76(DO[76]), .DO77(DO[77]), .DO78(DO[78]), .DO79(DO[79]),
        .DO80(DO[80]), .DO81(DO[81]), .DO82(DO[82]), .DO83(DO[83]),
        .DO84(DO[84]), .DO85(DO[85]), .DO86(DO[86]), .DO87(DO[87]),
        .DO88(DO[88]), .DO89(DO[89]), .DO90(DO[90]), .DO91(DO[91]),
        .DO92(DO[92]), .DO93(DO[93]), .DO94(DO[94]), .DO95(DO[95]),
        .DO96(DO[96]), .DO97(DO[97]), .DO98(DO[98]), .DO99(DO[99]),
        .DO100(DO[100]), .DO101(DO[101]), .DO102(DO[102]), .DO103(DO[103]),
        .DO104(DO[104]), .DO105(DO[105]), .DO106(DO[106]), .DO107(DO[107]),
        .DO108(DO[108]), .DO109(DO[109]), .DO110(DO[110]), .DO111(DO[111]),
        .DO112(DO[112]), .DO113(DO[113]), .DO114(DO[114]), .DO115(DO[115]),
        .DO116(DO[116]), .DO117(DO[117]), .DO118(DO[118]), .DO119(DO[119]),
        .DO120(DO[120]), .DO121(DO[121]), .DO122(DO[122]), .DO123(DO[123]),
        .DO124(DO[124]), .DO125(DO[125]), .DO126(DO[126]), .DO127(DO[127]),

        // Data Input
        .DI0(DI[0]),   .DI1(DI[1]),   .DI2(DI[2]),   .DI3(DI[3]),
        .DI4(DI[4]),   .DI5(DI[5]),   .DI6(DI[6]),   .DI7(DI[7]),
        .DI8(DI[8]),   .DI9(DI[9]),   .DI10(DI[10]), .DI11(DI[11]),
        .DI12(DI[12]), .DI13(DI[13]), .DI14(DI[14]), .DI15(DI[15]),
        .DI16(DI[16]), .DI17(DI[17]), .DI18(DI[18]), .DI19(DI[19]),
        .DI20(DI[20]), .DI21(DI[21]), .DI22(DI[22]), .DI23(DI[23]),
        .DI24(DI[24]), .DI25(DI[25]), .DI26(DI[26]), .DI27(DI[27]),
        .DI28(DI[28]), .DI29(DI[29]), .DI30(DI[30]), .DI31(DI[31]),
        .DI32(DI[32]), .DI33(DI[33]), .DI34(DI[34]), .DI35(DI[35]),
        .DI36(DI[36]), .DI37(DI[37]), .DI38(DI[38]), .DI39(DI[39]),
        .DI40(DI[40]), .DI41(DI[41]), .DI42(DI[42]), .DI43(DI[43]),
        .DI44(DI[44]), .DI45(DI[45]), .DI46(DI[46]), .DI47(DI[47]),
        .DI48(DI[48]), .DI49(DI[49]), .DI50(DI[50]), .DI51(DI[51]),
        .DI52(DI[52]), .DI53(DI[53]), .DI54(DI[54]), .DI55(DI[55]),
        .DI56(DI[56]), .DI57(DI[57]), .DI58(DI[58]), .DI59(DI[59]),
        .DI60(DI[60]), .DI61(DI[61]), .DI62(DI[62]), .DI63(DI[63]),
        .DI64(DI[64]), .DI65(DI[65]), .DI66(DI[66]), .DI67(DI[67]),
        .DI68(DI[68]), .DI69(DI[69]), .DI70(DI[70]), .DI71(DI[71]),
        .DI72(DI[72]), .DI73(DI[73]), .DI74(DI[74]), .DI75(DI[75]),
        .DI76(DI[76]), .DI77(DI[77]), .DI78(DI[78]), .DI79(DI[79]),
        .DI80(DI[80]), .DI81(DI[81]), .DI82(DI[82]), .DI83(DI[83]),
        .DI84(DI[84]), .DI85(DI[85]), .DI86(DI[86]), .DI87(DI[87]),
        .DI88(DI[88]), .DI89(DI[89]), .DI90(DI[90]), .DI91(DI[91]),
        .DI92(DI[92]), .DI93(DI[93]), .DI94(DI[94]), .DI95(DI[95]),
        .DI96(DI[96]), .DI97(DI[97]), .DI98(DI[98]), .DI99(DI[99]),
        .DI100(DI[100]), .DI101(DI[101]), .DI102(DI[102]), .DI103(DI[103]),
        .DI104(DI[104]), .DI105(DI[105]), .DI106(DI[106]), .DI107(DI[107]),
        .DI108(DI[108]), .DI109(DI[109]), .DI110(DI[110]), .DI111(DI[111]),
        .DI112(DI[112]), .DI113(DI[113]), .DI114(DI[114]), .DI115(DI[115]),
        .DI116(DI[116]), .DI117(DI[117]), .DI118(DI[118]), .DI119(DI[119]),
        .DI120(DI[120]), .DI121(DI[121]), .DI122(DI[122]), .DI123(DI[123]),
        .DI124(DI[124]), .DI125(DI[125]), .DI126(DI[126]), .DI127(DI[127]),

        .CK(CK),
        .WEB(WEB),
        .OE(OE),
        .CS(CS)
    );

endmodule

module INTERP (
    input  reg signed [20:0] IN0,
    input  reg signed [20:0] IN1,
    input  reg signed [20:0] IN2,
    input  reg signed [20:0] IN3,
    input  reg signed [20:0] IN4,
    input  reg signed [20:0] IN5,
    output reg signed [20:0] OUT
);

always @(*) begin
    OUT =
          IN0
        - ((IN1 << 2) + IN1)         
        + ((IN2 << 4) + (IN2 << 2))
        + ((IN3 << 4) + (IN3 << 2))
        - ((IN4 << 2) + IN4)         
        + IN5;
end
    
endmodule
