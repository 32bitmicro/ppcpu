`include "config.v"

module execute (
    input i_clk,
    input i_rst,

    // Pipeline control singnals
    output reg o_ready,
    input i_submit,
    output reg o_flush,
    input i_flush,

    input [`RW-1:0] i_imm,
    input i_jmp_predict,

    // Execution control singals
    input c_pc_inc, c_pc_ie,
    input c_r_bus_imm,
    input [`ALU_MODE_W-1:0] c_alu_mode,
    input c_alu_carry_en, c_alu_flags_ie,
    input [`REGNO_LOG-1:0] c_l_reg_sel, c_r_reg_sel, 
    input [`REGNO-1:0] c_rf_ie,
    input [`JUMP_CODE_W-1:0] c_jump_cond_code,

    // Signals to fetch stage to handle mispredictions
    output o_pc_update,
    output [`RW-1:0] o_exec_pc,

    // Debug outputs
    output [`RW-1:0] dbg_r0, dbg_pc
);

// separate memory access stage?
assign o_ready = 1'b1; // for now this stage is always read (no mem)

// don't update state when current instruction is not valid (flush or bubble)
wire valid = i_submit & ~i_flush;

// Internal buses
wire [`RW-1:0] reg_l_con, reg_r_con;
wire [`RW-1:0] alu_l_bus, alu_r_bus;
wire [`RW-1:0] alu_bus;

// Muxes definitions
assign alu_l_bus = reg_l_con;
assign alu_r_bus = (c_r_bus_imm ? i_imm : reg_r_con);

// Component connects
wire [`RW-1:0] pc_val;
wire [`ALU_FLAG_CNT-1:0] alu_flags_d, alu_flags_q;
assign dbg_pc = pc_val;
assign o_pc_update = valid;
assign o_exec_pc = pc_val;

// Submodules
rf rf(.i_clk(i_clk), .i_rst(i_rst), .i_d(alu_bus), .o_lout(reg_l_con),
    .o_rout(reg_r_con), .i_lout_sel(c_l_reg_sel), .i_rout_sel(c_r_reg_sel),
    .i_ie(c_rf_ie), .i_gie(valid), .dbg_r0(dbg_r0));

alu alu(.i_l(alu_l_bus), .i_r(alu_r_bus), .o_out(alu_bus), .i_mode(c_alu_mode), 
    .o_flags(alu_flags_d), .i_carry(alu_flags_q[`ALU_FLAG_C] & c_alu_carry_en));

pc pc(.i_clk(i_clk), .i_rst(i_rst), .i_bus(alu_bus), .i_c_pc_inc((c_pc_inc | (~jump_dec_en & jump_dec_valid)) & i_submit), 
    .i_c_pc_ie((c_pc_ie | (jump_dec_en & jump_dec_valid)) & valid), .o_pc(pc_val));

// Cpu control registers
register  #(.N(`ALU_FLAG_CNT)) alu_flag_reg (.i_clk(i_clk), .i_rst(i_rst), 
    .i_d(alu_flags_d), .o_d(alu_flags_q), .i_ie(c_alu_flags_ie & valid));

// JUMP DECODE
reg jump_dec_en;
wire jump_dec_valid = c_jump_cond_code[`JUMP_CODE_BIT_EN];

wire jump_mispredict = jump_dec_valid & (jump_dec_en ^ i_jmp_predict);

always @(posedge i_clk) begin
    o_flush <= jump_mispredict & valid; // invalidate itself and all previous stages at next cycle
end

`define JUMP_CODE_UNCOND`JUMP_CODE_W'b10000
`define JUMP_CODE_CARRY `JUMP_CODE_W'b10001
`define JUMP_CODE_EQUAL `JUMP_CODE_W'b10010
`define JUMP_CODE_LT    `JUMP_CODE_W'b10011
`define JUMP_CODE_GT    `JUMP_CODE_W'b10100
`define JUMP_CODE_LE    `JUMP_CODE_W'b10101
`define JUMP_CODE_GE    `JUMP_CODE_W'b10110
`define JUMP_CODE_NE    `JUMP_CODE_W'b10111
`define JUMP_CODE_OVF   `JUMP_CODE_W'b11000
`define JUMP_CODE_PAR   `JUMP_CODE_W'b11001
always @(*) begin
    case (c_jump_cond_code[`JUMP_CODE_W-1:0])
        `JUMP_CODE_UNCOND:
            jump_dec_en = 1'b1;
        `JUMP_CODE_CARRY:
            jump_dec_en = alu_flags_q[`ALU_FLAG_C];
        `JUMP_CODE_EQUAL:
            jump_dec_en = alu_flags_q[`ALU_FLAG_Z];
        `JUMP_CODE_LT:
            jump_dec_en = alu_flags_q[`ALU_FLAG_N];
        `JUMP_CODE_GT:
            jump_dec_en = ~(alu_flags_q[`ALU_FLAG_N] | alu_flags_q[`ALU_FLAG_Z]);
        `JUMP_CODE_LE:
            jump_dec_en = alu_flags_q[`ALU_FLAG_N] | alu_flags_q[`ALU_FLAG_Z];
        `JUMP_CODE_GE:
            jump_dec_en = ~alu_flags_q[`ALU_FLAG_N];
        `JUMP_CODE_NE:
            jump_dec_en = ~alu_flags_q[`ALU_FLAG_Z];
        `JUMP_CODE_OVF:
            jump_dec_en = alu_flags_q[`ALU_FLAG_O];
        `JUMP_CODE_PAR:
            jump_dec_en = alu_flags_q[`ALU_FLAG_P];
        default:
            jump_dec_en = 1'b0;
    endcase
end

endmodule;

`include "alu.v"
`include "rf.v"
