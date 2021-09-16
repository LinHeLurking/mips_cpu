`include "mycpu.h"

module exe_stage
#(
    parameter TLBNUM = 16
)
(
    input                          clk           ,
    input                          reset         ,
    input                          resetn        ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ds
    output [4:0]                   es_dest       ,
    output reg                     es_valid      ,
    output                         es_load_op    ,
    output                         es_lwlr_op    ,
    output [31:0]                  es_final_result,
    output                         es_gr_we      ,            
    // data sram-like interface
    output                         data_req      ,
    output                         data_wr       ,
    output [1:0]                   data_size     ,
    output [31:0]                  data_addr     ,
    output [31:0]                  data_wdata    ,
    output [3:0]                   data_wstrb    ,
    // input  [31:0]                  data_rdata    ,
    input                          data_addr_ok  ,
    // input                          data_data_ok  ,
    //exception
    input                          ws_reflush      ,
    input                          ms_reflush      ,
    output                         es_mfc0_op      ,
    // TLB
    output [18:0]                  es_vpn2        ,
    output                         es_odd_page    ,
    input  [$clog2(TLBNUM)-1:0]    es_index       ,
    input                          es_found       ,
    input  [19:0]                  es_pfn         ,
    input  [2:0]                   es_c           ,
    input                          es_d           , 
    input                          es_v           ,
    input  [31:0]                  cp0_entryhi    ,
    input                          ms_mtc0_op     ,
    input                          ws_mtc0_op 
);

wire [31:0] es_alu_result;

wire es_ready_go;
//////////

wire        overflow;
wire        es_need_ades;
wire        es_need_adel;

wire        es_mtc0_op;

wire [4:0] es_rd;
wire       es_inst_in_slot;
wire       es_eret_cmt;
wire [14:0] es_exception_cmt;
wire [14:0] from_ds_exception_cmt;
wire       reflush;

wire        es_ade_1;
wire        es_ade_2;
//////////
wire   st_valid;
assign st_valid  = es_need_ades & ((es_ade_1 && (es_alu_result[1:0] != 2'b00)) | (es_ade_2 && (es_alu_result[0] != 1'b0)));



reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [12:0] es_alu_op     ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_mem_we     ;
wire [16:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
/////////////

wire es_refetch;



wire [63:0] divout;
wire [63:0] mulout;
wire        div_complete;
reg  [63:0] div_result;

wire        es_div_signed;
wire        es_div;
wire        es_mul_signed;
wire        es_mul_unsigned;
wire        es_hi_write;
wire        es_hi_read;
wire        es_lo_write;
wire        es_lo_read;

wire [31:0] HI_temp;
wire [31:0] LO_temp;

wire [3:0] es_mem_num_temp;
wire [3:0] es_mem_num;
wire       es_unaligned_mem_acc_regl;
wire       es_unaligned_mem_acc_regr;
wire       es_mem_sign_ext;
wire [4:0] es_rt;


wire es_tlbp_op;
wire es_tlbr_op;
wire es_tlbwi_op;

assign {es_tlbwi_op              ,
        es_tlbr_op               ,
        es_tlbp_op               ,
        es_refetch               ,
        es_ade_1                 ,
        es_ade_2                 ,
        es_need_ades             ,
        es_need_adel             ,
        es_rd                    ,
        es_inst_in_slot          ,//175:175
        from_ds_exception_cmt    ,//175:161
        es_mtc0_op               ,//160:160
        es_mfc0_op               ,//159:159
        es_eret_cmt              ,//158:158
        es_lwlr_op               ,//157:157
        es_rt                    ,//156:152
        es_div_signed            ,//151:151
        es_div                   ,//150:150
        es_mul_signed            ,//149:149
        es_mul_unsigned          ,//148:148
        es_hi_write              ,//147:147
        es_hi_read               ,//146:146
        es_lo_write              ,//145:145
        es_lo_read               ,//144:144
        es_unaligned_mem_acc_regl,//143:143
        es_unaligned_mem_acc_regr,//142:142
        es_mem_sign_ext          ,//141:141
        es_mem_num_temp          ,//140:137
        es_alu_op                ,//136:125
        es_load_op               ,//124:124
        es_src1_is_sa            ,//123:123
        es_src1_is_pc            ,//122:122
        es_src2_is_imm           ,//121:121
        es_src2_is_8             ,//120:120
        es_gr_we                 ,//119:119
        es_mem_we                ,//118:118
        es_dest                  ,//117:113
        es_imm                   ,//112:96
        es_rs_value              ,//95 :64
        es_rt_value              ,//63 :32
        es_pc                     //31 :0
       } = ds_to_es_bus_r;


// reflush AFTER response
reg  ws_reflush_r;
reg  ms_reflush_r;
always @(posedge clk) begin 
    if(reset) begin 
        ws_reflush_r <= 1'b0;
        ms_reflush_r <= 1'b0;
    end else begin
        if((ws_reflush_r||ws_reflush||ms_reflush_r||ms_reflush) && es_ready_go) begin 
            ws_reflush_r <= 1'b0;
        end else if(ws_reflush && es_valid) begin 
            ws_reflush_r <= 1'b1;
        end
        if((ws_reflush_r||ws_reflush||ms_reflush_r||ms_reflush) && es_ready_go) begin 
            ms_reflush_r <= 1'b0;
        end else if(ms_reflush && es_valid) begin 
            ms_reflush_r <= 1'b1;
        end
    end
end

assign reflush = ws_reflush_r || ms_reflush_r || ws_reflush || ms_reflush;

wire [31:0] es_alu_src1    ;
wire [31:0] es_alu_src2    ;
wire        es_res_from_mem;


assign es_res_from_mem = es_load_op;

assign es_to_ms_bus = {es_tlbwi_op              ,// 1
                       es_tlbr_op               ,// 1
                       es_index                 ,// 4
                       es_found                 ,// 1
                       es_tlbp_op               ,// 1
                       es_refetch               ,// 1
                       es_ade_1                 ,// 1
                       es_ade_2                 ,// 1
                       es_need_ades             ,// 1
                       es_need_adel             ,// 1
                       es_rd                    ,// 5
                       es_inst_in_slot          ,// 1
                       es_exception_cmt         ,// 15
                       es_mtc0_op               ,// 1
                       es_mfc0_op               ,// 1
                       es_eret_cmt              ,// 1
                       es_rt                    ,// 5
                       es_hi_read               ,// 1
                       es_lo_read               ,// 1
                       es_hi_write              ,// 1
                       es_lo_write              ,// 1
                       es_rt_value              ,// 32
                       es_unaligned_mem_acc_regl,// 1
                       es_unaligned_mem_acc_regr,// 1
                       es_mem_sign_ext          ,// 1
                       es_mem_num               ,// 4 
                       es_res_from_mem          ,// 1
                       es_gr_we                 ,// 1
                       es_dest                  ,// 5
                       es_final_result          ,// 32
                       es_pc                     // 32
                      };

wire div_stall = ws_reflush ? 0 : es_div && !div_complete;
reg data_addr_ok_r;

wire mem_acc_stall;
assign mem_acc_stall = (es_mem_we || es_res_from_mem) && !data_addr_ok && !data_addr_ok_r && !(|es_exception_cmt);

wire tlb_stall;
assign tlb_stall = es_tlbp_op && ms_mtc0_op && ws_mtc0_op;

assign es_ready_go    = !div_stall && !mem_acc_stall && !tlb_stall;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && !ws_reflush && !ws_reflush_r;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end else if((ws_reflush_r||ws_reflush) && es_ready_go) begin 
        es_valid <= 1'b0;
    end else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

always @(posedge clk) begin 
    if(reset) begin 
        data_addr_ok_r <= 1'b0;
    end else begin 
        if(data_addr_ok) begin 
            data_addr_ok_r <= 1'b1;
        end else if(es_allowin) begin 
            data_addr_ok_r <= 1'b0;
        end
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[16]}}, es_imm[15:0]} : 
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .overflow   (overflow     )    
    );

wire [3:0] lwl_num;
wire [3:0] lwr_num;
wire [3:0] swl_num;
wire [3:0] swr_num;
wire [3:0] regl_num;
wire [3:0] regr_num;

// little endian!
assign lwl_num = es_alu_result[1:0]==2'b00 ? 4'b0001 :
                 es_alu_result[1:0]==2'b01 ? 4'b0011 :
                 es_alu_result[1:0]==2'b10 ? 4'b0111 :
               /*es_alu_result[1:0]==2'b11*/ 4'b1111 ;

assign lwr_num = es_alu_result[1:0]==2'b00 ? 4'b1111 :
                 es_alu_result[1:0]==2'b01 ? 4'b1110 :
                 es_alu_result[1:0]==2'b10 ? 4'b1100 :
               /*es_alu_result[1:0]==2'b11*/ 4'b1000 ;

assign swl_num = es_alu_result[1:0]==2'b00 ? 4'b0001 :
                 es_alu_result[1:0]==2'b01 ? 4'b0011 :
                 es_alu_result[1:0]==2'b10 ? 4'b0111 :
               /*es_alu_result[1:0]==2'b11*/ 4'b1111 ;

assign swr_num = es_alu_result[1:0]==2'b00 ? 4'b1111 :
                 es_alu_result[1:0]==2'b01 ? 4'b1110 :
                 es_alu_result[1:0]==2'b10 ? 4'b1100 :
               /*es_alu_result[1:0]==2'b11*/ 4'b1000 ;

assign regl_num = es_res_from_mem ? lwl_num : swl_num;
assign regr_num = es_res_from_mem ? lwr_num : swr_num;
assign es_mem_num = es_unaligned_mem_acc_regl ? regl_num:
                    es_unaligned_mem_acc_regr ? regr_num:
                    es_mem_num_temp << es_alu_result[1:0];

wire [31:0] st_data;


assign st_data = // swl
                 es_unaligned_mem_acc_regl ? 
                 (
                 es_mem_num==4'b0001 ? {24'b0, es_rt_value[31:24]}:
                 es_mem_num==4'b0011 ? {16'b0, es_rt_value[31:16]}:
                 es_mem_num==4'b0111 ? {8'b0, es_rt_value[31:8]}:
                 es_rt_value
                 ):
                 // swr 
                 es_unaligned_mem_acc_regr ?
                 (
                 es_mem_num==4'b1110 ? {es_rt_value[23:0], 8'b0}:
                 es_mem_num==4'b1100 ? {es_rt_value[15:0], 16'b0}:
                 es_mem_num==4'b1000 ? {es_rt_value[7:0], 24'b0}:
                 es_rt_value
                 ):
                 // others situations are the same as sb/sh
                 es_mem_num_temp==4'b0001 ? {4{es_rt_value[7:0]}}:
                 es_mem_num_temp==4'b0011 ? {2{es_rt_value[15:0]}}:
                 es_rt_value;

wire kseg0;
wire kseg1;
wire mapped;
wire es_tlb_miss;
wire es_tlb_invalid;
wire es_tlb_modified;
wire [31:0] tlb_addr;
wire tlbp_found;
assign kseg0 = es_alu_result[31:29] == 3'b100;
assign kseg1 = es_alu_result[31:29] == 3'b101;
assign mapped = !kseg0 && !kseg1;
assign es_vpn2 = es_tlbp_op ? cp0_entryhi[31:13] : es_alu_result[31:13];
assign es_odd_page = es_tlbp_op ? 1'b0 : es_alu_result[12];
assign tlb_addr = mapped ? {es_pfn, es_alu_result[11:0]} : {3'b0, es_alu_result[28:0]};
assign es_tlb_miss = mapped && !es_found && (es_mem_we || es_res_from_mem) && es_valid;
assign es_tlb_invalid = mapped && es_found && !es_v && (es_mem_we || es_res_from_mem) && es_valid;    
assign es_tlb_modified = mapped && es_found && es_v && !es_d && data_wr && (es_mem_we || es_res_from_mem) && es_valid;           
assign tlbp_found = es_found;

assign data_req   = ((es_exception_cmt|| reflush)? 1'b0 : (es_res_from_mem || es_mem_we)) 
                    && es_valid && !es_tlb_miss && !es_tlb_invalid && !es_tlb_modified;
assign data_wr    = (|(es_mem_we && es_valid ? es_mem_num : 4'h0)) && !reflush;
assign data_size  = 2'b10;
assign data_wstrb = es_mem_num;
assign data_addr  = tlb_addr;
assign data_wdata = st_data;

divider u_divider
(
    .div_clk     (clk),
    .resetn      (resetn),
    .div         (es_div),
    .div_signed  (es_div_signed),
    .x           (es_alu_src1),
    .y           (es_alu_src2),
    .s           (divout[31:0]),
    .r           (divout[63:32]),
    .complete    (div_complete)
);

always@(posedge clk)begin
    if(!resetn) begin
        div_result <= 64'b0;
    end else begin
        if(div_complete)
            div_result <= divout;
    end
end


wire [63:0] unsigned_prod;
wire [63:0] signed_prod;

assign unsigned_prod = es_alu_src1 * es_alu_src2;
assign signed_prod = $signed(es_alu_src1) * $signed(es_alu_src2);

assign mulout = es_mul_signed ? signed_prod:unsigned_prod;

reg [31:0] HI;
reg [31:0] LO;

assign es_final_result = es_hi_read ? HI :
                         es_lo_read ? LO :
                         es_mtc0_op ? es_rt_value:
                         es_alu_result;

assign HI_temp = es_mul_unsigned || es_mul_signed ? mulout[63:32]:
                 es_div || es_div_signed          ? divout[63:32]:
                 es_hi_write                      ? es_alu_src1:
                 HI;


assign LO_temp = es_mul_unsigned || es_mul_signed ? mulout[31:0]:
                 es_div || es_div_signed          ? divout[31:0]:
                 es_lo_write                      ? es_alu_src1:
                 LO;


always @(posedge clk) begin
    if(!resetn) begin 
        HI <= 32'h0;
        LO <= 32'h0;
    end else if (!reflush && es_valid) begin 
        HI <= HI_temp;
        LO <= LO_temp;
    end
end


assign es_exception_cmt[1:0] = from_ds_exception_cmt[1:0];
assign es_exception_cmt[2]   = es_need_adel & ((es_ade_1 && (es_alu_result[1:0] != 2'b00)) | (es_ade_2 && (es_alu_result[0] != 1'b0)));//mem_adel
assign es_exception_cmt[5:3] = from_ds_exception_cmt[5:3];
assign es_exception_cmt[6]   = es_need_ades & ((es_ade_1 && (es_alu_result[1:0] != 2'b00)) | (es_ade_2 && (es_alu_result[0] != 1'b0)));//mem_ades
assign es_exception_cmt[7]   = overflow;
assign es_exception_cmt[9:8] = from_ds_exception_cmt[9:8];
assign es_exception_cmt[10]  = es_tlb_miss && es_res_from_mem;
assign es_exception_cmt[11]  = es_tlb_invalid && es_res_from_mem;
assign es_exception_cmt[12]  = es_tlb_miss && es_mem_we;
assign es_exception_cmt[13]  = es_tlb_invalid && es_mem_we;
assign es_exception_cmt[14]  = es_tlb_modified;

endmodule
