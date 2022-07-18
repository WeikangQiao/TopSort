module simple_reg #(
    parameter WIDTH=8
) 
(
   input logic                 clk,

   input logic [WIDTH-1:0]     in_bus,

   (* dont_touch = "yes" *) output logic [WIDTH-1:0]    out_bus
);

initial begin
    out_bus = 0;
end

always @(posedge clk)
begin
    out_bus <=  in_bus;
end


endmodule