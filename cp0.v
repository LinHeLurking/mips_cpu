`include "mycpu.h"

module cp0(
    input                           clk              ,
    input                           resetn           ,
    input  [31:0]                   pc               ,
    input  [14:0]                   exception_cmt    ,
    input                           eret_cmt         ,
    input                           inst_in_slot     ,
    input                           mtc0_op          ,
    input                           mfc0_op          ,
    input  [ 4:0]                   cp0_addr         ,
    input  [31:0]                   mtc0_data        ,
    output [31:0]                   mfc0_data        ,
    output [31:0]                   epc              ,
    //lab9 newly added
    output                          int_cmt          ,
    input  [31:0]                   ws_badvaddr      ,
    // TLB
    output [31:0]                   cp0_entryhi      , 
    output [31:0]                   cp0_entrylo0     ,
    output [31:0]                   cp0_entrylo1     ,
    output [31:0]                   cp0_index        ,
    input                           tlbp_op          ,
    input                           tlbr_op          ,
    // in EXE TLB search
    input                           tlbp_index_p      ,
    input  [5:0]                    tlbp_index_index  ,
    // in WB TLB read
    input  [31:0]                   tlbr_entryhi     ,
    input  [31:0]                   tlbr_entrylo0    ,
    input  [31:0]                   tlbr_entrylo1    
    // input  [31:0]                   tlbr_index       
);


wire [5:0] ext_int_in;
assign ext_int_in = 6'd0;

//mtc0
wire        cp0_status_wen;
wire        cp0_cause_wen;
wire        cp0_epc_wen;
wire        cp0_count_wen;
wire        cp0_compare_wen;
wire        cp0_index_wen;
wire        cp0_entryhi_wen;
wire        cp0_entrylo0_wen;
wire        cp0_entrylo1_wen;


//mfc0
wire        cp0_badvaddr_read;
wire        cp0_status_read;
wire        cp0_cause_read;
wire        cp0_epc_read;
wire        cp0_count_read;
wire        cp0_compare_read;
wire        cp0_index_read;
wire        cp0_entryhi_read;
wire        cp0_entrylo0_read;
wire        cp0_entrylo1_read;

//cp0
reg  [31:0] cp0_badvaddr;

wire [31:0] cp0_status;
wire        cp0_status_bev;
reg  [ 7:0] cp0_status_im;
reg         cp0_status_exl;
reg         cp0_status_ie;

wire [31:0] cp0_cause;
reg         cp0_cause_bd;
reg         cp0_cause_ti;
reg  [ 7:0] cp0_cause_ip;
reg  [ 4:0] cp0_cause_exccode;

reg  [31:0] cp0_epc;
reg  [31:0] cp0_count;
reg  [31:0] cp0_compare;

wire [31:0] epc_data;

// entryhi entrylo0 entrylo1 index
//wire [31:0] cp0_entryhi;
//wire [31:0] cp0_entrylo0;
//wire [31:0] cp0_entrylo1;
//wire [31:0] cp0_index;

reg  cp0_index_p;
reg  [3:0] cp0_index_index;
assign cp0_index = {cp0_index_p, 27'b0, cp0_index_index};

reg [19:0] cp0_entrylo0_pfn;
reg [2:0]  cp0_entrylo0_c;
reg cp0_entrylo0_d;
reg cp0_entrylo0_v;
reg cp0_entrylo0_g;
assign cp0_entrylo0 = {6'b0, cp0_entrylo0_pfn, cp0_entrylo0_c, cp0_entrylo0_d, cp0_entrylo0_v, cp0_entrylo0_g};

reg [19:0] cp0_entrylo1_pfn;
reg [2:0]  cp0_entrylo1_c;
reg cp0_entrylo1_d;
reg cp0_entrylo1_v;
reg cp0_entrylo1_g;
assign cp0_entrylo1 = {6'b0, cp0_entrylo1_pfn, cp0_entrylo1_c, cp0_entrylo1_d, cp0_entrylo1_v, cp0_entrylo1_g};

reg [18:0] cp0_entryhi_vpn2;
reg [7:0] cp0_entryhi_asid;
assign cp0_entryhi = {cp0_entryhi_vpn2, 5'b0, cp0_entryhi_asid};

assign epc_data = inst_in_slot ? pc - 32'd4
                               : pc;

wire tlb_exception;
assign tlb_exception = |exception_cmt[14:8];

assign epc = cp0_epc;

assign ie_value = cp0_status_ie;

assign int_cmt = cp0_status_ie   &&!cp0_status_exl   &&
                (cp0_cause_ip[7] && cp0_status_im[7] ||
                 cp0_cause_ip[6] && cp0_status_im[6] ||
                 cp0_cause_ip[5] && cp0_status_im[5] ||
                 cp0_cause_ip[4] && cp0_status_im[4] ||
                 cp0_cause_ip[3] && cp0_status_im[3] ||
                 cp0_cause_ip[2] && cp0_status_im[2] ||
                 cp0_cause_ip[1] && cp0_status_im[1] ||
                 cp0_cause_ip[0] && cp0_status_im[0] );

//mtc0
assign cp0_index_wen      = mtc0_op & (cp0_addr == 4'd0 );
assign cp0_entrylo0_wen   = mtc0_op & (cp0_addr == 4'd2 );
assign cp0_entrylo1_wen   = mtc0_op & (cp0_addr == 4'd3 );
assign cp0_count_wen      = mtc0_op & (cp0_addr == 4'd9 );
assign cp0_entryhi_wen    = mtc0_op & (cp0_addr == 4'd10);
assign cp0_compare_wen    = mtc0_op & (cp0_addr == 4'd11);
assign cp0_status_wen     = mtc0_op & (cp0_addr == 4'd12);
assign cp0_cause_wen      = mtc0_op & (cp0_addr == 4'd13);
assign cp0_epc_wen        = mtc0_op & (cp0_addr == 4'd14);

//mfc0
assign cp0_index_read     = mfc0_op & (cp0_addr == 4'd0 );
assign cp0_entrylo0_read  = mfc0_op & (cp0_addr == 4'd2 );
assign cp0_entrylo1_read  = mfc0_op & (cp0_addr == 4'd3 );
assign cp0_badvaddr_read  = mfc0_op & (cp0_addr == 4'd8 );
assign cp0_count_read     = mfc0_op & (cp0_addr == 4'd9 );
assign cp0_entryhi_read   = mfc0_op & (cp0_addr == 4'd10);
assign cp0_compare_read   = mfc0_op & (cp0_addr == 4'd11);
assign cp0_status_read    = mfc0_op & (cp0_addr == 4'd12);
assign cp0_cause_read     = mfc0_op & (cp0_addr == 4'd13);
assign cp0_epc_read       = mfc0_op & (cp0_addr == 4'd14);

assign mfc0_data = ({32{cp0_index_read   }} & cp0_index   )
                 | ({32{cp0_entrylo0_read}} & cp0_entrylo0)
                 | ({32{cp0_entrylo1_read}} & cp0_entrylo1)
                 | ({32{cp0_badvaddr_read}} & cp0_badvaddr)
                 | ({32{cp0_count_read   }} & cp0_count   )
                 | ({32{cp0_entryhi_read }} & cp0_entryhi )
                 | ({32{cp0_compare_read }} & cp0_compare )
                 | ({32{cp0_status_read  }} & cp0_status  )
                 | ({32{cp0_cause_read   }} & cp0_cause   )
                 | ({32{cp0_epc_read     }} & cp0_epc     );

//cp0
//badvaddr
wire ade;
assign ade = exception_cmt[1] || exception_cmt[2] || exception_cmt[6] || tlb_exception;

always @(posedge clk) 
begin
    if (ade)
        cp0_badvaddr <= ws_badvaddr;
end

//status
assign cp0_status = { 9'd0,
                      cp0_status_bev, //22
                      6'd0,
                      cp0_status_im,  //15:8
                      6'd0,
                      cp0_status_exl, //1
                      cp0_status_ie   //0
                    };

assign cp0_status_bev = 1'b1;

always @(posedge clk) begin
    if(~resetn) begin 
        cp0_index_index <= 4'b0;
        cp0_index_p <= 1'b0;
    end else begin 
        if(tlbp_op) begin 
            cp0_index_p <= tlbp_index_p;
            cp0_index_index <= tlbp_index_index[3:0];
        end else if(cp0_index_wen) begin
            cp0_index_index <= mtc0_data[3:0];
        end
    end
end

always @(posedge clk) begin 
    if(~resetn) begin 
        cp0_entrylo0_pfn <= 20'b0;
        cp0_entrylo0_c <= 3'b0;
        cp0_entrylo0_d <= 1'b0;
        cp0_entrylo0_v <= 1'b0;
        cp0_entrylo0_g <= 1'b0;
    end else begin
        if(tlbr_op) begin 
            cp0_entrylo0_pfn <= tlbr_entrylo0[25:6];
            cp0_entrylo0_c   <= tlbr_entrylo0[5:3];
            cp0_entrylo0_d   <= tlbr_entrylo0[2:2];
            cp0_entrylo0_v   <= tlbr_entrylo0[1:1];
            cp0_entrylo0_g   <= tlbr_entrylo0[0:0];
        end else if(cp0_entrylo0_wen) begin 
            cp0_entrylo0_pfn <= mtc0_data[25:6];
            cp0_entrylo0_c   <= mtc0_data[5:3];
            cp0_entrylo0_d   <= mtc0_data[2:2];
            cp0_entrylo0_v   <= mtc0_data[1:1];
            cp0_entrylo0_g   <= mtc0_data[0:0];
        end
    end
end

always @(posedge clk) begin 
    if(~resetn) begin 
        cp0_entrylo1_pfn <= 20'b0;
        cp0_entrylo1_c <= 3'b0;
        cp0_entrylo1_d <= 1'b0;
        cp0_entrylo1_v <= 1'b0;
        cp0_entrylo1_g <= 1'b0;
    end else begin 
        if(tlbr_op) begin 
            cp0_entrylo1_pfn <= tlbr_entrylo1[25:6];
            cp0_entrylo1_c   <= tlbr_entrylo1[5:3];
            cp0_entrylo1_d   <= tlbr_entrylo1[2:2];
            cp0_entrylo1_v   <= tlbr_entrylo1[1:1];
            cp0_entrylo1_g   <= tlbr_entrylo1[0:0];
        end else if(cp0_entrylo1_wen) begin 
            cp0_entrylo1_pfn <= mtc0_data[25:6];
            cp0_entrylo1_c   <= mtc0_data[5:3];
            cp0_entrylo1_d   <= mtc0_data[2:2];
            cp0_entrylo1_v   <= mtc0_data[1:1];
            cp0_entrylo1_g   <= mtc0_data[0:0];
        end
    end
end

always @(posedge clk) begin 
    if(~resetn) begin 
        cp0_entryhi_vpn2 <= 19'b0;
        cp0_entryhi_asid <= 8'b0;
    end else begin 
        if(tlbr_op) begin 
            cp0_entryhi_vpn2 <= tlbr_entryhi[31:13];
            cp0_entryhi_asid <= tlbr_entryhi[7:0];
        end else if(cp0_entryhi_wen) begin 
            cp0_entryhi_vpn2 <= mtc0_data[31:13];
            cp0_entryhi_asid <= mtc0_data[7:0];
        end else if(tlb_exception) begin 
            cp0_entryhi_vpn2 <= ws_badvaddr[31:13];
        end
    end
end

always@(posedge clk)
begin
    if(~resetn) begin 
        cp0_status_im <= 8'b0;
    end else if(cp0_status_wen)
        cp0_status_im <= mtc0_data[15:8];
end


always@(posedge clk)
begin
    if(~resetn)
        cp0_status_exl <= 1'b0;
    else if(cp0_status_wen)
        cp0_status_exl <= mtc0_data[1];
    else if(exception_cmt && cp0_status_exl == 1'b0)
        cp0_status_exl <= 1'b1;
    else if(eret_cmt)
        cp0_status_exl <= 1'b0;
end

always@(posedge clk)
begin
    if(~resetn)
        cp0_status_ie <= 1'b0;
    else if(cp0_status_wen)
        cp0_status_ie <= mtc0_data[0];
end
//cause
assign cp0_cause = { cp0_cause_bd, //32
                     cp0_cause_ti, //31
                     14'd0,
                     cp0_cause_ip, //15:8
                     1'b0,
                     cp0_cause_exccode, //6:2
                     2'd0
                    };

always@(posedge clk)
begin
    if(~resetn)
        cp0_cause_bd <= 1'b0;
    else if(exception_cmt && !cp0_status_exl)
        cp0_cause_bd <= inst_in_slot;
end

always@(posedge clk)
begin
    if(~resetn)
        cp0_cause_ti <= 1'b0;
    else if(cp0_count == cp0_compare)
        cp0_cause_ti <= 1'b1;
    else if(cp0_compare_wen)
        cp0_cause_ti <= 1'b0;
end

always@(posedge clk)
begin
    if(~resetn)
        cp0_cause_ip[1:0] <= 2'd0;
    else if(cp0_cause_wen)
        cp0_cause_ip[1:0] <= mtc0_data[9:8];
end 

always @(posedge clk) 
begin
    if (~resetn)
        cp0_cause_ip[7:2] <= 6'b0;
    else begin
        cp0_cause_ip[7] <= ext_int_in[5] | cp0_cause_ti;
        cp0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end

always@(posedge clk)
begin
    if(~resetn)
        cp0_cause_exccode <= 5'd31;
    else if(exception_cmt[9:8])
        cp0_cause_exccode <= 5'd2; // TLBL_if
    else if(exception_cmt[11:10])
        cp0_cause_exccode <= 5'd2; // TLBL_es
    else if(exception_cmt[13:12]) 
        cp0_cause_exccode <= 5'd3; // TLBS_es
    else if(exception_cmt[14])
        cp0_cause_exccode <= 5'd1; // TLBM
    else if(exception_cmt[0])
        cp0_cause_exccode <= 5'd0; // int
    else if(exception_cmt[1])
        cp0_cause_exccode <= 5'd4; // ADEL_if
    else if(exception_cmt[5])
        cp0_cause_exccode <= 5'd10; // Reserved Instruction
    else if(exception_cmt[3])
        cp0_cause_exccode <= 5'd8; // syscall
    else if(exception_cmt[4])
        cp0_cause_exccode <= 5'd9; // breakpoint
    else if(exception_cmt[7])
        cp0_cause_exccode <= 5'd12; // Overflow
    else if(exception_cmt[6])
        cp0_cause_exccode <= 5'd5; // ADES
    else if(exception_cmt[2])
        cp0_cause_exccode <= 5'd4; // ADEL_mem
end
//epc
always@(posedge clk)
begin
    if(exception_cmt && cp0_status_exl != 1'b1)
        cp0_epc <= epc_data;
    else if(cp0_epc_wen)
        cp0_epc <= mtc0_data;
end
//count
reg tick;
always @(posedge clk) 
begin
    if (~resetn) tick <= 1'b0;
    else tick <= ~tick;
end

always@(posedge clk)
begin
    if(cp0_count_wen)
        cp0_count <= mtc0_data;
    else if(tick)
        cp0_count <= cp0_count + 32'b1;
end
//compare
always@(posedge clk)
begin
    if(cp0_compare_wen)
        cp0_compare <= mtc0_data;
end

endmodule
