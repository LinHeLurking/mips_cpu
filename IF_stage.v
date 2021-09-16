`include "mycpu.h"

module if_stage
#(
    parameter TLBNUM = 16
)
(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,

    // inst sram-like interface
    output                          inst_req      ,
    output                          inst_wr       ,
    output [1:0]                    inst_size     ,
    output [31:0]                   inst_addr     ,
    output [31:0]                   inst_wdata    ,
    input  [31:0]                   inst_rdata    ,
    input                           inst_addr_ok  ,
    input                           inst_data_ok  ,
    //exception
    input                          ws_reflush     ,
    input  [31:0]                  exception_pc   ,/* from ws */
    // TLB
    output [18:0]                  if_vpn2        ,
    output                         if_odd_page    ,
    input  [$clog2(TLBNUM)-1:0]    if_index       ,
    input                          if_found       ,
    input  [19:0]                  if_pfn         ,
    input  [2:0]                   if_c           ,
    input                          if_d           , 
    input                          if_v           
);


reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;

wire [14:0] exception_cmt;
wire        adel;

reg  [31:0] exception_pc_r;

// bus
// 15 + 32 + 32 = 79
assign fs_to_ds_bus = {exception_cmt,
                       fs_inst ,
                       fs_pc   };

assign {br_taken,br_target} = br_bus;

always @(posedge clk) begin 
    if(ws_reflush) begin 
        exception_pc_r <= exception_pc;
    end
end

// pre-IF stage
wire pre_if_ready_go;
wire pre_if_valid;
wire pre_if_allowin;
reg  inst_addr_ok_r;
reg br_taken_r;
reg ws_reflush_r;
reg inst_req_r;
reg  [31:0] nextpc_r;

// TLB
wire kseg0;
wire kseg1;
wire mapped;
wire tlb_miss;
wire tlb_invalid;
wire [31:0] tlbpc;


// pipeline control
assign pre_if_ready_go  = (inst_addr_ok || inst_addr_ok_r || tlb_miss || tlb_invalid);
assign pre_if_valid     = ~reset;
assign pre_if_allowin   = (!pre_if_valid || pre_if_ready_go && fs_allowin);
assign to_fs_valid      = pre_if_valid && pre_if_ready_go;


// nextpc generate
assign seq_pc           = fs_pc + 3'h4;
assign nextpc = ws_reflush   ? exception_pc   :
                ws_reflush_r ? exception_pc_r :
                br_taken     || br_taken_r   ? br_target      :
                seq_pc;

// inst request
always @(posedge clk) begin 
    if(reset) begin 
        inst_req_r <= 1'b1;
    end else begin 
        if(pre_if_allowin) begin 
            inst_req_r <= 1'b1;
        end else if(pre_if_ready_go) begin 
            inst_req_r <= 1'b0;
        end
    end
end

// latches for control signals
always @(posedge clk) begin 
    if(reset) begin 
        nextpc_r <= 32'hbfc00000;
        br_taken_r <= 1'b0;
        inst_addr_ok_r <= 1'b0;
    end else begin 
        if(pre_if_allowin) begin 
            nextpc_r <= nextpc;
            inst_addr_ok_r <= 1'b0;
            br_taken_r <= 1'b0;
        end
        if(inst_addr_ok) begin 
            inst_addr_ok_r <= 1'b1;
        end
        if(br_taken) begin 
            br_taken_r <= 1'b1;
        end
    end
end

always @(posedge clk) begin 
    if(reset) begin 
        ws_reflush_r <= 1'b0;
    end else begin 
        if((ws_reflush || ws_reflush_r) && fs_ready_go) begin 
            ws_reflush_r <= 1'b0;
        end else if(ws_reflush && fs_valid) begin 
            ws_reflush_r <= 1'b1;
        end
    end
end



assign kseg0 = nextpc_r[31:29] == 3'b100;
assign kseg1 = nextpc_r[31:29] == 3'b101;
assign mapped = !kseg0 && !kseg1;
assign if_vpn2 = nextpc_r[31:13];
assign if_odd_page = nextpc_r[12];
assign tlbpc = mapped ? {if_pfn, nextpc_r[11:0]} : {3'b0, nextpc_r[28:0]};
assign tlb_miss = mapped && !if_found && fs_valid;
assign tlb_invalid = mapped && if_found && !if_v && fs_valid;


assign inst_req   = (inst_req_r) && !(|exception_cmt) && pre_if_valid;
assign inst_wr    = 4'h0;
assign inst_size  = 2'b10;
// assign inst_addr  = nextpc_r;
assign inst_addr  = tlbpc;
assign inst_wdata = 32'b0;


// IF stage
reg  inst_data_ok_r;
assign fs_ready_go    = inst_data_ok || inst_data_ok_r || exception_cmt;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && !ws_reflush && !ws_reflush_r;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end  
end

always @(posedge clk) begin 
    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end 
end

always @(posedge clk) begin 
    if(reset) begin 
        inst_data_ok_r <= 1'b0;
    end else begin 
        if(inst_data_ok) begin 
            inst_data_ok_r <= 1'b1;
        end
        if(fs_allowin) begin 
            inst_data_ok_r <= 1'b0;
        end
    end
end

assign fs_inst         =  inst_rdata;

// exception
assign adel = (fs_pc[1:0] != 2'b00);

/* 
 8  <-> IF TLB miss
 9  <-> IF TLB invalid
 10 <-> EXE TLB read miss
 11 <-> EXE TLB read invalid
 12 <-> EXE TLB write miss
 13 <-> EXE TLB write invalid
 14 <-> EXE TLB modified
 */

assign exception_cmt[ 0   ]  = 1'b0;
assign exception_cmt[ 1   ]  = adel;
assign exception_cmt[ 7: 2]  = 6'b0;
assign exception_cmt[ 8   ]  = tlb_miss;
assign exception_cmt[ 9   ]  = tlb_invalid;
assign exception_cmt[14:10]  = 3'b0;

endmodule
