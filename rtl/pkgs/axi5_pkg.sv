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
    BRESP_OKAY        = {1'b0, RESP_OKAY},
    BRESP_EXOKAY      = {1'b0, RESP_EXOKAY},
    BRESP_SLVERR      = {1'b0, RESP_SLVERR},
    BRESP_DECERR      = {1'b0, RESP_DECERR},
    BRESP_DEFER       = 3'b100,
    BRESP_TRANSFAULT  = 3'b101,
    BRESP_UNSUPPORTED = 3'b111
  } bresp_e;

  // AXI5 EXTENDED READ RESPONSE
  typedef enum logic [2:0] {
    RRESP_OKAY       = {1'b0, RESP_OKAY},
    RRESP_EXOKAY     = {1'b0, RESP_EXOKAY},
    RRESP_SLVERR     = {1'b0, RESP_SLVERR},
    RRESP_DECERR     = {1'b0, RESP_DECERR},
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
  typedef logic [2:0] prot_t;

  typedef enum prot_t {
    PROT_PRIVILEGED  = 3'b001,
    PROT_NON_SECURE  = 3'b010,
    PROT_INSTRUCTION = 3'b100
  } prot_e;

  // LEN (TRANSFERS - 1)
  typedef logic [7:0] len_t;

  // QOS
  typedef logic [3:0] qos_t;

  // REGION
  typedef logic [3:0] region_t;

  // SUBSYSTEM
  typedef logic [7:0] max_subsystem_id_t;

  // helpers
  localparam int unsigned LiteMaxDataWidth = 1024;
  typedef logic [LiteMaxDataWidth / 8 - 1:0] lite_lane_mask_t;

  function automatic bit lite_widths_valid(input int unsigned addr_width,
                                           input int unsigned data_width);
    return addr_width >= 1 && addr_width <= 64 && data_width >= 8 &&
           data_width <= LiteMaxDataWidth && (data_width & (data_width - 1)) == 0;
  endfunction

  function automatic lite_lane_mask_t lite_byte_lanes(input logic [63:0] addr, input size_e size,
                                                      input int unsigned data_width);
    int unsigned first_lane, limit_lane;
    lite_lane_mask_t mask;
    first_lane = int'(addr) & (data_width / 8 - 1);
    limit_lane = ((first_lane >> size) + 1) << size;
    for (int unsigned lane = 0; lane < LiteMaxDataWidth / 8; lane++)
    mask[lane] = (lane < data_width / 8) && (lane >= first_lane) && (lane < limit_lane);
    return mask;
  endfunction

endpackage
