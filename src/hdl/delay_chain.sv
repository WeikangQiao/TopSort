module delay_chain #(
    parameter WIDTH=8, 
    parameter STAGES=1
) 
(
   input logic                 clk,

   input logic [WIDTH-1:0]     in_bus,

   output logic [WIDTH-1:0]    out_bus
);

//Note the shreg_extract=no directs Xilinx to not infer shift registers which
// defeats using this as a pipeline

   (* dont_touch = "yes" *) logic [WIDTH-1:0] pipe[STAGES-1:0];
   
   genvar i;
   for (i = 0; i < STAGES; i = i + 1) begin : inst
      if (i==0 ) begin: pipe_0
         simple_reg #(
            .WIDTH   ( WIDTH  )
         ) 
         u_pipe_0(
            .clk     ( clk    ),
            .in_bus  ( in_bus ),
            .out_bus ( pipe[0])
         );
      end: pipe_0
      else begin: pipe_multi
         simple_reg #(
            .WIDTH   ( WIDTH  )
         ) 
         u_pipe(
            .clk     ( clk       ),
            .in_bus  ( pipe[i-1] ),
            .out_bus ( pipe[i]   )
         );
      end: pipe_multi
   end

   assign out_bus = pipe[STAGES-1];

endmodule
