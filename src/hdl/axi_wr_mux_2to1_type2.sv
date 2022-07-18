/*
 * AXI4 register
 */
module axi_wr_mux_2to1_type2 # (
    parameter integer C_M_AXI_ID_WIDTH            =   4   , 
    parameter integer C_M_AXI_ADDR_WIDTH          =   64  ,
    parameter integer C_M_AXI_DATA_WIDTH          =   512 
)
(
    input  logic                                    clk                ,

    input  logic                                    sel                ,

    axi_bus_wr_t.slave                              s00_axi            ,
    axi_bus_wr_t.slave                              s01_axi            ,

    axi_bus_wr_t.master                             m_axi                  
);

always_comb begin : genaxi_wr
    m_axi.awvalid       =   sel ?  s01_axi.awvalid : s00_axi.awvalid;
    s00_axi.awready     =   ~sel & m_axi.awready;
    s01_axi.awready     =   sel & m_axi.awready;
    m_axi.awaddr        =   sel ?  s01_axi.awaddr : s00_axi.awaddr;
    m_axi.awburst       =   2'b01;
    m_axi.awlen         =   sel ?  s01_axi.awlen : s00_axi.awlen;
    m_axi.awsize        =   $clog2((C_M_AXI_DATA_WIDTH/8));;
    m_axi.awid          =   {C_M_AXI_ID_WIDTH{1'b0}};

    m_axi.wvalid        = sel ?  s01_axi.wvalid : s00_axi.wvalid;
    s00_axi.wready      = ~sel & m_axi.wready;
    s01_axi.wready      = sel & m_axi.wready;
    m_axi.wdata         = sel ?  s01_axi.wdata : s00_axi.wdata;
    m_axi.wstrb         = sel ?  s01_axi.wstrb : s00_axi.wstrb;
    m_axi.wlast         = sel ?  s01_axi.wlast : s00_axi.wlast;

    s00_axi.bvalid      = ~sel & m_axi.bvalid;
    s01_axi.bvalid      = sel & m_axi.bvalid;
    m_axi.bready        = 1'b1;
end : genaxi_wr

endmodule