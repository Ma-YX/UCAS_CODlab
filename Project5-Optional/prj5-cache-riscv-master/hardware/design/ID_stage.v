`include "mycpu.h"
module ID_stage(
    input                           clk,
    input                           rst,
    //allowin
    input                           ex_allowin,
    output                          id_allowin,
    //from if
    input                           if_to_id_valid,
    input  [`IF_TO_ID_BUS_WD - 1:0] if_to_id_bus,
    //to ex
    output                          id_to_ex_valid,
    output [`ID_TO_EX_BUS_WD - 1:0] id_to_ex_bus,
    //to if
    output [`BJ_BUS_WD - 1     : 0] bj_bus,
    output                          to_if_valid,
    //to rf: from WB
    input  [`WB_TO_RF_BUS_WD - 1:0] wb_to_rf_bus,
    //RDW signals: form EX, MEM, WB
    input  [`RDW_BUS_WD - 1     :0] rdw_ex_bus,
    input  [`RDW_BUS_WD - 1     :0] rdw_mem_bus,
    input  [`RDW_BUS_WD - 1     :0] rdw_wb_bus
);

    reg  id_valid;
    wire id_ready_go;
    
    wire [31                  :0] if_pc;
    reg  [`IF_TO_ID_BUS_WD - 1:0] if_to_id_bus_r;
    wire [31                  :0] id_ins;
    wire [31                  :0] id_pc;
    assign if_pc = if_to_id_bus[31:0];
    assign {id_ins, //63:32
            id_pc   //31:0
            } = if_to_id_bus_r;
    
    wire [4 :0] RF_raddr1;
    wire [4 :0] RF_raddr2;
    wire [31:0] RF_rdata1;
    wire [31:0] RF_rdata2;
    wire        RF_wen;
    wire [4 :0] RF_waddr;
    wire [31:0] RF_wdata;
    assign {RF_wen, //37:37
            RF_waddr, //36:32
            RF_wdata //31:0
            } = wb_to_rf_bus;
    

    wire        bj_wen;
    wire        bj_valid;
    wire [31:0] bj_pc;
    wire [31:0] CLA_A;
    wire [31:0] CLA_B;
    wire        CLA_ZF;
    wire        CLA_OF;
    wire        CLA_CF;
    wire        CLA_SF;
    wire [31:0] CLA_result;
    wire        branch;
    wire        jump;
    wire [31:0] branch_result;
    wire [31:0] jump_result;

    wire        rdw_ex_addr_valid;
    wire        rdw_ex_data_valid;
    wire [4 :0] rdw_ex_addr;
    wire [31:0] rdw_ex_data;
    wire        rdw_mem_addr_valid;
    wire        rdw_mem_data_valid;
    wire [4 :0] rdw_mem_addr;
    wire [31:0] rdw_mem_data;
    wire        rdw_wb_addr_valid;
    wire        rdw_wb_data_valid;
    wire [4 :0] rdw_wb_addr;
    wire [31:0] rdw_wb_data;
    assign {rdw_ex_addr_valid, rdw_ex_data_valid, rdw_ex_addr, rdw_ex_data} = rdw_ex_bus;
    assign {rdw_mem_addr_valid, rdw_mem_data_valid, rdw_mem_addr, rdw_mem_data} = rdw_mem_bus;
    assign {rdw_wb_addr_valid, rdw_wb_data_valid, rdw_wb_addr, rdw_wb_data} = rdw_wb_bus;
    wire        rs1_from_ex;
    wire        rs1_from_mem;
    wire        rs1_from_wb;
    wire        rs1_from_rf;
    wire        rs2_from_ex;
    wire        rs2_from_mem;
    wire        rs2_from_wb;
    wire        rs2_from_rf;
    

    wire [6 :0 ] opcode;
    wire [4 :0 ] rs1;
    wire [4 :0 ] rs2;
    wire [4 :0 ] rd;
    wire [6 :0 ] funct7;
    wire [2 :0 ] funct3;
    wire [11:0 ] imm_Itype;
    wire [4 :0 ] shamt;
    wire [11:0 ] imm_Stype;
    wire [12:1 ] imm_Btype;
    wire [31:12] imm_Utype;
    wire [20:1 ] imm_Jtype;
    
    wire R_type;
    wire I_type;
    wire I_type_calc;
    wire I_type_load;
    wire I_type_jalr;
    wire J_type;
    wire S_type;
    wire B_type;
    wire U_type_AUIPC;
    wire U_type_LUI;
    
    wire [31:0] sign_extension;
    wire [31:0] zero_extension;
    wire [31:0] IStype_extension;
    wire [31:0] Btype_extension;
    wire [31:0] Utype_extension;
    wire [31:0] Jtype_extension;
    wire [31:0] imm_extension;
    
    wire        RI_type;
    wire [2 :0] ALUop;
    wire [1 :0] Shifterop;
    wire        load_wen;
    wire        store_wen;
    wire [2 :0] ls_type;
    wire        lui;
    wire        mem_wen;
    wire        wb_wen;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        src2_is_4;
    wire [4 :0] dest;
    wire [31:0] rs1_value;
    wire [31:0] rs2_value;
    
    assign opcode    = id_ins[6:0];
    assign rs1       = id_ins[19:15];
    assign rs2       = id_ins[24:20];
    assign rd        = id_ins[11:7];
    assign funct3    = id_ins[14:12];
    assign funct7    = id_ins[31:25];
    assign shamt     = rs2;
    assign imm_Itype = id_ins[31:20];
    assign imm_Stype = {id_ins[31:25], id_ins[11:7]};
    assign imm_Btype = {id_ins[31], id_ins[7], id_ins[30:25], id_ins[11:8]};
    assign imm_Utype = id_ins[31:12];
    assign imm_Jtype = {id_ins[31], id_ins[19:12], id_ins[20], id_ins[30:21]};
    
    assign R_type       = (opcode == 7'b0110011);
    assign I_type       = I_type_calc | I_type_load | I_type_jalr;
    assign I_type_calc  = (opcode == 7'b0010011);
    assign I_type_load  = (opcode == 7'b0000011);
    assign I_type_jalr  = (opcode == 7'b1100111);
    assign S_type       = (opcode == 7'b0100011);
    assign B_type       = (opcode == 7'b1100011);
    assign U_type_LUI   = (opcode == 7'b0110111);
    assign U_type_AUIPC = (opcode == 7'b0010111);
    assign J_type       = (opcode == 7'b1101111);
    
    assign sign_extension   = ({32{I_type}} & {{20{imm_Itype[11]}}, imm_Itype}) |
                              ({32{S_type}} & {{20{imm_Stype[11]}}, imm_Stype});
    assign zero_extension   = ({32{I_type}} & {{20{1'b0}}, imm_Itype}) |
                              ({32{S_type}} & {{20{1'b0}}, imm_Stype});
    assign IStype_extension = ({32{I_type_calc & (funct3 == 3'b011)}} & zero_extension) |
                              ({32{~(I_type_calc & (funct3 == 3'b011))}} & sign_extension);
    assign Btype_extension  = {{19{imm_Btype[12]}}, imm_Btype, 1'b0};
    assign Utype_extension  = {imm_Utype, 12'b0};
    assign Jtype_extension  = {{11{imm_Jtype[20]}}, imm_Jtype, 1'b0};
    assign imm_extension    = ({32{I_type | S_type}} & IStype_extension) |
                              ({32{B_type}} & Btype_extension) |
                              ({32{U_type_LUI | U_type_AUIPC}} & Utype_extension) |
                              ({32{J_type}} & Jtype_extension);

    assign RF_raddr1 = rs1;
    assign RF_raddr2 = rs2;    

    assign RI_type = R_type | I_type_calc;

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
                   ({3{I_type_load | S_type | I_type_jalr | J_type | U_type_AUIPC}} & 3'b010) |
                   ({3{B_type}} & 3'b110) ;
    assign Shifterop   = {funct3[2], funct7[5]};
    assign src1_is_pc  = J_type | I_type_jalr | U_type_AUIPC;
    assign src2_is_imm = I_type_calc | I_type_load | S_type | U_type_AUIPC;
    assign src2_is_4   = J_type | I_type_jalr;
    assign load_wen    = I_type_load;
    assign store_wen   = S_type;
    assign ls_type     = funct3;
    assign lui         = U_type_LUI;
    assign mem_wen     = I_type_load | S_type;
    assign wb_wen      = ~(S_type | B_type);
    assign dest        = rd;

    assign rs1_from_ex  = (|rs1) & rdw_ex_data_valid & (rdw_ex_addr == rs1);
    assign rs1_from_mem = (|rs1) & ~rs1_from_ex & rdw_mem_data_valid & (rdw_mem_addr == rs1);
    assign rs1_from_wb  = (|rs1) & ~rs1_from_ex & ~rs1_from_mem & rdw_wb_data_valid & (rdw_wb_addr == rs1);
    assign rs1_from_rf  = ~(rs1_from_ex |rs1_from_mem | rs1_from_wb);
    assign rs2_from_ex  = (|rs2) & rdw_ex_data_valid & (rdw_ex_addr == rs2);
    assign rs2_from_mem = (|rs2) & ~rs2_from_ex & rdw_mem_data_valid & (rdw_mem_addr == rs2);
    assign rs2_from_wb  = (|rs2) & ~rs2_from_ex & ~rs2_from_mem & rdw_wb_data_valid & (rdw_wb_addr == rs2);
    assign rs2_from_rf  = ~(rs2_from_ex |rs2_from_mem | rs2_from_wb);
    assign rs1_value  = ({32{rs1_from_ex}} & rdw_ex_data) |
                        ({32{rs1_from_mem}} & rdw_mem_data) |
                        ({32{rs1_from_wb}} & rdw_wb_data) |
                        ({32{rs1_from_rf}} & RF_rdata1);
    assign rs2_value  = ({32{rs2_from_ex}} & rdw_ex_data) |
                        ({32{rs2_from_mem}} & rdw_mem_data) |
                        ({32{rs2_from_wb}} & rdw_wb_data) |
                        ({32{rs2_from_rf}} & RF_rdata2);
    
    assign id_to_ex_bus = {rs1,           //159:155
                           rs2,           //154:150
                           RI_type,       //149:149
                           ALUop,         //148:146
                           Shifterop,     //145:144
                           src1_is_pc,    //143:143
                           src2_is_imm,   //142:142
                           src2_is_4,     //141:141
                           load_wen,      //140:140
                           store_wen,     //139:139
                           ls_type,       //138:136
                           lui,           //135:135
                           mem_wen,       //134:134
                           wb_wen,        //133:133
                           dest,          //132:128
                           imm_extension, //127:96
                           rs1_value,     //95:64
                           rs2_value,     //63:32
                           id_pc          //31:0
                           };
    
    assign CLA_A = rs1_value;
    assign CLA_B = ({32{B_type}} & ~rs2_value) |
                   ({32{I_type_jalr}} & imm_extension);
    CLA CLA(
        .A(CLA_A),
        .B(CLA_B),
        .CIN(B_type),
        .SF(CLA_SF),
        .ZF(CLA_ZF),
        .OF(CLA_OF),
        .CF(CLA_CF),
        .S(CLA_result)
    );
    assign branch        = B_type & (((~|funct3) & CLA_ZF) |
                                     ((funct3 == 3'b001) & ~CLA_ZF) |
                                     ((funct3 == 3'b100) & (CLA_OF ^ CLA_SF)) |
                                     ((funct3 == 3'b101) & ~(CLA_OF ^ CLA_SF)) |
                                     ((funct3 == 3'b110) & CLA_CF) |
                                     ((&funct3) & ~CLA_CF)
                                    );
    assign branch_result = id_pc + Btype_extension;
    assign jump          = J_type | I_type_jalr;
    assign jump_result   = ({32{J_type}} & (id_pc + Jtype_extension)) |
                           ({32{I_type_jalr}} & {CLA_result[31:1], 1'b0});
    assign bj_wen        = (branch | jump) & id_valid;
    assign bj_valid      = id_valid & id_allowin;
    assign bj_pc         = ({32{branch}} & branch_result) |
                           ({32{jump}} & jump_result);
    assign bj_bus        = {bj_valid, bj_wen, bj_pc};
    assign to_if_valid   = id_valid;
    

    assign id_ready_go   = ~((B_type & (~rs1_from_rf | ~rs2_from_rf)) |
                             (~rdw_ex_addr_valid & (rs1_from_ex | rs2_from_ex)) |
                             (~rdw_mem_addr_valid & (rs1_from_mem | rs2_from_mem)) |
                             (~rdw_wb_addr_valid & (rs1_from_wb | rs2_from_wb))
                            );
    assign id_allowin     = !id_valid || id_ready_go && ex_allowin;
    assign id_to_ex_valid = id_valid & id_ready_go;
    always @(posedge  clk) begin
        if(rst) begin
            id_valid <= 1'b0;
        end
        else if(id_allowin) begin
            id_valid <= if_to_id_valid;
        end
        
        if(if_to_id_valid & id_allowin) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end


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

    
endmodule


module CLA(
    input [31:0] A,
    input [31:0] B,
    input CIN,
    output SF,
    output ZF,
    output CF,
    output OF,
    output [31:0] S
);
    wire [32:0] cout;
    wire Cin;
    wire COUT;
    
    assign cout[0] = CIN;
    
    genvar i;
    generate 
        for(i = 0; i < 32; i = i + 1) 
            begin : CLA
                wire p, g;
                assign p = ~A[i] & B[i] | A[i] & ~B[i];
                assign g = A[i] & B[i];
                assign S[i] = ~p & cout[i] | p & ~cout[i];
                assign cout[i + 1] = g | p & cout[i];
            end
    endgenerate 
    
    assign COUT = cout[32];
    assign Cin = cout[31];
    
    assign SF = S[31];
    assign ZF = ~|S;
    assign CF = ~COUT;
    assign OF =  Cin ^ COUT;
endmodule




