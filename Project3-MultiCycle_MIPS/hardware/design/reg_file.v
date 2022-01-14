`timescale 10 ns / 1 ns

`define DATA_WIDTH 32
`define ADDR_WIDTH 5

module reg_file(
	input clk,
	input rst,
	input [`ADDR_WIDTH - 1:0] waddr,
	input [`ADDR_WIDTH - 1:0] raddr1,
	input [`ADDR_WIDTH - 1:0] raddr2,
	input wen,
	input [`DATA_WIDTH - 1:0] wdata,
	output [`DATA_WIDTH - 1:0] rdata1,
	output [`DATA_WIDTH - 1:0] rdata2
);

	reg [`DATA_WIDTH - 1:0] r [`DATA_WIDTH - 1:0];

	always @(posedge clk) begin
		if(wen & (|waddr)) begin
			r[waddr] <= wdata;
		end
	end
	
	assign rdata1 = {`DATA_WIDTH{|raddr1}} & r[raddr1];
	assign rdata2 = {`DATA_WIDTH{|raddr2}} & r[raddr2];

endmodule
