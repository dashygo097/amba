`include "amba/axi5_lite.svh"

package axi5_verify_pkg;
  typedef enum bit [1:0] {
    LITE_NOT_STARTED,
    LITE_ACTIVE,
    LITE_COMPLETED,
    LITE_RESET
  } lite_status_e;

  virtual class lite_types #(
      parameter  int unsigned ADDR_WIDTH     = 32,
      parameter  int unsigned DATA_WIDTH     = 32,
      parameter  int unsigned ID_W_WIDTH     = 0,
      parameter  int unsigned ID_R_WIDTH     = 0,
      parameter  int unsigned SUBSYSID_WIDTH = 0,
      parameter  type req_user_t             = logic,
      parameter  type data_user_t            = logic,
      parameter  type resp_user_t            = logic,
      localparam type r_user_t               = `AMBA_AXI5_LITE_R_USER_TYPE(data_user_t, resp_user_t)
  );
    localparam int unsigned WriteIdWidth = ID_W_WIDTH > 0 ? ID_W_WIDTH : 1;
    localparam int unsigned ReadIdWidth = ID_R_WIDTH > 0 ? ID_R_WIDTH : 1;
    localparam int unsigned SubsysIdWidth = SUBSYSID_WIDTH > 0 ? SUBSYSID_WIDTH : 1;
    typedef `AMBA_AXI5_LITE_AW_PAYLOAD_TYPE(ADDR_WIDTH, WriteIdWidth, SubsysIdWidth,
      req_user_t) aw_t;
    typedef `AMBA_AXI5_LITE_W_PAYLOAD_TYPE(DATA_WIDTH,
      data_user_t) w_t;
    typedef `AMBA_AXI5_LITE_B_PAYLOAD_TYPE(WriteIdWidth,
      resp_user_t) b_t;
    typedef `AMBA_AXI5_LITE_AR_PAYLOAD_TYPE(ADDR_WIDTH, ReadIdWidth, SubsysIdWidth,
      req_user_t) ar_t;
    typedef `AMBA_AXI5_LITE_R_PAYLOAD_TYPE(DATA_WIDTH, ReadIdWidth,
      r_user_t) r_t;
    typedef logic [ADDR_WIDTH - 1:0] addr_t;
    typedef logic [DATA_WIDTH - 1:0] data_t;
    typedef logic [DATA_WIDTH / 8 - 1:0] strb_t;
    typedef logic [WriteIdWidth - 1:0] aw_id_t;
    typedef logic [ReadIdWidth - 1 :0] ar_id_t;
    typedef logic [SubsysIdWidth - 1:0] subsys_id_t;

    static function strb_t byte_lanes(input addr_t addr, input axi5_pkg::size_e size);
      return strb_t'(axi5_pkg::lite_byte_lanes(64'(addr), size, DATA_WIDTH));
    endfunction
  endclass

  class channel_coverage #(
      type payload_t
  );
    payload_t ones_seen = '0;
    payload_t zeros_seen = '0;
    longint unsigned transfers = 0;
    longint unsigned stalls = 0;

    function void sample (input logic valid, input logic ready, input payload_t payload);
      if (valid && !ready) stalls++;
      if (valid && ready) begin
        transfers++;
        ones_seen |= payload;
        zeros_seen |= ~payload;
      end
    endfunction

    function bit exercised(input payload_t mask);
      return (ones_seen & zeros_seen & mask) === mask;
    endfunction
  endclass
endpackage
