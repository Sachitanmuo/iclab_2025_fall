module Handshake_syn #(parameter WIDTH=32) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
output flag_handshake_to_clk1;
input  flag_clk1_to_handshake;

output flag_handshake_to_clk2;
input  flag_clk2_to_handshake;

// Remember:
//   Don't modify the signal name
reg sreq;
wire dreq;
reg dack;
wire sack;

reg sreq_n;
wire dreq_n;
reg dack_n;
reg dvalid_n;


reg [WIDTH-1:0] data;
reg [WIDTH-1:0] data_n;
reg [WIDTH-1:0] dout_n;

assign sidle = !sreq & !sack;
always @(posedge sclk or negedge rst_n) begin
    if(!rst_n) begin
      sreq <= 0;
      data <= 0;
    end else begin
      sreq <= sreq_n;
      data <= data_n;
    end
end

always @(posedge dclk or negedge rst_n) begin
    if (!rst_n) begin
        dvalid <= 1'b0;
        dout   <= 0;
        dack   <= 0;
    end else begin
        dvalid <= dvalid_n;
        dout   <= dout_n;
        dack   <= dack_n;
    end
end

always @(*) begin
    data_n        = data;
    sreq_n        = sreq;
    dack_n        = dack;
    dvalid_n      = dvalid;
    dout_n        = 0;
    if(sready && !sack) begin
        sreq_n    = 1;
        data_n    = din;
    end else if(sack) begin
        sreq_n    = 0;
    end

    if(!dack && !dbusy && dreq) begin// New request arrives
        dvalid_n  = 1'b1;
        dout_n    = data;
    end else  begin // Consumer is ready and took the data
        dvalid_n  = 1'b0;
        dout_n    = 0;
    end

    if (dreq && !dbusy) begin
        dack_n = 1'b1;
    end else if(!dreq) begin
        dack_n = 1'b0;
    end
end





NDFF_syn u_sreq_to_dreq (
    .D      (sreq),
    .Q      (dreq),
    .clk    (dclk),
    .rst_n  (rst_n)
);

NDFF_syn u_dack_to_sack (
    .D      (dack),
    .Q      (sack),
    .clk    (sclk),
    .rst_n  (rst_n)
);

assign flag_handshake_to_clk1 = 1'b0;
assign flag_handshake_to_clk2 = 1'b0;



endmodule