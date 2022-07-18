module merge_tree_top 
  import user_def_pkg::C_M_AXI_ID_WIDTH;
  import user_def_pkg::C_M_AXI_ADDR_WIDTH;
  import user_def_pkg::C_M_AXI_DATA_WIDTH;
  import user_def_pkg::C_XFER_SIZE_WIDTH;
  import user_def_pkg::C_RECORD_BIT_WIDTH;
  import user_def_pkg::C_RECORD_KEY_WIDTH;
  import user_def_pkg::C_INIT_SORTED_CHUNK;
  import user_def_pkg::ROOT_BUNDLE_WIDTH;
  import user_def_pkg::C_NUM_LEAVES;
  import user_def_pkg::C_AXI_READ_BURST_BYTES_TYPE1;
#(
  parameter integer SCALA_PIPE                  =   2   ,
  parameter integer CHANNEL_OFFSET              =   0   ,
  parameter integer C_NUM_BRAM_NODES            =   4   
)
(
    // System Signals
    input  logic                                    aclk                 ,

    // Engine signal
    input  logic                                    ap_start             ,
    output logic                                    ap_done              ,

    // User control signal
    input  logic [7:0]                              i_num_pass           ,
    input  logic [C_M_AXI_ADDR_WIDTH-1:0]           i_ptr_0              ,
    input  logic [C_XFER_SIZE_WIDTH-1:0]            i_xfer_size_in_bytes ,

    // AXI4 master interface
    axi_bus_t.master                                m_axi
);


///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

// Local Parameters
localparam integer LP_NUM_READ_CHANNELS       = C_NUM_LEAVES;

localparam integer LP_BURST_SIZE_BYTES        = C_AXI_READ_BURST_BYTES_TYPE1;
localparam integer LP_DW_BYTES                = C_M_AXI_DATA_WIDTH/8;
localparam integer LP_AXI_BURST_LEN           = LP_BURST_SIZE_BYTES/LP_DW_BYTES < 256 ? LP_BURST_SIZE_BYTES/LP_DW_BYTES : 256;
localparam integer LP_LOG_BURST_LEN           = $clog2(LP_AXI_BURST_LEN);
localparam integer LP_RD_MAX_OUTSTANDING      = 2;
localparam integer LP_BRAM_DEPTH              = LP_AXI_BURST_LEN * LP_RD_MAX_OUTSTANDING;

localparam integer LP_WR_MAX_OUTSTANDING      = 32;

// Variables
// Registered input signals
logic                                                         ap_start_pipe           ;
logic [7:0]                                                   num_pass_pipe           ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                                ptr_0_pipe              ;
logic [C_XFER_SIZE_WIDTH-1:0]                                 xfer_size_in_bytes_pipe ;
// Merge tree input streams
logic                                                         init_pass               ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tvalid               ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tready               ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tlast                ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_DATA_WIDTH-1:0]      rd_tdata                ;
// Merge tree output streams
logic                                                         merger_out_tvalid       ;
logic                                                         merger_out_tready       ;
logic [C_M_AXI_DATA_WIDTH-1:0]                                merger_out_tdata        ;
// AXI read control information
logic                                                         single_run_read_done    ; 
logic                                                         read_start              ;
logic [C_XFER_SIZE_WIDTH-1:0]                                 read_size_in_bytes      ; 
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr               ;
logic                                                         read_divide             ;
logic [7:0]                                                   axi_cnt_per_run         ; 
// AXI write control information
logic                                                         write_done              ;
logic                                                         write_start             ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                                write_addr              ;
// Kernel Control
logic                                                         all_done                ;
logic                                                         all_done_pipe           ;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

delay_chain #(
  .WIDTH          ( 1 + 8 + C_M_AXI_ADDR_WIDTH + C_XFER_SIZE_WIDTH ), 
  .STAGES         ( SCALA_PIPE        )
) 
u_input_pipe (
  .clk            ( aclk              ),
  .in_bus         ( {ap_start, i_num_pass, i_ptr_0, i_xfer_size_in_bytes}  ),
  .out_bus        ( {ap_start_pipe, num_pass_pipe, ptr_0_pipe, xfer_size_in_bytes_pipe}  )
);

delay_chain #(
  .WIDTH          ( 1                 ),
  .STAGES         ( SCALA_PIPE        )
)
u_output_pipe (
  .clk            ( aclk              ),
  .in_bus         ( all_done          ),
  .out_bus        ( all_done_pipe     )
);

// The following is for calculating addresses 
addr_cal #(
  .NUM_READ_CHANNELS       ( LP_NUM_READ_CHANNELS       ) , 
  .C_M_AXI_DATA_WIDTH      ( C_M_AXI_DATA_WIDTH         ) ,
  .C_M_AXI_ADDR_WIDTH      ( C_M_AXI_ADDR_WIDTH         ) ,
  .C_XFER_SIZE_WIDTH       ( C_XFER_SIZE_WIDTH          ) ,
  .C_BURST_SIZE_BYTES      ( LP_BURST_SIZE_BYTES        ) ,
  .C_INIT_BUNDLE_WIDTH     ( C_INIT_SORTED_CHUNK        ) ,
  .C_RECORD_BIT_WIDTH      ( C_RECORD_BIT_WIDTH         ) ,
  .C_CHANNEL_OFFSET        ( CHANNEL_OFFSET             ) 
)
u_addr_cal (
  .aclk                    ( aclk                       ) ,

  .ap_start                ( ap_start_pipe              ) ,
  .ap_done                 ( all_done                   ) ,  

  .i_num_pass              ( num_pass_pipe              ) ,
  .i_ptr_ch_0              ( ptr_0_pipe                 ) ,
  .i_xfer_size_in_bytes    ( xfer_size_in_bytes_pipe    ) , 
  .i_single_run_read_done  ( single_run_read_done       ) ,
  .i_write_done            ( write_done                 ) ,
  .o_read_start            ( read_start                 ) ,
  .o_read_addr             ( read_addr                  ) ,
  .o_read_size_in_bytes    ( read_size_in_bytes         ) ,
  .o_read_divide           ( read_divide                ) ,
  .o_read_axi_cnt_per_run  ( axi_cnt_per_run            ) ,
  .o_write_start           ( write_start                ) ,
  .o_write_addr            ( write_addr                 ) ,
  .o_init_pass             ( init_pass                  )          
);

// AXI4 Read Master, output format is an AXI4-Stream master, two stream per thread.
axi_read_master #(
  .C_ID_WIDTH              ( C_M_AXI_ID_WIDTH           ) ,
  .C_M_AXI_ADDR_WIDTH      ( C_M_AXI_ADDR_WIDTH         ) ,
  .C_M_AXI_DATA_WIDTH      ( C_M_AXI_DATA_WIDTH         ) ,
  .C_NUM_NODES             ( LP_NUM_READ_CHANNELS       ) ,
  .C_XFER_SIZE_WIDTH       ( C_XFER_SIZE_WIDTH          ) ,
  .C_RECORD_BIT_WIDTH      ( C_RECORD_BIT_WIDTH         ) ,
  .C_RECORD_KEY_WIDTH      ( C_RECORD_KEY_WIDTH         ) ,
  .C_BURST_SIZE_BYTES      ( LP_BURST_SIZE_BYTES        ) ,
  .C_MAX_OUTSTANDING       ( LP_RD_MAX_OUTSTANDING      ) ,
  .C_NUM_BRAM_NODES        ( C_NUM_BRAM_NODES           ) ,
  .C_INIT_SORTED_CHUNK     ( C_INIT_SORTED_CHUNK        )
)
u_axi_read (
  .aclk                    ( aclk                       ) ,
  
  .i_start                 ( read_start                 ) ,
  .i_pass_start            ( write_done                 ) ,
  .o_done                  ( single_run_read_done       ) ,
  .i_addr_offset           ( read_addr                  ) ,
  .i_xfer_size_in_bytes    ( read_size_in_bytes         ) ,
  .i_read_divide           ( read_divide                ) , 
  .i_axi_cnt_per_run       ( axi_cnt_per_run            ) ,

  .m_axi_arvalid           ( m_axi.arvalid              ) ,
  .m_axi_arready           ( m_axi.arready              ) ,
  .m_axi_araddr            ( m_axi.araddr               ) ,
  .m_axi_arburst           ( m_axi.arburst              ) ,
  .m_axi_arlen             ( m_axi.arlen                ) ,
  .m_axi_arsize            ( m_axi.arsize               ) ,
  .m_axi_arid              ( m_axi.arid                 ) ,

  .m_axi_rvalid            ( m_axi.rvalid               ) ,
  .m_axi_rready            ( m_axi.rready               ) ,
  .m_axi_rdata             ( m_axi.rdata                ) ,
  .m_axi_rlast             ( m_axi.rlast                ) ,
  .m_axi_rid               ( m_axi.rid                  ) ,
  .m_axi_rresp             ( m_axi.rresp                ) ,

  .m_axis_tvalid           ( rd_tvalid                  ) ,
  .m_axis_tready           ( rd_tready                  ) ,
  .m_axis_tlast            ( rd_tlast                   ) ,
  .m_axis_tdata            ( rd_tdata                   ) 
);

// merger kernel
merge_integration #(
  .AXIS_TDATA_WIDTH         ( C_M_AXI_DATA_WIDTH        ) ,
  .RECORD_DATA_WIDTH        ( C_RECORD_BIT_WIDTH        ) ,
  .RECORD_KEY_WIDTH         ( C_RECORD_KEY_WIDTH        ) ,
  .INIT_SORTED_CHUNK        ( C_INIT_SORTED_CHUNK       ) ,
  .ROOT_BUNDLE_WIDTH        ( ROOT_BUNDLE_WIDTH         ) ,
  .NUM_LEAVES               ( LP_NUM_READ_CHANNELS      )
)
u_merge_integration  (
  .i_clk                    ( aclk                      ) ,

  .i_init_pass              ( init_pass                 ) ,

  .s_axis_tvalid            ( rd_tvalid                 ) ,
  .s_axis_tready            ( rd_tready                 ) ,
  .s_axis_tdata             ( rd_tdata                  ) ,
  .s_axis_tlast             ( rd_tlast                  ) , 

  .m_axis_tvalid            ( merger_out_tvalid         ) ,
  .m_axis_tready            ( merger_out_tready         ) ,
  .m_axis_tdata             ( merger_out_tdata          ) ,
  .m_axis_tkeep             (                           ) , // Not used
  .m_axis_tlast             (                           )   // Not used
);


// AXI4 Write Master
axi_write_master #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       ) ,
  .C_INCLUDE_DATA_FIFO      ( 1                           )
)
u_axi_write (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start                 ) ,
  .ctrl_done                ( write_done                  ) ,
  .ctrl_addr_offset         ( write_addr                  ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi_awvalid            ( m_axi.awvalid               ) ,
  .m_axi_awready            ( m_axi.awready               ) ,
  .m_axi_awaddr             ( m_axi.awaddr                ) ,
  .m_axi_awburst            ( m_axi.awburst               ) ,
  .m_axi_awlen              ( m_axi.awlen                 ) ,
  .m_axi_awsize             ( m_axi.awsize                ) , 
  .m_axi_awid               ( m_axi.awid                  ) ,

  .m_axi_wvalid             ( m_axi.wvalid                ) ,
  .m_axi_wready             ( m_axi.wready                ) ,
  .m_axi_wdata              ( m_axi.wdata                 ) ,
  .m_axi_wstrb              ( m_axi.wstrb                 ) ,
  .m_axi_wlast              ( m_axi.wlast                 ) ,

  .m_axi_bvalid             ( m_axi.bvalid                ) ,
  .m_axi_bready             ( m_axi.bready                ) ,
  .m_axi_bresp              ( m_axi.bresp                 ) ,
  .m_axi_bid                ( m_axi.bid                   ) ,

  .s_axis_tvalid            ( merger_out_tvalid           ) ,
  .s_axis_tready            ( merger_out_tready           ) ,
  .s_axis_tdata             ( merger_out_tdata            )
);

assign ap_done = all_done_pipe;

endmodule

