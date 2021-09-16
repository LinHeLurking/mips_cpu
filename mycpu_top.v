module mycpu_top
#(
    parameter TLBNUM = 16
)
(
    input [5:0]   int,
    input         aclk,
    input         aresetn,

    //axi
    //ar
    output [3:0]  arid      ,
    output [31:0] araddr    ,
    output [7:0]  arlen     ,
    output [2:0]  arsize    ,
    output [1:0]  arburst   ,
    output [1:0]  arlock    ,
    output [3:0]  arcache   ,
    output [2:0]  arprot    ,
    output        arvalid   ,
    input         arready   ,
    //r              
    input  [3:0]  rid       ,
    input  [31:0] rdata     ,
    input  [1:0]  rresp     ,
    input         rlast     ,
    input         rvalid    ,
    output        rready    ,
    //aw           
    output [3:0]  awid      ,
    output [31:0] awaddr    ,
    output [7:0]  awlen     ,
    output [2:0]  awsize    ,
    output [1:0]  awburst   ,
    output [1:0]  awlock    ,
    output [3:0]  awcache   ,
    output [2:0]  awprot    ,
    output        awvalid   ,
    input         awready   ,
    //w          
    output [3:0]  wid       ,
    output [31:0] wdata     ,
    output [3:0]  wstrb     ,
    output        wlast     ,
    output        wvalid    ,
    input         wready    ,
    //b              
    input  [3:0]  bid       ,
    input  [1:0]  bresp     ,
    input         bvalid    ,
    output        bready    ,

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         reset;
wire resetn;
wire clk;
always @(posedge clk) reset <= ~aresetn;
assign clk = aclk;
assign resetn = aresetn;

// sram-like <-> axi bridge interface
// inst sram-like
wire inst_req;
wire inst_wr;
wire [1:0] inst_size;
wire [31:0] inst_addr;
wire [31:0] inst_wdata;
wire [31:0] inst_rdata;
wire inst_addr_ok;
wire inst_data_ok;
// data sram-like
wire data_req;
wire data_wr;
wire [1:0] data_size;
wire [31:0] data_addr;
wire [31:0] data_wdata;
wire [3:0]  data_wstrb;
wire [31:0] data_rdata;
wire data_addr_ok;
wire data_data_ok;
// axi ports are defined in output ports


//cp0
wire [31:0] ws_pc;
wire        ws_eret_cmt;
wire [ 14:0] ws_exception_cmt;
wire        ws_inst_in_slot;
wire        ws_mtc0_op;
wire        ms_mtc0_op;
wire        ws_mfc0_op;
wire [ 4:0] ws_rd;
wire [31:0] ws_mfc0_data;
wire [31:0] cp0_epc;
wire        int_cmt;
wire [31:0] ws_badvaddr;
wire [31:0] exception_pc;
//if
// wire        inst_valid;
//id
wire        eret_cmt;
//wire        cp0_stall;
//ex
wire       es_mfc0_op;
//mem
wire       ms_mfc0_op;
wire       ms_load_op;
wire       ms_ready_go;
//wb
wire       ws_reflush;
wire       ms_reflush;


wire [4:0]   es_dest;
wire [4:0]   ms_dest;
wire [4:0]   ws_dest;
wire         es_valid;
wire         ms_valid;
wire         ws_valid;
wire         ms_gr_we;
wire         ws_gr_we;
wire         es_gr_we;
wire         es_load_op;
wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire [31:0]  es_final_result;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [31:0]  ms_final_result;
wire [31:0]  ws_final_result;
wire [4:0]   ws_rt;
wire [31:0]  ws_rt_value;
wire         es_lwlr_op;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;

wire [31:0]  cp0_index;
wire [31:0]  cp0_entryhi;
wire [31:0]  cp0_entrylo0;
wire [31:0]  cp0_entrylo1;
wire [7:0]   asid;
assign asid = cp0_entryhi[7:0];
wire [$clog2(TLBNUM)-1:0]  if_index       ;
wire [18:0]  if_vpn2;
wire         if_odd_page;
wire         if_found;
wire [19:0]  if_pfn;
wire [2:0]   if_c;
wire         if_d;
wire         if_v;
wire [$clog2(TLBNUM)-1:0]  es_index       ;
wire [18:0]  es_vpn2;
wire         es_odd_page;
wire         es_found;
wire [19:0]  es_pfn;
wire [2:0]   es_c;
wire         es_d;
wire         es_v;

wire         tlbp_op;
wire         tlbr_op;
wire         tlbp_index_p;
wire [5:0]   tlbp_index_index;


wire [31:0] tlbr_entryhi;
wire [31:0] tlbr_entrylo0;
wire [31:0] tlbr_entrylo1;


wire [$clog2(TLBNUM)-1:0]  r_index;
assign r_index = cp0_index[$clog2(TLBNUM)-1:0];
wire [18:0]               r_vpn2; //entryhi
wire [7:0]                r_asid; //entryhi
wire                      r_g;    //entrylo0 & entrylo1
wire [19:0]               r_pfn0; //entrylo0
wire [2:0]                r_c0;   //entrylo0
wire                      r_d0;   //entrylo0
wire                      r_v0;   //entrylo0
wire [19:0]               r_pfn1; //entrylo1
wire [2:0]                r_c1;   //entrylo1
wire                      r_d1;   //entrylo1
wire                      r_v1;   //entrylo1


wire                       tlb_we;     //write enable
wire [$clog2(TLBNUM)-1:0]  w_index;
wire [18:0]                w_vpn2; //entryhi
wire [7:0]                 w_asid; //entryhi
wire                       w_g;    //entrylo0 & entrylo1
wire [19:0]                w_pfn0; //entrylo0
wire [2:0]                 w_c0;   //entrylo0
wire                       w_d0;   //entrylo0
wire                       w_v0;   //entrylo0
wire [19:0]                w_pfn1; //entrylo1
wire [2:0]                 w_c1;   //entrylo1
wire                       w_d1;   //entrylo1
wire                       w_v1;   //entrylo1

assign w_index = cp0_index[$clog2(TLBNUM)-1:0];
assign w_vpn2 = cp0_entryhi[31:13];
assign w_asid = cp0_entryhi[7:0];
assign w_g = cp0_entrylo0[0] & cp0_entrylo1[0];
assign w_pfn0 = cp0_entrylo0[31:6];
assign w_c0 = cp0_entrylo0[5:3];
assign w_d0 = cp0_entrylo0[2];
assign w_v0 = cp0_entrylo0[1];
assign w_pfn1 = cp0_entrylo1[31:6];
assign w_c1 = cp0_entrylo1[5:3];
assign w_d1 = cp0_entrylo1[2];
assign w_v1 = cp0_entrylo1[1];

assign tlbr_entryhi = {r_vpn2, 5'b0, r_asid};
assign tlbr_entrylo0 = {r_pfn0, r_c0, r_d0, r_v0, r_g};
assign tlbr_entrylo1 = {r_pfn1, r_c1, r_d1, r_v1, r_g};


// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // sram-like 
    .inst_req          (inst_req     ),
    .inst_wr           (inst_wr      ),
    .inst_size         (inst_size    ),
    .inst_addr         (inst_addr    ),
    .inst_wdata        (inst_wdata   ),
    .inst_rdata        (inst_rdata   ),
    .inst_addr_ok      (inst_addr_ok ),
    .inst_data_ok      (inst_data_ok ),
    //exception
    .ws_reflush        (ws_reflush   ),
    .exception_pc      (exception_pc ),
    // TLB
    .if_vpn2           (if_vpn2      ),
    .if_odd_page       (if_odd_page  ),
    .if_index          (if_index     ),
    .if_found          (if_found     ),
    .if_pfn            (if_pfn       ),
    .if_c              (if_c         ),
    .if_d              (if_d         ),
    .if_v              (if_v         )
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //from es
    .es_dest        (es_dest        ),
    .es_valid       (es_valid       ),
    .es_load_op     (es_load_op     ),
    .es_lwlr_op     (es_lwlr_op     ),
    .es_final_result(es_final_result),
    .es_gr_we       (es_gr_we       ),        
    //from ms
    .ms_dest        (ms_dest        ),
    .ms_valid       (ms_valid       ),
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_gr_we       (ms_gr_we       ),
    .ms_load_op     (ms_load_op     ),
    .ms_ready_go    (ms_ready_go    ),
    .ms_final_result(ms_final_result),         
    //from ws
    .ws_dest        (ws_dest        ),
    .ws_valid       (ws_valid       ), 
    .ws_gr_we       (ws_gr_we       ),
    .ws_final_result(ws_final_result),       
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //exception
    .es_mfc0_op     (es_mfc0_op     ),
    .ms_mfc0_op     (ms_mfc0_op     ),
    .eret_cmt       (eret_cmt       ),
    .ws_reflush     (ws_reflush     ),
    .int_cmt        (int_cmt        )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .resetn         (resetn         ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ds
    .es_dest        (es_dest        ),
    .es_valid       (es_valid       ),
    .es_load_op     (es_load_op     ),
    .es_lwlr_op     (es_lwlr_op     ),
    .es_final_result(es_final_result), 
    .es_gr_we       (es_gr_we       ),   
    // data sram-like interface
    .data_req       (data_req       ),
    .data_wr        (data_wr        ),
    .data_size      (data_size      ),
    .data_addr      (data_addr      ),
    .data_wdata     (data_wdata     ),
    .data_wstrb     (data_wstrb     ),
    .data_addr_ok   (data_addr_ok   ),
    //exception
    .es_mfc0_op     (es_mfc0_op     ),
    .ws_reflush     (ws_reflush     ),
    .ms_reflush     (ms_reflush     ),
    // TLB
    .es_vpn2        (es_vpn2      ),
    .es_odd_page    (es_odd_page  ),
    .es_index       (es_index     ),
    .es_found       (es_found     ),
    .es_pfn         (es_pfn       ),
    .es_c           (es_c         ),
    .es_d           (es_d         ),
    .es_v           (es_v         ),
    .ms_mtc0_op     (ms_mtc0_op   ),
    .ws_mtc0_op     (ws_mtc0_op   ),
    .cp0_entryhi    (cp0_entryhi  )
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .resetn         (resetn         ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to ds
    .ms_dest        (ms_dest        ),
    .ms_valid       (ms_valid       ), 
    .ms_load_op     (ms_load_op     ),
    .ms_ready_go    (ms_ready_go    ),
    .ms_gr_we       (ms_gr_we       ),
    .ms_final_result(ms_final_result), 
    // from ws
    .ws_rt          (ws_rt          ),
    .ws_rt_value    (ws_rt_value    ),      
    // //from data-sram
    // .data_sram_rdata(data_sram_rdata),
    .data_rdata     (data_rdata     ),
    .data_data_ok   (data_data_ok   ),
    // exception
    .ms_mfc0_op     (ms_mfc0_op     ),
    .ws_reflush     (ws_reflush     ),
    .ms_reflush     (ms_reflush     ),
    // TLB
    .ms_mtc0_op     (ms_mtc0_op     )
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //to ds
    .ws_dest        (ws_dest        ),
    .ws_valid       (ws_valid       ), 
    .ws_gr_we       (ws_gr_we       ),
    .ws_final_result(ws_final_result),   
    .ws_rt(ws_rt)                    ,
    .ws_rt_value(ws_rt_value)        ,
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //exception
    .ws_rd            (ws_rd            ),    
    .ws_inst_in_slot  (ws_inst_in_slot  ),   
    .ws_pc            (ws_pc            ),       
    .ws_mtc0_op       (ws_mtc0_op       ),  
    .ws_mfc0_op       (ws_mfc0_op       ),
    .ws_eret_cmt      (ws_eret_cmt      ),  
    .ws_exception_cmt (ws_exception_cmt ),
    .ws_mfc0_data     (ws_mfc0_data     ),
    .ws_reflush       (ws_reflush       ),
    .ws_badvaddr      (ws_badvaddr      ),
    .cp0_epc          (cp0_epc          ),
    .exception_pc     (exception_pc     ),
    .tlbp_op          (tlbp_op          ),
    .tlbr_op          (tlbr_op          ),
    .tlbp_index_p     (tlbp_index_p     ),
    .tlbp_index_index (tlbp_index_index ),
    .tlbwi_op         (tlb_we           )
); 


cp0 cp0(
    .clk              (clk             ),
    .resetn           (resetn          ),
    .pc               (ws_pc           ),
    .exception_cmt    (ws_exception_cmt),        
    .eret_cmt         (ws_eret_cmt     ),
    .inst_in_slot     (ws_inst_in_slot ),    
    .mtc0_op          (ws_mtc0_op      ),
    .mfc0_op          (ws_mfc0_op      ),
    .cp0_addr         (ws_rd           ),    
    .mtc0_data        (ws_final_result ), 
    .mfc0_data        (ws_mfc0_data    ), 
    .epc              (cp0_epc         ),
    .int_cmt          (int_cmt         ),           
    .ws_badvaddr      (ws_badvaddr     ),
    .cp0_entryhi      (cp0_entryhi     ),
    .cp0_entrylo0     (cp0_entrylo0    ),
    .cp0_entrylo1     (cp0_entrylo1    ),
    .cp0_index        (cp0_index       ),
    .tlbp_op          (tlbp_op         ),
    .tlbp_index_p     (tlbp_index_p    ),
    .tlbp_index_index (tlbp_index_index),
    .tlbr_op          (tlbr_op         ),
    .tlbr_entryhi     (tlbr_entryhi    ),
    .tlbr_entrylo0    (tlbr_entrylo0   ),
    .tlbr_entrylo1    (tlbr_entrylo1   )
);

cpu_axi_interface cpu_sram_axi_interface(
    .clk            (clk             ),
    .resetn         (resetn          ),
    .inst_req       (inst_req        ),
    .inst_wr        (inst_wr         ),
    .inst_size      (inst_size       ),
    .inst_addr      (inst_addr       ),
    .inst_wdata     (inst_wdata      ),
    .inst_rdata     (inst_rdata      ),
    .inst_addr_ok   (inst_addr_ok    ),
    .inst_data_ok   (inst_data_ok    ),
    .data_req       (data_req        ),
    .data_wr        (data_wr         ),
    .data_size      (data_size       ),
    .data_addr      (data_addr       ),
    .data_wdata     (data_wdata      ),
    .data_wstrb     (data_wstrb      ),
    .data_rdata     (data_rdata      ),
    .data_addr_ok   (data_addr_ok    ),
    .data_data_ok   (data_data_ok    ),
    .arid           (arid            ),
    .araddr         (araddr          ),
    .arlen          (arlen           ),
    .arsize         (arsize          ),
    .arburst        (arburst         ),
    .arlock         (arlock          ),
    .arcache        (arcache         ),
    .arprot         (arprot          ),
    .arvalid        (arvalid         ),
    .arready        (arready         ),
    .rid            (rid             ),
    .rdata          (rdata           ),
    .rresp          (rresp           ),
    .rlast          (rlast           ),
    .rvalid         (rvalid          ),
    .rready         (rready          ),
    .awid           (awid            ),
    .awaddr         (awaddr          ),
    .awlen          (awlen           ),
    .awsize         (awsize          ),
    .awburst        (awburst         ),
    .awlock         (awlock          ),
    .awcache        (awcache         ),
    .awprot         (awprot          ),
    .awvalid        (awvalid         ),
    .awready        (awready         ),
    .wid            (wid             ),
    .wdata          (wdata           ),
    .wstrb          (wstrb           ),
    .wlast          (wlast           ),
    .wvalid         (wvalid          ),
    .wready         (wready          ),
    .bid            (bid             ),
    .bresp          (bresp           ),
    .bvalid         (bvalid          ),
    .bready         (bready          )
);

tlb tlb0(
    .clk            (clk             ),
    // search port 0
    .s0_vpn2        (if_vpn2         ),
    .s0_odd_page    (if_odd_page     ),
    .s0_asid        (asid            ),
    .s0_found       (if_found        ),
    .s0_index       (if_index        ),
    .s0_pfn         (if_pfn          ),
    .s0_c           (if_c            ),
    .s0_d           (if_d            ),
    .s0_v           (if_v            ),
    // search port 1
    .s1_vpn2        (es_vpn2         ),
    .s1_odd_page    (es_odd_page     ),
    .s1_asid        (asid            ),
    .s1_found       (es_found        ),
    .s1_index       (es_index        ),
    .s1_pfn         (es_pfn          ),
    .s1_c           (es_c            ),
    .s1_d           (es_d            ),
    .s1_v           (es_v            ),
    // read port
    .r_index        (r_index         ),
    .r_vpn2         (r_vpn2          ),
    .r_asid         (r_asid          ),
    .r_g            (r_g             ),
    .r_pfn0         (r_pfn0          ),
    .r_c0           (r_c0            ),
    .r_d0           (r_d0            ),
    .r_v0           (r_v0            ),
    .r_pfn1         (r_pfn1          ),
    .r_c1           (r_c1            ),
    .r_d1           (r_d1            ),
    .r_v1           (r_v1            ),
    // write port
    .we             (tlb_we          ),
    .w_index        (w_index         ),
    .w_vpn2         (w_vpn2          ),
    .w_asid         (w_asid          ),
    .w_g            (w_g             ),
    .w_pfn0         (w_pfn0          ),
    .w_c0           (w_c0            ),
    .w_d0           (w_d0            ),
    .w_v0           (w_v0            ),
    .w_pfn1         (w_pfn1          ),
    .w_c1           (w_c1            ),
    .w_d1           (w_d1            ),
    .w_v1           (w_v1            )
);

endmodule
