`include "mycpu.h"

module mem_stage
#(
    parameter TLBNUM = 16
)
(
    input                          clk             ,
    input                          reset           ,
    input                          resetn          ,
    //allowin
    input                          ws_allowin      ,
    output                         ms_allowin      ,
    //from es
    input                          es_to_ms_valid  ,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus    ,
    //to ws
    output                         ms_to_ws_valid  ,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus    ,
    //to ds
    output [4:0]                    ms_dest        ,
    output reg                      ms_valid       ,
    output                          ms_gr_we       ,
    output                          ms_load_op     ,
    output                          ms_ready_go    ,
    output [31:0]                   ms_final_result,   
    // from ws
    input [31:0]                    ws_rt_value    ,          
    input [4:0]                     ws_rt          ,          
    // data sram-like interface
    input  [31:0]                  data_rdata    ,
    input                          data_data_ok  ,
    //exception
    input                          ws_reflush      ,
    output                         ms_reflush      ,
    output                         ms_mfc0_op      ,
    // TLB
    output                         ms_mtc0_op
);

wire [4:0]  ms_rd;
wire        ms_inst_in_slot;
wire        ms_eret_cmt;
wire [14:0] ms_exception_cmt;

// wire        ms_ready_go;

wire        ms_mtc0_op_temp;
assign      ms_mtc0_op = ms_mtc0_op_temp && ms_valid;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire        ms_hi_read;
wire        ms_lo_read;
wire        ms_hi_write;
wire        ms_lo_write;

wire [3:0]  ms_mem_num;
wire        ms_unaligned_mem_acc_regl;
wire        ms_unaligned_mem_acc_regr;
wire        ms_mem_sign_ext;
wire [31:0] ms_rt_value;
wire [31:0] ms_rt_data;
wire [4:0]  ms_rt;
wire        ms_need_ades;
wire        ms_need_adel;
wire        ms_ade_1;
wire        ms_ade_2;

// lab 11 newly added
// wire       ms_load_op;
assign     ms_load_op = ms_res_from_mem;

// reg ms_valid;

wire ms_refetch;
wire ms_tlbp_op;
wire ms_tlbr_op;
wire ms_tlbwi_op;
wire ms_tlbp_found;
wire [$clog2(TLBNUM)-1:0] ms_tlbp_index;

assign {ms_tlbwi_op              ,
        ms_tlbr_op               ,
        ms_tlbp_index            ,
        ms_tlbp_found            ,
        ms_tlbp_op               ,
        ms_refetch               ,
        ms_ade_1                 ,
        ms_ade_2                 ,
        ms_need_ades             ,
        ms_need_adel             ,
        ms_rd                    ,
        ms_inst_in_slot          ,
        ms_exception_cmt         ,
        ms_mtc0_op_temp          ,
        ms_mfc0_op               ,
        ms_eret_cmt              ,
        ms_rt                    ,
        ms_hi_read               ,
        ms_lo_read               ,
        ms_hi_write              ,
        ms_lo_write              ,
        ms_rt_value              ,
        ms_unaligned_mem_acc_regl,
        ms_unaligned_mem_acc_regr,
        ms_mem_sign_ext          ,
        ms_mem_num               ,
        ms_res_from_mem          ,
        ms_gr_we                 ,
        ms_dest                  ,
        ms_alu_result            ,
        ms_pc                     
       } = es_to_ms_bus_r;


assign ms_to_ws_bus = {ms_tlbwi_op              ,
                       ms_tlbr_op               ,
                       ms_tlbp_index            ,
                       ms_tlbp_found            ,
                       ms_tlbp_op               ,
                       ms_refetch               ,
                       ms_alu_result            ,
                       ms_rd                    ,
                       ms_inst_in_slot          ,
                       ms_exception_cmt         ,//121:110
                       ms_mtc0_op               ,//109:109
                       ms_mfc0_op               ,//108:108
                       ms_eret_cmt              ,//107:107
                       ms_rt                    ,//106:102
                       ms_rt_data               ,//101:70
                       ms_gr_we                 ,//69:69
                       ms_dest                  ,//68:64
                       ms_final_result          ,//63:32
                       ms_pc                     //31:0
                      };
reg  ws_reflush_r;
assign ms_reflush = ms_valid && (ms_exception_cmt || ms_eret_cmt);

assign ms_ready_go    = !ms_res_from_mem || data_data_ok || |(ms_exception_cmt);
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go && !ws_reflush && !ws_reflush_r;


always @(posedge clk) begin 
    if(reset) begin 
        ws_reflush_r <= 1'b0;
    end else if((ws_reflush || ws_reflush_r) && ms_ready_go) begin 
        ws_reflush_r <= 1'b0;
    end else if(ws_reflush) begin 
        ws_reflush_r <= 1'b1;
    end
end



always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end else if((ws_reflush || ws_reflush_r) && ms_ready_go) begin 
        ms_valid <= 1'b0;
    end else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

assign ms_rt_data = ms_rt==ws_rt ? ws_rt_value :
                    ms_rt_value;

wire [31:0] mem_read_result;
wire [31:0] mem_merge_result;
assign mem_read_result = // one-byte values
                    ms_mem_num==4'b0001 ? {{24{ms_mem_sign_ext&data_rdata[7]}}, data_rdata[7:0]}:
                    ms_mem_num==4'b0010 ? {{24{ms_mem_sign_ext&data_rdata[15]}}, data_rdata[15:8]}:
                    ms_mem_num==4'b0100 ? {{24{ms_mem_sign_ext&data_rdata[23]}}, data_rdata[23:16]}:
                    ms_mem_num==4'b1000 ? {{24{ms_mem_sign_ext&data_rdata[31]}}, data_rdata[31:24]}:
                    // half word values
                    // lh/lhu require naturally aligned addresses so the mem_num 
                    // for these instructions is always 4'b0011 or 4'b1100.
                    ms_mem_num==4'b0011 ? {{16{ms_mem_sign_ext&data_rdata[15]}}, data_rdata[15:0]}:
                    ms_mem_num==4'b1100 ? {{16{ms_mem_sign_ext&data_rdata[31]}}, data_rdata[31:16]}:
                    // one-word values
                    data_rdata;
// only lwl and lwr need merge operation.
// possible mem_num are 4'b0001, 4'b0011, 4'b0111, 4'b1111, 4'b1110, 4'b1100, 4'b1000
assign mem_merge_result =   // for lwl
                            ms_mem_num==4'b0001 ? {data_rdata[7:0], ms_rt_data[23:0]}  :
                            ms_mem_num==4'b0011 ? {data_rdata[15:0], ms_rt_data[15:0]} :
                            ms_mem_num==4'b0111 ? {data_rdata[23:0], ms_rt_data[7:0]}  :
                            // ms_mem_num==4'b1111 ? data_rdata :
                            // for lwr
                            ms_mem_num==4'b1110 ? {ms_rt_data[31:24], data_rdata[31:8]} :
                            ms_mem_num==4'b1100 ? {ms_rt_data[31:16], data_rdata[31:16]}:
                            ms_mem_num==4'b1000 ? {ms_rt_data[31:8], data_rdata[31:24]} :
                            // 4'b1111
                            data_rdata;


assign ms_final_result = 
                         // lwl and lwr need this merged value. however, (**_regl || **_regr) includes swr and swl.
                         // but when instruction is swr and swl, gr_we is invalid so the result could be anything.
                         (ms_unaligned_mem_acc_regl || ms_unaligned_mem_acc_regr) ? mem_merge_result:
                         ms_res_from_mem ? mem_read_result:
                         ms_alu_result;



endmodule
