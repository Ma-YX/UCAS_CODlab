`timescale 10ns / 1ns

module dcache_top (
	input		clk,
	input		rst,
	
	//CPU interface
	input         from_cpu_mem_req_valid,
	input         from_cpu_mem_req,
	input [31:0]  from_cpu_mem_req_addr,
	input [31:0]  from_cpu_mem_req_wdata,
	input [ 3:0]  from_cpu_mem_req_wstrb,
	output        to_cpu_mem_req_ready,
	
	output        to_cpu_cache_rsp_valid,
	output [31:0] to_cpu_cache_rsp_data,
	input         from_cpu_cache_rsp_ready,

	//Memory/IO read interface
	output        to_mem_rd_req_valid,
	output [31:0] to_mem_rd_req_addr,
	output [ 7:0] to_mem_rd_req_len,
	input         from_mem_rd_req_ready,

	input         from_mem_rd_rsp_valid,
	input  [31:0] from_mem_rd_rsp_data,
	input         from_mem_rd_rsp_last,
	output        to_mem_rd_rsp_ready,

	//Memory/IO write interface
	output        to_mem_wr_req_valid,
	output [31:0] to_mem_wr_req_addr,
	output [ 7:0] to_mem_wr_req_len,
	input         from_mem_wr_req_ready,

	output        to_mem_wr_data_valid,
	output [31:0] to_mem_wr_data,
	output [ 3:0] to_mem_wr_data_strb,
	output        to_mem_wr_data_last,
	input         from_mem_wr_data_ready
);

  //TODO: Please add your D-Cache code here
    localparam WAIT       = 14'b00000000000001,
               ADDR_RD    = 14'b00000000000010,
               CACHE_RD   = 14'b00000000000100,
               RESP       = 14'b00000000001000,
               CACHE_WR   = 14'b00000000010000,
               EVICT      = 14'b00000000100000,
               MEM_WR     = 14'b00000001000000,
               DELV       = 14'b00000010000000,
               MEM_RD     = 14'b00000100000000,
               RECV       = 14'b00001000000000,
               REFILL     = 14'b00010000000000,
               BY_MEM_REQ = 14'b00100000000000,
               BY_RECV    = 14'b01000000000000,
               BY_DELV    = 14'b10000000000000;
    
    reg from_cpu_cache_rw;
    reg [31:0] from_cpu_cache_addr;
    reg [31:0] from_cpu_cache_wdata;
    reg [3:0] from_cpu_cache_wstrb;
    wire [31:0] from_cpu_cache_wdata_final;
    
    reg         valid0 [7:0];
    reg         dirty0 [7:0];
    reg [23:0]  tag0   [7:0];
    reg [255:0] data0  [7:0];
    reg         valid1 [7:0];
    reg         dirty1 [7:0];
    reg [23:0]  tag1   [7:0];
    reg [255:0] data1  [7:0];
    reg         valid2 [7:0];
    reg         dirty2 [7:0];
    reg [23:0]  tag2   [7:0];
    reg [255:0] data2  [7:0];
    reg         valid3 [7:0];
    reg         dirty3 [7:0];
    reg [23:0]  tag3   [7:0];
    reg [255:0] data3  [7:0];
    
    reg [13:0] current_state;
    reg [13:0] next_state;
    
    wire by_pass;
    wire read_hit_miss;
    wire write_hit_miss;
    wire dirty;
    
    wire [23:0] tag;
    wire [2:0] set;
    wire [4:0] offset;
    assign {tag, set, offset} = from_cpu_cache_addr;
    
    reg [31:0] from_mem_rd_rsp_data0;
    reg [31:0] from_mem_rd_rsp_data1;
    reg [31:0] from_mem_rd_rsp_data2;
    reg [31:0] from_mem_rd_rsp_data3;
    reg [31:0] from_mem_rd_rsp_data4;
    reg [31:0] from_mem_rd_rsp_data5;
    reg [31:0] from_mem_rd_rsp_data6;
    reg [31:0] from_mem_rd_rsp_data7;
    reg [2:0]  from_mem_rd_rsp_len;
    
    assign read_hit_miss = ~from_cpu_cache_rw & (tag0[set] == tag) & valid0[set];
    assign write_hit_miss = from_cpu_cache_rw & (tag0[set] == tag) & valid0[set];
    
    always @(posedge clk) begin
        if(rst) begin
            current_state <= WAIT;
        end
        else begin
            current_state <= next_state;
        end
    end
    
    always @(*) begin
        case(current_state)
            WAIT: begin
                if(from_cpu_mem_req_valid) begin
                    next_state = ADDR_RD;
                end
                else begin
                    next_state = WAIT;
                end
            end
            
            ADDR_RD: begin
                if(read_hit_miss & ~by_pass) begin
                    next_state = CACHE_RD;
                end
                else if(write_hit_miss & ~by_pass) begin
                    next_state = CACHE_WR;
                end
                else if(~(read_hit_miss | write_hit_miss) & ~by_pass) begin
                    next_state = EVICT;
                end
                else begin
                   next_state = BY_MEM_REQ;
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
            
            CACHE_WR: begin
                next_state = WAIT;
            end
            
            EVICT: begin
                if(dirty) begin
                    next_state = MEM_WR;
                end
                else begin
                    next_state = MEM_RD;
                end
            end
            
            MEM_WR: begin
                if(from_mem_wr_req_ready) begin
                    next_state = DELV;
                end
                else begin
                    next_state = MEM_WR;
                end
            end
            
            DELV: begin
                if(from_mem_wr_data_ready & to_mem_wr_data_last) begin
                    next_state = MEM_RD;
                end
                else begin
                    next_state = DELV;
                end
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
                if(from_cpu_cache_rw) begin
                    next_state = CACHE_WR;
                end
                else begin
                    next_state = RESP;
                end
            end
            
            RESP: begin
                if(from_cpu_cache_rsp_ready) begin
                    next_state = WAIT;
                end
                else begin
                    next_state = RESP;
                end
            end
            
            BY_MEM_REQ: begin
                if(from_cpu_cache_rw & from_mem_wr_req_ready) begin
                    next_state = BY_DELV;
                end
                else if(~from_cpu_cache_rw & from_mem_rd_req_ready) begin
                    next_state = BY_RECV;
                end
		else begin
                    next_state = BY_MEM_REQ;
                end
            end
            
            BY_RECV: begin
                if(from_mem_rd_rsp_valid & from_mem_rd_rsp_last) begin
                    next_state = RESP;
                end
                else begin
                    next_state = BY_RECV;
                end
            end
            
            BY_DELV: begin
                if(from_mem_wr_data_ready & to_mem_wr_data_last) begin
                    next_state = WAIT;
                end
                else begin
                    next_state = BY_DELV;
                end
            end

           default: next_state = current_state;
        endcase
    end
    
    always @(posedge clk) begin
        if(rst) begin
            from_cpu_cache_rw <= 1'b0;
            from_cpu_cache_addr <= 32'b0;
            from_cpu_cache_wdata <= 32'b0;
            from_cpu_cache_wstrb <= 4'b0;
        end
        else if(from_cpu_mem_req_valid & to_cpu_mem_req_ready) begin
            from_cpu_cache_rw <= from_cpu_mem_req;
            from_cpu_cache_addr <= from_cpu_mem_req_addr;
            from_cpu_cache_wdata<= from_cpu_mem_req_wdata;
            from_cpu_cache_wstrb <= from_cpu_mem_req_wstrb;
        end
    end
    
    assign to_cpu_mem_req_ready = current_state == WAIT; 

    //EVICT
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
             from_mem_rd_rsp_data0 <= 32'b0;
             from_mem_rd_rsp_data1 <= 32'b0;
             from_mem_rd_rsp_data2 <= 32'b0;
             from_mem_rd_rsp_data3 <= 32'b0;
             from_mem_rd_rsp_data4 <= 32'b0;
             from_mem_rd_rsp_data5 <= 32'b0;
             from_mem_rd_rsp_data6 <= 32'b0;
             from_mem_rd_rsp_data7 <= 32'b0;
         end
         else if((current_state == RECV) & from_mem_rd_rsp_valid & to_mem_rd_rsp_ready) begin
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
         else if((current_state == BY_RECV) & from_mem_rd_rsp_valid & to_mem_rd_rsp_ready) begin
             from_mem_rd_rsp_data0 <= from_mem_rd_rsp_data;
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
                 valid0[set] <= 1'b0;
             end
             else if(current_state == REFILL) begin
                 valid0[set] <= 1'b1;
             end
             
             if(current_state == REFILL) begin
                 tag0[set] <= tag;
             end
             
             if(current_state == REFILL) begin
                 data0[set] <= {from_mem_rd_rsp_data7, from_mem_rd_rsp_data6, from_mem_rd_rsp_data5, from_mem_rd_rsp_data4,
                                from_mem_rd_rsp_data3, from_mem_rd_rsp_data2, from_mem_rd_rsp_data1, from_mem_rd_rsp_data0};
             end
             
             //CACHE_WR: write cache
             if(current_state == CACHE_WR) begin
                 data0[set][{offset, 3'b000}+:32] <= from_cpu_cache_wdata_final;
             end
             
             if(current_state == CACHE_WR) begin
                 dirty0[set] <= 1'b1;
             end
             else if(current_state == DELV) begin
                 dirty0[set] <= 1'b0;
             end
         end
     end
     
     assign from_cpu_cache_wdata_final = {{8{from_cpu_cache_wstrb[3]}} & from_cpu_cache_wdata[31:24] | {8{~from_cpu_cache_wstrb[3]}} & data0[set][{offset, 3'b000}+5'd24 +:8],
                                          {8{from_cpu_cache_wstrb[2]}} & from_cpu_cache_wdata[23:16] | {8{~from_cpu_cache_wstrb[2]}} & data0[set][{offset, 3'b000}+5'd16 +:8],
                                          {8{from_cpu_cache_wstrb[1]}} & from_cpu_cache_wdata[15:8]  | {8{~from_cpu_cache_wstrb[1]}} & data0[set][{offset, 3'b000}+5'd8  +:8],
                                          {8{from_cpu_cache_wstrb[0]}} & from_cpu_cache_wdata[ 7:0]  | {8{~from_cpu_cache_wstrb[0]}} & data0[set][{offset, 3'b000}       +:8]
                                          };
     
     //read cache
     //signals concerning cpu and mem
     assign to_mem_req_ready = current_state == WAIT;
     assign to_cpu_cache_rsp_valid = current_state == RESP;
     wire [255:0] data;
     assign data = data0[set];
     assign to_cpu_cache_rsp_data = by_pass ? from_mem_rd_rsp_data0 : data[{offset, 3'b000}+:32];
     
     //write mem
     //case1: EVICT(dirty block)  case2: bypass
     assign dirty = dirty0[set];
     assign by_pass = (~|from_cpu_cache_addr[31:5]) | (|from_cpu_cache_addr[31:29]);
     assign to_mem_wr_req_valid = (current_state == MEM_WR) | (current_state == BY_MEM_REQ) & from_cpu_cache_rw;
     assign to_mem_wr_req_addr = {32{~by_pass}} & {tag0[set], set, 5'd0} |
                                 {32{by_pass}} & from_cpu_cache_addr;
     assign to_mem_wr_req_len = {8{~by_pass}} & 8'd7 |
                                {8{by_pass}} & 8'd0;
     assign to_mem_wr_data_valid = (current_state == DELV) | (current_state == BY_DELV);
     assign to_mem_wr_data_strb = {4{~by_pass}} & 4'b1111 |
                                  {4{by_pass}} & from_cpu_cache_wstrb;
     reg [2:0] to_mem_wr_len;
     always @(posedge clk) begin
         if(rst) begin
             to_mem_wr_len <= 3'd0;
         end
         else if(from_mem_wr_req_ready & to_mem_wr_req_valid) begin
             to_mem_wr_len <= 3'd0;
         end
         else if(from_mem_wr_data_ready & to_mem_wr_data_valid) begin
             to_mem_wr_len <= to_mem_wr_len + 1'd1;
         end
     end
     assign to_mem_wr_data = {32{by_pass}} & from_cpu_cache_wdata |
                             {32{~by_pass}} & data0[set][{to_mem_wr_len, 5'd0} +:32];
     assign to_mem_wr_data_last = from_mem_wr_data_ready & to_mem_wr_data_valid & (&to_mem_wr_len);
    
     //read mem
     //case1: EVICT case2: bypass
     assign to_mem_rd_req_valid = (current_state == MEM_RD) | (current_state == BY_MEM_REQ) & ~from_cpu_cache_rw;
     assign to_mem_rd_req_addr = {32{~by_pass}} & {from_cpu_cache_addr[31:5], 5'd0} |
                                 {32{by_pass}} & from_cpu_cache_addr;
     assign to_mem_rd_req_len = {8{~by_pass}} & 8'd7 |
                                {8{by_pass}} & 8'd0;
     assign to_mem_rd_rsp_ready = (current_state == BY_RECV) | (current_state == RECV) | rst;
     

endmodule



