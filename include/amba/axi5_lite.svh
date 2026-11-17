`ifndef AMBA_AXI5_LITE_SVH_
`define AMBA_AXI5_LITE_SVH_

// Public packed type expressions for axi5_lite_if channel payloads.
// Use with typedef in the module connected to _bus. USER types must match that
// interface instance. Optional fields retain their storage widths.
// Field order is part of the packing ABI; VALID, READY and AWAKEUP are
// separate from the payload.
// Example inside a module with an axi5_lite_if.sink port named axi and a
// req_user_t type parameter shared with the interface configuration:
//   typedef `AMBA_AXI5_LITE_AW_TYPE(axi, req_user_t) lite_aw_t;
//   lite_aw_t aw_in;
//   always_comb begin
//     `AMBA_AXI5_LITE_PACK_AW(aw_in, axi)
//   end

`define AMBA_AXI5_LITE_AW_PAYLOAD_TYPE(_addr_width, _id_width, _subsys_width, _user_t) \
  struct packed { \
    logic [(_addr_width)-1:0] addr; \
    axi5_pkg::prot_t prot; \
    axi5_pkg::size_e size; \
    logic [(_id_width)-1:0] id; \
    logic idunq; \
    _user_t user; \
    logic trace; \
    logic [(_subsys_width)-1:0] subsys_id; \
  }

`define AMBA_AXI5_LITE_W_PAYLOAD_TYPE(_data_width, _user_t) \
  struct packed { \
    logic [(_data_width)-1:0] data; \
    logic [(_data_width)/8-1:0] strb; \
    _user_t user; \
    logic trace; \
  }

`define AMBA_AXI5_LITE_B_PAYLOAD_TYPE(_id_width, _user_t) \
  struct packed { \
    axi5_pkg::bresp_e resp; \
    logic [(_id_width)-1:0] id; \
    logic idunq; \
    _user_t user; \
    logic trace; \
  }

`define AMBA_AXI5_LITE_AR_PAYLOAD_TYPE(_addr_width, _id_width, _subsys_width, _user_t) \
  `AMBA_AXI5_LITE_AW_PAYLOAD_TYPE(_addr_width, _id_width, _subsys_width, _user_t)

`define AMBA_AXI5_LITE_R_USER_TYPE(_data_user_t, _resp_user_t) \
  struct packed { \
    _data_user_t data; \
    _resp_user_t resp; \
  }

`define AMBA_AXI5_LITE_R_PAYLOAD_TYPE(_data_width, _id_width, _user_t) \
  struct packed { \
    logic [(_data_width)-1:0] data; \
    axi5_pkg::rresp_e resp; \
    logic [(_id_width)-1:0] id; \
    logic idunq; \
    _user_t user; \
    logic trace; \
  }

// verilog_format: off
`define AMBA_AXI5_LITE_AW_TYPE(_bus, _user_t) \
  `AMBA_AXI5_LITE_AW_PAYLOAD_TYPE($bits(_bus.AWADDR), $bits(_bus.AWID), $bits(_bus.AWSUBSYSID), _user_t)
`define AMBA_AXI5_LITE_W_TYPE(_bus, _user_t) \
  `AMBA_AXI5_LITE_W_PAYLOAD_TYPE($bits(_bus.WDATA), _user_t)
`define AMBA_AXI5_LITE_B_TYPE(_bus, _user_t) \
  `AMBA_AXI5_LITE_B_PAYLOAD_TYPE($bits(_bus.BID), _user_t)
`define AMBA_AXI5_LITE_AR_TYPE(_bus, _user_t) \
  `AMBA_AXI5_LITE_AR_PAYLOAD_TYPE($bits(_bus.ARADDR), $bits(_bus.ARID), $bits(_bus.ARSUBSYSID), _user_t)
`define AMBA_AXI5_LITE_R_TYPE(_bus, _user_t) \
  `AMBA_AXI5_LITE_R_PAYLOAD_TYPE($bits(_bus.RDATA), $bits(_bus.RID), _user_t)
// verilog_format: on

// PACKING ORDER
// Internal signal lists match the packed type declarations above, MSB first.
`define AMBA_AXI5_LITE_AW_SIGNALS_(_bus) \
  _bus.AWADDR, _bus.AWPROT, _bus.AWSIZE, _bus.AWID, _bus.AWIDUNQ, \
  _bus.AWUSER, _bus.AWTRACE, _bus.AWSUBSYSID

`define AMBA_AXI5_LITE_W_SIGNALS_(_bus) \
  _bus.WDATA, _bus.WSTRB, _bus.WUSER, _bus.WTRACE

`define AMBA_AXI5_LITE_B_SIGNALS_(_bus) \
  _bus.BRESP, _bus.BID, _bus.BIDUNQ, _bus.BUSER, _bus.BTRACE

`define AMBA_AXI5_LITE_AR_SIGNALS_(_bus) \
  _bus.ARADDR, _bus.ARPROT, _bus.ARSIZE, _bus.ARID, _bus.ARIDUNQ, \
  _bus.ARUSER, _bus.ARTRACE, _bus.ARSUBSYSID

`define AMBA_AXI5_LITE_R_SIGNALS_(_bus) \
  _bus.RDATA, _bus.RRESP, _bus.RID, _bus.RIDUNQ, _bus.RUSER, _bus.RTRACE

// PACK
// Procedural assignments for use inside always_comb; destination comes first.
// _payload must use the corresponding channel type and matching USER types.
// These connections preserve every bit, including enum encodings.
// They do not apply optional-signal defaults or validate codes.
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
