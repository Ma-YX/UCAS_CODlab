`timescale 10 ns / 1 ns

`define DATA_WIDTH 32

module alu(
	input [`DATA_WIDTH - 1:0] A,
	input [`DATA_WIDTH - 1:0] B,
	input [2:0] ALUop,
	output Overflow,
	output CarryOut,
	output Zero,
	output [`DATA_WIDTH - 1:0] Result
);

//creat wire variables for intermediate results
        wire [`DATA_WIDTH - 1:0] R_AND;
        wire [`DATA_WIDTH - 1:0] R_OR;
        wire [`DATA_WIDTH - 1:0] R_XOR;
	wire [`DATA_WIDTH - 1:0] R_NOR;
    	wire [`DATA_WIDTH - 1:0] R_ADD_SUB;
    	wire [`DATA_WIDTH - 1:0] R_SLT;
	wire [`DATA_WIDTH - 1:0] R_SLTU;
    	wire COUT;
    	wire CIN;
    	wire Cin;
    	wire [`DATA_WIDTH - 1:0] B_ADD_SUB;
	wire Compare;
//ALUop operators
    	parameter AND = 3'b000,
                  OR = 3'b001,
                  ADD = 3'b010,
		  SLTU = 3'b011,
		  XOR = 3'b100,
		  NOR = 3'b101,
                  SUB = 3'b110,
                  SLT = 3'b111;

//determine CIN and B(inverse or not) according to ALOup(SUB && SLT)
    	assign B_ADD_SUB = (ALUop[2] | (ALUop[1] & ALUop[0]) ) ? ~B : B;
    	assign CIN = ALUop[2] | (ALUop[1] & ALUop[0]);
//intermediate result of logic operations
    	assign R_AND = A & B;
    	assign R_OR = A | B;
	assign R_XOR = A ^ B;
	assign R_NOR = ~R_OR;
//instance of 32 bits carry lookahead adders
    	advance_add_32 instance_0(
        	.A(A),
        	.B(B_ADD_SUB),
        	.CIN(CIN),
        	.S(R_ADD_SUB),
        	.COUT(COUT),
		.Cin(Cin)
    	);
//result of intermediate result of SLT(U) opperations
	assign Compare =  Overflow ^ R_ADD_SUB[`DATA_WIDTH - 1];
//ADD or SUB or SLT(U) operations
	assign R_SLT = {31'b0,Compare}; 
	assign R_SLTU = {31'b0,~COUT};

//output
//final result according to ALUop
   	assign Result = ({`DATA_WIDTH{ALUop == AND}} & R_AND) |
			({`DATA_WIDTH{ALUop == OR}} & R_OR) |
			({`DATA_WIDTH{ALUop == XOR}} & R_XOR) |
			({`DATA_WIDTH{ALUop == NOR}} & R_NOR) |
			({`DATA_WIDTH{ALUop == ADD || ALUop == SUB}} & R_ADD_SUB) |
			({`DATA_WIDTH{ALUop == SLT}} & R_SLT) |
			({`DATA_WIDTH{ALUop == SLTU}} & R_SLTU) ;
//signed numbers add & sub operations whether overflow
   	assign Overflow = Cin ^ COUT;
//insigned numbers add & sub operations whether carry or borrow number from sign bit
   	assign CarryOut =  ALUop[2] ^ COUT;
//whether the result is 32'b0
   	assign Zero = ~|Result;
        
endmodule

module advance_add_32(
    input [`DATA_WIDTH - 1:0] A,
    input [`DATA_WIDTH - 1:0] B,
    input CIN,
    output Cin,
    output COUT,
    output [`DATA_WIDTH - 1:0] S  
);
    wire [`DATA_WIDTH:0] cout;
    
    assign cout[0] = CIN;
    
    genvar i;
    generate 
        for(i = 0; i < `DATA_WIDTH; i = i + 1) 
            begin : CLA
                wire p, g;
                assign p = ~A[i] & B[i] | A[i] & ~B[i];
                assign g = A[i] & B[i];
                assign S[i] = ~p & cout[i] | p & ~cout[i];
                assign cout[i + 1] = g | p & cout[i];
            end
    endgenerate 
    
    assign COUT = cout[`DATA_WIDTH];
    assign Cin = cout[`DATA_WIDTH - 1];
endmodule

