module HLPTE(
    // input signals
    clk,
    rst_n,
    in_valid_data,
    in_valid_param,
    
    data,
	index,
	mode,
    QP,
	
    // output signals
    out_valid,
    out_value
);

input                     clk;
input                     rst_n;
input                     in_valid_data;
input                     in_valid_param;

input              [7:0]  data;
input              [3:0]  index;
input                     mode;
input              [4:0]  QP;

output reg                out_valid;
output reg signed [31:0]  out_value;



//==================================================================
// parameter & integer
//==================================================================
parameter IDLE         = 4'd0,
          INPUT_DATA   = 4'd1,
          INPUT_PARAM  = 4'd2,
          UPDATE_PTR   = 4'd3,
          PRED         = 4'd4,
          PRED_16      = 4'd5,
          INT_TRAN     = 4'd6,
          QUANT        = 4'd7,
          INV_INT_TRAN = 4'd8;

parameter FF_WIDTH = 29, INT_TRAN_WIDTH = 27, QUANT_WIDTH = 14, DEQUANT_WIDTH = 15;

integer i, j, k;
//==================================================================
// reg & wire
//==================================================================
reg [3:0] current_state, next_state;
reg web            [0:3];
reg oe             [0:3];
reg cs             [0:3];
reg [9:0]  addr    [0:3];
reg [31:0] di      [0:3];
reg [31:0] do_     [0:3];
reg web_n          [0:3];
reg oe_n           [0:3];
reg cs_n           [0:3];
reg [9:0]  addr_n  [0:3];
reg [31:0] di_n    [0:3];
reg [31:0] do_n    [0:3];

reg out_valid_n;
reg signed [31:0] out_value_n;

reg [11:0] addr_idx;
reg [11:0] addr_idx_n;
reg [10:0] in_ctr;
reg [10:0] in_ctr_n;

reg [7:0] data_in    [0:3];
reg [7:0] data_in_n  [0:3];
reg [7:0] data_out   [0:3];
reg [7:0] data_out_n [0:3];
reg [31:0] mem_data_in;
assign mem_data_in = {data_in_n[0], data_in_n[1], data_in_n[2], data_in_n[3]};

reg [3:0] index_reg;
reg       mode_reg   [0:3];
reg [4:0] QP_reg;
reg [3:0] index_reg_n;
reg       mode_reg_n [0:3];
reg [4:0] QP_reg_n;
reg [2:0] param_ctr;
reg [2:0] param_ctr_n;
reg [4:0] pred_ctr;
reg [4:0] pred_ctr_n;

reg [1:0] pred_ctr2;
reg [1:0] pred_ctr2_n;
reg [1:0] int_ctr, int_ctr_n;
reg       to_pred, to_pred_16;
reg [7:0] top      [0:31];
reg [7:0] top_n    [0:31];
reg [7:0] left     [0:15];
reg [7:0] left_n   [0:15];

reg [2:0] block_row;
reg [2:0] block_row_n;
reg [2:0] block_col;
reg [2:0] block_col_n;
reg [5:0] block_ctr;
reg [5:0] block_ctr_n;
reg [4:0] row_offset;
reg [4:0] row_offset_n;
reg [4:0] col_offset;
reg [4:0] col_offset_n;
reg [1:0] row;
reg [1:0] row_n;
reg [1:0] col;
reg [1:0] col_n;
reg new_round, new_round_n;
reg pred_done, pred_16_done;
reg pred_16_done_reg;

reg signed [FF_WIDTH-1:0] map   [0:3][0:3];
reg signed [FF_WIDTH-1:0] map_n [0:3][0:3];
reg        has_top, has_top_n, has_left, has_left_n;

reg [127:0] ref_block;
reg [31:0]  top4;
reg [31:0]  left4;
reg ht, hl;
reg [15:0] sad_min;
reg [15:0] sad_dc;
reg [15:0] sad_h;
reg [15:0] sad_v;

reg [15:0] dc_acc;
reg [15:0] dc_acc_n;
reg [15:0] h_acc;
reg [15:0] h_acc_n;
reg [15:0] v_acc;
reg [15:0] v_acc_n;

reg [3:0]  pred16_step, pred16_step_n;
reg [15:0] predicted, predicted_n;
reg [1:0] dc_h_v;
reg [1:0] dc_h_v_n;
reg [1:0] dchv;

reg [7:0] dc_value;
reg [7:0] dc_value_n;
reg [7:0] dc_v;

reg [INT_TRAN_WIDTH * 16 - 1:0] x_flat;
reg [FF_WIDTH * 16 - 1:0] w_flat;
reg [4:0] image_ctr, image_ctr_n;

reg  [4:0] q_idx, q_idx_n;
reg  [4:0] dq_idx, dq_idx_n;
wire [1:0] q_row_w  = q_idx[3:2];
wire [1:0] q_col_w  = q_idx[1:0];
wire [1:0] dq_row_w = dq_idx[3:2];
wire [1:0] dq_col_w = dq_idx[1:0];
reg  [1:0] dq_row_w_last;
reg  [1:0] dq_col_w_last;
reg  signed [QUANT_WIDTH-1:0] q_coeff_in_w;
wire signed [FF_WIDTH-1:0]         q_z;
assign q_coeff_in_w = map[q_row_w][q_col_w][QUANT_WIDTH-1:0];
reg  signed [DEQUANT_WIDTH-1:0] q_z_d1, q_z_d1_n;


reg [127:0] top_16;
reg [127:0] left_16;
reg signed [FF_WIDTH-1:0] sum;
reg signed [FF_WIDTH-1:0] res [0:3][0:3];
reg pred_16_early;

reg [4:0] left_idx;
reg [4:0] top_idx;
reg [127:0] top16;
reg [127:0] left16;
reg [127:0] top16_n;
reg [127:0] left16_n;
reg intra_mode, intra_mode_n;

wire signed [FF_WIDTH-1:0] xhat_w; //dequant output


CAL_INTRA_4x4 #(.FF_WIDTH(FF_WIDTH)) u_intra44(
    .ref_blk(ref_block),
    .top4   (top4),
    .left4  (left4),
    .has_top(ht),
    .has_left(hl),
    .dc_value(dc_v),
    .out_dc(sad_dc),
    .out_v(sad_v),
    .out_h(sad_h),
    .dc_h_v(dchv),
    .mode(intra_mode),
    .left16(left_16),
    .top16(top_16)
);

INT_TRANSFORM #(.FF_WIDTH(FF_WIDTH), .INT_TRAN_WIDTH(INT_TRAN_WIDTH)) u_int_trans(
    .X_flat(x_flat),
    .W_flat(w_flat)
);

QUANT_CORE   #(.FF_WIDTH(FF_WIDTH), .QUANT_WIDTH(QUANT_WIDTH)) u_quant   (
    .coeff_in (q_coeff_in_w),
    .qp       (QP_reg),
    .row      (q_row_w),
    .col      (q_col_w),
    .mode     (dc_h_v),
    .z_out    (q_z)
);

DEQUANT_CORE #(.FF_WIDTH(FF_WIDTH), .DEQUANT_WIDTH(DEQUANT_WIDTH)) u_dequant (
    .z_in     (q_z_d1),
    .qp       (QP_reg),
    .row      (dq_row_w_last),
    .col      (dq_col_w_last),
    .mode     (dc_h_v),
    .xhat_out (xhat_w)
);



//reg [7:0]  
//==================================================================
// FSM
//==================================================================

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_state = IDLE;
    end else begin
        current_state = next_state;
    end
end

always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if(in_valid_data) next_state = INPUT_DATA;
            else              next_state = current_state;
        end

        INPUT_DATA: begin
            if(!in_valid_data) next_state = INPUT_PARAM;
            else               next_state = current_state;
        end

        INPUT_PARAM: begin
            if(param_ctr == 3) next_state = UPDATE_PTR;
            else               next_state = current_state;
        end

        UPDATE_PTR: begin
            if(to_pred_16)
                               next_state = PRED_16;
            else               next_state = PRED; 
        end

        PRED: begin
            if(pred_done)      next_state = INT_TRAN;
            else               next_state = current_state;
        end

        PRED_16: begin
            if(pred_16_done_reg || pred_16_early)
                                next_state = PRED;
            else                next_state = current_state;
        end

        INT_TRAN: begin
            if(int_ctr == 1)    next_state = QUANT;
            else                next_state = current_state; 
        end

        QUANT: begin
            if(q_idx == 16 && block_row == 7 && block_col == 7) begin
                if(image_ctr == 16)
                                next_state = IDLE;
                else            next_state = INPUT_PARAM;
            end
            else if(q_idx == 17)
                                next_state = INV_INT_TRAN;
            else                next_state = current_state; 
        end

        INV_INT_TRAN: begin
           if(int_ctr == 2)     next_state = UPDATE_PTR;
           else                 next_state = current_state;
        end

        
    endcase
end

//==================================================================
// SRAM
//==================================================================
IMG_SRAM u_sram0(.clk(clk), .web_n(web[0]), .oe_n(oe[0]), .cs(cs[0]), .addr(addr[0]), .di(di[0]), .do_(do_[0]));
IMG_SRAM u_sram1(.clk(clk), .web_n(web[1]), .oe_n(oe[1]), .cs(cs[1]), .addr(addr[1]), .di(di[1]), .do_(do_[1]));
IMG_SRAM u_sram2(.clk(clk), .web_n(web[2]), .oe_n(oe[2]), .cs(cs[2]), .addr(addr[2]), .di(di[2]), .do_(do_[2]));
IMG_SRAM u_sram3(.clk(clk), .web_n(web[3]), .oe_n(oe[3]), .cs(cs[3]), .addr(addr[3]), .di(di[3]), .do_(do_[3]));


//==================================================================
// design
//==================================================================

// Sequential
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid   <= 0;
        out_value   <= 0;
        addr_idx    <= 0;
        in_ctr      <= 0;
        index_reg   <= 0;
        QP_reg      <= 0;
        param_ctr   <= 0;
        pred_ctr    <= 0;
        for(i = 0; i < 4; i = i + 1) begin
            data_in[i]   <= 0;
            mode_reg[i]  <= 0;
            web[i]         <= 0;
            oe [i]         <= 0;
            cs [i]         <= 0;
            di [i]         <= 0;
            addr[i]        <= 0;
        end
        image_ctr   <= 0;
        for(i = 0; i < 32; i = i + 1) begin
            top[i]   <= 0;
        end

        for(i = 0; i < 16; i = i + 1) begin
            left[i]  <= 0;
        end
        block_row        <= 0;
        block_col        <= 0;
        row              <= 0;
        col              <= 0;
        new_round        <= 0;
        pred_ctr2        <= 0;
        h_acc            <= 0;
        v_acc            <= 0;
        dc_acc           <= 0;
        pred16_step      <= 0;
        pred_16_done_reg <= 0;
        dc_h_v           <= 0;
        int_ctr          <= 0;
        dc_value         <= 0;
        q_idx            <= 0;
        dq_idx           <= 0;
        q_z_d1           <= 0;
        dq_row_w_last    <= 0;
        dq_col_w_last    <= 0;
        has_top          <= 0;
        has_left         <= 0;
        block_ctr        <= 0;
        for(i = 0; i < 4; i = i + 1) begin
          for(j = 0; j < 4; j = j + 1) begin
              map[i][j]  <= 0;
          end
        end



    end else begin
        out_valid            <= out_valid_n;
        out_value            <= out_value_n;
        addr_idx             <= addr_idx_n;
        in_ctr               <= in_ctr_n;
        data_in              <= data_in_n;
        web                  <= web_n;
        oe                   <= oe_n;
        cs                   <= cs_n;
        di                   <= di_n;
        addr                 <= addr_n;   
        index_reg            <= index_reg_n;
        QP_reg               <= QP_reg_n;
        mode_reg             <= mode_reg_n;
        param_ctr            <= param_ctr_n;
        pred_ctr             <= pred_ctr_n;
        top                  <= top_n;
        left                 <= left_n;
        block_row            <= block_row_n;
        block_col            <= block_col_n;
        map                  <= map_n;
        has_top              <= has_top_n;
        has_left             <= has_left_n;
        block_ctr            <= block_ctr_n;
        row                  <= row_n;
        col                  <= col_n;
        row_offset           <= row_offset_n;
        col_offset           <= col_offset_n;
        new_round            <= new_round_n;
        pred_ctr2            <= pred_ctr2_n;
        h_acc                <= h_acc_n;
        v_acc                <= v_acc_n;
        dc_acc               <= dc_acc_n;
        pred16_step          <= pred16_step_n;
        predicted            <= predicted_n;
        pred_16_done_reg     <= pred_16_done;
        dc_h_v               <= dc_h_v_n;
        int_ctr              <= int_ctr_n;
        dc_value             <= dc_value_n;
        q_idx                <= q_idx_n;
        dq_idx               <= dq_idx_n;
        q_z_d1               <= q_z_d1_n;
        dq_row_w_last        <= dq_row_w;
        dq_col_w_last        <= dq_col_w;
        image_ctr            <= image_ctr_n;
    end
end

function [7:0] clip8;
    input signed [FF_WIDTH-1:0] v;
    begin
    if (v < 0)        clip8 = 8'd0;
    else if (v > 255) clip8 = 8'd255;
    else              clip8 = v[7:0];
    end
endfunction

// Combinational
always @(*) begin
    
    out_value_n   = 0;
    out_valid_n   = 0;
    addr_idx_n    = addr_idx;
    in_ctr_n      = in_ctr;
    data_in_n     = data_in;
    param_ctr_n   = 0;
    pred_ctr_n    = pred_ctr;
    top_n         = top;
    left_n        = left;
    block_row_n   = block_row;
    block_col_n   = block_col;
    data_out_n    = data_out;
    map_n         = map;
    has_top_n     = has_top;
    has_left_n    = has_left;
    row_offset_n  = row_offset;
    col_offset_n  = col_offset;
    block_ctr_n   = block_ctr;
    row_n         = row;
    col_n         = col;
    pred_done     = 0;
    pred_16_done  = pred_16_done_reg;
    new_round_n   = new_round;
    h_acc_n       = h_acc;
    v_acc_n       = v_acc;
    dc_acc_n      = dc_acc;
    pred16_step_n = pred16_step;
    predicted_n   = predicted;
    dc_h_v_n      = dc_h_v;
    int_ctr_n     = int_ctr;
    dc_value_n    = dc_value;
    q_idx_n       = q_idx;
    dq_idx_n      = dq_idx;
    map_n         = map;
    q_z_d1_n      = q_z_d1;
    QP_reg_n      = QP_reg;
    mode_reg_n    = mode_reg;
    index_reg_n   = index_reg;
    pred_ctr2_n   = pred_ctr2;
    image_ctr_n   = image_ctr;
    to_pred_16    = 0;
    x_flat        = 0;
    left_idx      = 0;
    top_idx       = 0;
    top_16        = 0;
    left_16       = 0;
    sum           = 0;
    intra_mode    = 0;
    for(i = 0; i < 4; i = i + 1) begin
        web_n [i]   = 1'b1;   // no write
        oe_n  [i]   = 1'b1;   // disable output
        cs_n  [i]   = 1'b0;   // chip deselect
        di_n  [i]   = di[i];  // hold previous DI (don't care if cs=0)
        addr_n[i]   = addr[i];// hold previous ADDR (don't care if cs=0)
    end
    ref_block = 0;
    top4      = 0;
    left4     = 0;
    ht        = 0;
    hl        = 0;
    pred_16_early = 0;

    for(i = 0; i < 4; i = i + 1) begin
        for(j = 0; j < 4; j = j + 1) begin
          res[i][j] = 0;
        end
    end
    
    if(current_state == IDLE) begin
        for(i = 0; i < 4; i = i + 1) begin
            data_in_n[i] = 0;
        end
        for(i = 0; i < 32; i = i + 1) begin
            top_n[i]     = 0;
        end

        for(i = 0; i < 16; i = i + 1) begin
            left_n[i]  = 0;
        end

        for(i = 0; i < 4; i = i + 1) begin
            for(j = 0; j < 4; j = j + 1) begin
                map_n[i][j] = 0;
            end
        end

        block_row_n = 0;
        block_col_n = 0;
        new_round_n = 1;
        image_ctr_n = 0;

        if(in_valid_data) begin
            data_in_n[0] = data;
            in_ctr_n   = 1;
            addr_idx_n = 0;
        end
    end

    if(current_state == INPUT_DATA) begin
        for(i = 0; i < 4; i = i + 1) begin
            cs_n[i]  = 1'b0;
            web_n[i] = 1'b1;
            oe_n[i]  = 1'b1;
            di_n[i]  = di[i];
            addr_n[i] = addr[i];
        end
        if(in_valid_data) begin
            case(in_ctr[1:0])
                2'd0: data_in_n[0] = data;
                2'd1: data_in_n[1] = data;
                2'd2: data_in_n[2] = data;
                2'd3: data_in_n[3] = data;
            endcase
            in_ctr_n = in_ctr + 1;
            if(in_ctr[1:0] == 2'b11) begin
                for(i = 0; i < 4; i = i + 1) begin
                    if(i == in_ctr[6:5]) begin
                        cs_n[i]  = 1'b1;
                        web_n[i] = 1'b0;
                        oe_n[i]  = 1'b1;    
                        di_n[i]  = mem_data_in;
                        addr_n[i] = {addr_idx[11:5], addr_idx[2:0]};
                    end else begin
                        cs_n[i]  = 1'b0;
                        web_n[i] = 1'b1;
                        oe_n[i]  = 1'b1;
                        di_n[i]  = di[i];
                        addr_n[i] = addr[i];
                    end
                end
                addr_idx_n = addr_idx + 1;
            end else begin
                addr_idx_n = addr_idx;
            end
        end else begin
            in_ctr_n = in_ctr;
            addr_idx_n = addr_idx;
        end
    end

    if(current_state == INPUT_PARAM) begin
        if(in_valid_param) begin
            mode_reg_n[3] = mode;
            mode_reg_n[2] = mode_reg[3];
            mode_reg_n[1] = mode_reg[2];
            mode_reg_n[0] = mode_reg[1];
            if(param_ctr == 0) begin
              QP_reg_n     = QP;
              index_reg_n  = index;
            end
            param_ctr_n = param_ctr + 1;
            for(i = 0; i < 16; i = i + 1) begin
                    left_n[i] = 0;
                end
            for(i = 0; i < 32; i = i + 1) begin
                top_n[i] = 0;
            end
            new_round_n = 1;
            if(param_ctr == 3) image_ctr_n = image_ctr + 1;
        end
    end

    if(current_state == UPDATE_PTR) begin
        if(new_round) begin
            block_row_n  = 0;
            block_col_n  = 0;
            block_ctr_n  = 1;
            new_round_n  = 0;
            if(mode_reg[0] == 0) begin
                to_pred_16 = 1;
                pred_16_done = 0;
            end
        end else begin
            block_ctr_n = block_ctr + 1;
            block_col_n = (block_col == 7) ? 0 : (block_col + 1);
            if(block_col[1:0] == 2'b11) begin
                if(block_row[1:0] == 2'b11) block_row_n[1:0] = 2'b00;
                else block_row_n[1:0] = block_row[1:0] + 1;
            end else begin
                block_row_n[1:0] = block_row[1:0];
            end
            case (block_ctr[5:4])
                2'b00: begin
                    block_row_n[2] = 0;
                    block_col_n[2] = 0;
                end
                2'b01: begin
                    block_row_n[2] = 0;
                    block_col_n[2] = 1;
                end
                2'b10: begin
                    block_row_n[2] = 1;
                    block_col_n[2] = 0;
                end
                2'b11: begin
                    block_row_n[2] = 1;
                    block_col_n[2] = 1;
                end
            endcase
            if(block_ctr == 16 || block_ctr == 32 || block_ctr == 48) begin
                mode_reg_n[0]  = mode_reg[1];
                mode_reg_n[1]  = mode_reg[2];
                mode_reg_n[2]  = mode_reg[3];
                if(mode_reg[1] == 0) begin
                    to_pred_16 = 1;
                    pred_16_done = 0;
                end
            end
        end
        pred_ctr_n    = 0;
        pred_ctr2_n   = 0;
        h_acc_n       = 0;
        v_acc_n       = 0;
        dc_acc_n      = 0;
        row_n         = 0;
        col_n         = 0;
        pred16_step_n = 0;
        int_ctr_n     = 0;
        q_idx_n       = 0;
        dq_idx_n      = 0;
        q_z_d1_n      = 0;
    end

    if(current_state == PRED) begin
        pred_ctr_n = pred_ctr + 1;
        case (pred_ctr)
            0: begin
                if(mode_reg[0] == 0) begin
                    has_top_n  = block_row[2] != 0;
                    has_left_n = block_col[2] != 0;
                end else begin
                    has_top_n  = block_row != 0;
                    has_left_n = block_col != 0;
                end;
                pred_ctr_n = 1;
                for(i=0;i<4;i=i+1) begin
                    cs_n[i]   = 1'b1;
                    web_n[i]  = 1'b1;
                    oe_n[i]   = 1'b1;
                    addr_n[i] = {index_reg, block_row,  block_col}; 
                end
            end
            1: begin
              pred_ctr_n = 2;
            end
            2: begin
                map_n[0][0][7:0] = do_[0][31:24];
                map_n[0][1][7:0] = do_[0][23:16];
                map_n[0][2][7:0] = do_[0][15: 8];
                map_n[0][3][7:0] = do_[0][ 7: 0];
                map_n[1][0][7:0] = do_[1][31:24];
                map_n[1][1][7:0] = do_[1][23:16];
                map_n[1][2][7:0] = do_[1][15: 8];
                map_n[1][3][7:0] = do_[1][ 7: 0];
                map_n[2][0][7:0] = do_[2][31:24];
                map_n[2][1][7:0] = do_[2][23:16];
                map_n[2][2][7:0] = do_[2][15: 8];
                map_n[2][3][7:0] = do_[2][ 7: 0];
                map_n[3][0][7:0] = do_[3][31:24];
                map_n[3][1][7:0] = do_[3][23:16];
                map_n[3][2][7:0] = do_[3][15: 8];
                map_n[3][3][7:0] = do_[3][ 7: 0];
                pred_ctr_n = 3;
            end
            3: begin
                pred_ctr_n = 4;
                ref_block = {map[3][3][7:0], map[3][2][7:0], map[3][1][7:0], map[3][0][7:0],
                             map[2][3][7:0], map[2][2][7:0], map[2][1][7:0], map[2][0][7:0],
                             map[1][3][7:0], map[1][2][7:0], map[1][1][7:0], map[1][0][7:0],
                             map[0][3][7:0], map[0][2][7:0], map[0][1][7:0], map[0][0][7:0]};
                left_idx  = block_row[1:0] << 2;
                top_idx   = block_col << 2;
                top4        = { top[top_idx + 3],  top[top_idx + 2],  top[top_idx + 1],  top[top_idx]};
                left4       = {left[left_idx + 3], left[left_idx + 2], left[left_idx + 1], left[left_idx]};
                intra_mode = 1;
                ht          = has_top;
                hl          = has_left;
                
                if(mode_reg[0] == 1) begin
                    dc_h_v_n    = dchv;
                    dc_value_n  = dc_v;
                end
                pred_done   = 1;
            end

            
            
        endcase
    end

    if(current_state == PRED_16) begin
        has_top_n  = block_row != 0;
        has_left_n = block_col != 0;
        case (pred_ctr2)
            0: begin
                // ======== PIPE 0 ==========
                
                pred_ctr2_n = 1;
                for(i=0;i<4;i=i+1) begin
                    cs_n[i]   = 1'b1;
                    web_n[i]  = 1'b1;
                    oe_n[i]   = 1'b1;
                    addr_n[i] = {index_reg, block_row + row, block_col + col}; 
                end
            end
            1: begin
                pred_ctr2_n = 2;
            end
            2: begin
                map_n[0][0][7:0] = do_[0][31:24];
                map_n[0][1][7:0] = do_[0][23:16];
                map_n[0][2][7:0] = do_[0][15: 8];
                map_n[0][3][7:0] = do_[0][ 7: 0];
                map_n[1][0][7:0] = do_[1][31:24];
                map_n[1][1][7:0] = do_[1][23:16];
                map_n[1][2][7:0] = do_[1][15: 8];
                map_n[1][3][7:0] = do_[1][ 7: 0];
                map_n[2][0][7:0] = do_[2][31:24];
                map_n[2][1][7:0] = do_[2][23:16];
                map_n[2][2][7:0] = do_[2][15: 8];
                map_n[2][3][7:0] = do_[2][ 7: 0];
                map_n[3][0][7:0] = do_[3][31:24];
                map_n[3][1][7:0] = do_[3][23:16];
                map_n[3][2][7:0] = do_[3][15: 8];
                map_n[3][3][7:0] = do_[3][ 7: 0];
                pred_ctr2_n = 3;
                end
            3: begin
                pred_ctr2_n = 0;
                ref_block = {map[3][3][7:0], map[3][2][7:0], map[3][1][7:0], map[3][0][7:0],
                             map[2][3][7:0], map[2][2][7:0], map[2][1][7:0], map[2][0][7:0],
                             map[1][3][7:0], map[1][2][7:0], map[1][1][7:0], map[1][0][7:0],
                             map[0][3][7:0], map[0][2][7:0], map[0][1][7:0], map[0][0][7:0]};
                left_idx  = (block_row[1:0] + row) << 2;
                top_idx   = (block_col + col ) << 2;
                top4        = { top[top_idx + 3],  top[top_idx + 2],  top[top_idx + 1],  top[top_idx]};
                left4       = {left[left_idx + 3], left[left_idx + 2], left[left_idx + 1], left[left_idx]};
                intra_mode  = 0;
                left_16 = {left[ 0], left[ 1], left[ 2], left[ 3],
                           left[ 4], left[ 5], left[ 6], left[ 7],
                           left[ 8], left[ 9], left[10], left[11],
                           left[12], left[13], left[14], left[15]};
                if(block_col[2]) begin
                  top_16 =  {top[16], top[17], top[18], top[19], 
                             top[20], top[21], top[22], top[23], 
                             top[24], top[25], top[26], top[27], 
                             top[28], top[29], top[30], top[31]};
                end else begin
                  top_16 =  {top[ 0], top[ 1], top[ 2], top[ 3], 
                             top[ 4], top[ 5], top[ 6], top[ 7], 
                             top[ 8], top[ 9], top[10], top[11], 
                             top[12], top[13], top[14], top[15]};
                end 
                
                
                ht      = has_top;
                hl      = has_left;
                h_acc_n   = h_acc + sad_h;
                v_acc_n   = v_acc + sad_v;
                dc_acc_n  = dc_acc + sad_dc;
                dc_value_n = dc_v;
                col_n = col == 3 ? 0 : col + 1;
                row_n = col == 3 ? row == 3 ? 0 : row + 1 : row;
                pred16_step_n = pred16_step + 1;
                if(block_row == 0 && block_col == 0) begin
                    pred_16_early = 1;
                    dc_h_v_n      = 0;
                end
                if( pred16_step == 15) begin
                    pred_16_done = 1;
                end 
            end
        endcase
        if(pred_16_done_reg) begin
            if (!has_top && !has_left) begin
                dc_h_v_n = 2'd0;
            end else if (!has_top && has_left) begin
                dc_h_v_n = (dc_acc <= h_acc) ? 2'd0 : 2'd1;  // DC : H
            end else if (has_top && !has_left) begin
                dc_h_v_n = (dc_acc <= v_acc) ? 2'd0 : 2'd2;  // DC : V
            end else begin
                dc_h_v_n =
                    (dc_acc <= h_acc)
                        ? ((dc_acc <= v_acc) ? 2'd0 : 2'd2)  // DC vs V
                        : ((h_acc <= v_acc) ? 2'd1 : 2'd2); // H vs V
            end
        end
    end

    if(current_state == INT_TRAN) begin
        int_ctr_n = int_ctr + 1;
        if(int_ctr == 0) begin
            case (dc_h_v)
                0: begin //dc
                    for(int i = 0; i < 4; i = i + 1) begin
                      for(int j = 0; j < 4; j = j + 1) begin
                        map_n[i][j] = map[i][j][7:0] - dc_value;
                      end
                    end
                end
                1: begin //h
                    for(int i = 0; i < 4; i = i + 1) begin
                      for(int j = 0; j < 4; j = j + 1) begin
                        map_n[i][j] = map[i][j][7:0] - left[(block_row[1:0] << 2) + i];
                      end
                    end
                end
                2: begin //v
                    for(int i = 0; i < 4; i = i + 1) begin
                      for(int j = 0; j < 4; j = j + 1) begin
                        map_n[i][j] = map[i][j][7:0] - top[(block_col[2:0] << 2) + j];
                      end
                    end
                end 
                default:
                    map_n = map; 
            endcase
        end else begin
            x_flat = {map[3][3][INT_TRAN_WIDTH-1:0], map[3][2][INT_TRAN_WIDTH-1:0], map[3][1][INT_TRAN_WIDTH-1:0], map[3][0][INT_TRAN_WIDTH-1:0],
                      map[2][3][INT_TRAN_WIDTH-1:0], map[2][2][INT_TRAN_WIDTH-1:0], map[2][1][INT_TRAN_WIDTH-1:0], map[2][0][INT_TRAN_WIDTH-1:0],
                      map[1][3][INT_TRAN_WIDTH-1:0], map[1][2][INT_TRAN_WIDTH-1:0], map[1][1][INT_TRAN_WIDTH-1:0], map[1][0][INT_TRAN_WIDTH-1:0],
                      map[0][3][INT_TRAN_WIDTH-1:0], map[0][2][INT_TRAN_WIDTH-1:0], map[0][1][INT_TRAN_WIDTH-1:0], map[0][0][INT_TRAN_WIDTH-1:0]};
            map_n[0][0] = w_flat[FF_WIDTH *  1 - 1 :             0];
            map_n[0][1] = w_flat[FF_WIDTH *  2 - 1 : FF_WIDTH *  1];
            map_n[0][2] = w_flat[FF_WIDTH *  3 - 1 : FF_WIDTH *  2];
            map_n[0][3] = w_flat[FF_WIDTH *  4 - 1 : FF_WIDTH *  3];
            map_n[1][0] = w_flat[FF_WIDTH *  5 - 1 : FF_WIDTH *  4];
            map_n[1][1] = w_flat[FF_WIDTH *  6 - 1 : FF_WIDTH *  5];
            map_n[1][2] = w_flat[FF_WIDTH *  7 - 1 : FF_WIDTH *  6];
            map_n[1][3] = w_flat[FF_WIDTH *  8 - 1 : FF_WIDTH *  7];
            map_n[2][0] = w_flat[FF_WIDTH *  9 - 1 : FF_WIDTH *  8];
            map_n[2][1] = w_flat[FF_WIDTH * 10 - 1 : FF_WIDTH *  9];
            map_n[2][2] = w_flat[FF_WIDTH * 11 - 1 : FF_WIDTH * 10];
            map_n[2][3] = w_flat[FF_WIDTH * 12 - 1 : FF_WIDTH * 11];
            map_n[3][0] = w_flat[FF_WIDTH * 13 - 1 : FF_WIDTH * 12];
            map_n[3][1] = w_flat[FF_WIDTH * 14 - 1 : FF_WIDTH * 13];
            map_n[3][2] = w_flat[FF_WIDTH * 15 - 1 : FF_WIDTH * 14];
            map_n[3][3] = w_flat[FF_WIDTH * 16 - 1 : FF_WIDTH * 15];
        end
    end

    if(current_state == QUANT) begin
        q_z_d1_n  = q_z_d1;
        int_ctr_n = 0;
        if(q_idx[4] == 0) map_n[q_row_w][q_col_w] = q_z;
        out_valid_n = 1'b1;
        out_value_n = $signed(q_z);
        q_idx_n = q_idx + 1;
        dq_idx_n  = q_idx;
        if(q_idx != 0) begin
            q_z_d1_n  = map[dq_row_w][dq_col_w][DEQUANT_WIDTH-1:0];
            map_n[dq_row_w_last][dq_col_w_last] = xhat_w;
        end
        if(q_idx >= 16) begin
            out_valid_n = 0;
            out_value_n = 0;
        end
    end

    if(current_state == INV_INT_TRAN) begin
        int_ctr_n = int_ctr + 1;
        if(int_ctr == 0) begin
            x_flat = {map[3][3][INT_TRAN_WIDTH-1:0], map[3][2][INT_TRAN_WIDTH-1:0], map[3][1][INT_TRAN_WIDTH-1:0], map[3][0][INT_TRAN_WIDTH-1:0],
                      map[2][3][INT_TRAN_WIDTH-1:0], map[2][2][INT_TRAN_WIDTH-1:0], map[2][1][INT_TRAN_WIDTH-1:0], map[2][0][INT_TRAN_WIDTH-1:0],
                      map[1][3][INT_TRAN_WIDTH-1:0], map[1][2][INT_TRAN_WIDTH-1:0], map[1][1][INT_TRAN_WIDTH-1:0], map[1][0][INT_TRAN_WIDTH-1:0],
                      map[0][3][INT_TRAN_WIDTH-1:0], map[0][2][INT_TRAN_WIDTH-1:0], map[0][1][INT_TRAN_WIDTH-1:0], map[0][0][INT_TRAN_WIDTH-1:0]};
            
            map_n[0][0] = $signed(w_flat[FF_WIDTH *  1 - 1 :             0]) >>> 6;
            map_n[0][1] = $signed(w_flat[FF_WIDTH *  2 - 1 : FF_WIDTH *  1]) >>> 6;
            map_n[0][2] = $signed(w_flat[FF_WIDTH *  3 - 1 : FF_WIDTH *  2]) >>> 6;
            map_n[0][3] = $signed(w_flat[FF_WIDTH *  4 - 1 : FF_WIDTH *  3]) >>> 6;
            map_n[1][0] = $signed(w_flat[FF_WIDTH *  5 - 1 : FF_WIDTH *  4]) >>> 6;
            map_n[1][1] = $signed(w_flat[FF_WIDTH *  6 - 1 : FF_WIDTH *  5]) >>> 6;
            map_n[1][2] = $signed(w_flat[FF_WIDTH *  7 - 1 : FF_WIDTH *  6]) >>> 6;
            map_n[1][3] = $signed(w_flat[FF_WIDTH *  8 - 1 : FF_WIDTH *  7]) >>> 6;
            map_n[2][0] = $signed(w_flat[FF_WIDTH *  9 - 1 : FF_WIDTH *  8]) >>> 6;
            map_n[2][1] = $signed(w_flat[FF_WIDTH * 10 - 1 : FF_WIDTH *  9]) >>> 6;
            map_n[2][2] = $signed(w_flat[FF_WIDTH * 11 - 1 : FF_WIDTH * 10]) >>> 6;
            map_n[2][3] = $signed(w_flat[FF_WIDTH * 12 - 1 : FF_WIDTH * 11]) >>> 6;
            map_n[3][0] = $signed(w_flat[FF_WIDTH * 13 - 1 : FF_WIDTH * 12]) >>> 6;
            map_n[3][1] = $signed(w_flat[FF_WIDTH * 14 - 1 : FF_WIDTH * 13]) >>> 6;
            map_n[3][2] = $signed(w_flat[FF_WIDTH * 15 - 1 : FF_WIDTH * 14]) >>> 6;
            map_n[3][3] = $signed(w_flat[FF_WIDTH * 16 - 1 : FF_WIDTH * 15]) >>> 6;
        end 
        if(int_ctr == 1) begin
            case (dc_h_v)
                0: begin //dc
                    for(int i = 0; i < 4; i = i + 1) begin
                      for(int j = 0; j < 4; j = j + 1) begin
                        res[i][j] = $signed(map[i][j]) + dc_value;
                        map_n[i][j] = {{(FF_WIDTH-8){1'b0}}, clip8(res[i][j])};
                        //map_n[i][j][31:8] = 0;
                      end
                    end
                end
                1: begin //h
                    for(int i = 0; i < 4; i = i + 1) begin
                      for(int j = 0; j < 4; j = j + 1) begin
                        res[i][j] = $signed(map[i][j]) + left[(block_row[1:0]<<2)+i];
                        map_n[i][j] = {{(FF_WIDTH-8){1'b0}}, clip8(res[i][j])};
                        //map_n[i][j][31:8] = 0;
                      end
                    end
                end
                2: begin //v
                    for(int i = 0; i < 4; i = i + 1) begin
                      for(int j = 0; j < 4; j = j + 1) begin
                        res[i][j] = $signed(map[i][j]) + top[(block_col[2:0]<<2)+j];
                        map_n[i][j] = {{(FF_WIDTH-8){1'b0}}, clip8(res[i][j])};
                        //map_n[i][j][31:8] = 0;
                      end
                    end
                end 
                default:
                    map_n = map; 
            endcase
        end

        if(int_ctr == 2) begin //update left and top
            if(mode_reg[0] == 0) begin // 16 x 16
                if(block_col[1:0] == 2'b11) begin // only update when right most reached
                    for(int i = 0; i < 4; i = i + 1) begin
                        left_n[(block_row[1:0] << 2) + i] = map[i][3];
                    end
                end

                if(block_row[1:0] == 2'b11) begin // only update when bottom most reached
                    for(int j = 0; j < 4; j = j + 1) begin
                        top_n[(block_col[2:0] << 2) + j] = map[3][j];
                    end
                end
            end else begin // 4 x 4
                for(int i = 0; i < 4; i = i + 1) begin
                    left_n[(block_row[1:0] << 2) + i] = map[i][3];
                end
                for(int j = 0; j < 4; j = j + 1) begin
                    top_n[(block_col[2:0] << 2) + j] = map[3][j];
                end
            end
        end
    end
end

endmodule

module IMG_SRAM (
    input  wire         clk,      // clock
    input  wire         web_n,   // write enable (active-LOW)
    input  wire         oe_n,    // output enable (active-LOW)
    input  wire         cs,      // chip select (active-HIGH)
    input  wire [9:0]   addr,    // address
    input  wire [31:0]  di,      // data in
    output wire [31:0]  do_       // data out
);

    // ---- Scalar breakouts for address ----
    wire A0 = addr[0];
    wire A1 = addr[1];
    wire A2 = addr[2];
    wire A3 = addr[3];
    wire A4 = addr[4];
    wire A5 = addr[5];
    wire A6 = addr[6];
    wire A7 = addr[7];
    wire A8 = addr[8];
    wire A9 = addr[9];

    // ---- Scalar breakouts for DI (write data) ----
    wire DI0  = di[0];
    wire DI1  = di[1];
    wire DI2  = di[2];
    wire DI3  = di[3];
    wire DI4  = di[4];
    wire DI5  = di[5];
    wire DI6  = di[6];
    wire DI7  = di[7];
    wire DI8  = di[8];
    wire DI9  = di[9];
    wire DI10 = di[10];
    wire DI11 = di[11];
    wire DI12 = di[12];
    wire DI13 = di[13];
    wire DI14 = di[14];
    wire DI15 = di[15];
    wire DI16 = di[16];
    wire DI17 = di[17];
    wire DI18 = di[18];
    wire DI19 = di[19];
    wire DI20 = di[20];
    wire DI21 = di[21];
    wire DI22 = di[22];
    wire DI23 = di[23];
    wire DI24 = di[24];
    wire DI25 = di[25];
    wire DI26 = di[26];
    wire DI27 = di[27];
    wire DI28 = di[28];
    wire DI29 = di[29];
    wire DI30 = di[30];
    wire DI31 = di[31];

    // ---- Scalar wires for DO (read data) ----
    wire DO0,  DO1,  DO2,  DO3,  DO4,  DO5,  DO6,  DO7;
    wire DO8,  DO9,  DO10, DO11, DO12, DO13, DO14, DO15;
    wire DO16, DO17, DO18, DO19, DO20, DO21, DO22, DO23;
    wire DO24, DO25, DO26, DO27, DO28, DO29, DO30, DO31;

    // ---- Repack scalars into the output bus ----
    assign do_ = { DO31, DO30, DO29, DO28, DO27, DO26, DO25, DO24,
                  DO23, DO22, DO21, DO20, DO19, DO18, DO17, DO16,
                  DO15, DO14, DO13, DO12, DO11, DO10, DO9,  DO8,
                  DO7,  DO6,  DO5,  DO4,  DO3,  DO2,  DO1,  DO0 };

    // -----------------------------------------------------------------------------
    // Underlying SRAM instance (exact ports taken from your IMAGE_MEM declaration)
    // -----------------------------------------------------------------------------
    IMAGE_MEM u_sram (
        .A0 (A0), .A1 (A1), .A2 (A2), .A3 (A3), .A4 (A4),
        .A5 (A5), .A6 (A6), .A7 (A7), .A8 (A8), .A9 (A9),

        .DO0 (DO0),   .DO1 (DO1),   .DO2 (DO2),   .DO3 (DO3),
        .DO4 (DO4),   .DO5 (DO5),   .DO6 (DO6),   .DO7 (DO7),
        .DO8 (DO8),   .DO9 (DO9),   .DO10(DO10),  .DO11(DO11),
        .DO12(DO12),  .DO13(DO13),  .DO14(DO14),  .DO15(DO15),
        .DO16(DO16),  .DO17(DO17),  .DO18(DO18),  .DO19(DO19),
        .DO20(DO20),  .DO21(DO21),  .DO22(DO22),  .DO23(DO23),
        .DO24(DO24),  .DO25(DO25),  .DO26(DO26),  .DO27(DO27),
        .DO28(DO28),  .DO29(DO29),  .DO30(DO30),  .DO31(DO31),

        .DI0 (DI0),   .DI1 (DI1),   .DI2 (DI2),   .DI3 (DI3),
        .DI4 (DI4),   .DI5 (DI5),   .DI6 (DI6),   .DI7 (DI7),
        .DI8 (DI8),   .DI9 (DI9),   .DI10(DI10),  .DI11(DI11),
        .DI12(DI12),  .DI13(DI13),  .DI14(DI14),  .DI15(DI15),
        .DI16(DI16),  .DI17(DI17),  .DI18(DI18),  .DI19(DI19),
        .DI20(DI20),  .DI21(DI21),  .DI22(DI22),  .DI23(DI23),
        .DI24(DI24),  .DI25(DI25),  .DI26(DI26),  .DI27(DI27),
        .DI28(DI28),  .DI29(DI29),  .DI30(DI30),  .DI31(DI31),

        .CK  (clk),
        .WEB (web_n),    // active-LOW write enable
        .OE  (oe_n),     // active-LOW output enable
        .CS  (cs)
    );

endmodule


module CAL_INTRA_4x4 #(
    parameter integer FF_WIDTH = 32
)(
    input  [127:0] ref_blk,
    input  [31:0]  top4,
    input  [31:0]  left4,
    input  [127:0] top16,
    input  [127:0] left16,
    input          mode,
    input          has_top,
    input          has_left,
    output [15:0]  out_dc,
    output [15:0]  out_h,
    output [15:0]  out_v,
    output [1:0]   dc_h_v,
    output [7:0]   dc_value
);
    // ---------- helpers ----------
    function [7:0] byte8_128; input [127:0] vec; input integer idx; begin
        byte8_128 = vec[8*idx +: 8];
    end endfunction

    function [7:0] byte8_32;  input [31:0]  vec; input integer idx; begin
        byte8_32  = vec[8*idx +: 8];
    end endfunction

    function [8:0] abs8; input [7:0] a,b; begin
        abs8 = (a>=b) ? (a-b) : (b-a);
    end endfunction

    wire [8:0]  sumT01_4 = {1'b0,byte8_32(top4 ,0)} + {1'b0,byte8_32(top4 ,1)};
    wire [8:0]  sumT23_4 = {1'b0,byte8_32(top4 ,2)} + {1'b0,byte8_32(top4 ,3)};
    wire [9:0]  sumT4    = {1'b0,sumT01_4} + {1'b0,sumT23_4}; 

    wire [8:0]  sumL01_4 = {1'b0,byte8_32(left4,0)} + {1'b0,byte8_32(left4,1)};
    wire [8:0]  sumL23_4 = {1'b0,byte8_32(left4,2)} + {1'b0,byte8_32(left4,3)};
    wire [9:0]  sumL4    = {1'b0,sumL01_4} + {1'b0,sumL23_4};

    wire [10:0] sum8_4   = {1'b0,sumT4} + {1'b0,sumL4}; 
    wire [7:0]  DC4_both = sum8_4[10:3];
    wire [7:0]  DC4_top  = sumT4[9:2];
    wire [7:0]  DC4_left = sumL4[9:2];
    wire [7:0]  DCv4     = has_top ? (has_left ? DC4_both : DC4_top)
                                   : (has_left ? DC4_left : 8'd128);

    wire [8:0]  t0  = {1'b0,byte8_128(top16 ,0)} + {1'b0,byte8_128(top16 ,1)};
    wire [8:0]  t1  = {1'b0,byte8_128(top16 ,2)} + {1'b0,byte8_128(top16 ,3)};
    wire [8:0]  t2  = {1'b0,byte8_128(top16 ,4)} + {1'b0,byte8_128(top16 ,5)};
    wire [8:0]  t3  = {1'b0,byte8_128(top16 ,6)} + {1'b0,byte8_128(top16 ,7)};
    wire [8:0]  t4  = {1'b0,byte8_128(top16 ,8)} + {1'b0,byte8_128(top16 ,9)};
    wire [8:0]  t5  = {1'b0,byte8_128(top16 ,10)}+ {1'b0,byte8_128(top16 ,11)};
    wire [8:0]  t6  = {1'b0,byte8_128(top16 ,12)}+ {1'b0,byte8_128(top16 ,13)};
    wire [8:0]  t7  = {1'b0,byte8_128(top16 ,14)}+ {1'b0,byte8_128(top16 ,15)};
    wire [10:0] t01 = {1'b0,t0} + {1'b0,t1};
    wire [10:0] t23 = {1'b0,t2} + {1'b0,t3};
    wire [10:0] t45 = {1'b0,t4} + {1'b0,t5};
    wire [10:0] t67 = {1'b0,t6} + {1'b0,t7};
    wire [11:0] t0123 = {1'b0,t01} + {1'b0,t23};
    wire [11:0] t4567 = {1'b0,t45} + {1'b0,t67};
    wire [12:0] sumT16 = {1'b0,t0123} + {1'b0,t4567};

    wire [8:0]  l0  = {1'b0,byte8_128(left16 ,0)} + {1'b0,byte8_128(left16 ,1)};
    wire [8:0]  l1  = {1'b0,byte8_128(left16 ,2)} + {1'b0,byte8_128(left16 ,3)};
    wire [8:0]  l2  = {1'b0,byte8_128(left16 ,4)} + {1'b0,byte8_128(left16 ,5)};
    wire [8:0]  l3  = {1'b0,byte8_128(left16 ,6)} + {1'b0,byte8_128(left16 ,7)};
    wire [8:0]  l4  = {1'b0,byte8_128(left16 ,8)} + {1'b0,byte8_128(left16 ,9)};
    wire [8:0]  l5  = {1'b0,byte8_128(left16 ,10)}+ {1'b0,byte8_128(left16 ,11)};
    wire [8:0]  l6  = {1'b0,byte8_128(left16 ,12)}+ {1'b0,byte8_128(left16 ,13)};
    wire [8:0]  l7  = {1'b0,byte8_128(left16 ,14)}+ {1'b0,byte8_128(left16 ,15)};
    wire [10:0] l01 = {1'b0,l0} + {1'b0,l1};
    wire [10:0] l23 = {1'b0,l2} + {1'b0,l3};
    wire [10:0] l45 = {1'b0,l4} + {1'b0,l5};
    wire [10:0] l67 = {1'b0,l6} + {1'b0,l7};
    wire [11:0] l0123 = {1'b0,l01} + {1'b0,l23};
    wire [11:0] l4567 = {1'b0,l45} + {1'b0,l67};
    wire [12:0] sumL16 = {1'b0,l0123} + {1'b0,l4567};

    wire [13:0] sum32_16  = {1'b0,sumT16} + {1'b0,sumL16};
    wire [7:0]  DC16_both = sum32_16[13:5];
    wire [7:0]  DC16_top  = sumT16[12:4];
    wire [7:0]  DC16_left = sumL16[12:4];
    wire [7:0]  DCv16     = has_top ? (has_left ? DC16_both : DC16_top)
                                    : (has_left ? DC16_left : 8'd128);

    wire [7:0] DCv = mode ? DCv4 : DCv16;
    assign dc_value = DCv;

    wire [8:0] ddc0  = abs8(byte8_128(ref_blk,  0), DCv);
    wire [8:0] ddc1  = abs8(byte8_128(ref_blk,  1), DCv);
    wire [8:0] ddc2  = abs8(byte8_128(ref_blk,  2), DCv);
    wire [8:0] ddc3  = abs8(byte8_128(ref_blk,  3), DCv);
    wire [8:0] ddc4  = abs8(byte8_128(ref_blk,  4), DCv);
    wire [8:0] ddc5  = abs8(byte8_128(ref_blk,  5), DCv);
    wire [8:0] ddc6  = abs8(byte8_128(ref_blk,  6), DCv);
    wire [8:0] ddc7  = abs8(byte8_128(ref_blk,  7), DCv);
    wire [8:0] ddc8  = abs8(byte8_128(ref_blk,  8), DCv);
    wire [8:0] ddc9  = abs8(byte8_128(ref_blk,  9), DCv);
    wire [8:0] ddc10 = abs8(byte8_128(ref_blk, 10), DCv);
    wire [8:0] ddc11 = abs8(byte8_128(ref_blk, 11), DCv);
    wire [8:0] ddc12 = abs8(byte8_128(ref_blk, 12), DCv);
    wire [8:0] ddc13 = abs8(byte8_128(ref_blk, 13), DCv);
    wire [8:0] ddc14 = abs8(byte8_128(ref_blk, 14), DCv);
    wire [8:0] ddc15 = abs8(byte8_128(ref_blk, 15), DCv);

    function [7:0] predH_L; input [31:0] Lvec; input integer idx; begin
        predH_L = byte8_32(Lvec, (idx>>2));
    end endfunction

    wire [8:0] dh0  = abs8(byte8_128(ref_blk,  0), predH_L(left4,  0));
    wire [8:0] dh1  = abs8(byte8_128(ref_blk,  1), predH_L(left4,  1));
    wire [8:0] dh2  = abs8(byte8_128(ref_blk,  2), predH_L(left4,  2));
    wire [8:0] dh3  = abs8(byte8_128(ref_blk,  3), predH_L(left4,  3));
    wire [8:0] dh4  = abs8(byte8_128(ref_blk,  4), predH_L(left4,  4));
    wire [8:0] dh5  = abs8(byte8_128(ref_blk,  5), predH_L(left4,  5));
    wire [8:0] dh6  = abs8(byte8_128(ref_blk,  6), predH_L(left4,  6));
    wire [8:0] dh7  = abs8(byte8_128(ref_blk,  7), predH_L(left4,  7));
    wire [8:0] dh8  = abs8(byte8_128(ref_blk,  8), predH_L(left4,  8));
    wire [8:0] dh9  = abs8(byte8_128(ref_blk,  9), predH_L(left4,  9));
    wire [8:0] dh10 = abs8(byte8_128(ref_blk, 10), predH_L(left4, 10));
    wire [8:0] dh11 = abs8(byte8_128(ref_blk, 11), predH_L(left4, 11));
    wire [8:0] dh12 = abs8(byte8_128(ref_blk, 12), predH_L(left4, 12));
    wire [8:0] dh13 = abs8(byte8_128(ref_blk, 13), predH_L(left4, 13));
    wire [8:0] dh14 = abs8(byte8_128(ref_blk, 14), predH_L(left4, 14));
    wire [8:0] dh15 = abs8(byte8_128(ref_blk, 15), predH_L(left4, 15));

    function [7:0] predV_T; input [31:0] Tvec; input integer idx; begin
        predV_T = byte8_32(Tvec, (idx & 3));
    end endfunction

    wire [8:0] dv0  = abs8(byte8_128(ref_blk,  0), predV_T(top4,  0));
    wire [8:0] dv1  = abs8(byte8_128(ref_blk,  1), predV_T(top4,  1));
    wire [8:0] dv2  = abs8(byte8_128(ref_blk,  2), predV_T(top4,  2));
    wire [8:0] dv3  = abs8(byte8_128(ref_blk,  3), predV_T(top4,  3));
    wire [8:0] dv4  = abs8(byte8_128(ref_blk,  4), predV_T(top4,  4));
    wire [8:0] dv5  = abs8(byte8_128(ref_blk,  5), predV_T(top4,  5));
    wire [8:0] dv6  = abs8(byte8_128(ref_blk,  6), predV_T(top4,  6));
    wire [8:0] dv7  = abs8(byte8_128(ref_blk,  7), predV_T(top4,  7));
    wire [8:0] dv8  = abs8(byte8_128(ref_blk,  8), predV_T(top4,  8));
    wire [8:0] dv9  = abs8(byte8_128(ref_blk,  9), predV_T(top4,  9));
    wire [8:0] dv10 = abs8(byte8_128(ref_blk, 10), predV_T(top4, 10));
    wire [8:0] dv11 = abs8(byte8_128(ref_blk, 11), predV_T(top4, 11));
    wire [8:0] dv12 = abs8(byte8_128(ref_blk, 12), predV_T(top4, 12));
    wire [8:0] dv13 = abs8(byte8_128(ref_blk, 13), predV_T(top4, 13));
    wire [8:0] dv14 = abs8(byte8_128(ref_blk, 14), predV_T(top4, 14));
    wire [8:0] dv15 = abs8(byte8_128(ref_blk, 15), predV_T(top4, 15));

    // ---------- adder trees ----------
    // L1
    wire [9:0] s1_dc0 = ddc0  + ddc1;   wire [9:0] s1_dc1 = ddc2  + ddc3;
    wire [9:0] s1_dc2 = ddc4  + ddc5;   wire [9:0] s1_dc3 = ddc6  + ddc7;
    wire [9:0] s1_dc4 = ddc8  + ddc9;   wire [9:0] s1_dc5 = ddc10 + ddc11;
    wire [9:0] s1_dc6 = ddc12 + ddc13;  wire [9:0] s1_dc7 = ddc14 + ddc15;

    wire [9:0] s1_h0  = dh0  + dh1;     wire [9:0] s1_h1  = dh2  + dh3;
    wire [9:0] s1_h2  = dh4  + dh5;     wire [9:0] s1_h3  = dh6  + dh7;
    wire [9:0] s1_h4  = dh8  + dh9;     wire [9:0] s1_h5  = dh10 + dh11;
    wire [9:0] s1_h6  = dh12 + dh13;    wire [9:0] s1_h7  = dh14 + dh15;

    wire [9:0] s1_v0  = dv0  + dv1;     wire [9:0] s1_v1  = dv2  + dv3;
    wire [9:0] s1_v2  = dv4  + dv5;     wire [9:0] s1_v3  = dv6  + dv7;
    wire [9:0] s1_v4  = dv8  + dv9;     wire [9:0] s1_v5  = dv10 + dv11;
    wire [9:0] s1_v6  = dv12 + dv13;    wire [9:0] s1_v7  = dv14 + dv15;

    // L2
    wire [10:0] s2_dc0 = s1_dc0 + s1_dc1;  wire [10:0] s2_v0 = s1_v0 + s1_v1;
    wire [10:0] s2_dc1 = s1_dc2 + s1_dc3;  wire [10:0] s2_v1 = s1_v2 + s1_v3;
    wire [10:0] s2_dc2 = s1_dc4 + s1_dc5;  wire [10:0] s2_v2 = s1_v4 + s1_v5;
    wire [10:0] s2_dc3 = s1_dc6 + s1_dc7;  wire [10:0] s2_v3 = s1_v6 + s1_v7;

    wire [10:0] s2_h0  = s1_h0 + s1_h1;    wire [10:0] s2_h1  = s1_h2 + s1_h3;
    wire [10:0] s2_h2  = s1_h4 + s1_h5;    wire [10:0] s2_h3  = s1_h6 + s1_h7;

    // L3
    wire [11:0] s3_dc0 = s2_dc0 + s2_dc1;  wire [11:0] s3_v0 = s2_v0 + s2_v1;
    wire [11:0] s3_dc1 = s2_dc2 + s2_dc3;  wire [11:0] s3_v1 = s2_v2 + s2_v3;

    wire [11:0] s3_h0  = s2_h0 + s2_h1;
    wire [11:0] s3_h1  = s2_h2 + s2_h3;

    // L4
    wire [12:0] SAD_DC = s3_dc0 + s3_dc1;
    wire [12:0] SAD_H  = s3_h0  + s3_h1;
    wire [12:0] SAD_V  = s3_v0  + s3_v1;

    wire [12:0] SAD_H_eff = has_left ? SAD_H : 13'h1FFF;
    wire [12:0] SAD_V_eff = has_top  ? SAD_V : 13'h1FFF;

    wire [12:0] min_dch = (SAD_DC  <= SAD_H_eff) ? SAD_DC : SAD_H;
    wire [12:0] min_all = (min_dch <= SAD_V_eff) ? min_dch : SAD_V;

    assign dc_h_v = (SAD_DC <= SAD_H_eff) ?
                ((SAD_DC   <= SAD_V_eff) ? 2'd0 : 2'd2) :
                ((SAD_H_eff<= SAD_V_eff) ? 2'd1 : 2'd2);

    assign out_dc  = {3'd0, SAD_DC};
    assign out_h   = {3'd0, SAD_H};
    assign out_v   = {3'd0, SAD_V};
endmodule

module INT_TRANSFORM #(
    parameter FF_WIDTH = 32,
    parameter INT_TRAN_WIDTH = 32
)(
    input      [16*INT_TRAN_WIDTH-1:0]         X_flat,
    output reg signed [16 * FF_WIDTH-1:0]      W_flat
);

    function reg signed [INT_TRAN_WIDTH-1:0] X_at;
        input [16*INT_TRAN_WIDTH-1:0] vec;
        input integer idx;
    begin
        X_at = $signed(vec[INT_TRAN_WIDTH*(idx+1)-1 -: INT_TRAN_WIDTH]);
    end
    endfunction

    function reg signed [FF_WIDTH-1:0] SXN;
        input signed [INT_TRAN_WIDTH-1:0] v;
        begin
        if (FF_WIDTH > INT_TRAN_WIDTH)
            SXN = {{(FF_WIDTH-INT_TRAN_WIDTH){v[INT_TRAN_WIDTH-1]}}, v};
        else if (FF_WIDTH == INT_TRAN_WIDTH)
            SXN = v;
        else
            SXN = v[INT_TRAN_WIDTH-1:0];
        end
    endfunction

    // ---- Unpack（row-major：x00,x01,x02,x03, x10,...,x33）----
    wire signed [INT_TRAN_WIDTH-1:0] x00 = X_at(X_flat,  0);
    wire signed [INT_TRAN_WIDTH-1:0] x01 = X_at(X_flat,  1);
    wire signed [INT_TRAN_WIDTH-1:0] x02 = X_at(X_flat,  2);
    wire signed [INT_TRAN_WIDTH-1:0] x03 = X_at(X_flat,  3);

    wire signed [INT_TRAN_WIDTH-1:0] x10 = X_at(X_flat,  4);
    wire signed [INT_TRAN_WIDTH-1:0] x11 = X_at(X_flat,  5);
    wire signed [INT_TRAN_WIDTH-1:0] x12 = X_at(X_flat,  6);
    wire signed [INT_TRAN_WIDTH-1:0] x13 = X_at(X_flat,  7);

    wire signed [INT_TRAN_WIDTH-1:0] x20 = X_at(X_flat,  8);
    wire signed [INT_TRAN_WIDTH-1:0] x21 = X_at(X_flat,  9);
    wire signed [INT_TRAN_WIDTH-1:0] x22 = X_at(X_flat, 10);
    wire signed [INT_TRAN_WIDTH-1:0] x23 = X_at(X_flat, 11);

    wire signed [INT_TRAN_WIDTH-1:0] x30 = X_at(X_flat, 12);
    wire signed [INT_TRAN_WIDTH-1:0] x31 = X_at(X_flat, 13);
    wire signed [INT_TRAN_WIDTH-1:0] x32 = X_at(X_flat, 14);
    wire signed [INT_TRAN_WIDTH-1:0] x33 = X_at(X_flat, 15);


    reg signed [INT_TRAN_WIDTH-1:0] t00,t01,t02,t03;
    reg signed [INT_TRAN_WIDTH-1:0] t10,t11,t12,t13;
    reg signed [INT_TRAN_WIDTH-1:0] t20,t21,t22,t23;
    reg signed [INT_TRAN_WIDTH-1:0] t30,t31,t32,t33;

    reg signed [FF_WIDTH-1:0] w00, w01, w02, w03,
                              w10, w11, w12, w13,
                              w20, w21, w22, w23,
                              w30, w31, w32, w33;

    always @(*) begin
        // ---- row pass ----
        begin : ROW0
            reg signed [INT_TRAN_WIDTH-1:0] a0,a1,a2,a3;
            a0 = x00 + x03;  a1 = x01 + x02;  a2 = x01 - x02;  a3 = x00 - x03;
            t00 = a0 + a1;   t01 = a3 + a2;   t02 = a0 - a1;   t03 = a3 - a2;
        end
        begin : ROW1
            reg signed [INT_TRAN_WIDTH-1:0] a0,a1,a2,a3;
            a0 = x10 + x13;  a1 = x11 + x12;  a2 = x11 - x12;  a3 = x10 - x13;
            t10 = a0 + a1;   t11 = a3 + a2;   t12 = a0 - a1;   t13 = a3 - a2;
        end
        begin : ROW2
            reg signed [INT_TRAN_WIDTH-1:0] a0,a1,a2,a3;
            a0 = x20 + x23;  a1 = x21 + x22;  a2 = x21 - x22;  a3 = x20 - x23;
            t20 = a0 + a1;   t21 = a3 + a2;   t22 = a0 - a1;   t23 = a3 - a2;
        end
        begin : ROW3
            reg signed [INT_TRAN_WIDTH-1:0] a0,a1,a2,a3;
            a0 = x30 + x33;  a1 = x31 + x32;  a2 = x31 - x32;  a3 = x30 - x33;
            t30 = a0 + a1;   t31 = a3 + a2;   t32 = a0 - a1;   t33 = a3 - a2;
        end

        // ---- column pass ----
        begin : COL0
            reg signed [INT_TRAN_WIDTH-1:0] a0,a1,a2,a3, y0,y1,y2,y3;
            a0 = t00 + t30;  a1 = t10 + t20;  a2 = t10 - t20;  a3 = t00 - t30;
            y0 = a0 + a1;    y1 = a3 + a2;    y2 = a0 - a1;    y3 = a3 - a2;
            w00 = y0; w10 = y1; w20 = y2; w30 = y3;
        end
        begin : COL1
            reg signed [INT_TRAN_WIDTH-1:0] a0,a1,a2,a3, y0,y1,y2,y3;
            a0 = t01 + t31;  a1 = t11 + t21;  a2 = t11 - t21;  a3 = t01 - t31;
            y0 = a0 + a1;    y1 = a3 + a2;    y2 = a0 - a1;    y3 = a3 - a2;
            w01 = y0; w11 = y1; w21 = y2; w31 = y3;
        end
        begin : COL2
            reg signed [INT_TRAN_WIDTH-1:0] a0,a1,a2,a3, y0,y1,y2,y3;
            a0 = t02 + t32;  a1 = t12 + t22;  a2 = t12 - t22;  a3 = t02 - t32;
            y0 = a0 + a1;    y1 = a3 + a2;    y2 = a0 - a1;    y3 = a3 - a2;
            w02 = y0; w12 = y1; w22 = y2; w32 = y3;
        end
        begin : COL3
            reg signed [INT_TRAN_WIDTH-1:0] a0,a1,a2,a3, y0,y1,y2,y3;
            a0 = t03 + t33;  a1 = t13 + t23;  a2 = t13 - t23;  a3 = t03 - t33;
            y0 = a0 + a1;    y1 = a3 + a2;    y2 = a0 - a1;    y3 = a3 - a2;
            w03 = y0; w13 = y1; w23 = y2; w33 = y3;
        end

        W_flat = {
            SXN(w33), SXN(w32), SXN(w31), SXN(w30),
            SXN(w23), SXN(w22), SXN(w21), SXN(w20),
            SXN(w13), SXN(w12), SXN(w11), SXN(w10),
            SXN(w03), SXN(w02), SXN(w01), SXN(w00)
        };
    end
endmodule


module QUANT_CORE #(
    parameter FF_WIDTH = 32,
    parameter QUANT_WIDTH = 32
)(
    input  signed [QUANT_WIDTH-1:0] coeff_in,
    input         [4:0]          qp,
    input         [1:0]          row,
    input         [1:0]          col,
    input         [1:0]          mode,
    output signed [FF_WIDTH-1:0] z_out
);

    reg [2:0] qdiv;
    reg [2:0] qmod;
    always @* begin
        case (qp)
            // 0..51
            0:  begin qdiv=0; qmod=0; end  1:  begin qdiv=0; qmod=1; end
            2:  begin qdiv=0; qmod=2; end  3:  begin qdiv=0; qmod=3; end
            4:  begin qdiv=0; qmod=4; end  5:  begin qdiv=0; qmod=5; end
            6:  begin qdiv=1; qmod=0; end  7:  begin qdiv=1; qmod=1; end
            8:  begin qdiv=1; qmod=2; end  9:  begin qdiv=1; qmod=3; end
            10: begin qdiv=1; qmod=4; end  11: begin qdiv=1; qmod=5; end
            12: begin qdiv=2; qmod=0; end  13: begin qdiv=2; qmod=1; end
            14: begin qdiv=2; qmod=2; end  15: begin qdiv=2; qmod=3; end
            16: begin qdiv=2; qmod=4; end  17: begin qdiv=2; qmod=5; end
            18: begin qdiv=3; qmod=0; end  19: begin qdiv=3; qmod=1; end
            20: begin qdiv=3; qmod=2; end  21: begin qdiv=3; qmod=3; end
            22: begin qdiv=3; qmod=4; end  23: begin qdiv=3; qmod=5; end
            24: begin qdiv=4; qmod=0; end  25: begin qdiv=4; qmod=1; end
            26: begin qdiv=4; qmod=2; end  27: begin qdiv=4; qmod=3; end
            28: begin qdiv=4; qmod=4; end  29: begin qdiv=4; qmod=5; end
            default: begin qdiv=0; qmod=0; end
        endcase
    end

    reg [13:0] MF_A, MF_B, MF_C;
    always @* begin
        case (qmod)
            3'd0: begin MF_A=14'd13107; MF_B=14'd8066;  MF_C=14'd5243;  end
            3'd1: begin MF_A=14'd11916; MF_B=14'd7490;  MF_C=14'd4660;  end
            3'd2: begin MF_A=14'd10082; MF_B=14'd6554;  MF_C=14'd4194;  end
            3'd3: begin MF_A=14'd9362;  MF_B=14'd5825;  MF_C=14'd3647;  end
            3'd4: begin MF_A=14'd8192;  MF_B=14'd5243;  MF_C=14'd3355;  end
            default: begin MF_A=14'd7282; MF_B=14'd4559; MF_C=14'd2893; end // qmod=5
        endcase
    end

    wire sel_A = (~row[0]) & (~col[0]);
    wire sel_C = ( row[0]) & ( col[0]);
    wire [13:0] MF = sel_A ? MF_A : (sel_C ? MF_C : MF_B);

    reg [17:0] f;  // 174762 < 2^18
    always @* begin
        if      (qp <= 5)   f = 18'd10922;
        else if (qp <= 11)  f = 18'd21845;
        else if (qp <= 17)  f = 18'd43690;
        else if (qp <= 23)  f = 18'd87381;
        else                f = 18'd174762;
    end


    wire signed [QUANT_WIDTH-1:0] s = coeff_in;
    wire coeff_neg = s[QUANT_WIDTH-1];
    wire [QUANT_WIDTH-1:0] coeff_abs = coeff_neg ? (~s + {{(QUANT_WIDTH-1){1'b0}},1'b1}) : s;

    wire [QUANT_WIDTH+13:0] mul = coeff_abs * MF;
    wire [4:0] qbits = 5'd15 + {2'b00, qdiv};


    wire [QUANT_WIDTH+13:0] f_ext = {{(QUANT_WIDTH-4){1'b0}}, f};

    wire [QUANT_WIDTH+13:0] add = mul + f_ext;
    wire [QUANT_WIDTH   :0] ushift = add >> qbits;

    wire signed [QUANT_WIDTH-1:0] z_signed_w = coeff_neg ? -$signed({1'b0,ushift})
                                                       :  $signed({1'b0,ushift});
    
    //wire signed [QUANT_WIDTH-1:0] z_narrow = z_signed_w[QUANT_WIDTH-1:0];
    assign z_out = {{(FF_WIDTH-(QUANT_WIDTH)){z_signed_w[QUANT_WIDTH-1]}}, z_signed_w};

endmodule


module DEQUANT_CORE #(
    parameter FF_WIDTH = 32,
    parameter DEQUANT_WIDTH = 32
)(
    input  signed [DEQUANT_WIDTH-1:0] z_in,
    input         [4:0]          qp, 
    input         [1:0]          row,
    input         [1:0]          col,
    input         [1:0]          mode, 
    output signed [FF_WIDTH-1:0] xhat_out
);

    reg [2:0] qdiv, qmod;
    always @* begin
        case (qp)
            5'd0:  begin qdiv=3'd0; qmod=3'd0; end
            5'd1:  begin qdiv=3'd0; qmod=3'd1; end
            5'd2:  begin qdiv=3'd0; qmod=3'd2; end
            5'd3:  begin qdiv=3'd0; qmod=3'd3; end
            5'd4:  begin qdiv=3'd0; qmod=3'd4; end
            5'd5:  begin qdiv=3'd0; qmod=3'd5; end
            5'd6:  begin qdiv=3'd1; qmod=3'd0; end
            5'd7:  begin qdiv=3'd1; qmod=3'd1; end
            5'd8:  begin qdiv=3'd1; qmod=3'd2; end
            5'd9:  begin qdiv=3'd1; qmod=3'd3; end
            5'd10: begin qdiv=3'd1; qmod=3'd4; end
            5'd11: begin qdiv=3'd1; qmod=3'd5; end
            5'd12: begin qdiv=3'd2; qmod=3'd0; end
            5'd13: begin qdiv=3'd2; qmod=3'd1; end
            5'd14: begin qdiv=3'd2; qmod=3'd2; end
            5'd15: begin qdiv=3'd2; qmod=3'd3; end
            5'd16: begin qdiv=3'd2; qmod=3'd4; end
            5'd17: begin qdiv=3'd2; qmod=3'd5; end
            5'd18: begin qdiv=3'd3; qmod=3'd0; end
            5'd19: begin qdiv=3'd3; qmod=3'd1; end
            5'd20: begin qdiv=3'd3; qmod=3'd2; end
            5'd21: begin qdiv=3'd3; qmod=3'd3; end
            5'd22: begin qdiv=3'd3; qmod=3'd4; end
            5'd23: begin qdiv=3'd3; qmod=3'd5; end
            5'd24: begin qdiv=3'd4; qmod=3'd0; end
            5'd25: begin qdiv=3'd4; qmod=3'd1; end
            5'd26: begin qdiv=3'd4; qmod=3'd2; end
            5'd27: begin qdiv=3'd4; qmod=3'd3; end
            5'd28: begin qdiv=3'd4; qmod=3'd4; end
            5'd29: begin qdiv=3'd4; qmod=3'd5; end

            default: begin qdiv=3'd1; qmod=qp-5'd1; end
        endcase
    end

    reg [5:0] a, b, c; 
    always @* begin
        case (qmod)
            3'd0: begin a=6'd10; b=6'd16; c=6'd13; end
            3'd1: begin a=6'd11; b=6'd18; c=6'd14; end
            3'd2: begin a=6'd13; b=6'd20; c=6'd16; end
            3'd3: begin a=6'd14; b=6'd23; c=6'd18; end
            3'd4: begin a=6'd16; b=6'd25; c=6'd20; end
            default: begin a=6'd18; b=6'd29; c=6'd23; end
        endcase
    end


    reg [5:0] Vij_u;
    always @* begin
        if(~row[0] && ~col[0])      Vij_u = a; // even,even
        else if ( row[0] &&  col[0]) Vij_u = b; // odd,odd
        else                         Vij_u = c; // mixed
    end

    wire signed [DEQUANT_WIDTH-1:0] z      = z_in;
    wire signed [7:0]          Vij_s  = $signed({1'b0, Vij_u});
    wire signed [26:0] prod   = z * Vij_s;
    wire signed [26:0] widened= prod <<< qdiv;
    //wire signed [DEQUANT_WIDTH-1:0] xhat_narrow = widened[DEQUANT_WIDTH-1:0];
    assign xhat_out = {{(FF_WIDTH-27){widened[26]}}, widened[24:0]};
endmodule

