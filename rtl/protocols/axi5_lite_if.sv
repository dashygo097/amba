`include "cc/assertions.svh"

interface axi5_lite_if #(
    parameter  int unsigned DATA_WIDTH     = 32,
    parameter  int unsigned ADDR_WIDTH     = 32,
    // AXI5-Lite Data Bus Width Options
    parameter  bit          O_EN_SIZE      = 1'b0,
    // AXI5-Lite Prot Options
    parameter  bit          OI_EN_PROT     = 1'b0,
    // AXI5-Lite ID Options
    parameter  bit          OO_EN_ID       = 1'b0,
    parameter  int unsigned ID_WIDTH       = 1,
    parameter  int unsigned ID_W_WIDTH     = OO_EN_ID ? ID_WIDTH : 0,
    parameter  int unsigned ID_R_WIDTH     = OO_EN_ID ? ID_WIDTH : 0,
    // AXI5-Lite User Options
    parameter  bit          O_EN_USER      = 1'b0,
    parameter  type         req_user_t     = logic,
    parameter  type         data_user_t    = logic,
    parameter  type         resp_user_t    = logic,
    // verilog_lint: waive typedef-structs-unions
    localparam type         r_user_t       = struct packed {data_user_t data; resp_user_t resp;},
    // AXI5-Lite Tracing Conditions
    parameter  bit          C_EN_TRACE     = 1'b0,
    // AXI5-Lite Unique ID Options
    parameter  bit          OO_EN_IDUNQ    = 1'b0,
    // AXI5-Lite Wakeup Options
    parameter  bit          O_EN_WAKEUP    = 1'b0,
    // AXI5-Lite Poison Options
    parameter  bit          O_EN_POISON    = 1'b0,
    // AXI5-Lite Parity Conditions
    parameter  bit          C_EN_DATACHK   = 1'b0,
    parameter  bit          C_EN_CTRLCHK   = 1'b0,
    // AXI5-Lite Subsystem ID Options
    parameter  int unsigned SUBSYSID_WIDTH = 0,
    // AXI5-Lite Write Strobe Options
    parameter  bit          O_EN_STRB      = 1'b1
) (
    // GLOBAL
    input logic ACLK,
    input logic ARESETn
);

  localparam int unsigned StrbWidth = DATA_WIDTH / 8;
  localparam int unsigned PoisonWidth = (DATA_WIDTH + 63) / 64;
  localparam int unsigned UserReqWidth = O_EN_USER ? $bits(req_user_t) : 0;
  localparam int unsigned UserDataWidth = O_EN_USER ? $bits(data_user_t) : 0;
  localparam int unsigned UserRespWidth = O_EN_USER ? $bits(resp_user_t) : 0;
  localparam bit EnDataChk = C_EN_DATACHK || C_EN_CTRLCHK;

  // OPTIONAL
  localparam int unsigned IdWStorageWidth = ID_W_WIDTH > 0 ? ID_W_WIDTH : 1;
  localparam int unsigned IdRStorageWidth = ID_R_WIDTH > 0 ? ID_R_WIDTH : 1;
  localparam int unsigned SubsysIdStorageWidth = SUBSYSID_WIDTH > 0 ? SUBSYSID_WIDTH : 1;

  // CONDITIONAL
  localparam int unsigned AddrChkWidth = (ADDR_WIDTH + 7) / 8;
  localparam int unsigned IdWChkBits = (ID_W_WIDTH + int'(OO_EN_IDUNQ) + 7) / 8;
  localparam int unsigned IdRChkBits = (ID_R_WIDTH + int'(OO_EN_IDUNQ) + 7) / 8;
  localparam int unsigned IdWChkWidth = IdWChkBits > 0 ? IdWChkBits : 1;
  localparam int unsigned IdRChkWidth = IdRChkBits > 0 ? IdRChkBits : 1;
  localparam int unsigned ReqUserChkWidth = ($bits(req_user_t) + 7) / 8;
  localparam int unsigned DataUserChkWidth = ($bits(data_user_t) + 7) / 8;
  localparam int unsigned RespUserChkWidth = ($bits(resp_user_t) + 7) / 8;
  localparam int unsigned ReadUserChkWidth = ($bits(r_user_t) + 7) / 8;
  localparam int unsigned PoisonChkWidth = (DATA_WIDTH + 511) / 512;

  // GLOBAL
  logic AWAKEUP;
  logic AWAKEUPCHK;

  // AW
  logic AWVALID;
  logic AWREADY;
  logic [ADDR_WIDTH - 1:0] AWADDR;
  axi5_pkg::prot_t AWPROT;
  axi5_pkg::size_e AWSIZE;
  logic [IdWStorageWidth - 1:0] AWID;
  logic AWIDUNQ;
  req_user_t AWUSER;
  logic AWTRACE;
  logic [SubsysIdStorageWidth - 1:0] AWSUBSYSID;
  logic AWVALIDCHK;
  logic AWREADYCHK;
  logic [AddrChkWidth - 1:0] AWADDRCHK;
  logic [IdWChkWidth - 1:0] AWIDCHK;
  logic AWCTLCHK0;
  logic [ReqUserChkWidth - 1:0] AWUSERCHK;
  logic AWTRACECHK;
  logic AWSUBSYSIDCHK;

  // W
  logic WVALID;
  logic WREADY;
  logic [DATA_WIDTH - 1:0] WDATA;
  logic [StrbWidth - 1:0] WSTRB;
  data_user_t WUSER;
  logic WTRACE;
  logic [PoisonWidth - 1:0] WPOISON;
  logic WVALIDCHK;
  logic WREADYCHK;
  logic [StrbWidth - 1:0] WDATACHK;
  logic [PoisonWidth - 1:0] WSTRBCHK;
  logic [DataUserChkWidth - 1:0] WUSERCHK;
  logic [PoisonChkWidth - 1:0] WPOISONCHK;
  logic WTRACECHK;

  // B
  logic BVALID;
  logic BREADY;
  axi5_pkg::bresp_e BRESP;
  logic [IdWStorageWidth - 1:0] BID;
  logic BIDUNQ;
  resp_user_t BUSER;
  logic BTRACE;
  logic BVALIDCHK;
  logic BREADYCHK;
  logic [IdWChkWidth - 1:0] BIDCHK;
  logic BRESPCHK;
  logic [RespUserChkWidth - 1:0] BUSERCHK;
  logic BTRACECHK;

  // AR
  logic ARVALID;
  logic ARREADY;
  logic [ADDR_WIDTH - 1:0] ARADDR;
  axi5_pkg::prot_t ARPROT;
  axi5_pkg::size_e ARSIZE;
  logic [IdRStorageWidth - 1:0] ARID;
  logic ARIDUNQ;
  req_user_t ARUSER;
  logic ARTRACE;
  logic [SubsysIdStorageWidth - 1:0] ARSUBSYSID;
  logic ARVALIDCHK;
  logic ARREADYCHK;
  logic [AddrChkWidth - 1:0] ARADDRCHK;
  logic [IdRChkWidth - 1:0] ARIDCHK;
  logic ARCTLCHK0;
  logic [ReqUserChkWidth - 1:0] ARUSERCHK;
  logic ARTRACECHK;
  logic ARSUBSYSIDCHK;

  // R
  logic RVALID;
  logic RREADY;
  logic [DATA_WIDTH - 1:0] RDATA;
  axi5_pkg::rresp_e RRESP;
  logic [IdRStorageWidth - 1:0] RID;
  logic RIDUNQ;
  r_user_t RUSER;
  logic RTRACE;
  logic [PoisonWidth - 1:0] RPOISON;
  logic RVALIDCHK;
  logic RREADYCHK;
  logic [IdRChkWidth - 1:0] RIDCHK;
  logic [StrbWidth - 1:0] RDATACHK;
  logic RRESPCHK;
  logic [ReadUserChkWidth - 1:0] RUSERCHK;
  logic [PoisonChkWidth - 1:0] RPOISONCHK;
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
  `ASSERT_INIT(DataWidthValid,
               DATA_WIDTH >= 8 && DATA_WIDTH <= 1024 && (DATA_WIDTH & (DATA_WIDTH - 1)) == 0)
  `ASSERT_INIT(AddressWidthValid, ADDR_WIDTH >= 1 && ADDR_WIDTH <= 64)
  `ASSERT_INIT(WriteIdWidthValid, ID_W_WIDTH <= 32)
  `ASSERT_INIT(ReadIdWidthValid, ID_R_WIDTH <= 32)
  `ASSERT_INIT(SubsysIdWidthValid, SUBSYSID_WIDTH <= 8)

endinterface
