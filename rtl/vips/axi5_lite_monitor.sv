`include "cc/assertions.svh"
`include "amba/axi5_lite.svh"

module axi5_lite_monitor #(
    parameter  type req_user_t  = logic,
    parameter  type data_user_t = logic,
    parameter  type resp_user_t = logic,
    localparam type r_user_t    = `AMBA_AXI5_LITE_R_USER_TYPE(data_user_t, resp_user_t)
) (
    axi5_lite_if.monitor axi
);
  typedef `AMBA_AXI5_LITE_AW_TYPE(axi, req_user_t) aw_t;
  typedef `AMBA_AXI5_LITE_W_TYPE(axi, data_user_t) w_t;
  typedef `AMBA_AXI5_LITE_B_TYPE(axi, resp_user_t) b_t;
  typedef `AMBA_AXI5_LITE_AR_TYPE(axi, req_user_t) ar_t;
  typedef `AMBA_AXI5_LITE_R_TYPE(axi, r_user_t) r_t;
  typedef axi5_verify_pkg::lite_types#(
      .ADDR_WIDTH($bits(axi.AWADDR)),
      .DATA_WIDTH($bits(axi.WDATA))
  ) types_t;
  typedef struct packed {
    aw_t aw;
    w_t  w;
  } write_t;

  aw_t aw, aw_checked, last_aw;
  w_t w, w_checked, last_w;
  b_t b, b_checked, last_b;
  ar_t ar, ar_checked, last_ar;
  r_t r, r_checked, last_r;
  aw_t aw_pending[$];
  w_t w_pending[$];
  write_t writes_pending[$];
  ar_t reads_pending[$];
  logic [10:0] controls;
  bit in_reset = 1'b0;
  longint unsigned resets = 0;

  axi5_verify_pkg::channel_coverage #(aw_t) aw_coverage = new;
  axi5_verify_pkg::channel_coverage #(w_t) w_coverage = new;
  axi5_verify_pkg::channel_coverage #(b_t) b_coverage = new;
  axi5_verify_pkg::channel_coverage #(ar_t) ar_coverage = new;
  axi5_verify_pkg::channel_coverage #(r_t) r_coverage = new;
  axi5_verify_pkg::channel_coverage #(logic [10:0]) control_coverage = new;

  always_comb begin
    `AMBA_AXI5_LITE_PACK_AW(aw, axi)
    `AMBA_AXI5_LITE_PACK_W(w, axi)
    `AMBA_AXI5_LITE_PACK_B(b, axi)
    `AMBA_AXI5_LITE_PACK_AR(ar, axi)
    `AMBA_AXI5_LITE_PACK_R(r, axi)
    controls = {
      axi.O_EN_WAKEUP && axi.AWAKEUP,
      axi.AWVALID,
      axi.AWREADY,
      axi.WVALID,
      axi.WREADY,
      axi.BVALID,
      axi.BREADY,
      axi.ARVALID,
      axi.ARREADY,
      axi.RVALID,
      axi.RREADY
    };

    aw_checked = aw;
    w_checked = w;
    b_checked = b;
    ar_checked = ar;
    r_checked = r;
    if (!axi.OI_EN_PROT) begin
      aw_checked.prot = '0;
      ar_checked.prot = '0;
    end
    if (!axi.O_EN_SIZE) begin
      aw_checked.size = axi5_pkg::SIZE_1B;
      ar_checked.size = axi5_pkg::SIZE_1B;
    end
    if (axi.ID_W_WIDTH == 0) begin
      aw_checked.id = '0;
      b_checked.id  = '0;
    end
    if (axi.ID_R_WIDTH == 0) begin
      ar_checked.id = '0;
      r_checked.id  = '0;
    end
    if (!axi.OO_EN_IDUNQ) begin
      aw_checked.idunq = 1'b0;
      b_checked.idunq  = 1'b0;
      ar_checked.idunq = 1'b0;
      r_checked.idunq  = 1'b0;
    end
    if (!axi.O_EN_USER) begin
      aw_checked.user = '0;
      w_checked.user  = '0;
      b_checked.user  = '0;
      ar_checked.user = '0;
      r_checked.user  = '0;
    end
    if (!axi.C_EN_TRACE) begin
      aw_checked.trace = 1'b0;
      w_checked.trace  = 1'b0;
      b_checked.trace  = 1'b0;
      ar_checked.trace = 1'b0;
      r_checked.trace  = 1'b0;
    end
    if (axi.SUBSYSID_WIDTH == 0) begin
      aw_checked.subsys_id = '0;
      ar_checked.subsys_id = '0;
    end
    if (!axi.O_EN_STRB) w_checked.strb = '1;
  end

  function automatic void check_idle();
    df_verify_pkg::check(
        aw_pending.size() == 0 && w_pending.size() == 0 &&
                         writes_pending.size() == 0 && reads_pending.size() == 0,
        "AXI-Lite has outstanding channel transfers");
    df_verify_pkg::check({axi.AWVALID, axi.WVALID, axi.ARVALID, axi.BVALID, axi.RVALID} === '0,
                         "AXI-Lite has pending valid signals");
  endfunction

  function automatic void check_write_response();
    int match_index;
    match_index = -1;
    foreach (writes_pending[i]) begin
      if (match_index < 0 && writes_pending[i].aw.id === b_checked.id) match_index = i;
    end
    df_verify_pkg::check(match_index >= 0, "B response has no accepted AW/W with matching ID");
    df_verify_pkg::check(!b_checked.idunq || writes_pending[match_index].aw.idunq,
                         "BIDUNQ asserted for a non-unique request");
    if (axi.BREADY) begin
      writes_pending.delete(match_index);
      last_b = b;
    end
  endfunction

  function automatic void check_read_response();
    int match_index;
    match_index = -1;
    foreach (reads_pending[i]) begin
      if (match_index < 0 && reads_pending[i].id === r_checked.id) match_index = i;
    end
    df_verify_pkg::check(match_index >= 0, "R response has no accepted AR with matching ID");
    df_verify_pkg::check(!r_checked.idunq || reads_pending[match_index].idunq,
                         "RIDUNQ asserted for a non-unique request");
    if (axi.RREADY) begin
      reads_pending.delete(match_index);
      last_r = r;
    end
  endfunction

  function automatic void accept_aw();
    foreach (aw_pending[i])
    if (aw_checked.id === aw_pending[i].id)
      df_verify_pkg::check(!(aw_checked.idunq || aw_pending[i].idunq),
                           "AW reused an outstanding unique ID");
    foreach (writes_pending[i])
    if (aw_checked.id === writes_pending[i].aw.id)
      df_verify_pkg::check(!(aw_checked.idunq || writes_pending[i].aw.idunq),
                           "AW reused an outstanding unique ID");
    aw_pending.push_back(aw_checked);
    last_aw = aw;
  endfunction

  function automatic void accept_ar();
    foreach (reads_pending[i])
    if (ar_checked.id === reads_pending[i].id)
      df_verify_pkg::check(!(ar_checked.idunq || reads_pending[i].idunq),
                           "AR reused an outstanding unique ID");
    reads_pending.push_back(ar_checked);
    last_ar = ar;
  endfunction

  always @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      if (!in_reset) resets++;
      in_reset = 1'b1;
      aw_pending.delete();
      w_pending.delete();
      writes_pending.delete();
      reads_pending.delete();
      last_aw = 'x;
      last_w  = 'x;
      last_b  = 'x;
      last_ar = 'x;
      last_r  = 'x;
    end else begin
      write_t request;
      in_reset = 1'b0;
      aw_coverage.sample(axi.AWVALID, axi.AWREADY, aw);
      w_coverage.sample(axi.WVALID, axi.WREADY, w);
      b_coverage.sample(axi.BVALID, axi.BREADY, b);
      ar_coverage.sample(axi.ARVALID, axi.ARREADY, ar);
      r_coverage.sample(axi.RVALID, axi.RREADY, r);
      control_coverage.sample(1'b1, 1'b1, controls);
      // Responses must match requests accepted before this edge.
      if (axi.BVALID) check_write_response();
      if (axi.RVALID) check_read_response();
      if (axi.AWVALID && axi.AWREADY) accept_aw();
      if (axi.WVALID && axi.WREADY) begin
        w_pending.push_back(w_checked);
        last_w = w;
      end
      if (axi.ARVALID && axi.ARREADY) accept_ar();
      if (aw_pending.size() != 0 && w_pending.size() != 0) begin
        request.aw = aw_pending.pop_front();
        request.w  = w_pending.pop_front();
        if (axi.O_EN_SIZE && axi.O_EN_STRB)
          df_verify_pkg::check((request.w.strb & ~types_t::byte_lanes(
                               request.aw.addr, request.aw.size)) === '0,
                               "WSTRB exceeds the addressed transfer lanes");
        writes_pending.push_back(request);
      end
    end
  end

  initial begin
    df_verify_pkg::check($bits(axi.AWUSER) == $bits(req_user_t) && $bits(axi.ARUSER) == $bits(
                         req_user_t) && $bits(axi.WUSER) == $bits(data_user_t) && $bits(axi.BUSER
                         ) == $bits(resp_user_t) && $bits(axi.RUSER) == $bits(r_user_t),
                         "Monitor USER type width mismatch");
    df_verify_pkg::check($bits(axi.AWID) == $bits(axi.BID) && $bits(axi.ARID) == $bits(axi.RID),
                         "Monitor response ID width mismatch");
  end

  always @(posedge axi.ACLK) begin
    `ASSERT_I(ResetKnown, !$isunknown(axi.ARESETn))
    if (axi.ARESETn === 1'b0) begin
      `ASSERT_I(ResetValids, {axi.AWVALID, axi.WVALID, axi.ARVALID, axi.BVALID, axi.RVALID} === '0)
    end
  end

  `ASSERT_KNOWN(ControlsKnown, controls, axi.ACLK, axi.ARESETn)
  `ASSERT(AwStable, axi.AWVALID && !axi.AWREADY |=> axi.AWVALID && $stable(aw_checked), axi.ACLK,
          axi.ARESETn)
  `ASSERT(WStable, axi.WVALID && !axi.WREADY |=> axi.WVALID && $stable(w_checked), axi.ACLK,
          axi.ARESETn)
  `ASSERT(BStable, axi.BVALID && !axi.BREADY |=> axi.BVALID && $stable(b_checked), axi.ACLK,
          axi.ARESETn)
  `ASSERT(ArStable, axi.ARVALID && !axi.ARREADY |=> axi.ARVALID && $stable(ar_checked), axi.ACLK,
          axi.ARESETn)
  `ASSERT(RStable, axi.RVALID && !axi.RREADY |=> axi.RVALID && $stable(r_checked), axi.ACLK,
          axi.ARESETn)
  `ASSERT_KNOWN_IF(AwKnown, aw_checked, axi.AWVALID, axi.ACLK, axi.ARESETn)
  `ASSERT_KNOWN_IF(WKnown, w_checked, axi.WVALID, axi.ACLK, axi.ARESETn)
  `ASSERT_KNOWN_IF(BKnown, b_checked, axi.BVALID, axi.ACLK, axi.ARESETn)
  `ASSERT_KNOWN_IF(ArKnown, ar_checked, axi.ARVALID, axi.ACLK, axi.ARESETn)
  `ASSERT_KNOWN_IF(RKnown, r_checked, axi.RVALID, axi.ACLK, axi.ARESETn)
  `ASSERT(AwSize, axi.O_EN_SIZE && axi.AWVALID |-> int'(axi.AWSIZE) <= $clog2($bits(axi.WDATA) / 8),
          axi.ACLK, axi.ARESETn)
  `ASSERT(ArSize, axi.O_EN_SIZE && axi.ARVALID |-> int'(axi.ARSIZE) <= $clog2($bits(axi.RDATA) / 8),
          axi.ACLK, axi.ARESETn)
  `ASSERT(AwWakeup, axi.O_EN_WAKEUP && axi.AWAKEUP && axi.AWVALID && !axi.AWREADY |=> axi.AWAKEUP,
          axi.ACLK, axi.ARESETn)
  `ASSERT(ArWakeup, axi.O_EN_WAKEUP && axi.AWAKEUP && axi.ARVALID && !axi.ARREADY |=> axi.AWAKEUP,
          axi.ACLK, axi.ARESETn)
endmodule
