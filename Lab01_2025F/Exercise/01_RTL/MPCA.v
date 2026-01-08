module MPCA(
    // Input signals
    input [127:0] packets,
    input  [11:0] channel_load,
    input   [8:0] channel_capacity,
    input  [63:0] KEY,
    // Output signals
    output reg [15:0] grant_channel
);

//================================================================
//    Wire & Registers 
//================================================================
// Declare the wire/reg you would use in your circuit
// remember 
// wire for port connection and cont. assignment
// reg for proc. assignment
wire [15:0] pkt [0:7];
genvar p;
generate
  for (p = 0; p < 8; p = p + 1) begin
    assign pkt[p] = packets[16*p +: 16];
  end
endgenerate

// initialization to generate key
wire [15:0] k0;
wire [15:0] l[0:2];

assign k0   = KEY[15:0];
assign l[0] = KEY[31:16];
assign l[1] = KEY[47:32];
assign l[2] = KEY[63:48];

integer r, a, b;



//================================================================
//    DESIGN
//================================================================

// subkey scheduling for 4 rounds

reg  [15:0] round_keys [0:3];
reg  [15:0] k[0:3];
reg  [15:0] lreg[0:2];

always @* begin
  // r = 0
  k[0] = k0;
  round_keys[0] = k[0];

  // r = 1
  k[1] = ({k[0][6:0], k[0][15:7]} + l[0]);
  round_keys[1] = k[1];

  // r = 2
  k[2] = ({k[1][6:0], k[1][15:7]} + l[1]) ^ 16'd1;
  round_keys[2] = k[2];

  // r = 3
  k[3] = ({k[2][6:0], k[2][15:7]} + l[2]) ^ 16'd2;
  round_keys[3] = k[3];

end


// 4 rounds
reg [15:0] x0[0:3] ,y0[0:3];
reg [15:0] x1[0:3] ,y1[0:3];
reg [15:0] x2[0:3] ,y2[0:3];
reg [15:0] x3[0:3] ,y3[0:3];
reg [15:0] x4[0:3], y4[0:3];
reg [15:0] tmp;

always @(*) begin
  x4[0] = pkt[0]; y4[0] = pkt[1];
  x4[1] = pkt[2]; y4[1] = pkt[3];
  x4[2] = pkt[4]; y4[2] = pkt[5];
  x4[3] = pkt[6]; y4[3] = pkt[7];
end


always @(*) begin
    for(b = 0; b < 4; b = b + 1) begin
        // -------- r = 3 --------
        tmp   = y4[b] ^ x4[b];
        y3[b] = {tmp[1:0], tmp[15:2]}; 

        tmp   = (x4[b] ^ round_keys[3]) - y3[b];
        x3[b] = {tmp[8:0], tmp[15:9]};

        // -------- r = 2 --------
        tmp   = y3[b] ^ x3[b];
        y2[b] = {tmp[1:0], tmp[15:2]}; 

        tmp   = (x3[b] ^ round_keys[2]) - y2[b];
        x2[b] = {tmp[8:0], tmp[15:9]};

        // -------- r = 1 --------
        tmp   = y2[b] ^ x2[b];
        y1[b] = {tmp[1:0], tmp[15:2]};

        tmp   = (x2[b] ^ round_keys[1]) - y1[b];
        x1[b] = {tmp[8:0], tmp[15:9]};

        // -------- r = 0 --------
        tmp   = y1[b] ^ x1[b];
        y0[b] = {tmp[1:0], tmp[15:2]};

        tmp   = (x1[b] ^ round_keys[0]) - y0[b];
        x0[b] = {tmp[8:0], tmp[15:9]};
    end
end

wire [15:0] pkt_plain [0:7];
assign pkt_plain[0] = x0[0];
assign pkt_plain[1] = y0[0];
assign pkt_plain[2] = x0[1];
assign pkt_plain[3] = y0[1];
assign pkt_plain[4] = x0[2];
assign pkt_plain[5] = y0[2];
assign pkt_plain[6] = x0[3];
assign pkt_plain[7] = y0[3];


//================================================================
//    SCORING
//================================================================
wire        req   [0:7];
wire [1:0]  pref  [0:7];
wire signed [6:0] score [0:7];
wire [2:0]  index [0:7];
wire [2:0]  src   [0:7];

genvar i;
generate
  for (i = 0; i < 8; i = i + 1) begin
    assign index[i] = i[2:0];  // record packet index
    ScoreUnit u_score (
      .packet(pkt_plain[i]),
      .req(req[i]),
      .pref(pref[i]),
      .src(src[i]),
      .score(score[i])
    );
  end
endgenerate

//================================================================
//    SORTING
//================================================================
wire signed [6:0] score_sorted [0:7];
wire [2:0]        index_sorted [0:7];
wire [1:0]        pref_sorted  [0:7];
wire              req_sorted   [0:7];
wire [2:0]        src_sorted   [0:7];

Sort_v2 u_sort (
  .score_in(score),
  .index_in(index),
  .pref_in(pref),
  .req_in(req),
  .src_in(src),

  .score_out(score_sorted),
  .index_out(index_sorted),
  .pref_out(pref_sorted),
  .req_out(req_sorted),
  .src_out(src_sorted)
);


//================================================================
//    MASK CALC
//================================================================

reg mask_value [0:7];


reg [1:0] allocation [0:7];
reg [5:0] allocated_load [0:2];
reg [5:0] allocated_capacity [0:2];
Allocation alloc(.score(score_sorted), .pref(pref_sorted), .req(req_sorted), .channel_load(channel_load), .channel_capacity(channel_capacity), .allocation(allocation), .allocated_load(allocated_load), .index(index_sorted), .allocated_capacity(allocated_capacity));
MASK masker(.score(score_sorted), .pref(pref_sorted), .src(src_sorted), .channel_load(channel_load), .allocated_load(allocated_load), .mask_val(mask_value), .allocation(allocation));


//================================================================
//    GLOBAL REBALANCE & OUTPUT
//================================================================


reg [1:0] max_ch;
reg [1:0] allocation_rb [0:7];
reg [7:0] filtered_allocation [2:0];
reg [2:0] rebalance_index     [2:0]; //the rebalance target of each
reg valid [2:0]; //record whether can move a packet from target channel

reg channel_full [2:0];

// pre calculate load sum
wire check_sum [0:2];

assign check_sum[0] = (allocated_load[0] << 1) > allocated_load[1] + allocated_load[2];
assign check_sum[1] = (allocated_load[1] << 1) > allocated_load[0] + allocated_load[2];
assign check_sum[2] = (allocated_load[2] << 1) > allocated_load[0] + allocated_load[1];




always @(*) begin
  // === STEP 1: filter / channel_full ===
  for(a= 0; a < 3; a = a + 1) begin
    for (b = 0; b < 8; b = b + 1) begin
      filtered_allocation[a][b] = (mask_value[b]) && (allocation[b] == a);
    end
    channel_full[a] = (allocated_load[a] < 15) && (allocated_capacity[a] > 0) ? 0 : 1;

  end

  // === STEP 2: default assignment ===
  for (b = 0; b < 8; b = b + 1) begin
      allocation_rb[b] = allocation[b];
  end

  // === STEP 3: choose candidate per channel ===
  for(a = 0; a < 3; a = a + 1) begin
    casex (filtered_allocation[a])
      8'b1xxxxxxx: begin rebalance_index[a] = 7;  valid[a] = 1; end
      8'b01xxxxxx: begin rebalance_index[a] = 6;  valid[a] = 1; end
      8'b001xxxxx: begin rebalance_index[a] = 5;  valid[a] = 1; end
      8'b0001xxxx: begin rebalance_index[a] = 4;  valid[a] = 1; end
      8'b00001xxx: begin rebalance_index[a] = 3;  valid[a] = 1; end
      8'b000001xx: begin rebalance_index[a] = 2;  valid[a] = 1; end
      8'b0000001x: begin rebalance_index[a] = 1;  valid[a] = 1; end
      8'b00000001: begin rebalance_index[a] = 0;  valid[a] = 1; end
      8'b00000000: begin rebalance_index[a] = 0;  valid[a] = 0; end
      default:     begin rebalance_index[a] = 7;  valid[a] = 0; end
    endcase

  end

  // === STEP 4: find max channel ===
  if (allocated_load[0] >= allocated_load[1]) begin
    if (allocated_load[0] >= allocated_load[2])
      max_ch = 0;
    else
      max_ch = 2;
  end else begin
    if (allocated_load[1] >= allocated_load[2])
      max_ch = 1;
    else
      max_ch = 2;
  end


  // === STEP 5: rebalance decision ===
  case (max_ch)
    0: begin
      if(check_sum[0]) begin
        if(valid[0]) begin
          if(!channel_full[1]) begin
            allocation_rb[rebalance_index[0]] = 1;
            //$display("Rebalance: move pkt%0d from CH0 -> CH1", rebalance_index[0]);
          end else if(!channel_full[2]) begin
            allocation_rb[rebalance_index[0]] = 2;
            //$display("Rebalance: move pkt%0d from CH0 -> CH2", rebalance_index[0]);
          end else begin
            allocation_rb[rebalance_index[0]] = 3;
            //$display("Rebalance: drop pkt%0d from CH0", rebalance_index[0]);
          end
        end 
      end
    end
    1: begin
      if(check_sum[1]) begin
        if(valid[1]) begin
          if(!channel_full[2]) begin
            allocation_rb[rebalance_index[1]] = 2;
            //$display("Rebalance: move pkt%0d from CH1 -> CH2", rebalance_index[1]);
          end else if(!channel_full[0]) begin
            allocation_rb[rebalance_index[1]] = 0;
            //$display("Rebalance: move pkt%0d from CH1 -> CH0", rebalance_index[1]);
          end else begin
            allocation_rb[rebalance_index[1]] = 3;
            //$display("Rebalance: drop pkt%0d from CH1", rebalance_index[1]);
          end
        end
      end
    end
    2: begin
      if(check_sum[2]) begin
        if(valid[2]) begin
          if(!channel_full[0]) begin
            allocation_rb[rebalance_index[2]] = 0;
            //$display("Rebalance: move pkt%0d from CH2 -> CH0", rebalance_index[2]);
          end else if(!channel_full[1]) begin
            allocation_rb[rebalance_index[2]] = 1;
            //$display("Rebalance: move pkt%0d from CH2 -> CH1", rebalance_index[2]);
          end else begin
            allocation_rb[rebalance_index[2]] = 3;
            //$display("Rebalance: drop pkt%0d from CH2", rebalance_index[2]);
          end
        end
      end
    end
  endcase

end

reg [1:0] grant_channel_r [0:7];

always @(*) begin
  for (r = 0; r < 8; r = r + 1) begin
    case (r)
      index_sorted[0]: grant_channel_r[r] = allocation_rb[0];
      index_sorted[1]: grant_channel_r[r] = allocation_rb[1];
      index_sorted[2]: grant_channel_r[r] = allocation_rb[2];
      index_sorted[3]: grant_channel_r[r] = allocation_rb[3];
      index_sorted[4]: grant_channel_r[r] = allocation_rb[4];
      index_sorted[5]: grant_channel_r[r] = allocation_rb[5];
      index_sorted[6]: grant_channel_r[r] = allocation_rb[6];
      index_sorted[7]: grant_channel_r[r] = allocation_rb[7];
      default:  grant_channel_r[r] = 2'b11;
    endcase
  end
end

assign grant_channel = {grant_channel_r[7], grant_channel_r[6], grant_channel_r[5], grant_channel_r[4],
                        grant_channel_r[3], grant_channel_r[2], grant_channel_r[1], grant_channel_r[0]};


endmodule

module Allocation (
  input signed [6:0] score   [0:7],
  input        [2:0] index   [0:7],
  input [1:0]  pref          [0:7],
  input        req           [0:7],
  input [11:0] channel_load,
  input [8:0]  channel_capacity,


  output reg [1:0] allocation [0:7],
  output reg [5:0] allocated_load [0:2],
  output reg [5:0] allocated_capacity [0:2]
);


// per-channel load & cap
reg  [4:0] load         [0:2][0:8];
reg  [4:0] cap          [0:2][0:8];
reg  [1:0] pivot        [0:8];
reg        pivot_start  [0:8];

integer i, ch;

always @(*) begin
  load[0][0] = channel_load[3:0];
  load[1][0] = channel_load[7:4];
  load[2][0] = channel_load[11:8];
  cap[0][0] = channel_capacity[2:0];
  cap[1][0] = channel_capacity[5:3];
  cap[2][0] = channel_capacity[8:6];
  pivot_start[0] = 0;
  pivot[0] = 0;

  for(i = 0; i < 8; ++i) begin
    // initialize
    allocation[i] = 2'b11;
    for (ch=0; ch<3; ch=ch+1) begin
        load[ch][i+1] = load[ch][i];
        cap[ch][i+1]  = cap[ch][i];
    end
    pivot[i+1]       = pivot[i];
    pivot_start[i+1] = pivot_start[i];

    // =========
    if(req[i] == 0) begin
      allocation[i] = 2'b11;
      //$display("Packet %0d: req=0 -> unallocated, current pivot = %d", i, pivot[i]);
    end
    if(req[i] == 1 && cap[pref[i]][i] > 0) begin
         allocation[i] = pref[i];
         load[pref[i]][i+1] = load[pref[i]][i] + 1;
         cap[pref[i]][i+1]  = cap[pref[i]][i] - 1;
    end

    if(req[i] == 1 && cap[pref[i]][i] <= 0) begin
        // dynamic round-robin
        if(!pivot_start[i]) begin
          pivot[i] = pref[i];
          pivot_start[i+1] = 1;
          //$display("Packet %0d: first fallback -> set pivot=%0d", index[i], pivot[i]);
        end
        case (pivot[i])
          2'd0, 2'd3: begin
            if(cap[0][i] > 0) begin
              allocation[i] = 2'd0;
              load[0][i+1] = load[0][i] + 1;
              cap[0][i+1]  = cap[0][i] - 1;
              pivot[i+1]   = 1;
              //$display("Packet %0d: fallback to ch=0 success, pivot updated to %d", index[i], pivot[i+1]);
            end else if(cap[1][i] > 0) begin
              allocation[i] = 2'd1;
              load[1][i+1] = load[1][i] + 1;
              cap[1][i+1]  = cap[1][i] - 1;
              pivot[i+1]   = 1;
              //$display("Packet %0d: fallback to ch=1 success, pivot updated to %d", index[i], pivot[i+1]);
            end else if(cap[2][i] > 0) begin
              allocation[i] = 2'd2;
              load[2][i+1] = load[2][i] + 1;
              cap[2][i+1]  = cap[2][i] - 1;
              pivot[i+1]   = 1;
              //$display("Packet %0d: fallback to ch=2 success, pivot updated to %d", index[i], pivot[i+1]);
            end else begin
              allocation[i] = 2'b11;
              pivot[i+1]   = 2;
              //$display("Packet %0d: all channels full -> unallocated", index[i]);
            end
          end

          2'd1: begin
            if(cap[1][i] > 0) begin
              allocation[i] = 2'd1;
              load[1][i+1] = load[1][i] + 1;
              cap[1][i+1]  = cap[1][i] - 1;
              pivot[i+1]   = 2;
              //$display("Packet %0d: fallback to ch=1 success", index[i]);
            end else if(cap[2][i] > 0) begin
              allocation[i] = 2'd2;
              load[2][i+1] = load[2][i] + 1;
              cap[2][i+1]  = cap[2][i] - 1;
              pivot[i+1]   = 2;
              //$display("Packet %0d: fallback to ch=2 success", index[i]);
            end else if(cap[0][i] > 0) begin
              allocation[i] = 2'd0;
              load[0][i+1] = load[0][i] + 1;
              cap[0][i+1]  = cap[0][i] - 1;
              pivot[i+1]   = 2;
              //$display("Packet %0d: fallback to ch=0 success", index[i]);
            end else begin
              allocation[i] = 2'b11;
              pivot[i+1]   = 0;
              //$display("Packet %0d: all channels full -> unallocated", index[i]);
            end
          end

          2'd2: begin
            if(cap[2][i] > 0) begin
              allocation[i] = 2'd2;
              load[2][i+1] = load[2][i] + 1;
              cap[2][i+1]  = cap[2][i] - 1;
              pivot[i+1]   = 0;
              //$display("Packet %0d: fallback to ch=2 success", index[i]);
            end else if(cap[0][i] > 0) begin
              allocation[i] = 2'd0;
              load[0][i+1] = load[0][i] + 1;
              cap[0][i+1]  = cap[0][i] - 1;
              pivot[i+1]   = 0;
              //$display("Packet %0d: fallback to ch=0 success", index[i]);
            end else if(cap[1][i] > 0) begin
              allocation[i] = 2'd1;
              load[1][i+1] = load[1][i] + 1;
              cap[1][i+1]  = cap[1][i] - 1;
              pivot[i+1]   = 0;
              //$display("Packet %0d: fallback to ch=1 success", index[i]);
            end else begin
              allocation[i] = 2'b11;
              pivot[i+1]   = 1;
              //$display("Packet %0d: all channels full -> unallocated", index[i]);
            end
          end
        endcase
      end
    end

  for(i = 0; i < 3; ++i) begin
    allocated_load[i] = load[i][8]; // findal load
    allocated_capacity[i] = cap[i][8]; // findal capacity
  end
end


endmodule


module MASK (
  input signed [6:0] score   [0:7],
  input [1:0] pref           [0:7],
  input [2:0] src            [0:7],
  input [11:0] channel_load,
  input [5:0]  allocated_load [0:2],
  input [1:0]  allocation     [0:7],
  output reg mask_val        [0:7]
);

  reg [3:0] ch_load [7:0];
  reg [5:0] tmp     [7:0];
  reg [5:0] alloc_load; 
  wire [6:0] score_u [0:7];
  assign score_u = score;
  reg [4:0] thr;
  reg [3:0] msk; 



  integer i;
  always @(*) begin
    for(i = 0; i < 8; i = i + 1) begin
        mask_val[i] = 0;
        case (allocation[i])
          0: begin
            ch_load[i] = channel_load[3:0];
          end
          1: begin
            ch_load[i] = channel_load[7:4];
          end
          2: begin
            ch_load[i] = channel_load[11:8];            
          end 
          default: begin
            ch_load[i] = 0;
          end
        endcase 



        tmp[i] = ((score_u[i] & 3'd6) + pref[i]) + ((src[i] ^ 3'b011) + (ch_load[i]));
        if(tmp[i] >= 20) begin
          msk = tmp[i] - 20;
        end else if(tmp[i] >= 10) begin
          msk = tmp[i] - 10;
        end else begin
          msk = tmp[i];
        end



        case (ch_load[i])
          0,1,2:       thr = 7;
          3,4,5:       thr = 8;
          6,7,8:       thr = 9;
          9,10,11:     thr = 10;
          12,13,14:    thr = 11;
          15:          thr = 12;
          default:     thr = 7;
        endcase
        mask_val[i] = (msk < thr);

        if(allocation[i] == 3) mask_val[i] = 0;

    end

  end
  
endmodule



module ScoreUnit (
    input         [15:0]    packet,
    output                  req,
    output        [1:0]     pref,
    output        [2:0]     src,
    output signed [6:0]     score
);

  // -------- field decode --------
  assign req      = packet[15];
  wire [1:0] qos  = packet[14:13];
  wire [3:0] len  = packet[12:9];
  wire [1:0] cong = packet[8:7];
  assign pref     = packet[6:5];
  wire [2:0] src_  = packet[4:2];
  wire       mode = packet[1];

  wire signed [2:0]  qos_u  = qos; 
  wire signed [4:0]  len_u  = len;
  wire signed [2:0]  cong_u = cong; 
  wire signed [3:0]  src_u  = src; 


  wire signed [2:0]  qos_s  = {qos[1],  qos};
  wire signed [4:0]  len_s  = {len[3],  len};
  wire signed [2:0]  cong_s = {cong[1], cong}; 
  wire signed [3:0]  src_s  = {src[2],  src}; 


  wire signed [2:0]  qv  = (mode==1) ? qos_s  : qos_u;
  wire signed [4:0]  lv  = (mode==1) ? len_s  : len_u;
  wire signed [2:0]  cv  = (mode==1) ? cong_s : cong_u;
  wire signed [3:0]  sv  = (mode==1) ? src_s  : src_u;


  assign score = ((qv - 2) << 2)
             - ((lv - 8) << 1)
             - (cv + (cv << 1))
             + (sv - 1);

  assign src = src_;


endmodule



module Sort_v2 (
  input signed [6:0] score_in [0:7],
  input [2:0] index_in [0:7],
  input [1:0] pref_in [0:7],
  input       req_in [0:7],
  input [2:0] src_in [0:7],


  output signed [6:0] score_out [0:7],
  output [2:0] index_out [0:7],
  output [1:0] pref_out [0:7],
  output       req_out [0:7],
  output [2:0] src_out [0:7]
);
  wire signed [10:0] key [7:0];
  reg [3:0] rank [0:7];
  reg record[0:7][0:7];


  genvar i;
  generate
    for(i = 0; i < 8; i = i + 1) begin
        assign key[i] = {req_in[i], !score_in[i][6], score_in[i][5:0], ~index_in[i]};
    end
  endgenerate


  integer m,n;
  always @(*) begin
    for(m=0; m<8; m=m+1) begin
      rank[m] = 0;
      record[m][m] = 0;
      for(n=m+1; n<8; n=n+1) begin
        if(key[m] < key[n]) begin
          record[m][n] = 1;
          record[n][m] = 0;
        end else begin
          record[m][n] = 0;
          record[n][m] = 1;
        end
      end
    end

    for(m=0; m<8; m=m+1) begin
      rank[m] = ((record[m][0] + record[m][1]) + (record[m][2] + record[m][3])) + ((record[m][4] + record[m][5]) + (record[m][6] + record[m][7]));
    end
  end



  reg signed [8:0] score_tmp [0:7];
  reg [2:0] index_tmp [0:7];
  reg [1:0] pref_tmp  [0:7];
  reg       req_tmp   [0:7];
  reg [2:0] src_tmp   [0:7];

  always @(*) begin
    for (m=0; m<8; m=m+1) begin
      score_tmp[m] = 0;
      index_tmp[m] = 0;
      pref_tmp [m] = 0;
      req_tmp  [m] = 0;
      src_tmp  [m] = 0;
    end

    for(m=0; m<8; m=m+1) begin
      score_tmp[rank[m]] = score_in[m];
      index_tmp[rank[m]] = index_in[m];
      pref_tmp [rank[m]] = pref_in[m];
      req_tmp  [rank[m]] = req_in[m];
      src_tmp  [rank[m]] = src_in[m];
    end
  end


  generate
    for(i=0; i<8; i=i+1) begin
      assign score_out[i] = score_tmp[i];
      assign index_out[i] = index_tmp[i];
      assign pref_out[i]  = pref_tmp[i];
      assign req_out[i]   = req_tmp[i];
      assign src_out[i]   = src_tmp[i];
    end
  endgenerate


endmodule
