`timescale 10ns / 1ns

module custom_cpu(
    input  rst,
    input  clk,

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

    output [31:0]    cpu_perf_cnt_0,
    output [31:0]    cpu_perf_cnt_1,
    output [31:0]    cpu_perf_cnt_2,
    output [31:0]    cpu_perf_cnt_3,
    output [31:0]    cpu_perf_cnt_4,
    output [31:0]    cpu_perf_cnt_5,
    output [31:0]    cpu_perf_cnt_6,
    output [31:0]    cpu_perf_cnt_7,
    output [31:0]    cpu_perf_cnt_8,
    output [31:0]    cpu_perf_cnt_9,
    output [31:0]    cpu_perf_cnt_10,
    output [31:0]    cpu_perf_cnt_11,
    output [31:0]    cpu_perf_cnt_12,
    output [31:0]    cpu_perf_cnt_13,
    output [31:0]    cpu_perf_cnt_14,
    output [31:0]    cpu_perf_cnt_15

);
    localparam RST = 9'b000000001,
               IF  = 9'b000000010,
               IW  = 9'b000000100,
               ID  = 9'b000001000,
               EX  = 9'b000010000,
               WB  = 9'b000100000,
               ST  = 9'b001000000,
               LD  = 9'b010000000,
               RDW = 9'b100000000;

    reg [8:0] current_state;
    reg [8:0] next_state;
    
    reg [31:0] Instruction_reg;
    reg [31:0] PC_reg;
    reg [31:0] Read_data_reg;
    //reg [31:0] ALU_Shifter_reg;
    
    wire [6:0]   opcode;
    wire [4:0]   rs1;
    wire [4:0]   rs2;
    wire [4:0]   rd;
    wire [6:0]   funct7;
    wire [2:0]   funct3;
    wire [11:0]  imm_Itype;
    wire [4:0]   shamt;
    wire [11:0]  imm_Stype;
    wire [12:1]  imm_Btype;
    wire [31:12] imm_Utype;
    wire [20:1]  imm_Jtype;
    
    wire R_type;
    wire I_type;
    wire I_type_calc;
    wire I_type_load;
    wire I_type_jalr;
    wire J_type;
    wire S_type;
    wire B_type;
    wire U_type;
    
    wire RF_wen;
    wire [4:0]  RF_waddr;
    wire [31:0] RF_wdata;
    wire [4:0]  RF_raddr1;
    wire [4:0]  RF_raddr2;
    wire [31:0] RF_rdata1;
    wire [31:0] RF_rdata2;
    
    wire [2:0]  ALUop;
    wire [31:0] ALU_A;
    wire [31:0] ALU_B;
    wire [31:0] ALU_result;
    wire        ALU_zero;
    wire        ALU_CarryOut;
    wire        ALU_Overflow;
    wire [1:0]  Shifterop;
    wire [31:0] Shifter_A;
    wire [31:0] Shifter_B;
    wire [31:0] Shifter_result;
    
    wire branch;
    wire jump;
    wire AUIPC;
    wire [31:0] branch_result;
    wire [31:0] jump_result;
    wire [31:0] AUIPC_result;
    wire [31:0] PC4;
    wire [31:0] PC_reg4;
    
    wire [31:0] lb_data;
    wire [31:0] lh_data;
    wire [31:0] lw_data;
    wire [31:0] lbu_data;
    wire [31:0] lhu_data;
    wire [31:0] load_data;
    
    wire [31:0] sign_extension;
    wire [31:0] zero_extension;
    wire [31:0] imm_extension;
    wire [31:0] Btype_extension;
    wire [31:0] Utype_extension;
    wire [31:0] Jtype_extension;
    
    always @ (posedge clk) begin
        if(rst)
            current_state <= RST;
        else
            current_state <= next_state;
    end
    
    always @ (*) begin
        case(current_state)
            RST: begin
                if(rst)
                    next_state = RST;
                else
                    next_state = IF;
            end
            
            IF: begin
                if(Inst_Req_Ready)
                    next_state = IW;
                else
                    next_state = IF;
            end
            
            IW: begin
                if(Inst_Valid)
                    next_state = ID;
                else
                    next_state = IW;
            end
            
            ID: begin
                next_state = EX;
            end
            
            //TO IF: B-type;
            //TO WB: R-type, I-type(calc), U-type, J-type;
            //TO ST: S-type;
            //TO LD: I-type(load);
            EX: begin
                if(B_type)
                    next_state = IF;
                else if(R_type | I_type_calc | I_type_jalr | U_type | J_type)
                    next_state = WB;
                else if(S_type)
                    next_state = ST;
                else if(I_type_load)
                    next_state = LD;
            end
            
            WB: begin
                next_state = IF;
            end
            
            ST: begin
                if(Mem_Req_Ready)
                    next_state = IF;
                else
                    next_state = ST;
            end
            
            LD: begin
                if(Mem_Req_Ready)
                   next_state = RDW;
                else
                   next_state = LD;
            end
            
            RDW: begin
                if(Read_data_Valid)
                    next_state = WB;
                else
                    next_state = RDW;
            end
            
            default: next_state = current_state;
        endcase 
    end
    
    //Instruction
    always  @ (posedge clk) begin
        if(Inst_Valid & Inst_Ready)
           Instruction_reg <= Instruction;
        else
           Instruction_reg <= Instruction_reg;
    end
    
    //Read_data
    always @ (posedge clk) begin
        if(Read_data_Valid & Read_data_Ready)
            Read_data_reg <= Read_data;
        else
            Read_data_reg <= Read_data_reg;
    end
    
    //PC
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
        else if(current_state[4]) begin //EX
            PC <= branch ? branch_result : jump ? jump_result : PC4;
        end
        else begin
            PC <= PC;
        end
    end
    assign PC4 = PC + 4;
    assign PC_reg4 = PC_reg + 4;
    
    assign Inst_Req_Valid = current_state[1];
    assign Inst_Ready = current_state[0] | current_state[2];
    assign Read_data_Ready = current_state[0] | current_state[8];
    
    assign opcode    = Instruction_reg[6:0];
    assign rs1       = Instruction_reg[19:15];
    assign rs2       = Instruction_reg[24:20];
    assign rd        = Instruction_reg[11:7];
    assign funct3    = Instruction_reg[14:12];
    assign funct7    = Instruction_reg[31:25];
    assign shamt     = rs2;
    assign imm_Itype = Instruction_reg[31:20];
    assign imm_Stype = {Instruction_reg[31:25], Instruction_reg[11:7]};
    assign imm_Btype = {Instruction_reg[31], Instruction_reg[7], Instruction_reg[30:25], Instruction_reg[11:8]};
    assign imm_Utype = Instruction_reg[31:12];
    assign imm_Jtype = {Instruction_reg[31], Instruction_reg[19:12], Instruction_reg[20], Instruction_reg[30:21]};
    
    assign R_type = (opcode == 7'b0110011);
    assign I_type = I_type_calc | I_type_load | I_type_jalr;
    assign I_type_calc = (opcode == 7'b0010011);
    assign I_type_load = (opcode == 7'b0000011);
    assign I_type_jalr = (opcode == 7'b1100111);
    assign S_type = (opcode == 7'b0100011);
    assign B_type = (opcode == 7'b1100011);
    assign U_type = (opcode == 7'b0110111) | (opcode == 7'b0010111);
    assign J_type = (opcode == 7'b1101111);
    
    assign sign_extension = ({32{I_type}} & {{20{imm_Itype[11]}}, imm_Itype}) |
                            ({32{S_type}} & {{20{imm_Stype[11]}}, imm_Stype});
    assign zero_extension = ({32{I_type}} & {{20{1'b0}}, imm_Itype}) |
                            ({32{S_type}} & {{20{1'b0}}, imm_Stype});
    assign imm_extension = ({32{I_type_calc & (funct3 == 3'b011)}} & zero_extension) |
                           ({32{~(I_type_calc & (funct3 == 3'b011))}} & sign_extension);
    assign Btype_extension = {{19{imm_Btype[12]}}, imm_Btype, 1'b0};
    assign Utype_extension = {imm_Utype, 12'b0};
    assign Jtype_extension = {{11{imm_Jtype[20]}}, imm_Jtype, 1'b0};
    
    //ALUop: 
    //AND = 3'b000
    //OR = 3'b001
    //ADD = 3'b010   : R_type, I_type_calc, I_type_load/jalr, S_type
    //SLTU = 3'b011
    //XOR = 3'b100
    //NOR = 3'b101
    //SUB = 3'b110   : R_type, I_type_calc, B_type 
    //SLT = 3'b111
    assign ALUop = ({3{R_type}} & (({3{~funct7[5] & (~|funct3)}} & 3'b010) |
                                   ({3{funct7[5] & (~|funct3)}} & 3'b110) |
                                   ({3{funct3 == 3'b010}} & 3'b111) |
                                   ({3{(funct3 == 3'b011) | (funct3 == 3'b100)}} & funct3) |
                                   ({3{(&funct3) | (funct3 == 3'b110)}} & ~funct3) 
                                  )
                   ) |
                   ({3{I_type_calc}} & (({3{~|funct3}} & 3'b010) |
                                   ({3{funct3 == 3'b010}} & 3'b111) |
                                   ({3{(funct3 == 3'b011) | (funct3 == 3'b100)}} & funct3) |
                                   ({3{(&funct3) | (funct3 == 3'b001)}} & ~funct3)
                                  ) 
                   ) |
                   ({3{I_type_load | S_type | I_type_jalr}} & 3'b010) |
                   ({3{B_type}} & 3'b110) ;
    assign ALU_A = RF_rdata1;
    assign ALU_B = ({32{R_type | B_type}} & RF_rdata2) |
                   ({32{I_type | S_type}} & imm_extension);
    //Shifterop:
    //L = 2'b00
    //AR = 2'b11
    //LR = 2'b10
    assign Shifterop = {funct3[2], funct7[5]};
    assign Shifter_A = RF_rdata1;
    assign Shifter_B = ({32{R_type}} & {27'b0, RF_rdata2[4:0]}) |
                       ({32{I_type}} & {27'b0, shamt});
    
    assign RF_raddr1 = rs1;
    assign RF_raddr2 = rs2;
    assign RF_waddr = rd;
   //R-type, I-type-calc: ALU_result | Shifter_result
   //I-type-load: Read_data;
   //I-type-jalr: pc4
   //U-type: LUI: Utype_extension, AUIPC: AUIPC_result
   //J-type: pc4
    assign RF_wdata = ({32{R_type | I_type_calc}} & (({32{(funct3 == 3'b001) | (funct3 == 3'b101)}} & Shifter_result) |
                                                     ({32{~((funct3 == 3'b001) | (funct3 == 3'b101))}} & ALU_result)
                                                    )
                      ) |
                      ({32{I_type_load}} & load_data) |
                      ({32{I_type_jalr | J_type}} & PC_reg4) |
                      ({32{U_type}} & (({32{opcode == 7'b0110111}} & Utype_extension) |
                                       ({32{opcode == 7'b0010111}} & AUIPC_result)
                                      )
                      );
    //R-type, I-type, U-type, J-type
    assign RF_wen = current_state[5];
    
    //BEQ(==): funct3 = 000
    //BNE(!=): funct3 = 001
    //BLT(<) : funct3 = 100
    //BGE(>=): funct3 = 101
    //BLTU   : funct3 = 110
    //BGEU   : funct3 = 111
    assign branch = B_type & (((~|funct3) & ALU_zero) |
                              ((funct3 == 3'b001) & ~ALU_zero) |
                              ((funct3 == 3'b100) & (ALU_Overflow ^ ALU_result[31])) |
                              ((funct3 == 3'b101) & ~(ALU_Overflow ^ ALU_result[31])) |
                              ((funct3 == 3'b110) & ALU_CarryOut) |
                              ((&funct3) & ~ALU_CarryOut)
                             );
    assign branch_result = PC_reg + Btype_extension;
    assign jump = J_type | I_type_jalr;
    assign jump_result = ({32{J_type}} & (PC_reg + Jtype_extension)) |
                         ({32{I_type_jalr}} & {ALU_result[31:1], 1'b0});
    assign AUIPC_result = PC_reg + Utype_extension;
    
    assign MemWrite = current_state[6];
    assign MemRead = current_state[7];
    assign Address = {ALU_result[31:2], 2'b00};
    
    assign lb_data = ({32{~ALU_result[1] & ~ALU_result[0]}} & {{24{Read_data_reg[7]}} , Read_data_reg[7:0]})   |
                     ({32{~ALU_result[1] & ALU_result[0]}}  & {{24{Read_data_reg[15]}}, Read_data_reg[15:8]})  |
                     ({32{ALU_result[1]  & ~ALU_result[0]}} & {{24{Read_data_reg[23]}}, Read_data_reg[23:16]}) |
                     ({32{ALU_result[1]  & ALU_result[0]}}  & {{24{Read_data_reg[31]}}, Read_data_reg[31:24]}) ;
    assign lh_data = ({32{~ALU_result[1]}} & {{16{Read_data_reg[15]}}, Read_data_reg[15:0]})  |
                     ({32{ALU_result[1]}}  & {{16{Read_data_reg[31]}}, Read_data_reg[31:16]}) ;
    assign lw_data = Read_data_reg;
    assign lbu_data = {{24{1'b0}}, lb_data[7:0]};
    assign lhu_data = {{16{1'b0}}, lh_data[15:0]};
    assign load_data = ({32{~|funct3}} & lb_data) |
                       ({32{funct3 == 3'b001}} & lh_data) |
                       ({32{funct3 == 3'b010}} & lw_data) |
                       ({32{funct3 == 3'b100}} & lbu_data) |
                       ({32{funct3 == 3'b101}} & lhu_data);
                       
    assign Write_strb = ({4{funct3 == 3'b000}} & {ALU_result[1] & ALU_result[0], ALU_result[1] & ~ALU_result[0], ~ALU_result[1] & ALU_result[0], ~ALU_result[1] & ~ALU_result[0]}) |
                        ({4{funct3 == 3'b001}} & {ALU_result[1], ALU_result[1], ~ALU_result[1], ~ALU_result[1]}) |
                        ({4{funct3 == 3'b010}} & 4'b1111);
    assign Write_data = ({32{funct3 == 3'b000}} & {4{RF_rdata2[7:0]}}) |
                        ({32{funct3 == 3'b001}} & {2{RF_rdata2[15:0]}}) |
                        ({32{funct3 == 3'b010}} & RF_rdata2) ;
    
    
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

    always @(posedge clk) begin
        if(rst) begin
            branch_cnt <= 32'b0;
        end 
        else if(current_state[4] & B_type) begin
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
        else if(current_state[4] & B_type & branch) begin
            branch_suc_cnt <= branch_suc_cnt + 32'b1;
        end
        else begin
            branch_suc_cnt <= branch_suc_cnt;
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            jump_cnt <= 32'b0;
        end 
        else if(current_state[4] & (J_type | I_type_jalr)) begin
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
        else if(current_state[4] & (J_type | I_type_jalr) & jump) begin
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

