/*
 * AXI4 Lite register
 */
module axil_register #
(
    parameter S_AXI_ADDR_WIDTH  =   32          ,
    parameter PIPE_LEVEL        =   3
)
(
    input  logic                            clk         ,

    // axi4 lite slave signals
    input  logic [S_AXI_ADDR_WIDTH-1:0]     s_awaddr    ,
    input  logic                            s_awvalid   ,
    output logic                            s_awready   ,

    input  logic [32-1:0]                   s_wdata     ,
    input  logic [4-1:0]                    s_wstrb     ,
    input  logic                            s_wvalid    ,
    output logic                            s_wready    ,

    output logic [1:0]                      s_bresp     ,
    output logic                            s_bvalid    ,
    input  logic                            s_bready    ,

    input  logic [S_AXI_ADDR_WIDTH-1:0]     s_araddr    ,
    input  logic                            s_arvalid   ,
    output logic                            s_arready   ,

    output logic [32-1:0]                   s_rdata     ,
    output logic [1:0]                      s_rresp     ,
    output logic                            s_rvalid    ,
    input  logic                            s_rready    ,

    // axi4 lite master signals
    output logic [S_AXI_ADDR_WIDTH-1:0]     m_awaddr    ,
    output logic                            m_awvalid   ,
    input  logic                            m_awready   ,

    output logic [32-1:0]                   m_wdata     ,
    output logic [4-1:0]                    m_wstrb     ,
    output logic                            m_wvalid    ,
    input  logic                            m_wready    ,

    input  logic [1:0]                      m_bresp     ,
    input  logic                            m_bvalid    ,
    output logic                            m_bready    ,

    output logic [S_AXI_ADDR_WIDTH-1:0]     m_araddr    ,
    output logic                            m_arvalid   ,
    input  logic                            m_arready   ,

    input  logic [32-1:0]                   m_rdata     ,
    input  logic [1:0]                      m_rresp     ,
    input  logic                            m_rvalid    ,
    output logic                            m_rready    
);

relay_station
  #(
    .DATA_WIDTH     ( S_AXI_ADDR_WIDTH      ),
    .DEPTH          ( 2                     ),
    .ADDR_WIDTH     ( 1                     ),
    .LEVEL          ( PIPE_LEVEL            )
  )
  AW_pipeline
  (
    .clk            ( clk                   ),
    .if_read_ce     ( 1'b1                  ),
    .if_write_ce    ( 1'b1                  ),

    .if_din         ( s_awaddr              ),
    .if_full_n      ( s_awready             ),
    .if_write       ( s_awvalid             ),

    .if_dout        ( m_awaddr              ),
    .if_empty_n     ( m_awvalid             ),
    .if_read        ( m_awready             )
  );

  relay_station
  #(
    .DATA_WIDTH     ( 36                    ),
    .DEPTH          ( 2                     ),
    .ADDR_WIDTH     ( 1                     ),
    .LEVEL          ( PIPE_LEVEL            )
  )
  W_pipeline
  (
    .clk            ( clk                   ),
    .if_read_ce     ( 1'b1                  ),
    .if_write_ce    ( 1'b1                  ),

    .if_din         ( {s_wdata,  s_wstrb}   ),
    .if_full_n      ( s_wready              ),
    .if_write       ( s_wvalid              ),

    .if_dout        ( {m_wdata, m_wstrb}    ),
    .if_empty_n     ( m_wvalid              ),
    .if_read        ( m_wready              )
  );

  relay_station
  #(
    .DATA_WIDTH     ( S_AXI_ADDR_WIDTH      ),
    .DEPTH          ( 2                     ),
    .ADDR_WIDTH     ( 1                     ),
    .LEVEL          ( PIPE_LEVEL            )
  )
  AR_pipeline
  (
    .clk            ( clk                   ),
    .if_read_ce     ( 1'b1                  ),
    .if_write_ce    ( 1'b1                  ),

    .if_din         ( s_araddr              ),
    .if_full_n      ( s_arready             ),
    .if_write       ( s_arvalid             ),

    .if_dout        ( m_araddr              ),
    .if_empty_n     ( m_arvalid             ),
    .if_read        ( m_arready             )
  );

  relay_station
  #(
    .DATA_WIDTH     ( 34                    ),
    .DEPTH          ( 2                     ),
    .ADDR_WIDTH     ( 1                     ),
    .LEVEL          ( PIPE_LEVEL            )
  )
  R_pipeline
  (
    .clk            ( clk                   ),
    .if_read_ce     ( 1'b1                  ),
    .if_write_ce    ( 1'b1                  ),

    .if_din         ( {m_rdata, m_rresp}    ),
    .if_full_n      ( m_rready              ),
    .if_write       ( m_rvalid              ),

    .if_dout        ( {s_rdata, s_rresp}    ),
    .if_empty_n     ( s_rvalid              ),
    .if_read        ( s_rready              )
  );

  relay_station
  #(
    .DATA_WIDTH     ( 2                     ),
    .DEPTH          ( 2                     ),
    .ADDR_WIDTH     ( 1                     ),
    .LEVEL          ( PIPE_LEVEL            )
  )
  B_pipeline
  (
    .clk            (    clk                ),
    .if_read_ce     ( 1'b1                  ),
    .if_write_ce    ( 1'b1                  ),

    .if_din         ( m_bresp               ),
    .if_full_n      ( m_bready              ),
    .if_write       ( m_bvalid              ),

    .if_dout        ( s_bresp               ),
    .if_empty_n     ( s_bvalid              ),
    .if_read        ( s_bready              )
  );

endmodule