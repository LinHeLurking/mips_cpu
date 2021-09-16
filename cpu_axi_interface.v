`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/14/2019 03:00:28 PM
// Design Name: 
// Module Name: cpu_axi_interface
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 001 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module cpu_axi_interface(
    input clk            ,
    input resetn         ,

    //inst sram-like 
    input inst_req      ,
    input inst_wr       ,
    input [1:0] inst_size     ,
    input [31:0] inst_addr     ,
    input [31:0] inst_wdata    ,
    output reg [31:0] inst_rdata    ,
    output reg inst_addr_ok  ,
    output reg inst_data_ok  ,
    
    //data sram-like 
    input data_req      ,
    input data_wr       ,
    input [1:0] data_size     ,
    input [31:0] data_addr     ,
    input [31:0] data_wdata    ,
    input [3:0]  data_wstrb    ,
    output reg [31:0] data_rdata    ,
    output reg data_addr_ok  ,
    output reg data_data_ok  ,

    //axi
    //ar
    output reg [3:0] arid      ,
    output reg [31:0] araddr    ,
    output reg [7:0] arlen     ,
    output reg [2:0] arsize    ,
    output reg [1:0] arburst   ,
    output reg [1:0] arlock    ,
    output reg [3:0] arcache   ,
    output reg [2:0] arprot    ,
    output reg arvalid   ,
    input arready   ,
    //r              
    input [3:0] rid       ,
    input [31:0] rdata     ,
    input [1:0] rresp     ,
    input rlast     ,
    input rvalid    ,
    output reg rready    ,
    //aw           
    output reg [3:0] awid      ,
    output reg [31:0] awaddr    ,
    output reg [7:0] awlen     ,
    output reg [2:0] awsize    ,
    output reg [1:0] awburst   ,
    output reg [1:0] awlock    ,
    output reg [3:0] awcache   ,
    output reg [2:0] awprot    ,
    output reg awvalid   ,
    input awready   ,
    //w          
    output reg [3:0] wid       ,
    output reg [31:0] wdata     ,
    output reg [3:0] wstrb     ,
    output reg wlast     ,
    output reg wvalid    ,
    input wready    ,
    //b              
    input [3:0] bid       ,
    input [1:0] bresp     ,
    input bvalid    ,
    output reg bready    
);

reg valid;
// 0 -> inst
// 1 -> data
reg inst_or_data;
reg we;
reg [31:0] wdata_r;
reg [3:0] wstrb_r;
reg [31:0] raddr_r;
wire allowin;
wire ready_go;

assign allowin = !valid || ready_go;
assign ready_go = (rready && rvalid) || (bvalid && bready);

// constant values
always @(posedge clk) begin 
    if(!resetn) begin 
        arlen <= 8'b0;
        arburst <= 2'b01;
        arlock <= 2'b0;
        arcache <= 4'b0;
        arprot <= 3'b0;
        awid <= 4'b1;
        awlen <= 8'b0;
        awburst <= 2'b01;
        awlock <= 2'b0;
        awcache <= 4'b0;
        awprot <= 3'b0;
        wid <= 4'b1;
        wlast <= 1'b1;
    end
end

// valid 
always @(posedge clk) begin 
    if(!resetn) begin 
        valid <= 1'b0;
    end else begin 
        if(allowin) begin 
            if(inst_req || data_req) begin 
                valid <= 1'b1;
            end else begin
                valid <= 1'b0;
            end
        end
    end
end

// inst_or_data
always @(posedge clk) begin 
    if(!resetn) begin 
        inst_or_data <= 1'b0;
    end else begin 
        if(allowin) begin 
            if(data_req) begin 
                inst_or_data <= 1'b1;
            end else if(inst_req) begin 
                inst_or_data <= 1'b0;
            end
        end
    end
end

// we
always @(posedge clk) begin 
    if(!resetn) begin 
        we <= 1'b0;
    end else begin 
        if(allowin) begin 
            if((data_req && data_wr) || (inst_req && inst_wr)) begin 
                we <= 1'b1;
            end else begin 
                we <= 1'b0;
            end
        end
    end
end

// sram-like channel

// data_addr_ok, inst_addr_ok
always @(posedge clk) begin 
    if(!resetn) begin 
        data_addr_ok <= 1'b0;
    end else begin 
        if(allowin) begin 
            if(data_req) begin 
                data_addr_ok <= 1'b1;
            end else if(inst_req) begin 
                inst_addr_ok <= 1'b1;
            end
        end else begin 
            data_addr_ok <= 1'b0;
            inst_addr_ok <= 1'b0;
        end
    end
end

// data_data_ok, inst_data_ok 
always @(posedge clk) begin 
    if(!resetn) begin 
        data_data_ok <= 1'b0;
        inst_data_ok <= 1'b0;
    end else begin 
        if(valid && ready_go) begin 
            if(inst_or_data == 1) begin 
                data_data_ok <= 1'b1;
            end else if(inst_or_data == 0) begin 
                inst_data_ok <= 1'b1;
            end
        end else begin 
            data_data_ok <= 1'b0;
            inst_data_ok <= 1'b0;
        end
    end
end

// data_rdata, inst_rdata
always @(posedge clk) begin 
    if(!resetn) begin 
        data_rdata <= 32'b0;
        inst_rdata <= 32'b0;
    end else begin 
        if(valid && ready_go) begin 
            data_rdata <= rdata;
            inst_rdata <= rdata;
        end
    end
end 

// axi read request channel

// arid 
always @(posedge clk) begin 
    if(!resetn) begin 
        arid <= 4'b0;
    end else begin 
        if(valid && !we) begin 
            if(inst_or_data == 1) begin
                // data
                arid <= 4'b1;
            end else begin 
                // int
                arid <= 4'b0;
            end
        end 
    end
end

// araddr 
always @(posedge clk) begin 
    if(!resetn) begin 
        araddr <= 32'b0;
    end else begin 
        if(valid && !we) begin 
            if(data_addr_ok) begin
                // data
                araddr <= data_addr;
            end else if(inst_addr_ok) begin 
                // int
                araddr <= inst_addr;
            end
        end 
    end
end

// arsize 
always @(posedge clk) begin 
    if(!resetn) begin 
        arsize <= 3'b0;
    end else begin 
        if(inst_or_data == 1) begin
            // data
            arsize <= {3'b1} << data_size;
        end else begin 
            // int
            arsize <= {3'b1} << inst_size;
        end
    end
end

// arvalid 
always @(posedge clk) begin 
    if(!resetn) begin 
        arvalid <= 1'b0;
    end else begin 
        if(arready && arvalid) begin 
            arvalid <= 1'b0;
        end else if(valid && !we && (inst_addr_ok || data_addr_ok)) begin 
            arvalid <= 1'b1;
        end
    end
end

// axi read response channel 

// rready 
always @(posedge clk) begin 
    if(!resetn) begin 
        rready <= 1'b0;
    end else begin 
        // if(valid && !we) begin 
        //     rready <= 1'b1;
        // end else if(rvalid && rready) begin 
        //     rready <= 1'b0;
        // end
        if(rvalid && rready) begin 
            rready <= 1'b0;
        end else if(valid && !we) begin 
            rready <= 1'b1;
        end
    end
end 

// axi write request channel

// awaddr
always @(posedge clk) begin 
    if(!resetn) begin 
        awaddr <= 32'b0;
    end else begin 
        if(valid && we) begin 
            if(inst_or_data == 1 && data_addr_ok) begin 
                // data
                awaddr <= data_addr;
                wdata_r <= data_wdata;
            end else if(inst_addr_ok) begin 
                // inst
                awaddr <= inst_addr;
            end
        end
    end
end

// awsize
always @(posedge clk) begin 
    if(!resetn) begin 
        awsize <= 4'b0;
    end else begin 
        if(valid && we) begin 
            if(inst_or_data == 1 && data_addr_ok) begin 
                // data
                awsize <= {3'b1} << data_size;
            end else if(inst_addr_ok) begin 
                // inst
                awsize <= {3'b1} << inst_size;
            end
        end
    end
end

// awvalid 
always @(posedge clk) begin 
    if(!resetn) begin 
        awvalid <= 1'b0;
    end else begin 
        if(valid && we && data_addr_ok) begin 
            awvalid <= 1'b1;
        end else if(awvalid && awready) begin 
            awvalid <= 1'b0;
        end
    end
end

// write data channel 

// wdata
always @(posedge clk) begin 
    if(!resetn) begin 
        wdata <= 32'b0;
    end else begin 
        if(awready && awvalid) begin 
            wdata <= wdata_r;
        end
    end
end

// wstrb 
always @(posedge clk) begin 
    if(!resetn) begin 
        wstrb <= 4'b1111;
    end else begin 
        if(valid && we && data_addr_ok) begin 
            // if(data_size == 2'b00) begin 
            //     wstrb_r <= {4'b0001} << data_addr[1:0];
            // end else if(data_size == 2'b01) begin 
            //     wstrb_r <= {4'b0011} << data_addr[1:0];
            // end else if(data_size == 2'b10) begin 
            //     wstrb_r <= 4'b1111;
            // end
            wstrb_r <= data_wstrb;
        end
        if(awready && awvalid) begin 
            wstrb <= wstrb_r;
        end
    end
end 

// wvalid 
always @(posedge clk) begin 
    if(!resetn) begin 
        wvalid <= 1'b0;
    end else begin 
        if(awready && awvalid) begin 
            wvalid <= 1'b1;
        end else if(wvalid && wready) begin 
            wvalid <= 1'b0;
        end
    end
end

// axi write response channel 
always @(posedge clk) begin 
    if(!resetn) begin 
        bready <= 1'b0;
    end else begin 
        if(bready && bvalid) begin 
            bready <= 1'b0;
        end else if(valid && we) begin 
            bready <= 1'b1;
        end
    end
end


endmodule