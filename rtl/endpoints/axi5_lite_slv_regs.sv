`include "cc/registers.svh"
`include "cc/assertions.svh"
`include "cc/register_bank.svh"
`include "amba/axi5_lite.svh"

// spyglass disable_block W240,W528
module axi5_lite_slv_regs #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned NUM_REGS   = 1,

    localparam type addr_t = logic [ADDR_WIDTH - 1:0],
    localparam type data_t = logic [DATA_WIDTH - 1:0],
    localparam type strb_t = logic [DATA_WIDTH / 8 - 1:0],

    parameter addr_t BASE_ADDR = '0,

    // REGISTER CONFIGURATION
    parameter addr_t [NUM_REGS - 1:0] OFFSET_CFG = '0,
    parameter data_t [NUM_REGS - 1:0] RESET_CFG  = '0,
    parameter data_t [NUM_REGS - 1:0] READ_CFG   = '0,
    parameter data_t [NUM_REGS - 1:0] RW_CFG     = '0,
    parameter data_t [NUM_REGS - 1:0] W1C_CFG    = '0,
    parameter data_t [NUM_REGS - 1:0] W1S_CFG    = '0,
    parameter data_t [NUM_REGS - 1:0] RC_CFG     = '0,

    localparam type req_t  = `CC_REG_BANK_REQ_TYPE(addr_t, data_t, strb_t),
    localparam type resp_t = `CC_REG_BANK_RESP_TYPE(data_t),

    // USER TYPES
    parameter  type req_user_t  = logic,
    parameter  type data_user_t = logic,
    parameter  type resp_user_t = logic,
    localparam type r_user_t    = `AMBA_AXI5_LITE_R_USER_TYPE(data_user_t, resp_user_t)
) (
    axi5_lite_if.sink axi
);

  localparam int unsigned StrbWidth = DATA_WIDTH / 8;
  localparam int unsigned WriteIdWidth = $bits(axi.AWID);
  localparam int unsigned ReadIdWidth = $bits(axi.ARID);
  localparam int unsigned IdWidth = WriteIdWidth > ReadIdWidth ? WriteIdWidth : ReadIdWidth;

  // TYPES
  typedef `AMBA_AXI5_LITE_AW_TYPE(axi, req_user_t) aw_t;
  typedef `AMBA_AXI5_LITE_W_TYPE(axi, data_user_t) w_t;
  typedef `AMBA_AXI5_LITE_AR_TYPE(axi, req_user_t) ar_t;
  typedef `AMBA_AXI5_LITE_B_TYPE(axi, resp_user_t) b_t;
  typedef `AMBA_AXI5_LITE_R_TYPE(axi, r_user_t) r_t;

  aw_t aw_in, aw_r, aw;
  w_t w_in, w_r, w;
  ar_t ar_in, ar_r, ar;
  b_t b_in, b_out;
  r_t r_in, r_out;

  logic [IdWidth - 1:0] id_d, id_r;
  logic idunq_d, idunq_r, write_r;

  logic aw_pending_d, aw_pending_r, aw_fire;
  logic w_pending_d, w_pending_r, w_fire;
  logic ar_pending_d, ar_pending_r, ar_fire;
  logic write_valid, read_valid, select_write, prefer_write_r;
  logic bank_fire, write_fire, read_fire;

  handshake_if #(.payload_t(req_t)) bank_req ();
  handshake_if #(.payload_t(resp_t)) bank_resp ();
  handshake_if #(.payload_t(b_t)) b_req ();
  handshake_if #(.payload_t(b_t)) b_resp ();
  handshake_if #(.payload_t(r_t)) r_req ();
  handshake_if #(.payload_t(r_t)) r_resp ();

  // AW
  always_comb begin
    aw_in = '{
        addr: axi.AWADDR,
        size: axi5_pkg::size_e'(0),
        id: axi.ID_W_WIDTH > 0 ? WriteIdWidth'(axi.AWID) : '0,
        idunq: axi.OO_EN_IDUNQ && axi.AWIDUNQ,
        default: '0
    };
    aw = aw_pending_r ? aw_r : aw_in;
    axi.AWREADY = !aw_pending_r;
    aw_fire = axi.AWVALID && axi.AWREADY;
    aw_pending_d = (aw_pending_r || aw_fire) && !write_fire;
  end

  `REG_ARSTN(aw_pending_r, aw_pending_d, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(aw_r, aw_in, aw_fire && !write_fire, axi.ACLK)

  // W
  always_comb begin
    w_in = '{data: axi.WDATA, strb: axi.O_EN_STRB ? axi.WSTRB : '1, default: '0};
    w = w_pending_r ? w_r : w_in;
    axi.WREADY = !w_pending_r;
    w_fire = axi.WVALID && axi.WREADY;
    w_pending_d = (w_pending_r || w_fire) && !write_fire;
  end

  `REG_ARSTN(w_pending_r, w_pending_d, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(w_r, w_in, w_fire && !write_fire, axi.ACLK)

  // AR
  always_comb begin
    ar_in = '{
        addr: axi.ARADDR,
        size: axi5_pkg::size_e'(0),
        id: axi.ID_R_WIDTH > 0 ? ReadIdWidth'(axi.ARID) : '0,
        idunq: axi.OO_EN_IDUNQ && axi.ARIDUNQ,
        default: '0
    };
    ar = ar_pending_r ? ar_r : ar_in;
    axi.ARREADY = !ar_pending_r;
    ar_fire = axi.ARVALID && axi.ARREADY;
    ar_pending_d = (ar_pending_r || ar_fire) && !read_fire;
  end

  `REG_ARSTN(ar_pending_r, ar_pending_d, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(ar_r, ar_in, ar_fire && !read_fire, axi.ACLK)

  // ACCESS
  always_comb begin
    write_valid = (aw_pending_r || aw_fire) && (w_pending_r || w_fire);
    read_valid = ar_pending_r || ar_fire;
    select_write = write_valid && (!read_valid || prefer_write_r);
    bank_req.valid = bank_req.ready && (write_valid || read_valid);
    bank_fire = bank_req.valid && bank_req.ready;
    write_fire = bank_fire && select_write;
    read_fire = bank_fire && !select_write;

    bank_req.payload = '{
        addr: (select_write ? aw.addr : ar.addr) & ~addr_t'(StrbWidth - 1),
        write: select_write,
        data: select_write ? w.data : '0,
        strb: select_write ? w.strb : '0
    };

    id_d = select_write ? IdWidth'(aw.id) : IdWidth'(ar.id);
    idunq_d = select_write ? aw.idunq : ar.idunq;
  end

  `REG_CE_ARSTN(prefer_write_r, !select_write, bank_fire, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(write_r, select_write, bank_fire, axi.ACLK)
  `REG_CE(id_r, id_d, bank_fire, axi.ACLK)
  `REG_CE(idunq_r, idunq_d, bank_fire, axi.ACLK)

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

  // RESPONSE
  always_comb begin
    b_in = '{
        resp: bank_resp.payload.error ? axi5_pkg::BRESP_SLVERR : axi5_pkg::BRESP_OKAY,
        id: id_r[$bits(axi.BID)-1:0],
        idunq: idunq_r,
        default: '0
    };
    r_in = '{
        data: bank_resp.payload.data,
        resp: bank_resp.payload.error ? axi5_pkg::RRESP_SLVERR : axi5_pkg::RRESP_OKAY,
        id: id_r[$bits(axi.RID)-1:0],
        idunq: idunq_r,
        default: '0
    };
    b_req.payload = b_in;
    r_req.payload = r_in;
    b_req.valid = bank_resp.valid && write_r;
    r_req.valid = bank_resp.valid && !write_r;
    bank_resp.ready = write_r ? b_req.ready : r_req.ready;
  end

  // B
  skid_buffer #(
      .payload_t(b_t)
  ) i_b_skid (
      .clk_i(axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in(b_req),
      .out(b_resp)
  );

  always_comb begin
    b_out = b_resp.payload;
    `AMBA_AXI5_LITE_UNPACK_B(axi, b_out)
    axi.BVALID   = b_resp.valid;
    b_resp.ready = axi.BREADY;
  end

  // R
  skid_buffer #(
      .payload_t(r_t)
  ) i_r_skid (
      .clk_i(axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in(r_req),
      .out(r_resp)
  );

  always_comb begin
    r_out = r_resp.payload;
    `AMBA_AXI5_LITE_UNPACK_R(axi, r_out)
    axi.RVALID   = r_resp.valid;
    r_resp.ready = axi.RREADY;
  end

  // CHECKS
  `ASSERT_INIT(WriteAddressWidthMatch, ADDR_WIDTH == $bits(axi.AWADDR))
  `ASSERT_INIT(ReadAddressWidthMatch, ADDR_WIDTH == $bits(axi.ARADDR))
  `ASSERT_INIT(WriteDataWidthMatch, DATA_WIDTH == $bits(axi.WDATA))
  `ASSERT_INIT(ReadDataWidthMatch, DATA_WIDTH == $bits(axi.RDATA))
  `ASSERT_INIT(StrobeWidthMatch, DATA_WIDTH/ 8 == $bits(axi.WSTRB))
  `ASSERT_INIT(WriteIdWidthMatch, $bits(axi.AWID) == $bits(axi.BID))
  `ASSERT_INIT(ReadIdWidthMatch, $bits(axi.ARID) == $bits(axi.RID))
  `ASSERT_INIT(SizeDisabled, !axi.O_EN_SIZE)
  `ASSERT_INIT(TraceDisabled, !axi.C_EN_TRACE)

  `ASSERT(BankAccepted, bank_req.valid |-> bank_req.ready, axi.ACLK, axi.ARESETn)
  `ASSERT(OwnerStable, bank_resp.valid && !bank_resp.ready |=> $stable({write_r, id_r, idunq_r}),
          axi.ACLK, axi.ARESETn)
  `ASSERT(BStable, axi.BVALID && !axi.BREADY |=> axi.BVALID && $stable(b_out), axi.ACLK,
          axi.ARESETn)
  `ASSERT(RStable, axi.RVALID && !axi.RREADY |=> axi.RVALID && $stable(r_out), axi.ACLK,
          axi.ARESETn)

endmodule

// spyglass enable_block W240,W528
