`include "mycpu.h"

module id_stage(
    input                          clk            ,
    input                          reset          ,
    //allowin
    input                          es_allowin     ,
    output                         ds_allowin     ,
    //from fs
    input                          fs_to_ds_valid ,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    //from es
    input  [4:0]                   es_dest        ,
    input                          es_valid       ,
    input                          es_load_op     ,
    input                          es_lwlr_op     ,
    input  [31:0]                  es_final_result,
    input                          es_gr_we       ,    
    //from ms
    input  [4:0]                   ms_dest        ,
    input                          ms_valid       ,
    input                          ms_to_ws_valid ,
    input                          ms_gr_we       ,
    input                          ms_load_op     ,
    input                          ms_ready_go    ,
    input  [31:0]                  ms_final_result,    
    //from ws
    input  [4:0]                   ws_dest        ,
    input                          ws_valid       ,
    input                          ws_gr_we       ,
    input  [31:0]                  ws_final_result,              
    //to es
    output                         ds_to_es_valid ,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus   ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus         ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //exception
    input                          ws_reflush    ,
    input                          es_mfc0_op    ,  
    input                          ms_mfc0_op    ,
    output                         eret_cmt      ,
    input                          int_cmt         
);

/////////////////////
// lab8/lab9 newly added
wire        inst_mtc0;
wire        inst_mfc0;
wire        inst_eret;
wire        inst_syscall;
wire        inst_break;
wire        inst_reserved;

reg         ds_inst_in_slot;

wire [14:0]  ds_exception_cmt;
wire [14:0]  from_fs_exception_cmt;
wire        mfc0_op;
wire        mtc0_op;

wire        ade_1;
wire        ade_2;
/////////////////////

wire        ds_stall;
wire        ds_ready_go;
reg         ds_valid;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire ds_refetch;
assign {from_fs_exception_cmt,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

assign {rf_we             ,//37:37
        rf_waddr          ,//36:32
        rf_wdata           //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [12:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
wire [31:0] rs_mch_value;
wire [31:0] rt_mch_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;
/////////////////////
//newly added
wire        inst_add;
wire        inst_addi;
wire        inst_sub;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllv;
wire        inst_srlv;
wire        inst_srav;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
///////////////////////
// lab 13 newly added for TLB 
wire        inst_tlbp;
wire        inst_tlbr;
wire        inst_tlbwi;

wire        imm_zero_ext;
wire [16:0] imm17;

wire        div_signed;
wire        div;
wire        mul_signed;
wire        mul_unsigned;
wire        hi_write;
wire        hi_read;
wire        lo_write;
wire        lo_read;
//////////////////////
// newly added for branch&jump instructions
wire [31:0] mid_d;

wire        inst_bgez;
wire        inst_bgezal;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_bltzal;
wire        inst_j;
wire        inst_jalr;

wire [3:0] mem_num;

// 0 if instuction is one of lwl, lwr, swl, swr
wire       unaligned_mem_acc_regl;
wire       unaligned_mem_acc_regr;

wire       mem_sign_ext;

wire       inst_lb;
wire       inst_lbu;
wire       inst_lh;
wire       inst_lhu;
wire       inst_lwl;
wire       inst_lwr;
wire       inst_sb;
wire       inst_sh;
wire       inst_swl;
wire       inst_swr;

wire       lwlr_op;



/////////////////////

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rs_mch_es_dst;
wire        rt_mch_es_dst;
wire        rs_mch_ms_dst;
wire        rt_mch_ms_dst;
wire        rs_mch_ws_dst;
wire        rt_mch_ws_dst;
wire        rs_mch_dst;
wire        rt_mch_dst;
wire        rs_eq_rt;
assign br_bus       = {br_taken,br_target};

wire        need_ades;
wire        need_adel;

///////////////////////
wire tlbp_op;
wire tlbr_op;
wire tlbwi_op;
assign tlbp_op = inst_tlbp;
assign tlbr_op = inst_tlbr;
assign tlbwi_op = inst_tlbwi;

assign ds_to_es_bus = {tlbwi_op              ,// 1
                       tlbr_op               ,// 1
                       tlbp_op               ,// 1
                       ds_refetch            ,// 1
                       ade_1                 ,// 1
                       ade_2                 ,// 1
                       need_ades             ,// 1
                       need_adel             ,// 1
                       rd                    ,// 5
                       ds_inst_in_slot       ,// 1
                       ds_exception_cmt      ,// 15
                       mtc0_op               ,// 1
                       mfc0_op               ,// 1
                       eret_cmt              ,// 1
                       lwlr_op               ,// 1
                       rt                    ,// 5
                       div_signed            ,// 1
                       div                   ,// 1
                       mul_signed            ,// 1
                       mul_unsigned          ,// 1
                       hi_write              ,// 1
                       hi_read               ,// 1
                       lo_write              ,// 1
                       lo_read               ,// 1
                       unaligned_mem_acc_regl,// 1
                       unaligned_mem_acc_regr,// 1
                       mem_sign_ext          ,// 1
                       mem_num               ,// 4
                       alu_op                ,// 13
                       load_op               ,// 1
                       src1_is_sa            ,// 1
                       src1_is_pc            ,// 1
                       src2_is_imm           ,// 1
                       src2_is_8             ,// 1 
                       gr_we                 ,// 1
                       mem_we                ,// 1
                       dest                  ,// 5
                       imm17                 ,// 17
                       rs_value              ,// 32
                       rt_value              ,// 32
                       ds_pc                  // 32
                      };


wire ds_stall_by_es;
wire ds_stall_by_ms;
wire ds_stall_by_ws;


/*
 * Before we intergrate the bus bridge, there are two types of stall. One is load in EXE, 
 * the other one is mfc0 in EXE or MEM. After the bridge is integrated, stall is needed before the 
 * response signals in MEM arive, for the sake of data forwarding towards ID.
 */

assign ds_stall_by_es =  es_valid
                && (!inst_jal && !inst_j && !inst_jr) // jal/jr/j does not read and general registers
                &&  es_dest!=5'b0
                && (es_dest==rs || es_dest==rt)
                &&((es_load_op && !lwlr_op) || (es_lwlr_op && !load_op) || (es_mfc0_op));
                
assign ds_stall_by_ms = ms_valid
                && (!inst_jal && !inst_j && !inst_jr)               // jal/jr/j does not read and general registers
                &&  ms_dest!=5'b0
                &&  (ms_dest==rs || ms_dest==rt)
                &&  (ms_mfc0_op || (ms_load_op && !ms_ready_go));

assign ds_stall = ds_stall_by_es || ds_stall_by_ms;

assign ds_ready_go    = ws_reflush ? 1'b1 : !ds_stall;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go && !ws_reflush;

always @(posedge clk) begin
    if (reset || ws_reflush) begin
        ds_valid <= 1'b0;
    end else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;  
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

always @(posedge clk) 
begin
  if (reset || ws_reflush) begin
    ds_inst_in_slot <= 1'b0;
  end

  else if (ds_allowin && ds_to_es_valid) begin
    ds_inst_in_slot <= in_slot;
  end
end


assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
//////////////////////
//newly added
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00] & rd_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00] & rd_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00] & rd_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00] & rd_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & sa_d[5'h00] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & sa_d[5'h00] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & sa_d[5'h00] & rt_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & sa_d[5'h00] & rt_d[5'h00];
///////////////////////////
assign div_signed  = inst_div;
assign div         = inst_divu | inst_div;
assign mul_signed  = inst_mult;
assign mul_unsigned         = inst_multu;
assign hi_write    = inst_div | inst_divu | inst_mult | inst_multu | inst_mthi;
assign hi_read     = inst_mfhi;
assign lo_write    = inst_div | inst_divu | inst_mult | inst_multu | inst_mtlo;
assign lo_read     = inst_mflo;
/////////////////////////////
// newly added for branch&jump instructions
assign mid_d       = rt_d;

assign inst_bgez   = op_d[6'h01] & mid_d[5'h01];
assign inst_bgezal = op_d[6'h01] & mid_d[5'h11];
assign inst_bgtz   = op_d[6'h07] & mid_d[5'h00];
assign inst_blez   = op_d[6'h06] & mid_d[5'h00];
assign inst_bltz   = op_d[6'h01] & mid_d[5'h00];
assign inst_bltzal = op_d[6'h01] & mid_d[5'h10];
assign inst_j      = op_d[6'h02];
assign inst_jalr   = op_d[6'h00] & func_d[5'h09] & sa_d[5'h00] & mid_d[5'h00];
/////////////////////////////
// newly added for memory access instructions
assign inst_lb  = op_d[6'h20];
assign inst_lbu = op_d[6'h24];
assign inst_lh  = op_d[6'h21];
assign inst_lhu = op_d[6'h25];
assign inst_lwl = op_d[6'h22];
assign inst_lwr = op_d[6'h26];
assign inst_sb  = op_d[6'h28];
assign inst_sh  = op_d[6'h29];
assign inst_swl = op_d[6'h2a];
assign inst_swr = op_d[6'h2e];
assign mem_num  = inst_lb || inst_lbu || inst_sb ? 4'b0001 :
                  inst_lh || inst_lhu || inst_sh ? 4'b0011 :
                  4'b1111;
assign unaligned_mem_acc_regl = inst_lwl | inst_swl;
assign unaligned_mem_acc_regr = inst_lwr | inst_swr;
assign lwlr_op = inst_lwl | inst_lwr;
/////////////////////////////
assign inst_tlbp  = op_d[6'h10] && func_d[6'h08];
assign inst_tlbr  = op_d[6'h10] && func_d[6'h01]; 
assign inst_tlbwi = op_d[6'h10] && func_d[6'h02]; 

assign ds_refetch = ds_valid && (inst_tlbr || inst_tlbwi);

/////////////////////////////

assign alu_op[ 0] = inst_addu | inst_add | inst_addiu | inst_addi | inst_lw | inst_sw | inst_bgezal | inst_bltzal | inst_jal |
                    inst_lb   | inst_lbu | inst_lh    | inst_lhu  | inst_lwl| inst_lwr| inst_sb     | inst_sh     | inst_swl |
                    inst_swr  | inst_jalr;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor  ;
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_sll  | inst_sllv;
assign alu_op[ 9] = inst_srl  | inst_srlv;
assign alu_op[10] = inst_sra  | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_add  | inst_addi | inst_sub;

assign src1_is_sa   = inst_sll    | inst_srl    | inst_sra  ;
assign src1_is_pc   = inst_bgezal | inst_bltzal | inst_jal  | inst_jalr;
assign src2_is_imm  = inst_addiu  | inst_lui    | inst_lw   | inst_sw  | inst_addi   | inst_slti  | inst_sltiu | inst_andi  | inst_ori | inst_xori |
                      inst_lb     | inst_lbu    | inst_lh   | inst_lhu | inst_lwl    | inst_lwr   | inst_sb    | inst_sh    | inst_swl | inst_swr  ;
assign src2_is_8    = inst_bgezal | inst_bltzal | inst_jal  | inst_jalr;
assign imm_zero_ext = inst_andi   | inst_ori    | inst_xori ;
assign res_from_mem = inst_lw     | inst_lb     | inst_lbu  | inst_lh  | inst_lhu    | inst_lwl   | inst_lwr   ;
assign dst_is_r31   = inst_bgezal | inst_bltzal | inst_jal  ;
assign dst_is_rt    = inst_addiu  | inst_lui    | inst_lw   | inst_addi| inst_slti  | inst_sltiu | inst_andi  | inst_ori   | inst_xori|
                      inst_lb     | inst_lbu    | inst_lh   | inst_lhu | inst_lwl   | inst_lwr   | inst_mfc0  ;
assign gr_we        = ~inst_sw    & ~inst_beq   & ~inst_bne & ~inst_jr & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & ~inst_j  &
                      ~inst_sb    & ~inst_sh    & ~inst_swl & ~inst_swr& ~inst_eret & ~inst_mtc0 & ~inst_break& ~inst_syscall & ~inst_reserved;
assign mem_we       = inst_sw     | inst_swl    | inst_swr  | inst_sb  | inst_sh    ;
assign load_op      = inst_lw     | inst_lb     | inst_lbu  | inst_lh  | inst_lhu   | inst_lwl   | inst_lwr   ;
assign store_op     = inst_sw     | inst_sb     | inst_sh   | inst_swl | inst_swr   ;
assign mem_sign_ext = inst_lb     | inst_lh     ;

assign imm17[16]    = imm_zero_ext ? 1'b0 : imm[15];
assign imm17[15:0]  = imm[15:0];
assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rs_mch_es_dst = es_valid && es_gr_we && !es_load_op && (es_dest!=5'b0) && (es_dest==rs);
assign rt_mch_es_dst = es_valid && es_gr_we && !es_load_op && (es_dest!=5'b0) && (es_dest==rt);
assign rs_mch_ms_dst = ms_to_ws_valid && ms_gr_we && (ms_dest!=5'b0) && (ms_dest==rs);
assign rt_mch_ms_dst = ms_to_ws_valid && ms_gr_we && (ms_dest!=5'b0) && (ms_dest==rt);
assign rs_mch_ws_dst = ws_valid && ws_gr_we && (ws_dest!=5'b0) && (ws_dest==rs);
assign rt_mch_ws_dst = ws_valid && ws_gr_we && (ws_dest!=5'b0) && (ws_dest==rt);


assign rs_mch_value = rs_mch_es_dst ? es_final_result :
                      rs_mch_ms_dst ? ms_final_result :
                      rs_mch_ws_dst ? ws_final_result :
                                      32'b0           ;

assign rt_mch_value = rt_mch_es_dst ? es_final_result :
                      rt_mch_ms_dst ? ms_final_result :
                      rt_mch_ws_dst ? ws_final_result :
                                      32'b0           ;

assign rs_mch_dst = rs_mch_es_dst | rs_mch_ms_dst | rs_mch_ws_dst; 
assign rt_mch_dst = rt_mch_es_dst | rt_mch_ms_dst | rt_mch_ws_dst;

assign rs_value = rs_mch_dst ? rs_mch_value : rf_rdata1;
assign rt_value = rt_mch_dst ? rt_mch_value : rf_rdata2;

assign rs_eq_rt = (rs_value == rt_value);

assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || inst_jal  || inst_jr || inst_j || inst_jalr
                   || (inst_bgez || inst_bgezal) && $signed(rs_value) >= 0
                   || inst_bgtz && $signed(rs_value) > 0
                   || inst_blez && $signed(rs_value) <= 0
                   || (inst_bltz || inst_bltzal) && $signed(rs_value) < 0
                  ) && ds_valid && ds_ready_go;

wire offset_branch;
wire [31:0] offset_target;
assign offset_branch = inst_beq || inst_bne || inst_bgez || inst_bgezal || inst_bgtz || inst_blez || inst_bltz || inst_bltzal;
assign offset_target = fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0};
assign br_target = offset_branch          ? offset_target :
                   (inst_jr || inst_jalr) ? rs_value      :
                   /*inst_jal&inst_j*/ {fs_pc[31:28], jidx[25:0], 2'b0};

wire   in_slot;
assign in_slot = offset_branch || inst_j || inst_jal || inst_jalr || inst_jr;

/////////////////////////////
//lab8/lab9 newly added
assign inst_syscall= op_d[6'h00] & func_d[6'h0c];
assign inst_eret   = op_d[6'h10] & func_d[6'h18] & ds_inst[25] & (ds_inst[24:6]==0);
assign inst_mtc0   = op_d[6'h10] &   rs_d[5'h04] & (ds_inst[10:3]==0);
assign inst_mfc0   = op_d[6'h10] &   rs_d[5'h00] & (ds_inst[10:3]==0);
assign inst_break  = op_d[6'h00] & func_d[6'h0d];

assign eret_cmt    = inst_eret;
assign mtc0_op     = inst_mtc0;
assign mfc0_op     = inst_mfc0;

assign ade_1       = inst_lw  | inst_sw  ;
assign ade_2       = inst_lh  | inst_lhu | inst_sh ;

assign ds_exception_cmt[0]   = int_cmt;
assign ds_exception_cmt[2:1] = from_fs_exception_cmt[2:1];
assign ds_exception_cmt[3]   = inst_syscall; 
assign ds_exception_cmt[4]   = inst_break; 
assign ds_exception_cmt[5]   = inst_reserved; 
assign ds_exception_cmt[14:6] = from_fs_exception_cmt[14:6];


assign need_ades = inst_sw | inst_sh ;
assign need_adel = inst_lw | inst_lh | inst_lhu ;

assign inst_reserved = ~( inst_addu  | inst_subu  | inst_slt  | inst_sltu  | inst_and  | inst_or
                        | inst_xor   | inst_nor   | inst_sll  | inst_srl   | inst_sra  | inst_addiu   
                        | inst_lui   | inst_lw    | inst_sw   | inst_beq   | inst_bne  | inst_jal
                        | inst_jr    | inst_add   | inst_addi | inst_sub   | inst_slti | inst_sltiu
                        | inst_andi  | inst_ori   | inst_xori | inst_sllv  | inst_srlv | inst_srav
                        | inst_mult  | inst_multu | inst_div  | inst_divu  | inst_mfhi | inst_mflo
                        | inst_mthi  | inst_mtlo  | inst_bgez | inst_bgezal| inst_bgtz | inst_blez
                        | inst_bltz  | inst_bltzal| inst_j    | inst_jalr  | inst_lb   | inst_lbu  
                        | inst_lh    | inst_lhu   | inst_lwl  | inst_lwr   | inst_sb   | inst_sh 
                        | inst_swl   | inst_swr   | inst_eret | inst_mtc0  | inst_mfc0 |inst_syscall
                        | inst_break | inst_tlbp  | inst_tlbr | inst_tlbwi);
/////////////////////////////
endmodule
