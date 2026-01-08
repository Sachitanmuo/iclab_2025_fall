module FIFO_syn #(parameter WIDTH=16, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk3,
    flag_clk3_to_fifo
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

//You can change the input  output of the custom flag ports
output flag_fifo_to_clk2;
input  flag_clk2_to_fifo;

output flag_fifo_to_clk3;
input  flag_clk3_to_fifo;

wire [WIDTH-1:0] rdata_q;



//---------------------------------------------------------------------
//   FIFO Params
//---------------------------------------------------------------------
parameter PTR_WIDTH = $clog2(WORDS);
parameter GRAY_PTR_WIDTH = PTR_WIDTH + 1;

//---------------------------------------------------------------------
//   Gray Code Conversion Function
//---------------------------------------------------------------------
function [GRAY_PTR_WIDTH-1:0] bin_to_gray;
    input [GRAY_PTR_WIDTH-1:0] bin;
    bin_to_gray = (bin >> 1) ^ bin;
endfunction
//---------------------------------------------------------------------
//   Pointers
//---------------------------------------------------------------------
reg [GRAY_PTR_WIDTH-1:0] wptr;
reg [GRAY_PTR_WIDTH-1:0] rptr;

reg [GRAY_PTR_WIDTH-1:0] wptr_bin;
reg [GRAY_PTR_WIDTH-1:0] rptr_bin;


reg [GRAY_PTR_WIDTH-1:0] wptr_bin_next;
reg [GRAY_PTR_WIDTH-1:0] wptr_gray_next;
reg [GRAY_PTR_WIDTH-1:0] rptr_bin_next;
reg [GRAY_PTR_WIDTH-1:0] rptr_gray_next;

reg wfull_n;
reg rempty_n;

reg [GRAY_PTR_WIDTH-1:0] wptr_sync, rptr_sync;

//assign wptr_bin_next   = wptr_bin + (!wfull);
//assign rptr_bin_next   = rptr_bin + (!rempty);
assign wptr_bin_next   = wptr_bin + (winc && !wfull);
assign rptr_bin_next   = rptr_bin + (rinc && !rempty);
assign wptr_gray_next  = bin_to_gray(wptr_bin_next);
assign rptr_gray_next =  bin_to_gray(rptr_bin_next); 

always @(posedge wclk or negedge rst_n) begin
    if(!rst_n) begin
        wptr_bin <= 0;
        wptr     <= 0;
        wfull    <= 0;
    end else begin
        wptr_bin <= wptr_bin_next;
        wptr     <= wptr_gray_next;
        wfull    <= wfull_n;
    end
end

always @(posedge rclk or negedge rst_n) begin
    if(!rst_n) begin
        rptr_bin <= 0;
        rptr     <= 0;
        rempty   <= 1'b1;
    end else begin
        rptr_bin <= rptr_bin_next;
        rptr     <= rptr_gray_next;
        rempty   <= rempty_n;
    end
end





always @(*) begin
    wfull_n    = {~wptr_gray_next[6:5], wptr_gray_next[4:0]} == rptr_sync;
    rempty_n = (rptr_gray_next == wptr_sync);
end

assign flag_fifo_to_clk2 = wfull_n;
assign flag_fifo_to_clk3 = rempty_n;

//rdata
// Add one more register stage to rdata
always @(posedge rclk or negedge rst_n) begin
    if(!rst_n) begin
        rdata <= 0;
    end else begin
        rdata <= rdata_q;
    end
end


NDFF_BUS_syn #( .WIDTH(GRAY_PTR_WIDTH) ) u_wptr_sync (
    .D      (wptr),
    .Q      (wptr_sync),
    .clk    (rclk),
    .rst_n  (rst_n)
);

// Synchronize Read Pointer to Write Domain
NDFF_BUS_syn #( .WIDTH(GRAY_PTR_WIDTH) ) u_rptr_sync (
    .D      (rptr),
    .Q      (rptr_sync),
    .clk    (wclk),
    .rst_n  (rst_n)
);

DUAL_64X16X1BM1 u_dual_sram (
    .CKA    (wclk),                 // Port A Clock (Write)
    .CKB    (rclk),                 // Port B Clock (Read)
    .WEAN   (!(winc && !wfull)),    // Write Enable (Active Low)
    .WEBN   (1'b1),                 // Write Enable (Disable Port B)
    .CSA    (1'b1),                 // Chip Select (Active)
    .CSB    (1'b1),                 // Chip Select (Active)
    .OEA    (1'b0),                 // Output Enable (Disable Port A)
    .OEB    (1'b1),                 // Output Enable (Active Port B)
    
    // Port A Address (Write) - 6 bits
    .A0     (wptr_bin[0]),
    .A1     (wptr_bin[1]),
    .A2     (wptr_bin[2]),
    .A3     (wptr_bin[3]),
    .A4     (wptr_bin[4]),
    .A5     (wptr_bin[5]),
    
    // Port B Address (Read) - 6 bits
    .B0     (rptr_bin[0]),
    .B1     (rptr_bin[1]),
    .B2     (rptr_bin[2]),
    .B3     (rptr_bin[3]),
    .B4     (rptr_bin[4]),
    .B5     (rptr_bin[5]),
    
    // Port A Data In (Write)
    .DIA0   (wdata[0]), .DIA1(wdata[1]), .DIA2(wdata[2]), .DIA3(wdata[3]),
    .DIA4   (wdata[4]), .DIA5(wdata[5]), .DIA6(wdata[6]), .DIA7(wdata[7]),
    .DIA8   (wdata[8]), .DIA9(wdata[9]), .DIA10(wdata[10]), .DIA11(wdata[11]),
    .DIA12  (wdata[12]), .DIA13(wdata[13]), .DIA14(wdata[14]), .DIA15(wdata[15]),
    
    // Port B Data In (Unused)
    .DIB0(1'b0), .DIB1(1'b0), .DIB2(1'b0), .DIB3(1'b0),
    .DIB4(1'b0), .DIB5(1'b0), .DIB6(1'b0), .DIB7(1'b0),
    .DIB8(1'b0), .DIB9(1'b0), .DIB10(1'b0), .DIB11(1'b0),
    .DIB12(1'b0), .DIB13(1'b0), .DIB14(1'b0), .DIB15(1'b0),

    // Port B Data Out (Read)
    .DOB0(rdata_q[0]), .DOB1(rdata_q[1]), .DOB2(rdata_q[2]), .DOB3(rdata_q[3]),
    .DOB4(rdata_q[4]), .DOB5(rdata_q[5]), .DOB6(rdata_q[6]), .DOB7(rdata_q[7]),
    .DOB8(rdata_q[8]), .DOB9(rdata_q[9]), .DOB10(rdata_q[10]), .DOB11(rdata_q[11]),
    .DOB12(rdata_q[12]), .DOB13(rdata_q[13]), .DOB14(rdata_q[14]), .DOB15(rdata_q[15])
);



endmodule
