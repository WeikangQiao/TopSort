// Address calculator for phase 1: merge tree 4 & 12 only
////////////////////////////////////////////////////////////////////////////////

module addr_cal_wr_phase1 #(
  parameter integer C_M_AXI_ADDR_WIDTH          = 64    ,
  parameter integer C_XFER_SIZE_WIDTH           = 64    ,
  parameter integer C_CHANNEL_OFFSET            = 0        
)
(
  // System Signals
  input  logic                                                      aclk                    ,
  //
  input  logic                                                      i_phase_1_start         ,
  // AXI read control information
  input  logic [C_M_AXI_ADDR_WIDTH-1:0]                             i_ptr_ch_0              , // starting address of channel 0
  input  logic                                                      i_write_start           , // phase 1 write start signal input from corresponding merge tree in different SLR
  // input  logic [C_XFER_SIZE_WIDTH-1:0]                              i_write_size            ,
  input  logic                                                      i_write_done            , // write done for the current channel

  output logic                                                      o_write_start           , 
  output logic [C_M_AXI_ADDR_WIDTH-1:0]                             o_write_addr            
  //output logic [C_XFER_SIZE_WIDTH-1:0]                              o_write_size                        
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
// Channel Addresses
logic [C_M_AXI_ADDR_WIDTH-1:0]                              ptr_0                   ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                              ptr_1                   ;
// Addr control information
logic                                                       pass_parity = '0        ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                              write_addr              ;   

// Output signals after register 
logic                                                       write_start_pipe = '0   ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                              write_addr_pipe = '0    ; 
logic [C_XFER_SIZE_WIDTH-1:0]                               write_size_pipe = '0    ;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

// Calculate channel starting address
dsp_ch_addr #(
  .CHANNEL_OFFSET           ( C_CHANNEL_OFFSET      )        
)
u_ch_addr_0 (
  .aclk                     ( aclk                  ) ,
  .i_ptr                    ( i_ptr_ch_0            ) ,
  .o_ptr                    ( ptr_0                 )    
);

dsp_ch_addr #(
  .CHANNEL_OFFSET           ( C_CHANNEL_OFFSET + 1  )        
)
u_ch_addr_1 (
  .aclk                     ( aclk                  ) ,
  .i_ptr                    ( i_ptr_ch_0            ) ,
  .o_ptr                    ( ptr_1                 )    
);

// calculate pass_count
always_ff @(posedge aclk) begin
    if (i_phase_1_start) begin
        pass_parity <= 0;
    end
    else if (i_write_done) begin
        pass_parity <= ~pass_parity;
    end
end

// calculate write_addr
always_ff @(posedge aclk) begin
    if(i_phase_1_start) begin
        write_addr <= ptr_1;
    end
    else if (i_write_done && (~pass_parity)) begin
        write_addr <= ptr_0;
    end 
    else if (i_write_done && pass_parity) begin
        write_addr <= ptr_1;
    end
end

// Generate output
always_ff @( posedge aclk ) begin
    write_start_pipe    <=  i_write_start   ;
    write_addr_pipe     <=  write_addr      ;
    //write_size_pipe     <=  i_write_size    ;
end

always_comb begin : gen_out
    o_write_start           =   write_start_pipe    ;
    o_write_addr            =   write_addr_pipe     ; 
    //o_write_size            =   write_size_pipe     ; 
end : gen_out


endmodule : addr_cal_wr_phase1