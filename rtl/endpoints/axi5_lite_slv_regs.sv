`include "cc/assertions.svh"
`include "cc/register_bank.svh"

module axi5_lite_slv_regs #(
    parameter int unsigned NUM_REGS   = 1,
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,

    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = '0,

    parameter logic [NUM_REGS-1:0][ADDR_WIDTH-1:0] OFFSET_CFG = '0,
    parameter logic [NUM_REGS-1:0][DATA_WIDTH-1:0] RESET_CFG  = '0,
    parameter logic [NUM_REGS-1:0][DATA_WIDTH-1:0] READ_CFG   = '0,
    parameter logic [NUM_REGS-1:0][DATA_WIDTH-1:0] RW_CFG     = '0,
    parameter logic [NUM_REGS-1:0][DATA_WIDTH-1:0] W1C_CFG    = '0,
    parameter logic [NUM_REGS-1:0][DATA_WIDTH-1:0] W1S_CFG    = '0,
    parameter logic [NUM_REGS-1:0][DATA_WIDTH-1:0] RC_CFG     = '0
) (
    axi5_lite_if.sink axi
);

  typedef logic [ADDR_WIDTH-1:0] addr_t;
  typedef logic [DATA_WIDTH-1:0] data_t;
  typedef logic [DATA_WIDTH/8-1:0] strb_t;
  typedef `CC_REG_BANK_REQ_TYPE(addr_t, data_t, strb_t) req_t;
  typedef `CC_REG_BANK_RESP_TYPE(data_t) resp_t;

  handshake_if #(.payload_t(req_t)) bank_req ();
  handshake_if #(.payload_t(resp_t)) bank_resp ();

  axi5_lite_to_reg i_adapter (
      .axi     (axi),
      .reg_req (bank_req),
      .reg_resp(bank_resp)
  );

  // REGISTER BANK
  register_bank #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
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

  `ASSERT_INIT(AddressWidthMatch, $bits(axi.AWADDR) == ADDR_WIDTH && $bits(axi.ARADDR)
               == ADDR_WIDTH)
  `ASSERT_INIT(DataWidthMatch, $bits(axi.WDATA) == DATA_WIDTH && $bits(axi.RDATA) == DATA_WIDTH)
  `ASSERT_INIT(StrobeWidthMatch, $bits(axi.WSTRB) == DATA_WIDTH/ 8)

endmodule
