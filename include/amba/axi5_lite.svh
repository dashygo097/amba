`ifndef AMBA_AXI5_LITE_SVH_
`define AMBA_AXI5_LITE_SVH_

// Public packed type expressions for axi5_lite_if channel payloads.
// Use with typedef in the module connected to _bus. USER types must match that
// interface instance. Optional fields retain their storage widths.
// Field order is part of the packing ABI; VALID, READY and their checks are
// separate from the payload. AWAKEUP and AWAKEUPCHK are also separate.
// Example inside a module with an axi5_lite_if.sink port named axi and a
// req_user_t type parameter shared with the interface configuration:
//   typedef `AMBA_AXI5_LITE_AW_TYPE(axi, req_user_t) lite_aw_t;
//   lite_aw_t aw_in;
//   always_comb begin
//     `AMBA_AXI5_LITE_PACK_AW(aw_in, axi)
//   end

// AW
`define AMBA_AXI5_LITE_AW_TYPE(_bus, _user_t) \
  struct packed { \
    logic [$bits(_bus.AWADDR) - 1:0] addr; \
    axi5_pkg::prot_t prot; \
    axi5_pkg::size_e size; \
    logic [$bits(_bus.AWID) - 1:0] id; \
    logic idunq; \
    _user_t user; \
    logic trace; \
    logic [$bits(_bus.AWSUBSYSID) - 1:0] subsys_id; \
    logic [$bits(_bus.AWADDRCHK) - 1:0] addr_chk; \
    logic [$bits(_bus.AWIDCHK) - 1:0] id_chk; \
    logic ctl_chk0; \
    logic [$bits(_bus.AWUSERCHK) - 1:0] user_chk; \
    logic trace_chk; \
    logic subsys_id_chk; \
  }

// W
`define AMBA_AXI5_LITE_W_TYPE(_bus, _user_t) \
  struct packed { \
    logic [$bits(_bus.WDATA) - 1:0] data; \
    logic [$bits(_bus.WSTRB) - 1:0] strb; \
    _user_t user; \
    logic trace; \
    logic [$bits(_bus.WPOISON) - 1:0] poison; \
    logic [$bits(_bus.WDATACHK) - 1:0] data_chk; \
    logic [$bits(_bus.WSTRBCHK) - 1:0] strb_chk; \
    logic [$bits(_bus.WUSERCHK) - 1:0] user_chk; \
    logic [$bits(_bus.WPOISONCHK) - 1:0] poison_chk; \
    logic trace_chk; \
  }

// B
`define AMBA_AXI5_LITE_B_TYPE(_bus, _user_t) \
  struct packed { \
    axi5_pkg::bresp_e resp; \
    logic [$bits(_bus.BID) - 1:0] id; \
    logic idunq; \
    _user_t user; \
    logic trace; \
    logic [$bits(_bus.BIDCHK) - 1:0] id_chk; \
    logic resp_chk; \
    logic [$bits(_bus.BUSERCHK) - 1:0] user_chk; \
    logic trace_chk; \
  }

// AR
`define AMBA_AXI5_LITE_AR_TYPE(_bus, _user_t) \
  struct packed { \
    logic [$bits(_bus.ARADDR) - 1:0] addr; \
    axi5_pkg::prot_t prot; \
    axi5_pkg::size_e size; \
    logic [$bits(_bus.ARID) - 1:0] id; \
    logic idunq; \
    _user_t user; \
    logic trace; \
    logic [$bits(_bus.ARSUBSYSID) - 1:0] subsys_id; \
    logic [$bits(_bus.ARADDRCHK) - 1:0] addr_chk; \
    logic [$bits(_bus.ARIDCHK) - 1:0] id_chk; \
    logic ctl_chk0; \
    logic [$bits(_bus.ARUSERCHK) - 1:0] user_chk; \
    logic trace_chk; \
    logic subsys_id_chk; \
  }

// R
`define AMBA_AXI5_LITE_R_USER_TYPE(_data_user_t, _resp_user_t) \
  struct packed { \
    _data_user_t data; \
    _resp_user_t resp; \
  }

`define AMBA_AXI5_LITE_R_TYPE(_bus, _user_t) \
  struct packed { \
    logic [$bits(_bus.RDATA) - 1:0] data; \
    axi5_pkg::rresp_e resp; \
    logic [$bits(_bus.RID) - 1:0] id; \
    logic idunq; \
    _user_t user; \
    logic trace; \
    logic [$bits(_bus.RPOISON) - 1:0] poison; \
    logic [$bits(_bus.RIDCHK) - 1:0] id_chk; \
    logic [$bits(_bus.RDATACHK) - 1:0] data_chk; \
    logic resp_chk; \
    logic [$bits(_bus.RUSERCHK) - 1:0] user_chk; \
    logic [$bits(_bus.RPOISONCHK) - 1:0] poison_chk; \
    logic trace_chk; \
  }

// PACKING ORDER
// Internal signal lists match the packed type declarations above, MSB first.
`define AMBA_AXI5_LITE_AW_SIGNALS_(_bus) \
  _bus.AWADDR, _bus.AWPROT, _bus.AWSIZE, _bus.AWID, _bus.AWIDUNQ, \
  _bus.AWUSER, _bus.AWTRACE, _bus.AWSUBSYSID, _bus.AWADDRCHK, _bus.AWIDCHK, \
  _bus.AWCTLCHK0, _bus.AWUSERCHK, _bus.AWTRACECHK, _bus.AWSUBSYSIDCHK

`define AMBA_AXI5_LITE_W_SIGNALS_(_bus) \
  _bus.WDATA, _bus.WSTRB, _bus.WUSER, _bus.WTRACE, _bus.WPOISON, \
  _bus.WDATACHK, _bus.WSTRBCHK, _bus.WUSERCHK, _bus.WPOISONCHK, _bus.WTRACECHK

`define AMBA_AXI5_LITE_B_SIGNALS_(_bus) \
  _bus.BRESP, _bus.BID, _bus.BIDUNQ, _bus.BUSER, _bus.BTRACE, \
  _bus.BIDCHK, _bus.BRESPCHK, _bus.BUSERCHK, _bus.BTRACECHK

`define AMBA_AXI5_LITE_AR_SIGNALS_(_bus) \
  _bus.ARADDR, _bus.ARPROT, _bus.ARSIZE, _bus.ARID, _bus.ARIDUNQ, \
  _bus.ARUSER, _bus.ARTRACE, _bus.ARSUBSYSID, _bus.ARADDRCHK, _bus.ARIDCHK, \
  _bus.ARCTLCHK0, _bus.ARUSERCHK, _bus.ARTRACECHK, _bus.ARSUBSYSIDCHK

`define AMBA_AXI5_LITE_R_SIGNALS_(_bus) \
  _bus.RDATA, _bus.RRESP, _bus.RID, _bus.RIDUNQ, _bus.RUSER, _bus.RTRACE, \
  _bus.RPOISON, _bus.RIDCHK, _bus.RDATACHK, _bus.RRESPCHK, _bus.RUSERCHK, \
  _bus.RPOISONCHK, _bus.RTRACECHK

// PACK
// Procedural assignments for use inside always_comb; destination comes first.
// _payload must use the corresponding channel type and matching USER types.
// These connections preserve every bit, including check bits and enum encodings.
// They do not generate parity, apply optional-signal defaults or validate codes.
`define AMBA_AXI5_LITE_PACK_AW(_payload, _bus) \
  _payload = {`AMBA_AXI5_LITE_AW_SIGNALS_(_bus)};

`define AMBA_AXI5_LITE_PACK_W(_payload, _bus) \
  _payload = {`AMBA_AXI5_LITE_W_SIGNALS_(_bus)};

`define AMBA_AXI5_LITE_PACK_B(_payload, _bus) \
  _payload = {`AMBA_AXI5_LITE_B_SIGNALS_(_bus)};

`define AMBA_AXI5_LITE_PACK_AR(_payload, _bus) \
  _payload = {`AMBA_AXI5_LITE_AR_SIGNALS_(_bus)};

`define AMBA_AXI5_LITE_PACK_R(_payload, _bus) \
  _payload = {`AMBA_AXI5_LITE_R_SIGNALS_(_bus)};

// UNPACK
// Drive only channels owned by the endpoint: AW/W/AR for a source, B/R for a sink.
// Call once per driven channel. Handshake and wakeup signals need separate logic.
`define AMBA_AXI5_LITE_UNPACK_AW(_bus, _payload) \
  {`AMBA_AXI5_LITE_AW_SIGNALS_(_bus)} = _payload;

`define AMBA_AXI5_LITE_UNPACK_W(_bus, _payload) \
  {`AMBA_AXI5_LITE_W_SIGNALS_(_bus)} = _payload;

`define AMBA_AXI5_LITE_UNPACK_B(_bus, _payload) \
  {`AMBA_AXI5_LITE_B_SIGNALS_(_bus)} = _payload;

`define AMBA_AXI5_LITE_UNPACK_AR(_bus, _payload) \
  {`AMBA_AXI5_LITE_AR_SIGNALS_(_bus)} = _payload;

`define AMBA_AXI5_LITE_UNPACK_R(_bus, _payload) \
  {`AMBA_AXI5_LITE_R_SIGNALS_(_bus)} = _payload;

`endif  // AMBA_AXI5_LITE_SVH_
