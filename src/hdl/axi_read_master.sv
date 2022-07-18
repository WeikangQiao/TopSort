///////////////////////////////////////////////////////////////////////////////
// 
// Description: This is a multi-threaded AXI4 read master. Each node will 
// issue commands on a different IDs. As a result data may arrive out ot order
///////////////////////////////////////////////////////////////////////////////
module axi_read_master #(
  // set the channel ID width
  // Must be >= $clog2(C_NUM_NODES)
  parameter integer C_ID_WIDTH  = 1,
  // Set to the address width of the interface
  parameter integer C_M_AXI_ADDR_WIDTH  = 64,
  // Set the data width of the interface
  // Range: 32, 64, 128, 256, 512, 1024
  parameter integer C_M_AXI_DATA_WIDTH  = 32,
  // Set the number of channels this AXI read master will connect
  parameter integer C_NUM_NODES = 2,
  // Width of the i_xfer_size_in_bytes input
  // Range: 16:C_M_AXI_ADDR_WIDTH
  parameter integer C_XFER_SIZE_WIDTH   = 32,
  // Width of each sorting elements
  parameter integer C_RECORD_BIT_WIDTH = 128,
  // Key width of each sorting elements
  parameter integer C_RECORD_KEY_WIDTH = 80,
  // Specifies how many bytes each full burst is
  parameter integer C_BURST_SIZE_BYTES = 1024,
  // Specifies the maximum number of AXI4 transactions that may be outstanding.
  // Affects FIFO depth if data FIFO is enabled.
  parameter integer C_MAX_OUTSTANDING   = 16,
  // Specify how many nodes uses BRAM
  parameter integer C_NUM_BRAM_NODES = 4,
  // Specify the sorted chunk size after the presorter
  parameter integer C_INIT_SORTED_CHUNK = 1
)
(
  // System signals
  input  logic                                             aclk                ,

  // Control signals
  input  logic                                             i_start             , // Pulse high for one cycle to begin reading
  input  logic                                             i_pass_start        , // Pusle high for one cycle to indicate one pass begin
  output logic                                             o_done              , // Pulses high for one cycle when transfer request is complete

  // The following ctrl signals are sampled when i_start is asserted
  input  logic [C_NUM_NODES-1:0][C_M_AXI_ADDR_WIDTH-1:0]   i_addr_offset       , // Starting address for each node
  input  logic                  [C_XFER_SIZE_WIDTH-1:0]    i_xfer_size_in_bytes, // The number of bytes that each node reads 
  input  logic                                             i_read_divide       , // Indicate if a full burst needs to be divided for multiple runs.
  input  logic                  [7:0]                      i_axi_cnt_per_run   , // How many 512-bit axi transfer is needed for the current run.

  // AXI4 master interface (read only)
  output logic                                             m_axi_arvalid       ,
  input  logic                                             m_axi_arready       ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]                    m_axi_araddr        ,
  output logic [1:0]                                       m_axi_arburst       ,
  output logic [7:0]                                       m_axi_arlen         ,
  output logic [2:0]                                       m_axi_arsize        ,
  output logic [C_ID_WIDTH-1:0]                            m_axi_arid          ,

  input  logic                                             m_axi_rvalid        ,
  output logic                                             m_axi_rready        ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]                    m_axi_rdata         ,
  input  logic                                             m_axi_rlast         ,
  input  logic [C_ID_WIDTH - 1:0]                          m_axi_rid           ,
  input  logic [1:0]                                       m_axi_rresp         ,

  // AXI4-Stream master interface
  output logic [C_NUM_NODES-1:0]                           m_axis_tvalid       ,
  input  logic [C_NUM_NODES-1:0]                           m_axis_tready       ,
  output logic [C_NUM_NODES-1:0][C_M_AXI_DATA_WIDTH-1:0]   m_axis_tdata        ,
  output logic [C_NUM_NODES-1:0]                           m_axis_tlast  
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

// functions
function integer f_max (
  input integer a,
  input integer b
);
  f_max = (a > b) ? a : b;
endfunction

function integer f_min (
  input integer a,
  input integer b
);
  f_min = (a < b) ? a : b;
endfunction

// AXI Parameters
localparam integer LP_DW_BYTES                   = C_M_AXI_DATA_WIDTH/8                                       ;
localparam integer LP_LOG_DW_BYTES               = $clog2(LP_DW_BYTES)                                        ;
localparam integer LP_MAX_BURST_LENGTH           = 256                                                        ; // Max AXI Protocol burst length
localparam integer LP_MAX_BURST_BYTES            = C_BURST_SIZE_BYTES                                         ; // How many bytes per AXI burst
localparam integer LP_AXI_BURST_LEN              = f_min(LP_MAX_BURST_BYTES/LP_DW_BYTES, LP_MAX_BURST_LENGTH) ;
localparam integer LP_LOG_BURST_LEN              = $clog2(LP_AXI_BURST_LEN)                                   ;
localparam integer LP_OUTSTANDING_CNTR_WIDTH     = $clog2(C_MAX_OUTSTANDING+1)                                ;
localparam integer LP_TOTAL_LEN_WIDTH            = C_XFER_SIZE_WIDTH-LP_LOG_DW_BYTES                          ;
localparam integer LP_TRANSACTION_CNTR_WIDTH     = LP_TOTAL_LEN_WIDTH-LP_LOG_BURST_LEN                        ;
localparam [C_M_AXI_ADDR_WIDTH-1:0] LP_ADDR_MASK = LP_DW_BYTES*LP_AXI_BURST_LEN - 1                           ;
// FIFO Parameters
localparam integer LP_FIFO_DEPTH                 = 2**($clog2(LP_AXI_BURST_LEN*C_MAX_OUTSTANDING))            ; // Ensure power of 2
localparam integer LP_FIFO_READ_LATENCY          = 2                                                          ;
localparam integer LP_FIFO_COUNT_WIDTH           = $clog2(LP_FIFO_DEPTH)+1                                    ;
// Presorter parameters
localparam integer LP_LOG_INIT_SORTED_CHUNK      = C_INIT_SORTED_CHUNK == 1 ? 1 : $clog2(C_INIT_SORTED_CHUNK)   ;
localparam integer LP_PRESORTER_PIPE_DEPTH       = LP_LOG_INIT_SORTED_CHUNK * (LP_LOG_INIT_SORTED_CHUNK + 1) / 2;

// Variables
// Control logic
logic                                                      start_pipe                 ;
logic                                                      pass_start_pipe            ;

logic [C_NUM_NODES-1:0][C_M_AXI_ADDR_WIDTH-1:0]            addr_offset_r              ; // Start address for each node
logic [LP_TOTAL_LEN_WIDTH-1:0]                             total_len_r                ; // Read length in terms of AXI interface data width for each node
logic                                                      has_partial_bursts         ; // Asserted if has partial burst
logic [LP_TRANSACTION_CNTR_WIDTH-1:0]                      num_transactions           ;
logic [LP_LOG_BURST_LEN-1:0]                               final_burst_len            ; 
logic                                                      single_transaction         ; // Asserted if only single transaction

logic [C_NUM_NODES-1:0]                                    ar_idle = '1               ;
logic [C_NUM_NODES-1:0]                                    ar_done_i = '0             ; // AXI AR channel read done for each node
logic                                                      ar_done                    ;

logic [C_NUM_NODES-1:0]                                    r_done_i = '0              ; // AXI R channel read done for each node

// AXI AR Channel
logic                                                      arxfer_general             ;
logic [C_NUM_NODES-1:0]                                    arxfer = '0                ;
logic [C_NUM_NODES-1:0]                                    arvalid_r = '0             ;
logic [C_NUM_NODES-1:0][C_M_AXI_ADDR_WIDTH-1:0]            araddr                     ;
logic [C_ID_WIDTH-1:0]                                     arid = '1                  ;
logic [C_NUM_NODES-1:0][LP_TRANSACTION_CNTR_WIDTH-1:0]     ar_transactions_to_go      ;
logic [C_NUM_NODES-1:0]                                    ar_final_transaction       ;
logic [C_NUM_NODES-1:0]                                    incr_ar_to_r_cnt           ;
logic [C_NUM_NODES-1:0]                                    decr_ar_to_r_cnt           ;
logic [C_NUM_NODES-1:0]                                    stall_ar                   ;
logic [C_NUM_NODES-1:0]                                    stall_ar_d = '0            ;
logic [C_NUM_NODES-1:0][LP_OUTSTANDING_CNTR_WIDTH-1:0]     outstanding_vacancy_count  ;

// AXI R Channel
logic                                                      rxfer                      ;
logic [C_NUM_NODES-1:0]                                    r_completed                ;
logic [C_NUM_NODES-1:0]                                    decr_r_transaction_cntr    ;
logic [C_NUM_NODES-1:0][LP_TRANSACTION_CNTR_WIDTH-1:0]     r_transactions_to_go       ;
logic [C_NUM_NODES-1:0]                                    r_final_transaction        ;

// fifo 
logic [C_NUM_NODES-1:0][LP_LOG_BURST_LEN-1:0]              tcnt = '0                  ; // To be added here

logic [C_NUM_NODES-1:0]                                    tvalid                     ;
logic [C_NUM_NODES-1:0][C_M_AXI_DATA_WIDTH-1:0]            tdata                      ;
logic [C_NUM_NODES-1:0]                                    tlast                      ;
logic [C_NUM_NODES-1:0][C_M_AXI_DATA_WIDTH:0]              fifo_din                   ;
logic [C_NUM_NODES-1:0]                                    fifo_empty                 ; // Not used
logic [C_NUM_NODES-1:0]                                    fifo_full                  ; // Not used
logic [C_NUM_NODES-1:0][C_M_AXI_DATA_WIDTH:0]              fifo_dout                  ;
logic [C_NUM_NODES-1:0][C_M_AXI_DATA_WIDTH-1:0]            tdata_fifo_out             ;
logic [C_NUM_NODES-1:0]                                    tlast_fifo_out             ;

// presorted data
logic [C_M_AXI_DATA_WIDTH-1:0]                             m_axi_rdata_sort           ;
logic                                                      m_axi_rvalid_sort          ;
logic                                                      rxfer_sort                 ;
logic                                                      m_axi_rlast_sort           ;
logic [C_ID_WIDTH - 1:0]                                   m_axi_rid_sort             ;
logic [C_NUM_NODES-1:0]                                    r_final_transaction_sort   ;

// multiple run info
logic [C_NUM_NODES-1:0][7:0]                               axi_cnt_per_run            ;
logic [C_NUM_NODES-1:0]                                    run_last                   ;
logic [C_NUM_NODES-1:0]                                    run_last_sort              ;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

delay_chain #(
    .WIDTH      ( 1                 ), 
    .STAGES     ( 1                 )
) 
u_start(
   .clk         ( aclk              ),
   .in_bus      ( i_start           ),
   .out_bus     ( start_pipe        )
);

delay_chain #(
    .WIDTH      ( 1                 ), 
    .STAGES     ( 2                 )
) 
u_pass_start(
   .clk         ( aclk              ),
   .in_bus      ( i_pass_start      ),
   .out_bus     ( pass_start_pipe   )
);

// Store the address and transfer size after some pre-processing.
always_ff @(posedge aclk) begin: convert_input
  if (i_start) begin
    // Round transfer size up to integer value of the axi interface data width. Convert to axi_arlen format which is length -1.
    total_len_r <= i_xfer_size_in_bytes[0+:LP_LOG_DW_BYTES] > 0
                      ? i_xfer_size_in_bytes[LP_LOG_DW_BYTES+:LP_TOTAL_LEN_WIDTH]
                      : i_xfer_size_in_bytes[LP_LOG_DW_BYTES+:LP_TOTAL_LEN_WIDTH] - 1'b1;
    for (int i = 0; i < C_NUM_NODES; i++) begin
      addr_offset_r[i] <= i_addr_offset[i];
    end
  end
end: convert_input

// Determine how many full burst to issue and if there are any partial bursts.
assign num_transactions = total_len_r[LP_LOG_BURST_LEN+:LP_TRANSACTION_CNTR_WIDTH];
assign has_partial_bursts = total_len_r[0+:LP_LOG_BURST_LEN] == {LP_LOG_BURST_LEN{1'b1}} ? 1'b0 : 1'b1;

always_ff @(posedge aclk) begin
  final_burst_len <=  total_len_r[0+:LP_LOG_BURST_LEN];
end

// Special case if there is only 1 AXI transaction.
assign single_transaction = (num_transactions == {LP_TRANSACTION_CNTR_WIDTH{1'b0}}) ? 1'b1 : 1'b0;

// AXI AR Channel
always_comb begin
  arxfer_general = m_axi_arvalid & m_axi_arready;
  for (int i = 0; i < C_NUM_NODES; i++)
    arxfer[i] = arxfer_general & (arid == i);
end

always_ff @(posedge aclk) begin
  for (int i = 0; i < C_NUM_NODES; i++) begin
    arvalid_r[i] <= ~ar_idle[i] & ~stall_ar[i] & ~arvalid_r[i]  ? 1'b1 :
                    m_axi_arready                               ? 1'b0 : 
                                                                  arvalid_r[i];
  end
end

// When ar_idle, there are no transactions to issue.
always_ff @(posedge aclk) begin
  for (int i = 0; i < C_NUM_NODES; i++) begin
    ar_idle[i] <= start_pipe   ?  1'b0 :
                  ar_done_i[i] ?  1'b1 :
                                  ar_idle[i]  ;
  end
end

// delay stall_ar for 1 cycle to match arvalid_r
always_ff @(posedge aclk) begin
  for (int i = 0; i < C_NUM_NODES; i++)
    stall_ar_d[i] <= stall_ar[i];
end

// each node is assigned a different id. The transactions are interleaved.
always_ff @(posedge aclk) begin
  if (start_pipe)
    arid <= '1;
  else
    arid <= (arxfer_general | (~m_axi_arvalid & m_axi_arready & stall_ar_d[arid]) | ar_done_i[arid])  ? arid - 1'b1 : 
                                                                                                        arid;
end

// Increment to next address after each transaction is issued.
// WK: this can be replaced by DSPs.
always_ff @(posedge aclk) begin: foreach_araddr
  for (int i = 0; i < C_NUM_NODES; i++)
    araddr[i] <=  start_pipe  ? addr_offset_r[i] :
                  arxfer[i]   ? araddr[i] + LP_AXI_BURST_LEN*LP_DW_BYTES :
                                araddr[i];
end: foreach_araddr

// Counts down the number of transactions to send.
genvar k;
generate 
  for(k = 0; k < C_NUM_NODES; k++) begin: ar_transaction_cntr 
    axi_transaction_counter #(
      .C_WIDTH    ( LP_TRANSACTION_CNTR_WIDTH         ) ,
      .C_INIT     ( {LP_TRANSACTION_CNTR_WIDTH{1'b0}} )
    )
    u_ar_transaction_cntr (
      .clk        ( aclk                              ) ,
      .load       ( start_pipe                        ) ,
      .incr       ( 1'b0                              ) ,
      .decr       ( arxfer[k]                         ) ,
      .load_value ( num_transactions                  ) ,
      .count      ( ar_transactions_to_go[k]          ) ,
      .is_zero    ( ar_final_transaction[k]           )
    );
  end: ar_transaction_cntr
endgenerate

always_ff @(posedge aclk) begin
  for (int i = 0; i < C_NUM_NODES; i++)
    ar_done_i[i] <= ar_final_transaction[i] & arxfer[i] ? 1'b1 :
                                                ar_done ? 1'b0 : 
                                                          ar_done_i[i];
end

assign ar_done = &ar_done_i;

assign r_completed = incr_ar_to_r_cnt;

always_ff @(posedge aclk) begin
  for (int i = 0; i < C_NUM_NODES; i++) begin
    if (start_pipe & pass_start_pipe)
      tcnt[i] <= {LP_LOG_BURST_LEN{1'b0}};
    else if (m_axis_tvalid[i] & m_axis_tready[i])
        tcnt[i] <= tcnt[i] + 1;
  end
end

always_comb begin 
  for (int i = 0; i < C_NUM_NODES; i++) begin : foreach_ar_to_r
    incr_ar_to_r_cnt[i] = m_axis_tvalid[i] & m_axis_tready[i] & (tcnt[i] == (LP_AXI_BURST_LEN-1));
    decr_ar_to_r_cnt[i] = arxfer[i];
  end: foreach_ar_to_r
end

// Keeps track of the number of outstanding transactions. Stalls
// when the value is reached so that the FIFO won't overflow.
// If no FIFO present, then just limit at max outstanding transactions.
axi_transaction_counter #(
  .C_WIDTH ( LP_OUTSTANDING_CNTR_WIDTH                       ) ,
  .C_INIT  ( C_MAX_OUTSTANDING[0+:LP_OUTSTANDING_CNTR_WIDTH] )
)
inst_ar_to_r_transaction_cntr[C_NUM_NODES-1:0] (
  .clk        ( aclk                              ) ,
  .load       ( 1'b0                              ) ,
  .incr       ( incr_ar_to_r_cnt                  ) ,
  .decr       ( decr_ar_to_r_cnt                  ) ,
  .load_value ( {LP_OUTSTANDING_CNTR_WIDTH{1'b0}} ) ,
  .count      ( outstanding_vacancy_count         ) ,
  .is_zero    ( stall_ar                          )
);


///////////////////////////////////////////////////////////////////////////////
// AXI Read Channel
///////////////////////////////////////////////////////////////////////////////
genvar chan_num;
generate
for (chan_num = 0; chan_num < C_NUM_NODES; chan_num++) begin: gen_fifo
  if (chan_num < C_NUM_BRAM_NODES) begin: gen_fifo_bram
    // xpm_fifo_sync: Synchronous FIFO
    // Xilinx Parameterized Macro, Version 2017.4
    xpm_fifo_sync # (
      .FIFO_MEMORY_TYPE    ( "block"              ) , // string; "auto", "block", "distributed", or "ultra";
      .ECC_MODE            ( "no_ecc"             ) , // string; "no_ecc" or "en_ecc";
      .FIFO_WRITE_DEPTH    ( LP_FIFO_DEPTH        ) , // positive integer
      .WRITE_DATA_WIDTH    ( C_M_AXI_DATA_WIDTH+1 ) , // positive integer
      .WR_DATA_COUNT_WIDTH ( LP_FIFO_COUNT_WIDTH  ) , // positive integer, not used
      .PROG_FULL_THRESH    ( 10                   ) , // positive integer, not used
      .FULL_RESET_VALUE    ( 1                    ) , // positive integer; 0 or 1
      .USE_ADV_FEATURES    ( "1F1F"               ) , // string; "0000" to "1F1F";
      .READ_MODE           ( "fwft"               ) , // string; "std" or "fwft";
      .FIFO_READ_LATENCY   ( LP_FIFO_READ_LATENCY ) , // positive integer;
      .READ_DATA_WIDTH     ( C_M_AXI_DATA_WIDTH+1 ) , // positive integer
      .RD_DATA_COUNT_WIDTH ( LP_FIFO_COUNT_WIDTH  ) , // positive integer, not used
      .PROG_EMPTY_THRESH   ( 10                   ) , // positive integer, not used
      .DOUT_RESET_VALUE    ( "0"                  ) , // string, don't care
      .WAKEUP_TIME         ( 0                    ) // positive integer; 0 or 2;
    )
    inst_rd_xpm_fifo_sync (
      .sleep         ( 1'b0                        ) ,
      .rst           ( 1'b0                        ) ,
      .wr_clk        ( aclk                        ) ,
      .wr_en         ( tvalid[chan_num]            ) ,
      .din           ( fifo_din[chan_num]          ) ,
      .full          ( fifo_full[chan_num]         ) ,
      .overflow      (                             ) ,
      .prog_full     (                             ) ,
      .wr_data_count (                             ) ,
      .almost_full   (                             ) ,
      .wr_ack        (                             ) ,
      .wr_rst_busy   (                             ) ,
      .rd_en         ( m_axis_tready[chan_num]     ) ,
      .dout          ( fifo_dout[chan_num]         ) ,
      .empty         ( fifo_empty[chan_num]        ) ,
      .prog_empty    (                             ) ,
      .rd_data_count (                             ) ,
      .almost_empty  (                             ) ,
      .data_valid    ( m_axis_tvalid[chan_num]     ) ,
      .underflow     (                             ) ,
      .rd_rst_busy   (                             ) ,
      .injectsbiterr ( 1'b0                        ) ,
      .injectdbiterr ( 1'b0                        ) ,
      .sbiterr       (                             ) ,
      .dbiterr       (                             )
    ) ;
  end: gen_fifo_bram
  else begin: gen_fifo_lutran
    hls_fifo # (
      .MEM_STYLE      ( "shiftreg"                  ),
      .DATA_WIDTH     ( C_M_AXI_DATA_WIDTH+1        ),
      .ADDR_WIDTH     ( LP_FIFO_COUNT_WIDTH         ),
      .DEPTH          ( LP_FIFO_DEPTH               )
    )
    u_rd_fifo (
      .clk            ( aclk                        ),
      .if_empty_n     ( m_axis_tvalid[chan_num]     ),
      .if_read_ce     ( 1'b1                        ),
      .if_read        ( m_axis_tready[chan_num]     ),
      .if_dout        ( fifo_dout[chan_num]         ),
      .if_full_n      ( /* Unused */                ),
      .if_write_ce    ( 1'b1                        ),
      .if_write       ( tvalid[chan_num]            ),
      .if_din         ( fifo_din[chan_num]          )
    );
  end: gen_fifo_lutran
end
endgenerate
  
always_comb begin 
    for (int i = 0; i < C_NUM_NODES; i++) begin
      fifo_din[i] = {tlast[i], tdata[i]}; 
      tlast_fifo_out[i] = fifo_dout[i][C_M_AXI_DATA_WIDTH];
      tdata_fifo_out[i] = fifo_dout[i][C_M_AXI_DATA_WIDTH-1:0];
    end
end
  
assign m_axis_tdata = tdata_fifo_out;
assign m_axis_tlast = tlast_fifo_out;

assign m_axi_rready = 1'b1;


always_comb begin 
  for (int i = 0; i < C_NUM_NODES; i++) begin
    tvalid[i] = m_axi_rvalid_sort && (m_axi_rid_sort == i); 
    tdata[i] = m_axi_rdata_sort;
    tlast[i] = rxfer_sort && (m_axi_rid_sort == i) && ((m_axi_rlast_sort && r_final_transaction_sort[i]) || run_last_sort[i]);
  end
end

presorter #(
    .AXI_DATA_WIDTH     ( C_M_AXI_DATA_WIDTH  ) ,
    .DATA_WIDTH         ( C_RECORD_BIT_WIDTH  ) ,
    .KEY_WIDTH          ( C_RECORD_KEY_WIDTH  ) ,
    .INIT_SORTED_CHUNK  ( C_INIT_SORTED_CHUNK )  
)
u_presorter(
    .aclk               ( aclk                ),  
    .in_data            ( m_axi_rdata         ),
    .out_data           ( m_axi_rdata_sort    )
);

delay_chain #(.WIDTH(1), .STAGES(LP_PRESORTER_PIPE_DEPTH)) rvalid_delay_inst(.clk(aclk),.in_bus(m_axi_rvalid),.out_bus(m_axi_rvalid_sort));
delay_chain #(.WIDTH(C_ID_WIDTH), .STAGES(LP_PRESORTER_PIPE_DEPTH)) rid_delay_inst(.clk(aclk),.in_bus(m_axi_rid),.out_bus(m_axi_rid_sort));
delay_chain #(.WIDTH(1), .STAGES(LP_PRESORTER_PIPE_DEPTH)) rxfer_delay_inst(.clk(aclk),.in_bus(rxfer),.out_bus(rxfer_sort));
delay_chain #(.WIDTH(1), .STAGES(LP_PRESORTER_PIPE_DEPTH)) rlast_delay_inst(.clk(aclk),.in_bus(m_axi_rlast),.out_bus(m_axi_rlast_sort));
delay_chain #(.WIDTH(C_NUM_NODES), .STAGES(LP_PRESORTER_PIPE_DEPTH)) r_final_transaction_delay_inst(.clk(aclk),.in_bus(r_final_transaction),.out_bus(r_final_transaction_sort));
delay_chain #(.WIDTH(C_NUM_NODES), .STAGES(LP_PRESORTER_PIPE_DEPTH)) run_last_delay_inst(.clk(aclk),.in_bus(run_last),.out_bus(run_last_sort));

assign rxfer = m_axi_rready & m_axi_rvalid;

always_comb begin
  for (int i = 0; i < C_NUM_NODES; i++) begin
    decr_r_transaction_cntr[i] = rxfer & m_axi_rlast & (m_axi_rid == i);
  end
end

always @(posedge aclk) begin
  for (int i = 0; i < C_NUM_NODES; i++) begin
    if (i_start) begin
      axi_cnt_per_run[i] <= 1;
    end
    else if ((axi_cnt_per_run[i] == i_axi_cnt_per_run) & rxfer & (m_axi_rid == i)) begin
      axi_cnt_per_run[i] <= 1;
    end
    else if (rxfer & (m_axi_rid == i)) begin
      axi_cnt_per_run[i] <= axi_cnt_per_run[i] + 1;
    end
    else begin
      axi_cnt_per_run[i] <= axi_cnt_per_run[i];
    end
  end
end

always_comb begin
  for (int i = 0; i < C_NUM_NODES; i++) begin
    run_last[i] = (axi_cnt_per_run[i] == i_axi_cnt_per_run) & i_read_divide;
  end
end

axi_transaction_counter #(
  .C_WIDTH ( LP_TRANSACTION_CNTR_WIDTH         ) ,
  .C_INIT  ( {LP_TRANSACTION_CNTR_WIDTH{1'b0}} )
)
inst_r_transaction_cntr[C_NUM_NODES-1:0] (
  .clk        ( aclk                          ) ,
  .load       ( start_pipe                    ) ,
  .incr       ( 1'b0                          ) ,
  .decr       ( decr_r_transaction_cntr       ) ,
  .load_value ( num_transactions              ) ,
  .count      ( r_transactions_to_go          ) ,
  .is_zero    ( r_final_transaction           )
);

// Control Logic
always_ff @(posedge aclk) begin
  for (int i = 0; i < C_NUM_NODES; i++) begin
    r_done_i[i] <= rxfer & m_axi_rlast & (m_axi_rid == i) & r_final_transaction[i] ?  1'b1 : 
                                                                            o_done ?  1'b0 : 
                                                                                      r_done_i[i];
  end
end

always_comb begin : gen_output
  m_axi_arburst   = 2'b01;
  m_axi_arvalid   = arvalid_r[arid];
  m_axi_araddr    = araddr[arid];
  m_axi_arlen     = ar_final_transaction[arid] || (start_pipe & single_transaction) ? final_burst_len : LP_AXI_BURST_LEN - 1;
  m_axi_arsize    = $clog2(LP_DW_BYTES);
  m_axi_arid      = arid;

  o_done          = &r_done_i;
end: gen_output


endmodule : axi_read_master

