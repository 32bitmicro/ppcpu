`include "config.v"

// Instruction fetch stage

module fetch (
    input i_clk,
    input i_rst,

    output [`RW-1:0] o_req_addr,
    output reg o_req_active,
    input [`I_SIZE-1:0] i_req_data,
    input i_req_data_valid,
    
    input i_next_ready,
    output reg o_submit,
    input i_flush,
 
    output reg [`I_SIZE-1:0] o_instr,
    output o_jmp_predict,

    input [`RW-1:0] i_exec_pc
);

reg [`I_SIZE-1:0] hold_instr; // buffer if output is not ready
reg hold_valid;

reg [`RW-1:0] fetch_pc, next_fetch_pc;
reg next_branch_pred;
assign o_jmp_predict = next_branch_pred;
reg invalidate_request;
wire [`RW-1:0] instr_imm = o_instr[31:16];

// halt loop opt: disable req and submit current instruction
// NOTE: don't do prediction on srs 0 and iret

assign o_req_addr = next_fetch_pc;

always @(posedge i_clk) begin
    if(i_rst) begin
        fetch_pc <= -`RW'b1; // start from addr 0
        o_submit <= 1'b0; // wait until first requst is completed
        o_instr <= `I_SIZE'b0;
        o_req_active <= 1'b0;
        hold_valid <= 1'b0;
        invalidate_request <= 1'b0;
    end else if (i_flush) begin
        // invalidate everything on flush
        o_submit <= 1'b0;
        hold_valid <= 1'b0;
        // read new correct pc (-1 to fetch correct one) and start request
        fetch_pc <= i_exec_pc - `RW'b1;
        o_instr <= `I_SIZE'b0; // ensure +1 pred
        invalidate_request <= o_req_active;
    end else if (i_req_data_valid & invalidate_request) begin
        invalidate_request <= 1'b0;
        o_req_active <= 1'b1;
        o_submit <= 1'b0;
    end else if (i_req_data_valid & i_next_ready) begin
        // memory request completed, submit instruction
        o_instr <= i_req_data;
        fetch_pc <= next_fetch_pc;
        o_submit <= 1'b1;
        // always request new instruction, address is computed comb
        o_req_active <= 1'b1;
    end else if(i_req_data_valid & ~i_next_ready) begin
        hold_instr <= i_req_data;
        hold_valid <= 1'b1;
        o_req_active <= 1'b0;
        o_submit <= 1'b0;
    end else if(hold_valid & i_next_ready) begin
        // submit holded instruction when next stage is ready
        o_instr <= hold_instr;
        fetch_pc <= next_fetch_pc;
        o_submit <= 1'b1;
        hold_valid <= 1'b0;
        o_req_active <= 1'b1;
    end else if (~hold_valid) begin // don't overwrite hold
        o_req_active <= 1'b1;
        o_submit <= 1'b0;
    end else begin
        o_req_active <= 1'b0;
        o_submit <= 1'b0;
    end
end

// BRANCH PREDICTION / PC DECODE
always @(*) begin
    if (o_instr[6:0] == 7'h0e) begin
        if (o_instr[10:7] == 4'h0) begin
            // unconditional jump
            next_fetch_pc = instr_imm;
            next_branch_pred = 1'b1;
        end else begin
            // try to predict jump
            if (fetch_pc > instr_imm) begin
                // back jump (taken)
                next_fetch_pc = instr_imm;
                next_branch_pred = 1'b1;
            end else begin
                // forward jump (not taken)
                next_fetch_pc = fetch_pc + `RW'b1;
                next_branch_pred = 1'b0;
            end
        end
    end else if (o_instr[6:0] == 7'h0f) begin
        next_fetch_pc = instr_imm;
        next_branch_pred = 1'b1;
    end else begin
        next_fetch_pc = fetch_pc + `RW'b1;
        next_branch_pred = 1'b0;
    end
end

endmodule
