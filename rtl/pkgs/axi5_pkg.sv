package axi5_pkg;

  // RESPONSE
  typedef enum logic [1:0] {
    RESP_OKAY   = 2'b00,
    RESP_EXOKAY = 2'b01,
    RESP_SLVERR = 2'b10,
    RESP_DECERR = 2'b11
  } resp_e;

  // AXI5 EXTENDED WRITE RESPONSE
  typedef enum logic [2:0] {
    BRESP_OKAY        = 3'b000,
    BRESP_EXOKAY      = 3'b001,
    BRESP_SLVERR      = 3'b010,
    BRESP_DECERR      = 3'b011,
    BRESP_DEFER       = 3'b100,
    BRESP_TRANSFAULT  = 3'b101,
    BRESP_UNSUPPORTED = 3'b111
  } bresp_e;

  // AXI5 EXTENDED READ RESPONSE
  typedef enum logic [2:0] {
    RRESP_OKAY       = 3'b000,
    RRESP_EXOKAY     = 3'b001,
    RRESP_SLVERR     = 3'b010,
    RRESP_DECERR     = 3'b011,
    RRESP_PREFETCHED = 3'b100,
    RRESP_TRANSFAULT = 3'b101,
    RRESP_OKAYDIRTY  = 3'b110
  } rresp_e;

  // BURST
  typedef enum logic [1:0] {
    BURST_FIXED = 2'b00,
    BURST_INCR  = 2'b01,
    BURST_WRAP  = 2'b10
  } burst_e;

  // SIZE
  typedef enum logic [2:0] {
    SIZE_1B   = 3'b000,
    SIZE_2B   = 3'b001,
    SIZE_4B   = 3'b010,
    SIZE_8B   = 3'b011,
    SIZE_16B  = 3'b100,
    SIZE_32B  = 3'b101,
    SIZE_64B  = 3'b110,
    SIZE_128B = 3'b111
  } size_e;

  // PROT
  typedef struct packed {
    logic instruction;
    logic non_secure;
    logic privileged;
  } prot_t;

  // LEN (TRANSFERS - 1)
  typedef logic [7:0] len_t;

  // QOS
  typedef logic [3:0] qos_t;

  // REGION
  typedef logic [3:0] region_t;

endpackage
