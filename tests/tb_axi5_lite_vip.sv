`include "amba/axi5_lite.svh"

module tb_axi5_lite_vip #(
    parameter bit ENABLE_OPTIONS = 1'b1,
    parameter int unsigned DATA_WIDTH = 64
) ();
  timeunit 1ns; timeprecision 1ps;
  localparam int unsigned AddrWidth = 40;
  typedef struct packed {
    logic [2:0] domain;
    logic [4:0] tag;
  } req_user_t;
  typedef struct packed {
    logic [3:0] flags;
    logic [2:0] tag;
  } data_user_t;
  typedef struct packed {
    logic [1:0] flags;
    logic [3:0] tag;
  } resp_user_t;
  logic  clk = 1'b0;
  logic  rst_n;
  string fault;
  axi5_lite_if #(
      .ADDR_WIDTH    (AddrWidth),
      .DATA_WIDTH    (DATA_WIDTH),
      .OI_EN_PROT    (ENABLE_OPTIONS),
      .O_EN_SIZE     (ENABLE_OPTIONS),
      .OO_EN_ID      (ENABLE_OPTIONS),
      .ID_W_WIDTH    (5),
      .ID_R_WIDTH    (3),
      .O_EN_USER     (ENABLE_OPTIONS),
      .OO_EN_IDUNQ   (ENABLE_OPTIONS),
      .C_EN_TRACE    (ENABLE_OPTIONS),
      .O_EN_WAKEUP   (ENABLE_OPTIONS),
      .O_EN_SUBSYSTEM(ENABLE_OPTIONS),
      .SUBSYSID_WIDTH(4),
      .req_user_t    (req_user_t),
      .data_user_t   (data_user_t),
      .resp_user_t   (resp_user_t)
  ) axi (
      .ACLK   (clk),
      .ARESETn(rst_n)
  );
  typedef axi5_verify_pkg::lite_types#(
      .ADDR_WIDTH    ($bits(axi.AWADDR)),
      .DATA_WIDTH    ($bits(axi.WDATA)),
      .ID_W_WIDTH    ($bits(axi.AWID)),
      .ID_R_WIDTH    ($bits(axi.ARID)),
      .SUBSYSID_WIDTH($bits(axi.AWSUBSYSID)),
      .req_user_t    (req_user_t),
      .data_user_t   (data_user_t),
      .resp_user_t   (resp_user_t)
  ) types_t;
  typedef types_t::addr_t addr_t;
  typedef types_t::data_t data_t;
  typedef types_t::strb_t strb_t;
  typedef types_t::aw_t aw_t;
  typedef types_t::w_t w_t;
  typedef types_t::b_t b_t;
  typedef types_t::ar_t ar_t;
  typedef types_t::r_t r_t;
  typedef types_t::r_user_t r_user_t;
  localparam int unsigned SizeBits = $clog2($bits(axi.WSTRB));

  axi5_lite_vip driver (.axi(axi));

  aw_t aw_sample;
  w_t  w_sample;
  ar_t ar_sample;
  b_t  b_drive;
  r_t  r_drive;
  always #5ns clk = ~clk;
  always_comb begin
    `AMBA_AXI5_LITE_PACK_AW(aw_sample, axi)
    `AMBA_AXI5_LITE_PACK_W(w_sample, axi)
    `AMBA_AXI5_LITE_PACK_AR(ar_sample, axi)
    `AMBA_AXI5_LITE_UNPACK_B(axi, b_drive)
    `AMBA_AXI5_LITE_UNPACK_R(axi, r_drive)
  end

  task automatic accept_aw(input aw_t expected);
    repeat (6) @(posedge clk);
    if (fault == "aw_user") begin
      @(negedge clk);
      #1ns;
      axi.AWUSER = ~axi.AWUSER;
      @(posedge clk);
    end
    @(negedge clk);
    axi.AWREADY = 1'b1;
    do @(posedge clk); while (!axi.AWVALID);
    df_verify_pkg::value_check#(aw_t)::equal(aw_sample, expected, "AW payload");
    @(negedge clk);
    axi.AWREADY = 1'b0;
  endtask

  task automatic accept_w(input w_t expected);
    repeat (8) @(posedge clk);
    if (fault == "w_user") begin
      @(negedge clk);
      #1ns;
      axi.WUSER = ~axi.WUSER;
      @(posedge clk);
    end
    @(negedge clk);
    axi.WREADY = 1'b1;
    do @(posedge clk); while (!axi.WVALID);
    df_verify_pkg::value_check#(w_t)::equal(w_sample, expected, "W payload");
    @(negedge clk);
    axi.WREADY = 1'b0;
  endtask

  task automatic accept_ar(input ar_t expected);
    repeat (6) @(posedge clk);
    if (fault == "ar_user") begin
      @(negedge clk);
      #1ns;
      axi.ARUSER = ~axi.ARUSER;
      @(posedge clk);
    end
    @(negedge clk);
    axi.ARREADY = 1'b1;
    do @(posedge clk); while (!axi.ARVALID);
    df_verify_pkg::value_check#(ar_t)::equal(ar_sample, expected, "AR payload");
    @(negedge clk);
    axi.ARREADY = 1'b0;
  endtask

  task automatic send_b(input b_t response);
    b_drive = response;
    if (fault == "b_id") b_drive.id ^= 1;
    if (fault == "b_idunq") b_drive.idunq = 1'b1;
    axi.BVALID = 1'b1;
    @(posedge clk);
    if (!ENABLE_OPTIONS) begin
      @(negedge clk);
      b_drive.id = '0;
      b_drive.idunq = 1'b0;
      b_drive.user = '0;
      b_drive.trace = 1'b0;
      @(negedge clk);
      b_drive = response;
    end
    if (fault == "b_user" || fault == "b_trace") begin
      @(negedge clk);
      if (fault == "b_user") b_drive.user = ~b_drive.user;
      else b_drive.trace = !b_drive.trace;
    end
    while (!axi.BREADY) @(posedge clk);
    @(negedge clk);
    axi.BVALID = 1'b0;
  endtask

  task automatic send_r(input r_t response);
    r_drive = response;
    if (fault == "r_id") r_drive.id ^= 1;
    if (fault == "r_idunq") r_drive.idunq = 1'b1;
    axi.RVALID = 1'b1;
    @(posedge clk);
    if (!ENABLE_OPTIONS) begin
      @(negedge clk);
      r_drive.id = '0;
      r_drive.idunq = 1'b0;
      r_drive.user = '0;
      r_drive.trace = 1'b0;
      @(negedge clk);
      r_drive = response;
    end
    if (fault == "r_user" || fault == "r_trace") begin
      @(negedge clk);
      if (fault == "r_user") r_drive.user = ~r_drive.user;
      else r_drive.trace = !r_drive.trace;
    end
    while (!axi.RREADY) @(posedge clk);
    @(negedge clk);
    axi.RVALID = 1'b0;
  endtask

  task automatic exercise_write(input int unsigned iteration);
    aw_t request;
    w_t  payload;
    b_t response, actual;
    axi5_pkg::bresp_e resp;
    bit pattern;
    pattern = iteration[0];
    request = '0;
    payload = '0;
    response = '0;
    request.addr = iteration == 1 ? '1 : '0;
    request.size = axi5_pkg::size_e'(ENABLE_OPTIONS ? iteration % (SizeBits + 1) : SizeBits);
    payload.data = pattern ? '1 : '0;
    payload.strb = pattern ? types_t::byte_lanes(request.addr, request.size) : '0;
    if (!ENABLE_OPTIONS) payload.strb = pattern ? '1 : '0;
    if (ENABLE_OPTIONS) begin
      request.prot = 3'(iteration);
      request.id = pattern ? '1 : '0;
      request.idunq = pattern;
      request.user = pattern ? '1 : '0;
      request.trace = pattern;
      request.subsys_id = pattern ? '1 : '0;
      payload.user = pattern ? '1 : '0;
      payload.trace = !pattern;
      response.id = request.id;
      response.idunq = request.idunq;
      response.user = pattern ? '0 : '1;
      response.trace = !pattern;
    end else begin
      response.id = '1;
      response.idunq = 1'b1;
      response.user = '1;
      response.trace = 1'b1;
    end
    unique case (iteration % 4)
      0: response.resp = axi5_pkg::BRESP_OKAY;
      1: response.resp = axi5_pkg::BRESP_SLVERR;
      2: response.resp = axi5_pkg::BRESP_DECERR;
      3: response.resp = axi5_pkg::BRESP_TRANSFAULT;
    endcase
    if (fault == "size") request.size = axi5_pkg::size_e'(SizeBits + 1);
    if (fault == "strb") begin
      request.size = axi5_pkg::SIZE_1B;
      payload.strb = '1;
    end
    fork
      driver.write(.addr(request.addr), .data(payload.data), .strb(payload.strb), .resp(resp),
                   .prot(request.prot), .size(request.size), .id(request.id), .idunq(request.idunq),
                   .aw_user(request.user), .w_user(payload.user), .aw_trace(request.trace),
                   .w_trace(payload.trace), .subsys_id(request.subsys_id), .wakeup_delay(2),
                   .aw_delay(iteration % 3), .w_delay(iteration % 2), .b_stall(3));
      begin
        fork
          accept_aw(request);
          accept_w(payload);
        join
        send_b(response);
      end
    join
    actual = driver.get_write_response();
    df_verify_pkg::value_check#(b_t)::equal(actual, response, "Complete B response");
    df_verify_pkg::value_check#(axi5_pkg::bresp_e)::equal(resp, response.resp, "BRESP output");
    driver.check_idle();
  endtask

  task automatic exercise_read(input int unsigned iteration);
    ar_t request;
    r_t response, actual;
    axi5_pkg::rresp_e resp;
    data_t data;
    bit pattern;
    pattern = iteration[0];
    request = '0;
    response = '0;
    request.addr = pattern ? '1 : '0;
    request.size = axi5_pkg::size_e'(ENABLE_OPTIONS ? iteration % (SizeBits + 1) : SizeBits);
    response.data = pattern ? '1 : '0;
    if (ENABLE_OPTIONS) begin
      request.prot = 3'(iteration);
      request.id = pattern ? '1 : '0;
      request.idunq = pattern;
      request.user = pattern ? '1 : '0;
      request.trace = pattern;
      request.subsys_id = pattern ? '1 : '0;
      response.id = request.id;
      response.idunq = request.idunq;
      response.user = '{data: pattern ? '1 : '0, resp: pattern ? '0 : '1};
      response.trace = !pattern;
    end else begin
      response.id = '1;
      response.idunq = 1'b1;
      response.user = '1;
      response.trace = 1'b1;
    end
    unique case (iteration % 4)
      0: response.resp = axi5_pkg::RRESP_OKAY;
      1: response.resp = axi5_pkg::RRESP_SLVERR;
      2: response.resp = axi5_pkg::RRESP_DECERR;
      3: response.resp = axi5_pkg::RRESP_TRANSFAULT;
    endcase
    fork
      driver.read(.addr(request.addr), .data(data), .resp(resp), .prot(request.prot),
                  .size(request.size), .id(request.id), .idunq(request.idunq),
                  .ar_user(request.user), .ar_trace(request.trace), .subsys_id(request.subsys_id),
                  .ar_delay(iteration % 3), .r_stall(4), .wakeup_delay(2));
      begin
        accept_ar(request);
        send_r(response);
      end
    join
    actual = driver.get_read_response();
    df_verify_pkg::value_check#(r_t)::equal(actual, response, "Complete R response");
    df_verify_pkg::value_check#(axi5_pkg::rresp_e)::equal(resp, response.resp, "RRESP output");
    df_verify_pkg::value_check#(data_t)::equal(data, response.data, "RDATA output");
    driver.check_idle();
  endtask

  task automatic check_coverage();
    aw_t aw_mask;
    w_t  w_mask;
    b_t  b_mask;
    ar_t ar_mask;
    r_t  r_mask;
    aw_mask = '1;
    w_mask = '1;
    b_mask = '1;
    ar_mask = '1;
    r_mask = '1;
    aw_mask.size = axi5_pkg::size_e'((1 << $clog2(SizeBits + 1)) - 1);
    ar_mask.size = aw_mask.size;
    if (!ENABLE_OPTIONS) begin
      aw_mask = '{addr: '1, size: axi5_pkg::SIZE_1B, default: '0};
      w_mask  = '{data: '1, strb: '1, default: '0};
      b_mask  = '{resp: axi5_pkg::bresp_e'('1), default: '0};
      ar_mask = '{addr: '1, size: axi5_pkg::SIZE_1B, default: '0};
      r_mask  = '{data: '1, resp: axi5_pkg::rresp_e'('1), default: '0};
    end
    df_verify_pkg::check(driver.monitor.aw_coverage.exercised(aw_mask), "AW field coverage");
    df_verify_pkg::check(driver.monitor.w_coverage.exercised(w_mask), "W field coverage");
    df_verify_pkg::check(driver.monitor.b_coverage.exercised(b_mask), "B field coverage");
    df_verify_pkg::check(driver.monitor.ar_coverage.exercised(ar_mask), "AR field coverage");
    df_verify_pkg::check(driver.monitor.r_coverage.exercised(r_mask), "R field coverage");
    df_verify_pkg::check(driver.monitor.control_coverage.exercised(
                         ENABLE_OPTIONS ? 11'h7ff : 11'h3ff), "Handshake and wakeup coverage");
    df_verify_pkg::check(
        driver.monitor.aw_coverage.stalls > 0 &&
                         driver.monitor.w_coverage.stalls > 0 &&
                         driver.monitor.b_coverage.stalls > 0 &&
                         driver.monitor.ar_coverage.stalls > 0 &&
                         driver.monitor.r_coverage.stalls > 0,
        "Every channel must stall");
    df_verify_pkg::check(driver.monitor.resets > 0, "Reset was not observed");
  endtask

  task automatic test_reset_cancel();
    axi5_pkg::bresp_e resp;
    fork
      driver.write(.addr('0), .data('1), .resp(resp), .id('1), .idunq(1'b1), .aw_user('1),
                   .w_user('1), .w_delay(64), .allow_reset(1'b1));
      begin
        @(negedge clk);
        axi.AWREADY = 1'b1;
        do @(posedge clk); while (!axi.AWVALID);
        @(negedge clk);
        rst_n = 1'b0;
        axi.AWREADY = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        driver.init();
        rst_n = 1'b1;
      end
    join
    df_verify_pkg::check(driver.get_status() == axi5_verify_pkg::LITE_RESET,
                         "Reset did not cancel a sideband-bearing request");
    driver.check_idle();
  endtask

  initial begin
    axi5_pkg::bresp_e bresp;
    axi5_pkg::rresp_e rresp;
    data_t data;
    void'($value$plusargs("FAULT=%s", fault));
    rst_n = 1'b0;
    axi.AWREADY = 1'b0;
    axi.WREADY = 1'b0;
    axi.ARREADY = 1'b0;
    axi.BVALID = 1'b0;
    axi.RVALID = 1'b0;
    b_drive = '0;
    r_drive = '0;
    driver.init();
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    case (fault)
      "timeout": driver.write(.addr('0), .data('0), .resp(bresp), .timeout_cycles(4));
      "concurrent":
      fork
        driver.write(.addr('0), .data('0), .resp(bresp));
        begin
          #1ns;
          driver.read(.addr('0), .data(data), .resp(rresp));
        end
      join
      "reset":
      fork
        driver.write(.addr('0), .data('0), .resp(bresp));
        begin
          #2ns;
          rst_n = 1'b0;
        end
      join
      default:   ;
    endcase
    for (int unsigned i = 0; i < 16; i++) begin
      exercise_write(i);
      exercise_read(i);
    end
    df_verify_pkg::check(fault == "", "Requested fault was not detected");
    test_reset_cancel();
    check_coverage();
    df_verify_pkg::finish_test();
  end

  initial begin
    #1ms;
    $fatal(1, "VIP self-test watchdog expired");
  end
endmodule
