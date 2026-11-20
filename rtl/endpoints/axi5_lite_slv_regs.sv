`include "cc/register_bank.svh"

module axi5_lite_slv_regs #(
    parameter int unsigned NUM_REGS = 1,

    localparam type addr_t      = logic [    $bits(axi.AWADDR)-1:0],
    localparam type data_t      = logic [     $bits(axi.WDATA)-1:0],
    localparam type subsys_id_t = logic [$bits(axi.AWSUBSYSID)-1:0],
    localparam type buser_t     = logic [     $bits(axi.BUSER)-1:0],
    localparam type ruser_t     = logic [     $bits(axi.RUSER)-1:0],

    parameter axi5_pkg::prot_t                          READ_PROT_MASK   = '0,
    parameter axi5_pkg::prot_t                          READ_PROT_VALUE  = '0,
    parameter axi5_pkg::prot_t                          WRITE_PROT_MASK  = '0,
    parameter axi5_pkg::prot_t                          WRITE_PROT_VALUE = '0,
    parameter logic            [$bits(subsys_id_t)-1:0] SUBSYSID_MASK    = '0,
    parameter logic            [$bits(subsys_id_t)-1:0] SUBSYSID_VALUE   = '0,
    parameter logic            [    $bits(buser_t)-1:0] BUSER_VALUE      = '0,
    parameter logic            [    $bits(ruser_t)-1:0] RUSER_VALUE      = '0,

    parameter addr_t                  BASE_ADDR  = '0,
    parameter addr_t [NUM_REGS - 1:0] OFFSET_CFG = '0,
    parameter data_t [NUM_REGS - 1:0] RESET_CFG  = '0,
    parameter data_t [NUM_REGS - 1:0] READ_CFG   = '0,
    parameter data_t [NUM_REGS - 1:0] RW_CFG     = '0,
    parameter data_t [NUM_REGS - 1:0] W1C_CFG    = '0,
    parameter data_t [NUM_REGS - 1:0] W1S_CFG    = '0,
    parameter data_t [NUM_REGS - 1:0] RC_CFG     = '0
) (
    axi5_lite_if.sink axi
);

  typedef logic [$bits(axi.WSTRB)-1:0] strb_t;
  typedef `CC_REG_BANK_REQ_TYPE(addr_t, data_t, strb_t) req_t;
  typedef `CC_REG_BANK_RESP_TYPE(data_t) resp_t;

  handshake_if #(.payload_t(req_t)) bank_req ();
  handshake_if #(.payload_t(resp_t)) bank_resp ();

  axi5_lite_to_reg #(
      .READ_PROT_MASK  (READ_PROT_MASK),
      .READ_PROT_VALUE (READ_PROT_VALUE),
      .WRITE_PROT_MASK (WRITE_PROT_MASK),
      .WRITE_PROT_VALUE(WRITE_PROT_VALUE),
      .SUBSYSID_MASK   (SUBSYSID_MASK),
      .SUBSYSID_VALUE  (SUBSYSID_VALUE),
      .BUSER_VALUE     (BUSER_VALUE),
      .RUSER_VALUE     (RUSER_VALUE)
  ) i_adapter (
      .axi     (axi),
      .reg_req (bank_req),
      .reg_resp(bank_resp)
  );

  // REGISTER BANK
  register_bank #(
      .ADDR_WIDTH($bits(axi.AWADDR)),
      .DATA_WIDTH($bits(axi.WDATA)),
      .NUM_REGS  (NUM_REGS),
      .BASE_ADDR (BASE_ADDR),
      .OFFSET_CFG(OFFSET_CFG),
      .RESET_CFG (RESET_CFG),
      .READ_CFG  (READ_CFG),
      .RW_CFG    (RW_CFG),
      .W1C_CFG   (W1C_CFG),
      .W1S_CFG   (W1S_CFG),
      .RC_CFG    (RC_CFG)
  ) i_regs (
      .clk_i  (axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in     (bank_req),
      .out    (bank_resp)
  );

endmodule
