`include "mycpu.h"
module EX_stage(
    input                            clk,
    input                            rst,
    //allowin
    input                            mem_allowin,
    output                           ex_allowin,
    //from id
    input                            id_to_ex_valid,
    input  [`ID_TO_EX_BUS_WD - 1 :0] id_to_ex_bus,
    //to mem
    output                           ex_to_mem_valid,
    output [`EX_TO_MEM_BUS_WD - 1:0] ex_to_mem_bus,
    //mem
    output [31                   :0] Address,
    output                           MemWrite,
    output [31                   :0] Write_data,
    output [3                    :0] Write_strb,
    output                           MemRead,
    input                            Mem_Req_Ready,
    //rdw to id
    output [`RDW_BUS_WD - 1      :0] rdw_ex_bus
);
    reg  ex_valid;
    wire ex_ready_go;

    reg  [`ID_TO_EX_BUS_WD - 1:0] id_to_ex_bus_r;
    wire [4                   :0] ex_rs1;
    wire [4                   :0] ex_rs2;
    wire                          ex_RI_type;
    wire [2                   :0] ex_ALUop;
    wire [1                   :0] ex_Shifterop;
    wire                          ex_src1_is_pc;
    wire                          ex_src2_is_imm;
    wire                          ex_src2_is_4;
    wire                          ex_load_wen;
    wire                          ex_store_wen;
    wire [2                   :0] ex_ls_type;
    wire                          ex_lui;
    wire                          ex_mem_wen;
    wire                          ex_wb_wen;
    wire [4                   :0] ex_dest;
    wire [31                  :0] ex_imm_extension;
    wire [31                  :0] ex_rs1_value;
    wire [31                  :0] ex_rs2_value;
    wire [31                  :0] ex_pc;
    assign {ex_rs1,           //159:155
            ex_rs2,           //154:150
            ex_RI_type,       //149:149
            ex_ALUop,         //148:146
            ex_Shifterop,     //145:144
            ex_src1_is_pc,    //143:143
            ex_src2_is_imm,   //142:142
            ex_src2_is_4,     //141:141
            ex_load_wen,      //140:140
            ex_store_wen,     //139:139
            ex_ls_type,       //138:136
            ex_lui,           //135:135
            ex_mem_wen,       //134:134
            ex_wb_wen,        //133:133
            ex_dest,          //132:128
            ex_imm_extension, //127:96
            ex_rs1_value,     //95:64
            ex_rs2_value,     //63:32
            ex_pc             //31:0
           } = id_to_ex_bus_r;
    
    wire [31:0] src1;
    wire [31:0] src2;
    wire [31:0] ALU_result;
    wire [31:0] Shifter_result;
    wire [31:0] result; //ALU, Shifter, LUI
    
    assign src1 = ex_src1_is_pc ? ex_pc : 
                  ex_rs1_value;
    assign src2 = ex_src2_is_imm ? ex_imm_extension :
                  ex_src2_is_4   ? 32'd4            :
                  ex_rs2_value;
    alu alu(
       .A(src1),
       .B(src2),
       .ALUop(ex_ALUop),
       .Overflow(),
       .CarryOut(),
       .Zero(),
       .Result(ALU_result)
    );
    shifter shifter(
       .A(src1),
       .B(src2),
       .Shiftop(ex_Shifterop),
       .Result(Shifter_result)
    );
    assign result = (ex_lui) ? ex_imm_extension :
                    (ex_RI_type & ((ex_ls_type == 3'b001) | (ex_ls_type == 3'b101))) ? Shifter_result :
                    ALU_result;
    

    assign rdw_ex_bus = {~ex_load_wen, //38:38
                         ex_wb_wen & ex_valid, //37:37
                         ex_dest, //36:32
                         result //31:0
                        };
    
    assign ex_to_mem_bus = {ex_rs2_value, //107:76
                            result, //75:44
                            ex_load_wen, //43:43
                            ex_store_wen, //42:42
                            ex_ls_type, //41:39
                            ex_mem_wen, //38:38
                            ex_wb_wen, //37:37
                            ex_dest, //36:32
                            ex_pc //31:0
                           };
    
    reg mem_req_succ;
    assign ex_ready_go     = mem_req_succ | ~ex_load_wen & ~ex_store_wen;
    assign ex_allowin      = !ex_valid || ex_ready_go && mem_allowin;
    assign ex_to_mem_valid = ex_valid & ex_ready_go; 
    always @(posedge clk) begin
        if(rst) begin
            ex_valid <= 1'b0;
        end
        else if(ex_allowin) begin
            ex_valid <= id_to_ex_valid;
        end
        
        if(id_to_ex_valid & ex_allowin) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    always @(posedge clk) begin
        if(~mem_req_succ | ex_allowin) begin
            mem_req_succ <= Mem_Req_Ready & (MemRead | MemWrite);
        end
    end

    assign Address    = {ALU_result[31:2], 2'b0};
    assign MemRead    = ex_load_wen & ex_valid & ~mem_req_succ;
    assign MemWrite   = ex_store_wen & ex_valid & ~mem_req_succ;
    assign Write_strb = ({4{ex_ls_type == 3'b000}} & {ALU_result[1] & ALU_result[0], ALU_result[1] & ~ALU_result[0], ~ALU_result[1] & ALU_result[0], ~ALU_result[1] & ~ALU_result[0]}) |
                        ({4{ex_ls_type == 3'b001}} & {ALU_result[1], ALU_result[1], ~ALU_result[1], ~ALU_result[1]}) |
                        ({4{ex_ls_type == 3'b010}} & 4'b1111);
    assign Write_data = ({32{ex_ls_type == 3'b000}} & {4{ex_rs2_value[7:0]}}) |
                        ({32{ex_ls_type == 3'b001}} & {2{ex_rs2_value[15:0]}}) |
                        ({32{ex_ls_type == 3'b010}} & ex_rs2_value) ;
    
    
endmodule

