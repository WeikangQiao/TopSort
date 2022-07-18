module merge_integration #(
    parameter integer AXIS_TDATA_WIDTH      =   512 , 
    parameter integer RECORD_DATA_WIDTH     =   32  ,
    parameter integer RECORD_KEY_WIDTH      =   32  ,
    parameter integer INIT_SORTED_CHUNK     =   1   ,
    parameter integer ROOT_BUNDLE_WIDTH     =   4   ,
    parameter integer NUM_LEAVES            =   8
)
(
    input   logic                                                       i_clk           ,

    input   logic                                                       i_init_pass     ,

    input   logic [NUM_LEAVES-1:0]                                      s_axis_tvalid   ,
    output  logic [NUM_LEAVES-1:0]                                      s_axis_tready   ,
    input   logic [NUM_LEAVES-1:0] [AXIS_TDATA_WIDTH-1:0]               s_axis_tdata    ,
    input   logic [NUM_LEAVES-1:0]                                      s_axis_tlast    ,

    output  logic                                                       m_axis_tvalid   ,
    input   logic                                                       m_axis_tready   ,
    output  logic [AXIS_TDATA_WIDTH-1:0]                                m_axis_tdata    ,
    output  logic [AXIS_TDATA_WIDTH/8-1:0]                              m_axis_tkeep    ,
    output  logic                                                       m_axis_tlast
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
logic   [NUM_LEAVES-1:0]                            feeder_read;
logic   [NUM_LEAVES-1:0][RECORD_DATA_WIDTH:0]       feeder_data;
logic   [NUM_LEAVES-1:0]                            feeder_data_vld;

logic   [NUM_LEAVES-1:0]                            feeder_read_pipe;
logic   [NUM_LEAVES-1:0][RECORD_DATA_WIDTH:0]       feeder_data_pipe;
logic   [NUM_LEAVES-1:0]                            feeder_data_vld_pipe;

logic                                               root_read;
logic   [ROOT_BUNDLE_WIDTH*RECORD_DATA_WIDTH-1:0]   root_data;
logic                                               root_data_vld;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

merge_tree_dispatch #(
   .AXIS_TDATA_WIDTH        ( AXIS_TDATA_WIDTH                  ), 
   .INIT_SORTED_CHUNK       ( INIT_SORTED_CHUNK                 ),
   .RECORD_DATA_WIDTH       ( RECORD_DATA_WIDTH                 )
)
u_feeder [NUM_LEAVES-1:0] (
   .i_clk                   ( i_clk                             ),

   .i_init_pass             ( i_init_pass                       ),

   .s_axis_tvalid           ( s_axis_tvalid                     ),
   .s_axis_tready           ( s_axis_tready                     ),
   .s_axis_tdata            ( s_axis_tdata                      ),
   .s_axis_tlast            ( s_axis_tlast                      ),

   .i_read                  ( feeder_read                       ),  
   .o_data                  ( feeder_data                       ),
   .o_data_vld              ( feeder_data_vld                   )
);

fifo_gen_register #
(
    .DATA_WIDTH             ( RECORD_DATA_WIDTH+1               ),
    .PIPE_LEVEL             ( 2                                 )
)
u_fifo_pipe [NUM_LEAVES-1:0] (
    .clk                    ( i_clk                             ),

    .s_data_vld             ( feeder_data_vld                   ),
    .s_data                 ( feeder_data                       ),
    .s_read                 ( feeder_read                       ),
    
    .m_data_vld             ( feeder_data_vld_pipe              ),
    .m_data                 ( feeder_data_pipe                  ),
    .m_read                 ( feeder_read_pipe                  )
);

merge_tree #(
    .DATA_WIDTH             ( RECORD_DATA_WIDTH                 ),
    .KEY_WIDTH              ( RECORD_KEY_WIDTH                  ),
    .BUNDLE_WIDTH           ( ROOT_BUNDLE_WIDTH                 ),
    .NUM_LEAVES             ( NUM_LEAVES                        )
)
u_merge_kernel(
    .i_clk                  ( i_clk                             ),

    .i_leaf_data            ( feeder_data_pipe                  ),   // {last, data} from each leaf
    .i_leaf_data_vld        ( feeder_data_vld_pipe              ),   // valid signal for data from each leaf
    .i_root_read            ( root_read                         ),   // enable signal for reading the root fifo

    .o_leaf_read            ( feeder_read_pipe                  ),   // enable signal for reading each leaf
    .o_root_data            ( root_data                         ),   // root output data
    .o_root_data_vld        ( root_data_vld                     )    // enable signal for writing output fifo
);

merge_tree_assembler #(
   .AXIS_TDATA_WIDTH        ( AXIS_TDATA_WIDTH                      ), 
   .RECORD_DATA_WIDTH       ( RECORD_DATA_WIDTH * ROOT_BUNDLE_WIDTH )
)
u_assembler(
   .i_clk                   ( i_clk                             ),

   .m_axis_tvalid           ( m_axis_tvalid                     ),
   .m_axis_tready           ( m_axis_tready                     ),
   .m_axis_tdata            ( m_axis_tdata                      ),
   .m_axis_tkeep            ( /* Unused */                      ),
   .m_axis_tlast            ( m_axis_tlast                      ),

    
   .i_data                  ( root_data                         ),
   .i_data_vld              ( root_data_vld                     ),
   .o_read                  ( root_read                         )  

);

endmodule