//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : Poker.v
//   	Module Name : Poker
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module Poker #(parameter IP_WIDTH = 9) (
    // Input signals
    IN_HOLE_CARD_NUM, IN_HOLE_CARD_SUIT, IN_PUB_CARD_NUM, IN_PUB_CARD_SUIT,
    // Output signals
    OUT_WINNER
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_WIDTH*8-1:0]  IN_HOLE_CARD_NUM;
input [IP_WIDTH*4-1:0]  IN_HOLE_CARD_SUIT;
input [19:0]  IN_PUB_CARD_NUM;
input [9:0]   IN_PUB_CARD_SUIT;

output [IP_WIDTH-1:0]  OUT_WINNER;

// ===============================================================
// Reg & Wire
// ===============================================================
genvar gi, gj, gp;
integer i, j, p;
// ===============================================================
// Design
// ===============================================================
reg [12:0] public_points [0:3];
//reg [12:0] public_suits  [0:3];


reg [12:0] hole_points      [0: IP_WIDTH - 1][0: 3];
reg [12:0] hole_suits       [0: IP_WIDTH - 1][0: 3];
reg [12:0]      points      [0: IP_WIDTH - 1];
reg [12:0]      suits       [0: IP_WIDTH - 1][0: 3];
reg [ 4:0]  rank_cnt        [0: IP_WIDTH - 1][0:12]; // [player][number][level sum]
reg [12:0] suit_points      [0: IP_WIDTH - 1][0: 3];

reg [IP_WIDTH-1:0]  IS_ROYAL_FLUSH; 
reg [IP_WIDTH-1:0]  IS_STRAIGHT_FLUSH;
reg [IP_WIDTH-1:0]  IS_FOUR_OF_A_KIND;
reg [IP_WIDTH-1:0]  IS_FULL_HOUSE;
reg [IP_WIDTH-1:0]  IS_FLUSH;
reg [IP_WIDTH-1:0]  IS_STRAIGHT;
reg [IP_WIDTH-1:0]  IS_THREE_OF_A_KIND;
reg [IP_WIDTH-1:0]  IS_TWO_PAIR;
reg [IP_WIDTH-1:0]  IS_PAIR;
reg [IP_WIDTH-1:0]  IS_HIGH_CARD;

reg [12:0]  encoded [0: IP_WIDTH - 1];
reg  [4:0]  op_code [0: IP_WIDTH - 1]; 

reg [12:0] encoded_has_four     [0: IP_WIDTH - 1];
reg [12:0] encoded_has_three    [0: IP_WIDTH - 1];
reg [12:0] encoded_has_two      [0: IP_WIDTH - 1];
reg [12:0] encoded_second_two   [0: IP_WIDTH - 1];
reg [12:0] encoded_second_three [0: IP_WIDTH - 1];
reg [12:0] no_four              [0: IP_WIDTH - 1];
reg [12:0] no_three             [0: IP_WIDTH - 1];
reg [12:0] no_three_second      [0: IP_WIDTH - 1];
reg [12:0] no_two               [0: IP_WIDTH - 1];
reg [12:0] no_two_second        [0: IP_WIDTH - 1];
reg [12:0] kicker               [0: IP_WIDTH - 1];
reg [12:0] rl1                  [0: IP_WIDTH - 1];
reg [12:0] rl2                  [0: IP_WIDTH - 1];
//this signal is used for determing if two pair occurs
wire [2:0] two_pair_count [0: IP_WIDTH - 1];
wire [3:0] suit_count     [0:IP_WIDTH - 1][0:3];

reg [12:0] pair_first_kick   [0: IP_WIDTH - 1];
reg [12:0] pair_second_kick  [0: IP_WIDTH - 1];
reg [12:0] pair_third_kick   [0: IP_WIDTH - 1];

reg [17:0] priority_score    [0: IP_WIDTH - 1];
//reg [12:0] debug    [0: IP_WIDTH - 1];
//reg [12:0] debug1   [0: IP_WIDTH - 1];
reg [1:0] sum_three [0: IP_WIDTH - 1];

//assign debug[0] = remove_lowest(remove_lowest(suit_points[0][3]));
//assign debug1[0] = suit_points[0][3];
// ========== FUNCTION DECLARATION =================
function reg [12:0] remove_lowest(input [12:0] m);
    remove_lowest = m & (m - 13'd1);
endfunction

function reg [12:0] remove_two_lowest(input [12:0] m);
    remove_two_lowest = remove_lowest(remove_lowest(m));
endfunction

function [12:0] get_top;
    input [12:0] x;
    reg   [12:0] t;
begin
    t = 13'b0;
    if (|x[12:8]) begin
        case (1'b1)
            x[12]: t[12] = 1'b1;
            x[11]: t[11] = 1'b1;
            x[10]: t[10] = 1'b1;
            x[ 9]: t[ 9] = 1'b1;
            x[ 8]: t[ 8] = 1'b1;
        endcase
    end else if (|x[7:4]) begin
        case (1'b1)
            x[7]: t[7] = 1'b1;
            x[6]: t[6] = 1'b1;
            x[5]: t[5] = 1'b1;
            x[4]: t[4] = 1'b1;
        endcase
    end else begin
        case (1'b1)
            x[3]: t[3] = 1'b1;
            x[2]: t[2] = 1'b1;
            x[1]: t[1] = 1'b1;
            x[0]: t[0] = 1'b1;
        endcase
    end
    get_top = t;
end
endfunction

function reg [3:0] one_hot_to_dec(input [12:0] x);
    case (1'b1)
        x == 13'b1000000000000: one_hot_to_dec = 4'd13;
        x == 13'b0100000000000: one_hot_to_dec = 4'd12;
        x == 13'b0010000000000: one_hot_to_dec = 4'd11;
        x == 13'b0001000000000: one_hot_to_dec = 4'd10;
        x == 13'b0000100000000: one_hot_to_dec = 4'd9;
        x == 13'b0000010000000: one_hot_to_dec = 4'd8;
        x == 13'b0000001000000: one_hot_to_dec = 4'd7;
        x == 13'b0000000100000: one_hot_to_dec = 4'd6;
        x == 13'b0000000010000: one_hot_to_dec = 4'd5;
        x == 13'b0000000001000: one_hot_to_dec = 4'd4;
        x == 13'b0000000000100: one_hot_to_dec = 4'd3;
        x == 13'b0000000000010: one_hot_to_dec = 4'd2;
        x == 13'b0000000000001: one_hot_to_dec = 4'd1;
        default: one_hot_to_dec = 4'd0;
    endcase
endfunction

function reg [12:0] top2(input [12:0] x);
  begin
    top2 = get_top(x & ~get_top(x));
  end
endfunction
// =================================================


generate
    for(gp = 0; gp < IP_WIDTH; gp = gp + 1) begin
        assign two_pair_count[gp] = ((rank_cnt[gp][0][2] + rank_cnt[gp][1][2]) + (rank_cnt[gp][2][2] + 
                             rank_cnt[gp][3][2])) + ((rank_cnt[gp][4][2] + rank_cnt[gp][5][2]) + 
                             (rank_cnt[gp][6][2] + rank_cnt[gp][7][2])) + ((rank_cnt[gp][8][2] + 
                             rank_cnt[gp][9][2]) + (rank_cnt[gp][10][2] + rank_cnt[gp][11][2])) + 
                             rank_cnt[gp][12][2];
        
        for(gj = 0; gj < 4; gj = gj + 1) begin
            assign suit_count[gp][gj] = ((suit_points[gp][gj][0] + suit_points[gp][gj][1]) +  (suit_points[gp][gj][2] + 
                                        suit_points[gp][gj][3])) + ((suit_points[gp][gj][4] +  suit_points[gp][gj][5]) + 
                                        (suit_points[gp][gj][6] + suit_points[gp][gj][7])) +  ((suit_points[gp][gj][8] + 
                                        suit_points[gp][gj][9]) + (suit_points[gp][gj][10] + suit_points[gp][gj][11])) + 
                                        suit_points[gp][gj][12];
        end
        assign encoded_has_four[gp]  = {rank_cnt[gp][12][4], rank_cnt[gp][11][4], rank_cnt[gp][10][4],
                                        rank_cnt[gp][ 9][4], rank_cnt[gp][ 8][4], rank_cnt[gp][ 7][4],
                                        rank_cnt[gp][ 6][4], rank_cnt[gp][ 5][4], rank_cnt[gp][ 4][4],
                                        rank_cnt[gp][ 3][4], rank_cnt[gp][ 2][4], rank_cnt[gp][ 1][4],
                                        rank_cnt[gp][ 0][4]};
        assign encoded_has_three[gp] = {rank_cnt[gp][12][3], rank_cnt[gp][11][3], rank_cnt[gp][10][3],
                                        rank_cnt[gp][ 9][3], rank_cnt[gp][ 8][3], rank_cnt[gp][ 7][3],
                                        rank_cnt[gp][ 6][3], rank_cnt[gp][ 5][3], rank_cnt[gp][ 4][3],
                                        rank_cnt[gp][ 3][3], rank_cnt[gp][ 2][3], rank_cnt[gp][ 1][3],
                                        rank_cnt[gp][ 0][3]};
        assign encoded_has_two[gp]   = {rank_cnt[gp][12][2], rank_cnt[gp][11][2], rank_cnt[gp][10][2],
                                        rank_cnt[gp][ 9][2], rank_cnt[gp][ 8][2], rank_cnt[gp][ 7][2],
                                        rank_cnt[gp][ 6][2], rank_cnt[gp][ 5][2], rank_cnt[gp][ 4][2],
                                        rank_cnt[gp][ 3][2], rank_cnt[gp][ 2][2], rank_cnt[gp][ 1][2],
                                        rank_cnt[gp][ 0][2]};
         //indicate the second largest pair, one hot.
        assign encoded_second_two[gp] = get_top((~get_top(encoded_has_two[gp])) & (encoded_has_two[gp]));
        // indicate the second largest triple, one hot.
        assign encoded_second_three[gp] = get_top((~get_top(encoded_has_three[gp])) & (encoded_has_three[gp]));
        assign no_four[gp]           = points[gp] & (~encoded_has_four[gp]);
        assign no_three[gp]          = points[gp] & (~get_top(encoded_has_three[gp]));
        // after finding the triple, we need to know the other 2 cards with different points.
        assign no_three_second[gp]   = get_top((~get_top(no_three[gp])) & (no_three[gp]));
        assign no_two[gp]            = points[gp] & (~get_top(encoded_has_two[gp]));
        // indicate the largest card regarding two pairs, one hot.
        assign no_two_second[gp]     = get_top(no_two[gp] & (~encoded_second_two[gp]));
        assign kicker[gp]            = get_top(no_four[gp]);
        assign rl1[gp]               = remove_lowest(points[gp]);
        assign rl2[gp]               = remove_lowest(rl1[gp]);
        assign pair_first_kick[gp]   = get_top(no_two[gp]);
        assign pair_second_kick[gp]  = get_top((~pair_first_kick[gp]) & (no_two[gp]));
        assign pair_third_kick[gp]   = get_top((~pair_first_kick[gp]) & (~pair_second_kick[gp]) & (no_two[gp]));
        assign sum_three[gp]             = rank_cnt[gp][12][3] + rank_cnt[gp][11][3] + rank_cnt[gp][10][3] +
                                        rank_cnt[gp][ 9][3] + rank_cnt[gp][ 8][3] + rank_cnt[gp][ 7][3] +
                                        rank_cnt[gp][ 6][3] + rank_cnt[gp][ 5][3] + rank_cnt[gp][ 4][3] +
                                        rank_cnt[gp][ 3][3] + rank_cnt[gp][ 2][3] + rank_cnt[gp][ 1][3] +
                                        rank_cnt[gp][ 0][3];
        assign priority_score[gp]    = {op_code[gp], encoded[gp]};
        //assign card_score            = priority_score[0];

    end

endgenerate

always @(*) begin
    //first, generate the public points and suits
    
    for(i = 0; i < 4; i = i + 1) begin
        //public_suits [i]  = 0;
        public_points[i]  = 0;
    end
    for(i = 0; i < 5; i = i + 1) begin
        case (IN_PUB_CARD_NUM[(i*4) +: 4] )
             2: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 0]  = 1; end
             3: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 1]  = 1; end
             4: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 2]  = 1; end
             5: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 3]  = 1; end
             6: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 4]  = 1; end
             7: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 5]  = 1; end
             8: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 6]  = 1; end
             9: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 7]  = 1; end
            10: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 8]  = 1; end
            11: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][ 9]  = 1; end
            12: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][10]  = 1; end
            13: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][11]  = 1; end
            14: begin public_points[IN_PUB_CARD_SUIT[(i*2) +: 2]][12]  = 1; end
        endcase
    end
    //second, generate the hole points and suits
    for(i = 0; i < IP_WIDTH; i = i + 1) begin //player
        for(j = 0; j < 4; j = j + 1) begin
            hole_suits [i][j] = 0;
            hole_points[i][j] = 0;
        end
        for(j = 0; j < 2; j = j + 1) begin // each player has three cards
            case (IN_HOLE_CARD_NUM[(i*8) + (j * 4) +: 4])
                 2: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 0]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [0] = 1; end
                 3: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 1]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [1] = 1; end
                 4: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 2]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [2] = 1; end
                 5: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 3]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [3] = 1; end
                 6: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 4]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [4] = 1; end
                 7: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 5]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [5] = 1; end
                 8: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 6]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [6] = 1; end
                 9: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 7]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [7] = 1; end
                10: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 8]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [8] = 1; end
                11: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][ 9]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]] [9] = 1; end
                12: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][10]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][10] = 1; end
                13: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][11]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][11] = 1; end
                14: begin hole_points[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][12]  = 1; hole_suits[i][IN_HOLE_CARD_SUIT[(i*4) + (j*2) +: 2]][12] = 1; end
            endcase
        end
    end
end




generate
    for(gi = 0; gi < IP_WIDTH; gi = gi + 1) begin
      //assign points[gi] = hole_points[gi][0] | hole_points[gi][1] | hole_points[gi][2] | hole_points[gi][3] | public_points;
      for(gj = 0; gj < 4; gj = gj + 1) begin
        //assign suits[gi][gj]  = hole_suits[gi][gj]  | public_suits[gj];
        assign suit_points[gi][gj] = hole_points[gi][gj] | public_points[gj];
      end
      assign points[gi] = suit_points[gi][0] | suit_points[gi][1] | suit_points[gi][2] | suit_points[gi][3];
    end
endgenerate

genvar gr;
always @(*) begin
    for(i = 0; i < IP_WIDTH; i = i + 1) begin
        for (j=0; j<13; j=j+1) begin: GEN_CNT
            case({suit_points[i][0][j], suit_points[i][1][j], suit_points[i][2][j], suit_points[i][3][j]})
                4'b0000:
                    begin rank_cnt[i][j] = 5'b00000; end
                4'b0001, 4'b0010, 4'b0100, 4'b1000:
                    begin rank_cnt[i][j] = 5'b00010; end
                4'b1100, 4'b1010, 4'b1001, 4'b0110, 4'b0101, 4'b0011:
                    begin rank_cnt[i][j] = 5'b00100; end
                4'b1110, 4'b1101, 4'b1011, 4'b0111:
                    begin rank_cnt[i][j] = 5'b01000; end
                4'b1111:
                    begin rank_cnt[i][j] = 5'b10000; end
                default: begin rank_cnt[i][j] = 5'b00000; end
            endcase
        end
    end
end

// ========================= DETERMINE THE TYPES ===================================
always @(*) begin
    for(p = 0; p < IP_WIDTH; p = p + 1) begin
        IS_ROYAL_FLUSH      [p] = 0; 
        IS_STRAIGHT_FLUSH   [p] = 0;
        IS_FOUR_OF_A_KIND   [p] = 0;
        IS_FULL_HOUSE       [p] = 0;
        IS_FLUSH            [p] = 0;
        IS_STRAIGHT         [p] = 0;
        IS_THREE_OF_A_KIND  [p] = 0;
        IS_TWO_PAIR         [p] = 0;
        IS_PAIR             [p] = 0;
        IS_HIGH_CARD        [p] = 0;
        // ROYAL FLUSH
        if(&suit_points[p][0][12:8] ||
           &suit_points[p][1][12:8] ||
           &suit_points[p][2][12:8] ||
           &suit_points[p][3][12:8]) begin
            IS_ROYAL_FLUSH[p] = 1;
        end
        //STRAIGHT
        if(&points[p][12:8] ||
           &points[p][11:7] ||
           &points[p][10:6] ||
           &points[p][ 9:5] ||
           &points[p][ 8:4] ||
           &points[p][ 7:3] ||
           &points[p][ 6:2] ||
           &points[p][ 5:1] ||
           &points[p][ 4:0] ||
           &{points[p][3:0], points[p][12]}) begin //A2345
            IS_STRAIGHT[p] = 1;
        end
        
        //STRAIGHT_FLUSH
        if(&suit_points[p][0][12:8] ||
           &suit_points[p][0][11:7] ||
           &suit_points[p][0][10:6] ||
           &suit_points[p][0][ 9:5] ||
           &suit_points[p][0][ 8:4] ||
           &suit_points[p][0][ 7:3] ||
           &suit_points[p][0][ 6:2] ||
           &suit_points[p][0][ 5:1] ||
           &suit_points[p][0][ 4:0] ||
           & {suit_points[p][0][3:0], suit_points[p][0][12]}) begin //A2345
            IS_STRAIGHT_FLUSH[p] = 1;
        end
        if(& suit_points[p][1][12:8] ||
           & suit_points[p][1][11:7] ||
           & suit_points[p][1][10:6] ||
           & suit_points[p][1][ 9:5] ||
           & suit_points[p][1][ 8:4] ||
           & suit_points[p][1][ 7:3] ||
           & suit_points[p][1][ 6:2] ||
           & suit_points[p][1][ 5:1] ||
           & suit_points[p][1][ 4:0] ||
           & {suit_points[p][1][3:0], suit_points[p][1][12]}) begin //A2345
            IS_STRAIGHT_FLUSH[p] = 1;
        end
        if(& suit_points[p][2][12:8] ||
           & suit_points[p][2][11:7] ||
           & suit_points[p][2][10:6] ||
           & suit_points[p][2][ 9:5] ||
           & suit_points[p][2][ 8:4] ||
           & suit_points[p][2][ 7:3] ||
           & suit_points[p][2][ 6:2] ||
           & suit_points[p][2][ 5:1] ||
           & suit_points[p][2][ 4:0] ||
           & {suit_points[p][2][3:0], suit_points[p][2][12]}) begin //A2345
            IS_STRAIGHT_FLUSH[p] = 1;
        end
        if(& suit_points[p][3][12:8] ||
           & suit_points[p][3][11:7] ||
           & suit_points[p][3][10:6] ||
           & suit_points[p][3][ 9:5] ||
           & suit_points[p][3][ 8:4] ||
           & suit_points[p][3][ 7:3] ||
           & suit_points[p][3][ 6:2] ||
           & suit_points[p][3][ 5:1] ||
           & suit_points[p][3][ 4:0] ||
           & {suit_points[p][3][3:0], suit_points[p][3][12]}) begin //A2345
            IS_STRAIGHT_FLUSH[p] = 1;
        end

        // FOUR OF A KIND
        if(rank_cnt[p][0][4] || rank_cnt[p][1][4] || rank_cnt[p][2][4] || rank_cnt[p][3][4] ||
           rank_cnt[p][4][4] || rank_cnt[p][5][4] || rank_cnt[p][6][4] || rank_cnt[p][7][4] ||
           rank_cnt[p][8][4] || rank_cnt[p][9][4] || rank_cnt[p][10][4] || rank_cnt[p][11][4] ||
           rank_cnt[p][12][4]) begin
            IS_FOUR_OF_A_KIND[p] = 1;
        end

        // THREE OF A KIND
        if(rank_cnt[p][0][3] || rank_cnt[p][1][3] || rank_cnt[p][2][3] || rank_cnt[p][3][3] ||
           rank_cnt[p][4][3] || rank_cnt[p][5][3] || rank_cnt[p][6][3] || rank_cnt[p][7][3] ||
           rank_cnt[p][8][3] || rank_cnt[p][9][3] || rank_cnt[p][10][3] || rank_cnt[p][11][3] ||
           rank_cnt[p][12][3]) begin
            IS_THREE_OF_A_KIND[p] = 1;
        end

        

        // PAIR & FULL HOUSE
        if(rank_cnt[p][0][2] || rank_cnt[p][1][2] || rank_cnt[p][2][2] || rank_cnt[p][3][2] ||
           rank_cnt[p][4][2] || rank_cnt[p][5][2] || rank_cnt[p][6][2] || rank_cnt[p][7][2] ||
           rank_cnt[p][8][2] || rank_cnt[p][9][2] || rank_cnt[p][10][2] || rank_cnt[p][11][2] ||
           rank_cnt[p][12][2]) begin
            IS_PAIR[p] = 1;    
        end

        //FULL HOUSE
        if(sum_three[p] == 2 || (sum_three[p] && IS_PAIR[p])) begin
                IS_FULL_HOUSE[p] = 1;
        end


        // TWO PAIR
        if(two_pair_count[p][1] == 1)  begin //check if it's more than two pairs
            IS_TWO_PAIR[p] = 1;
        end

        // FLUSH
        if(suit_count[p][0] >= 5|| suit_count[p][1] >= 5 || suit_count[p][2] >= 5|| suit_count[p][3] >= 5) begin
            IS_FLUSH[p] = 1;
        end

        //HIGH CARD
        IS_HIGH_CARD[p] = 1;
        
    end
end
// =================================================================================
// =========================  ENCODE TO 18 BITS  ===================================
always @(*) begin
    for(p = 0; p < IP_WIDTH; p = p + 1) begin
        op_code[p] = 0;
        encoded[p] = 0;
        case (1'b1)
            IS_ROYAL_FLUSH[p]: begin //ok
                op_code[p] = 5'd31;
                encoded[p] = 13'b0;
            end
            IS_STRAIGHT_FLUSH[p]: begin //ok
                op_code[p] = 5'd30;
                //encoded[p] = 13'b0;
                case(1'b1)
                    &suit_points[p][0][12:8]   || &suit_points[p][1][12:8]   ||
                    &suit_points[p][2][12:8]   || &suit_points[p][3][12:8]  :
                        encoded[p] = 13'b0000100000000;
                    &suit_points[p][0][11:7]   || &suit_points[p][1][11:7]   ||
                    &suit_points[p][2][11:7]   || &suit_points[p][3][11:7]  :
                        encoded[p] = 13'b0000010000000;
                    &suit_points[p][0][10:6]   || &suit_points[p][1][10:6]   ||
                    &suit_points[p][2][10:6]   || &suit_points[p][3][10:6]  :
                        encoded[p] = 13'b0000001000000;
                    &suit_points[p][0][ 9:5]   || &suit_points[p][1][ 9:5]   ||
                    &suit_points[p][2][ 9:5]   || &suit_points[p][3][ 9:5]  :
                        encoded[p] = 13'b0000000100000;
                    &suit_points[p][0][ 8:4]   || &suit_points[p][1][ 8:4]   ||
                    &suit_points[p][2][ 8:4]   || &suit_points[p][3][ 8:4]  :
                        encoded[p] = 13'b0000000010000;
                    &suit_points[p][0][ 7:3]   || &suit_points[p][1][ 7:3]   ||
                    &suit_points[p][2][ 7:3]   || &suit_points[p][3][ 7:3]  :
                        encoded[p] = 13'b0000000001000;
                    &suit_points[p][0][ 6:2]   || &suit_points[p][1][ 6:2]   ||
                    &suit_points[p][2][ 6:2]   || &suit_points[p][3][ 6:2]  :
                        encoded[p] = 13'b0000000000100;
                    &suit_points[p][0][ 5:1]   || &suit_points[p][1][ 5:1]   ||
                    &suit_points[p][2][ 5:1]   || &suit_points[p][3][ 5:1]  :
                        encoded[p] = 13'b0000000000010;
                    &suit_points[p][0][ 4:0]   || &suit_points[p][1][ 4:0]   ||
                    &suit_points[p][2][ 4:0]   || &suit_points[p][3][ 4:0]  :
                        encoded[p] = 13'b0000000000001;
                    &{suit_points[p][0][3:0], suit_points[p][0][12]}   || 
                    &{suit_points[p][1][3:0], suit_points[p][1][12]}   ||
                    &{suit_points[p][2][3:0], suit_points[p][2][12]}   ||
                    &{suit_points[p][3][3:0], suit_points[p][3][12]}  :
                        encoded[p] = 13'b0000000000000;
                endcase
            end
            IS_FOUR_OF_A_KIND[p]: begin //ok
                op_code[p] = 5'd29;
                case (1'b1)
                    encoded_has_four[p] == 13'b1000000000000: encoded[p][12:9] = 4'd13;
                    encoded_has_four[p] == 13'b0100000000000: encoded[p][12:9] = 4'd12;
                    encoded_has_four[p] == 13'b0010000000000: encoded[p][12:9] = 4'd11;
                    encoded_has_four[p] == 13'b0001000000000: encoded[p][12:9] = 4'd10;
                    encoded_has_four[p] == 13'b0000100000000: encoded[p][12:9] = 4'd9;
                    encoded_has_four[p] == 13'b0000010000000: encoded[p][12:9] = 4'd8;
                    encoded_has_four[p] == 13'b0000001000000: encoded[p][12:9] = 4'd7;
                    encoded_has_four[p] == 13'b0000000100000: encoded[p][12:9] = 4'd6;
                    encoded_has_four[p] == 13'b0000000010000: encoded[p][12:9] = 4'd5;
                    encoded_has_four[p] == 13'b0000000001000: encoded[p][12:9] = 4'd4;
                    encoded_has_four[p] == 13'b0000000000100: encoded[p][12:9] = 4'd3;
                    encoded_has_four[p] == 13'b0000000000010: encoded[p][12:9] = 4'd2;
                    encoded_has_four[p] == 13'b0000000000001: encoded[p][12:9] = 4'd1;
                    default: encoded[p][12:9] = 4'd0;
                endcase
                case (1'b1)
                    kicker[p] == 13'b1000000000000: encoded[p][8:5] = 4'd13;
                    kicker[p] == 13'b0100000000000: encoded[p][8:5] = 4'd12;
                    kicker[p] == 13'b0010000000000: encoded[p][8:5] = 4'd11;
                    kicker[p] == 13'b0001000000000: encoded[p][8:5] = 4'd10;
                    kicker[p] == 13'b0000100000000: encoded[p][8:5] = 4'd9;
                    kicker[p] == 13'b0000010000000: encoded[p][8:5] = 4'd8;
                    kicker[p] == 13'b0000001000000: encoded[p][8:5] = 4'd7;
                    kicker[p] == 13'b0000000100000: encoded[p][8:5] = 4'd6;
                    kicker[p] == 13'b0000000010000: encoded[p][8:5] = 4'd5;
                    kicker[p] == 13'b0000000001000: encoded[p][8:5] = 4'd4;
                    kicker[p] == 13'b0000000000100: encoded[p][8:5] = 4'd3;
                    kicker[p] == 13'b0000000000010: encoded[p][8:5] = 4'd2;
                    kicker[p] == 13'b0000000000001: encoded[p][8:5] = 4'd1;
                    kicker[p] == 13'b0000000000000: encoded[p][8:5] = 4'd0;
                endcase
            end
            IS_FULL_HOUSE[p]: begin //ok
                op_code[p] = 5'd28;
                encoded[p][12:9] = one_hot_to_dec(get_top(encoded_has_three[p]));
                if(sum_three[p] == 2) begin
                    encoded[p][8:5] = one_hot_to_dec(encoded_second_three[p]);
                end
                else begin  
                    encoded[p][8:5] = one_hot_to_dec(get_top(encoded_has_two[p]));
                end
            end
            IS_FLUSH[p]: begin //ok
                op_code[p] = 5'd27;
                case (1'b1)
                    suit_count[p][0] == 7: begin
                        encoded[p] = remove_two_lowest(suit_points[p][0]);
                    end
                    suit_count[p][1] == 7: begin
                        encoded[p] = remove_two_lowest(suit_points[p][1]);
                    end
                    suit_count[p][2] == 7: begin
                        encoded[p] = remove_two_lowest(suit_points[p][2]);
                    end
                    suit_count[p][3] == 7: begin
                        encoded[p] = remove_two_lowest(suit_points[p][3]);
                    end
                    suit_count[p][0] == 6: begin
                        encoded[p] = remove_lowest(suit_points[p][0]);
                    end
                    suit_count[p][1] == 6: begin
                        encoded[p] = remove_lowest(suit_points[p][1]);
                    end
                    suit_count[p][2] == 6: begin
                        encoded[p] = remove_lowest(suit_points[p][2]);
                    end
                    suit_count[p][3] == 6: begin
                        encoded[p] = remove_lowest(suit_points[p][3]);
                    end
                    suit_count[p][0] == 5: begin
                        encoded[p] = suit_points[p][0];
                    end
                    suit_count[p][1] == 5: begin
                        encoded[p] = suit_points[p][1];
                    end
                    suit_count[p][2] == 5: begin
                        encoded[p] = suit_points[p][2];
                    end
                    suit_count[p][3] == 5: begin
                        encoded[p] = suit_points[p][3];
                    end
                    default: encoded[p] = 13'b0000000000000;
                endcase
            end
            IS_STRAIGHT[p]: begin //ok
                op_code[p] = 5'd26;
                case(1'b1)
                    &points[p][12:8]  :
                        encoded[p] = 13'b0000100000000;
                    &points[p][11:7]  :
                        encoded[p] = 13'b0000010000000;
                    &points[p][10:6]  :
                        encoded[p] = 13'b0000001000000;
                    &points[p][ 9:5]  :
                        encoded[p] = 13'b0000000100000;
                    &points[p][ 8:4]  :
                        encoded[p] = 13'b0000000010000;
                    &points[p][ 7:3]  :
                        encoded[p] = 13'b0000000001000;
                    &points[p][ 6:2]  :
                        encoded[p] = 13'b0000000000100;
                    &points[p][ 5:1]  :
                        encoded[p] = 13'b0000000000010;
                    &points[p][ 4:0]  :
                        encoded[p] = 13'b0000000000001;
                    &{points[p][3:0], points[p][12]}  :
                        encoded[p] = 13'b0000000000000;
                endcase
            end
            IS_THREE_OF_A_KIND[p]: begin //ok
                op_code[p] = 5'd25;
                encoded[p][12:9] = one_hot_to_dec(get_top(encoded_has_three[p]));
                encoded[p][8: 5] = one_hot_to_dec(get_top(no_three[p]));
                encoded[p][4: 1] = one_hot_to_dec(no_three_second[p]);
            end
            IS_TWO_PAIR[p]: begin //ok
                op_code[p] = 5'd24;
                encoded[p][12:9] = one_hot_to_dec(get_top(encoded_has_two[p]));
                encoded[p][8: 5] = one_hot_to_dec(encoded_second_two[p]);
                encoded[p][4: 1] = one_hot_to_dec(no_two_second[p]);
            end
            IS_PAIR[p]: begin //ok
                case (1'b1)
                    get_top(encoded_has_two[p]) == 13'b1000000000000: op_code[p] = 23;
                    get_top(encoded_has_two[p]) == 13'b0100000000000: op_code[p] = 22;
                    get_top(encoded_has_two[p]) == 13'b0010000000000: op_code[p] = 21;
                    get_top(encoded_has_two[p]) == 13'b0001000000000: op_code[p] = 20;
                    get_top(encoded_has_two[p]) == 13'b0000100000000: op_code[p] = 19;
                    get_top(encoded_has_two[p]) == 13'b0000010000000: op_code[p] = 18;
                    get_top(encoded_has_two[p]) == 13'b0000001000000: op_code[p] = 17;
                    get_top(encoded_has_two[p]) == 13'b0000000100000: op_code[p] = 16;
                    get_top(encoded_has_two[p]) == 13'b0000000010000: op_code[p] = 15;
                    get_top(encoded_has_two[p]) == 13'b0000000001000: op_code[p] = 14;
                    get_top(encoded_has_two[p]) == 13'b0000000000100: op_code[p] = 13;
                    get_top(encoded_has_two[p]) == 13'b0000000000010: op_code[p] = 12;
                    get_top(encoded_has_two[p]) == 13'b0000000000001: op_code[p] = 11;
                    default: encoded[p] = 12;
                endcase
                encoded[p][12:9] = one_hot_to_dec(pair_first_kick[p]);
                encoded[p][8: 5] = one_hot_to_dec(pair_second_kick[p]);
                encoded[p][4: 1] = one_hot_to_dec(pair_third_kick[p]);
            end
            IS_HIGH_CARD[p]: begin //ok
                op_code[p] = 5'd0;
                encoded[p] = rl2[p];
            end
        endcase
    end
end

// ===================== Counting-Style Max + Tie Mask =====================

wire [IP_WIDTH-1:0] lose;

genvar ii, jj;
generate
  for (ii = 0; ii < IP_WIDTH; ii = ii + 1) begin : CMP_I

    wire [IP_WIDTH-1:0] bigger_than_i;
    for (jj = 0; jj < IP_WIDTH; jj = jj + 1) begin : CMP_J
      if (jj == ii) begin
        assign bigger_than_i[jj] = 1'b0;
      end else begin
        assign bigger_than_i[jj] = (priority_score[jj] > priority_score[ii]);
      end
    end
    assign lose[ii] = |bigger_than_i;
  end
endgenerate

assign OUT_WINNER = ~lose;
// ========================================================================


endmodule






