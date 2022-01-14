`timescale 10ns / 1ns

`include "mycpu.h"

module custom_cpu(
	input  rst,
	input  clk,

`ifdef BHV_SIM
	input  inst_retired_fifo_full,
`endif

	//Instruction request channel
	output [31:0] PC,
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
*/`ifdef BHV_SIM
	wire inst_retire_valid;
	wire [69:0] inst_retired;
`endif
    
    wire fifo_full;
    wire id_allowin;
    wire ex_allowin;
    wire mem_allowin;
    wire ws_allowin;
    wire if_to_id_valid;
    wire id_to_ex_valid;
    wire ex_to_mem_valid;
    wire mem_to_wb_valid;
    wire id_valid;
    wire [`IF_TO_ID_BUS_WD - 1:0] if_to_id_bus;
    wire [`ID_TO_EX_BUS_WD - 1:0] id_to_ex_bus;
    wire [`EX_TO_MEM_BUS_WD - 1:0] ex_to_mem_bus;
    wire [`MEM_TO_WB_BUS_WD - 1:0] mem_to_wb_bus;
    wire [`WB_TO_RF_BUS_WD - 1:0] wb_to_rf_bus;
    wire [`BJ_BUS_WD       - 1:0] bj_bus;
    wire [`RDW_BUS_WD - 1:0] rdw_ex_bus;
    wire [`RDW_BUS_WD - 1:0] rdw_mem_bus;
    wire [`RDW_BUS_WD - 1:0] rdw_wb_bus;
    wire retired;
    wire [69:0] fifo_data;
    
`ifdef BHV_SIM
	assign inst_retire_valid = retired & ~inst_retired_fifo_full;
	assign inst_retired = fifo_data;
	assign fifo_full = inst_retired_fifo_full;
`else
    assign fifo_full = 1'b0;
`endif
    
    IF_stage IF_stage(
    .clk(                      clk),
    .rst(                      rst),
    //block signals
    .id_allowin(        id_allowin),
    //branch or jump signals
    .bj_bus(                bj_bus),
    .id_valid(            id_valid),
    //to id
    .if_to_id_valid(if_to_id_valid),
    .if_to_id_bus(    if_to_id_bus),
    //memory interface
    //Instruction request channel
    .pc(                        PC),
    .Inst_Req_Valid(Inst_Req_Valid),
    .Inst_Req_Ready(Inst_Req_Ready),
    //Instruction response channel
    .Instruction(      Instruction),
    .Inst_Valid(        Inst_Valid),
    .Inst_Ready(        Inst_Ready)      
);
     
    ID_stage ID_stage(
    .clk(                      clk),
    .rst(                      rst),
    //allowin
    .ex_allowin(        ex_allowin),
    .id_allowin(        id_allowin),
    //from if
    .if_to_id_valid(if_to_id_valid),
    .if_to_id_bus(    if_to_id_bus),
    //to ex
    .id_to_ex_valid(id_to_ex_valid),
    .id_to_ex_bus(    id_to_ex_bus),
    //to if
    .bj_bus(                bj_bus),
    .to_if_valid(         id_valid),
    //to rf: from WB
    .wb_to_rf_bus(    wb_to_rf_bus),
    //RAW signals: form EX, MEM, WB
    .rdw_ex_bus(        rdw_ex_bus),
    .rdw_mem_bus(      rdw_mem_bus),
    .rdw_wb_bus(        rdw_wb_bus)
);
    
    EX_stage EX_stage(
    .clk(                        clk),
    .rst(                        rst),
    //allowin
    .mem_allowin(        mem_allowin),
    .ex_allowin(          ex_allowin),
    //from id
    .id_to_ex_valid(  id_to_ex_valid),
    .id_to_ex_bus(      id_to_ex_bus),
    //to mem
    .ex_to_mem_valid(ex_to_mem_valid),
    .ex_to_mem_bus(    ex_to_mem_bus),
    //mem
    .Address(                Address),
    .MemWrite(              MemWrite),
    .Write_data(          Write_data),
    .Write_strb(          Write_strb),
    .MemRead(                MemRead),
    .Mem_Req_Ready(    Mem_Req_Ready),
    //rdw to id
    .rdw_ex_bus(          rdw_ex_bus)
);
    
    MEM_stage MEM_stage(
    .clk(                        clk),
    .rst(                        rst),
    //allowin
    .wb_allowin(          wb_allowin),
    .mem_allowin(        mem_allowin),
    //from ex
    .ex_to_mem_valid(ex_to_mem_valid),
    .ex_to_mem_bus(    ex_to_mem_bus),
    //to wb
    .mem_to_wb_valid(mem_to_wb_valid),
    .mem_to_wb_bus(    mem_to_wb_bus),
    //mem
    .Read_data(            Read_data),
    .Read_data_Valid(Read_data_Valid),
    .Read_data_Ready(Read_data_Ready), 
    //rdw to id/ex
    .rdw_mem_bus(        rdw_mem_bus)
);
    
    WB_stage WB_stage(
    .clk(                        clk),
    .rst(                        rst),
    .fifo_full(            fifo_full),
    //allowin
    .wb_allowin(          wb_allowin),
    //from mem
    .mem_to_wb_valid(mem_to_wb_valid),
    .mem_to_wb_bus(    mem_to_wb_bus),
    //to rf
    .wb_to_rf_bus(      wb_to_rf_bus),
    //rdw to id
    .rdw_wb_bus(          rdw_wb_bus),
    //to fifo
    .retired(                retired),
    .fifo_data(            fifo_data)
);

    //performance counter
    reg [31:0] cycle_cnt;
    reg [31:0] ins_cnt;
    reg [31:0] mem_cnt;

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
        else if(Inst_Valid & Inst_Ready) begin
            ins_cnt <= ins_cnt + 32'b1;
        end
    end
    
    always @(posedge clk) begin
        if(rst) begin
            mem_cnt <= 32'b0;
        end 
        else if(Inst_Req_Ready & Inst_Req_Valid | (MemRead | MemWrite) & Mem_Req_Ready) begin
            mem_cnt <= mem_cnt + 32'b1;
        end
    end

    assign cpu_perf_cnt_0 = cycle_cnt;
    assign cpu_perf_cnt_1 = mem_cnt;
    assign cpu_perf_cnt_2 = ins_cnt;
endmodule





