`timescale 10ns / 1ns

module custom_cpu(
	input  rst,
	input  clk,

`ifdef BHV_SIM
	input  inst_retired_fifo_full,
`endif

	//Instruction request channel
	output reg [31:0] PC,
	output Inst_Req_Valid,
	input Inst_Req_Ready,

	//Instruction response channel
	input  [31:0] Instruction,
	input Inst_Valid,
	output Inst_Ready,

	//Memory request channel
	output [31:0] Address,
	output MemWrite,
	output [31:0] Write_data,
	output [3:0] Write_strb,
	output MemRead,
	input Mem_Req_Ready,

	//Memory data response channel
	input  [31:0] Read_data,
	input Read_data_Valid,
	output Read_data_Ready, 

    output [31:0]	cpu_perf_cnt_0,
    output [31:0]	cpu_perf_cnt_1,
    output [31:0]	cpu_perf_cnt_2,
    output [31:0]	cpu_perf_cnt_3,
    output [31:0]	cpu_perf_cnt_4,
    output [31:0]	cpu_perf_cnt_5,
    output [31:0]	cpu_perf_cnt_6,
    output [31:0]	cpu_perf_cnt_7,
    output [31:0]	cpu_perf_cnt_8,
    output [31:0]	cpu_perf_cnt_9,
    output [31:0]	cpu_perf_cnt_10,
    output [31:0]	cpu_perf_cnt_11,
    output [31:0]	cpu_perf_cnt_12,
    output [31:0]	cpu_perf_cnt_13,
    output [31:0]	cpu_perf_cnt_14,
    output [31:0]	cpu_perf_cnt_15

);

/* The following two signals are leveraged for behavioral simulation, 
* both of which are delivered to testbench.
*
* STUDENTS MUST CONTROL LOGICAL BEHAVIORS of BOTH SIGNALS.
*
* inst_retire_valid (1-bit): setting to 1 for one-cycle 
* when inst_retired_fifo_full from testbench is low,  
* indicating that one instruction is being retired from
* the WB stage. 
*
* inst_retired (70-bit): detailed information of the retired instruction,
* mainly including (in order) 
* { 
*   retired PC (32-bit), 
*   reg_file write-back enable (1-bit), 
*   reg_file write-back address (5-bit), 
*   reg_file write-back data (32-bit) 
* }
*
*/
`ifdef BHV_SIM
	wire inst_retire_valid;
	wire [69:0] inst_retired;
`endif

    
    localparam RST = 9'b000000001,
               IF  = 9'b000000010,
               IW  = 9'b000000100,
               ID  = 9'b000001000,
               EX  = 9'b000010000,
               WB  = 9'b000100000,
               ST  = 9'b001000000,
               LD  = 9'b010000000,
               RDW = 9'b100000000;
    
    reg  [8:0]  current_state;
    reg  [8:0]  next_state;
    
    reg  [31:0] Instruction_reg;
    reg  [31:0] Read_data_reg;
    reg  [31:0] PC_reg;

    
    wire [5:0]  opcode;
    wire [4:0]  rs;
    wire [4:0]  rt;
    wire [4:0]  rd;
    wire [4:0]  sa;
    wire [5:0]  func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    
    wire        RF_wen;
    wire [4:0]  RF_waddr;
    wire [31:0] RF_wdata;
    wire [4:0]  RF_raddr1;
    wire [4:0]  RF_raddr2;
    wire [31:0] RF_rdata1;
    wire [31:0] RF_rdata2;
    
    wire [31:0] ALU_A;
    wire [31:0] ALU_B;
    wire [2:0]  ALUop;
    wire [31:0] ALU_result;
    wire        ALU_zero;
    wire        ALU_CarryOut;
    wire        ALU_Overflow;
    wire [31:0] Shifter_A;
    wire [31:0] Shifter_B;
    wire [1:0]  Shifterop;
    wire [31:0] Shifter_result;
    
    wire        branch;
    wire        jump;
    wire [31:0] branch_result;
    wire [31:0] jump_result;
    wire [31:0] PC4;
    wire [31:0] PC8;
    
    wire [31:0] load_data;
    
    wire [31:0] sign_extension;
    wire [31:0] zero_extension;
    wire [31:0] shiftl2_extension;
    wire [31:0] imm_extension;
    wire [31:0] jump_extension;

    reg [31:0] PC_retired;
    wire fifo_full;

`ifdef BHV_SIM
    assign inst_retire_valid = ~inst_retired_fifo_full & 
                               ((((~|opcode[5:1]) & opcode[0]) | (opcode[5:2] == 4'b0001) | (opcode == 6'b000010)) & (current_state == EX) |
                                (opcode[5:3] == 3'b101) & (current_state == ST) & MemWrite & Mem_Req_Ready |
                                (((~|opcode) | (opcode[5:3] == 3'b001) | (opcode == 6'b000011)) | (opcode[5:3] == 3'b100)) & (current_state == WB) |
                                (~|Instruction_reg) & (current_state == ID)
                               );
    assign inst_retired = {PC_retired, RF_wen, RF_waddr, RF_wdata};
    assign fifo_full = inst_retired_fifo_full;
    always @(posedge clk) begin
        if(current_state == IW) begin
            PC_retired <= PC;
        end
    end
`else
    assign fifo_full = 1'b0;
`endif
    
    always @ (posedge clk) begin
       if(rst) begin
           current_state <= RST;
       end
       else if(~fifo_full) begin
           current_state <= next_state;
       end
    end
    
    always @ (*) begin
       case(current_state)
           RST: begin 
               if(rst) begin
                   next_state = RST;
               end
               else begin
                   next_state = IF;
               end
           end
           
           IF: begin
               if(Inst_Req_Ready) begin
                   next_state = IW;
               end
               else begin
                   next_state = IF;
               end
           end
           
           IW: begin
               if(Inst_Valid) begin
                   next_state = ID;
               end
               else begin
                   next_state = IW;
               end
           end
           
           ID: begin
               if(~|Instruction_reg) begin
                   next_state = IF;
               end
               else begin
                   next_state = EX;
               end
           end
           
           //TO IF: REGIMM, I-Type branch, j
           //REGIMM: opcode = b000001
           //I-Type: opcode[5:2] = 0001
           //j: opcode = 000010
           //TO WB: R_type, I-type calculate, jal
           //R_type: opcode = 000000
           //I-type calculate: opcode[5:3] = 001
           //jal: opcode = 000011
           //TO ST: store : opcode[5:3] = 101
           //TO LD: load : opcode[5:3] = 100
           EX: begin
               if(((~|opcode[5:1]) & opcode[0]) | (opcode[5:2] == 4'b0001) | (opcode == 6'b000010)) begin
                   next_state = IF;
               end
               else if((~|opcode) | (opcode[5:3] == 3'b001) | (opcode == 6'b000011)) begin
                   next_state = WB;
               end
               else if(opcode[5:3] == 3'b101) begin
                   next_state = ST;
               end
               else begin
                   next_state = LD;
               end
           end
           
           WB: begin
               next_state = IF;
           end
           
           ST: begin
               if(Mem_Req_Ready) begin
                   next_state = IF;
               end
               else begin
                   next_state = ST;
               end
           end
           
           LD: begin
               if(Mem_Req_Ready) begin
                   next_state = RDW;
               end
               else begin
                   next_state = LD;
               end
           end
           
           RDW: begin
               if(Read_data_Valid) begin
                   next_state = WB;
               end
               else begin
                   next_state = RDW;
               end
           end
           
           default: next_state = current_state;
       endcase
    end
    
    //Instruction_reg
    always  @ (posedge  clk) begin
       if(Inst_Valid & Inst_Ready) begin
           Instruction_reg <= Instruction;
       end
       else begin
           Instruction_reg <= Instruction_reg;
       end
    end
    
    //Read_data_reg
    always  @ (posedge clk) begin
       if(Read_data_Valid & Read_data_Ready) begin
           Read_data_reg <= Read_data;
       end
       else begin
           Read_data_reg <= Read_data_reg;
       end
    end
    
    //PC_reg
    always @ (posedge clk) begin
       if(current_state[1]) begin
           PC_reg <= PC;
       end 
       else begin
           PC_reg <= PC_reg;
       end
    end

    always @ (posedge clk) begin
        if(rst) begin
            PC <= 32'b0;
        end
        else if(current_state[3]) begin //ID
            PC <= branch ? branch_result : jump ? jump_result : PC4;
        end
        else begin
            PC <= PC;
        end
    end
    
    assign Inst_Req_Valid = current_state[1] & ~fifo_full;
    assign Inst_Ready = current_state[0] | current_state[2] & ~fifo_full;
    assign Read_data_Ready = current_state[0] | current_state[8] & ~fifo_full;
    
    //analyse Instruction
    assign opcode      = Instruction_reg[31:26];
    assign rs          = Instruction_reg[25:21];
    assign rt          = Instruction_reg[20:16];
    assign rd          = Instruction_reg[15:11];
    assign sa          = Instruction_reg[10:6];
    assign func        = Instruction_reg[5:0];
    assign imm         = Instruction_reg[15:0];
    assign instr_index = Instruction_reg[25:0];
    
    
    //extension operations
    assign sign_extension    = {{16{imm[15]}}, imm};
    assign zero_extension    = {16'b0, imm};
    assign shiftl2_extension = {sign_extension[29:0], 2'b0};
    assign jump_extension    = {PC4[31:28], instr_index, 2'b0};
    //I-type: zero-extension: andi, ori, xori(opcode[2] = 1); sign-extension: other caculate operations(opcode[2] = 0), load & store(opcode[5] = 1)
    //branch operations use shiftl2_extension
    assign imm_extension = opcode[2]                 ? zero_extension :
                           (~opcode[2] | opcode[5]) ? sign_extension :
                           shiftl2_extension;
    
    //define ALU control signals
    //R-Type calculate: opcode[5:0] = 000000 &&  func[5] = 1
    //I-Type calculate: opcode[5:3] = 001
    //mov             : opcode[5:0] = 000000 && {func[5:3], func[1]} = 0011
    //REGIMM          : opcode[5:0] = 000001
    //I-type branch   : opcode[5:2] = 0001
    //load store      : opcode[5]   = 1
    assign ALUop = (~|opcode)                ? (func[5] == 1         ? (func[3:2] == 2'b00 ? {func[1] , 2'b10}         :
                                                                        func[3:2] == 2'b01 ? {func[1] , 1'b0, func[0]} : 
                                                                        func[3:2] == 2'b10 ? {~func[0], 2'b11}         :
                                                                        0)                                             :
                                               {func[5:3], func[1]} == 4'b0011 ?  3'b010                       :
                                                3'b0) :
                    opcode[5:3] == 3'b001    ? (opcode[2:1] == 2'b00           ? {opcode[1] , 2'b10}           :
                                                opcode[2]                      ? {opcode[1] , 1'b0, opcode[0]} :
                                                opcode[2:1] == 2'b01           ? {~opcode[0], 2'b11}           :
                                                3'b0) :
                    opcode[5:0] == 6'b000001 ?  3'b110 :
                    opcode[5:2] == 4'b0001   ? (opcode[1]                      ? 3'b110                        :
                                                   ~opcode[1]                     ? 3'b110                        :
                                                3'b0) :
                    opcode[5]                ?  3'b010 :
                    3'b0;
      assign ALU_A = ((~|opcode) & ({func[5:3], func[1]} == 4'b0011)) ? 32'b0 : RF_rdata1;
      assign ALU_B = ((opcode[5:3] == 3'b001) & (opcode[2:0] != 3'b111)) | (opcode[5] == 1'b1) ? imm_extension :
                     ((opcode[5:1] == 5'b00011) | (opcode[5:0] == 6'b000001))                  ? 32'b0         :
                     RF_rdata2;
                     
      //define Shifter control signals
      //R-Type shift: opcode[5:0] = 000000, func[5:3] = 000
      //sa: func[2] = 0; rs: func[2] = 1
      assign Shifterop = {2{(~|opcode) & (~|func[5:3])}} & func[1:0];
      assign Shifter_A = RF_rdata2;
      assign Shifter_B = func[2] ? RF_rdata1 : {{27'b0}, sa};
    
    alu alu(
       .A(ALU_A),
       .B(ALU_B),
       .ALUop(ALUop),
       .Overflow(ALU_Overflow),
       .CarryOut(ALU_CarryOut),
       .Zero(ALU_zero),
       .Result(ALU_result)
    );
    
    shifter shifter(
       .A(Shifter_A),
       .B(Shifter_B),
       .Shiftop(Shifterop),
       .Result(Shifter_result)
    );

    reg_file reg_file(
       .clk(clk),
       .rst(rst),
       .raddr1(RF_raddr1),
       .raddr2(RF_raddr2),
       .rdata1(RF_rdata1),
       .rdata2(RF_rdata2),
       .waddr(RF_waddr),
       .wdata(RF_wdata),
       .wen(RF_wen)
    );
    
    //PC singals
    assign PC4 = PC + 4;
    assign PC8 = PC_reg + 8;
    
    //define branch siganls
    //beq, bne, blez, bgtz: opcode[5:2] = 0001 , opcode[1:0] = 00, 01, 10, 11
    //bltz, bgez:         : opcode[5:0] = 000001,  rt[0] = 0, 1
    assign branch = (((~|opcode[5:3]) & opcode[2]) & (((opcode[1:0] == 2'b00) & ALU_zero)                                    |
                                                      ((opcode[1:0] == 2'b01) & ~ALU_zero)                                   |
                                                      ((opcode[1:0] == 2'b10) & (ALU_zero | (ALU_Overflow ^ ALU_result[31]))) |
                                                      ((opcode[1:0] == 2'b11) & (~ALU_zero & (ALU_Overflow ^ (~ALU_result[31])))) 
                                                     )
                     ) |
                    (((~|opcode[5:1]) & opcode[0]) & ((~rt[0] & (ALU_Overflow ^ ALU_result[31])) |
                                                      (rt[0] & (ALU_Overflow ^ (~ALU_result[31])))
                                                     )                           
                    ) ;
     assign branch_result = PC4 + shiftl2_extension;
     
     //define jump signals
     //R-Type jump: opcode[5:0] = 000000, {func[5:3], func[1]} == 0010
     //J-type     : opcode[5:1] = 00001
     assign jump = ((~|opcode) & ({func[5:3], func[1]} == 4'b0010)) | ((~|opcode[5:2]) & opcode[1]);
     assign jump_result = ({32{(~|opcode) & ({func[5:3], func[1]} == 4'b0010)}} & RF_rdata1)       |
                          ({32{(~|opcode[5:2]) & opcode[1]}}                    & jump_extension)  ;
    
    
    //define signals concerning register file
    assign RF_raddr1 = rs;
    assign RF_raddr2 = rt;
    //jal: opcode[5:0] = 000011                     r31
    //I-type calculate: opcode[5:3] = 001           rt
    //I-type load: opcode[5] = 1, opcode[3] = 0     rt
    //other operations                              rd (or not cared)
    assign RF_waddr = (opcode[5:0] == 6'b000011)                           ? 5'd31 :
                      ((opcode[5:3] == 3'b001) | (opcode[5] & ~opcode[3])) ? rt    :
                      rd ;
    //consider operations not write register file
    //jr:               opcode[5:0] = 000000, func[5:0] = 001000
    //movz:             opcode[5:0] = 000000, func[5:0] = 001010
    //movn:             opcode[5:0] = 000000, func[5:0] = 001011
    //REGIMM:           opcode[5:0] = 000001
    //j:                opcode[5:0] = 000010
    //I-type branch:    opcode[5:2] = 0001
    //store:            opcode[5] = opcode[3] = 1
    assign RF_wen =  (current_state == WB) &
                     ~(((~|opcode) & ((func[5:0] == 6'b001000) | ((func[5:0] == 6'b001010) & ~ALU_zero) | ((func[5:0] == 6'b001011) & ALU_zero))) |
                      ((~|opcode[5:1]) & opcode[0])                                                                                              |
                      (opcode[5:0] == 6'b000010)                                                                                                 |
                      (opcode[5:2] == 4'b0001)                                                                                                   |
                      (opcode[5] & opcode[3])
                     );
    //R-type calculate: opcode[5:0] = 000000, func[5] = 1
    //R-type shift:     opcode[5:0] = 000000, func[5:3] = 000
    //R-type mov:       opcode[5:0] = 000000, func[5:0] = 001010, 001011
    //R-type jalr:      opcode[5:0] = 000000, func[5:0] = 001001
    //I-type calculate: opcode[5:3] = 001 (except lui)
    //jal:              opcode[5:0] = 000011
    //lui:              opcode[5:0] = 001111
    //load:             opcode[5] = 1, opcode[3] = 0
    assign RF_wdata = ((~|opcode) & ((func[5:0] == 6'b001010) & ALU_zero | (func[5:0] == 6'b001011) & ~ALU_zero)) ? RF_rdata1      :
                      (((~|opcode) &  (func[5:0] == 6'b001001)) | (opcode[5:0] == 6'b000011))                     ? PC8            :
                      ((~|opcode) &  (~|func[5:3]))                                                               ? Shifter_result :
                      (opcode[5:0] == 6'b001111)                                                                  ? {imm, 16'b0}   :
                      (opcode[5] & ~opcode[3])                                                                    ? load_data      :
                      ALU_result;
    

    wire [4:0] swl_shift_digits;
    wire [4:0] swr_shift_digits;
    
    wire [31:0] lb_data;
    wire [31:0] lh_data;
    wire [31:0] lw_data;
    wire [31:0] lbu_data;
    wire [31:0] lhu_data;
    wire [31:0] lwl_data;
    wire [31:0] lwr_data;
    
    //define mem control signals
    assign MemWrite = current_state[6] & ~fifo_full; //ST
    assign MemRead  = current_state[7] & ~fifo_full; //LD
    assign Address  = {ALU_result[31:2], 2'b0};
    
    //define Write_str & Write_data
    //store(opcode[5:3] = 101), sb(opcode[2:0] = 000), sh(001), sw(011), swl(010), swr(110)
    assign swl_shift_digits = ({5{~ALU_result[1] & ~ALU_result[0]}} & 5'd24) |
                              ({5{~ALU_result[1] & ALU_result[0]}}  & 5'd16) |
                              ({5{ALU_result[1]  & ~ALU_result[0]}} & 5'd8)  ;
    assign swr_shift_digits = ({5{ALU_result[1]  & ALU_result[0]}}  & 5'd24) |
                              ({5{ALU_result[1]  & ~ALU_result[0]}} & 5'd16) |
                              ({5{~ALU_result[1] & ALU_result[0]}}  & 5'd8)  ;
    assign Write_strb = ({4{opcode[2:0] == 3'b000}} & {ALU_result[1] & ALU_result[0], ALU_result[1] & ~ALU_result[0], ~ALU_result[1] & ALU_result[0], ~ALU_result[1] & ~ALU_result[0]}) |
                        ({4{opcode[2:0] == 3'b001}} & {ALU_result[1], ALU_result[1], ~ALU_result[1], ~ALU_result[1]}) |
                        ({4{opcode[2:0] == 3'b011}} & 4'b1111) |
                        ({4{opcode[2:0] == 3'b010}} & {ALU_result[1] & ALU_result[0], ALU_result[1], ALU_result[1] | ALU_result[0], 1'b1}) |
                        ({4{opcode[2:0] == 3'b110}} & {1'b1, ~(ALU_result[1] & ALU_result[0]), ~ALU_result[1], ~(ALU_result[1] | ALU_result[0])}) ;
    assign Write_data = ({32{opcode[2:0] == 3'b000}} & {4{RF_rdata2[7:0]}}) |
                        ({32{opcode[2:0] == 3'b001}} & {2{RF_rdata2[15:0]}}) |
                        ({32{opcode[2:0] == 3'b011}} & RF_rdata2) |
                        ({32{opcode[2:0] == 3'b010}} & (RF_rdata2 >> swl_shift_digits)) |
                        ({32{opcode[2:0] == 3'b110}} & (RF_rdata2 << swr_shift_digits)) ;
    
    //define load data
    //lb(000), lh(001), lw(011), lbu(100), lhu(101), lwl(010), lwr(110)
    assign lb_data   = ({32{~ALU_result[1] & ~ALU_result[0]}} & {{24{Read_data_reg[7]}} , Read_data_reg[7:0]})   |
                       ({32{~ALU_result[1] & ALU_result[0]}}  & {{24{Read_data_reg[15]}}, Read_data_reg[15:8]})  |
                       ({32{ALU_result[1]  & ~ALU_result[0]}} & {{24{Read_data_reg[23]}}, Read_data_reg[23:16]}) |
                       ({32{ALU_result[1]  & ALU_result[0]}}  & {{24{Read_data_reg[31]}}, Read_data_reg[31:24]}) ;
    assign lh_data   = ({32{~ALU_result[1]}} & {{16{Read_data_reg[15]}}, Read_data_reg[15:0]})  |
                       ({32{ALU_result[1]}}  & {{16{Read_data_reg[31]}}, Read_data_reg[31:16]}) ;
    assign lw_data   = Read_data_reg[31:0];
    assign lbu_data  = {24'b0, lb_data[7:0]};
    assign lhu_data  = {16'b0, lh_data[15:0]};
    assign lwl_data  = ({32{~ALU_result[1] & ~ALU_result[0]}} & {Read_data_reg[7:0] , RF_rdata2[23:0]}) |
                       ({32{~ALU_result[1] & ALU_result[0]}}  & {Read_data_reg[15:0], RF_rdata2[15:0]}) |
                       ({32{ALU_result[1]  & ~ALU_result[0]}} & {Read_data_reg[23:0], RF_rdata2[7:0]})  |
                       ({32{ALU_result[1]  & ALU_result[0]}}  & Read_data_reg) ;
    assign lwr_data  = ({32{~ALU_result[1] & ~ALU_result[0]}} & Read_data_reg) |
                       ({32{~ALU_result[1] & ALU_result[0]}}  & {RF_rdata2[31:24], Read_data_reg[31:8]})  |
                       ({32{ALU_result[1]  & ~ALU_result[0]}} & {RF_rdata2[31:16], Read_data_reg[31:16]}) |
                       ({32{ALU_result[1]  & ALU_result[0]}}  & {RF_rdata2[31:8] , Read_data_reg[31:24]}) ;
    assign load_data = ({32{opcode[2:0] == 3'b000}} & lb_data)  |
                       ({32{opcode[2:0] == 3'b001}} & lh_data)  |
                       ({32{opcode[2:0] == 3'b011}} & lw_data)  |
                       ({32{opcode[2:0] == 3'b100}} & lbu_data) |
                       ({32{opcode[2:0] == 3'b101}} & lhu_data) |
                       ({32{opcode[2:0] == 3'b010}} & lwl_data) |
                       ({32{opcode[2:0] == 3'b110}} & lwr_data) ;

    //cycle count
    reg [31:0] cycle_cnt;
    reg [31:0] ins_cnt;
    reg [31:0] mem_cnt;
    reg [31:0] branch_cnt;
    reg [31:0] branch_suc_cnt;
    reg [31:0] jump_cnt;
    reg [31:0] jump_suc_cnt;
    
    always @(posedge clk) begin
        if(rst) begin
            cycle_cnt <= 32'b0;
        end 
        else begin
            cycle_cnt <= cycle_cnt + 32'b1;
        end
    end
    
    always @(posedge clk) begin
        if(rst) begin
            ins_cnt <= 32'b0;
        end 
        else if(current_state[1]) begin
            ins_cnt <= ins_cnt + 32'b1;
        end
        else begin
            ins_cnt <= ins_cnt;
        end
    end
    
    always @(posedge clk) begin
        if(rst) begin
            mem_cnt <= 32'b0;
        end 
        else if(current_state[6] | current_state[7]) begin
            mem_cnt <= mem_cnt + 32'b1;
        end
        else begin
            mem_cnt <= mem_cnt;
        end
    end
    //beq, bne, blez, bgtz: opcode[5:2] = 0001 , opcode[1:0] = 00, 01, 10, 11
    //bltz, bgez:         : opcode[5:0] = 000001,  rt[0] = 0, 1
    always @(posedge clk) begin
        if(rst) begin
            branch_cnt <= 32'b0;
        end 
        else if(current_state[4] & (((~|opcode[5:1]) & opcode[0]) | ((~|opcode[5:3]) & opcode[2]))) begin
            branch_cnt <= branch_cnt + 32'b1;
        end
        else begin
            branch_cnt <= branch_cnt;
        end
    end
    
    always @(posedge clk) begin
        if(rst) begin
            branch_suc_cnt <= 32'b0;
        end 
        else if(current_state[4] & (((~|opcode[5:1]) & opcode[0]) | ((~|opcode[5:3]) & opcode[2])) & branch) begin
            branch_suc_cnt <= branch_suc_cnt + 32'b1;
        end
        else begin
            branch_suc_cnt <= branch_suc_cnt;
        end
    end
    //R-Type jump: opcode[5:0] = 000000, {func[5:3], func[1]} == 0010
     //J-type     : opcode[5:1] = 00001
    always @(posedge clk) begin
        if(rst) begin
            jump_cnt <= 32'b0;
        end 
        else if(current_state[4] & (((~|opcode) & (~func[5] & func[3] & ~func[1])) | ((~|opcode[5:2]) & opcode[1]))) begin
            jump_cnt <=jump_cnt + 32'b1;
        end
        else begin
            jump_cnt <= jump_cnt;
        end
    end
    
    always @(posedge clk) begin
        if(rst) begin
            jump_suc_cnt <= 32'b0;
        end 
        else if(current_state[4] & (((~|opcode) & (~func[5] & func[3] & ~func[1])) | ((~|opcode[5:2]) & opcode[1])) & jump) begin
            jump_suc_cnt <= jump_suc_cnt + 32'b1;
        end
        else begin
            jump_suc_cnt <= jump_suc_cnt;
        end
    end
    
    assign cpu_perf_cnt_0 = cycle_cnt;
    assign cpu_perf_cnt_1 = mem_cnt;
    assign cpu_perf_cnt_2 = ins_cnt;
    assign cpu_perf_cnt_3 = branch_cnt;
    assign cpu_perf_cnt_4 = branch_suc_cnt;
    assign cpu_perf_cnt_5 = jump_cnt;
    assign cpu_perf_cnt_6 = jump_suc_cnt;

endmodule

