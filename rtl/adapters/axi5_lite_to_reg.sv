`include "cc/registers.svh"
`include "cc/assertions.svh"
`include "cc/register_bank.svh"
`include "amba/axi5_lite.svh"

// spyglass disable_block W240,W528
module axi5_lite_to_reg #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,

    localparam type addr_t = logic [ADDR_WIDTH - 1:0],
    localparam type data_t = logic [DATA_WIDTH - 1:0],
    localparam type strb_t = logic [DATA_WIDTH / 8 - 1:0],
    localparam type req_t = `CC_REG_BANK_REQ_TYPE(addr_t, data_t, strb_t),
    localparam type resp_t = `CC_REG_BANK_RESP_TYPE(data_t),

    parameter type req_user_t = logic,
    parameter type data_user_t = logic,
    parameter type resp_user_t = logic,
    localparam type r_user_t = `AMBA_AXI5_LITE_R_USER_TYPE(data_user_t, resp_user_t),

    parameter axi5_pkg::prot_t READ_PROT_MASK = '0,
    parameter axi5_pkg::prot_t READ_PROT_VALUE = '0,
    parameter axi5_pkg::prot_t WRITE_PROT_MASK = '0,
    parameter axi5_pkg::prot_t WRITE_PROT_VALUE = '0,
    parameter axi5_pkg::max_subsystem_id_t SUBSYSID_MASK = '0,
    parameter axi5_pkg::max_subsystem_id_t SUBSYSID_VALUE = '0,
    parameter resp_user_t BUSER_VALUE = '0,
    parameter r_user_t RUSER_VALUE = '0
) (
    axi5_lite_if.sink   axi,
    handshake_if.source reg_req,
    handshake_if.sink   reg_resp
);

  localparam int unsigned StrbWidth = DATA_WIDTH / 8;
  localparam axi5_pkg::size_e FullSize = axi5_pkg::size_e'($clog2(StrbWidth));
  localparam int unsigned WriteIdWidth = $bits(axi.AWID);
  localparam int unsigned ReadIdWidth = $bits(axi.ARID);
  localparam int unsigned IdWidth = WriteIdWidth > ReadIdWidth ? WriteIdWidth : ReadIdWidth;

  typedef `AMBA_AXI5_LITE_AW_TYPE(axi, req_user_t) aw_t;
  typedef `AMBA_AXI5_LITE_W_TYPE(axi, data_user_t) w_t;
  typedef `AMBA_AXI5_LITE_AR_TYPE(axi, req_user_t) ar_t;
  typedef `AMBA_AXI5_LITE_B_TYPE(axi, resp_user_t) b_t;
  typedef `AMBA_AXI5_LITE_R_TYPE(axi, r_user_t) r_t;

  typedef struct packed {
    logic write;
    logic [IdWidth - 1:0] id;
    logic idunq;
    logic trace;
    logic local_error;
  } meta_t;

  typedef struct packed {
    req_t  req;
    meta_t meta;
  } cmd_t;

  aw_t aw_in, aw_r;
  w_t w_in, w_r;
  ar_t ar_in, ar_r;
  cmd_t cmd_d, cmd_r;
  meta_t owner_r;
  resp_t response;
  b_t b_in, b_out;
  r_t r_in, r_out;
  strb_t write_lanes;
  axi5_pkg::prot_t access_prot, prot_mask, prot_value;
  axi5_pkg::max_subsystem_id_t access_subsys_id;

  logic aw_valid_d, aw_valid_r, aw_push, aw_pop;
  logic w_valid_d, w_valid_r, w_push, w_pop;
  logic ar_valid_d, ar_valid_r, ar_push, ar_pop;
  logic write_valid, select_write, prefer_write_r;
  logic size_error, prot_error, subsys_error;
  logic cmd_valid_d, cmd_valid_r, cmd_ready, cmd_push, cmd_pop;
  logic owner_valid_d, owner_valid_r, owner_ready;
  logic issue_fire, reject_fire, response_fire;
  logic response_valid, response_ready, response_error;

  handshake_if #(.payload_t(b_t)) b_req ();
  handshake_if #(.payload_t(b_t)) b_resp ();
  handshake_if #(.payload_t(r_t)) r_req ();
  handshake_if #(.payload_t(r_t)) r_resp ();

  always_comb begin
    aw_in = '{
        addr: axi.AWADDR,
        prot: axi.OI_EN_PROT ? axi.AWPROT : '0,
        size: axi.O_EN_SIZE ? axi.AWSIZE : FullSize,
        id: axi.ID_W_WIDTH > 0 ? WriteIdWidth'(axi.AWID) : '0,
        idunq: axi.OO_EN_IDUNQ && axi.AWIDUNQ,
        trace: axi.C_EN_TRACE && axi.AWTRACE,
        subsys_id: axi.SUBSYSID_WIDTH > 0 ? axi.AWSUBSYSID : '0,
        default: '0
    };
    w_in = '{data: axi.WDATA, strb: axi.O_EN_STRB ? axi.WSTRB : '1, default: '0};
    ar_in = '{
        addr: axi.ARADDR,
        prot: axi.OI_EN_PROT ? axi.ARPROT : '0,
        size: axi.O_EN_SIZE ? axi.ARSIZE : FullSize,
        id: axi.ID_R_WIDTH > 0 ? ReadIdWidth'(axi.ARID) : '0,
        idunq: axi.OO_EN_IDUNQ && axi.ARIDUNQ,
        trace: axi.C_EN_TRACE && axi.ARTRACE,
        subsys_id: axi.SUBSYSID_WIDTH > 0 ? axi.ARSUBSYSID : '0,
        default: '0
    };

    aw_pop = cmd_push && select_write;
    w_pop = aw_pop;
    ar_pop = cmd_push && !select_write;
    axi.AWREADY = axi.ARESETn && (!aw_valid_r || aw_pop);
    axi.WREADY = axi.ARESETn && (!w_valid_r || w_pop);
    axi.ARREADY = axi.ARESETn && (!ar_valid_r || ar_pop);
    aw_push = axi.AWVALID && axi.AWREADY;
    w_push = axi.WVALID && axi.WREADY;
    ar_push = axi.ARVALID && axi.ARREADY;
    aw_valid_d = (aw_valid_r && !aw_pop) || aw_push;
    w_valid_d = (w_valid_r && !w_pop) || w_push;
    ar_valid_d = (ar_valid_r && !ar_pop) || ar_push;
  end

  `REG_ARSTN(aw_valid_r, aw_valid_d, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_ARSTN(w_valid_r, w_valid_d, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_ARSTN(ar_valid_r, ar_valid_d, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(aw_r, aw_in, aw_push, axi.ACLK)
  `REG_CE(w_r, w_in, w_push, axi.ACLK)
  `REG_CE(ar_r, ar_in, ar_push, axi.ACLK)

  always_comb begin
    write_valid = aw_valid_r && w_valid_r;
    select_write = write_valid && (!ar_valid_r || prefer_write_r);
    cmd_ready = !cmd_valid_r || cmd_pop;
    cmd_push = axi.ARESETn && cmd_ready && (write_valid || ar_valid_r);
    cmd_valid_d = (cmd_valid_r && !cmd_pop) || cmd_push;

    write_lanes = axi.O_EN_SIZE ?
        strb_t'(axi5_pkg::lite_byte_lanes(64'(aw_r.addr), aw_r.size, DATA_WIDTH)) : '1;
    access_prot = select_write ? aw_r.prot : ar_r.prot;
    prot_mask = select_write ? WRITE_PROT_MASK : READ_PROT_MASK;
    prot_value = select_write ? WRITE_PROT_VALUE : READ_PROT_VALUE;
    prot_error = (|prot_mask) &&
        (!axi.OI_EN_PROT || (access_prot & prot_mask) != (prot_value & prot_mask));
    access_subsys_id = select_write ? 8'(aw_r.subsys_id) : 8'(ar_r.subsys_id);
    subsys_error = (|(SUBSYSID_MASK >> axi.SUBSYSID_WIDTH)) ||
        (access_subsys_id & SUBSYSID_MASK) != (SUBSYSID_VALUE & SUBSYSID_MASK);
    cmd_d.req = '{
        addr: (select_write ? aw_r.addr : ar_r.addr) & ~addr_t'(StrbWidth - 1),
        write: select_write,
        data: select_write ? w_r.data : '0,
        strb: select_write ? w_r.strb & write_lanes : '0
    };
    cmd_d.meta = '{
        write: select_write,
        id: select_write ? IdWidth'(aw_r.id) : IdWidth'(ar_r.id),
        idunq: select_write ? aw_r.idunq : ar_r.idunq,
        trace: select_write ? aw_r.trace : ar_r.trace,
        local_error: size_error || prot_error || subsys_error
    };
  end

  if (axi.O_EN_SIZE && DATA_WIDTH < axi5_pkg::LiteMaxDataWidth) begin : gen_size_check
    assign size_error = (select_write ? aw_r.size : ar_r.size) > FullSize;
  end else begin : gen_no_size_check
    assign size_error = 1'b0;
  end

  `REG_ARSTN(cmd_valid_r, cmd_valid_d, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(cmd_r, cmd_d, cmd_push, axi.ACLK)
  `REG_CE_ARSTN(prefer_write_r, !select_write, cmd_push, 1'b0, axi.ACLK, axi.ARESETn)

  always_comb begin
    owner_ready = !owner_valid_r || response_fire;
    reg_req.valid = axi.ARESETn && cmd_valid_r && !cmd_r.meta.local_error && owner_ready;
    reg_req.payload = cmd_r.req;
    issue_fire = reg_req.valid && reg_req.ready;
    reject_fire = axi.ARESETn && cmd_valid_r && cmd_r.meta.local_error && owner_ready;
    cmd_pop = issue_fire || reject_fire;
    owner_valid_d = (owner_valid_r && !response_fire) || cmd_pop;
  end

  `REG_ARSTN(owner_valid_r, owner_valid_d, 1'b0, axi.ACLK, axi.ARESETn)
  `REG_CE(owner_r, cmd_r.meta, cmd_pop, axi.ACLK)

  always_comb begin
    response = resp_t'(reg_resp.payload);
    response_valid = axi.ARESETn && owner_valid_r && (owner_r.local_error || reg_resp.valid);
    response_ready = owner_r.write ? b_req.ready : r_req.ready;
    response_fire = response_valid && response_ready;
    response_error = owner_r.local_error || response.error;
    reg_resp.ready = axi.ARESETn && owner_valid_r && !owner_r.local_error && response_ready;

    b_in = '{
        resp: response_error ? axi5_pkg::BRESP_SLVERR : axi5_pkg::BRESP_OKAY,
        id: WriteIdWidth'(owner_r.id),
        idunq: owner_r.idunq,
        trace: owner_r.trace,
        user: axi.O_EN_USER ? BUSER_VALUE : resp_user_t'('0),
        default: '0
    };
    r_in = '{
        data: owner_r.local_error ? '0 : response.data,
        resp: response_error ? axi5_pkg::RRESP_SLVERR : axi5_pkg::RRESP_OKAY,
        id: ReadIdWidth'(owner_r.id),
        idunq: owner_r.idunq,
        trace: owner_r.trace,
        user: axi.O_EN_USER ? RUSER_VALUE : r_user_t'('0),
        default: '0
    };
    b_req.valid = response_valid && owner_r.write;
    b_req.payload = b_in;
    r_req.valid = response_valid && !owner_r.write;
    r_req.payload = r_in;
  end

  skid_buffer #(
      .payload_t(b_t)
  ) i_b_skid (
      .clk_i(axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in(b_req),
      .out(b_resp)
  );

  skid_buffer #(
      .payload_t(r_t)
  ) i_r_skid (
      .clk_i(axi.ACLK),
      .rst_n_i(axi.ARESETn),
      .in(r_req),
      .out(r_resp)
  );

  always_comb begin
    b_out = b_resp.payload;
    r_out = r_resp.payload;
    `AMBA_AXI5_LITE_UNPACK_B(axi, b_out)
    `AMBA_AXI5_LITE_UNPACK_R(axi, r_out)
    axi.BVALID   = b_resp.valid;
    axi.RVALID   = r_resp.valid;
    b_resp.ready = axi.BREADY;
    r_resp.ready = axi.RREADY;
  end

  `ASSERT_INIT(WidthsValid, axi5_pkg::lite_widths_valid(ADDR_WIDTH, DATA_WIDTH))
  `ASSERT_INIT(WriteAddressWidthMatch, ADDR_WIDTH == $bits(axi.AWADDR))
  `ASSERT_INIT(ReadAddressWidthMatch, ADDR_WIDTH == $bits(axi.ARADDR))
  `ASSERT_INIT(WriteDataWidthMatch, DATA_WIDTH == $bits(axi.WDATA))
  `ASSERT_INIT(ReadDataWidthMatch, DATA_WIDTH == $bits(axi.RDATA))
  `ASSERT_INIT(StrobeWidthMatch, StrbWidth == $bits(axi.WSTRB))
  `ASSERT_INIT(WriteIdWidthMatch, WriteIdWidth == $bits(axi.BID))
  `ASSERT_INIT(ReadIdWidthMatch, ReadIdWidth == $bits(axi.RID))
  `ASSERT_INIT(RequestUserWidthMatch, $bits(req_user_t) == $bits(axi.AWUSER) && $bits(req_user_t)
               == $bits(axi.ARUSER))
  `ASSERT_INIT(DataUserWidthMatch, $bits(data_user_t) == $bits(axi.WUSER) && $bits(data_user_t)
               == $bits(axi.RUSER.data))
  `ASSERT_INIT(ResponseUserWidthMatch, $bits(resp_user_t) == $bits(axi.BUSER) && $bits(resp_user_t)
               == $bits(axi.RUSER.resp))
  `ASSERT_INIT(RequestPayloadWidth, $bits(reg_req.payload) == $bits(req_t))
  `ASSERT_INIT(ResponsePayloadWidth, $bits(reg_resp.payload) == $bits(resp_t))
  `ASSERT_INIT(ProtFilterRequiresProt, (READ_PROT_MASK | WRITE_PROT_MASK) == '0 || axi.OI_EN_PROT)
  `ASSERT_INIT(SubsysFilterWidth, (SUBSYSID_MASK >> axi.SUBSYSID_WIDTH) == '0)
  `ASSERT_INIT(PolicyKnown, !$isunknown({READ_PROT_MASK, READ_PROT_VALUE, WRITE_PROT_MASK,
                                         WRITE_PROT_VALUE, SUBSYSID_MASK, SUBSYSID_VALUE,
                                         BUSER_VALUE, RUSER_VALUE}))

  `ASSERT(RequestStable, reg_req.valid && !reg_req.ready |=> reg_req.valid && $stable
                         (reg_req.payload), axi.ACLK, axi.ARESETn)
  `ASSERT(OwnerStable, owner_valid_r && !response_fire |=> owner_valid_r && $stable(owner_r),
          axi.ACLK, axi.ARESETn)
  `ASSERT(ResponseHasOwner, reg_resp.valid |-> owner_valid_r && !owner_r.local_error, axi.ACLK,
          axi.ARESETn)
  `ASSERT(BackendResponseStable, reg_resp.valid && !reg_resp.ready |=> reg_resp.valid && $stable
                                 (reg_resp.payload), axi.ACLK, axi.ARESETn)
  `ASSERT_KNOWN_IF(RequestKnown, reg_req.payload, reg_req.valid, axi.ACLK, axi.ARESETn)
  `ASSERT_KNOWN_IF(ResponseKnown, reg_resp.payload, reg_resp.valid, axi.ACLK, axi.ARESETn)
  `ASSERT(BStable, axi.BVALID && !axi.BREADY |=> axi.BVALID && $stable(b_out), axi.ACLK,
          axi.ARESETn)
  `ASSERT(RStable, axi.RVALID && !axi.RREADY |=> axi.RVALID && $stable(r_out), axi.ACLK,
          axi.ARESETn)

endmodule

// spyglass enable_block W240,W528
