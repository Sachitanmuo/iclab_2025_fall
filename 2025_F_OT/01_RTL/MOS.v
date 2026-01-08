//############################################################################

//############################################################################

module MOS(
  // Input Port
  rst_n, 
  clk, 
  matrix_size,
  in_valid,
  in_data,
    
    
  // Output Port
  out_valid,
  out_data
);
//==============================================//
//                   PARAMETER                  //
//==============================================//

integer i,j,k;

parameter  IDLE  = 0,
           INPUT = 1,
           CALC_4 = 2,
           CALC_8 = 3,
           OUTPUT = 4;
//==============================================//
//                   I/O PORTS                  //
//==============================================//
input rst_n, clk, matrix_size,in_valid;
input signed[15:0] in_data;
output reg                  out_valid;
output reg signed[39:0]      out_data;
//==============================================//
//            reg & wire declaration            //
//==============================================//

reg [2:0] cs, ns;
reg [7:0] in_ctr, in_ctr_n;
reg [7:0] out_ctr, out_ctr_n;
reg  matrix_size_reg;
reg  matrix_size_n;
reg signed [15:0] weight [0:7][0:7];
reg signed [15:0] weight_n [0:7][0:7];
reg signed [15:0] calc   [0:7][0:7];
reg signed [15:0] calc_n   [0:7][0:7];
reg signed [39:0] store   [0:7][0:7];
reg signed [39:0] store_n [0:7][0:7];

reg signed [15:0] multa [0:7][0:7];
reg signed [15:0] multa_n [0:7][0:7];
reg signed [15:0] multb [0:7][0:7];
reg signed [15:0] multb_n [0:7][0:7];
reg [4:0] idx_x;
reg [4:0] idx_x_n;
reg [4:0] idx_y;
reg [4:0] idx_y_n;
reg [6:0] calc_idx_n;
reg [6:0] calc_idx;

reg out_valid_n;
reg [39:0] out_data_n;
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
        ns = INPUT;
      end else begin
        ns = cs;
      end
    end
    INPUT: begin
      if(in_ctr == 31 && matrix_size_reg == 0) begin
         ns = CALC_4;
      end else if(in_ctr == 127 && matrix_size_reg == 1) begin
         ns = CALC_8;
      end else begin
         ns = cs;
      end

    end

    CALC_4: begin
        if(calc_idx == 10) begin
           ns = OUTPUT;
        end else begin
          ns = cs;
        end
      end

    CALC_8: begin
      if(calc_idx == 19) begin
           ns = OUTPUT;
        end else begin
          ns = cs;
        end
    end

    OUTPUT: begin
      if(out_ctr  == 6 && matrix_size_reg == 0) begin
          ns = IDLE;
      end else if(out_ctr  == 14 && matrix_size_reg == 1) begin
          ns = IDLE;
      end else begin
        ns = cs;
      end
    end
  endcase
end 

always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    for(i = 0; i < 8; i = i + 1) begin
      for(j = 0; j < 8; j = j + 1) begin
          store[i][j] <= 0;
          weight[i][j] <= 0;
          calc[i][j] <= 0;
          multa[i][j] <= 0;
          multb[i][j] <= 0;
      end
    end
    in_ctr  <= 0;
    matrix_size_reg <= 0;
    out_valid <= 0;
    out_data <= 0;
    idx_x <= 0;
    idx_y <= 0;
    calc_idx <= 0;
    out_ctr <= 0;
  end else begin
        store <=  store_n;
        weight <= weight_n;
        calc   <= calc_n;
        matrix_size_reg <= matrix_size_n;
        in_ctr <= in_ctr_n;
        out_valid <= out_valid_n;
        out_data <= out_data_n;
        idx_x <= idx_x_n;
        idx_y <= idx_y_n;
        calc_idx <= calc_idx_n;
        multa <= multa_n;
        multb <= multb_n;
        out_ctr <= out_ctr_n;
  end

end


always @(*) begin
  store_n = store;
  weight_n = weight;
  calc_idx_n = calc_idx;
  matrix_size_n = matrix_size_reg;
  in_ctr_n  = in_ctr;
  multa_n = multa;
  multb_n = multb;
  idx_x_n = idx_x;
  idx_y_n = idx_y;
  out_valid_n = 0;
  out_data_n = 0;
  out_ctr_n = out_ctr;
  calc_n = calc;
  if(cs == IDLE) begin
    for(i = 0; i < 8; i = i + 1) begin
      for(j = 0; j < 8; j = j + 1) begin
          store_n[i][j] = 0;
          weight_n[i][j] = 0;
          calc_n[i][j] = 0;
          multa_n[i][j] = 0;
          multb_n[i][j] = 0;
      end
    end
    in_ctr_n = 0;
    matrix_size_n = 0;
    out_ctr_n = 0;
    if(in_valid) begin
        matrix_size_n = matrix_size;
        idx_x_n = 0;
        idx_y_n = 1;
        weight_n[0][0] = in_data;
        in_ctr_n = 1;
    end
  end

  if(cs == INPUT) begin
    in_ctr_n = in_ctr + 1;
    if(matrix_size_reg == 0) begin
       if(idx_y == 3) begin
          idx_y_n = 0;
          if(idx_x == 3) begin
            idx_x_n = 0;
          end else begin
            idx_x_n = idx_x + 1;
          end
       end else begin
          idx_y_n = idx_y + 1; 
       end
       if(in_ctr < 16) begin
          weight_n[idx_x][idx_y] = in_data;
       end else begin
          calc_n[idx_x][idx_y] = in_data;
       end
       if(in_ctr == 31) begin
          multa_n[0][0] = weight[0][0];
          multb_n[0][0]  = calc[0][0];
          calc_idx_n = 1;
            weight_n[0][3] =  0;
            calc_n[3][0]   =  0;
            for(j = 0; j < 3; j = j + 1) begin
              weight_n[0][j]   =  weight[0][j+1];
              calc_n[j][0]   =  calc[j+1][0];
            end
       end
    end else begin
      if(idx_y == 7) begin
          idx_y_n = 0;
          if(idx_x == 7) begin
            idx_x_n = 0;
          end else begin
            idx_x_n = idx_x + 1;
          end
      end else begin
        idx_y_n = idx_y + 1;
      end

       if(in_ctr < 64) begin
          weight_n[idx_x][idx_y] = in_data;
       end else begin
          calc_n[idx_x][idx_y] = in_data;
       end

       if(in_ctr == 127) begin
          multa_n[0][0] = weight[0][0];
          multb_n[0][0]  = calc[0][0];
          calc_idx_n = 1;
            weight_n[0][7] =  0;
            calc_n[7][0]   =  0;
            for(j = 0; j < 7; j = j + 1) begin
              weight_n[0][j]   =  weight[0][j+1];
              calc_n[j][0]   =  calc[j+1][0];
            end
       end
    end
  end

  if(cs == CALC_4) begin
    calc_idx_n = calc_idx + 1;
      for(i = 0; i < 4; i = i + 1) begin
        for(j = 0; j < 4; j = j + 1) begin
          store_n[i][j] = store[i][j] + multa[i][j] * multb[i][j];
        end
      end

      for(i = 0; i < 4; i = i + 1) begin
        multa_n[i][0] = i <= calc_idx ? weight[i][0]: 0;
        multb_n[0][i] = i <= calc_idx ? calc[0][i]: 0;
        for(j = 1; j < 4; j = j + 1) begin
          multa_n[i][j] = multa[i][j-1];
          multb_n[j][i] = multb[j-1][i];
        end
      end

      //input shift
      for(i = 0; i < 4; i = i + 1) begin
        weight_n[i][3] = i <= calc_idx ? 0 : weight[i][3];
        calc_n[3][i]   = i <= calc_idx ? 0 : calc[3][i];
        for(j = 0; j < 3; j = j + 1) begin
          weight_n[i][j]   =  i <= calc_idx ? weight[i][j+1] : weight[i][j];
          calc_n[j][i]   =  i <= calc_idx ? calc[j+1][i] : calc[j][i];
        end
      end

      if(calc_idx == 10) begin
        out_valid_n = 1;
        out_data_n = store[0][0];
        out_ctr_n = 1;
      end
      
  end


  if(cs == CALC_8 || cs == OUTPUT) begin
    calc_idx_n = calc_idx + 1;
      for(i = 0; i < 8; i = i + 1) begin
        for(j = 0; j < 8; j = j + 1) begin
          store_n[i][j] = store[i][j] + multa[i][j] * multb[i][j];
        end
      end

      for(i = 0; i < 8; i = i + 1) begin
        multa_n[i][0] = i <= calc_idx ? weight[i][0]: 0;
        multb_n[0][i] = i <= calc_idx ? calc[0][i]: 0;
        for(j = 1; j < 8; j = j + 1) begin
          multa_n[i][j] = multa[i][j-1];
          multb_n[j][i] = multb[j-1][i];
        end
      end

      //input shift
      for(i = 0; i < 8; i = i + 1) begin
        weight_n[i][7] = i <= calc_idx ? 0 : weight[i][7];
        calc_n[7][i]   = i <= calc_idx ? 0 : calc[7][i];
        for(j = 0; j < 7; j = j + 1) begin
          weight_n[i][j]   =  i <= calc_idx ? weight[i][j+1] : weight[i][j];
          calc_n[j][i]   =  i <= calc_idx ? calc[j+1][i] : calc[j][i];
        end
      end

      if(calc_idx == 19) begin
        out_valid_n = 1;
        out_data_n = store[0][0];
        out_ctr_n = 1;
      end
  end
  if(cs == OUTPUT) begin
    if(matrix_size_reg == 0) begin
      out_ctr_n = out_ctr + 1;
      out_valid_n = 1;
      if(out_ctr == 1) begin
        out_data_n = store[0][1] + store[1][0];
      end
      if(out_ctr == 2) begin
        out_data_n = store[0][2] + store[1][1] + store[2][0];
      end
      if(out_ctr == 3) begin
        out_data_n = store[0][3] + store[1][2] + store[2][1] + store[3][0];
      end
      if(out_ctr == 4) begin
        out_data_n = store[1][3] + store[2][2] + store[3][1];
      end
      if(out_ctr == 5) begin
        out_data_n = store[2][3] + store[3][2];
      end
      if(out_ctr == 6) begin
        out_data_n = store[3][3];
      end
    end else begin
      out_ctr_n = out_ctr + 1;
      out_valid_n = 1;
      if(out_ctr == 1) begin
        out_data_n = store[0][1] + store[1][0];
      end
      if(out_ctr == 2) begin
        out_data_n = store[0][2] + store[1][1] + store[2][0];
      end
      if(out_ctr == 3) begin
        out_data_n = store[0][3] + store[1][2] + store[2][1] + store[3][0];
      end
      if(out_ctr == 4) begin
        out_data_n = store[0][4] + store[1][3] + store[2][2] + store[3][1] + store[4][0];
      end
      if(out_ctr == 5) begin
        out_data_n = store[0][5] + store[1][4] + store[2][3] + store[3][2] + store[4][1] + store[5][0];
      end
      if(out_ctr == 6) begin
        out_data_n = store[0][6] + store[1][5] + store[2][4] + store[3][3] + store[4][2] + store[5][1] + store[6][0];
      end
      if(out_ctr == 7) begin
        out_data_n = store[0][7] + store[1][6] + store[2][5] + store[3][4] + store[4][3] + store[5][2] + store[6][1] + store[7][0];
      end
      if(out_ctr == 8) begin
        out_data_n = store[1][7] + store[2][6] + store[3][5] + store[4][4] + store[5][3] + store[6][2] + store[7][1];
      end
      if(out_ctr == 9) begin
        out_data_n = store[2][7] + store[3][6] + store[4][5] + store[5][4] + store[6][3] + store[7][2];
      end
      if(out_ctr == 10) begin
        out_data_n = store[3][7] + store[4][6] + store[5][5] + store[6][4] + store[7][3];
      end
      if(out_ctr == 11) begin
        out_data_n = store[4][7] + store[5][6] + store[6][5] + store[7][4];
      end
      if(out_ctr == 12) begin
        out_data_n = store[5][7] + store[6][6] + store[7][5];
      end
      if(out_ctr == 13) begin
        out_data_n = store[6][7] + store[7][6];
      end
      if(out_ctr == 14) begin
        out_data_n = store[7][7];
      end
    end
  end
end
endmodule

