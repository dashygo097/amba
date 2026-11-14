`include "cc/registers.svh"
`include "cc/assertions.svh"
`include "cc/register_bank.svh"

module axi5_lite_slv_regs #(
    // WIDTHS
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,

    // REGISTER MAP
    parameter int unsigned NUM_REGS = 1,
    localparam type addr_t = logic [ADDR_WIDTH - 1:0],
    localparam type data_t = logic [DATA_WIDTH - 1:0],
    localparam type strb_t = logic [DATA_WIDTH / 8 - 1:0],
    localparam type reg_cfg_t = `CC_REG_BANK_CFG_TYPE(addr_t, data_t),
    parameter addr_t BASE_ADDR = '0,
    parameter reg_cfg_t [NUM_REGS - 1:0] REG_CFG = '0,
    localparam type req_t = `CC_REG_BANK_REQ_TYPE(addr_t, data_t, strb_t),
    localparam type resp_t = `CC_REG_BANK_RESP_TYPE(data_t)
) (
    axi5_lite_if.sink axi
);
  localparam int unsigned StrbWidth = DATA_WIDTH / 8;

endmodule
