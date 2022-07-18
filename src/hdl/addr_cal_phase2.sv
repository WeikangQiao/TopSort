// Address calculator of phase 2 for merge tree 00 & 08
////////////////////////////////////////////////////////////////////////////////

module addr_cal_phase2 #(
  parameter integer C_M_AXI_ADDR_WIDTH          = 64    ,
  parameter integer C_XFER_SIZE_WIDTH           = 64    ,
  parameter integer CHANNEL_OFFSET              = 0          
)
(
  // System Signals
  input  logic                                                      aclk                    ,
  // Engine signal
  input  logic                                                      i_start                 , // phase 2 start
  // AXI read control information
  input  logic                                                      i_pass_parity           , // parity of pass number in phase 1
  input  logic [C_M_AXI_ADDR_WIDTH-1:0]                             i_ptr_ch_0              , // starting address of channel 0
  input  logic [C_XFER_SIZE_WIDTH-1:0]                              i_xfer_size_in_bytes    , // total input size in bytes 
  input  logic                                                      i_write_done            , // write done for the current channel

  output logic                                                      o_read_start            , // read start
  output logic [15:0][C_M_AXI_ADDR_WIDTH-1:0]                       o_read_addr             , // read address for tree 1
  output logic [C_XFER_SIZE_WIDTH-1:0]                              o_read_size_in_bytes    , // how many bytes needs to be read per node for the current run
  output logic                                                      o_write_start           , // 
  output logic [C_M_AXI_ADDR_WIDTH-1:0]                             o_write_addr            ,
  output logic                                                      o_phase_2_done             
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

// Local parameters
localparam integer          LP_READ_SIZE_WIDTH      = 28;
localparam integer          LP_ADDR_STATIC_WIDTH    = C_M_AXI_ADDR_WIDTH - LP_READ_SIZE_WIDTH;

// Addresses
logic [7:0][C_M_AXI_ADDR_WIDTH-1:0]                         chan_start_addr         ; // Initial address for each channel
logic [15:0][C_M_AXI_ADDR_WIDTH-1:0]                        read_addr               ;

logic [C_XFER_SIZE_WIDTH-1:0]                               read_size_in_bytes      ; 
logic [C_XFER_SIZE_WIDTH-1:0]                               quarter3_xfer_size_in_bytes = '0;

logic [3:0][C_M_AXI_ADDR_WIDTH-1:0]                         write_addr_cand         ; // Write address candidates
logic                                                       write_start = '0        ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                              write_addr              ; // Write address after selection
logic [C_XFER_SIZE_WIDTH-1:0]                               write_size_in_bytes     ; 

logic [1:0]                                                 write_sel = '0          ;

logic                                                       phase_2_done            ; // Write done for current AXI in phase 2

// Output signals after register 
logic                                                       read_start_pipe = '0    ;
logic [15:0][C_M_AXI_ADDR_WIDTH-1:0]                        read_addr_pipe = '0     ;   
logic                                                       write_start_pipe = '0   ;    
logic [C_M_AXI_ADDR_WIDTH-1:0]                              write_addr_pipe = '0    ; 
logic                                                       phase_2_done_pipe       ;


///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

// Calculate channel starting address
genvar ch;
generate
    for (ch = 0; ch < 8; ch ++) begin: foreach_ch
        dsp_ch_addr #(
          .CHANNEL_OFFSET           ( ch + CHANNEL_OFFSET   )        
        )
        u_ch_addr (
          .aclk                     ( aclk                  ) ,
          .i_ptr                    ( i_ptr_ch_0            ) ,
          .o_ptr                    ( chan_start_addr[ch]   )    
        );
    end: foreach_ch
endgenerate

// Read address for tree 0
always_comb begin
    for (int i = 0; i < 4; i++) begin: genaddr_rd
        read_addr[4*i]  = i_pass_parity ? chan_start_addr[2*i+1] : chan_start_addr[2*i];
        // We do concatenation to simplify the case
        read_addr[4*i+1]    = i_pass_parity ?   {chan_start_addr[2*i+1][LP_READ_SIZE_WIDTH +: LP_ADDR_STATIC_WIDTH], i_xfer_size_in_bytes[2 +: LP_READ_SIZE_WIDTH]} : 
                                                {chan_start_addr[2*i][LP_READ_SIZE_WIDTH +: LP_ADDR_STATIC_WIDTH], i_xfer_size_in_bytes[2 +: LP_READ_SIZE_WIDTH]};
        read_addr[4*i+2]    = i_pass_parity ?   {chan_start_addr[2*i+1][LP_READ_SIZE_WIDTH +: LP_ADDR_STATIC_WIDTH], i_xfer_size_in_bytes[1 +: LP_READ_SIZE_WIDTH]} : 
                                                {chan_start_addr[2*i][LP_READ_SIZE_WIDTH +: LP_ADDR_STATIC_WIDTH], i_xfer_size_in_bytes[1 +: LP_READ_SIZE_WIDTH]};
        read_addr[4*i+3]    = i_pass_parity ?   {chan_start_addr[2*i+1][LP_READ_SIZE_WIDTH +: LP_ADDR_STATIC_WIDTH], quarter3_xfer_size_in_bytes[0 +: LP_READ_SIZE_WIDTH]} : 
                                                {chan_start_addr[2*i][LP_READ_SIZE_WIDTH +: LP_ADDR_STATIC_WIDTH], quarter3_xfer_size_in_bytes[0 +: LP_READ_SIZE_WIDTH]};
    end: genaddr_rd
end

// Read size is 1/4 of the size per channel
assign read_size_in_bytes   =   {2'b0, i_xfer_size_in_bytes[C_XFER_SIZE_WIDTH-1:2]};
always_ff @(posedge aclk ) begin
    quarter3_xfer_size_in_bytes <= {2'b0, i_xfer_size_in_bytes[C_XFER_SIZE_WIDTH-1:2]} + {1'b0, i_xfer_size_in_bytes[C_XFER_SIZE_WIDTH-1:1]}; 
end

// Write address candidates
always_comb begin
    for (int i = 0; i < 4; i++) begin: genaddr_wr
        write_addr_cand[i] = i_pass_parity ? chan_start_addr[2*i] : chan_start_addr[2*i+1];
    end: genaddr_wr 
end

// Write selection
always_ff @( posedge aclk) begin
    if (i_write_done)
        write_sel <= write_sel + 1;
end


assign phase_2_done = (write_sel == 2'd3) & i_write_done;

// Write start logic
always_ff @( posedge aclk ) begin
    write_start <= i_start | (i_write_done & (write_sel != 2'd3));
end

// Write address for 1st & 2nd axi
mux_4_to_1 #(
   .RECORD_DATA_WIDTH   ( C_M_AXI_ADDR_WIDTH    )
)
u_write_addr_0(
    .i_data_0           ( write_addr_cand[0]    ) ,
    .i_data_1           ( write_addr_cand[1]    ) ,
    .i_data_2           ( write_addr_cand[2]    ) ,
    .i_data_3           ( write_addr_cand[3]    ) ,
    .i_sel              ( write_sel             ) ,

    .o_data             ( write_addr            ) 
);

// Generate output
always_ff @( posedge aclk ) begin
    read_start_pipe     <=  i_start         ;
    read_addr_pipe      <=  read_addr       ;
    write_start_pipe    <=  write_start     ;
    write_addr_pipe     <=  write_addr      ;
    phase_2_done_pipe   <=  phase_2_done    ;  
end

always_comb begin : gen_out
    o_read_start            =   read_start_pipe     ;
    o_read_addr             =   read_addr_pipe      ;
    o_read_size_in_bytes    =   read_size_in_bytes  ;
    o_write_start           =   write_start_pipe    ;
    o_write_addr            =   write_addr_pipe     ; 
    o_phase_2_done          =   phase_2_done_pipe   ;
end : gen_out


endmodule : addr_cal_phase2