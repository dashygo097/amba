`include "cc/assertions.svh"
`include "amba/axi5_lite.svh"

interface axi5_lite_if #(
    parameter  int unsigned DATA_WIDTH     = 32,
    parameter  int unsigned ADDR_WIDTH     = 32,
    // AXI5-Lite Data Bus Width Options
    parameter  bit          O_EN_SIZE      = 1'b0,
    // AXI5-Lite Write Strobe Options
    parameter  bit          O_EN_STRB      = 1'b1,
    // AXI5-Lite Prot Options
    parameter  bit          OI_EN_PROT     = 1'b0,
    // AXI5-Lite ID Options
    parameter  bit          OO_EN_ID       = 1'b0,
    parameter  int unsigned ID_WIDTH       = 1,
    parameter  int unsigned ID_W_WIDTH     = OO_EN_ID ? ID_WIDTH : 1,
    parameter  int unsigned ID_R_WIDTH     = OO_EN_ID ? ID_WIDTH : 1,
    // AXI5-Lite User Options
    parameter  bit          O_EN_USER      = 1'b0,
    parameter  type         req_user_t     = logic,
    parameter  type         data_user_t    = logic,
    parameter  type         resp_user_t    = logic,
    localparam type         r_user_t       = `AMBA_AXI5_LITE_R_USER_TYPE(data_user_t, resp_user_t),
    // AXI5-Lite Tracing Conditions
    parameter  bit          C_EN_TRACE     = 1'b0,
    // AXI5-Lite Unique ID Options
    parameter  bit          OO_EN_IDUNQ    = 1'b0,
    // AXI5-Lite Wakeup Options
    parameter  bit          O_EN_WAKEUP    = 1'b0,
    // AXI5-Lite Subsystem ID Options
    parameter  bit          O_EN_SUBSYSTEM = 1'b0,
    parameter  int unsigned SUBSYSID_WIDTH = 1
) (
    // GLOBAL
    input logic ACLK,
    input logic ARESETn
);

  localparam int unsigned StrbWidth = DATA_WIDTH / 8;

  // OPTIONAL
  localparam int unsigned IdWStorageWidth = ID_W_WIDTH > 0 ? ID_W_WIDTH : 1;
  localparam int unsigned IdRStorageWidth = ID_R_WIDTH > 0 ? ID_R_WIDTH : 1;
  localparam int unsigned SubsysIdStorageWidth = SUBSYSID_WIDTH > 0 ? SUBSYSID_WIDTH : 1;

  // GLOBAL
  logic AWAKEUP;

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

  // W
  logic WVALID;
  logic WREADY;
  logic [DATA_WIDTH - 1:0] WDATA;
  logic [StrbWidth - 1:0] WSTRB;
  data_user_t WUSER;
  logic WTRACE;

  // B
  logic BVALID;
  logic BREADY;
  axi5_pkg::bresp_e BRESP;
  logic [IdWStorageWidth - 1:0] BID;
  logic BIDUNQ;
  resp_user_t BUSER;
  logic BTRACE;

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

  // R
  logic RVALID;
  logic RREADY;
  logic [DATA_WIDTH - 1:0] RDATA;
  axi5_pkg::rresp_e RRESP;
  logic [IdRStorageWidth - 1:0] RID;
  logic RIDUNQ;
  r_user_t RUSER;
  logic RTRACE;

  // SLAVE
  modport sink(
      input ACLK, ARESETn,
      input AWAKEUP,
      input AWVALID, AWADDR, AWPROT, AWSIZE, AWID, AWIDUNQ, AWUSER, AWTRACE, AWSUBSYSID,
      output AWREADY,
      input WVALID, WDATA, WSTRB, WUSER, WTRACE,
      output WREADY,
      input BREADY,
      output BVALID, BRESP, BID, BIDUNQ, BUSER, BTRACE,
      input ARVALID, ARADDR, ARPROT, ARSIZE, ARID, ARIDUNQ, ARUSER, ARTRACE, ARSUBSYSID,
      output ARREADY,
      input RREADY,
      output RVALID, RDATA, RRESP, RID, RIDUNQ, RUSER, RTRACE
  );

  // MASTER
  modport source(
      input ACLK, ARESETn,
      output AWAKEUP,
      output AWVALID, AWADDR, AWPROT, AWSIZE, AWID, AWIDUNQ, AWUSER, AWTRACE, AWSUBSYSID,
      input AWREADY,
      output WVALID, WDATA, WSTRB, WUSER, WTRACE,
      input WREADY,
      output BREADY,
      input BVALID, BRESP, BID, BIDUNQ, BUSER, BTRACE,
      output ARVALID, ARADDR, ARPROT, ARSIZE, ARID, ARIDUNQ, ARUSER, ARTRACE, ARSUBSYSID,
      input ARREADY,
      output RREADY,
      input RVALID, RDATA, RRESP, RID, RIDUNQ, RUSER, RTRACE
  );

  // MONITOR
  modport monitor(
      input ACLK, ARESETn, AWAKEUP,
      input AWVALID, AWADDR, AWPROT, AWSIZE, AWID, AWIDUNQ, AWUSER, AWTRACE, AWSUBSYSID, AWREADY,
      input WVALID, WDATA, WSTRB, WUSER, WTRACE, WREADY,
      input BREADY, BVALID, BRESP, BID, BIDUNQ, BUSER, BTRACE,
      input ARVALID, ARADDR, ARPROT, ARSIZE, ARID, ARIDUNQ, ARUSER, ARTRACE, ARSUBSYSID, ARREADY,
      input RREADY, RVALID, RDATA, RRESP, RID, RIDUNQ, RUSER, RTRACE
  );

  // CHECKS
  `ASSERT_INIT(DataWidthValid,
               DATA_WIDTH >= 8 && DATA_WIDTH <= 1024 && (DATA_WIDTH & (DATA_WIDTH - 1)) == 0)
  `ASSERT_INIT(AddressWidthValid, ADDR_WIDTH >= 1 && ADDR_WIDTH <= 64)
  `ASSERT_INIT(WriteIdWidthValid, ID_W_WIDTH <= 32)
  `ASSERT_INIT(ReadIdWidthValid, ID_R_WIDTH <= 32)
  `ASSERT_INIT(SubsysIdWidthValid, SUBSYSID_WIDTH <= 8)

endinterface
