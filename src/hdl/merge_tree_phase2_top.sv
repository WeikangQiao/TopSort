/**********************************************************************************
 *  The module is the top module of phase 2
 * 
**********************************************************************************/
module merge_tree_phase2_top 
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
  import user_def_pkg::C_GRAIN_IN_BYTES;
#(
  parameter integer SCALA_PIPE                  =   2   ,
  parameter integer C_NUM_BRAM_NODES            =   4  
)
(
    // System Signals
    input  logic                                    aclk                 ,

    // Engine control signal
    input  logic                                    i_start_p1             ,
    output logic [1:0]                              o_done_p1              ,
    input  logic                                    i_start_p2             ,
    input  logic                                    i_done_p2              ,
    output logic [3:0]                              o_done_p2              ,

    // User control signal
    input  logic [7:0]                              i_num_pass             ,
    input  logic [C_M_AXI_ADDR_WIDTH-1:0]           i_ptr_0                ,  // starting address for channel 0
    input  logic [C_XFER_SIZE_WIDTH-1:0]            i_xfer_size_in_bytes   ,  // transfer size for each channel

    // Signals from merge tree 4 & 12
    input  logic                                    i_wr_start_p1_t04      ,
    output logic                                    o_wr_done_p1_t04       ,
    fifo_if_t.slave                                 fifo_it_t04            ,
    input  logic                                    i_wr_start_p1_t12      ,
    output logic                                    o_wr_done_p1_t12       ,
    fifo_if_t.slave                                 fifo_it_t12            ,

    // AXI4 master interface
    axi_bus_t.master                                m00_axi                ,
    axi_bus_wr_t.master                             m04_axi_wr             ,
    axi_bus_t.master                                m08_axi                ,  
    axi_bus_wr_t.master                             m12_axi_wr                       
);


///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

// Local Parameters
localparam integer LP_NUM_LEAVES              = C_NUM_LEAVES;
localparam integer LP_NUM_READ_CHANNELS       = LP_NUM_LEAVES;

localparam integer LP_CHANNEL_OFFSET_0        = 0 ; // 0th channel
localparam integer LP_CHANNEL_OFFSET_1        = 8 ; // 8th channel
localparam integer LP_CHANNEL_OFFSET_2        = 16; // 16th channel
localparam integer LP_CHANNEL_OFFSET_3        = 24; // 16th channel

localparam integer LP_BURST_SIZE_BYTES        = C_AXI_READ_BURST_BYTES_TYPE2;
localparam integer LP_DW_BYTES                = C_M_AXI_DATA_WIDTH/8;
localparam integer LP_AXI_BURST_LEN           = LP_BURST_SIZE_BYTES/LP_DW_BYTES < 256 ? LP_BURST_SIZE_BYTES/LP_DW_BYTES : 256;
localparam integer LP_LOG_BURST_LEN           = $clog2(LP_AXI_BURST_LEN);
localparam integer LP_RD_MAX_OUTSTANDING      = 2;
localparam integer LP_BRAM_DEPTH              = LP_AXI_BURST_LEN * LP_RD_MAX_OUTSTANDING;

localparam integer LP_WR_MAX_OUTSTANDING      = 32;

localparam integer LP_LOG_GRAIN_IN_BYTES      = $clog2(C_GRAIN_IN_BYTES);
localparam integer LP_LOG_AXIS_WR_CNT         = LP_LOG_GRAIN_IN_BYTES - $clog2(C_RECORD_BIT_WIDTH * ROOT_BUNDLE_WIDTH * 4 / 8);

// Variables
// Phase select
logic                                                         phase_sel = 0           ; //0: phase 1, 1: phase 2
// Registered input signals
logic                                                         start_p1_pipe           ;
logic                                                         start_p2_pipe           ;
logic [7:0]                                                   num_pass_pipe           ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                                ptr_ch_0_pipe           ;
logic [C_XFER_SIZE_WIDTH-1:0]                                 xfer_size_in_bytes_pipe ;
// Registered other signals
(* keep = "true" *)logic                                      phase_sel_t00           ;
(* keep = "true" *)logic                                      phase_sel_t04           ;
(* keep = "true" *)logic                                      phase_sel_t08           ;
(* keep = "true" *)logic                                      phase_sel_t12           ;
// AXI read control signals of phase 1: two sets for tree 00 & 08
logic [1:0]                                                   read_start_p1           ;
logic [1:0][C_XFER_SIZE_WIDTH-1:0]                            read_size_in_bytes_p1   ; 
logic [1:0]                                                   read_divide_p1          ;
logic [1:0][7:0]                                              axi_cnt_per_run_p1      ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr_t00_p1        ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr_t08_p1        ;
logic [1:0]                                                   init_pass_p1            ;
// AXI read control signals of phase 2: two sets for tree 00 & 08
logic [1:0]                                                   read_start_p2           ;
logic [1:0][C_XFER_SIZE_WIDTH-1:0]                            read_size_in_bytes_p2   ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr_t00_p2        ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr_t08_p2        ;
// AXI read control signals after phase selection
logic [1:0]                                                   single_run_read_done    ; 
logic [1:0]                                                   read_start              ;
logic [1:0]                                                   pass_start              ;
logic [1:0][C_XFER_SIZE_WIDTH-1:0]                            read_size_in_bytes      ; 
logic [1:0]                                                   read_divide             ;
logic [1:0][7:0]                                              axi_cnt_per_run         ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr_t00           ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      read_addr_t08           ;
logic [1:0]                                                   init_pass               ;
//AXI stream inputs to merge tree 00 & 08: shared by both phases
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tvalid_t00           ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tready_t00           ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_DATA_WIDTH-1:0]      rd_tdata_t00            ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tlast_t00            ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tvalid_t08           ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tready_t08           ;
logic [LP_NUM_READ_CHANNELS-1:0][C_M_AXI_DATA_WIDTH-1:0]      rd_tdata_t08            ;
logic [LP_NUM_READ_CHANNELS-1:0]                              rd_tlast_t08            ;

// Dispatched data from AXIS to merge tree 00 & 08: shared by both phases
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_read_t00         ;
logic [LP_NUM_READ_CHANNELS-1:0][C_RECORD_BIT_WIDTH:0]        feeder_data_t00         ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_data_vld_t00     ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_read_t08         ;
logic [LP_NUM_READ_CHANNELS-1:0][C_RECORD_BIT_WIDTH:0]        feeder_data_t08         ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_data_vld_t08     ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_read_t00_pipe    ;
logic [LP_NUM_READ_CHANNELS-1:0][C_RECORD_BIT_WIDTH:0]        feeder_data_t00_pipe    ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_data_vld_t00_pipe;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_read_t08_pipe    ;
logic [LP_NUM_READ_CHANNELS-1:0][C_RECORD_BIT_WIDTH:0]        feeder_data_t08_pipe    ;
logic [LP_NUM_READ_CHANNELS-1:0]                              feeder_data_vld_t08_pipe;
// Merge tree root output of phase 1
logic                                                         root_read_t00           ;
logic [ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH-1:0]              root_data_t00           ;
logic                                                         root_data_vld_t00       ;
logic                                                         root_read_t04           ;
logic [ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH-1:0]              root_data_t04           ;
logic                                                         root_data_vld_t04       ;
logic                                                         root_read_t08           ;
logic [ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH-1:0]              root_data_t08           ;
logic                                                         root_data_vld_t08       ;
logic                                                         root_read_t12           ;
logic [ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH-1:0]              root_data_t12           ;
logic                                                         root_data_vld_t12       ;
// Merge tree's final root output of phase 2
logic                                                         root_read_p2            ;
logic [32*C_RECORD_BIT_WIDTH-1:0]                             root_data_p2            ;
logic                                                         root_data_vld_p2        ;
// Merge trees' coupler output from phase 1 to the merge tree in phase 2
logic                                                         coupler_read_t00        ;
logic [2*ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH:0]              coupler_data_t00        ; // include last signal
logic                                                         coupler_data_vld_t00    ;
logic                                                         coupler_read_t04        ;
logic [2*ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH:0]              coupler_data_t04        ; // include last signal
logic                                                         coupler_data_vld_t04    ;
logic                                                         coupler_read_t08        ;
logic [2*ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH:0]              coupler_data_t08        ; // include last signal
logic                                                         coupler_data_vld_t08    ;
logic                                                         coupler_read_t12        ;
logic [2*ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH:0]              coupler_data_t12        ; // include last signal
logic                                                         coupler_data_vld_t12    ;
// Merge tree output streams for phase 1: four sets
logic                                                         merger_out_tvalid_t00   ;
logic                                                         merger_out_tready_t00   ;
logic [C_M_AXI_DATA_WIDTH-1:0]                                merger_out_tdata_t00    ;
logic                                                         merger_out_tvalid_t04   ;
logic                                                         merger_out_tready_t04   ;
logic [C_M_AXI_DATA_WIDTH-1:0]                                merger_out_tdata_t04    ;
logic                                                         merger_out_tvalid_t08   ;
logic                                                         merger_out_tready_t08   ;
logic [C_M_AXI_DATA_WIDTH-1:0]                                merger_out_tdata_t08    ;
logic                                                         merger_out_tvalid_t12   ;
logic                                                         merger_out_tready_t12   ;
logic [C_M_AXI_DATA_WIDTH-1:0]                                merger_out_tdata_t12    ;
// Merge tree output streams for phase 2
logic                                                         merger_out_tvalid_p2_t00;
logic                                                         merger_out_tready_p2_t00;
logic                                                         merger_out_tvalid_p2_t04;
logic                                                         merger_out_tready_p2_t04;
logic                                                         merger_out_tvalid_p2_t08;
logic                                                         merger_out_tready_p2_t08;
logic                                                         merger_out_tvalid_p2_t12;
logic                                                         merger_out_tready_p2_t12;
logic                                                         merger_out_tvalid_p2    ;
logic                                                         merger_out_tready_p2    ;
logic [4*C_M_AXI_DATA_WIDTH-1:0]                              merger_out_tdata_p2     ;
// AXI write control signals for phase 1: four sets
logic [3:0]                                                   write_done_p1           ;
logic [3:0]                                                   write_start_p1          ;
logic [3:0][C_M_AXI_ADDR_WIDTH-1:0]                           write_addr_p1           ;
// AXI write control signals for phase 2: four sets
logic [3:0]                                                   write_done_p2           ;
logic [3:0]                                                   write_start_p2          ;
logic [3:0][C_M_AXI_ADDR_WIDTH-1:0]                           write_addr_p2           ;
logic [1:0]                                                   write_sel = '0          ; 
logic [LP_LOG_AXIS_WR_CNT-1:0]                                axis_write_cnt = '0     ;
// Kernel Control
logic [1:0]                                                   p1_done                 ;
logic [1:0]                                                   p1_done_pipe            ;
logic [3:0]                                                   p2_done_i               ;
//logic [3:0]                                                   p2_done_r = '0          ;
//logic                                                         p2_done                 ;
logic                                                         p2_done_pipe            ;

axi_bus_wr_t #
( 
  .M_AXI_ADDR_WIDTH   ( C_M_AXI_ADDR_WIDTH  ),
  .M_AXI_DATA_WIDTH   ( C_M_AXI_DATA_WIDTH  ),
  .M_AXI_ID_WIDTH     ( C_M_AXI_ID_WIDTH    )
) m00_axi_wr_p1();

axi_bus_wr_t #
( 
  .M_AXI_ADDR_WIDTH   ( C_M_AXI_ADDR_WIDTH  ),
  .M_AXI_DATA_WIDTH   ( C_M_AXI_DATA_WIDTH  ),
  .M_AXI_ID_WIDTH     ( C_M_AXI_ID_WIDTH    )
) m04_axi_wr_p1();

axi_bus_wr_t #
( 
  .M_AXI_ADDR_WIDTH   ( C_M_AXI_ADDR_WIDTH  ),
  .M_AXI_DATA_WIDTH   ( C_M_AXI_DATA_WIDTH  ),
  .M_AXI_ID_WIDTH     ( C_M_AXI_ID_WIDTH    )
) m08_axi_wr_p1();

axi_bus_wr_t #
( 
  .M_AXI_ADDR_WIDTH   ( C_M_AXI_ADDR_WIDTH  ),
  .M_AXI_DATA_WIDTH   ( C_M_AXI_DATA_WIDTH  ),
  .M_AXI_ID_WIDTH     ( C_M_AXI_ID_WIDTH    )
) m12_axi_wr_p1();

axi_bus_wr_t #
( 
  .M_AXI_ADDR_WIDTH   ( C_M_AXI_ADDR_WIDTH  ),
  .M_AXI_DATA_WIDTH   ( C_M_AXI_DATA_WIDTH  ),
  .M_AXI_ID_WIDTH     ( C_M_AXI_ID_WIDTH    )
) m00_axi_wr_p2();

axi_bus_wr_t #
( 
  .M_AXI_ADDR_WIDTH   ( C_M_AXI_ADDR_WIDTH  ),
  .M_AXI_DATA_WIDTH   ( C_M_AXI_DATA_WIDTH  ),
  .M_AXI_ID_WIDTH     ( C_M_AXI_ID_WIDTH    )
) m04_axi_wr_p2();

axi_bus_wr_t #
( 
  .M_AXI_ADDR_WIDTH   ( C_M_AXI_ADDR_WIDTH  ),
  .M_AXI_DATA_WIDTH   ( C_M_AXI_DATA_WIDTH  ),
  .M_AXI_ID_WIDTH     ( C_M_AXI_ID_WIDTH    )
) m08_axi_wr_p2();

axi_bus_wr_t #
( 
  .M_AXI_ADDR_WIDTH   ( C_M_AXI_ADDR_WIDTH  ),
  .M_AXI_DATA_WIDTH   ( C_M_AXI_DATA_WIDTH  ),
  .M_AXI_ID_WIDTH     ( C_M_AXI_ID_WIDTH    )
) m12_axi_wr_p2();

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

delay_chain #(
  .WIDTH                   ( 2 + 8 + C_M_AXI_ADDR_WIDTH + C_XFER_SIZE_WIDTH ), 
  .STAGES                  ( SCALA_PIPE                 )
) 
u_input_pipe (
  .clk                     ( aclk                       ),
  .in_bus                  ( {i_start_p1, i_start_p2, i_num_pass, i_ptr_0, i_xfer_size_in_bytes}  ),
  .out_bus                 ( {start_p1_pipe, start_p2_pipe, num_pass_pipe, ptr_ch_0_pipe, xfer_size_in_bytes_pipe}  )
);

delay_chain #(
  .WIDTH                   ( 2                          ) ,
  .STAGES                  ( SCALA_PIPE                 ) 
)
u_output_pipe (
  .clk                     ( aclk                       ) ,
  .in_bus                  ( {p1_done}         ) ,
  .out_bus                 ( {p1_done_pipe}              ) 
);

/*
delay_chain #(
  .WIDTH                   ( 3                          ) ,
  .STAGES                  ( SCALA_PIPE                 ) 
)
u_output_pipe (
  .clk                     ( aclk                       ) ,
  .in_bus                  ( {p1_done, p2_done}         ) ,
  .out_bus                 ( {p1_done_pipe, p2_done_pipe}              ) 
);

// Done logic

always_ff @( posedge aclk ) begin
    p2_done_r <= (start_p2_pipe | p2_done) ? '0 : (p2_done_r | p2_done_i);
end

assign p2_done = &p2_done_r;


// Phase selection
always_ff @( posedge aclk ) begin
  phase_sel <=  start_p2_pipe ? 1'b1  : 
                o_done_p2     ? 1'b0  :
                                phase_sel;
end
*/

always_ff @( posedge aclk ) begin
  phase_sel <=  start_p2_pipe ? 1'b1  : 
                i_done_p2     ? 1'b0  :
                                phase_sel;
end

always_comb begin : readctrl_sel
  read_start              = phase_sel ? read_start_p2 : read_start_p1;
  pass_start[0]           = phase_sel ? '1 : write_done_p1[0];
  pass_start[1]           = phase_sel ? '1 : write_done_p1[2];
  read_size_in_bytes      = phase_sel ? read_size_in_bytes_p2 : read_size_in_bytes_p1; 
  read_divide             = phase_sel ? '0 : read_divide_p1;
  axi_cnt_per_run         = axi_cnt_per_run_p1;
  read_addr_t00           = phase_sel ? read_addr_t00_p2 : read_addr_t00_p1;
  read_addr_t08           = phase_sel ? read_addr_t08_p2 : read_addr_t08_p1;
  init_pass               = phase_sel ? '0 : init_pass_p1;
end: readctrl_sel

delay_chain #(
  .WIDTH                   ( 1                          ), 
  .STAGES                  ( 1                          )
) 
u_phase_sel_t00 (
  .clk                     ( aclk                       ),
  .in_bus                  ( phase_sel                  ),
  .out_bus                 ( phase_sel_t00              )
);

delay_chain #(
  .WIDTH                   ( 1                          ), 
  .STAGES                  ( 1                          )
) 
u_phase_sel_t04 (
  .clk                     ( aclk                       ),
  .in_bus                  ( phase_sel                  ),
  .out_bus                 ( phase_sel_t04              )
);

delay_chain #(
  .WIDTH                   ( 1                          ), 
  .STAGES                  ( 1                          )
) 
u_phase_sel_t08 (
  .clk                     ( aclk                       ),
  .in_bus                  ( phase_sel                  ),
  .out_bus                 ( phase_sel_t08              )
);

delay_chain #(
  .WIDTH                   ( 1                          ), 
  .STAGES                  ( 1                          )
) 
u_phase_sel_t12 (
  .clk                     ( aclk                       ),
  .in_bus                  ( phase_sel                  ),
  .out_bus                 ( phase_sel_t12              )
);

// Read address calculation for merge tree 00 in phase 1
addr_cal #(
  .NUM_READ_CHANNELS       ( LP_NUM_READ_CHANNELS       ) , 
  .C_M_AXI_DATA_WIDTH      ( C_M_AXI_DATA_WIDTH         ) ,
  .C_M_AXI_ADDR_WIDTH      ( C_M_AXI_ADDR_WIDTH         ) ,
  .C_XFER_SIZE_WIDTH       ( C_XFER_SIZE_WIDTH          ) ,
  .C_BURST_SIZE_BYTES      ( LP_BURST_SIZE_BYTES        ) ,
  .C_INIT_BUNDLE_WIDTH     ( C_INIT_SORTED_CHUNK        ) ,
  .C_RECORD_BIT_WIDTH      ( C_RECORD_BIT_WIDTH         ) ,
  .C_CHANNEL_OFFSET        ( LP_CHANNEL_OFFSET_0        )
)
u_addr_cal_p1_t00 (
  .aclk                    ( aclk                       ) ,

  .ap_start                ( start_p1_pipe              ) ,
  .ap_done                 ( p1_done[0]                 ) ,  

  .i_num_pass              ( num_pass_pipe              ) ,
  .i_ptr_ch_0              ( ptr_ch_0_pipe              ) ,
  .i_xfer_size_in_bytes    ( xfer_size_in_bytes_pipe    ) , 
  .i_single_run_read_done  ( single_run_read_done[0]    ) ,
  .i_write_done            ( write_done_p1[0]           ) ,
  .o_read_start            ( read_start_p1[0]           ) ,
  .o_read_addr             ( read_addr_t00_p1           ) ,
  .o_read_size_in_bytes    ( read_size_in_bytes_p1[0]   ) ,
  .o_read_divide           ( read_divide_p1[0]          ) ,
  .o_read_axi_cnt_per_run  ( axi_cnt_per_run_p1[0]      ) ,
  .o_write_start           ( write_start_p1[0]          ) ,
  .o_write_addr            ( write_addr_p1[0]           ) ,
  .o_init_pass             ( init_pass_p1[0]            )          
);

addr_cal_wr_phase1 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH        ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH         ) ,
  .C_CHANNEL_OFFSET         ( LP_CHANNEL_OFFSET_1       )    
)
u_addr_cal_wr_p1_t04(
  .aclk                     ( aclk                      ) ,

  .i_phase_1_start          ( start_p1_pipe             ) ,

  .i_ptr_ch_0               ( ptr_ch_0_pipe             ) , // starting address of channel 0
  .i_write_start            ( i_wr_start_p1_t04         ) , // phase 1 write start signal input from corresponding merge tree in different SLR
  .i_write_done             ( write_done_p1[1]          ) , // write done for the current channel

  .o_write_start            ( write_start_p1[1]         ) , 
  .o_write_addr             ( write_addr_p1[1]          )           
);

addr_cal #(
  .NUM_READ_CHANNELS       ( LP_NUM_READ_CHANNELS       ) , 
  .C_M_AXI_DATA_WIDTH      ( C_M_AXI_DATA_WIDTH         ) ,
  .C_M_AXI_ADDR_WIDTH      ( C_M_AXI_ADDR_WIDTH         ) ,
  .C_XFER_SIZE_WIDTH       ( C_XFER_SIZE_WIDTH          ) ,
  .C_BURST_SIZE_BYTES      ( LP_BURST_SIZE_BYTES        ) ,
  .C_INIT_BUNDLE_WIDTH     ( C_INIT_SORTED_CHUNK        ) ,
  .C_RECORD_BIT_WIDTH      ( C_RECORD_BIT_WIDTH         ) ,
  .C_CHANNEL_OFFSET        ( LP_CHANNEL_OFFSET_2        )
)
u_addr_cal_p1_t08 (
  .aclk                    ( aclk                       ) ,

  .ap_start                ( start_p1_pipe              ) ,
  .ap_done                 ( p1_done[1]                 ) ,  

  .i_num_pass              ( num_pass_pipe              ) ,
  .i_ptr_ch_0              ( ptr_ch_0_pipe              ) ,
  .i_xfer_size_in_bytes    ( xfer_size_in_bytes_pipe    ) , 
  .i_single_run_read_done  ( single_run_read_done[1]    ) ,
  .i_write_done            ( write_done_p1[2]           ) ,
  .o_read_start            ( read_start_p1[1]           ) ,
  .o_read_addr             ( read_addr_t08_p1           ) ,
  .o_read_size_in_bytes    ( read_size_in_bytes_p1[1]   ) ,
  .o_read_divide           ( read_divide_p1[1]          ) ,
  .o_read_axi_cnt_per_run  ( axi_cnt_per_run_p1[1]      ) ,
  .o_write_start           ( write_start_p1[2]          ) ,
  .o_write_addr            ( write_addr_p1[2]           ) ,
  .o_init_pass             ( init_pass_p1[1]            )          
);

addr_cal_wr_phase1 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH        ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH         ) ,
  .C_CHANNEL_OFFSET         ( LP_CHANNEL_OFFSET_3       )    
)
u_addr_cal_wr_p1_t12(
  .aclk                     ( aclk                      ) ,

  .i_phase_1_start          ( start_p1_pipe             ) ,

  .i_ptr_ch_0               ( ptr_ch_0_pipe             ) , // starting address of channel 0
  .i_write_start            ( i_wr_start_p1_t12         ) , // phase 1 write start signal input from corresponding merge tree in different SLR
  .i_write_done             ( write_done_p1[3]          ) , // write done for the current channel

  .o_write_start            ( write_start_p1[3]         ) , 
  .o_write_addr             ( write_addr_p1[3]          )           
);

// Address calculation for the merge trees in phase 2
addr_cal_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH        ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH         ) ,  
  .CHANNEL_OFFSET           ( LP_CHANNEL_OFFSET_0       )         
)
u_addr_cal_p2_t00 (
  .aclk                     ( aclk                      ) ,

  .i_start                  ( start_p2_pipe             ) , // phase 2 start

  .i_pass_parity            ( num_pass_pipe[0]          ) , // parity of pass number in phase 1
  .i_ptr_ch_0               ( ptr_ch_0_pipe             ) , // starting address of channel 0
  .i_xfer_size_in_bytes     ( xfer_size_in_bytes_pipe   ) , // total input size in bytes 
  .i_write_done             ( write_done_p2[0]          ) , // write done for the current channel

  .o_read_start             ( read_start_p2[0]          ) , // read start
  .o_read_addr              ( read_addr_t00_p2          ) , // read address for tree 0
  .o_read_size_in_bytes     ( read_size_in_bytes_p2[0]  ) , // how many bytes needs to be read per node for the current run
  .o_write_start            ( write_start_p2[0]         ) , // 
  .o_write_addr             ( write_addr_p2[0]          ) ,
  .o_phase_2_done           ( p2_done_i[0]              )           
);

addr_cal_write_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH        ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH         ) ,  
  .CHANNEL_OFFSET           ( LP_CHANNEL_OFFSET_1       )         
)
u_addr_cal_p2_t04 (
  .aclk                     ( aclk                      ) ,

  .i_start                  ( start_p2_pipe             ) , // phase 2 start

  .i_pass_parity            ( num_pass_pipe[0]          ) , // parity of pass number in phase 1
  .i_ptr_ch_0               ( ptr_ch_0_pipe             ) , // starting address of channel 0
  .i_xfer_size_in_bytes     ( xfer_size_in_bytes_pipe   ) , // total input size in bytes 
  .i_write_done             ( write_done_p2[1]          ) , // write done for the current channel

  .o_write_start            ( write_start_p2[1]         ) , // 
  .o_write_addr             ( write_addr_p2[1]          ) ,
  .o_phase_2_done           ( p2_done_i[1]              )           
);

addr_cal_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH        ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH         ) ,  
  .CHANNEL_OFFSET           ( LP_CHANNEL_OFFSET_2       )         
)
u_addr_cal_p2_t08 (
  .aclk                     ( aclk                      ) ,

  .i_start                  ( start_p2_pipe             ) , // phase 2 start

  .i_pass_parity            ( num_pass_pipe[0]          ) , // parity of pass number in phase 1
  .i_ptr_ch_0               ( ptr_ch_0_pipe             ) , // starting address of channel 0
  .i_xfer_size_in_bytes     ( xfer_size_in_bytes_pipe   ) , // total input size in bytes 
  .i_write_done             ( write_done_p2[2]          ) , // write done for the current channel

  .o_read_start             ( read_start_p2[1]          ) , // read start
  .o_read_addr              ( read_addr_t08_p2          ) , // read address for tree 0
  .o_read_size_in_bytes     ( read_size_in_bytes_p2[1]  ) , // how many bytes needs to be read per node for the current run
  .o_write_start            ( write_start_p2[2]         ) , // 
  .o_write_addr             ( write_addr_p2[2]          ) ,
  .o_phase_2_done           ( p2_done_i[2]              )           
);

addr_cal_write_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH        ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH         ) ,  
  .CHANNEL_OFFSET           ( LP_CHANNEL_OFFSET_3       )         
)
u_addr_cal_p2_t12 (
  .aclk                     ( aclk                      ) ,

  .i_start                  ( start_p2_pipe             ) , // phase 2 start

  .i_pass_parity            ( num_pass_pipe[0]          ) , // parity of pass number in phase 1
  .i_ptr_ch_0               ( ptr_ch_0_pipe             ) , // starting address of channel 0
  .i_xfer_size_in_bytes     ( xfer_size_in_bytes_pipe   ) , // total input size in bytes 
  .i_write_done             ( write_done_p2[3]          ) , // write done for the current channel

  .o_write_start            ( write_start_p2[3]         ) , // 
  .o_write_addr             ( write_addr_p2[3]          ) ,
  .o_phase_2_done           ( p2_done_i[3]              )           
);

// AXI4 Read Master, shared by both phases.
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
u_axi_read_t00 (
  .aclk                    ( aclk                       ) ,
  
  .i_start                 ( read_start[0]              ) ,
  .i_pass_start            ( pass_start[0]              ) ,
  .o_done                  ( single_run_read_done[0]    ) ,
  .i_addr_offset           ( read_addr_t00              ) ,
  .i_xfer_size_in_bytes    ( read_size_in_bytes[0]      ) ,
  .i_read_divide           ( read_divide[0]             ) , 
  .i_axi_cnt_per_run       ( axi_cnt_per_run[0]         ) ,

  .m_axi_arvalid           ( m00_axi.arvalid            ) ,
  .m_axi_arready           ( m00_axi.arready            ) ,
  .m_axi_araddr            ( m00_axi.araddr             ) ,
  .m_axi_arburst           ( m00_axi.arburst            ) ,
  .m_axi_arlen             ( m00_axi.arlen              ) ,
  .m_axi_arsize            ( m00_axi.arsize             ) ,
  .m_axi_arid              ( m00_axi.arid               ) ,

  .m_axi_rvalid            ( m00_axi.rvalid             ) ,
  .m_axi_rready            ( m00_axi.rready             ) ,
  .m_axi_rdata             ( m00_axi.rdata              ) ,
  .m_axi_rlast             ( m00_axi.rlast              ) ,
  .m_axi_rid               ( m00_axi.rid                ) ,
  .m_axi_rresp             ( m00_axi.rresp              ) ,

  .m_axis_tvalid           ( rd_tvalid_t00              ) ,
  .m_axis_tready           ( rd_tready_t00              ) ,
  .m_axis_tlast            ( rd_tlast_t00               ) ,
  .m_axis_tdata            ( rd_tdata_t00               ) 
);

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
u_axi_read_t08 (
  .aclk                    ( aclk                       ) ,
  
  .i_start                 ( read_start[1]              ) ,
  .i_pass_start            ( pass_start[1]              ) ,
  .o_done                  ( single_run_read_done[1]    ) ,
  .i_addr_offset           ( read_addr_t08              ) ,
  .i_xfer_size_in_bytes    ( read_size_in_bytes[1]      ) ,
  .i_read_divide           ( read_divide[1]             ) , 
  .i_axi_cnt_per_run       ( axi_cnt_per_run[1]         ) ,

  .m_axi_arvalid           ( m08_axi.arvalid            ) ,
  .m_axi_arready           ( m08_axi.arready            ) ,
  .m_axi_araddr            ( m08_axi.araddr             ) ,
  .m_axi_arburst           ( m08_axi.arburst            ) ,
  .m_axi_arlen             ( m08_axi.arlen              ) ,
  .m_axi_arsize            ( m08_axi.arsize             ) ,
  .m_axi_arid              ( m08_axi.arid               ) ,

  .m_axi_rvalid            ( m08_axi.rvalid             ) ,
  .m_axi_rready            ( m08_axi.rready             ) ,
  .m_axi_rdata             ( m08_axi.rdata              ) ,
  .m_axi_rlast             ( m08_axi.rlast              ) ,
  .m_axi_rid               ( m08_axi.rid                ) ,
  .m_axi_rresp             ( m08_axi.rresp              ) ,

  .m_axis_tvalid           ( rd_tvalid_t08              ) ,
  .m_axis_tready           ( rd_tready_t08              ) ,
  .m_axis_tlast            ( rd_tlast_t08               ) ,
  .m_axis_tdata            ( rd_tdata_t08               ) 
);

// merger kernel : split into 3 parts
merge_tree_dispatch #(
   .AXIS_TDATA_WIDTH       ( C_M_AXI_DATA_WIDTH         ) , 
   .INIT_SORTED_CHUNK      ( C_INIT_SORTED_CHUNK        ) ,
   .RECORD_DATA_WIDTH      ( C_RECORD_BIT_WIDTH         ) 
)
u_feeder_t00 [LP_NUM_LEAVES-1:0] (
   .i_clk                  ( aclk                       ) ,

   .i_init_pass            ( init_pass[0]               ) ,

   .s_axis_tvalid          ( rd_tvalid_t00              ) ,
   .s_axis_tready          ( rd_tready_t00              ) ,
   .s_axis_tdata           ( rd_tdata_t00               ) ,
   .s_axis_tlast           ( rd_tlast_t00               ) ,

   .i_read                 ( feeder_read_t00            ) ,  
   .o_data                 ( feeder_data_t00            ) ,
   .o_data_vld             ( feeder_data_vld_t00        ) 
);

merge_tree_dispatch #(
   .AXIS_TDATA_WIDTH       ( C_M_AXI_DATA_WIDTH         ) , 
   .INIT_SORTED_CHUNK      ( C_INIT_SORTED_CHUNK        ) ,
   .RECORD_DATA_WIDTH      ( C_RECORD_BIT_WIDTH         ) 
)
u_feeder_t08 [LP_NUM_LEAVES-1:0] (
   .i_clk                  ( aclk                       ) ,

   .i_init_pass            ( init_pass[1]               ) ,

   .s_axis_tvalid          ( rd_tvalid_t08              ) ,
   .s_axis_tready          ( rd_tready_t08              ) ,
   .s_axis_tdata           ( rd_tdata_t08               ) ,
   .s_axis_tlast           ( rd_tlast_t08               ) ,

   .i_read                 ( feeder_read_t08            ) ,  
   .o_data                 ( feeder_data_t08            ) ,
   .o_data_vld             ( feeder_data_vld_t08        ) 
);

fifo_gen_register #
(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH+1      ) ,
    .PIPE_LEVEL             ( 2                         )
)
u_feeder_pipe_t00 [LP_NUM_LEAVES-1:0] (
    .clk                    ( aclk                      ) ,

    .s_data_vld             ( feeder_data_vld_t00       ) ,
    .s_data                 ( feeder_data_t00           ) ,
    .s_read                 ( feeder_read_t00           ) ,
    
    .m_data_vld             ( feeder_data_vld_t00_pipe  ) ,
    .m_data                 ( feeder_data_t00_pipe      ) ,
    .m_read                 ( feeder_read_t00_pipe      )
);

fifo_gen_register #
(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH+1      ) ,
    .PIPE_LEVEL             ( 2                         )
)
u_feeder_pipe_t08 [LP_NUM_LEAVES-1:0] (
    .clk                    ( aclk                      ) ,

    .s_data_vld             ( feeder_data_vld_t08       ) ,
    .s_data                 ( feeder_data_t08           ) ,
    .s_read                 ( feeder_read_t08           ) ,
    
    .m_data_vld             ( feeder_data_vld_t08_pipe  ) ,
    .m_data                 ( feeder_data_t08_pipe      ) ,
    .m_read                 ( feeder_read_t08_pipe      )
);

merge_tree_reuse #(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH        ) ,
    .KEY_WIDTH              ( C_RECORD_KEY_WIDTH        ) ,
    .BUNDLE_WIDTH           ( ROOT_BUNDLE_WIDTH         ) ,
    .NUM_LEAVES             ( LP_NUM_READ_CHANNELS      ) 
)
u_merge_tree_t00 (
    .i_clk                  ( aclk                      ) ,

    .i_phase_sel            ( phase_sel_t00             ) ,
    .i_leaf_data            ( feeder_data_t00_pipe      ) ,
    .i_leaf_data_vld        ( feeder_data_vld_t00_pipe  ) ,
    .i_root_read            ( root_read_t00             ) ,
    .i_coupler_read         ( coupler_read_t00          ) ,

    .o_leaf_read            ( feeder_read_t00_pipe      ) ,
    .o_root_data            ( root_data_t00             ) ,
    .o_root_data_vld        ( root_data_vld_t00         ) ,
    .o_coupler_data         ( coupler_data_t00          ) ,
    .o_coupler_data_vld     ( coupler_data_vld_t00      ) 
);

merge_logic_demux #(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH        ) ,
    .KEY_WIDTH              ( C_RECORD_KEY_WIDTH        ) ,
    .BUNDLE_WIDTH           ( ROOT_BUNDLE_WIDTH         ) 
)
u_ml_demux_t04(
    .i_clk                  ( aclk                      ) ,

    .i_phase_sel            ( phase_sel_t04             ) ,   // 0: phase 1; 1: phase 2
    .i_ml_data              ( fifo_it_t04.data          ) ,   // root ml data
    .i_ml_data_vld          ( fifo_it_t04.data_vld      ) ,   // root ml data valid
    .i_root_read            ( root_read_t04             ) ,   // enable signal for reading the root fifo, this is for phase 1
    .i_coupler_read         ( coupler_read_t04          ) ,   // enable signal for reading the root coupler, this is for phase 2

    .o_ml_read              ( fifo_it_t04.read          ) ,   // fifo prog full signal
    .o_root_data            ( root_data_t04             ) ,   // root output data
    .o_root_data_vld        ( root_data_vld_t04         ) ,   // root output data valid
    .o_coupler_data         ( coupler_data_t04          ) ,   // root coupler output data
    .o_coupler_data_vld     ( coupler_data_vld_t04      )     // root coupler output data valid
);

merge_tree_reuse #(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH        ) ,
    .KEY_WIDTH              ( C_RECORD_KEY_WIDTH        ) ,
    .BUNDLE_WIDTH           ( ROOT_BUNDLE_WIDTH         ) ,
    .NUM_LEAVES             ( LP_NUM_READ_CHANNELS      ) 
)
u_merge_tree_t08 (
    .i_clk                  ( aclk                      ) ,

    .i_phase_sel            ( phase_sel_t08             ) ,
    .i_leaf_data            ( feeder_data_t08_pipe      ) ,
    .i_leaf_data_vld        ( feeder_data_vld_t08_pipe  ) ,
    .i_root_read            ( root_read_t08             ) ,
    .i_coupler_read         ( coupler_read_t08          ) ,

    .o_leaf_read            ( feeder_read_t08_pipe      ) ,
    .o_root_data            ( root_data_t08             ) ,
    .o_root_data_vld        ( root_data_vld_t08         ) ,
    .o_coupler_data         ( coupler_data_t08          ) ,
    .o_coupler_data_vld     ( coupler_data_vld_t08      ) 
);

merge_logic_demux #(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH        ) ,
    .KEY_WIDTH              ( C_RECORD_KEY_WIDTH        ) ,
    .BUNDLE_WIDTH           ( ROOT_BUNDLE_WIDTH         ) 
)
u_ml_demux_t12(
    .i_clk                  ( aclk                      ) ,

    .i_phase_sel            ( phase_sel_t12             ) ,   // 0: phase 1; 1: phase 2
    .i_ml_data              ( fifo_it_t12.data          ) ,   // root ml data
    .i_ml_data_vld          ( fifo_it_t12.data_vld      ) ,   // root ml data valid
    .i_root_read            ( root_read_t12             ) ,   // enable signal for reading the root fifo, this is for phase 1
    .i_coupler_read         ( coupler_read_t12          ) ,   // enable signal for reading the root coupler, this is for phase 2

    .o_ml_read              ( fifo_it_t12.read          ) ,   // fifo prog full signal
    .o_root_data            ( root_data_t12             ) ,   // root output data
    .o_root_data_vld        ( root_data_vld_t12         ) ,   // root output data valid
    .o_coupler_data         ( coupler_data_t12          ) ,   // root coupler output data
    .o_coupler_data_vld     ( coupler_data_vld_t12      )     // root coupler output data valid
);

// Merge tree for phase 2 only
merge_tree_phase2 #(
    .DATA_WIDTH             ( C_RECORD_BIT_WIDTH        ) ,
    .KEY_WIDTH              ( C_RECORD_KEY_WIDTH        ) ,
    .BUNDLE_WIDTH           ( 16                        ) 
)
u_merge_tree_phase2(
    .i_clk                  ( aclk                      ) ,

    .i_leaf_0_data          ( coupler_data_t00          ) ,   
    .i_leaf_0_data_vld      ( coupler_data_vld_t00      ) ,   
    .i_leaf_1_data          ( coupler_data_t04          ) ,   
    .i_leaf_1_data_vld      ( coupler_data_vld_t04      ) ,   
    .i_leaf_2_data          ( coupler_data_t08          ) ,   
    .i_leaf_2_data_vld      ( coupler_data_vld_t08      ) ,   
    .i_leaf_3_data          ( coupler_data_t12          ) ,   
    .i_leaf_3_data_vld      ( coupler_data_vld_t12      ) ,   
    .i_root_read            ( root_read_p2              ) ,   // enable signal for reading the root fifo

    .o_leaf_0_read          ( coupler_read_t00          ) ,   
    .o_leaf_1_read          ( coupler_read_t04          ) ,   
    .o_leaf_2_read          ( coupler_read_t08          ) ,   
    .o_leaf_3_read          ( coupler_read_t12          ) ,
    .o_root_data            ( root_data_p2              ) ,   // root output data
    .o_root_data_vld        ( root_data_vld_p2          )     // root output data valid
);

// Merge tree assember
// phase 1
merge_tree_assembler #(
   .AXIS_TDATA_WIDTH        ( C_M_AXI_DATA_WIDTH                      ), 
   .RECORD_DATA_WIDTH       ( C_RECORD_BIT_WIDTH * ROOT_BUNDLE_WIDTH  )
)
u_assembler_p1_t00(
   .i_clk                   ( aclk                      ) ,

   .m_axis_tvalid           ( merger_out_tvalid_t00     ) ,
   .m_axis_tready           ( merger_out_tready_t00     ) ,
   .m_axis_tdata            ( merger_out_tdata_t00      ) ,
   .m_axis_tkeep            ( /* Unused */              ) ,
   .m_axis_tlast            ( /* Unused */              ) ,

    
   .i_data                  ( root_data_t00             ) ,
   .i_data_vld              ( root_data_vld_t00         ) ,
   .o_read                  ( root_read_t00             )   
);

merge_tree_assembler #(
   .AXIS_TDATA_WIDTH        ( C_M_AXI_DATA_WIDTH                      ), 
   .RECORD_DATA_WIDTH       ( C_RECORD_BIT_WIDTH * ROOT_BUNDLE_WIDTH  )
)
u_assembler_p1_t04(
   .i_clk                   ( aclk                      ) ,

   .m_axis_tvalid           ( merger_out_tvalid_t04     ) ,
   .m_axis_tready           ( merger_out_tready_t04     ) ,
   .m_axis_tdata            ( merger_out_tdata_t04      ) ,
   .m_axis_tkeep            ( /* Unused */              ) ,
   .m_axis_tlast            ( /* Unused */              ) ,

    
   .i_data                  ( root_data_t04             ) ,
   .i_data_vld              ( root_data_vld_t04         ) ,
   .o_read                  ( root_read_t04             )   
);

merge_tree_assembler #(
   .AXIS_TDATA_WIDTH        ( C_M_AXI_DATA_WIDTH                      ), 
   .RECORD_DATA_WIDTH       ( C_RECORD_BIT_WIDTH * ROOT_BUNDLE_WIDTH  )
)
u_assembler_p1_t08(
   .i_clk                   ( aclk                      ) ,

   .m_axis_tvalid           ( merger_out_tvalid_t08     ) ,
   .m_axis_tready           ( merger_out_tready_t08     ) ,
   .m_axis_tdata            ( merger_out_tdata_t08      ) ,
   .m_axis_tkeep            ( /* Unused */              ) ,
   .m_axis_tlast            ( /* Unused */              ) ,

    
   .i_data                  ( root_data_t08             ) ,
   .i_data_vld              ( root_data_vld_t08         ) ,
   .o_read                  ( root_read_t08             )   
);

merge_tree_assembler #(
   .AXIS_TDATA_WIDTH        ( C_M_AXI_DATA_WIDTH                      ), 
   .RECORD_DATA_WIDTH       ( C_RECORD_BIT_WIDTH * ROOT_BUNDLE_WIDTH  )
)
u_assembler_p1_t12(
   .i_clk                   ( aclk                      ) ,

   .m_axis_tvalid           ( merger_out_tvalid_t12     ) ,
   .m_axis_tready           ( merger_out_tready_t12     ) ,
   .m_axis_tdata            ( merger_out_tdata_t12      ) ,
   .m_axis_tkeep            ( /* Unused */              ) ,
   .m_axis_tlast            ( /* Unused */              ) ,

    
   .i_data                  ( root_data_t12             ) ,
   .i_data_vld              ( root_data_vld_t12         ) ,
   .o_read                  ( root_read_t12             )   
);

merge_tree_assembler #(
   .AXIS_TDATA_WIDTH        ( 4*C_M_AXI_DATA_WIDTH      ), 
   .RECORD_DATA_WIDTH       ( C_RECORD_BIT_WIDTH * 32   )
)
u_assembler_p2(
   .i_clk                   ( aclk                      ) ,

   .m_axis_tvalid           ( merger_out_tvalid_p2      ) ,
   .m_axis_tready           ( merger_out_tready_p2      ) ,
   .m_axis_tdata            ( merger_out_tdata_p2       ) ,
   .m_axis_tkeep            ( /* Unused */              ) ,
   .m_axis_tlast            ( /* Unused */              ) ,

    
   .i_data                  ( root_data_p2              ) ,
   .i_data_vld              ( root_data_vld_p2          ) ,
   .o_read                  ( root_read_p2              )   
);

// AXI4 Write for phase 1
axi_write_master #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       ) ,
  .C_INCLUDE_DATA_FIFO      ( 1                           )
)
u_axi_write_p1_t00 (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start_p1[0]           ) ,
  .ctrl_done                ( write_done_p1[0]            ) ,
  .ctrl_addr_offset         ( write_addr_p1[0]            ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi_awvalid            ( m00_axi_wr_p1.awvalid       ) ,
  .m_axi_awready            ( m00_axi_wr_p1.awready       ) ,
  .m_axi_awaddr             ( m00_axi_wr_p1.awaddr        ) ,
  .m_axi_awburst            ( m00_axi_wr_p1.awburst       ) ,
  .m_axi_awlen              ( m00_axi_wr_p1.awlen         ) ,
  .m_axi_awsize             ( m00_axi_wr_p1.awsize        ) , 
  .m_axi_awid               ( m00_axi_wr_p1.awid          ) ,

  .m_axi_wvalid             ( m00_axi_wr_p1.wvalid        ) ,
  .m_axi_wready             ( m00_axi_wr_p1.wready        ) ,
  .m_axi_wdata              ( m00_axi_wr_p1.wdata         ) ,
  .m_axi_wstrb              ( m00_axi_wr_p1.wstrb         ) ,
  .m_axi_wlast              ( m00_axi_wr_p1.wlast         ) ,

  .m_axi_bvalid             ( m00_axi_wr_p1.bvalid        ) ,
  .m_axi_bready             ( m00_axi_wr_p1.bready        ) ,
  .m_axi_bresp              ( m00_axi_wr_p1.bresp         ) ,
  .m_axi_bid                ( m00_axi_wr_p1.bid           ) ,

  .s_axis_tvalid            ( merger_out_tvalid_t00       ) ,
  .s_axis_tready            ( merger_out_tready_t00       ) ,
  .s_axis_tdata             ( merger_out_tdata_t00        )
);

axi_write_master #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       ) ,
  .C_INCLUDE_DATA_FIFO      ( 1                           )
)
u_axi_write_p1_t04 (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start_p1[1]           ) ,
  .ctrl_done                ( write_done_p1[1]            ) ,
  .ctrl_addr_offset         ( write_addr_p1[1]            ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi_awvalid            ( m04_axi_wr_p1.awvalid       ) ,
  .m_axi_awready            ( m04_axi_wr_p1.awready       ) ,
  .m_axi_awaddr             ( m04_axi_wr_p1.awaddr        ) ,
  .m_axi_awburst            ( m04_axi_wr_p1.awburst       ) ,
  .m_axi_awlen              ( m04_axi_wr_p1.awlen         ) ,
  .m_axi_awsize             ( m04_axi_wr_p1.awsize        ) , 
  .m_axi_awid               ( m04_axi_wr_p1.awid          ) ,

  .m_axi_wvalid             ( m04_axi_wr_p1.wvalid        ) ,
  .m_axi_wready             ( m04_axi_wr_p1.wready        ) ,
  .m_axi_wdata              ( m04_axi_wr_p1.wdata         ) ,
  .m_axi_wstrb              ( m04_axi_wr_p1.wstrb         ) ,
  .m_axi_wlast              ( m04_axi_wr_p1.wlast         ) ,

  .m_axi_bvalid             ( m04_axi_wr_p1.bvalid        ) ,
  .m_axi_bready             ( m04_axi_wr_p1.bready        ) ,
  .m_axi_bresp              ( m04_axi_wr_p1.bresp         ) ,
  .m_axi_bid                ( m04_axi_wr_p1.bid           ) ,

  .s_axis_tvalid            ( merger_out_tvalid_t04       ) ,
  .s_axis_tready            ( merger_out_tready_t04       ) ,
  .s_axis_tdata             ( merger_out_tdata_t04        )
);

axi_write_master #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       ) ,
  .C_INCLUDE_DATA_FIFO      ( 1                           )
)
u_axi_write_p1_t08 (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start_p1[2]           ) ,
  .ctrl_done                ( write_done_p1[2]            ) ,
  .ctrl_addr_offset         ( write_addr_p1[2]            ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi_awvalid            ( m08_axi_wr_p1.awvalid       ) ,
  .m_axi_awready            ( m08_axi_wr_p1.awready       ) ,
  .m_axi_awaddr             ( m08_axi_wr_p1.awaddr        ) ,
  .m_axi_awburst            ( m08_axi_wr_p1.awburst       ) ,
  .m_axi_awlen              ( m08_axi_wr_p1.awlen         ) ,
  .m_axi_awsize             ( m08_axi_wr_p1.awsize        ) , 
  .m_axi_awid               ( m08_axi_wr_p1.awid          ) ,

  .m_axi_wvalid             ( m08_axi_wr_p1.wvalid        ) ,
  .m_axi_wready             ( m08_axi_wr_p1.wready        ) ,
  .m_axi_wdata              ( m08_axi_wr_p1.wdata         ) ,
  .m_axi_wstrb              ( m08_axi_wr_p1.wstrb         ) ,
  .m_axi_wlast              ( m08_axi_wr_p1.wlast         ) ,

  .m_axi_bvalid             ( m08_axi_wr_p1.bvalid        ) ,
  .m_axi_bready             ( m08_axi_wr_p1.bready        ) ,
  .m_axi_bresp              ( m08_axi_wr_p1.bresp         ) ,
  .m_axi_bid                ( m08_axi_wr_p1.bid           ) ,

  .s_axis_tvalid            ( merger_out_tvalid_t08       ) ,
  .s_axis_tready            ( merger_out_tready_t08       ) ,
  .s_axis_tdata             ( merger_out_tdata_t08        )
);

axi_write_master #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       ) ,
  .C_INCLUDE_DATA_FIFO      ( 1                           )
)
u_axi_write_p1_t12 (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start_p1[3]           ) ,
  .ctrl_done                ( write_done_p1[3]            ) ,
  .ctrl_addr_offset         ( write_addr_p1[3]            ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi_awvalid            ( m12_axi_wr_p1.awvalid       ) ,
  .m_axi_awready            ( m12_axi_wr_p1.awready       ) ,
  .m_axi_awaddr             ( m12_axi_wr_p1.awaddr        ) ,
  .m_axi_awburst            ( m12_axi_wr_p1.awburst       ) ,
  .m_axi_awlen              ( m12_axi_wr_p1.awlen         ) ,
  .m_axi_awsize             ( m12_axi_wr_p1.awsize        ) , 
  .m_axi_awid               ( m12_axi_wr_p1.awid          ) ,

  .m_axi_wvalid             ( m12_axi_wr_p1.wvalid        ) ,
  .m_axi_wready             ( m12_axi_wr_p1.wready        ) ,
  .m_axi_wdata              ( m12_axi_wr_p1.wdata         ) ,
  .m_axi_wstrb              ( m12_axi_wr_p1.wstrb         ) ,
  .m_axi_wlast              ( m12_axi_wr_p1.wlast         ) ,

  .m_axi_bvalid             ( m12_axi_wr_p1.bvalid        ) ,
  .m_axi_bready             ( m12_axi_wr_p1.bready        ) ,
  .m_axi_bresp              ( m12_axi_wr_p1.bresp         ) ,
  .m_axi_bid                ( m12_axi_wr_p1.bid           ) ,

  .s_axis_tvalid            ( merger_out_tvalid_t12       ) ,
  .s_axis_tready            ( merger_out_tready_t12       ) ,
  .s_axis_tdata             ( merger_out_tdata_t12        )
);

// AXI4 Write for phase 2
always_ff @( posedge aclk ) begin
  if (merger_out_tvalid_p2 && merger_out_tready_p2)
    axis_write_cnt <= axis_write_cnt + 1;
end

always_ff @( posedge aclk ) begin
  if (merger_out_tvalid_p2 && merger_out_tready_p2 && (axis_write_cnt == '1))
    write_sel <= write_sel + 1; 
end

assign merger_out_tvalid_p2_t00  = merger_out_tvalid_p2 & (write_sel == 2'b00);
assign merger_out_tvalid_p2_t04  = merger_out_tvalid_p2 & (write_sel == 2'b01);
assign merger_out_tvalid_p2_t08  = merger_out_tvalid_p2 & (write_sel == 2'b10);
assign merger_out_tvalid_p2_t12  = merger_out_tvalid_p2 & (write_sel == 2'b11);

mux_4_to_1 #(
   .RECORD_DATA_WIDTH   ( 1    )
)
u_tready_mux_p2(
    .i_data_0           ( merger_out_tready_p2_t00    ) ,
    .i_data_1           ( merger_out_tready_p2_t04    ) ,
    .i_data_2           ( merger_out_tready_p2_t08    ) ,
    .i_data_3           ( merger_out_tready_p2_t12    ) ,
    .i_sel              ( write_sel                   ) ,

    .o_data             ( merger_out_tready_p2        ) 
);

axi_write_master_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXIS_DATA_WIDTH      ( 2048                        ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       )
)
u_axi_write_p2_t00 (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start_p2[0]           ) ,
  .ctrl_done                ( write_done_p2[0]            ) ,
  .ctrl_addr_offset         ( write_addr_p2[0]            ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi                    ( m00_axi_wr_p2               ) ,

  .s_axis_tvalid            ( merger_out_tvalid_p2_t00    ) ,
  .s_axis_tready            ( merger_out_tready_p2_t00    ) ,
  .s_axis_tdata             ( merger_out_tdata_p2         )
);

axi_write_master_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXIS_DATA_WIDTH      ( 2048                        ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       ) 
)
u_axi_write_p2_t04 (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start_p2[1]           ) ,
  .ctrl_done                ( write_done_p2[1]            ) ,
  .ctrl_addr_offset         ( write_addr_p2[1]            ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi                    ( m04_axi_wr_p2               ) ,

  .s_axis_tvalid            ( merger_out_tvalid_p2_t04    ) ,
  .s_axis_tready            ( merger_out_tready_p2_t04    ) ,
  .s_axis_tdata             ( merger_out_tdata_p2         )
);

axi_write_master_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXIS_DATA_WIDTH      ( 2048                        ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       ) 
)
u_axi_write_p2_t08 (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start_p2[2]           ) ,
  .ctrl_done                ( write_done_p2[2]            ) ,
  .ctrl_addr_offset         ( write_addr_p2[2]            ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi                    ( m08_axi_wr_p2               ) ,

  .s_axis_tvalid            ( merger_out_tvalid_p2_t08    ) ,
  .s_axis_tready            ( merger_out_tready_p2_t08    ) ,
  .s_axis_tdata             ( merger_out_tdata_p2         )
);

axi_write_master_phase2 #(
  .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
  .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) ,
  .C_M_AXIS_DATA_WIDTH      ( 2048                        ) ,
  .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
  .C_XFER_SIZE_WIDTH        ( C_XFER_SIZE_WIDTH           ) ,
  .C_MAX_OUTSTANDING        ( LP_WR_MAX_OUTSTANDING       ) 
)
u_axi_write_p2_t12 (
  .aclk                     ( aclk                        ) ,

  .ctrl_start               ( write_start_p2[3]           ) ,
  .ctrl_done                ( write_done_p2[3]            ) ,
  .ctrl_addr_offset         ( write_addr_p2[3]            ) ,
  .ctrl_xfer_size_in_bytes  ( xfer_size_in_bytes_pipe     ) ,

  .m_axi                    ( m12_axi_wr_p2               ) ,

  .s_axis_tvalid            ( merger_out_tvalid_p2_t12    ) ,
  .s_axis_tready            ( merger_out_tready_p2_t12    ) ,
  .s_axis_tdata             ( merger_out_tdata_p2         )
);

// Select the right source for AXI write between phase 1 & 2
axi_wr_mux_2to1 # (
    .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
    .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
    .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) 
)
u_axi_wr_mux_t00 (
    .clk                      ( aclk                        ) ,

    .sel                      ( phase_sel_t00               ) ,

    .s00_axi                  ( m00_axi_wr_p1               ) ,
    .s01_axi                  ( m00_axi_wr_p2               ) ,

    .m_axi_awvalid            ( m00_axi.awvalid             ) ,
    .m_axi_awready            ( m00_axi.awready             ) ,
    .m_axi_awaddr             ( m00_axi.awaddr              ) ,
    .m_axi_awburst            ( m00_axi.awburst             ) ,
    .m_axi_awlen              ( m00_axi.awlen               ) ,
    .m_axi_awsize             ( m00_axi.awsize              ) ,
    .m_axi_awid               ( m00_axi.awid                ) ,

    .m_axi_wvalid             ( m00_axi.wvalid              ) ,
    .m_axi_wready             ( m00_axi.wready              ) ,
    .m_axi_wdata              ( m00_axi.wdata               ) ,
    .m_axi_wstrb              ( m00_axi.wstrb               ) ,
    .m_axi_wlast              ( m00_axi.wlast               ) ,

    .m_axi_bvalid             ( m00_axi.bvalid              ) ,
    .m_axi_bready             ( m00_axi.bready              ) ,
    .m_axi_bresp              ( m00_axi.bresp               ) ,
    .m_axi_bid                ( m00_axi.bid                 ) 
);

axi_wr_mux_2to1_type2 # (
    .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
    .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
    .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) 
)
u_axi_wr_mux_t04 (
    .clk                      ( aclk                        ) ,

    .sel                      ( phase_sel_t04               ) ,

    .s00_axi                  ( m04_axi_wr_p1               ) ,
    .s01_axi                  ( m04_axi_wr_p2               ) ,

    .m_axi                    ( m04_axi_wr                  ) 
);

axi_wr_mux_2to1 # (
    .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
    .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
    .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) 
)
u_axi_wr_mux_t08 (
    .clk                      ( aclk                        ) ,

    .sel                      ( phase_sel_t08               ) ,

    .s00_axi                  ( m08_axi_wr_p1               ) ,
    .s01_axi                  ( m08_axi_wr_p2               ) ,

    .m_axi_awvalid            ( m08_axi.awvalid             ) ,
    .m_axi_awready            ( m08_axi.awready             ) ,
    .m_axi_awaddr             ( m08_axi.awaddr              ) ,
    .m_axi_awburst            ( m08_axi.awburst             ) ,
    .m_axi_awlen              ( m08_axi.awlen               ) ,
    .m_axi_awsize             ( m08_axi.awsize              ) ,
    .m_axi_awid               ( m08_axi.awid                ) ,

    .m_axi_wvalid             ( m08_axi.wvalid              ) ,
    .m_axi_wready             ( m08_axi.wready              ) ,
    .m_axi_wdata              ( m08_axi.wdata               ) ,
    .m_axi_wstrb              ( m08_axi.wstrb               ) ,
    .m_axi_wlast              ( m08_axi.wlast               ) ,

    .m_axi_bvalid             ( m08_axi.bvalid              ) ,
    .m_axi_bready             ( m08_axi.bready              ) ,
    .m_axi_bresp              ( m08_axi.bresp               ) ,
    .m_axi_bid                ( m08_axi.bid                 ) 
);

axi_wr_mux_2to1_type2 # (
    .C_M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH            ) ,
    .C_M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH          ) ,
    .C_M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH          ) 
)
u_axi_wr_mux_t12 (
    .clk                      ( aclk                        ) ,

    .sel                      ( phase_sel_t12               ) ,

    .s00_axi                  ( m12_axi_wr_p1               ) ,
    .s01_axi                  ( m12_axi_wr_p2               ) ,

    .m_axi                    ( m12_axi_wr                  ) 
);

assign o_wr_done_p1_t04 = write_done_p1[1];
assign o_wr_done_p1_t12 = write_done_p1[3];

assign o_done_p1 = p1_done_pipe;
//assign o_done_p2 = p2_done_pipe;
assign o_done_p2 = p2_done_i;

endmodule

