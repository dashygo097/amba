`include "cc/registers.svh"
`include "cc/assertions.svh"
`include "cc/register_bank.svh"
`include "amba/axi5_lite_payload.svh"

module axi5_lite_slv_regs #(
    // WIDTHS
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,

    // REGISTER MAP
    parameter int unsigned NUM_REGS = 1,
    localparam type addr_t = logic [ADDR_WIDTH - 1:0],
    localparam type data_t = logic [DATA_WIDTH - 1:0],
    localparam type strb_t = logic [DATA_WIDTH / 8 - 1:0],
    localparam type reg_cfg_t = `CC_REG_BANK_CFG_TYPE(addr_t, data_t),
    parameter addr_t BASE_ADDR = '0,
    parameter reg_cfg_t [NUM_REGS - 1:0] REG_CFG = '0,
    localparam type req_t = `CC_REG_BANK_REQ_TYPE(addr_t, data_t, strb_t),
    localparam type resp_t = `CC_REG_BANK_RESP_TYPE(data_t)
) (
    axi5_lite_if.sink axi
);
  localparam int unsigned StrbWidth = DATA_WIDTH / 8;

  `AXI5_LITE_TYPEDEFS(lite, axi)

  typedef axi.bresp_t bresp_t;
  typedef axi.rresp_t rresp_t;

  typedef struct packed {
    logic write;
    logic [$bits(axi.AWID) - 1:0] write_id;
    logic [$bits(axi.ARID) - 1:0] read_id;
    logic idunq;
    logic trace;
  } context_t;

  lite_aw_t aw_in, aw_r, aw;
  lite_w_t w_in, w_r, w;
  lite_ar_t ar_in, ar_r, ar;
  lite_b_t b_in, b_out;
  lite_r_t r_in, r_out;

  context_t context_d, context_r;

  logic aw_valid, aw_valid_r, aw_fire;
  logic w_valid, w_valid_r, w_fire;
  logic ar_valid, ar_valid_r, ar_fire;
  logic write_valid;
  logic [1:0] write_take;
  logic select_write, prefer_write_r;
  logic locked_r, locked_write_r;
  logic issue, issue_write, issue_read;

  handshake_if #(.payload_t(req_t)) bank_req ();
  handshake_if #(.payload_t(resp_t)) bank_resp ();
  handshake_if #(.payload_t(lite_b_t)) b_req ();
  handshake_if #(.payload_t(lite_b_t)) b_resp ();
  handshake_if #(.payload_t(lite_r_t)) r_req ();
  handshake_if #(.payload_t(lite_r_t)) r_resp ();

  // AW
  `AXI5_LITE_PACK(aw_in, axi, AXI5_LITE_AW_FIELDS)

  always_comb begin
    axi.AWREADY = axi.ARESETn && !aw_valid_r;
    aw_fire = axi.AWREADY && axi.AWVALID;
    aw_valid = aw_valid_r || axi.AWVALID;
    aw = aw_valid_r ? aw_r : aw_in;
  end

  `REG_CE_ARSTN(aw_valid_r, !write_take[0], aw_fire || write_take[0], 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(aw_r, aw_in, aw_fire && !write_take[0], axi.ACLK)

  // W
  `AXI5_LITE_PACK(w_in, axi, AXI5_LITE_W_FIELDS)

  always_comb begin
    axi.WREADY = axi.ARESETn && !w_valid_r;
    w_fire = axi.WVALID && axi.WREADY;
    w_valid = w_valid_r || axi.WVALID;
    w = w_valid_r ? w_r : w_in;
  end

  `REG_CE_ARSTN(w_valid_r, !write_take[1], w_fire || write_take[1], 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(w_r, w_in, w_fire && !write_take[1], axi.ACLK)

  // AR
  `AXI5_LITE_PACK(ar_in, axi, AXI5_LITE_AR_FIELDS)

  always_comb begin
    axi.ARREADY = axi.ARESETn && !ar_valid_r;
    ar_fire = axi.ARVALID && axi.ARREADY;
    ar_valid = ar_valid_r || axi.ARVALID;
    ar = ar_valid_r ? ar_r : ar_in;
  end

  `REG_CE_ARSTN(ar_valid_r, !issue_read, ar_fire || issue_read, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(ar_r, ar_in, ar_fire && !issue_read, axi.ACLK)

  // WRITE JOIN
  handshake_join #(
      .NUM_INPUTS(2)
  ) i_write_join (
      .valid_i({w_valid, aw_valid}),
      .ready_o(write_take),
      .valid_o(write_valid),
      .ready_i(issue_write)
  );

  // ARBITRATION
  always_comb begin
    select_write = locked_r ? locked_write_r : (write_valid && (!ar_valid || prefer_write_r));
    bank_req.valid = axi.ARESETn && (select_write ? write_valid : ar_valid);
    issue = bank_req.valid && bank_req.ready;
    issue_write = issue && select_write;
    issue_read = issue && !select_write;
  end

  `REG_CE_ARSTN(prefer_write_r, !select_write, issue, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE_ARSTN(locked_r, !bank_req.ready, bank_req.valid, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(locked_write_r, select_write, bank_req.valid && !bank_req.ready, axi.ACLK)

  // REQUEST
  always_comb begin
    bank_req.payload = '0;
    context_d = '0;
    context_d.write = select_write;

    if (select_write) begin
      bank_req.payload.addr = aw.addr & ~addr_t'(StrbWidth - 1);
      bank_req.payload.write = 1'b1;
      bank_req.payload.data = w.data;
      bank_req.payload.strb = axi.O_EN_STRB ? w.strb : '1;

      context_d.write_id = axi.ID_W_WIDTH > 0 ? aw.id : '0;
      context_d.idunq = axi.OO_EN_IDUNQ && aw.idunq;
      context_d.trace = axi.C_EN_TRACE && aw.trace;
    end else begin
      bank_req.payload.addr = ar.addr & ~addr_t'(StrbWidth - 1);

      context_d.read_id = axi.ID_R_WIDTH > 0 ? ar.id : '0;
      context_d.idunq = axi.OO_EN_IDUNQ && ar.idunq;
      context_d.trace = axi.C_EN_TRACE && ar.trace;
    end
  end

  // CONTEXT
  `REG_CE(context_r, context_d, issue, axi.ACLK)

  // MAIN DEVICE
  register_bank #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .NUM_REGS(NUM_REGS),
      .BASE_ADDR(BASE_ADDR),
      .REG_CFG(REG_CFG)
  ) i_regs (
      .clk_i(axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in(bank_req),
      .out(bank_resp)
  );

  // RESPONSE
  always_comb begin
    b_req.valid = bank_resp.valid && context_r.write;
    r_req.valid = bank_resp.valid && !context_r.write;
    bank_resp.ready = context_r.write ? b_req.ready : r_req.ready;

    b_in = '0;
    b_in.resp = bank_resp.payload.error
        ? bresp_t'(axi5_pkg::RESP_SLVERR) : bresp_t'(axi5_pkg::RESP_OKAY);
    b_in.id = context_r.write_id;
    b_in.idunq = context_r.idunq;
    b_in.trace = context_r.trace;
    b_req.payload = b_in;

    r_in = '0;
    r_in.data = bank_resp.payload.data;
    r_in.resp = bank_resp.payload.error
        ? rresp_t'(axi5_pkg::RESP_SLVERR) : rresp_t'(axi5_pkg::RESP_OKAY);
    r_in.id = context_r.read_id;
    r_in.idunq = context_r.idunq;
    r_in.trace = context_r.trace;
    r_req.payload = r_in;
  end

  // B
  skid_buffer #(
      .payload_t(lite_b_t)
  ) i_b_skid (
      .clk_i(axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in(b_req),
      .out(b_resp)
  );

  always_comb begin
    axi.BVALID = b_resp.valid;
    b_resp.ready = axi.BREADY;
    b_out = b_resp.payload;
  end

  `AXI5_LITE_UNPACK(axi, b_out, AXI5_LITE_B_FIELDS)

  // R
  skid_buffer #(
      .payload_t(lite_r_t)
  ) i_r_skid (
      .clk_i(axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in(r_req),
      .out(r_resp)
  );

  always_comb begin
    axi.RVALID = r_resp.valid;
    r_resp.ready = axi.RREADY;
    r_out = r_resp.payload;
  end

  `AXI5_LITE_UNPACK(axi, r_out, AXI5_LITE_R_FIELDS)

  // CHECK SIGNALS
  always_comb begin
    axi.AWREADYCHK = 1'b0;
    axi.WREADYCHK  = 1'b0;
    axi.ARREADYCHK = 1'b0;
    axi.BVALIDCHK  = 1'b0;
    axi.RVALIDCHK  = 1'b0;
  end

  // CHECKS
  `ASSERT_INIT(AddressWidthMatch, ADDR_WIDTH == $bits(axi.AWADDR) && ADDR_WIDTH == $bits(axi.ARADDR
                                                                                            ))
  `ASSERT_INIT(DataWidthMatch, DATA_WIDTH == $bits(axi.WDATA) && DATA_WIDTH == $bits(axi.RDATA))
  `ASSERT_INIT(StrobeWidthMatch, StrbWidth == $bits(axi.WSTRB))
  `ASSERT_INIT(SizeDisabled, !axi.O_EN_SIZE)
  `ASSERT_INIT(PoisonDisabled, !axi.O_EN_POISON)
  `ASSERT_INIT(ControlCheckDisabled, !axi.C_EN_CTRLCHK)
  `ASSERT_INIT(DataCheckDisabled, !axi.C_EN_DATACHK)
  `ASSERT(BankStable, bank_req.valid && !bank_req.ready |=> bank_req.valid && $stable
                      (bank_req.payload) && $stable(context_d), axi.ACLK, axi.ARESETn)
  `ASSERT(ContextStable, bank_resp.valid && !bank_resp.ready |=> $stable(context_r), axi.ACLK,
          axi.ARESETn)

endmodule
