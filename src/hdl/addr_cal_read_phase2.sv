/**********************************************************************************
 * Read address calculator of phase 2 for trees that are in mid or top SLR. 
 * The address calculator reads 4 channels and in each channel it reads 4 
   consecutive streams.
**********************************************************************************/

module addr_cal_read_phase2 #(
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

  output logic                                                      o_read_start            , // read start
  output logic [15:0][C_M_AXI_ADDR_WIDTH-1:0]                       o_read_addr             , // read address for tree 0
  output logic [C_XFER_SIZE_WIDTH-1:0]                              o_read_size_in_bytes             
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

// Local parameters
localparam integer          LP_READ_SIZE_WIDTH      = 28; // A single channel contain at most 256MB data
localparam integer          LP_ADDR_STATIC_WIDTH    = C_M_AXI_ADDR_WIDTH - LP_READ_SIZE_WIDTH;

// Addresses
logic [7:0][C_M_AXI_ADDR_WIDTH-1:0]                         chan_start_addr         ; // Initial address for each channel
logic [15:0][C_M_AXI_ADDR_WIDTH-1:0]                        read_addr               ;   

// Addr control information
logic [C_XFER_SIZE_WIDTH-1:0]                               read_size_in_bytes      ; 
logic [C_XFER_SIZE_WIDTH-1:0]                               quarter3_xfer_size_in_bytes = '0;

// Output signals after register 
(* keep = "true" *)logic                                    read_start_pipe = '0    ;
logic [15:0][C_M_AXI_ADDR_WIDTH-1:0]                        read_addr_pipe = '0     ;   

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


// Generate output
always_ff @( posedge aclk ) begin
    read_start_pipe  <=  i_start         ;
    read_addr_pipe   <=  read_addr       ;
end

always_comb begin : gen_out
    o_read_start            =   read_start_pipe     ;
    o_read_addr             =   read_addr_pipe      ;
    o_read_size_in_bytes    =   read_size_in_bytes  ;
end : gen_out


endmodule : addr_cal_read_phase2