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
     reg  [31:0] next_pc_r;
     
     wire        bj_wen;
     wire [31:0] bj_pc;
     
     wire [31:0] if_ins;
     
     reg         ins_req_succ;
     
     //pre_IF stage
     assign {bj_wen, bj_pc}           = bj_bus;
     assign to_if_valid               = ~rst;
     assign seq_pc                    = if_pc + 4;
     assign next_pc                   = bj_wen ? bj_pc : seq_pc;
     
     reg bj_wen_r;
     reg bj_wen_t;
     always @(posedge clk) begin
         if(rst) begin
             bj_wen_r <= 1'b0;
         end
         else if(id_valid | if_allowin) begin
             bj_wen_r <= bj_wen;
         end

         bj_wen_t <= bj_wen_r;
     end
     
     always @(posedge clk) begin
         if(rst) begin
             next_pc_r <= seq_pc;
         end
         else if (id_valid | ~bj_wen_r & bj_wen_t | (~|if_pc)) begin
             next_pc_r <= next_pc;
         end
     end
     //IF stage
     assign if_ready_go    = ins_req_succ & Inst_Valid;
     assign if_allowin     = !if_valid || if_ready_go && id_allowin;
     assign if_to_id_valid = if_valid & if_ready_go & ~bj_wen_r;
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
             if_pc <= next_pc_r;
         end
     end
     
     always @(posedge clk) begin
         if(if_allowin) begin
             ins_req_succ <= Inst_Req_Valid & Inst_Req_Ready;
         end

     end
     assign pc             = next_pc_r;
     assign Inst_Req_Valid = to_if_valid & if_allowin;
     assign Inst_Ready     = ins_req_succ & id_allowin | rst ;
     
     
     assign if_ins       = Instruction;
     assign if_to_id_bus = {if_ins, if_pc};

endmodule

