`include "mycpu.h"

module wb_stage
#(
    parameter TLBNUM = 16
)
(
    input                           clk            ,
    input                           reset          ,
    //allowin
    output                          ws_allowin     ,
    //from ms
    input                           ms_to_ws_valid ,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus   ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus   ,
    //to ds
    output [4:0]                    ws_dest        ,
    output reg                      ws_valid       ,
    output                          ws_gr_we       ,
    output [31:0]                   ws_final_result,
    // to ms
    output [31:0]                   ws_rt_value    ,
    output [4:0]                    ws_rt          ,          
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    //exception
    output [4:0]                    ws_rd          , 
    output                          ws_inst_in_slot,     
    output [31:0]                   ws_pc          ,
    output                          ws_mtc0_op     , 
    output                          ws_mfc0_op     ,
    output                          ws_eret_cmt    , 
    output [14:0]                   ws_exception_cmt,
    output                          ws_reflush     ,
    input  [31:0]                   ws_mfc0_data   ,
    output [31:0]                   ws_badvaddr    ,
    input  [31:0]                   cp0_epc        ,
    output [31:0]                   exception_pc   ,
    // TLB
    output                          tlbp_op        ,
    output                          tlbp_index_p   ,
    output [5:0]                    tlbp_index_index,
    output                          tlbr_op        ,
    output                          tlbwi_op       
);


wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;

wire [4:0] wb_rt;

wire [31:0] ws_final_result_temp;
wire [14:0] es_to_ws_exception_cmt;
wire es_to_ws_eret_cmt;

wire [31:0] ws_alu_result;
wire [31:0] ws_badvaddr_temp;


wire        ws_mtc0_op_temp;
wire ws_refetch;
wire ws_tlbp_op;
wire ws_tlbr_op;
wire ws_tlbwi_op;
wire [$clog2(TLBNUM)-1:0] ws_tlbp_index;
wire ws_tlbp_found;

assign tlbp_op = ws_tlbp_op && ws_valid;
assign tlbp_index_p = ~ws_tlbp_found;
assign tlbp_index_index = ws_tlbp_index;
assign tlbr_op = ws_tlbr_op && ws_valid;
assign tlbwi_op = ws_tlbwi_op && ws_valid;

assign {ws_tlbwi_op              ,// 1
        ws_tlbr_op               ,// 1
        ws_tlbp_index            ,// 4
        ws_tlbp_found            ,// 1
        ws_tlbp_op               ,// 1
        ws_refetch               ,// 1
        ws_alu_result            ,// 32
        ws_rd                    ,// 5
        ws_inst_in_slot          ,// 1
        es_to_ws_exception_cmt   ,// 15
        ws_mtc0_op_temp          ,// 1
        ws_mfc0_op               ,// 1
        es_to_ws_eret_cmt        ,// 1
        ws_rt                    ,// 5
        ws_rt_value              ,// 32
        ws_gr_we                 ,// 1
        ws_dest                  ,// 5
        ws_final_result_temp     ,// 32
        ws_pc                     // 32
       } = ms_to_ws_bus_r;

assign ws_exception_cmt = ws_valid ? es_to_ws_exception_cmt : 15'b0;

assign ws_badvaddr = ws_exception_cmt[1] || ws_exception_cmt[6] || ws_exception_cmt[9:8] ? ws_pc : ws_alu_result;

assign ws_mtc0_op = ws_mtc0_op_temp && ws_valid;


wire ws_tlb_exception;
assign ws_tlb_exception = |ws_exception_cmt[10:8];



assign ws_eret_cmt      = es_to_ws_eret_cmt && ws_valid;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset || ws_reflush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign ws_final_result = ws_mfc0_op ? ws_mfc0_data : ws_final_result_temp;

// exception pipeline ws_reflush


assign ws_reflush = ws_valid && (ws_eret_cmt || ws_exception_cmt || ws_refetch);
assign exception_pc = ws_refetch ? ws_pc + 32'h4:
                      ws_exception_cmt[8] || ws_exception_cmt[10] || ws_exception_cmt[12] ? 32'hbfc00200 :
                      ws_exception_cmt    ? 32'hbfc00380 : 
                      cp0_epc;


assign rf_we    = ws_gr_we && ws_valid && !(ws_eret_cmt || ws_exception_cmt);
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
