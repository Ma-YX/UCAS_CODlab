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

    //TODO: Please add your I-Cache code here
	localparam WAIT     = 8'b00000001,
	           TAG_RD   = 8'b00000010,
	           CACHE_RD = 8'b00000100,
	           EVICT    = 8'b00001000, 
	           MEM_RD   = 8'b00010000,
	           RECV     = 8'b00100000,
	           REFILL   = 8'b01000000,
	           RESP     = 8'b10000000;
    reg [7:0] current_state;
    reg [7:0] next_state;

    //declarations
    reg         valid0 [7:0];
    reg         valid1 [7:0];
    reg         valid2 [7:0];
    reg         valid3 [7:0];
    reg [ 23:0] tag0   [7:0];
    reg [ 23:0] tag1   [7:0];
    reg [ 23:0] tag2   [7:0];
    reg [ 23:0] tag3   [7:0];
    reg [255:0] data0  [7:0];
    reg [255:0] data1  [7:0];
    reg [255:0] data2  [7:0];
    reg [255:0] data3  [7:0];

    reg [31:0] from_cpu_cache_inst_addr;
    wire [ 2:0] set;
    wire [23:0] tag;
    wire [ 4:0] offset;
    
    wire hit_miss0;
    wire hit_miss1;
    wire hit_miss2;
    wire hit_miss3;
    wire hit_miss;
    reg  hit_miss_r;
    reg  hit_miss_r0;
    reg  hit_miss_r1;
    reg  hit_miss_r2;
    reg  hit_miss_r3;
    wire hit_miss_01;
    
    reg [2:0] PLRU_r [7:0];
    
    wire valid;
    wire L0;
    wire L1;
    wire L2;
    wire L3;
    
    wire [255:0] data; //orignal data in cache
    wire [ 31:0] cache_valid_data;
    reg [31:0] to_cpu_cache_data;
    wire [ 31:0] mem_vaild_data;
    reg  [ 31:0] to_cpu_mem_data;
    reg [255:0] from_mem_rsp_data;
    
    //state machine
    //current state
    always @(posedge clk) begin
        if (rst)
            current_state <= WAIT;
        else
            current_state <= next_state;
    end
    //next state
    always @(*) begin
        case (current_state)
            WAIT: begin
                if (from_cpu_inst_req_valid)
                    next_state = TAG_RD;
                else
                    next_state = WAIT;
            end

            TAG_RD: begin
                if (hit_miss)
                    next_state = CACHE_RD;
                else
                    next_state = EVICT; 
            end

            CACHE_RD: begin
                next_state = RESP;
            end

            EVICT: begin
                next_state = MEM_RD;
            end

            MEM_RD: begin
                if (from_mem_rd_req_ready)
                    next_state = RECV;
                else
                    next_state = MEM_RD;
            end

            RECV: begin
                if (from_mem_rd_rsp_valid && from_mem_rd_rsp_last)
                    next_state = REFILL;
                else
                    next_state = RECV;
            end

            REFILL: begin
                next_state = RESP;
            end

            RESP: begin
                if (from_cpu_cache_rsp_ready)
                    next_state = WAIT;
                else
                    next_state = RESP;
            end

            default:
                next_state = WAIT;
        endcase
    end
    
    //cache control signals
    //state: TAG_RD, EVICT
    //TAG_RD
    assign set    = from_cpu_cache_inst_addr[ 7:5];
    assign tag    = from_cpu_cache_inst_addr[31:8];
    assign offset = from_cpu_cache_inst_addr[ 4:0];
    assign hit_miss0 = valid0[set] & tag0[set] == tag;
    assign hit_miss1 = valid1[set] & tag1[set] == tag;
    assign hit_miss2 = valid2[set] & tag2[set] == tag;
    assign hit_miss3 = valid3[set] & tag3[set] == tag;
    assign hit_miss  = hit_miss0 | hit_miss1 | hit_miss2 | hit_miss3;
    //EVICT
    assign valid = valid0[set] & valid1[set] & valid2[set] & valid3[set];
    assign L0 =  valid & ~PLRU_r[set][1] & ~PLRU_r[set][0] |
                ~valid0[set];
    assign L1 =  valid &  PLRU_r[set][1] & ~PLRU_r[set][0] |
                ~valid1[set] & valid0[set];
    assign L2 =  valid & ~PLRU_r[set][2] &  PLRU_r[set][0] |
                ~valid2[set] & valid0[set] & valid1[set];
    assign L3 =  valid &  PLRU_r[set][2] &  PLRU_r[set][0] |
                ~valid3[set] & valid0[set] & valid1[set] & valid2[set];

    always @(posedge clk) begin
        if (current_state == TAG_RD) begin
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
    //algorithm ：PLRU
    assign hit_miss_01 = hit_miss_r0 | hit_miss_r1;
    always @(posedge clk) begin
        if (rst) begin
            PLRU_r[0] <= 3'b0; PLRU_r[1] <= 3'b0; PLRU_r[2] <= 3'b0; PLRU_r[3] <= 3'b0;
            PLRU_r[4] <= 3'b0; PLRU_r[5] <= 3'b0; PLRU_r[6] <= 3'b0; PLRU_r[7] <= 3'b0;        
        end
        else if (current_state == RESP) begin
            PLRU_r[set][0] <= hit_miss_01;
            if (hit_miss_01)
                PLRU_r[set][1] <= hit_miss_r0;
            if (~hit_miss_01)
                PLRU_r[set][2] <= hit_miss_r2;
        end
    end
    
    //cache operations
    //state: CACHE_RD, REFILL
    //CACHE_RD
    assign data             = {256{hit_miss_r0}} & data0[set] |
                              {256{hit_miss_r1}} & data1[set] |
                              {256{hit_miss_r2}} & data2[set] |
                              {256{hit_miss_r3}} & data3[set];
    assign cache_valid_data = data[{offset, 3'd0}+:32];
    
    always @(posedge clk) begin
        if (current_state == CACHE_RD)
            to_cpu_cache_data <= cache_valid_data;
    end
    //REFILL
    assign mem_vaild_data = from_mem_rsp_data[{offset, 3'd0}+:32];
    
    always @(posedge clk) begin
        if (current_state == REFILL)
            to_cpu_mem_data <= mem_vaild_data;        
    end
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
    //data array
    always @(posedge clk) begin
        if (current_state == REFILL) begin
            if (hit_miss_r0) data0[set] <= from_mem_rsp_data;
            if (hit_miss_r1) data1[set] <= from_mem_rsp_data;
            if (hit_miss_r2) data2[set] <= from_mem_rsp_data;
            if (hit_miss_r3) data3[set] <= from_mem_rsp_data;
        end
    end
    
    //interactions of data and control signals with cpu
    //req state: WAIT
    assign to_cpu_inst_req_ready = current_state == WAIT;

    always @(posedge clk) begin
        if (current_state == WAIT)
           from_cpu_cache_inst_addr <= from_cpu_inst_req_addr;
    end
    //rsp state: RESP
    assign to_cpu_cache_rsp_valid = current_state == RESP;
    assign to_cpu_cache_rsp_data  = {32{ hit_miss_r}} & to_cpu_cache_data
                                  | {32{~hit_miss_r}} & to_cpu_mem_data;

    //interactions of data and control signals with memory
    //req state: MEM_RD
    assign to_mem_rd_req_valid = current_state == MEM_RD;
    assign to_mem_rd_req_addr  = {from_cpu_cache_inst_addr[31:5], 5'b0};
    //rsp state: RECV
    assign to_mem_rd_rsp_ready = current_state == RECV;
    
    always @(posedge clk) begin
        if (current_state == RECV && from_mem_rd_rsp_valid)
            from_mem_rsp_data <= {from_mem_rd_rsp_data, from_mem_rsp_data[255:32]};
    end


endmodule
