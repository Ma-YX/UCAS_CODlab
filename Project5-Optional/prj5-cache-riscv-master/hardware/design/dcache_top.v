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
    
    reg        from_cpu_cache_rw;
    reg [31:0] from_cpu_cache_addr;
    reg [31:0] from_cpu_cache_wdata;
    reg [ 3:0] from_cpu_cache_wstrb;
    wire [ 4:0] offset;
    wire [ 2:0] set;
    wire [23:0] tag;
    
    wire bypass;
    wire valid;
    wire dirty;
    wire hit_miss;
    wire hit_miss0;
    wire hit_miss1;
    wire hit_miss2;
    wire hit_miss3;
    reg hit_miss_r;
    reg hit_miss_r0;
    reg hit_miss_r1;
    reg hit_miss_r2;
    reg hit_miss_r3;
    
    reg [2:0] PLRU_r [7:0];
    wire hit_miss_01;
    wire L0;
    wire L1;
    wire L2;
    wire L3;
    
    wire [255:0] cache_data; //original data in cache
    wire [31:0] cache_valid_data;
    reg [31:0] from_cache_data;
    reg [255:0] from_mem_cache_data;
    //state machine
    //current state
    always @(posedge clk) begin
        if(rst) begin
            current_state <= WAIT;
        end
        else begin
            current_state <= next_state;
        end
    end
    //next state
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
                if(hit_miss & ~bypass) begin
                    next_state = CACHE_RD;
                end
                else if(hit_miss & ~bypass) begin
                    next_state = CACHE_WR;
                end
                else if(~hit_miss & ~bypass) begin
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
                    next_state = CACHE_RD;
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

    //cache control signals
    //state: ADDR_RD, EVICT
    //ADDR_RD
    assign offset    = from_cpu_cache_addr[ 4:0];
    assign set       = from_cpu_cache_addr[ 7:5];
    assign tag       = from_cpu_cache_addr[31:8];
    assign bypass    = ~|from_cpu_cache_addr[31:5] || |from_cpu_cache_addr[31:30];
    assign hit_miss0 = valid0[set] & tag0[set] == tag;
    assign hit_miss1 = valid1[set] & tag1[set] == tag;
    assign hit_miss2 = valid2[set] & tag2[set] == tag;
    assign hit_miss3 = valid3[set] & tag3[set] == tag;
    assign hit_miss  = hit_miss0 | hit_miss1 | hit_miss2 | hit_miss3;

    assign cache_data = {256{hit_miss_r0}} & data0[set] |
                        {256{hit_miss_r1}} & data1[set] |
                        {256{hit_miss_r2}} & data2[set] |
                        {256{hit_miss_r3}} & data3[set];
    //EVICT
    assign dirty = L0 & valid0[set] & dirty0[set] |
                   L1 & valid1[set] & dirty1[set] |
                   L2 & valid2[set] & dirty2[set] |
                   L3 & valid3[set] & dirty3[set]; 
    assign valid = valid0[set] & valid1[set] & valid2[set] & valid3[set];
    assign L0    = valid & ~PLRU_r[set][1] & ~PLRU_r[set][0] | ~valid0[set];
    assign L1    = valid &  PLRU_r[set][1] & ~PLRU_r[set][0] | ~valid1[set] & valid0[set];
    assign L2    = valid & ~PLRU_r[set][2] &  PLRU_r[set][0] | ~valid2[set] & valid0[set] & valid1[set];
    assign L3    = valid &  PLRU_r[set][2] &  PLRU_r[set][0] | ~valid3[set] & valid0[set] & valid1[set] & valid2[set];

    always @(posedge clk) begin
        if (current_state == ADDR_RD) begin
            hit_miss_r  <= hit_miss;
            hit_miss_r0 <= hit_miss0;
            hit_miss_r1 <= hit_miss1;
            hit_miss_r2 <= hit_miss2;
            hit_miss_r3 <= hit_miss3;            
        end
        else if (current_state == EVICT) begin
            hit_miss_r0 <= L0;
            hit_miss_r1 <= L1;
            hit_miss_r2 <= L2;
            hit_miss_r3 <= L3;
        end
    end
    //algorithm ： PLRU
    assign hit_miss_01 = hit_miss_r0 | hit_miss_r1;
    always @(posedge clk) begin
        if (rst) begin
            PLRU_r[0] <= 3'b0; PLRU_r[1] <= 3'b0; PLRU_r[2] <= 3'b0; PLRU_r[3] <= 3'b0;
            PLRU_r[4] <= 3'b0; PLRU_r[5] <= 3'b0; PLRU_r[6] <= 3'b0; PLRU_r[7] <= 3'b0;    
        end
        else if (current_state == CACHE_RD || current_state == CACHE_WR) begin
            PLRU_r[set][0] <= hit_miss_01;
            if (hit_miss_01)
                PLRU_r[set][1] <= hit_miss_r0;
            if (~hit_miss_01)
                PLRU_r[set][2] <= hit_miss_r2;
        end
    end
    
    //cache operations
    //state: CACHE_RD, CACHE_WR, REFILL
    //REFILL
    //valid array
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
        else if (current_state == REFILL) begin
            if (hit_miss_r0) valid0[set] <= 1'b1;
            if (hit_miss_r1) valid1[set] <= 1'b1;
            if (hit_miss_r2) valid2[set] <= 1'b1;
            if (hit_miss_r3) valid3[set] <= 1'b1;
        end
    end
    //tag array
    always @(posedge clk) begin
        if (current_state == REFILL) begin
            if (hit_miss_r0) tag0[set] <= tag;
            if (hit_miss_r1) tag1[set] <= tag;
            if (hit_miss_r2) tag2[set] <= tag;
            if (hit_miss_r3) tag3[set] <= tag;
        end
    end
    //CACHE_RD
    assign cache_valid_data = cache_data[{offset, 3'd0}+:32];
    always @(posedge clk) begin
        if (current_state == CACHE_RD)
            from_cache_data <= cache_valid_data;        
    end
    //CACHE_WR
    wire [255:0] from_cpu_cache_data;
    assign from_cpu_cache_data = {{8{from_cpu_cache_wstrb[3]}} & from_cpu_cache_wdata[31:24] | {8{~from_cpu_cache_wstrb[3]}} & cache_data[{offset, 3'b000}+5'd24 +:8],
                                  {8{from_cpu_cache_wstrb[2]}} & from_cpu_cache_wdata[23:16] | {8{~from_cpu_cache_wstrb[2]}} & cache_data[{offset, 3'b000}+5'd16 +:8],
                                  {8{from_cpu_cache_wstrb[1]}} & from_cpu_cache_wdata[15:8]  | {8{~from_cpu_cache_wstrb[1]}} & cache_data[{offset, 3'b000}+5'd8  +:8],
                                  {8{from_cpu_cache_wstrb[0]}} & from_cpu_cache_wdata[ 7:0]  | {8{~from_cpu_cache_wstrb[0]}} & cache_data[{offset, 3'b000}       +:8]
                                 };

    //data array
    always @(posedge clk) begin
        if (current_state == REFILL) begin
            if (hit_miss_r0) data0[set] <= from_mem_cache_data;
            if (hit_miss_r1) data1[set] <= from_mem_cache_data;
            if (hit_miss_r2) data2[set] <= from_mem_cache_data;
            if (hit_miss_r3) data3[set] <= from_mem_cache_data;
        end
        else if (current_state == CACHE_WR) begin
            if (hit_miss_r0) data0[set] <= from_cpu_cache_data;
            if (hit_miss_r1) data1[set] <= from_cpu_cache_data;
            if (hit_miss_r2) data2[set] <= from_cpu_cache_data;
            if (hit_miss_r3) data3[set] <= from_cpu_cache_data;
        end
    end
    //dirty array
    always @(posedge clk) begin
        if (rst) begin
            dirty0[0] <= 0; dirty1[0] <= 0; dirty2[0] <= 0; dirty3[0] <= 0;
            dirty0[1] <= 0; dirty1[1] <= 0; dirty2[1] <= 0; dirty3[1] <= 0;
            dirty0[2] <= 0; dirty1[2] <= 0; dirty2[2] <= 0; dirty3[2] <= 0;
            dirty0[3] <= 0; dirty1[3] <= 0; dirty2[3] <= 0; dirty3[3] <= 0;
            dirty0[4] <= 0; dirty1[4] <= 0; dirty2[4] <= 0; dirty3[4] <= 0;
            dirty0[5] <= 0; dirty1[5] <= 0; dirty2[5] <= 0; dirty3[5] <= 0;
            dirty0[6] <= 0; dirty1[6] <= 0; dirty2[6] <= 0; dirty3[6] <= 0;
            dirty0[7] <= 0; dirty1[7] <= 0; dirty2[7] <= 0; dirty3[7] <= 0;
        end
        else if (current_state == CACHE_WR) begin
            if (hit_miss_r0) dirty0[set] <= 1'b1;
            if (hit_miss_r1) dirty1[set] <= 1'b1;
            if (hit_miss_r2) dirty2[set] <= 1'b1;
            if (hit_miss_r3) dirty3[set] <= 1'b1;
        end
    end
    
    
    //interactions of data and control signals with cpu
    //req state: WAIT
    assign to_cpu_mem_req_ready = current_state == WAIT;

    always @(posedge clk) begin
        if (current_state == WAIT) begin
            from_cpu_cache_rw    <= from_cpu_mem_req;
            from_cpu_cache_addr  <= from_cpu_mem_req_addr;
            from_cpu_cache_wdata <= from_cpu_mem_req_wdata;
            from_cpu_cache_wstrb <= from_cpu_mem_req_wstrb;
        end
    end
    //rsp state: RESP
    assign to_cpu_cache_rsp_valid = current_state == RESP;
    assign to_cpu_cache_rsp_data  = {32{ bypass}} & from_mem_cache_data[255:224] |
                                    {32{~bypass}} & from_cache_data;

    
    // interactions of data and control signals with memory
    //req state: BY_MEM_REQ, MEM_RD, MEM_WR
    //MEM_RD, MEM_RD
    assign to_mem_rd_req_valid = (current_state == MEM_RD) | (current_state == BY_MEM_REQ);
    assign to_mem_rd_req_addr  = {32{ bypass}} & from_cpu_cache_addr              |
                                 {32{~bypass}} & {from_cpu_cache_addr[31:5], 5'b0};
    assign to_mem_rd_req_len   = {5'b0, {3{~bypass}}};
    //MEM_WR, BY_MEM_REQ
    assign to_mem_wr_req_valid = (current_state == MEM_WR) | (current_state == BY_MEM_REQ);
    assign to_mem_wr_req_addr  = {32{ bypass}}           & from_cpu_cache_addr        |
                                 {32{~bypass & hit_miss_r0}} & {tag0[set], set, 5'b0} |
                                 {32{~bypass & hit_miss_r1}} & {tag1[set], set, 5'b0} |
                                 {32{~bypass & hit_miss_r2}} & {tag2[set], set, 5'b0} |
                                 {32{~bypass & hit_miss_r3}} & {tag3[set], set, 5'b0};
    assign to_mem_wr_req_len   = {5'b0, {3{~bypass}}};

    reg [  7:0] delv_len;
    reg [255:0] delv_data;
    always @(posedge clk) begin
        if ((current_state == MEM_WR) | (current_state == BY_MEM_REQ)) begin
            if (bypass) begin
                delv_len  <= 8'b1;
                delv_data <= {224'b0, from_cpu_cache_wdata};
            end
            else begin
                delv_len  <= {1'b1, 7'b0};
                delv_data <= cache_data; 
            end
        end
        else if (current_state == DELV && from_mem_wr_data_ready) begin
                delv_len  <= {1'b0, delv_len[7:1]};
                delv_data <= {32'b0, delv_data[255:32]};
        end
    end
    //rsp state: BY_RECV, RECV, BY_DELV, DELV
    //BY_RECV, RECV
    assign to_mem_rd_rsp_ready = (current_state == RECV) | (current_state == BY_RECV);

    always @(posedge clk) begin
        if ((current_state == RECV) || (current_state == BY_RECV) && from_mem_rd_rsp_valid)
            from_mem_cache_data <= {from_mem_rd_rsp_data, from_mem_cache_data[255:32]};
    end
    //BY_DELV, DELV
    assign to_mem_wr_data_valid = (current_state == DELV) | (current_state == BY_DELV);
    assign to_mem_wr_data_last  = delv_len[0];
    assign to_mem_wr_data_strb  = {4{~bypass}} | from_cpu_cache_wstrb;
    assign to_mem_wr_data       = delv_data[31:0];

endmodule



