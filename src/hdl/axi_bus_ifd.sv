interface axi_bus_t #
(
    parameter   integer     M_AXI_ADDR_WIDTH    =   8   ,
    parameter   integer     M_AXI_DATA_WIDTH    =   512 ,
    parameter   integer     M_AXI_ID_WIDTH      =   4   
);

    logic                                    awvalid      ;
    logic                                    awready      ;
    logic [M_AXI_ADDR_WIDTH-1:0]             awaddr       ;
    logic [1:0]                              awburst      ;
    logic [7:0]                              awlen        ;
    logic [2:0]                              awsize       ;
    logic [M_AXI_ID_WIDTH-1:0]               awid         ;

    logic                                    wvalid       ;
    logic                                    wready       ;
    logic [M_AXI_DATA_WIDTH-1:0]             wdata        ;
    logic [M_AXI_DATA_WIDTH/8-1:0]           wstrb        ;
    logic                                    wlast        ;

    logic                                    bvalid       ;
    logic                                    bready       ;
    logic [1:0]                              bresp        ;
    logic [M_AXI_ID_WIDTH-1:0]               bid          ;

    logic                                    arvalid      ;
    logic                                    arready      ;
    logic [M_AXI_ADDR_WIDTH-1:0]             araddr       ;
    logic [1:0]                              arburst      ;
    logic [7:0]                              arlen        ;
    logic [2:0]                              arsize       ;
    logic [M_AXI_ID_WIDTH-1:0]               arid         ;

    logic                                    rvalid       ;
    logic                                    rready       ;
    logic [M_AXI_DATA_WIDTH-1:0]             rdata        ;
    logic                                    rlast        ;
    logic [M_AXI_ID_WIDTH-1:0]               rid          ;
    logic [1:0]                              rresp        ;

    modport     slave ( // AW channel
                        input   awvalid, awaddr, awburst, awlen, awsize, awid,
                        output  awready,
                        // W channel
                        input   wvalid, wdata, wstrb, wlast,
                        output  wready,
                        // B channel
                        input   bready,
                        output  bvalid, bresp, bid,
                        // AR channel
                        input   arvalid, araddr, arburst, arlen, arsize, arid,
                        output  arready,
                        // R
                        input   rready,
                        output  rvalid, rdata, rlast, rid, rresp
                    );

    modport     master ( // AW channel
                        output  awvalid, awaddr, awburst, awlen, awsize, awid,
                        input   awready,
                        // W channel
                        output  wvalid, wdata, wstrb, wlast,
                        input   wready,
                        // B channel
                        output  bready,
                        input   bvalid, bresp, bid,
                        // AR channel
                        output  arvalid, araddr, arburst, arlen, arsize, arid,
                        input   arready,
                        // R
                        output  rready,
                        input   rvalid, rdata, rlast, rid, rresp
                    );

endinterface


interface axi_bus_wr_t #
(
    parameter   integer     M_AXI_ADDR_WIDTH    =   8   ,
    parameter   integer     M_AXI_DATA_WIDTH    =   512 ,
    parameter   integer     M_AXI_ID_WIDTH      =   4   
);

    logic                                    awvalid      ;
    logic                                    awready      ;
    logic [M_AXI_ADDR_WIDTH-1:0]             awaddr       ;
    logic [1:0]                              awburst      ;
    logic [7:0]                              awlen        ;
    logic [2:0]                              awsize       ;
    logic [M_AXI_ID_WIDTH-1:0]               awid         ;

    logic                                    wvalid       ;
    logic                                    wready       ;
    logic [M_AXI_DATA_WIDTH-1:0]             wdata        ;
    logic [M_AXI_DATA_WIDTH/8-1:0]           wstrb        ;
    logic                                    wlast        ;

    logic                                    bvalid       ;
    logic                                    bready       ;
    logic [1:0]                              bresp        ;
    logic [M_AXI_ID_WIDTH-1:0]               bid          ;

    modport     slave ( // AW channel
                        input   awvalid, awaddr, awburst, awlen, awsize, awid,
                        output  awready,
                        // W channel
                        input   wvalid, wdata, wstrb, wlast,
                        output  wready,
                        // B channel
                        input   bready,
                        output  bvalid, bresp, bid
                    );

    modport     master ( // AW channel
                        output  awvalid, awaddr, awburst, awlen, awsize, awid,
                        input   awready,
                        // W channel
                        output  wvalid, wdata, wstrb, wlast,
                        input   wready,
                        // B channel
                        output  bready,
                        input   bvalid, bresp, bid
                    );

endinterface  

interface axi_bus_rd_t #
(
    parameter   integer     M_AXI_ADDR_WIDTH    =   8   ,
    parameter   integer     M_AXI_DATA_WIDTH    =   512 ,
    parameter   integer     M_AXI_ID_WIDTH      =   4   
);

    logic                                    arvalid      ;
    logic                                    arready      ;
    logic [M_AXI_ADDR_WIDTH-1:0]             araddr       ;
    logic [1:0]                              arburst      ;
    logic [7:0]                              arlen        ;
    logic [2:0]                              arsize       ;
    logic [M_AXI_ID_WIDTH-1:0]               arid         ;

    logic                                    rvalid       ;
    logic                                    rready       ;
    logic [M_AXI_DATA_WIDTH-1:0]             rdata        ;
    logic                                    rlast        ;
    logic [M_AXI_ID_WIDTH-1:0]               rid          ;
    logic [1:0]                              rresp        ;

    modport     slave ( 
                        // AR channel
                        input   arvalid, araddr, arburst, arlen, arsize, arid,
                        output  arready,
                        // R
                        input   rready,
                        output  rvalid, rdata, rlast, rid, rresp
                    );

    modport     master (
                        // AR channel
                        output  arvalid, araddr, arburst, arlen, arsize, arid,
                        input   arready,
                        // R
                        output  rready,
                        input   rvalid, rdata, rlast, rid, rresp
                    );

endinterface