/*
 * This is for reuse the merge trees that are in the mid or top SLRs.
 * To-do: specify proper pipeline stages for i_write_done_p1 & o_write_start_p1
 */

`include "macro_def.sv"

module merge_tree_reuse_type2_top 
  import user_def_pkg::C_M_AXI_ID_WIDTH;
  import user_def_pkg::C_M_AXI_ADDR_WIDTH;
  import user_def_pkg::C_M_AXI_DATA_WIDTH;
  import user_def_pkg::C_XFER_SIZE_WIDTH;
  import user_def_pkg::C_RECORD_BIT_WIDTH;
  import user_def_pkg::C_RECORD_KEY_WIDTH;
  import user_def_pkg::C_INIT_SORTED_CHUNK;
  import user_def_pkg::ROOT_BUNDLE_WIDTH;
  import user_def_pkg::C_NUM_LEAVES;
  import user_def_pkg::C_AXI_READ_BURST_BYTES_TYPE2;
#(
  parameter integer SCALA_PIPE                  =   2   ,
  parameter integer CHANNEL_OFFSET              =   0   ,
  parameter integer C_NUM_BRAM_NODES            =   4    
)
(
    // System Signals
    input  logic                                                aclk                    ,
    // Engine signal
    input  logic                                                i_start_p1              ,
    output logic                                                o_done_p1               ,
    input  logic                                                i_start_p2              ,
    input  logic                                                i_write_done_p1         , // used for pass count
    output logic                                                o_write_start_p1        , 
    // User control signal
    input  logic [7:0]                                          i_num_pass              ,
    input  logic [C_M_AXI_ADDR_WIDTH-1:0]                       i_ptr_0                 ,
    input  logic [C_XFER_SIZE_WIDTH-1:0]                        i_xfer_size_in_bytes    ,
    // AXI4 master read interface
    axi_bus_rd_t.master                                         m_axi                   ,
    // Merge tree root 
    input  logic                                                i_root_read             ,
    output logic [ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH:0]       o_root_data             ,
    output logic                                                o_root_data_vld              
);


///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

// Local Parameters
localparam integer LP_NUM_LEAVES              = C_NUM_LEAVES;
localparam integer LP_NUM_READ_CHANNELS       = LP_NUM_LEAVES;

localparam integer LP_CHANNEL_OFFSET          = CHANNEL_OFFSET;

localparam integer LP_BURST_SIZE_BYTES        = C_AXI_READ_BURST_BYTES_TYPE2;
localparam integer LP_DW_BYTES                = C_M_AXI_DATA_WIDTH/8;
localparam integer LP_AXI_BURST_LEN           = LP_BURST_SIZE_BYTES/LP_DW_BYTES < 256 ? LP_BURST_SIZE_BYTES/LP_DW_BYTES : 256;
localparam integer LP_LOG_BURST_LEN           = $clog2(LP_AXI_BURST_LEN);
localparam integer LP_RD_MAX_OUTSTANDING      = 2;
localparam integer LP_BRAM_DEPTH              = LP_AXI_BURST_LEN * LP_RD_MAX_OUTSTANDING;

localparam integer LP_WR_MAX_OUTSTANDING      = 32;

localparam integer LP_BM_LATENCY              = `LOG2(ROOT_BUNDLE_WIDTH) + 1;
localparam integer LP_ML_LATENCY              = (ROOT_BUNDLE_WIDTH <= 1) ? 1 : (2 * LP_BM_LATENCY + 2);

// Variables
// Phase select
logic                                                         phase_sel = 0           ; //0: phase 1, 1: phase 2
// Registered input signals
logic                                                         start_p1_pipe           ;
logic                                                         start_p2_pipe           ;
logic [7:0]                                                   num_pass_pipe           ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                                ptr_ch_0_pipe           ;
logic [C_XFER_SIZE_WIDTH-1:0]                                 xfer_size_in_bytes_pipe ;
// AXI read control signals for phase 1
logic                                                         read_start_p1           ;
logic [C_XFER_SIZE_WIDTH-1:0]                                 read_size_in_bytes_p1   ; 
logic                                                         read_divide_p1          ;
logic [7:0]                                                   axi_cnt_per_run_p1      ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr_p1            ;
logic                                                         init_pass_p1            ;
// AXI read control signals for phase 2
logic                                                         read_start_p2           ;
logic [C_XFER_SIZE_WIDTH-1:0]                                 read_size_in_bytes_p2   ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr_p2            ;
// AXI read control signals after phase selection
logic                                                         single_run_read_done    ; 
logic                                                         read_start              ;
logic                                                         pass_start              ;
logic [C_XFER_SIZE_WIDTH-1:0]                                 read_size_in_bytes      ; 
logic                                                         read_divide             ;
logic [7:0]                                                   axi_cnt_per_run         ; 
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr               ;
logic                                                         init_pass               ;
// AXI stream inputs to merge tree: shared by both phases
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tvalid               ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tready               ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tlast                ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_DATA_WIDTH-1:0]      rd_tdata                ;
// Dispatched data from AXIS to merge trees: shared by both phases
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_read             ;
logic [LP_NUM_READ_CHANNELS-1:0][C_RECORD_BIT_WIDTH:0]        feeder_data             ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_data_vld         ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_read_pipe        ;
logic [LP_NUM_READ_CHANNELS-1:0][C_RECORD_BIT_WIDTH:0]        feeder_data_pipe        ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_data_vld_pipe    ;
// Merge trees' root output: shared by both phase
logic                                                         root_read               ;
logic [ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH:0]                root_data               ;
logic                                                         root_data_vld           ;
logic [ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH:0]                root_fifo_data          ;
logic                                                         root_fifo_data_empty    ;
logic                                                         root_fifo_prog_full     ;
// AXI write control signals for phase 1: two sets
logic                                                         write_done_p1           ;
logic                                                         write_start_p1          ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                                write_addr_p1           ;
// Kernel Control
logic                                                         p1_done                 ;
logic                                                         p1_done_pipe            ;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

delay_chain #(
  .WIDTH          ( 2 + 8 + C_M_AXI_ADDR_WIDTH + C_XFER_SIZE_WIDTH ), 
  .STAGES         ( SCALA_PIPE          )
) 
u_input_pipe (
  .clk            ( aclk                ),
  .in_bus         ( {i_start_p1, i_start_p2, i_num_pass, i_ptr_0, i_xfer_size_in_bytes}  ),
  .out_bus        ( {start_p1_pipe, start_p2_pipe, num_pass_pipe, ptr_ch_0_pipe, xfer_size_in_bytes_pipe}  )
);

delay_chain #(
  .WIDTH          ( 1                   ),
  .STAGES         ( SCALA_PIPE          )
)
u_output_pipe (
  .clk            ( aclk                ),
  .in_bus         ( p1_done             ),
  .out_bus        ( p1_done_pipe        )
);

always_comb begin : conv_in
    write_done_p1   =   i_write_done_p1 ;
    root_read       =   i_root_read     ;
end: conv_in

// Phase selection
always_ff @( posedge aclk ) begin
  phase_sel <=  start_p2_pipe ? 1'b1  : 
                start_p1_pipe ? 1'b0  :
                                phase_sel;
end

always_comb begin : readctrl_sel
  read_start              = phase_sel ? read_start_p2 : read_start_p1;
  pass_start              = phase_sel ? '1 : write_done_p1;
  read_size_in_bytes      = phase_sel ? read_size_in_bytes_p2 : read_size_in_bytes_p1; 
  read_divide             = phase_sel ? '0 : read_divide_p1;
  axi_cnt_per_run         = axi_cnt_per_run_p1;
  read_addr               = phase_sel ? read_addr_p2 : read_addr_p1;
  init_pass               = phase_sel ? '0 : init_pass_p1;
end: readctrl_sel

// Read address calculation for merge tree in phase 1
addr_cal #(
  .NUM_READ_CHANNELS       ( LP_NUM_READ_CHANNELS       ) , 
  .C_M_AXI_DATA_WIDTH      ( C_M_AXI_DATA_WIDTH         ) ,
  .C_M_AXI_ADDR_WIDTH      ( C_M_AXI_ADDR_WIDTH         ) ,
  .C_XFER_SIZE_WIDTH       ( C_XFER_SIZE_WIDTH          ) ,
  .C_BURST_SIZE_BYTES      ( LP_BURST_SIZE_BYTES        ) ,
  .C_INIT_BUNDLE_WIDTH     ( C_INIT_SORTED_CHUNK        ) ,
  .C_RECORD_BIT_WIDTH      ( C_RECORD_BIT_WIDTH         ) ,
  .C_CHANNEL_OFFSET        ( LP_CHANNEL_OFFSET          ) 
)
u_addr_cal (
  .aclk                    ( aclk                       ) ,

  .ap_start                ( start_p1_pipe              ) ,
  .ap_done                 ( p1_done                    ) ,  

  .i_num_pass              ( num_pass_pipe              ) ,
  .i_ptr_ch_0              ( ptr_ch_0_pipe              ) ,
  .i_xfer_size_in_bytes    ( xfer_size_in_bytes_pipe    ) , 
  .i_single_run_read_done  ( single_run_read_done       ) ,
  .i_write_done            ( write_done_p1              ) ,
  .o_read_start            ( read_start_p1              ) ,
  .o_read_addr             ( read_addr_p1               ) ,
  .o_read_size_in_bytes    ( read_size_in_bytes_p1      ) ,
  .o_read_divide           ( read_divide_p1             ) ,
  .o_read_axi_cnt_per_run  ( axi_cnt_per_run_p1         ) ,
  .o_write_start           ( write_start_p1             ) ,
  .o_write_addr            ( write_addr_p1              ) ,
  .o_init_pass             ( init_pass_p1               )          
);

// Read address calculation for merge tree in phase 2
addr_cal_read_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH        ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH         ) ,
  .CHANNEL_OFFSET           ( LP_CHANNEL_OFFSET         )     
)
u_addr_cal_rd_phase2 (
  .aclk                     ( aclk                      ) ,

  .i_start                  ( start_p2_pipe             ) , // phase 2 start

  .i_pass_parity            ( num_pass_pipe[0]          ) , // parity of pass number in phase 1
  .i_ptr_ch_0               ( ptr_ch_0_pipe             ) , // starting address of channel 0
  .i_xfer_size_in_bytes     ( xfer_size_in_bytes_pipe   ) , // total input size in bytes 

  .o_read_start             ( read_start_p2             ) , // read start
  .o_read_addr              ( read_addr_p2              ) , // read address for tree 0
  .o_read_size_in_bytes     ( read_size_in_bytes_p2     )             
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
  .i_pass_start            ( pass_start                 ) ,
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

// merger kernel dispatch
merge_tree_dispatch #(
   .AXIS_TDATA_WIDTH       ( C_M_AXI_DATA_WIDTH         ) , 
   .INIT_SORTED_CHUNK      ( C_INIT_SORTED_CHUNK        ) ,
   .RECORD_DATA_WIDTH      ( C_RECORD_BIT_WIDTH         ) 
)
u_feeder [LP_NUM_LEAVES-1:0] (
   .i_clk                  ( aclk                       ) ,

   .i_init_pass            ( init_pass                  ) ,

   .s_axis_tvalid          ( rd_tvalid                  ) ,
   .s_axis_tready          ( rd_tready                  ) ,
   .s_axis_tdata           ( rd_tdata                   ) ,
   .s_axis_tlast           ( rd_tlast                   ) ,

   .i_read                 ( feeder_read                ) ,  
   .o_data                 ( feeder_data                ) ,
   .o_data_vld             ( feeder_data_vld            ) 
);

fifo_gen_register #
(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH+1      ) ,
    .PIPE_LEVEL             ( 2                         )
)
u_feeder_pipe [LP_NUM_LEAVES-1:0] (
    .clk                    ( aclk                      ) ,

    .s_data_vld             ( feeder_data_vld           ) ,
    .s_data                 ( feeder_data               ) ,
    .s_read                 ( feeder_read               ) ,
    
    .m_data_vld             ( feeder_data_vld_pipe      ) ,
    .m_data                 ( feeder_data_pipe          ) ,
    .m_read                 ( feeder_read_pipe          )
);

merge_tree_reuse_type2 #(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH        ) ,
    .KEY_WIDTH              ( C_RECORD_KEY_WIDTH        ) ,
    .BUNDLE_WIDTH           ( ROOT_BUNDLE_WIDTH         ) ,
    .NUM_LEAVES             ( LP_NUM_READ_CHANNELS      ) 
)
u_merge_tree(
    .i_clk                  ( aclk                      ) ,

    .i_leaf_data            ( feeder_data_pipe          ) ,
    .i_leaf_data_vld        ( feeder_data_vld_pipe      ) ,
    .i_root_read            ( !root_fifo_prog_full      ) ,

    .o_leaf_read            ( feeder_read_pipe          ) ,
    .o_root_data            ( root_data                 ) ,
    .o_root_data_vld        ( root_data_vld             ) 
);

qshift_fifo #(
  .FIFO_WIDTH               ( ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH + 1) ,
  .FIFO_DEPTH               ( 32                        ) ,
  .PROG_FULL_THRESH         ( 32 - LP_ML_LATENCY        ) 
) 
u_pre_fifo(
  .i_clk                    ( aclk                      ) ,
  .i_din                    ( root_data                 ) ,
  .i_wr_en                  ( root_data_vld             ) ,
  .i_rd_en                  ( root_read                 ) ,
  .o_dout                   ( root_fifo_data            ) ,
  .o_full                   ( /*Unused*/                ) , 
  .o_empty                  ( root_fifo_data_empty      ) ,
  .o_prog_full              ( root_fifo_prog_full       )
);

always_comb begin : blockName
    o_write_start_p1  = write_start_p1        ;
    o_root_data       = root_fifo_data        ;
    o_root_data_vld   = !root_fifo_data_empty ;
    o_done_p1         =   p1_done_pipe        ;
end

endmodule

