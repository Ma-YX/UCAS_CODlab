`include "mycpu.h"

module WB_stage(
    input                            clk,
    input                            rst,
    input                            fifo_full,
    //allowin
    output                           wb_allowin,
    //from mem
    input                            mem_to_wb_valid,
    input  [`MEM_TO_WB_BUS_WD - 1:0] mem_to_wb_bus,
    //to rf
    output [`WB_TO_RF_BUS_WD - 1 :0] wb_to_rf_bus,
    //rdw to id
    output [`RDW_BUS_WD - 1      :0] rdw_wb_bus,
    //to fifo
    output                           retired,
    output [69                   :0] fifo_data
);
    reg  wb_valid;
    wire wb_ready_go;
    
    reg  [`MEM_TO_WB_BUS_WD - 1:0] mem_to_wb_bus_r;
    wire                           wb_wen;
    wire [4                    :0] wb_dest;
    wire [31                   :0] wb_final_result;
    wire [31                   :0] wb_pc;
    assign {wb_wen,
            wb_dest,
            wb_final_result,
            wb_pc
           } = mem_to_wb_bus_r;
    
    wire        RF_wen;
    wire [4 :0] RF_waddr;
    wire [31:0] RF_wdata;
    assign wb_to_rf_bus = {RF_wen, //37:37
                           RF_waddr, //36:32
                           RF_wdata //31:0
                          };
    
    assign rdw_wb_bus = {1'b1,//38:38
                         RF_wen, //37:37
                         wb_dest, //36:2
                         wb_final_result //31:0
                        };
    
    assign wb_ready_go = ~fifo_full;
    assign wb_allowin  = !wb_valid || wb_ready_go;
    always @(posedge clk)begin
        if(rst) begin
            wb_valid <= 1'b0;
        end
        else if(wb_allowin)begin
            wb_valid <= mem_to_wb_valid;
        end
        
        if(mem_to_wb_valid & wb_allowin) begin
            mem_to_wb_bus_r <= mem_to_wb_bus;
        end
    end
    
    assign RF_wen   = wb_valid & wb_wen;
    assign RF_waddr = wb_dest;
    assign RF_wdata = wb_final_result;
    

    assign retired   = wb_valid;
    assign fifo_data = {wb_pc, wb_wen, wb_dest, wb_final_result};
    
endmodule

