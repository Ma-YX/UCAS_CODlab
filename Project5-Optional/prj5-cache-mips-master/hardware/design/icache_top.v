`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define TAG_LEN		24
`define LINE_LEN	256

module icache_top (
	input		clk,
	input		rst,
	
	//CPU interface
	/** CPU instruction fetch request to Cache: valid signal */
	input          from_cpu_inst_req_valid,
	/** CPU instruction fetch request to Cache: address (4 byte alignment) */
	input  [31:0]  from_cpu_inst_req_addr,
	/** Acknowledgement from Cache: ready to receive CPU instruction fetch request */
	output         to_cpu_inst_req_ready,
	
	/** Cache responses to CPU: valid signal */
	output         to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit Instruction value */
	output [31:0]  to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive Instruction */
	input          from_cpu_cache_rsp_ready,

	//Memory interface (32 byte aligned address)
	/** Cache sending memory read request: valid signal */
	output         to_mem_rd_req_valid,
	/** Cache sending memory read request: address (32 byte alignment) */
	output [31:0]  to_mem_rd_req_addr,
	/** Acknowledgement from memory: ready to receive memory read request */
	input          from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input          from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0]  from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input          from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output         to_mem_rd_rsp_ready
);


    localparam WAIT     = 8'b00000001,
               TAG_RD   = 8'b00000010,
               CACHE_RD = 8'b00000100,
               RESP     = 8'b00001000,
               EVICT    = 8'b00010000,
               MEM_RD   = 8'b00100000,
               RECV     = 8'b01000000,
               REFILL   = 8'b10000000;
     
     reg         valid0 [7:0];
     reg [23:0]  tag0   [7:0];
     reg [255:0] data0  [7:0];
     reg         valid1 [7:0];
     reg [23:0]  tag1   [7:0];
     reg [255:0] data1  [7:0];
     reg         valid2 [7:0];
     reg [23:0]  tag2   [7:0];
     reg [255:0] data2  [7:0];
     reg         valid3 [7:0];
     reg [23:0]  tag3   [7:0];
     reg [255:0] data3  [7:0];
     
     reg [1:0] FIFO [7:0];
     
     reg [7:0] current_state;
     reg [7:0] next_state;
     
     wire hit_miss;
     wire hit_miss0;
     wire hit_miss1;
     wire hit_miss2;
     wire hit_miss3;
     
     reg [31:0] from_cpu_cache_req_addr;
     reg [31:0] from_mem_rd_rsp_data0;
     reg [31:0] from_mem_rd_rsp_data1;
     reg [31:0] from_mem_rd_rsp_data2;
     reg [31:0] from_mem_rd_rsp_data3;
     reg [31:0] from_mem_rd_rsp_data4;
     reg [31:0] from_mem_rd_rsp_data5;
     reg [31:0] from_mem_rd_rsp_data6;
     reg [31:0] from_mem_rd_rsp_data7;
     reg [2:0]  from_mem_rd_rsp_len;
     
     wire [23:0] tag;
     wire [2:0] set;
     wire [4:0] offset;
     assign {tag, set, offset} = from_cpu_cache_req_addr;
     //current_state
     always @(posedge clk) begin
         if(rst) begin
             current_state <= WAIT;
         end
         else begin
             current_state <= next_state;
         end
     end
     
     //next_state
     always @(*) begin
         case(current_state)
             WAIT: begin
                 if(from_cpu_inst_req_valid) begin
                      next_state = TAG_RD;
                 end
                 else begin
                      next_state = WAIT;
                 end
             end
             
             TAG_RD: begin
                 if(hit_miss) begin
                     next_state = CACHE_RD;
                 end
                 else begin
                     next_state = EVICT;
                 end
             end
             
             CACHE_RD: begin
                 next_state = RESP;
             end
             
             RESP: begin
                 if(from_cpu_cache_rsp_ready) begin
                     next_state = WAIT;
                 end
                 else begin
                     next_state = RESP;
                 end
             end
             
             EVICT: begin
                 next_state = MEM_RD;
             end
             
             MEM_RD: begin
                 if(from_mem_rd_req_ready) begin
                     next_state = RECV;
                 end
                 else begin
                     next_state = MEM_RD;
                 end
             end
             
             RECV: begin
                 if(from_mem_rd_rsp_valid & from_mem_rd_rsp_last) begin
                     next_state = REFILL;
                 end
                 else begin
                     next_state = RECV;
                 end
             end
             
             REFILL: begin
                 next_state = RESP;
             end

             default: next_state = current_state;
         endcase 
     end
     
     //req addr from cpu
     always @(posedge clk) begin
         if(rst) begin
             from_cpu_cache_req_addr <= 32'b0;
         end
         else if(from_cpu_inst_req_valid & from_cpu_inst_req_valid) begin
             from_cpu_cache_req_addr <= from_cpu_inst_req_addr;
         end
     end
     
     //read data from mem
     always @(posedge clk) begin
         if(rst) begin
             from_mem_rd_rsp_len <= 3'b0;
         end
         else if(from_mem_rd_req_ready & to_mem_rd_req_valid) begin
             from_mem_rd_rsp_len <= 3'b0;
         end
         else if(from_mem_rd_rsp_valid & to_mem_rd_rsp_ready) begin
             from_mem_rd_rsp_len <= from_mem_rd_rsp_len + 1'b1;
         end
     end
     
     always @(posedge clk) begin
         if(rst) begin
             FIFO[0] <= 2'b0; FIFO[1] <= 2'b0; FIFO[2] <= 2'b0; FIFO[3] <= 2'b0;
             FIFO[4] <= 2'b0; FIFO[5] <= 2'b0; FIFO[6] <= 2'b0; FIFO[7] <= 2'b0;
         end
         else if(current_state == TAG_RD) begin
             FIFO[set] <= FIFO[set] + {1'b0, ~hit_miss};
         end
     end
     
     always @(posedge clk) begin
         if(rst) begin
             from_mem_rd_rsp_data0 <= 32'b0;
             from_mem_rd_rsp_data1 <= 32'b0;
             from_mem_rd_rsp_data2 <= 32'b0;
             from_mem_rd_rsp_data3 <= 32'b0;
             from_mem_rd_rsp_data4 <= 32'b0;
             from_mem_rd_rsp_data5 <= 32'b0;
             from_mem_rd_rsp_data6 <= 32'b0;
             from_mem_rd_rsp_data7 <= 32'b0;
         end
         else if(from_mem_rd_rsp_valid & to_mem_rd_rsp_ready) begin
             case(from_mem_rd_rsp_len)
                 3'b000: from_mem_rd_rsp_data0 <= from_mem_rd_rsp_data;
                 3'b001: from_mem_rd_rsp_data1 <= from_mem_rd_rsp_data;
                 3'b010: from_mem_rd_rsp_data2 <= from_mem_rd_rsp_data;
                 3'b011: from_mem_rd_rsp_data3 <= from_mem_rd_rsp_data;
                 3'b100: from_mem_rd_rsp_data4 <= from_mem_rd_rsp_data;
                 3'b101: from_mem_rd_rsp_data5 <= from_mem_rd_rsp_data;
                 3'b110: from_mem_rd_rsp_data6 <= from_mem_rd_rsp_data;
                 3'b111: from_mem_rd_rsp_data7 <= from_mem_rd_rsp_data;
             endcase
         end
     end
     
     always @(posedge clk) begin
         if (rst) begin
             valid0[0] <= 0; valid1[0] <= 0; valid2[0] <= 0; valid3[0] <= 0;
             valid0[1] <= 0; valid1[1] <= 0; valid2[1] <= 0; valid3[1] <= 0;
             valid0[2] <= 0; valid1[2] <= 0; valid2[2] <= 0; valid3[2] <= 0;
             valid0[3] <= 0; valid1[3] <= 0; valid2[3] <= 0; valid3[3] <= 0;
             valid0[4] <= 0; valid1[4] <= 0; valid2[4] <= 0; valid3[4] <= 0;
             valid0[5] <= 0; valid1[5] <= 0; valid2[5] <= 0; valid3[5] <= 0;
             valid0[6] <= 0; valid1[6] <= 0; valid2[6] <= 0; valid3[6] <= 0;
             valid0[7] <= 0; valid1[7] <= 0; valid2[7] <= 0; valid3[7] <= 0;
         end
         
         else begin
             if(current_state == EVICT) begin
                 case(FIFO[set])
                     2'd0: valid0[set] <= 1'b0;
                     2'd1: valid1[set] <= 1'b0;
                     2'd2: valid2[set] <= 1'b0;
                     2'd3: valid3[set] <= 1'b0;
                 endcase
             end
             else if(current_state == REFILL) begin
                 case(FIFO[set])
                     2'd0: valid0[set] <= 1'b1;
                     2'd1: valid1[set] <= 1'b1;
                     2'd2: valid2[set] <= 1'b1;
                     2'd3: valid3[set] <= 1'b1;
                 endcase
             end
             
             if(current_state == REFILL) begin
                 case(FIFO[set])
                     2'd0: tag0[set] <= tag;
                     2'd1: tag1[set] <= tag;
                     2'd2: tag2[set] <= tag;
                     2'd3: tag3[set] <= tag;
                 endcase 
             end
             
             if(current_state == REFILL) begin
                 case(FIFO[set])
                     2'd0: data0[set] <= {from_mem_rd_rsp_data7, from_mem_rd_rsp_data6, from_mem_rd_rsp_data5, from_mem_rd_rsp_data4,
                                          from_mem_rd_rsp_data3, from_mem_rd_rsp_data2, from_mem_rd_rsp_data1, from_mem_rd_rsp_data0};
                     2'd1: data1[set] <= {from_mem_rd_rsp_data7, from_mem_rd_rsp_data6, from_mem_rd_rsp_data5, from_mem_rd_rsp_data4,
                                          from_mem_rd_rsp_data3, from_mem_rd_rsp_data2, from_mem_rd_rsp_data1, from_mem_rd_rsp_data0};
                     2'd2: data2[set] <= {from_mem_rd_rsp_data7, from_mem_rd_rsp_data6, from_mem_rd_rsp_data5, from_mem_rd_rsp_data4,
                                          from_mem_rd_rsp_data3, from_mem_rd_rsp_data2, from_mem_rd_rsp_data1, from_mem_rd_rsp_data0};
                     2'd3: data3[set] <= {from_mem_rd_rsp_data7, from_mem_rd_rsp_data6, from_mem_rd_rsp_data5, from_mem_rd_rsp_data4,
                                          from_mem_rd_rsp_data3, from_mem_rd_rsp_data2, from_mem_rd_rsp_data1, from_mem_rd_rsp_data0};
                 endcase 
             end
         end
     end
     
     assign hit_miss0 = valid0[set] & (tag0[set] == tag);
     assign hit_miss1 = valid1[set] & (tag1[set] == tag);
     assign hit_miss2 = valid2[set] & (tag2[set] == tag);
     assign hit_miss3 = valid3[set] & (tag3[set] == tag);
     assign hit_miss = hit_miss0 | hit_miss1 | hit_miss2 | hit_miss3;
     
     assign to_cpu_inst_req_ready = current_state == WAIT;
     assign to_cpu_cache_rsp_valid = current_state == RESP;
     wire [255:0] data;
     assign data = {256{hit_miss0}} & data0[set] |
                   {256{hit_miss1}} & data1[set] |
                   {256{hit_miss2}} & data2[set] |
                   {256{hit_miss3}} & data3[set] ;
     assign to_cpu_cache_rsp_data = data[{offset, 3'b000}+:32];
     
     assign to_mem_rd_req_valid = current_state == MEM_RD;
     assign to_mem_rd_req_addr = {from_cpu_cache_req_addr[31:5], 5'd0};
     assign to_mem_rd_rsp_ready = (current_state == RECV) | rst;
     

endmodule

