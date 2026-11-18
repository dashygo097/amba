`include "amba/axi5_lite.svh"

module axi5_lite_vip #(
    parameter int unsigned TIMEOUT_CYCLES = 256
) (
    axi5_lite_if axi
);
  typedef logic [$bits(axi.AWADDR)-1:0] addr_t;
  typedef logic [$bits(axi.WDATA)-1:0] data_t;
  typedef logic [$bits(axi.WSTRB)-1:0] strb_t;
  typedef logic [$bits(axi.AWUSER)-1:0] req_user_t;
  typedef logic [$bits(axi.WUSER)-1:0] data_user_t;

  bit initialized = 1'b0;
  axi5_verify_pkg::lite_status_e transfer_status = axi5_verify_pkg::LITE_NOT_STARTED;
  typedef logic [$bits(axi.AWID)-1:0] aw_id_t;
  typedef logic [$bits(axi.ARID)-1:0] ar_id_t;
  typedef logic [$bits(axi.AWSUBSYSID)-1:0] subsys_id_t;
  typedef `AMBA_AXI5_LITE_B_TYPE(axi) b_t;
  typedef `AMBA_AXI5_LITE_R_TYPE(axi) r_t;
  localparam axi5_pkg::size_e FullSize = axi5_pkg::size_e'($clog2($bits(axi.WSTRB)));
  b_t b_sample, b_response;
  r_t r_sample, r_response;
  bit b_response_valid = 1'b0;
  bit r_response_valid = 1'b0;

  axi5_lite_monitor monitor (.axi(axi));

  always_comb begin
    `AMBA_AXI5_LITE_PACK_B(b_sample, axi)
    `AMBA_AXI5_LITE_PACK_R(r_sample, axi)
  end

  task automatic drive_idle();
    axi.AWAKEUP = 1'b0;
    axi.AWVALID = 1'b0;
    axi.WVALID  = 1'b0;
    axi.BREADY  = 1'b0;
    axi.ARVALID = 1'b0;
    axi.RREADY  = 1'b0;
  endtask

  task automatic init();
    df_verify_pkg::check(transfer_status != axi5_verify_pkg::LITE_ACTIVE && axi.ARESETn === 1'b0,
                         "driver.init requires idle driver and asserted reset");
    drive_idle();
    axi.AWAKEUP = 1'b0;
    axi.AWADDR = '0;
    axi.AWPROT = '0;
    axi.AWSIZE = FullSize;
    axi.AWID = '0;
    axi.AWIDUNQ = 1'b0;
    axi.AWUSER = '0;
    axi.AWTRACE = 1'b0;
    axi.AWSUBSYSID = '0;
    axi.WDATA = '0;
    axi.WSTRB = '0;
    axi.WUSER = '0;
    axi.WTRACE = 1'b0;
    axi.ARADDR = '0;
    axi.ARPROT = '0;
    axi.ARSIZE = FullSize;
    axi.ARID = '0;
    axi.ARIDUNQ = 1'b0;
    axi.ARUSER = '0;
    axi.ARTRACE = 1'b0;
    axi.ARSUBSYSID = '0;
    initialized = 1'b1;
  endtask

  task automatic begin_transfer(input int unsigned timeout_cycles);
    df_verify_pkg::check(initialized, "Call driver.init before issuing traffic");
    df_verify_pkg::check(transfer_status != axi5_verify_pkg::LITE_ACTIVE,
                         "AXI-Lite driver permits only one active read/write call");
    df_verify_pkg::check(axi.ARESETn === 1'b1, "Cannot start a transfer during reset");
    df_verify_pkg::check(timeout_cycles > 0, "AXI-Lite timeout_cycles must be positive");
    b_response_valid = 1'b0;
    r_response_valid = 1'b0;
    transfer_status  = axi5_verify_pkg::LITE_ACTIVE;
  endtask

  function automatic axi5_verify_pkg::lite_status_e get_status();
    return transfer_status;
  endfunction

  function automatic b_t get_write_response();
    df_verify_pkg::check(b_response_valid && transfer_status == axi5_verify_pkg::LITE_COMPLETED,
                         "No completed write response available");
    return b_response;
  endfunction

  function automatic r_t get_read_response();
    df_verify_pkg::check(r_response_valid && transfer_status == axi5_verify_pkg::LITE_COMPLETED,
                         "No completed read response available");
    return r_response;
  endfunction

  task automatic complete_transfer();
    @(negedge axi.ACLK);
    drive_idle();
    transfer_status = axi5_verify_pkg::LITE_COMPLETED;
  endtask

  task automatic abort_transfer(input bit allow_reset);
    drive_idle();
    transfer_status = axi5_verify_pkg::LITE_RESET;
    df_verify_pkg::check(allow_reset, "Unexpected reset during AXI-Lite transfer");
  endtask

  task automatic write(
      input addr_t addr, input data_t data, output axi5_pkg::bresp_e resp, input strb_t strb = '1,
      input int unsigned aw_delay = 0, input int unsigned w_delay = 0,
      input int unsigned b_stall = 0, input int unsigned timeout_cycles = TIMEOUT_CYCLES,
      input bit allow_reset = 1'b0, input axi5_pkg::prot_t prot = '0,
      input axi5_pkg::size_e size = FullSize, input aw_id_t id = '0, input logic idunq = 1'b0,
      input req_user_t aw_user = '0, input data_user_t w_user = '0, input logic aw_trace = 1'b0,
      input logic w_trace = 1'b0, input subsys_id_t subsys_id = '0,
      input int unsigned wakeup_delay = 0);
    bit aw_done, w_done;
    int unsigned stalled_cycles;
    begin_transfer(timeout_cycles);
    aw_done = 1'b0;
    w_done = 1'b0;
    stalled_cycles = 0;
    resp = axi5_pkg::bresp_e'('x);
    for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
      @(negedge axi.ACLK or negedge axi.ARESETn);
      if (axi.ARESETn !== 1'b1) begin
        abort_transfer(allow_reset);
        return;
      end
      axi.AWAKEUP = axi.O_EN_WAKEUP && cycle >= wakeup_delay;
      axi.AWADDR = addr;
      axi.AWPROT = axi.OI_EN_PROT ? prot : '0;
      axi.AWSIZE = axi.O_EN_SIZE ? size : FullSize;
      axi.AWID = axi.OO_EN_ID ? id : '0;
      axi.AWIDUNQ = axi.OO_EN_IDUNQ && idunq;
      axi.AWUSER = axi.O_EN_USER ? aw_user : req_user_t'('0);
      axi.WUSER = axi.O_EN_USER ? w_user : data_user_t'('0);
      axi.AWTRACE = axi.C_EN_TRACE && aw_trace;
      axi.WTRACE = axi.C_EN_TRACE && w_trace;
      axi.AWSUBSYSID = axi.O_EN_SUBSYSTEM ? subsys_id : '0;
      axi.WDATA = data;
      axi.WSTRB = axi.O_EN_STRB ? strb : '1;
      axi.AWVALID = !aw_done && cycle >= aw_delay;
      axi.WVALID = !w_done && cycle >= w_delay;
      axi.BREADY = stalled_cycles >= b_stall;
      @(posedge axi.ACLK or negedge axi.ARESETn);
      if (axi.ARESETn !== 1'b1) begin
        abort_transfer(allow_reset);
        return;
      end
      if (axi.AWVALID && axi.AWREADY) aw_done = 1'b1;
      if (axi.WVALID && axi.WREADY) w_done = 1'b1;
      if (axi.BVALID && !axi.BREADY) stalled_cycles++;
      if (axi.BVALID && axi.BREADY) begin
        b_response = b_sample;
        b_response_valid = 1'b1;
        resp = b_sample.resp;
        complete_transfer();
        return;
      end
    end
    $fatal(1, "AXI-Lite write timeout addr=%h cycles=%0d AW=%b W=%b BVALID=%b", addr,
           timeout_cycles, aw_done, w_done, axi.BVALID);
  endtask

  task automatic read(input addr_t addr, output data_t data, output axi5_pkg::rresp_e resp,
                      input int unsigned ar_delay = 0, input int unsigned r_stall = 0,
                      input int unsigned timeout_cycles = TIMEOUT_CYCLES,
                      input bit allow_reset = 1'b0, input axi5_pkg::prot_t prot = '0,
                      input axi5_pkg::size_e size = FullSize, input ar_id_t id = '0,
                      input logic idunq = 1'b0, input req_user_t ar_user = '0,
                      input logic ar_trace = 1'b0, input subsys_id_t subsys_id = '0,
                      input int unsigned wakeup_delay = 0);
    bit ar_done;
    int unsigned stalled_cycles;
    begin_transfer(timeout_cycles);
    ar_done = 1'b0;
    stalled_cycles = 0;
    data = 'x;
    resp = axi5_pkg::rresp_e'('x);
    for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
      @(negedge axi.ACLK or negedge axi.ARESETn);
      if (axi.ARESETn !== 1'b1) begin
        abort_transfer(allow_reset);
        return;
      end
      axi.AWAKEUP = axi.O_EN_WAKEUP && cycle >= wakeup_delay;
      axi.ARADDR = addr;
      axi.ARPROT = axi.OI_EN_PROT ? prot : '0;
      axi.ARSIZE = axi.O_EN_SIZE ? size : FullSize;
      axi.ARID = axi.OO_EN_ID ? id : '0;
      axi.ARIDUNQ = axi.OO_EN_IDUNQ && idunq;
      axi.ARUSER = axi.O_EN_USER ? ar_user : req_user_t'('0);
      axi.ARTRACE = axi.C_EN_TRACE && ar_trace;
      axi.ARSUBSYSID = axi.O_EN_SUBSYSTEM ? subsys_id : '0;
      axi.ARVALID = !ar_done && cycle >= ar_delay;
      axi.RREADY = stalled_cycles >= r_stall;
      @(posedge axi.ACLK or negedge axi.ARESETn);
      if (axi.ARESETn !== 1'b1) begin
        abort_transfer(allow_reset);
        return;
      end
      if (axi.ARVALID && axi.ARREADY) ar_done = 1'b1;
      if (axi.RVALID && !axi.RREADY) stalled_cycles++;
      if (axi.RVALID && axi.RREADY) begin
        r_response = r_sample;
        r_response_valid = 1'b1;
        data = r_sample.data;
        resp = r_sample.resp;
        complete_transfer();
        return;
      end
    end
    $fatal(1, "AXI-Lite read timeout addr=%h cycles=%0d AR=%b RVALID=%b", addr, timeout_cycles,
           ar_done, axi.RVALID);
  endtask

  function automatic void check_idle();
    df_verify_pkg::check(transfer_status != axi5_verify_pkg::LITE_ACTIVE,
                         "AXI-Lite driver still active");
    monitor.check_idle();
  endfunction

  initial begin
    df_verify_pkg::check(TIMEOUT_CYCLES > 0, "AXI-Lite TIMEOUT_CYCLES must be positive");
  end
endmodule
