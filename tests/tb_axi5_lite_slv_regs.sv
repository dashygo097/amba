`include "amba/axi5_lite.svh"

module tb_axi5_lite_slv_regs #(
    parameter int unsigned RANDOM_TRANSACTIONS = 200,
    parameter bit ENABLE_STRB = 1'b1,
    parameter bit ENABLE_SIDEBANDS = 1'b1
) ();
  timeunit 1ns; timeprecision 1ps;

  localparam int unsigned AddrWidth = 32;
  localparam int unsigned DataWidth = 32;
  localparam int unsigned NumRegs   = 5;
  typedef axi5_verify_pkg::lite_types#(
      .ADDR_WIDTH    (AddrWidth),
      .DATA_WIDTH    (DataWidth),
      .ID_W_WIDTH    (ENABLE_SIDEBANDS ? 5 : 0),
      .ID_R_WIDTH    (ENABLE_SIDEBANDS ? 3 : 0),
      .SUBSYSID_WIDTH(ENABLE_SIDEBANDS ? 4 : 0),
      .req_user_t    (logic [6:0]),
      .data_user_t   (logic [8:0]),
      .resp_user_t   (logic [3:0])
  ) types_t;
  typedef types_t::addr_t addr_t;
  typedef types_t::data_t data_t;
  typedef types_t::strb_t strb_t;
  typedef logic [6:0] req_user_t;
  typedef logic [8:0] data_user_t;
  typedef logic [3:0] resp_user_t;
  typedef struct packed {
    data_user_t data;
    resp_user_t resp;
  } r_user_t;

  typedef enum {
    RESET_AFTER_AW,
    RESET_AFTER_W,
    RESET_WITH_B,
    RESET_WITH_R
  } reset_scenario_e;

  localparam addr_t BaseAddr = 'h100;
  localparam addr_t [NumRegs-1:0] OffsetCfg = '{0: 'h00, 1: 'h04, 2: 'h08, 3: 'h0c, 4: 'h10};
  localparam data_t [NumRegs-1:0] ResetCfg = '{
      0: 'h11223344,
      1: 'ha500ff5a,
      2: 'h89abcdef,
      3: '0,
      4: 'hcafebabe
  };
  localparam data_t [NumRegs-1:0] ReadCfg = '{0: '1, 1: '1, 2: 'h00ff00ff, 3: '0, 4: '1};
  localparam data_t [NumRegs-1:0] RwCfg = '{0: '1, 1: 'hff, 3: '1, default: '0};
  localparam data_t [NumRegs-1:0] W1cCfg = '{1: 'h0000ff00, default: '0};
  localparam data_t [NumRegs-1:0] W1sCfg = '{1: 'h00ff0000, default: '0};
  localparam data_t [NumRegs-1:0] RcCfg = '{2: 'hff, default: '0};

  logic clk_i = 1'b0;
  logic rst_n_i;
  axi5_lite_if #(
      .ADDR_WIDTH(AddrWidth),
      .DATA_WIDTH(DataWidth),
      .O_EN_STRB(ENABLE_STRB),
      .OI_EN_PROT(ENABLE_SIDEBANDS),
      .OO_EN_ID(ENABLE_SIDEBANDS),
      .ID_W_WIDTH(ENABLE_SIDEBANDS ? 5 : 0),
      .ID_R_WIDTH(ENABLE_SIDEBANDS ? 3 : 0),
      .OO_EN_IDUNQ(ENABLE_SIDEBANDS),
      .O_EN_USER(ENABLE_SIDEBANDS),
      .O_EN_WAKEUP(ENABLE_SIDEBANDS),
      .SUBSYSID_WIDTH(ENABLE_SIDEBANDS ? 4 : 0),
      .req_user_t(req_user_t),
      .data_user_t(data_user_t),
      .resp_user_t(resp_user_t)
  ) axi (
      .ACLK(clk_i),
      .ARESETn(rst_n_i)
  );
  axi5_lite_vip #(
      .ADDR_WIDTH (AddrWidth),
      .DATA_WIDTH (DataWidth),
      .req_user_t (req_user_t),
      .data_user_t(data_user_t),
      .resp_user_t(resp_user_t)
  ) driver (
      .axi(axi)
  );
  axi5_lite_slv_regs #(
      .ADDR_WIDTH(AddrWidth),
      .DATA_WIDTH(DataWidth),
      .NUM_REGS(NumRegs),
      .BASE_ADDR(BaseAddr),
      .OFFSET_CFG(OffsetCfg),
      .RESET_CFG(ResetCfg),
      .READ_CFG(ReadCfg),
      .RW_CFG(RwCfg),
      .W1C_CFG(W1cCfg),
      .W1S_CFG(W1sCfg),
      .RC_CFG(RcCfg),
      .req_user_t(req_user_t),
      .data_user_t(data_user_t),
      .resp_user_t(resp_user_t)
  ) dut (
      .axi(axi)
  );

  typedef types_t::aw_t aw_t;
  typedef types_t::w_t write_data_t;
  typedef types_t::b_t b_t;
  typedef types_t::ar_t ar_t;
  typedef types_t::r_t read_response_t;
  aw_t aw_payload, write_address;
  write_data_t w_payload;
  b_t b_payload;
  ar_t ar_payload;
  read_response_t r_payload;

  always_comb begin
    `AMBA_AXI5_LITE_PACK_AW(aw_payload, axi)
    `AMBA_AXI5_LITE_PACK_W(w_payload, axi)
    `AMBA_AXI5_LITE_PACK_B(b_payload, axi)
    `AMBA_AXI5_LITE_PACK_AR(ar_payload, axi)
    `AMBA_AXI5_LITE_PACK_R(r_payload, axi)
  end

  df_verify_pkg::ordered_scoreboard #(b_t) writes = new("AXI write responses");
  df_verify_pkg::ordered_scoreboard #(read_response_t) reads = new("AXI read responses");
  data_t model_regs[NumRegs];
  write_data_t write_data;
  bit have_aw, have_w;
  longint unsigned cycle_count = 0;
  longint unsigned aw_cycle, w_cycle;
  int unsigned aw_first = 0, w_first = 0, together = 0;
  int unsigned b_stalls = 0, r_stalls = 0;

  always #5ns clk_i = ~clk_i;

  function automatic int register_index(input addr_t addr);
    addr_t aligned;
    aligned = addr - addr % addr_t'(DataWidth / 8);
    foreach (model_regs[i]) begin
      if (aligned == BaseAddr + OffsetCfg[i]) return i;
    end
    return -1;
  endfunction

  function automatic axi5_pkg::bresp_e model_write(input addr_t addr, input write_data_t item);
    int index;
    index = register_index(addr);
    if (index < 0) return axi5_pkg::BRESP_SLVERR;
    for (int unsigned b = 0; b < DataWidth; b++) begin
      if (ENABLE_STRB && !item.strb[b/8]) continue;
      if (RwCfg[index][b]) model_regs[index][b] = item.data[b];
      if (W1cCfg[index][b] && item.data[b]) model_regs[index][b] = 1'b0;
      if (W1sCfg[index][b] && item.data[b]) model_regs[index][b] = 1'b1;
    end
    return axi5_pkg::BRESP_OKAY;
  endfunction

  function automatic read_response_t model_read(input ar_t request);
    int index;
    read_response_t result;
    index  = register_index(request.addr);
    result = '{resp: axi5_pkg::RRESP_SLVERR, id: request.id, idunq: request.idunq, default: '0};
    if (index < 0) return result;
    result.resp = axi5_pkg::RRESP_OKAY;
    for (int unsigned b = 0; b < DataWidth; b++) begin
      if (ReadCfg[index][b]) result.data[b] = model_regs[index][b];
      if (RcCfg[index][b]) model_regs[index][b] = 1'b0;
    end
    return result;
  endfunction

  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      have_aw = 1'b0;
      have_w  = 1'b0;
      writes.clear();
      reads.clear();
      foreach (model_regs[i]) model_regs[i] = ResetCfg[i];
    end else begin
      cycle_count++;
      if (axi.BVALID && axi.BREADY) writes.check_actual(b_payload);
      if (axi.RVALID && axi.RREADY) reads.check_actual(r_payload);
      if (axi.BVALID && !axi.BREADY) b_stalls++;
      if (axi.RVALID && !axi.RREADY) r_stalls++;

      if (axi.AWVALID && axi.AWREADY) begin
        df_verify_pkg::check(!have_aw, "Unexpected second outstanding AW");
        have_aw = 1'b1;
        write_address = aw_payload;
        aw_cycle = cycle_count;
      end
      if (axi.WVALID && axi.WREADY) begin
        df_verify_pkg::check(!have_w, "Unexpected second outstanding W");
        have_w = 1'b1;
        write_data = w_payload;
        w_cycle = cycle_count;
      end
      if (have_aw && have_w) begin
        writes.push_expected('{resp: model_write(write_address.addr, write_data),
                             id: write_address.id, idunq: write_address.idunq, default: '0});
        if (aw_cycle < w_cycle) aw_first++;
        else if (w_cycle < aw_cycle) w_first++;
        else together++;
        have_aw = 1'b0;
        have_w  = 1'b0;
      end
      if (axi.ARVALID && axi.ARREADY) reads.push_expected(model_read(ar_payload));
    end
  end

  task automatic reset_dut();
    @(negedge clk_i);
    rst_n_i = 1'b0;
    #1ns;
    df_verify_pkg::check({axi.BVALID, axi.RVALID} === 2'b00,
                         "Reset must discard pending responses");
    repeat (3) @(posedge clk_i);
    @(negedge clk_i);
    driver.init();
    rst_n_i = 1'b1;
  endtask

  task automatic expect_read(input addr_t addr, input data_t expected,
                             input axi5_pkg::rresp_e expected_resp = axi5_pkg::RRESP_OKAY,
                             input int unsigned r_stall = 0);
    data_t data;
    axi5_pkg::rresp_e resp;
    driver.read(.addr(addr), .data(data), .resp(resp), .r_stall(r_stall));
    df_verify_pkg::check(driver.get_status() == axi5_verify_pkg::LITE_COMPLETED,
                         "Directed read did not complete");
    df_verify_pkg::value_check#(data_t)::equal(data, expected, $sformatf("Read data at %h", addr));
    df_verify_pkg::value_check#(axi5_pkg::rresp_e)::equal(resp, expected_resp, $sformatf(
                                                          "Read response at %h", addr));
  endtask

  task automatic reset_pending(input reset_scenario_e scenario);
    axi5_pkg::bresp_e bresp;
    axi5_pkg::rresp_e rresp;
    data_t data;
    reset_dut();
    fork
      begin
        if (scenario == RESET_WITH_R)
          driver.read(.addr('h108), .data(data), .resp(rresp), .r_stall(64), .allow_reset(1'b1));
        else
          driver.write(
              .addr('h100), .data('1), .resp(bresp), .aw_delay(scenario == RESET_AFTER_W ? 64 : 0),
              .w_delay(scenario == RESET_AFTER_AW ? 64 : 0), .b_stall(64), .allow_reset(1'b1));
      end
      begin
        bit reached;
        reached = 1'b0;
        for (int unsigned cycle = 0; cycle < 32; cycle++) begin
          @(posedge clk_i);
          case (scenario)
            RESET_AFTER_AW: reached = axi.AWVALID && axi.AWREADY;
            RESET_AFTER_W: reached = axi.WVALID && axi.WREADY;
            RESET_WITH_B: reached = axi.BVALID && !axi.BREADY;
            RESET_WITH_R: reached = axi.RVALID && !axi.RREADY;
            default: $fatal(1, "Unknown reset scenario");
          endcase
          if (reached) break;
        end
        df_verify_pkg::check(reached, "Reset scenario did not reach the intended channel state");
        df_verify_pkg::check(driver.get_status() == axi5_verify_pkg::LITE_ACTIVE,
                             "Pending transfer must report active status");
        reset_dut();
      end
    join
    df_verify_pkg::check(driver.get_status() == axi5_verify_pkg::LITE_RESET,
                         "In-flight operation did not report reset cancellation");
    driver.check_idle();
    expect_read('h100, 'h11223344);
    expect_read('h104, 'ha500ff5a);
    expect_read('h108, 'h00ab00ef);
  endtask

  task automatic test_reset_values();
    reset_dut();
    expect_read('h100, 'h11223344);
    expect_read('h104, 'ha500ff5a);
    expect_read('h108, 'h00ab00ef, .r_stall(5));
    expect_read('h108, 'h00ab0000);
    expect_read('h10c, '0);
    expect_read('h110, 'hcafebabe);
  endtask

  task automatic test_write_ordering();
    axi5_pkg::bresp_e bresp;
    reset_dut();
    driver.write(.addr('h100), .data('h1234abcd), .strb(4'b0011), .aw_delay(4), .w_delay(0),
                 .b_stall(3), .resp(bresp));
    df_verify_pkg::check(driver.get_status() == axi5_verify_pkg::LITE_COMPLETED,
                         "Directed write did not complete");
    df_verify_pkg::value_check#(axi5_pkg::bresp_e)::equal(bresp, axi5_pkg::BRESP_OKAY,
                                                          "Partial write response");
    expect_read('h100, ENABLE_STRB ? 'h1122abcd : 'h1234abcd);

    driver.write(.addr('h100), .data('h55667788), .strb('0), .w_delay(4), .resp(bresp));
    expect_read('h100, ENABLE_STRB ? 'h1122abcd : 'h55667788);
  endtask

  task automatic test_register_fields();
    axi5_pkg::bresp_e bresp;
    reset_dut();
    driver.write(.addr('h104), .data('h003c0f12), .resp(bresp));
    expect_read('h104, 'ha53cf012);
    driver.write(.addr('h104), .data('hffffffff), .strb(4'b0001), .resp(bresp));
    expect_read('h104, ENABLE_STRB ? 'ha53cf0ff : 'ha5ff00ff);
    driver.write(.addr('h110), .data('0), .resp(bresp));
    expect_read('h110, 'hcafebabe);
    driver.write(.addr('h10c), .data('hdeadbeef), .resp(bresp));
    expect_read('h10c, '0);
  endtask

  task automatic test_address_decode();
    axi5_pkg::bresp_e bresp;
    reset_dut();
    driver.write(.addr('h180), .data('1), .resp(bresp));
    df_verify_pkg::value_check#(axi5_pkg::bresp_e)::equal(bresp, axi5_pkg::BRESP_SLVERR,
                                                          "Unmapped write response");
    expect_read('h180, '0, axi5_pkg::RRESP_SLVERR);
    expect_read('h0fc, '0, axi5_pkg::RRESP_SLVERR);
    expect_read('h114, '0, axi5_pkg::RRESP_SLVERR);

    driver.write(.addr('h103), .data('hdeadbeef), .resp(bresp));
    for (int unsigned lane = 0; lane < 4; lane++) expect_read(addr_t'('h100 + lane), 'hdeadbeef);
  endtask

  task automatic test_random_accesses();
    axi5_pkg::bresp_e bresp;
    axi5_pkg::rresp_e rresp;
    data_t data;
    addr_t addr;
    reset_dut();
    repeat (RANDOM_TRANSACTIONS) begin
      addr = BaseAddr + OffsetCfg[$urandom_range(0, NumRegs-1)];
      case ($urandom_range(
          0, 7
      ))
        0: addr = 'h180;
        1: addr += addr_t'($urandom_range(1, 3));
        default: ;
      endcase
      if ($urandom_range(0, 1) != 0)
        driver.write(.addr(addr), .data(data_t'($urandom)), .strb(strb_t'($urandom)),
                     .aw_delay($urandom_range(0, 5)), .w_delay($urandom_range(0, 5)),
                     .b_stall($urandom_range(0, 8)), .resp(bresp));
      else
        driver.read(.addr(addr), .ar_delay($urandom_range(0, 5)), .r_stall($urandom_range(0, 8)),
                    .data(data), .resp(rresp));
    end
  endtask

  task automatic test_sidebands();
    axi5_pkg::bresp_e bresp;
    axi5_pkg::rresp_e rresp;
    data_t data;
    if (!ENABLE_SIDEBANDS) return;
    reset_dut();
    for (int unsigned i = 0; i < 8; i++) begin
      driver.write(.addr('h100), .data(data_t'(i)), .resp(bresp), .id(types_t::aw_id_t'(i * 7)),
                   .idunq(1'(i)), .prot(3'(i)), .aw_user(i[0] ? '1 : '0), .w_user(i[0] ? '1 : '0),
                   .subsys_id(i[0] ? '1 : '0), .aw_delay(i % 3), .w_delay(i % 4), .b_stall(3),
                   .wakeup_delay(1));
      driver.read(.addr('h100), .data(data), .resp(rresp), .id(types_t::ar_id_t'(i)), .idunq(1'(i)),
                  .prot(3'(i)), .ar_user(i[0] ? '1 : '0), .subsys_id(i[0] ? '1 : '0), .r_stall(3),
                  .wakeup_delay(1));
      df_verify_pkg::value_check#(data_t)::equal(data, data_t'(i), "Sideband readback");
    end
    df_verify_pkg::check(driver.monitor.aw_coverage.exercised(
                         '{
                             prot: '1,
                             size: axi5_pkg::SIZE_1B,
                             id: '1,
                             idunq: 1'b1,
                             user: '1,
                             subsys_id: '1,
                             default: '0
                         }
                         ), "AW sidebands were not exercised");
    df_verify_pkg::check(driver.monitor.ar_coverage.exercised(
                         '{
                             prot: '1,
                             size: axi5_pkg::SIZE_1B,
                             id: '1,
                             idunq: 1'b1,
                             user: '1,
                             subsys_id: '1,
                             default: '0
                         }
                         ), "AR sidebands were not exercised");
    df_verify_pkg::check(driver.monitor.w_coverage.exercised('{user: '1, default: '0}),
                         "WUSER was not exercised");
    df_verify_pkg::check(driver.monitor.b_coverage.exercised(
                         '{resp: axi5_pkg::BRESP_OKAY, id: '1, idunq: 1'b1, default: '0}
                         ) && driver.monitor.r_coverage.exercised(
                         '{resp: axi5_pkg::RRESP_OKAY, id: '1, idunq: 1'b1, default: '0}),
                         "Response IDs were not exercised");
    df_verify_pkg::check(driver.monitor.control_coverage.exercised(11'b10000000000),
                         "AWAKEUP was not exercised");
  endtask

  task automatic check_results();
    axi5_pkg::rresp_e rresp;
    data_t data;
    foreach (model_regs[i]) driver.read(.addr(BaseAddr + OffsetCfg[i]), .data(data), .resp(rresp));
    repeat (4) @(negedge clk_i);
    driver.check_idle();
    writes.check_empty();
    reads.check_empty();
    df_verify_pkg::check(!have_aw && !have_w, "Unpaired write channels at completion");
    df_verify_pkg::check(writes.comparison_count() > 0 && reads.comparison_count() > 0,
                         "Both read and write responses must be checked");
    df_verify_pkg::check(aw_first > 0 && w_first > 0 && together > 0,
                         "Missing AW/W ordering coverage");
    df_verify_pkg::check(b_stalls > 0 && r_stalls > 0, "Missing response backpressure coverage");
    $display({"AXI-Lite: writes=%0d reads=%0d ",
              "AW-first=%0d W-first=%0d together=%0d B-stalls=%0d R-stalls=%0d"},
               writes.comparison_count(), reads.comparison_count(), aw_first, w_first, together,
               b_stalls, r_stalls);
  endtask

  initial begin
    rst_n_i = 1'b0;
    driver.init();
    df_verify_pkg::check(driver.get_status() == axi5_verify_pkg::LITE_NOT_STARTED,
                         "Initialization must not report a completed transfer");
    df_verify_pkg::check(RANDOM_TRANSACTIONS > 0, "RANDOM_TRANSACTIONS must be positive");

    test_reset_values();
    test_write_ordering();
    test_register_fields();
    test_address_decode();
    test_sidebands();
    reset_pending(RESET_AFTER_AW);
    reset_pending(RESET_AFTER_W);
    reset_pending(RESET_WITH_B);
    reset_pending(RESET_WITH_R);
    test_random_accesses();
    check_results();
    df_verify_pkg::finish_test();
  end

  initial begin
    #10ms;
    $fatal(1, "AXI-Lite testbench watchdog expired");
  end
endmodule
