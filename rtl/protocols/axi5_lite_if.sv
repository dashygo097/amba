interface axi5_lite_if #(
    parameter int unsigned DATA_WIDTH     = 32,
    parameter int unsigned ADDR_WIDTH     = 32,
    // AXI5-Lite Data Bus Width Options
    parameter bit          O_EN_SIZE      = 1'b0,
    // AXI5-Lite Prot Options
    parameter bit          OI_EN_PROT     = 1'b0,
    // AXI5-Lite ID Options
    parameter bit          OO_EN_ID       = 1'b0,
    parameter int unsigned ID_WIDTH       = 1,
    parameter int unsigned ID_W_WIDTH     = OO_EN_ID ? ID_WIDTH : 0,
    parameter int unsigned ID_R_WIDTH     = OO_EN_ID ? ID_WIDTH : 0,
    // AXI5-Lite User Options
    parameter bit          O_EN_USER      = 1'b0,
    parameter type         user_t         = logic,
    // AXI5-Lite Tracing Conditions
    parameter bit          C_EN_TRACE     = 1'b0,
    // AXI5-Lite Unique ID Options
    parameter bit          OO_EN_IDUNQ    = 1'b0,
    // AXI5-Lite Wakeup Options
    parameter bit          O_EN_WAKEUP    = 1'b0,
    // AXI5-Lite Poison Options
    parameter bit          O_EN_POISON    = 1'b0,
    // AXI5-Lite Parity Conditions
    parameter bit          C_EN_DATACHK   = 1'b0,
    parameter bit          C_EN_CTRLCHK   = 1'b0,
    // AXI5-Lite User Type Options
    parameter type         req_user_t     = user_t,
    parameter type         data_user_t    = user_t,
    parameter type         resp_user_t    = user_t,
    // AXI5-Lite Subsystem ID Options
    parameter int unsigned SUBSYSID_WIDTH = 0,
    // AXI5-Lite Write Strobe Options
    parameter bit          O_EN_STRB      = 1'b1,
    // AXI5-Lite Response Options
    parameter int unsigned BRESP_WIDTH    = 2,
    parameter int unsigned RRESP_WIDTH    = 2
) (
    // GLOBAL
    input logic ACLK,
    input logic ARESETn
);

  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;
  localparam int unsigned POISON_WIDTH = (DATA_WIDTH + 63) / 64;
  localparam int unsigned USER_REQ_WIDTH = O_EN_USER ? $bits(req_user_t) : 0;
  localparam int unsigned USER_DATA_WIDTH = O_EN_USER ? $bits(data_user_t) : 0;
  localparam int unsigned USER_RESP_WIDTH = O_EN_USER ? $bits(resp_user_t) : 0;
  localparam bit EN_DATACHK = C_EN_DATACHK || C_EN_CTRLCHK;

  // OPTIONAL
  localparam int unsigned ID_W_STORAGE_WIDTH = ID_W_WIDTH > 0 ? ID_W_WIDTH : 1;
  localparam int unsigned ID_R_STORAGE_WIDTH = ID_R_WIDTH > 0 ? ID_R_WIDTH : 1;
  localparam int unsigned SUBSYSID_STORAGE_WIDTH = SUBSYSID_WIDTH > 0 ? SUBSYSID_WIDTH : 1;
  localparam int unsigned BRESP_STORAGE_WIDTH = BRESP_WIDTH > 0 ? BRESP_WIDTH : 1;
  localparam int unsigned RRESP_STORAGE_WIDTH = RRESP_WIDTH > 0 ? RRESP_WIDTH : 1;

  // CONDITIONAL
  localparam int unsigned ADDR_CHK_WIDTH = (ADDR_WIDTH + 7) / 8;
  localparam int unsigned ID_W_CHK_BITS = (ID_W_WIDTH + int'(OO_EN_IDUNQ) + 7) / 8;
  localparam int unsigned ID_R_CHK_BITS = (ID_R_WIDTH + int'(OO_EN_IDUNQ) + 7) / 8;
  localparam int unsigned ID_W_CHK_WIDTH = ID_W_CHK_BITS > 0 ? ID_W_CHK_BITS : 1;
  localparam int unsigned ID_R_CHK_WIDTH = ID_R_CHK_BITS > 0 ? ID_R_CHK_BITS : 1;
  localparam int unsigned REQ_USER_CHK_WIDTH = ($bits(req_user_t) + 7) / 8;
  localparam int unsigned DATA_USER_CHK_WIDTH = ($bits(data_user_t) + 7) / 8;
  localparam int unsigned RESP_USER_CHK_WIDTH = ($bits(resp_user_t) + 7) / 8;
  localparam int unsigned READ_USER_CHK_WIDTH = ($bits(data_user_t) + $bits(resp_user_t) + 7) / 8;
  localparam int unsigned POISON_CHK_WIDTH = (DATA_WIDTH + 511) / 512;

  // TYPES
  typedef struct packed {
    data_user_t data;
    resp_user_t resp;
  } r_user_t;

  // GLOBAL
  logic AWAKEUP;
  logic AWAKEUPCHK;

  // AW
  logic AWVALID;
  logic AWREADY;
  logic [ADDR_WIDTH - 1:0] AWADDR;
  logic [2:0] AWPROT;
  logic [2:0] AWSIZE;
  logic [ID_W_STORAGE_WIDTH - 1:0] AWID;
  logic AWIDUNQ;
  req_user_t AWUSER;
  logic AWTRACE;
  logic [SUBSYSID_STORAGE_WIDTH - 1:0] AWSUBSYSID;
  logic AWVALIDCHK;
  logic AWREADYCHK;
  logic [ADDR_CHK_WIDTH - 1:0] AWADDRCHK;
  logic [ID_W_CHK_WIDTH - 1:0] AWIDCHK;
  logic AWCTLCHK0;
  logic [REQ_USER_CHK_WIDTH - 1:0] AWUSERCHK;
  logic AWTRACECHK;
  logic AWSUBSYSIDCHK;

  // W
  logic WVALID;
  logic WREADY;
  logic [DATA_WIDTH - 1:0] WDATA;
  logic [STRB_WIDTH - 1:0] WSTRB;
  data_user_t WUSER;
  logic WTRACE;
  logic [POISON_WIDTH - 1:0] WPOISON;
  logic WVALIDCHK;
  logic WREADYCHK;
  logic [STRB_WIDTH - 1:0] WDATACHK;
  logic [POISON_WIDTH - 1:0] WSTRBCHK;
  logic [DATA_USER_CHK_WIDTH - 1:0] WUSERCHK;
  logic [POISON_CHK_WIDTH - 1:0] WPOISONCHK;
  logic WTRACECHK;

  // B
  logic BVALID;
  logic BREADY;
  logic [BRESP_STORAGE_WIDTH - 1:0] BRESP;
  logic [ID_W_STORAGE_WIDTH - 1:0] BID;
  logic BIDUNQ;
  resp_user_t BUSER;
  logic BTRACE;
  logic BVALIDCHK;
  logic BREADYCHK;
  logic [ID_W_CHK_WIDTH - 1:0] BIDCHK;
  logic BRESPCHK;
  logic [RESP_USER_CHK_WIDTH - 1:0] BUSERCHK;
  logic BTRACECHK;

  // AR
  logic ARVALID;
  logic ARREADY;
  logic [ADDR_WIDTH - 1:0] ARADDR;
  logic [2:0] ARPROT;
  logic [2:0] ARSIZE;
  logic [ID_R_STORAGE_WIDTH - 1:0] ARID;
  logic ARIDUNQ;
  req_user_t ARUSER;
  logic ARTRACE;
  logic [SUBSYSID_STORAGE_WIDTH - 1:0] ARSUBSYSID;
  logic ARVALIDCHK;
  logic ARREADYCHK;
  logic [ADDR_CHK_WIDTH - 1:0] ARADDRCHK;
  logic [ID_R_CHK_WIDTH - 1:0] ARIDCHK;
  logic ARCTLCHK0;
  logic [REQ_USER_CHK_WIDTH - 1:0] ARUSERCHK;
  logic ARTRACECHK;
  logic ARSUBSYSIDCHK;

  // R
  logic RVALID;
  logic RREADY;
  logic [DATA_WIDTH - 1:0] RDATA;
  logic [RRESP_STORAGE_WIDTH - 1:0] RRESP;
  logic [ID_R_STORAGE_WIDTH - 1:0] RID;
  logic RIDUNQ;
  r_user_t RUSER;
  logic RTRACE;
  logic [POISON_WIDTH - 1:0] RPOISON;
  logic RVALIDCHK;
  logic RREADYCHK;
  logic [ID_R_CHK_WIDTH - 1:0] RIDCHK;
  logic [STRB_WIDTH - 1:0] RDATACHK;
  logic RRESPCHK;
  logic [READ_USER_CHK_WIDTH - 1:0] RUSERCHK;
  logic [POISON_CHK_WIDTH - 1:0] RPOISONCHK;
  logic RTRACECHK;

  // SLAVE
  modport sink(
      input ACLK, ARESETn,
      input AWAKEUP, AWAKEUPCHK,
      input AWVALID, AWADDR, AWPROT, AWSIZE, AWID, AWIDUNQ, AWUSER, AWTRACE, AWSUBSYSID,
            AWVALIDCHK, AWADDRCHK, AWIDCHK, AWCTLCHK0, AWUSERCHK, AWTRACECHK, AWSUBSYSIDCHK,
      output AWREADY, AWREADYCHK,
      input WVALID, WDATA, WSTRB, WUSER, WTRACE, WPOISON, WVALIDCHK, WDATACHK, WSTRBCHK,
            WUSERCHK, WPOISONCHK, WTRACECHK,
      output WREADY, WREADYCHK,
      input BREADY, BREADYCHK,
      output BVALID, BRESP, BID, BIDUNQ, BUSER, BTRACE, BVALIDCHK, BIDCHK, BRESPCHK, BUSERCHK,
             BTRACECHK,
      input ARVALID, ARADDR, ARPROT, ARSIZE, ARID, ARIDUNQ, ARUSER, ARTRACE, ARSUBSYSID,
            ARVALIDCHK, ARADDRCHK, ARIDCHK, ARCTLCHK0, ARUSERCHK, ARTRACECHK, ARSUBSYSIDCHK,
      output ARREADY, ARREADYCHK,
      input RREADY, RREADYCHK,
      output RVALID, RDATA, RRESP, RID, RIDUNQ, RUSER, RTRACE, RPOISON, RVALIDCHK, RIDCHK,
             RDATACHK, RRESPCHK, RUSERCHK, RPOISONCHK, RTRACECHK
  );

  // MASTER
  modport source(
      input ACLK, ARESETn,
      output AWAKEUP, AWAKEUPCHK,
      output AWVALID, AWADDR, AWPROT, AWSIZE, AWID, AWIDUNQ, AWUSER, AWTRACE, AWSUBSYSID,
             AWVALIDCHK, AWADDRCHK, AWIDCHK, AWCTLCHK0, AWUSERCHK, AWTRACECHK, AWSUBSYSIDCHK,
      input AWREADY, AWREADYCHK,
      output WVALID, WDATA, WSTRB, WUSER, WTRACE, WPOISON, WVALIDCHK, WDATACHK, WSTRBCHK,
             WUSERCHK, WPOISONCHK, WTRACECHK,
      input WREADY, WREADYCHK,
      output BREADY, BREADYCHK,
      input BVALID, BRESP, BID, BIDUNQ, BUSER, BTRACE, BVALIDCHK, BIDCHK, BRESPCHK, BUSERCHK,
            BTRACECHK,
      output ARVALID, ARADDR, ARPROT, ARSIZE, ARID, ARIDUNQ, ARUSER, ARTRACE, ARSUBSYSID,
             ARVALIDCHK, ARADDRCHK, ARIDCHK, ARCTLCHK0, ARUSERCHK, ARTRACECHK, ARSUBSYSIDCHK,
      input ARREADY, ARREADYCHK,
      output RREADY, RREADYCHK,
      input RVALID, RDATA, RRESP, RID, RIDUNQ, RUSER, RTRACE, RPOISON, RVALIDCHK, RIDCHK,
            RDATACHK, RRESPCHK, RUSERCHK, RPOISONCHK, RTRACECHK
  );

  // MONITOR
  modport monitor(
      input ACLK, ARESETn, AWAKEUP, AWAKEUPCHK,
      input AWVALID, AWADDR, AWPROT, AWSIZE, AWID, AWIDUNQ, AWUSER, AWTRACE, AWSUBSYSID,
            AWVALIDCHK, AWADDRCHK, AWIDCHK, AWCTLCHK0, AWUSERCHK, AWTRACECHK, AWSUBSYSIDCHK,
            AWREADY, AWREADYCHK,
      input WVALID, WDATA, WSTRB, WUSER, WTRACE, WPOISON, WVALIDCHK, WDATACHK, WSTRBCHK,
            WUSERCHK, WPOISONCHK, WTRACECHK, WREADY, WREADYCHK,
      input BREADY, BREADYCHK, BVALID, BRESP, BID, BIDUNQ, BUSER, BTRACE, BVALIDCHK, BIDCHK,
            BRESPCHK, BUSERCHK, BTRACECHK,
      input ARVALID, ARADDR, ARPROT, ARSIZE, ARID, ARIDUNQ, ARUSER, ARTRACE, ARSUBSYSID,
            ARVALIDCHK, ARADDRCHK, ARIDCHK, ARCTLCHK0, ARUSERCHK, ARTRACECHK, ARSUBSYSIDCHK,
            ARREADY, ARREADYCHK,
      input RREADY, RREADYCHK, RVALID, RDATA, RRESP, RID, RIDUNQ, RUSER, RTRACE, RPOISON,
            RVALIDCHK, RIDCHK, RDATACHK, RRESPCHK, RUSERCHK, RPOISONCHK, RTRACECHK
  );

  // CHECKS
  initial begin : check_parameters
    if (DATA_WIDTH < 8 || DATA_WIDTH > 1024 || (DATA_WIDTH & (DATA_WIDTH - 1)) != 0)
      $fatal(1, "axi5_lite_if: DATA_WIDTH must be a power of two from 8 through 1024");
    if (ADDR_WIDTH < 1 || ADDR_WIDTH > 64)
      $fatal(1, "axi5_lite_if: ADDR_WIDTH must be from 1 through 64");
    if (ID_W_WIDTH > 32 || ID_R_WIDTH > 32)
      $fatal(1, "axi5_lite_if: ID_W_WIDTH and ID_R_WIDTH must be from 0 through 32");
    if (SUBSYSID_WIDTH > 8) $fatal(1, "axi5_lite_if: SUBSYSID_WIDTH must be from 0 through 8");
    if (!(BRESP_WIDTH == 0 || BRESP_WIDTH == 2 || BRESP_WIDTH == 3))
      $fatal(1, "axi5_lite_if: BRESP_WIDTH must be 0, 2, or 3");
    if (!(RRESP_WIDTH == 0 || RRESP_WIDTH == 2 || RRESP_WIDTH == 3))
      $fatal(1, "axi5_lite_if: RRESP_WIDTH must be 0, 2, or 3");
  end

endinterface
