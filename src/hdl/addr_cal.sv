// Address calculator for multipass
////////////////////////////////////////////////////////////////////////////////
// default_nettype of none prevents implicit wire declaration.
module addr_cal #(
  parameter integer NUM_READ_CHANNELS           = 1     , 
  parameter integer C_M_AXI_DATA_WIDTH          = 512   ,
  parameter integer C_M_AXI_ADDR_WIDTH          = 64    ,
  parameter integer C_XFER_SIZE_WIDTH           = 64    ,
  parameter integer C_BURST_SIZE_BYTES          = 1024  ,
  parameter integer C_INIT_BUNDLE_WIDTH         = 1     ,
  parameter integer C_RECORD_BIT_WIDTH          = 32    ,
  parameter integer C_CHANNEL_OFFSET            = 0        
)
(
  // System Signals
  input  logic                                                      aclk                    ,
  // Engine signal
  input  logic                                                      ap_start                ,
  output logic                                                      ap_done                 ,  
  // AXI read control information
  input  logic [8-1:0]                                              i_num_pass              , // number of total passes needed
  input  logic [C_M_AXI_ADDR_WIDTH-1:0]                             i_ptr_ch_0              , // Starting address of channel 0
  input  logic [C_XFER_SIZE_WIDTH-1:0]                              i_xfer_size_in_bytes    , // total input size in bytes 
  input  logic                                                      i_single_run_read_done  , // asserted to indicate a single run of read is done
  input  logic                                                      i_write_done            , // write done means one pass is done

  output logic                                                      o_read_start            , // Start read if each run
  output logic [NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]      o_read_addr             , // read address for each leaf node
  output logic [C_XFER_SIZE_WIDTH-1:0]                              o_read_size_in_bytes    , // how many bytes needs to be read per node for the current run
  output logic                                                      o_read_divide           , // asserted to indicate burst needs to be divided for multiple runs
  output logic [7:0]                                                o_read_axi_cnt_per_run  , // indicate after how many 64-byte reads we assert tlast bit
  output logic                                                      o_write_start           , // 
  output logic [C_M_AXI_ADDR_WIDTH-1:0]                             o_write_addr            , //    
  output logic                                                      o_init_pass
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

// Local Parameters
localparam integer LP_DW_BYTES                      = C_M_AXI_DATA_WIDTH/8                          ; // AXI data width in bytes
localparam integer LP_LOG_DW_BYTES                  = $clog2(LP_DW_BYTES)                           ; //
localparam integer LP_AXI_DATA_CNT_WIDTH            = 8                                             ; // data width of o_read_axi_cnt_per_run
localparam integer LP_NUM_READ_NODES                = NUM_READ_CHANNELS                             ; //
localparam integer LP_PASS_INCREMENT                = $clog2(LP_NUM_READ_NODES)                     ; // each pass increase bytes by LP_NUM_READ_NODES
localparam integer LP_LOG_BURST_SIZE_BYTE           = $clog2(C_BURST_SIZE_BYTES)                    ; //
localparam integer LP_INIT_SORT_BYTE                = C_INIT_BUNDLE_WIDTH * C_RECORD_BIT_WIDTH / 8  ; // sorted chunk size in bytes after presort
localparam integer LP_LOG_INIT_SORT_BYTE            = $clog2(LP_INIT_SORT_BYTE)                     ; // 
localparam integer LP_INIT_XFER_ZERO_WIDTH          = C_XFER_SIZE_WIDTH - LP_LOG_INIT_SORT_BYTE - 1 ; // Number of 0s needed to be filled.
localparam integer LP_TRANSCATION_CNTR_WIDTH        = C_XFER_SIZE_WIDTH - LP_LOG_BURST_SIZE_BYTE    ;

// Initial address
logic [C_M_AXI_ADDR_WIDTH-1:0]                                  ptr_0                               ;
logic [C_M_AXI_ADDR_WIDTH-1:0]                                  ptr_1                               ;

// Addr control information
logic                                                           ap_start_delay = 0                   ;
logic                                                           single_run_read_done_delay = 0       ; 
logic                                                           write_done_delay = 0                 ;

logic [7:0]                                                     pass_count = 0                       ; // count how many passes have been done

logic [C_M_AXI_ADDR_WIDTH-1:0]                                  read_addr_multi_run = 0              ; // the starting addr for multi-runs read
logic [NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]           read_addr                            ; // read address for each node

logic [C_XFER_SIZE_WIDTH-1:0]                                   single_run_xfer_bytes = 0            ; // for the current pass, how many bytes need to read per node, round to an axi burst
logic [C_XFER_SIZE_WIDTH-1:0]                                   single_run_xfer_bytes_sum = 0        ; // single_run_xfer_bytes_sum = single_run_xfer_bytes * LP_NUM_READ_NODES
logic [C_XFER_SIZE_WIDTH-1:0]                                   total_run_xfer_bytes = 0             ; // for the current pass, how many bytes in total have been read till the current run

logic [C_XFER_SIZE_WIDTH-1:0]                                   real_single_run_xfer_bytes_next = 0  ; // for the next pass, how many bytes actually read per node

logic                                                           need_divide = 0                      ; // a full axi burst needs to be divided for multiple runs
logic [7:0]                                                     axi_cnt_per_run = 0                  ; // how many 64-byte axi read per run

logic [C_M_AXI_ADDR_WIDTH-1:0]                                  write_addr = 0                       ; // write addr

// Output signals after register 
logic                                                           read_start_pipe             =  '0;
logic [NUM_READ_CHANNELS-1:0][C_M_AXI_ADDR_WIDTH-1:0]           read_addr_pipe              =  '0;
logic [C_XFER_SIZE_WIDTH-1:0]                                   read_size_in_bytes_pipe     =  '0;
logic                                                           read_divide_pipe            =  '0;
logic [7:0]                                                     read_axi_cnt_per_run_pipe   =  '0;
logic                                                           write_start_pipe            =  '0; 
logic [C_M_AXI_ADDR_WIDTH-1:0]                                  write_addr_pipe             =  '0;    
logic                                                           init_pass_pipe              =  '0;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

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

assign ap_done = i_write_done && (pass_count == (i_num_pass - 1));

// calculate pass_count
always_ff @(posedge aclk) begin
    if (ap_start) begin
        pass_count <= 0;
    end
    else if (i_write_done) begin
        pass_count <= pass_count + 1;
    end
end

// calculate write_addr
always_ff @(posedge aclk) begin
    if(ap_start) begin
        write_addr <= ptr_1;
    end
    else if (i_write_done && (~pass_count[0])) begin
        write_addr <= ptr_0;
    end 
    else if (i_write_done && pass_count[0]) begin
        write_addr <= ptr_1;
    end
end

// calculate read_addr_multi_run
// WK: this can be replaced by DSPs
always_ff @(posedge aclk) begin
    if (ap_start) begin
        read_addr_multi_run <= ptr_0;
    end
    else if (i_write_done && (~pass_count[0])) begin
        read_addr_multi_run <= ptr_1;
    end
    else if (i_write_done && pass_count[0]) begin
        read_addr_multi_run <= ptr_0;
    end
    else if (i_single_run_read_done) begin
        read_addr_multi_run <= read_addr_multi_run + single_run_xfer_bytes_sum;
    end
end

// calculate read address for each node
// WK: this can be replaced by DSPs
always_comb begin
    for (int i = 0; i < LP_NUM_READ_NODES; i++) begin
        read_addr[i] = read_addr_multi_run + i * single_run_xfer_bytes;
    end
end

// calculate how many bytes actually needed to be read per each run for the next pass
always_ff @(posedge aclk) begin
    if (ap_start) begin
        real_single_run_xfer_bytes_next <= ({{LP_INIT_XFER_ZERO_WIDTH{1'b0}}, 1'b1, {LP_LOG_INIT_SORT_BYTE{1'b0}}} << LP_PASS_INCREMENT); // start from initial sorted chunk size, shifted by << LP_PASS_INCREMENT)
    end
    else if(i_write_done) begin
        if (pass_count == (i_num_pass - 3)) begin // the next pass is the last pass: each node has only one run, run size is i_xfer_size_in_bytes/LP_NUM_READ_NODES
            real_single_run_xfer_bytes_next <= ({2'b0, i_xfer_size_in_bytes[C_XFER_SIZE_WIDTH-1:2]} >> LP_PASS_INCREMENT);
        end
        else begin
            real_single_run_xfer_bytes_next <= (real_single_run_xfer_bytes_next << LP_PASS_INCREMENT);
        end
    end
end

// calculate how many bytes need to read per node for the current pass
// if less than an entire AXI burst, issue an entire AXI burst read
always_ff @(posedge aclk) begin
    if (ap_start) begin // Initial run
        single_run_xfer_bytes <= {{C_XFER_SIZE_WIDTH-1-LP_LOG_BURST_SIZE_BYTE{1'b0}}, 1'b1, {LP_LOG_BURST_SIZE_BYTE{1'b0}}}; // initially issue an entire AXI burst
        need_divide <= 1'b1;
        axi_cnt_per_run <= 1; // If initial sorted chunk size in bytes is less than 8, this is not preciese, but functionally acceptable as we will assert last in merge_tree_dispatch
    end
    else if(i_write_done) begin   // Following runs
        if (real_single_run_xfer_bytes_next[LP_LOG_BURST_SIZE_BYTE+:LP_TRANSCATION_CNTR_WIDTH] > 0) begin // if single run transfer size is larger than an AXI burst read size
            need_divide <= 1'b0;
            axi_cnt_per_run <= axi_cnt_per_run;
            single_run_xfer_bytes <= real_single_run_xfer_bytes_next;
        end 
        else begin // if single run transfer size is less than an AXI burst read size, issue an AXI burst
            need_divide <= 1;
            axi_cnt_per_run <= real_single_run_xfer_bytes_next[LP_LOG_DW_BYTES+:LP_AXI_DATA_CNT_WIDTH]; // Assume in this pass a single run already contains multiple 512-bit AXI data
            single_run_xfer_bytes <= {{C_XFER_SIZE_WIDTH-1-LP_LOG_BURST_SIZE_BYTE{1'b0}}, 1'b1, {LP_LOG_BURST_SIZE_BYTE{1'b0}}};
        end
    end
end

// calculate how much address offset for all nodes per run
// if each node has less than an entire AXI burst, then address offset is LP_NUM_READ_NODES axi bursts
always_ff @(posedge aclk) begin
    if (ap_start) begin
        single_run_xfer_bytes_sum <= ({{C_XFER_SIZE_WIDTH-1-LP_LOG_BURST_SIZE_BYTE{1'b0}}, 1'b1, {LP_LOG_BURST_SIZE_BYTE{1'b0}}} << LP_PASS_INCREMENT);
    end
    else if(i_write_done) begin
        if (real_single_run_xfer_bytes_next[LP_LOG_BURST_SIZE_BYTE+:LP_TRANSCATION_CNTR_WIDTH] > 0) begin 
            single_run_xfer_bytes_sum <= (real_single_run_xfer_bytes_next << LP_PASS_INCREMENT);
        end
        else begin
            single_run_xfer_bytes_sum <= ({{C_XFER_SIZE_WIDTH-1-LP_LOG_BURST_SIZE_BYTE{1'b0}}, 1'b1, {LP_LOG_BURST_SIZE_BYTE{1'b0}}} << LP_PASS_INCREMENT);
        end
    end
end

// calculate total_run_xfer_bytes
always_ff @(posedge aclk) begin
  if (ap_start | i_write_done) begin
    total_run_xfer_bytes <= 0;
  end
  else if (i_single_run_read_done) begin
    total_run_xfer_bytes <= total_run_xfer_bytes + single_run_xfer_bytes_sum;
  end
end

// delay ap_start_delay for 1 cycle
always_ff @(posedge aclk) begin
  ap_start_delay <= ap_start;
end

// delay i_single_run_read_done for 1 cycle
always_ff @(posedge aclk) begin
  single_run_read_done_delay <= i_single_run_read_done;
end

// delay i_write_done for 1 cycle
always_ff @(posedge aclk) begin
  write_done_delay <= i_write_done;
end

// Generate output
always_ff @(posedge aclk) begin : assign_value
    read_start_pipe             <=  ap_start_delay || (write_done_delay && (pass_count != i_num_pass)) 
                                    || (single_run_read_done_delay && total_run_xfer_bytes < i_xfer_size_in_bytes);
    read_addr_pipe              <=  read_addr;
    read_size_in_bytes_pipe     <=  single_run_xfer_bytes;
    read_divide_pipe            <=  need_divide;
    read_axi_cnt_per_run_pipe   <=  axi_cnt_per_run;
    write_start_pipe            <=  ap_start_delay || (write_done_delay && (pass_count != i_num_pass));
    write_addr_pipe             <=  write_addr;
    init_pass_pipe              <=  (pass_count == 0);
end: assign_value

always_comb begin : gen_output
    o_read_start            =   read_start_pipe;
    o_read_addr             =   read_addr_pipe;
    o_read_size_in_bytes    =   read_size_in_bytes_pipe;
    o_read_divide           =   read_divide_pipe;
    o_read_axi_cnt_per_run  =   read_axi_cnt_per_run_pipe;
    o_write_start           =   write_start_pipe;
    o_write_addr            =   write_addr_pipe;
    o_init_pass             =   init_pass_pipe;
end: gen_output


endmodule : addr_cal