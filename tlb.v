module tlb
#(
    parameter TLBNUM = 16
)
(
    input                       clk,
    // search port 0
    input [18:0]                s0_vpn2,    //vaddr 31..13
    input                       s0_odd_page,//vaddr 12
    input [7:0]                 s0_asid,    //entryhi
    output                      s0_found,
    output [$clog2(TLBNUM)-1:0] s0_index,
    output [19:0]               s0_pfn,
    output [2:0]                s0_c,
    output                      s0_d,
    output                      s0_v,
    // search port 1
    input [18:0]                s1_vpn2,    //vaddr 31..13
    input                       s1_odd_page,//vaddr 12
    input [7:0]                 s1_asid,    //entryhi
    output                      s1_found,
    output [$clog2(TLBNUM)-1:0] s1_index,
    output [19:0]               s1_pfn,
    output [2:0]                s1_c,
    output                      s1_d,
    output                      s1_v,
    // write port
    input                       we,     //write enable
    input [$clog2(TLBNUM)-1:0]  w_index,
    input [18:0]                w_vpn2, //entryhi
    input [7:0]                 w_asid, //entryhi
    input                       w_g,    //entrylo0 & entrylo1
    input [19:0]                w_pfn0, //entrylo0
    input [2:0]                 w_c0,   //entrylo0
    input                       w_d0,   //entrylo0
    input                       w_v0,   //entrylo0
    input [19:0]                w_pfn1, //entrylo1
    input [2:0]                 w_c1,   //entrylo1
    input                       w_d1,   //entrylo1
    input                       w_v1,   //entrylo1
    // read port
    input [$clog2(TLBNUM)-1:0]  r_index, 
    output [18:0]               r_vpn2, //entryhi
    output [7:0]                r_asid, //entryhi
    output                      r_g,    //entrylo0 & entrylo1
    output [19:0]               r_pfn0, //entrylo0
    output [2:0]                r_c0,   //entrylo0
    output                      r_d0,   //entrylo0
    output                      r_v0,   //entrylo0
    output [19:0]               r_pfn1, //entrylo1
    output [2:0]                r_c1,   //entrylo1
    output                      r_d1,   //entrylo1
    output                      r_v1    //entrylo1
);
    reg [18:0]  tlb_vpn2[TLBNUM-1:0];
    reg [7:0]   tlb_asid[TLBNUM-1:0];
    reg         tlb_g   [TLBNUM-1:0];
    reg [19:0]  tlb_pfn0[TLBNUM-1:0];
    reg [2:0]   tlb_c0  [TLBNUM-1:0];
    reg         tlb_d0  [TLBNUM-1:0];
    reg         tlb_v0  [TLBNUM-1:0];
    reg [19:0]  tlb_pfn1[TLBNUM-1:0];
    reg [2:0]   tlb_c1  [TLBNUM-1:0];
    reg         tlb_d1  [TLBNUM-1:0];
    reg         tlb_v1  [TLBNUM-1:0];

    // write
    always @(posedge clk) begin
        if (we) begin
            tlb_vpn2[w_index] <= w_vpn2;
            tlb_g   [w_index] <= w_g   ;
            tlb_asid[w_index] <= w_asid;
            tlb_pfn0[w_index] <= w_pfn0;
            tlb_c0  [w_index] <= w_c0  ;
            tlb_d0  [w_index] <= w_d0  ;
            tlb_v0  [w_index] <= w_v0  ;
            tlb_pfn1[w_index] <= w_pfn1;
            tlb_c1  [w_index] <= w_c1  ;
            tlb_d1  [w_index] <= w_d1  ;
            tlb_v1  [w_index] <= w_v1  ;
        end
    end
    
    genvar i;

    // port 0 search
    wire [TLBNUM-1:0] s0_match;
    wire [19:0] s0_pfn_arr[TLBNUM:0];
    wire [4:0]  s0_idx_arr[TLBNUM:0];
    wire [2:0]  s0_c_arr  [TLBNUM:0];
    wire        s0_v_arr  [TLBNUM:0];
    wire        s0_d_arr  [TLBNUM:0];
    
    assign s0_pfn_arr[0] = 32'd0;
    assign s0_idx_arr[0] =  5'd0;
    assign s0_c_arr[0]   =  3'd0;
    assign s0_v_arr[0]   =  1'd0; 
    assign s0_d_arr[0]   =  1'd0; 
    
    generate
        for (i=0; i<TLBNUM; i=i+1) begin
            assign s0_match[i]     = (s0_vpn2 == tlb_vpn2[i]) && (tlb_g[i] || tlb_asid[i] == s0_asid);
            assign s0_idx_arr[i+1] = s0_idx_arr[i] | { 5{s0_match[i]}} & i;
            assign s0_pfn_arr[i+1] = s0_pfn_arr[i] | {20{s0_match[i]}} & (s0_odd_page ? tlb_pfn1[i] : tlb_pfn0[i]);
            assign s0_c_arr  [i+1] = s0_c_arr  [i] | { 3{s0_match[i]}} & (s0_odd_page ? tlb_c1  [i] : tlb_c0  [i]);
            assign s0_v_arr  [i+1] = s0_v_arr  [i] | { 1{s0_match[i]}} & (s0_odd_page ? tlb_v1  [i] : tlb_v0  [i]);
            assign s0_d_arr  [i+1] = s0_d_arr  [i] | { 1{s0_match[i]}} & (s0_odd_page ? tlb_d1  [i] : tlb_d0  [i]);
        end
    endgenerate

    assign s0_found =(s0_match != 16'b0);
    assign s0_pfn   = s0_pfn_arr[TLBNUM];
    assign s0_index = s0_idx_arr[TLBNUM];
    assign s0_c     = s0_c_arr  [TLBNUM];
    assign s0_v     = s0_v_arr  [TLBNUM];
    assign s0_d     = s0_d_arr  [TLBNUM];
    
    // port 1 search
    wire [TLBNUM-1:0] s1_match;
    wire [19:0] s1_pfn_arr[TLBNUM:0];
    wire [4:0]  s1_idx_arr[TLBNUM:0];
    wire [2:0]  s1_c_arr  [TLBNUM:0];
    wire        s1_d_arr  [TLBNUM:0];
    wire        s1_v_arr  [TLBNUM:0];

    assign s1_pfn_arr[0] = 32'd0;
    assign s1_idx_arr[0] =  5'd0;
    assign s1_c_arr[0]   =  3'd0;
    assign s1_d_arr[0]   =  1'd0; 
    assign s1_v_arr[0]   =  1'd0; 

    generate
        for (i=0; i<TLBNUM; i=i+1) begin
            assign s1_match[i]     = (s1_vpn2 == tlb_vpn2[i]) && (tlb_g[i] || tlb_asid[i] == s1_asid);
            assign s1_idx_arr[i+1] = s1_idx_arr[i] | { 5{s1_match[i]}} & i;
            assign s1_pfn_arr[i+1] = s1_pfn_arr[i] | {20{s1_match[i]}} & (s1_odd_page ? tlb_pfn1[i] : tlb_pfn0[i]);
            assign s1_c_arr  [i+1] = s1_c_arr  [i] | { 3{s1_match[i]}} & (s1_odd_page ? tlb_c1  [i] : tlb_c0  [i]);
            assign s1_d_arr  [i+1] = s1_d_arr  [i] | { 1{s1_match[i]}} & (s1_odd_page ? tlb_d1  [i] : tlb_d0  [i]);
            assign s1_v_arr  [i+1] = s1_v_arr  [i] | { 1{s1_match[i]}} & (s1_odd_page ? tlb_v1  [i] : tlb_v0  [i]);
        end
    endgenerate

    assign s1_found =(s1_match != 16'b0);
    assign s1_pfn   = s1_pfn_arr[TLBNUM];
    assign s1_index = s1_idx_arr[TLBNUM];
    assign s1_c     = s1_c_arr  [TLBNUM];
    assign s1_v     = s1_v_arr  [TLBNUM];
    assign s1_d     = s1_d_arr  [TLBNUM];
    
    // read
    assign r_vpn2 = tlb_vpn2[r_index];
    assign r_asid = tlb_asid[r_index];
    assign r_g    = tlb_g   [r_index];
    assign r_pfn0 = tlb_pfn0[r_index];
    assign r_c0   = tlb_c0  [r_index];
    assign r_d0   = tlb_d0  [r_index];
    assign r_v0   = tlb_v0  [r_index];
    assign r_pfn1 = tlb_pfn1[r_index];
    assign r_c1   = tlb_c1  [r_index];
    assign r_d1   = tlb_d1  [r_index];
    assign r_v1   = tlb_v1  [r_index];

endmodule