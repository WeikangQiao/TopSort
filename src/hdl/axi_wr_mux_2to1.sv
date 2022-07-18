/*
 * AXI4 register
 */
module axi_wr_mux_2to1 # (
    parameter integer C_M_AXI_ID_WIDTH            =   4   , 
    parameter integer C_M_AXI_ADDR_WIDTH          =   64  ,
    parameter integer C_M_AXI_DATA_WIDTH          =   512 
)
(
    input  logic                                    clk                ,

    input  logic                                    sel                ,

    axi_bus_wr_t.slave                              s00_axi            ,
    axi_bus_wr_t.slave                              s01_axi            ,

    output logic                                    m_axi_awvalid      ,
    input  logic                                    m_axi_awready      ,
    output logic [C_M_AXI_ADDR_WIDTH-1:0]           m_axi_awaddr       ,
    output logic [1:0]                              m_axi_awburst      ,
    output logic [7:0]                              m_axi_awlen        ,
    output logic [2:0]                              m_axi_awsize       ,
    output logic [C_M_AXI_ID_WIDTH-1:0]             m_axi_awid         ,

    output logic                                    m_axi_wvalid       ,
    input  logic                                    m_axi_wready       ,
    output logic [C_M_AXI_DATA_WIDTH-1:0]           m_axi_wdata        ,
    output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m_axi_wstrb        ,
    output logic                                    m_axi_wlast        ,

    input  logic                                    m_axi_bvalid       ,
    output logic                                    m_axi_bready       ,
    input  logic [1:0]                              m_axi_bresp        ,
    input  logic [C_M_AXI_ID_WIDTH-1:0]             m_axi_bid          
);

always_comb begin : genaxi_wr
    m_axi_awvalid       =   sel ?  s01_axi.awvalid : s00_axi.awvalid;
    s00_axi.awready     =   ~sel & m_axi_awready;
    s01_axi.awready     =   sel & m_axi_awready;
    m_axi_awaddr        =   sel ?  s01_axi.awaddr : s00_axi.awaddr;
    m_axi_awburst       =   2'b01;
    m_axi_awlen         =   sel ?  s01_axi.awlen : s00_axi.awlen;
    m_axi_awsize        =   $clog2((C_M_AXI_DATA_WIDTH/8));;
    m_axi_awid          =   {C_M_AXI_ID_WIDTH{1'b0}};

    m_axi_wvalid        = sel ?  s01_axi.wvalid : s00_axi.wvalid;
    s00_axi.wready      = ~sel & m_axi_wready;
    s01_axi.wready      = sel & m_axi_wready;
    m_axi_wdata         = sel ?  s01_axi.wdata : s00_axi.wdata;
    m_axi_wstrb         = sel ?  s01_axi.wstrb : s00_axi.wstrb;
    m_axi_wlast         = sel ?  s01_axi.wlast : s00_axi.wlast;

    s00_axi.bvalid      = ~sel & m_axi_bvalid;
    s01_axi.bvalid      = sel & m_axi_bvalid;
    m_axi_bready        = 1'b1;
end : genaxi_wr

endmodule