`include "cc/register_bank.svh"
`include "amba/axi5_lite.svh"

module axi5_lite_slv_regs #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned NUM_REGS   = 1,

    localparam type addr_t = logic [ADDR_WIDTH - 1:0],
    localparam type data_t = logic [DATA_WIDTH - 1:0],
    localparam type strb_t = logic [DATA_WIDTH / 8 - 1:0],

    parameter  type req_user_t  = logic,
    parameter  type data_user_t = logic,
    parameter  type resp_user_t = logic,
    localparam type r_user_t    = `AMBA_AXI5_LITE_R_USER_TYPE(data_user_t, resp_user_t),

    parameter axi5_pkg::prot_t READ_PROT_MASK = '0,
    parameter axi5_pkg::prot_t READ_PROT_VALUE = '0,
    parameter axi5_pkg::prot_t WRITE_PROT_MASK = '0,
    parameter axi5_pkg::prot_t WRITE_PROT_VALUE = '0,
    parameter axi5_pkg::max_subsystem_id_t SUBSYSID_MASK = '0,
    parameter axi5_pkg::max_subsystem_id_t SUBSYSID_VALUE = '0,
    parameter resp_user_t BUSER_VALUE = '0,
    parameter r_user_t RUSER_VALUE = '0,

    parameter addr_t                  BASE_ADDR  = '0,
    parameter addr_t [NUM_REGS - 1:0] OFFSET_CFG = '0,
    parameter data_t [NUM_REGS - 1:0] RESET_CFG  = '0,
    parameter data_t [NUM_REGS - 1:0] READ_CFG   = '0,
    parameter data_t [NUM_REGS - 1:0] RW_CFG     = '0,
    parameter data_t [NUM_REGS - 1:0] W1C_CFG    = '0,
    parameter data_t [NUM_REGS - 1:0] W1S_CFG    = '0,
    parameter data_t [NUM_REGS - 1:0] RC_CFG     = '0,

    localparam type req_t  = `CC_REG_BANK_REQ_TYPE(addr_t, data_t, strb_t),
    localparam type resp_t = `CC_REG_BANK_RESP_TYPE(data_t)
) (
    axi5_lite_if.sink axi
);

  handshake_if #(.payload_t(req_t)) bank_req ();
  handshake_if #(.payload_t(resp_t)) bank_resp ();

  axi5_lite_to_reg #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .req_user_t(req_user_t),
      .data_user_t(data_user_t),
      .resp_user_t(resp_user_t),
      .READ_PROT_MASK(READ_PROT_MASK),
      .READ_PROT_VALUE(READ_PROT_VALUE),
      .WRITE_PROT_MASK(WRITE_PROT_MASK),
      .WRITE_PROT_VALUE(WRITE_PROT_VALUE),
      .SUBSYSID_MASK(SUBSYSID_MASK),
      .SUBSYSID_VALUE(SUBSYSID_VALUE),
      .BUSER_VALUE(BUSER_VALUE),
      .RUSER_VALUE(RUSER_VALUE)
  ) i_adapter (
      .axi(axi),
      .reg_req(bank_req),
      .reg_resp(bank_resp)
  );

  // REGISTER BANK
  register_bank #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .NUM_REGS(NUM_REGS),
      .BASE_ADDR(BASE_ADDR),
      .OFFSET_CFG(OFFSET_CFG),
      .RESET_CFG(RESET_CFG),
      .READ_CFG(READ_CFG),
      .RW_CFG(RW_CFG),
      .W1C_CFG(W1C_CFG),
      .W1S_CFG(W1S_CFG),
      .RC_CFG(RC_CFG)
  ) i_regs (
      .clk_i(axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in(bank_req),
      .out(bank_resp)
  );

endmodule
