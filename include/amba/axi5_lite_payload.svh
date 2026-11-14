`ifndef AMBA_AXI5_LITE_PAYLOAD_SVH
`define AMBA_AXI5_LITE_PAYLOAD_SVH

// FIELD OPERATIONS
`define AXI5_LITE_PORT_SCALAR(_prefix, _bus, _member, _signal) logic _member;
`define AXI5_LITE_PORT_VECTOR(_prefix, _bus, _member,
                              _signal) logic [$bits(_bus._signal) - 1:0] _member;
`define AXI5_LITE_PORT_PROT(_prefix, _bus, _member, _signal) axi5_pkg::prot_t _member;
`define AXI5_LITE_PORT_SIZE(_prefix, _bus, _member, _signal) axi5_pkg::size_e _member;
`define AXI5_LITE_PORT_REQ_USER(_prefix, _bus, _member, _signal) _prefix``_req_user_t _member;
`define AXI5_LITE_PORT_DATA_USER(_prefix, _bus, _member, _signal) _prefix``_data_user_t _member;
`define AXI5_LITE_PORT_RESP_USER(_prefix, _bus, _member, _signal) _prefix``_resp_user_t _member;
`define AXI5_LITE_PORT_R_USER(_prefix, _bus, _member, _signal) _prefix``_r_user_t _member;
`define AXI5_LITE_PORT_BRESP(_prefix, _bus, _member, _signal) _prefix``_bresp_t _member;
`define AXI5_LITE_PORT_RRESP(_prefix, _bus, _member, _signal) _prefix``_rresp_t _member;

`define AXI5_LITE_DECLARE_PORT_FIELD(_prefix, _bus, _member, _kind, _signal) \
  `AXI5_LITE_PORT_``_kind(_prefix, _bus, _member, _signal)

`define AXI5_LITE_PACK_FIELD(_payload, _bus, _member, _type, _signal) \
  assign _payload._member = _bus._signal;

`define AXI5_LITE_UNPACK_FIELD(_payload, _bus, _member, _type, _signal) \
  assign _bus._signal = _payload._member;

// PAYLOAD OPERATIONS
`define AXI5_LITE_PACK(_payload, _bus, _fields) \
  `_fields(AXI5_LITE_PACK_FIELD, _payload, _bus)

`define AXI5_LITE_UNPACK(_bus, _payload, _fields) \
  `_fields(AXI5_LITE_UNPACK_FIELD, _payload, _bus)

// AW
`define AXI5_LITE_AW_FIELDS(_op, _payload, _bus) \
  `_op(_payload, _bus, addr,           VECTOR,    AWADDR) \
  `_op(_payload, _bus, prot,           PROT,      AWPROT) \
  `_op(_payload, _bus, size,           SIZE,      AWSIZE) \
  `_op(_payload, _bus, id,             VECTOR,    AWID) \
  `_op(_payload, _bus, idunq,          SCALAR,    AWIDUNQ) \
  `_op(_payload, _bus, user,           REQ_USER,  AWUSER) \
  `_op(_payload, _bus, trace,          SCALAR,    AWTRACE) \
  `_op(_payload, _bus, subsys_id,      VECTOR,    AWSUBSYSID) \
  `_op(_payload, _bus, addr_chk,       VECTOR,    AWADDRCHK) \
  `_op(_payload, _bus, id_chk,         VECTOR,    AWIDCHK) \
  `_op(_payload, _bus, ctl_chk0,       SCALAR,    AWCTLCHK0) \
  `_op(_payload, _bus, user_chk,       VECTOR,    AWUSERCHK) \
  `_op(_payload, _bus, trace_chk,      SCALAR,    AWTRACECHK) \
  `_op(_payload, _bus, subsys_id_chk,  SCALAR,    AWSUBSYSIDCHK)

// W
`define AXI5_LITE_W_FIELDS(_op, _payload, _bus) \
  `_op(_payload, _bus, data,           VECTOR,    WDATA) \
  `_op(_payload, _bus, strb,           VECTOR,    WSTRB) \
  `_op(_payload, _bus, user,           DATA_USER, WUSER) \
  `_op(_payload, _bus, trace,          SCALAR,    WTRACE) \
  `_op(_payload, _bus, poison,         VECTOR,    WPOISON) \
  `_op(_payload, _bus, data_chk,       VECTOR,    WDATACHK) \
  `_op(_payload, _bus, strb_chk,       VECTOR,    WSTRBCHK) \
  `_op(_payload, _bus, user_chk,       VECTOR,    WUSERCHK) \
  `_op(_payload, _bus, poison_chk,     VECTOR,    WPOISONCHK) \
  `_op(_payload, _bus, trace_chk,      SCALAR,    WTRACECHK)

// B
`define AXI5_LITE_B_FIELDS(_op, _payload, _bus) \
  `_op(_payload, _bus, resp,           BRESP,     BRESP) \
  `_op(_payload, _bus, id,             VECTOR,    BID) \
  `_op(_payload, _bus, idunq,          SCALAR,    BIDUNQ) \
  `_op(_payload, _bus, user,           RESP_USER, BUSER) \
  `_op(_payload, _bus, trace,          SCALAR,    BTRACE) \
  `_op(_payload, _bus, id_chk,         VECTOR,    BIDCHK) \
  `_op(_payload, _bus, resp_chk,       SCALAR,    BRESPCHK) \
  `_op(_payload, _bus, user_chk,       VECTOR,    BUSERCHK) \
  `_op(_payload, _bus, trace_chk,      SCALAR,    BTRACECHK)

// AR
`define AXI5_LITE_AR_FIELDS(_op, _payload, _bus) \
  `_op(_payload, _bus, addr,           VECTOR,    ARADDR) \
  `_op(_payload, _bus, prot,           PROT,      ARPROT) \
  `_op(_payload, _bus, size,           SIZE,      ARSIZE) \
  `_op(_payload, _bus, id,             VECTOR,    ARID) \
  `_op(_payload, _bus, idunq,          SCALAR,    ARIDUNQ) \
  `_op(_payload, _bus, user,           REQ_USER,  ARUSER) \
  `_op(_payload, _bus, trace,          SCALAR,    ARTRACE) \
  `_op(_payload, _bus, subsys_id,      VECTOR,    ARSUBSYSID) \
  `_op(_payload, _bus, addr_chk,       VECTOR,    ARADDRCHK) \
  `_op(_payload, _bus, id_chk,         VECTOR,    ARIDCHK) \
  `_op(_payload, _bus, ctl_chk0,       SCALAR,    ARCTLCHK0) \
  `_op(_payload, _bus, user_chk,       VECTOR,    ARUSERCHK) \
  `_op(_payload, _bus, trace_chk,      SCALAR,    ARTRACECHK) \
  `_op(_payload, _bus, subsys_id_chk,  SCALAR,    ARSUBSYSIDCHK)

// R
`define AXI5_LITE_R_FIELDS(_op, _payload, _bus) \
  `_op(_payload, _bus, data,           VECTOR,    RDATA) \
  `_op(_payload, _bus, resp,           RRESP,     RRESP) \
  `_op(_payload, _bus, id,             VECTOR,    RID) \
  `_op(_payload, _bus, idunq,          SCALAR,    RIDUNQ) \
  `_op(_payload, _bus, user,           R_USER,    RUSER) \
  `_op(_payload, _bus, trace,          SCALAR,    RTRACE) \
  `_op(_payload, _bus, poison,         VECTOR,    RPOISON) \
  `_op(_payload, _bus, id_chk,         VECTOR,    RIDCHK) \
  `_op(_payload, _bus, data_chk,       VECTOR,    RDATACHK) \
  `_op(_payload, _bus, resp_chk,       SCALAR,    RRESPCHK) \
  `_op(_payload, _bus, user_chk,       VECTOR,    RUSERCHK) \
  `_op(_payload, _bus, poison_chk,     VECTOR,    RPOISONCHK) \
  `_op(_payload, _bus, trace_chk,      SCALAR,    RTRACECHK)

// CHANNEL TYPES
`define AXI5_LITE_PORT_TYPEDEF(_name, _prefix, _bus, _fields) \
  typedef struct packed { \
    `_fields(AXI5_LITE_DECLARE_PORT_FIELD, _prefix, _bus) \
  } _name;

`define AXI5_LITE_TYPEDEFS(_prefix, _bus) \
  typedef _bus.req_user_t _prefix``_req_user_t; \
  typedef _bus.data_user_t _prefix``_data_user_t; \
  typedef _bus.resp_user_t _prefix``_resp_user_t; \
  typedef _bus.bresp_t _prefix``_bresp_t; \
  typedef _bus.rresp_t _prefix``_rresp_t; \
  typedef struct packed { \
    _prefix``_data_user_t data; \
    _prefix``_resp_user_t resp; \
  } _prefix``_r_user_t; \
  `AXI5_LITE_PORT_TYPEDEF(_prefix``_aw_t, _prefix, _bus, AXI5_LITE_AW_FIELDS) \
  `AXI5_LITE_PORT_TYPEDEF(_prefix``_w_t,  _prefix, _bus, AXI5_LITE_W_FIELDS) \
  `AXI5_LITE_PORT_TYPEDEF(_prefix``_b_t,  _prefix, _bus, AXI5_LITE_B_FIELDS) \
  `AXI5_LITE_PORT_TYPEDEF(_prefix``_ar_t, _prefix, _bus, AXI5_LITE_AR_FIELDS) \
  `AXI5_LITE_PORT_TYPEDEF(_prefix``_r_t,  _prefix, _bus, AXI5_LITE_R_FIELDS)

`endif
