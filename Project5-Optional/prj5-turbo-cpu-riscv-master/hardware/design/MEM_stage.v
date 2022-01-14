
`include "mycpu.h"

module MEM_stage(
    input                            clk,
    input                            rst,
    //allowin
    input                            wb_allowin,
    output                           mem_allowin,
    //from ex
    input                            ex_to_mem_valid,
    input  [`EX_TO_MEM_BUS_WD - 1:0] ex_to_mem_bus,
    //to wb
    output                           mem_to_wb_valid,
    output [`MEM_TO_WB_BUS_WD - 1:0] mem_to_wb_bus,
    //mem
    input  [31                   :0] Read_data,
    input                            Read_data_Valid,
    output                           Read_data_Ready, 

    //rdw to id/ex
    output [`RDW_BUS_WD - 1:0] rdw_mem_bus
);
    reg  mem_valid;
    wire mem_ready_go;

    reg  [`EX_TO_MEM_BUS_WD - 1:0] ex_to_mem_bus_r;
    wire [31                   :0] mem_rs2_value;
    wire [31                   :0] mem_result;
    wire                           mem_load_wen;
    wire                           mem_store_wen;
    wire [2                    :0] mem_ls_type;
    wire                           mem_wen;
    wire                           mem_wb_wen;
    wire [4                    :0] mem_dest;
    wire [31                   :0] mem_pc;
    assign {mem_rs2_value, //107:76
            mem_result,    //75:44
            mem_load_wen,  //43:43
            mem_store_wen, //42:42
            mem_ls_type,   //41:39
            mem_wen,       //38:38
            mem_wb_wen,    //37:37
            mem_dest,      //36:32
            mem_pc         //31:0
           } = ex_to_mem_bus_r;
     
    wire [31:0] mem_read_data;
    wire [31:0] final_result;
    wire [31:0] lb_data;
    wire [31:0] lh_data;
    wire [31:0] lw_data;
    wire [31:0] lbu_data;
    wire [31:0] lhu_data;
    wire [31:0] load_data;
    
    assign rdw_mem_bus = {mem_ready_go, //38:38
                          mem_wb_wen & mem_valid, //37:37
                          mem_dest, //36:32
                          final_result //31:0
                         };
     
    assign mem_ready_go    = ~mem_load_wen | Read_data_Valid;
    assign mem_allowin     = !mem_valid || mem_ready_go && wb_allowin;
    assign mem_to_wb_valid = mem_valid & mem_ready_go;
    always @(posedge clk) begin
        if(rst) begin
            mem_valid <= 1'b0;
        end
        else if(mem_allowin) begin
            mem_valid <= ex_to_mem_valid;
        end
        
        if(ex_to_mem_valid & mem_allowin) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
    end

    assign Read_data_Ready = mem_load_wen & mem_valid & wb_allowin | rst;
    assign mem_read_data   = Read_data;
    assign lb_data         = ({32{~mem_result[1] & ~mem_result[0]}} & {{24{mem_read_data[7]}} , mem_read_data[7:0]})   |
                             ({32{~mem_result[1] & mem_result[0]}}  & {{24{mem_read_data[15]}}, mem_read_data[15:8]})  |
                             ({32{mem_result[1]  & ~mem_result[0]}} & {{24{mem_read_data[23]}}, mem_read_data[23:16]}) |
                             ({32{mem_result[1]  & mem_result[0]}}  & {{24{mem_read_data[31]}}, mem_read_data[31:24]}) ;
    assign lh_data         = ({32{~mem_result[1]}} & {{16{mem_read_data[15]}}, mem_read_data[15:0]})  |
                             ({32{mem_result[1]}}  & {{16{mem_read_data[31]}}, mem_read_data[31:16]}) ;
    assign lw_data         = mem_read_data;
    assign lbu_data        = {{24{1'b0}}, lb_data[7:0]};
    assign lhu_data        = {{16{1'b0}}, lh_data[15:0]};
    assign load_data       = ({32{~|mem_ls_type}} & lb_data) |
                             ({32{mem_ls_type == 3'b001}} & lh_data) |
                             ({32{mem_ls_type == 3'b010}} & lw_data) |
                             ({32{mem_ls_type == 3'b100}} & lbu_data) |
                             ({32{mem_ls_type == 3'b101}} & lhu_data);
    assign final_result    = mem_load_wen ? load_data : mem_result;
    
    assign mem_to_wb_bus = {mem_wb_wen, //69:69
                            mem_dest, //68:64
                            final_result, //63:32
                            mem_pc //31:0
                           };
    
endmodule


