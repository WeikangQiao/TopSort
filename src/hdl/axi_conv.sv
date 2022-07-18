/**********************************************************************************
 This module is a bypass wrapper to convert the axi_bus_t.slave signals into each
 separate signal.
**********************************************************************************/

module axi_conv #
(
    parameter   integer     M_AXI_ADDR_WIDTH    =   8   ,
    parameter   integer     M_AXI_DATA_WIDTH    =   512 ,
    parameter   integer     M_AXI_ID_WIDTH      =   4 
)
(

    axi_bus_t.slave                                 s_axi               , 

    output logic                                    m_axi_awvalid       ,
    input  logic                                    m_axi_awready       ,
    output logic [M_AXI_ADDR_WIDTH-1:0]             m_axi_awaddr        ,
    output logic [1:0]                              m_axi_awburst       ,
    output logic [7:0]                              m_axi_awlen         ,
    output logic [2:0]                              m_axi_awsize        ,
    output logic [M_AXI_ID_WIDTH-1:0]               m_axi_awid          ,

    output logic                                    m_axi_wvalid        ,
    input  logic                                    m_axi_wready        ,
    output logic [M_AXI_DATA_WIDTH-1:0]             m_axi_wdata         ,
    output logic [M_AXI_DATA_WIDTH/8-1:0]           m_axi_wstrb         ,
    output logic                                    m_axi_wlast         ,

    input  logic                                    m_axi_bvalid        ,
    output logic                                    m_axi_bready        ,
    input  logic [1:0]                              m_axi_bresp         ,
    input  logic [M_AXI_ID_WIDTH-1:0]               m_axi_bid           ,

    output logic                                    m_axi_arvalid       ,
    input  logic                                    m_axi_arready       ,
    output logic [M_AXI_ADDR_WIDTH-1:0]             m_axi_araddr        ,
    output logic [1:0]                              m_axi_arburst       ,
    output logic [7:0]                              m_axi_arlen         ,
    output logic [2:0]                              m_axi_arsize        ,
    output logic [M_AXI_ID_WIDTH-1:0]               m_axi_arid          ,

    input  logic                                    m_axi_rvalid        ,
    output logic                                    m_axi_rready        ,
    input  logic [M_AXI_DATA_WIDTH-1:0]             m_axi_rdata         ,
    input  logic                                    m_axi_rlast         ,
    input  logic [M_AXI_ID_WIDTH-1:0]               m_axi_rid           ,
    input  logic [1:0]                              m_axi_rresp            
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

always_comb begin
    m_axi_awvalid   =   s_axi.awvalid   ;       
    m_axi_awaddr    =   s_axi.awaddr    ;        
    m_axi_awburst   =   s_axi.awburst   ;       
    m_axi_awlen     =   s_axi.awlen     ;         
    m_axi_awsize    =   s_axi.awsize    ;        
    m_axi_awid      =   s_axi.awid      ;
    s_axi.awready   =   m_axi_awready   ;   

    m_axi_wvalid    =   s_axi.wvalid    ;    
    m_axi_wdata     =   s_axi.wdata     ;     
    m_axi_wstrb     =   s_axi.wstrb     ;         
    m_axi_wlast     =   s_axi.wlast     ;
    s_axi.wready    =   m_axi_wready    ;  

    s_axi.bvalid    =   m_axi_bvalid    ;        
    m_axi_bready    =   s_axi.bready    ;        
    s_axi.bresp     =   m_axi_bresp     ;         
    s_axi.bid       =   m_axi_bid       ;

    m_axi_arvalid   =   s_axi.arvalid   ;            
    m_axi_araddr    =   s_axi.araddr    ;        
    m_axi_arburst   =   s_axi.arburst   ;      
    m_axi_arlen     =   s_axi.arlen     ;        
    m_axi_arsize    =   s_axi.arsize    ;       
    m_axi_arid      =   s_axi.arid      ;
    s_axi.arready   =   m_axi_arready   ; 

    s_axi.rvalid    =   m_axi_rvalid    ;             
    s_axi.rdata     =   m_axi_rdata     ;         
    s_axi.rlast     =   m_axi_rlast     ;         
    s_axi.rid       =   m_axi_rid       ;         
    s_axi.rresp     =   m_axi_rresp     ; 
    m_axi_rready    =   s_axi.rready    ;  
end

endmodule