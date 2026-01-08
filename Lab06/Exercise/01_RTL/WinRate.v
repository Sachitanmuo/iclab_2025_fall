//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : WinRate.v
//   	Module Name : WinRate
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`include "Poker.v"

module WinRate (
    // Input signals
    clk,
	rst_n,
	in_valid,
    in_hole_num,
    in_hole_suit,
    in_pub_num,
    in_pub_suit,
    out_valid,
    out_win_rate
);
// ===============================================================
// Input & Output
// ===============================================================
input clk;
input rst_n;
input in_valid;
input [71:0] in_hole_num;
input [35:0] in_hole_suit;
input [11:0] in_pub_num;
input [5:0]  in_pub_suit;

output reg out_valid;
output reg [62:0] out_win_rate;

// ===============================================================
// Parameter
// ===============================================================
parameter IDLE      = 2'd0,
          CT        = 2'd1,
          CALC      = 2'd2,
          OUTPUT    = 2'd3;

integer i, j;
// ===============================================================
// Reg & Wire
// ===============================================================
reg [1:0] cs, ns;
reg [3:0] HOLE_NUM    [0:8][0:1];
reg [1:0] HOLE_SUIT   [0:8][0:1];
reg [3:0] PUB_NUM     [0:4];
reg [1:0] PUB_SUIT    [0:4];
reg [3:0] HOLE_NUM_n  [0:8][0:1];
reg [1:0] HOLE_SUIT_n [0:8][0:1];
reg [3:0] PUB_NUM_n   [0:4];
reg [1:0] PUB_SUIT_n  [0:4];

reg [ 8:0] OUT_WINNER_reg;
reg [ 8:0] OUT_WINNER;
reg [ 8:0] OUT_WINNER_n;
reg        out_valid_n;
reg [62:0] out_win_rate_n;

reg [51:0] card_set;
reg [51:0] card_set_n;
reg [ 5:0] card_set_head;
reg [ 5:0] card_set_head_n;
reg [51:0] filtered;
reg [51:0] filtered_n;
reg [ 5:0] filtered_head;
reg [ 5:0] filtered_head_n;

reg [63:0] encode_oh;
reg [ 9:0] calc_ctr;
reg [ 9:0] calc_ctr_n; 
reg        calc_done;
reg [ 6:0] score            [0:8];
reg [ 6:0] score_n          [0:8];
reg [ 6:0] score_buffer     [0:8];
reg [ 6:0] score_buffer_n   [0:8];
reg [ 3:0] mod_9     [0:8];
reg [ 3:0] mod_9_n   [0:8];
reg [ 3:0] winner_count;
reg [ 3:0] winner_count_n;
reg inc    [0:8];

wire [71:0] hole_num_bus;
wire [35:0] hole_suit_bus;
wire [19:0] pub_num_bus;
wire [ 9:0] pub_suit_bus;


reg debug, debug1;
assign debug  = &filtered_n;
assign debug1 = &card_set_n;

genvar gi;
generate
  for (gi = 0; gi < 9; gi = gi + 1) begin : PACK_HOLE
    assign hole_num_bus [gi*8 +: 4]     = HOLE_NUM [gi][0];
    assign hole_num_bus [gi*8 + 4 +: 4] = HOLE_NUM [gi][1];
    assign hole_suit_bus[gi*4 +: 2]     = HOLE_SUIT[gi][0];
    assign hole_suit_bus[gi*4 + 2 +: 2] = HOLE_SUIT[gi][1];
  end
endgenerate

assign pub_num_bus   [ 0*4 +: 4] = PUB_NUM [0];
assign pub_num_bus   [ 1*4 +: 4] = PUB_NUM [1];
assign pub_num_bus   [ 2*4 +: 4] = PUB_NUM [2];
assign pub_num_bus   [ 3*4 +: 4] = PUB_NUM [3];
assign pub_num_bus   [ 4*4 +: 4] = PUB_NUM [4];

assign pub_suit_bus  [ 0*2 +: 2] = PUB_SUIT[0];
assign pub_suit_bus  [ 1*2 +: 2] = PUB_SUIT[1];
assign pub_suit_bus  [ 2*2 +: 2] = PUB_SUIT[2];
assign pub_suit_bus  [ 3*2 +: 2] = PUB_SUIT[3];
assign pub_suit_bus  [ 4*2 +: 2] = PUB_SUIT[4];


Poker #(.IP_WIDTH(9)) u_poker (
  .IN_HOLE_CARD_NUM  (hole_num_bus),
  .IN_HOLE_CARD_SUIT (hole_suit_bus),
  .IN_PUB_CARD_NUM   (pub_num_bus),
  .IN_PUB_CARD_SUIT  (pub_suit_bus),
  .OUT_WINNER        (OUT_WINNER_n)
);


function reg [5:0] oh_to_idx(input [51:0] x);
  case (x)
    // Clubs (00), 2..A
    (52'h1 <<  0): oh_to_idx = 6'b00_0010;  // C2
    (52'h1 <<  1): oh_to_idx = 6'b00_0011;  // C3
    (52'h1 <<  2): oh_to_idx = 6'b00_0100;  // C4
    (52'h1 <<  3): oh_to_idx = 6'b00_0101;  // C5
    (52'h1 <<  4): oh_to_idx = 6'b00_0110;  // C6
    (52'h1 <<  5): oh_to_idx = 6'b00_0111;  // C7
    (52'h1 <<  6): oh_to_idx = 6'b00_1000;  // C8
    (52'h1 <<  7): oh_to_idx = 6'b00_1001;  // C9
    (52'h1 <<  8): oh_to_idx = 6'b00_1010;  // C10
    (52'h1 <<  9): oh_to_idx = 6'b00_1011;  // CJ
    (52'h1 << 10): oh_to_idx = 6'b00_1100;  // CQ
    (52'h1 << 11): oh_to_idx = 6'b00_1101;  // CK
    (52'h1 << 12): oh_to_idx = 6'b00_1110;  // CA

    // Diamonds (01), 2..A
    (52'h1 << 13): oh_to_idx = 6'b01_0010;  // D2
    (52'h1 << 14): oh_to_idx = 6'b01_0011;  // D3
    (52'h1 << 15): oh_to_idx = 6'b01_0100;  // D4
    (52'h1 << 16): oh_to_idx = 6'b01_0101;  // D5
    (52'h1 << 17): oh_to_idx = 6'b01_0110;  // D6
    (52'h1 << 18): oh_to_idx = 6'b01_0111;  // D7
    (52'h1 << 19): oh_to_idx = 6'b01_1000;  // D8
    (52'h1 << 20): oh_to_idx = 6'b01_1001;  // D9
    (52'h1 << 21): oh_to_idx = 6'b01_1010;  // D10
    (52'h1 << 22): oh_to_idx = 6'b01_1011;  // DJ
    (52'h1 << 23): oh_to_idx = 6'b01_1100;  // DQ
    (52'h1 << 24): oh_to_idx = 6'b01_1101;  // DK
    (52'h1 << 25): oh_to_idx = 6'b01_1110;  // DA

    // Hearts (10), 2..A
    (52'h1 << 26): oh_to_idx = 6'b10_0010;  // H2
    (52'h1 << 27): oh_to_idx = 6'b10_0011;  // H3
    (52'h1 << 28): oh_to_idx = 6'b10_0100;  // H4
    (52'h1 << 29): oh_to_idx = 6'b10_0101;  // H5
    (52'h1 << 30): oh_to_idx = 6'b10_0110;  // H6
    (52'h1 << 31): oh_to_idx = 6'b10_0111;  // H7
    (52'h1 << 32): oh_to_idx = 6'b10_1000;  // H8
    (52'h1 << 33): oh_to_idx = 6'b10_1001;  // H9
    (52'h1 << 34): oh_to_idx = 6'b10_1010;  // H10
    (52'h1 << 35): oh_to_idx = 6'b10_1011;  // HJ
    (52'h1 << 36): oh_to_idx = 6'b10_1100;  // HQ
    (52'h1 << 37): oh_to_idx = 6'b10_1101;  // HK
    (52'h1 << 38): oh_to_idx = 6'b10_1110;  // HA

    // Spades (11), 2..A
    (52'h1 << 39): oh_to_idx = 6'b11_0010;  // S2
    (52'h1 << 40): oh_to_idx = 6'b11_0011;  // S3
    (52'h1 << 41): oh_to_idx = 6'b11_0100;  // S4
    (52'h1 << 42): oh_to_idx = 6'b11_0101;  // S5
    (52'h1 << 43): oh_to_idx = 6'b11_0110;  // S6
    (52'h1 << 44): oh_to_idx = 6'b11_0111;  // S7
    (52'h1 << 45): oh_to_idx = 6'b11_1000;  // S8
    (52'h1 << 46): oh_to_idx = 6'b11_1001;  // S9
    (52'h1 << 47): oh_to_idx = 6'b11_1010;  // S10
    (52'h1 << 48): oh_to_idx = 6'b11_1011;  // SJ
    (52'h1 << 49): oh_to_idx = 6'b11_1100;  // SQ
    (52'h1 << 50): oh_to_idx = 6'b11_1101;  // SK
    (52'h1 << 51): oh_to_idx = 6'b11_1110;  // SA
    default:          oh_to_idx = 6'd0;
  endcase
endfunction

function automatic [12:0] msb1_oh13_casex(input [12:0] a);
begin
  casex (a)
    13'b1xxxxxxxxxxxx: msb1_oh13_casex = 13'b1000000000000;
    13'b01xxxxxxxxxxx: msb1_oh13_casex = 13'b0100000000000;
    13'b001xxxxxxxxxx: msb1_oh13_casex = 13'b0010000000000;
    13'b0001xxxxxxxxx: msb1_oh13_casex = 13'b0001000000000;
    13'b00001xxxxxxxx: msb1_oh13_casex = 13'b0000100000000;
    13'b000001xxxxxxx: msb1_oh13_casex = 13'b0000010000000;
    13'b0000001xxxxxx: msb1_oh13_casex = 13'b0000001000000;
    13'b00000001xxxxx: msb1_oh13_casex = 13'b0000000100000;
    13'b000000001xxxx: msb1_oh13_casex = 13'b0000000010000;
    13'b0000000001xxx: msb1_oh13_casex = 13'b0000000001000;
    13'b00000000001xx: msb1_oh13_casex = 13'b0000000000100;
    13'b000000000001x: msb1_oh13_casex = 13'b0000000000010;
    13'b0000000000001: msb1_oh13_casex = 13'b0000000000001;
    default          : msb1_oh13_casex = 13'b0;
  endcase
end
endfunction

function reg [51:0] get_top(input [51:0] x);
  reg [51:0] y;
begin
  casex (1'b1)
    (|x[51:39]): y = { msb1_oh13_casex(x[51:39]), 39'b0 };
    (|x[38:26]): y = { 13'b0, msb1_oh13_casex(x[38:26]), 26'b0 };
    (|x[25:13]): y = { 26'b0, msb1_oh13_casex(x[25:13]), 13'b0 };
    (|x[12:0]) : y = { 39'b0, msb1_oh13_casex(x[12:0])};
    default    : y = 52'b0;
  endcase
  get_top = y;
end
endfunction
// ===============================================================
// Design
// ===============================================================

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
                ns = CT;
            end else begin
                ns = cs;
            end
        end
        CT: begin
           ns = CALC;
        end
        CALC: begin
            if(calc_ctr == 467) begin
              ns = IDLE;
            end else begin
              ns = cs;
            end
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid          <= 0;
        out_win_rate       <= 0;
        card_set           <= 0;
        filtered           <= 0;
        calc_ctr           <= 0;
        winner_count       <= 0;
        OUT_WINNER         <= 0;
        OUT_WINNER_reg     <= 0;
        for(i = 0; i < 5; i = i + 1) begin
            PUB_NUM [i]       <= 0;
            PUB_SUIT[i]       <= 0;
        end 
        for(i = 0; i < 9; i = i + 1) begin
            HOLE_NUM [i][0]    <= 0;
            HOLE_NUM [i][1]    <= 0; 
            HOLE_SUIT[i][0]    <= 0;
            HOLE_SUIT[i][1]    <= 0;
            score[i]           <= 0;
            score_buffer[i]    <= 0;
            mod_9[i]           <= 0;
        end
    end else begin
        out_valid          <= out_valid_n;
        out_win_rate       <= out_win_rate_n;
        card_set           <= card_set_n;
        HOLE_NUM           <= HOLE_NUM_n;
        HOLE_SUIT          <= HOLE_SUIT_n;
        PUB_NUM            <= PUB_NUM_n;
        PUB_SUIT           <= PUB_SUIT_n;
        filtered           <= filtered_n;
        calc_ctr           <= calc_ctr_n;
        score              <= score_n;
        score_buffer       <= score_buffer_n;
        mod_9              <= mod_9_n;
        winner_count       <= winner_count_n;
        OUT_WINNER         <= OUT_WINNER_n;
        OUT_WINNER_reg     <= OUT_WINNER;
    end
end

always@(*) begin
    out_valid_n             = 0;
    out_win_rate_n          = 0;
    card_set_n              = card_set;
    filtered_n              = filtered;
    calc_ctr_n              = calc_ctr;
    HOLE_NUM_n              = HOLE_NUM;
    HOLE_SUIT_n             = HOLE_SUIT;
    PUB_NUM_n               = PUB_NUM;
    PUB_SUIT_n              = PUB_SUIT;
    encode_oh               = 64'b0;
    calc_done               = 0;
    score_n                 = score;
    score_buffer_n          = score_buffer;
    mod_9_n                 = mod_9;
    winner_count_n          = winner_count;
    for(i = 0; i < 9; i = i + 1) begin
      inc[i]                   = 0;
    end
    if(cs == IDLE) begin
        calc_ctr_n     = 0;
        out_valid_n    = 0;
        out_win_rate_n = 0;
        for(i = 0; i < 9; i = i + 1) begin
            score_buffer_n[i] = 0;
            score_n[i]        = 0;
            mod_9_n[i]        = 0;
        end
        if(in_valid) begin
            HOLE_NUM_n [0][0] = in_hole_num[ 3: 0];
            HOLE_NUM_n [0][1] = in_hole_num[ 7: 4];
            HOLE_NUM_n [1][0] = in_hole_num[11: 8];
            HOLE_NUM_n [1][1] = in_hole_num[15:12];
            HOLE_NUM_n [2][0] = in_hole_num[19:16];
            HOLE_NUM_n [2][1] = in_hole_num[23:20];
            HOLE_NUM_n [3][0] = in_hole_num[27:24];
            HOLE_NUM_n [3][1] = in_hole_num[31:28];
            HOLE_NUM_n [4][0] = in_hole_num[35:32];
            HOLE_NUM_n [4][1] = in_hole_num[39:36];
            HOLE_NUM_n [5][0] = in_hole_num[43:40];
            HOLE_NUM_n [5][1] = in_hole_num[47:44];
            HOLE_NUM_n [6][0] = in_hole_num[51:48];
            HOLE_NUM_n [6][1] = in_hole_num[55:52];
            HOLE_NUM_n [7][0] = in_hole_num[59:56];
            HOLE_NUM_n [7][1] = in_hole_num[63:60];
            HOLE_NUM_n [8][0] = in_hole_num[67:64];
            HOLE_NUM_n [8][1] = in_hole_num[71:68];

            HOLE_SUIT_n[0][0] = in_hole_suit[ 1: 0];
            HOLE_SUIT_n[0][1] = in_hole_suit[ 3: 2];
            HOLE_SUIT_n[1][0] = in_hole_suit[ 5: 4];
            HOLE_SUIT_n[1][1] = in_hole_suit[ 7: 6];
            HOLE_SUIT_n[2][0] = in_hole_suit[ 9: 8];
            HOLE_SUIT_n[2][1] = in_hole_suit[11:10];
            HOLE_SUIT_n[3][0] = in_hole_suit[13:12];
            HOLE_SUIT_n[3][1] = in_hole_suit[15:14];
            HOLE_SUIT_n[4][0] = in_hole_suit[17:16];
            HOLE_SUIT_n[4][1] = in_hole_suit[19:18];
            HOLE_SUIT_n[5][0] = in_hole_suit[21:20];
            HOLE_SUIT_n[5][1] = in_hole_suit[23:22];
            HOLE_SUIT_n[6][0] = in_hole_suit[25:24];
            HOLE_SUIT_n[6][1] = in_hole_suit[27:26];
            HOLE_SUIT_n[7][0] = in_hole_suit[29:28];
            HOLE_SUIT_n[7][1] = in_hole_suit[31:30];
            HOLE_SUIT_n[8][0] = in_hole_suit[33:32];
            HOLE_SUIT_n[8][1] = in_hole_suit[35:34];

            PUB_NUM_n  [0]    = in_pub_num[ 3: 0];
            PUB_NUM_n  [1]    = in_pub_num[ 7: 4];
            PUB_NUM_n  [2]    = in_pub_num[11: 8];
            PUB_NUM_n  [3]    = 0;
            PUB_NUM_n  [4]    = 0;

            PUB_SUIT_n [0]    = in_pub_suit[ 1: 0];
            PUB_SUIT_n [1]    = in_pub_suit[ 3: 2];
            PUB_SUIT_n [2]    = in_pub_suit[ 5: 4];
            PUB_SUIT_n [3]    = 0;
            PUB_SUIT_n [4]    = 0;
        end
    end

    if(cs == CT) begin
        encode_oh = 64'b0;
        encode_oh[{HOLE_SUIT[0][0], HOLE_NUM[0][0]}] = 1;
        encode_oh[{HOLE_SUIT[0][1], HOLE_NUM[0][1]}] = 1;
        encode_oh[{HOLE_SUIT[1][0], HOLE_NUM[1][0]}] = 1;
        encode_oh[{HOLE_SUIT[1][1], HOLE_NUM[1][1]}] = 1;
        encode_oh[{HOLE_SUIT[2][0], HOLE_NUM[2][0]}] = 1;
        encode_oh[{HOLE_SUIT[2][1], HOLE_NUM[2][1]}] = 1;
        encode_oh[{HOLE_SUIT[3][0], HOLE_NUM[3][0]}] = 1;
        encode_oh[{HOLE_SUIT[3][1], HOLE_NUM[3][1]}] = 1;
        encode_oh[{HOLE_SUIT[4][0], HOLE_NUM[4][0]}] = 1;
        encode_oh[{HOLE_SUIT[4][1], HOLE_NUM[4][1]}] = 1;
        encode_oh[{HOLE_SUIT[5][0], HOLE_NUM[5][0]}] = 1;
        encode_oh[{HOLE_SUIT[5][1], HOLE_NUM[5][1]}] = 1;
        encode_oh[{HOLE_SUIT[6][0], HOLE_NUM[6][0]}] = 1;
        encode_oh[{HOLE_SUIT[6][1], HOLE_NUM[6][1]}] = 1;
        encode_oh[{HOLE_SUIT[7][0], HOLE_NUM[7][0]}] = 1;
        encode_oh[{HOLE_SUIT[7][1], HOLE_NUM[7][1]}] = 1;
        encode_oh[{HOLE_SUIT[8][0], HOLE_NUM[8][0]}] = 1;
        encode_oh[{HOLE_SUIT[8][1], HOLE_NUM[8][1]}] = 1;

        encode_oh[{PUB_SUIT[0], PUB_NUM[0]}] = 1;
        encode_oh[{PUB_SUIT[1], PUB_NUM[1]}] = 1;
        encode_oh[{PUB_SUIT[2], PUB_NUM[2]}] = 1;

        card_set_n = {encode_oh[62:50], encode_oh[46:34], encode_oh[30:18], encode_oh[14:2]};
        filtered_n = card_set_n | get_top(~card_set_n);
    end

    if(cs == CALC) begin
        calc_ctr_n = calc_ctr + 1;
        {PUB_SUIT_n[3], PUB_NUM_n[3]} = oh_to_idx(get_top(~card_set));
        {PUB_SUIT_n[4], PUB_NUM_n[4]} = oh_to_idx(get_top(~filtered));
        filtered_n = filtered | get_top(~filtered);
        if(&filtered_n) begin
            card_set_n = card_set   | get_top(~card_set);
            filtered_n = card_set_n | get_top(~card_set_n);
        end

        //score calculating
        winner_count_n = ((OUT_WINNER[0] + OUT_WINNER[1]) + (OUT_WINNER[2] + OUT_WINNER[3])) + 
                         ((OUT_WINNER[4] + OUT_WINNER[5]) + (OUT_WINNER[6] + OUT_WINNER[7])) + OUT_WINNER[8];
        
        if(calc_ctr >= 3) begin
            for(i = 0; i < 9; i = i + 1) begin
                if(OUT_WINNER_reg[i]) begin
                    case (winner_count)
                        1: begin
                            if(score_buffer[i] >= 73) begin
                                score_n[i]        = score[i] + 1;
                                score_buffer_n[i] = score_buffer[i] - 73;
                            end else begin
                                score_buffer_n[i] = score_buffer[i] + 20;
                            end
                        end

                        2: begin
                            if(score_buffer[i] >= 83) begin
                                score_n[i]        = score[i] + 1;
                                score_buffer_n[i] = score_buffer[i] - 83;
                            end else begin
                                score_buffer_n[i] = score_buffer[i] + 10;
                            end
                        end

                        3: begin
                            if(mod_9[i] >= 3) begin
                                inc[i]            = 1;
                                mod_9_n[i]        = mod_9[i] - 3;
                            end else begin
                                mod_9_n[i]        = mod_9[i]  + 6;
                            end

                            if(score_buffer[i] + inc[i] >= 87) begin
                                score_n[i]        = score[i] + 1;
                                score_buffer_n[i] = score_buffer[i] - 87 + inc[i];
                            end else begin
                                score_buffer_n[i] = score_buffer[i] + 6  + inc[i];
                            end
                        end

                        4: begin
                            if(score_buffer[i] >= 88) begin
                                score_n[i]        = score[i] + 1;
                                score_buffer_n[i] = score_buffer[i] - 88;
                            end else begin
                                score_buffer_n[i] = score_buffer[i] + 5;
                            end
                        end

                        9: begin
                            if(mod_9[i] >= 7) begin
                                inc[i]            = 1;
                                mod_9_n[i]        =  mod_9[i] - 7;
                            end else begin
                                mod_9_n[i]        =  mod_9[i] + 2;
                            end

                            if(score_buffer[i] + inc[i] >= 91) begin
                                score_n[i]        = score[i] + 1;
                                score_buffer_n[i] = score_buffer[i] - 91 + inc[i];
                            end else begin
                                score_buffer_n[i] = score_buffer[i] + 2  + inc[i];
                            end
                        end
                    endcase
                end
            end
        end

        if(calc_ctr == 467) begin
            out_win_rate_n = {score_n[8], score_n[7], score_n[6], score_n[5], score_n[4], score_n[3], score_n[2], score_n[1], score_n[0]};
            out_valid_n    = 1;
        end
    end

    
end


endmodule