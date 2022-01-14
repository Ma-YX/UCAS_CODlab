`timescale 10 ns / 1 ns

`define DATA_WIDTH 32

module shifter (
	input [`DATA_WIDTH - 1:0] A,
	input [`DATA_WIDTH - 1:0] B,
	input [1:0] Shiftop,
	output [`DATA_WIDTH - 1:0] Result
);

//define Shifterop operations: left shift; arithmatic right shift, logic right shift
parameter L = 2'b00,
           AR = 2'b11,
           LR = 2'b10;

//define intermediate reg
//results
wire [`DATA_WIDTH - 1:0] R_L;
wire [`DATA_WIDTH - 1:0] R_AR;
wire [`DATA_WIDTH - 1:0] R_LR;
//shift digits

assign R_L = A << B[4:0];
assign R_LR = A >> B[4:0];
assign R_AR = ($signed(A)) >>> B[4:0];

assign Result = ({`DATA_WIDTH{Shiftop == L}} & R_L) |
                ({`DATA_WIDTH{Shiftop == AR}} & R_AR) |
                ({`DATA_WIDTH{Shiftop == LR}} & R_LR);


endmodule
