`include "mycpu.h"
module IF_stage(
     input                           clk            ,
     input                           rst            ,
     //block signals
     input                           id_allowin     ,
     //branch or jump signals
     input  [`BJ_BUS_WD       - 1:0] bj_bus         ,
     input  id_valid,
     //to id
     output                          if_to_id_valid ,
     output [`IF_TO_ID_BUS_WD - 1:0] if_to_id_bus   ,
     //memory interface
     //Instruction request channel
     output [31                  :0] pc             ,
     output                          Inst_Req_Valid ,
     input                           Inst_Req_Ready ,
     //Instruction response channel
     input  [31                  :0] Instruction    ,
     input                           Inst_Valid     ,
     output                          Inst_Ready     
);
     
     reg         if_valid;
     wire        if_ready_go;
     wire        if_allowin;
     wire        to_if_valid;
     
     wire [31:0] seq_pc;
     reg  [31:0] if_pc;
     wire [31:0] next_pc;
     
     wire        bj_wen;
     wire        bj_valid;
     wire [31:0] bj_pc;
     
     wire [31:0] if_ins;
     
     //pre_IF stage
     assign {bj_valid, bj_wen, bj_pc} = bj_bus;
     assign to_if_valid               = ~rst;
     assign seq_pc                    = if_pc + 3'd4;
     assign next_pc                   = bj_wen ? bj_pc : seq_pc;

     //IF stage
     assign if_ready_go    = Inst_Valid;
     assign if_allowin     = !if_valid || if_ready_go && id_allowin;
     assign if_to_id_valid = if_valid & if_ready_go;
     always @(posedge clk) begin
         if(rst) begin
             if_valid <= 1'b0;
         end
         else if(if_allowin) begin
             if_valid <= to_if_valid & Inst_Req_Ready;
         end
         
         if(rst) begin
             if_pc <= 32'hfffffffc;
         end
         else if(Inst_Req_Valid & Inst_Req_Ready) begin
             if_pc <= next_pc;
         end
     end
     
     assign pc             = next_pc;
     assign Inst_Req_Valid = to_if_valid & (bj_valid | (~|seq_pc));
     assign Inst_Ready     = id_allowin | rst ;
     
     
     assign if_ins       = Instruction;
     assign if_to_id_bus = {if_ins, if_pc};

endmodule

