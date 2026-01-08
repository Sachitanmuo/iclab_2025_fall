module SUDOKU(
    //Input Port
    clk,
    rst_n,
	in_valid,
	in,

    //Output Port
    out_valid,
    out
    );

//==============================
//   INPUT/OUTPUT DECLARATION
//==============================
input clk;
input rst_n;
input in_valid;
input [3:0] in;

output reg out_valid;
output reg [3:0] out;
    
//==============================
//   PARAMETER DECLARATION
//==============================
reg [2:0] cs, ns;
reg [8:0] grid        [0:8][0:8];
reg [8:0] grid_n      [0:8][0:8];
reg [8:0] candidate   [0:8][0:8];
reg [8:0] candidate_n [0:8][0:8];
reg [6:0] input_counter, input_counter_n;
reg [6:0] output_counter, output_counter_n;
reg [3:0] out_n;
reg       out_valid_n;
reg       single_success;
reg [3:0] encoder_in;
reg [8:0] encoder_out;
reg [8:0] decoder_in;
reg [3:0] decoder_out;
integer i, j;

reg  [8:0] row   [0:8];
reg  [8:0] col   [0:8];
reg  [8:0] box   [0:2][0:2];

reg [8:0]  row_n [0:8];
reg [8:0]  col_n [0:8];
reg [8:0]  box_n [0:2][0:2];
wire [3:0] check_single [0:8][0:8]; 
wire       full;
wire hs_enter;
reg [9:0] debug;
encoder u_encoder(.in(encoder_in), .out(encoder_out));
decoder u_decoder(.in(decoder_in), .out(decoder_out));

integer br, bc;
reg  [8:0] buff   [0:8];
reg  [8:0] buff_n [0:8];
reg  [4:0] hs_u, hs_u_n;  // 0..26：9 row + 9 col + 9 box
reg  [3:0] r0,c0,r1,c1,r2,c2,r3,c3,r4,c4,r5,c5,r6,c6,r7,c7,r8,c8;

reg  [8:0] hs_m   [0:8];
wire [8:0] hs_own [0:8];
wire       hs_any;
reg        hs_wrote_any, hs_wrote_any_n;


HS_Verifier hs_v (
  .m0(hs_m[0]), .m1(hs_m[1]), .m2(hs_m[2]), .m3(hs_m[3]), .m4(hs_m[4]),
  .m5(hs_m[5]), .m6(hs_m[6]), .m7(hs_m[7]), .m8(hs_m[8]),
  .own0(hs_own[0]), .own1(hs_own[1]), .own2(hs_own[2]), .own3(hs_own[3]), .own4(hs_own[4]),
  .own5(hs_own[5]), .own6(hs_own[6]), .own7(hs_own[7]), .own8(hs_own[8]),
  .any_hit(hs_any)
);

genvar gi, gj, gk;


generate
    
    for(gi = 0; gi < 9;gi = gi + 1) begin
        for(gj = 0; gj < 9; gj = gj + 1) begin
            assign check_single[gi][gj] = candidate_n[gi][gj][0] + candidate_n[gi][gj][1] + candidate_n[gi][gj][2] + 
                                          candidate_n[gi][gj][3] + candidate_n[gi][gj][4] + candidate_n[gi][gj][5] + 
                                          candidate_n[gi][gj][6] + candidate_n[gi][gj][7] + candidate_n[gi][gj][8];
        end
    end

    for(gi = 0; gi < 9; gi = gi + 1) begin
        assign row[gi]   =  grid[gi][0]   | grid[gi][1]   | grid[gi][2]   |
                            grid[gi][3]   | grid[gi][4]   | grid[gi][5]   | 
                            grid[gi][6]   | grid[gi][7]   | grid[gi][8];  
        assign col[gi]   =  grid[0][gi]   | grid[1][gi]   | grid[2][gi]   |
                            grid[3][gi]   | grid[4][gi]   | grid[5][gi]   |
                            grid[6][gi]   | grid[7][gi]   | grid[8][gi];  
        assign row_n[gi] =  grid_n[gi][0] | grid_n[gi][1] | grid_n[gi][2] |
                            grid_n[gi][3] | grid_n[gi][4] | grid_n[gi][5] | 
                            grid_n[gi][6] | grid_n[gi][7] | grid_n[gi][8];
        assign col_n[gi] =  grid_n[0][gi] | grid_n[1][gi] | grid_n[2][gi] |
                            grid_n[3][gi] | grid_n[4][gi] | grid_n[5][gi] |
                            grid_n[6][gi] | grid_n[7][gi] | grid_n[8][gi];
    end

    for(gi = 0; gi < 3; gi = gi + 1) begin
        for(gj = 0; gj < 3; gj = gj + 1) begin
            assign box[gi][gj]   =  grid[3 * gi    ][3 * gj]   | grid[3 * gi    ][3 * gj + 1]   | grid[3 * gi    ][3 * gj + 2] | 
                                    grid[3 * gi + 1][3 * gj]   | grid[3 * gi + 1][3 * gj + 1]   | grid[3 * gi + 1][3 * gj + 2] | 
                                    grid[3 * gi + 2][3 * gj]   | grid[3 * gi + 2][3 * gj + 1]   | grid[3 * gi + 2][3 * gj + 2];
            assign box_n[gi][gj] =  grid_n[3 * gi    ][3 * gj] | grid_n[3 * gi    ][3 * gj + 1] | grid_n[3 * gi    ][3 * gj + 2] | 
                                    grid_n[3 * gi + 1][3 * gj] | grid_n[3 * gi + 1][3 * gj + 1] | grid_n[3 * gi + 1][3 * gj + 2] | 
                                    grid_n[3 * gi + 2][3 * gj] | grid_n[3 * gi + 2][3 * gj + 1] | grid_n[3 * gi + 2][3 * gj + 2];
        end
    end

    assign full =
    (row_n[0][0] & row_n[0][1] & row_n[0][2] & row_n[0][3] & row_n[0][4] & row_n[0][5] & row_n[0][6] & row_n[0][7] & row_n[0][8]) &
    (row_n[1][0] & row_n[1][1] & row_n[1][2] & row_n[1][3] & row_n[1][4] & row_n[1][5] & row_n[1][6] & row_n[1][7] & row_n[1][8]) &
    (row_n[2][0] & row_n[2][1] & row_n[2][2] & row_n[2][3] & row_n[2][4] & row_n[2][5] & row_n[2][6] & row_n[2][7] & row_n[2][8]) &
    (row_n[3][0] & row_n[3][1] & row_n[3][2] & row_n[3][3] & row_n[3][4] & row_n[3][5] & row_n[3][6] & row_n[3][7] & row_n[3][8]) &
    (row_n[4][0] & row_n[4][1] & row_n[4][2] & row_n[4][3] & row_n[4][4] & row_n[4][5] & row_n[4][6] & row_n[4][7] & row_n[4][8]) &
    (row_n[5][0] & row_n[5][1] & row_n[5][2] & row_n[5][3] & row_n[5][4] & row_n[5][5] & row_n[5][6] & row_n[5][7] & row_n[5][8]) &
    (row_n[6][0] & row_n[6][1] & row_n[6][2] & row_n[6][3] & row_n[6][4] & row_n[6][5] & row_n[6][6] & row_n[6][7] & row_n[6][8]) &
    (row_n[7][0] & row_n[7][1] & row_n[7][2] & row_n[7][3] & row_n[7][4] & row_n[7][5] & row_n[7][6] & row_n[7][7] & row_n[7][8]) &
    (row_n[8][0] & row_n[8][1] & row_n[8][2] & row_n[8][3] & row_n[8][4] & row_n[8][5] & row_n[8][6] & row_n[8][7] & row_n[8][8]);
endgenerate

//==============================
//   LOGIC DECLARATION                                                 
//==============================
parameter IDLE      = 3'd0,
          INPUT     = 3'd1,
          ELIM      = 3'd2,
          HS        = 3'd3,
          OUT       = 3'd4;




//==============================
//   Design                                                            
//==============================

// FSM
always @(negedge rst_n or posedge clk) begin
    if(!rst_n) cs <= 0;
    else cs <= ns;
end

always @(*) begin
    case (cs)
        IDLE: begin
            if(in_valid) ns = INPUT;
            else ns = cs;
        end 
        INPUT: begin
            if(input_counter == 80) ns = ELIM;
            else ns = cs;
        end

        ELIM: begin
            if(single_success) begin
                if(full) begin
                    ns = OUT;
                end else begin
                    ns = cs;
                end
            end else begin
                ns = HS;
            end
        end

        HS: begin
            ns = (hs_u == 5'd26) ? (hs_wrote_any_n ? ELIM : OUT) : HS;
        end


        OUT: begin
            if(output_counter == 80) ns = IDLE;
            else ns = cs; 
        end

        default: ns = cs;  
    endcase
end



// Sequential
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 9; i = i + 1) begin
            buff[i] <= 0;
            for(j = 0; j < 9; j = j + 1) begin
                grid[i][j]      <= 0;
            end
        end
        input_counter  <= 0;
        output_counter <= 0;
        out            <= 0;
        out_valid      <= 0;
        hs_u           <= 0;
        hs_wrote_any   <= 0;
        
    end else begin
        grid           <= grid_n;
        input_counter  <= input_counter_n;
        out            <= out_n;
        out_valid      <= out_valid_n;
        output_counter <= output_counter_n;
        hs_u           <= hs_u_n;
        hs_wrote_any   <= hs_wrote_any_n;
        buff           <= buff_n;
    end
end


// Combinational
always @(*) begin
    grid_n            = grid;
    input_counter_n   = input_counter;
    out_n             = out;
    out_valid_n       = 1'b0;
    single_success    = 0;
    output_counter_n  = output_counter;
    encoder_in        = 0;
    decoder_in        = 0;
    hs_u_n            = hs_u;
    hs_wrote_any_n    = hs_wrote_any;
    buff_n            = buff;
    for(i = 0; i < 9; i = i + 1) begin
        for(j = 0; j < 9; j = j + 1) begin
            candidate_n[i][j] = 0;
            
        end
    end

    for(i = 0; i < 9; i = i + 1) begin
        hs_m[i] = 0;
    end

    if(cs == IDLE) begin
        for(i = 0; i < 9; i = i + 1) begin
            for(j = 0; j < 9; j = j + 1) begin
                grid_n[i][j]      = 0;
                candidate_n[i][j] = 0;
                
            end
        end
        input_counter_n   = 0;
        output_counter_n  = 0;
        out_n = 0;


        if(in_valid) begin
            encoder_in = in;
            grid_n[8][8] = encoder_out;
            input_counter_n = input_counter + 1;
        end
    end

    if(cs == INPUT) begin
        input_counter_n = input_counter + 1;
        encoder_in   = in;
        grid_n[8][8] = encoder_out;
        if(input_counter < 81) begin
            for(i = 0; i < 9; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    grid_n[i][j] = grid[i][j+1];
                end
            end
            for(i = 0; i < 8; i = i + 1) begin
                grid_n[i][8] = grid[i+1][0]; 
            end
        end else begin
            input_counter_n = 0;
        end
    end


    if(cs == ELIM) begin
        single_success = 0;
        for(i = 0; i < 9; i = i + 1) begin
            for(j = 0; j < 9; j = j + 1) begin
                candidate_n[i][j] = (grid[i][j]==9'b0) ? ~(row[i] | col[j] | box[i/3][j/3]) : 9'b0;
                if(check_single[i][j] == 1) begin
                    grid_n[i][j]     = candidate_n[i][j];
                    single_success   = 1;
                end
            end
        end

        if(!single_success) begin
            hs_u_n         = 5'd0;
            hs_wrote_any_n = 1'b0;
        end
    end

    if (cs == HS) begin
        // === SELECT 9 CELLS OF THE CURRENT UNIT (no div/mod/mul) ===
        r0=0; c0=0; r1=0; c1=1; r2=0; c2=2; r3=0; c3=3; r4=0; c4=4;
        r5=0; c5=5; r6=0; c6=6; r7=0; c7=7; r8=0; c8=8;

        if (hs_u < 5'd9) begin
            // row
            r0=hs_u; c0=0;  r1=hs_u; c1=1;  r2=hs_u; c2=2;
            r3=hs_u; c3=3;  r4=hs_u; c4=4;  r5=hs_u; c5=5;
            r6=hs_u; c6=6;  r7=hs_u; c7=7;  r8=hs_u; c8=8;

        end else if (hs_u < 5'd18) begin
            // column
            r0=0; c0=hs_u-5'd9;  r1=1; c1=hs_u-5'd9;  r2=2; c2=hs_u-5'd9;
            r3=3; c3=hs_u-5'd9;  r4=4; c4=hs_u-5'd9;  r5=5; c5=hs_u-5'd9;
            r6=6; c6=hs_u-5'd9;  r7=7; c7=hs_u-5'd9;  r8=8; c8=hs_u-5'd9;

        end else begin

            case (hs_u) 
            5'd18: begin br=4'd0; bc=4'd0; end
            5'd19: begin br=4'd0; bc=4'd3; end
            5'd20: begin br=4'd0; bc=4'd6; end
            5'd21: begin br=4'd3; bc=4'd0; end
            5'd22: begin br=4'd3; bc=4'd3; end
            5'd23: begin br=4'd3; bc=4'd6; end
            5'd24: begin br=4'd6; bc=4'd0; end
            5'd25: begin br=4'd6; bc=4'd3; end
            default/*5'd26*/: begin br=4'd6; bc=4'd6; end
            endcase

            r0=br+0; c0=bc+0;  r1=br+0; c1=bc+1;  r2=br+0; c2=bc+2;
            r3=br+1; c3=bc+0;  r4=br+1; c4=bc+1;  r5=br+1; c5=bc+2;
            r6=br+2; c6=bc+0;  r7=br+2; c7=bc+1;  r8=br+2; c8=bc+2;
        end

        // === FEED SNAPSHOT CANDIDATES ===
        hs_m[0] = (grid[r0][c0]==9'b0) ? ~(row[r0] | col[c0] | box[r0/3][c0/3]) : 9'b0;
        hs_m[1] = (grid[r1][c1]==9'b0) ? ~(row[r1] | col[c1] | box[r1/3][c1/3]) : 9'b0;
        hs_m[2] = (grid[r2][c2]==9'b0) ? ~(row[r2] | col[c2] | box[r2/3][c2/3]) : 9'b0;
        hs_m[3] = (grid[r3][c3]==9'b0) ? ~(row[r3] | col[c3] | box[r3/3][c3/3]) : 9'b0;
        hs_m[4] = (grid[r4][c4]==9'b0) ? ~(row[r4] | col[c4] | box[r4/3][c4/3]) : 9'b0;
        hs_m[5] = (grid[r5][c5]==9'b0) ? ~(row[r5] | col[c5] | box[r5/3][c5/3]) : 9'b0;
        hs_m[6] = (grid[r6][c6]==9'b0) ? ~(row[r6] | col[c6] | box[r6/3][c6/3]) : 9'b0;
        hs_m[7] = (grid[r7][c7]==9'b0) ? ~(row[r7] | col[c7] | box[r7/3][c7/3]) : 9'b0;
        hs_m[8] = (grid[r8][c8]==9'b0) ? ~(row[r8] | col[c8] | box[r8/3][c8/3]) : 9'b0;

        // === APPLY UPDATES (NO PRINT) ===
        if (hs_own[0] != 9'b0) grid_n[r0][c0] = hs_own[0];
        if (hs_own[1] != 9'b0) grid_n[r1][c1] = hs_own[1];
        if (hs_own[2] != 9'b0) grid_n[r2][c2] = hs_own[2];
        if (hs_own[3] != 9'b0) grid_n[r3][c3] = hs_own[3];
        if (hs_own[4] != 9'b0) grid_n[r4][c4] = hs_own[4];
        if (hs_own[5] != 9'b0) grid_n[r5][c5] = hs_own[5];
        if (hs_own[6] != 9'b0) grid_n[r6][c6] = hs_own[6];
        if (hs_own[7] != 9'b0) grid_n[r7][c7] = hs_own[7];
        if (hs_own[8] != 9'b0) grid_n[r8][c8] = hs_own[8];

        // record if this round made any write
        hs_wrote_any_n = hs_wrote_any | hs_any;

        // next unit
        hs_u_n = (hs_u == 5'd26) ? 5'd26 : (hs_u + 5'd1);
    end

    if(cs == OUT) begin
        out_valid_n = 1'b1;
        decoder_in  = grid[0][0];
        out_n       = decoder_out;

        if(output_counter < 7'd80) begin
            output_counter_n = output_counter + 7'd1;

            for(i = 0; i < 9; i = i + 1) begin
                for(j = 0; j < 8; j = j + 1) begin
                    grid_n[i][j] = grid[i][j+1];
                end
            end
            for(i = 0; i < 8; i = i + 1) begin
                grid_n[i][8] = grid[i+1][0];
            end
        end
    end
end

endmodule

module encoder (
    input      [3:0] in,
    output reg [8:0] out
);


always @(*) begin
    case (in)
        4'd0: out = 9'b000000000;
        4'd1: out = 9'b000000001;
        4'd2: out = 9'b000000010;
        4'd3: out = 9'b000000100;
        4'd4: out = 9'b000001000;
        4'd5: out = 9'b000010000;
        4'd6: out = 9'b000100000;
        4'd7: out = 9'b001000000;
        4'd8: out = 9'b010000000;
        4'd9: out = 9'b100000000;
        default:
              out = 9'b000000000;
    endcase
end    
endmodule

module decoder (
    input      [8:0] in,
    output reg [3:0] out
);

always @(*) begin
    case (in)
        9'b000000000: out = 4'd0; 
        9'b000000001: out = 4'd1; 
        9'b000000010: out = 4'd2; 
        9'b000000100: out = 4'd3; 
        9'b000001000: out = 4'd4; 
        9'b000010000: out = 4'd5; 
        9'b000100000: out = 4'd6; 
        9'b001000000: out = 4'd7; 
        9'b010000000: out = 4'd8; 
        9'b100000000: out = 4'd9; 
        default:
                      out = 4'd0;
    endcase
end
endmodule


module HS_Verifier (
  input  [8:0] m0, input [8:0] m1, input [8:0] m2,
  input  [8:0] m3, input [8:0] m4, input [8:0] m5,
  input  [8:0] m6, input [8:0] m7, input [8:0] m8,
  output [8:0] own0, output [8:0] own1, output [8:0] own2,
  output [8:0] own3, output [8:0] own4, output [8:0] own5,
  output [8:0] own6, output [8:0] own7, output [8:0] own8,
  output       any_hit
);
  integer k;
  reg [8:0] seen1, seen2, unique_bits;
  reg [8:0] mm [0:8];

  always @* begin
    mm[0]=m0; mm[1]=m1; mm[2]=m2; mm[3]=m3; mm[4]=m4;
    mm[5]=m5; mm[6]=m6; mm[7]=m7; mm[8]=m8;

    seen1 = 9'b0;
    seen2 = 9'b0;
    for (k=0;k<9;k=k+1) begin
      seen2 = seen2 | (seen1 & mm[k]); 
      seen1 = seen1 ^  mm[k]; 
    end
    unique_bits = seen1 & ~seen2; 
  end

  assign own0 = m0 & unique_bits;
  assign own1 = m1 & unique_bits;
  assign own2 = m2 & unique_bits;
  assign own3 = m3 & unique_bits;
  assign own4 = m4 & unique_bits;
  assign own5 = m5 & unique_bits;
  assign own6 = m6 & unique_bits;
  assign own7 = m7 & unique_bits;
  assign own8 = m8 & unique_bits;

  assign any_hit = |(own0 | own1 | own2 | own3 | own4 | own5 | own6 | own7 | own8);
endmodule
