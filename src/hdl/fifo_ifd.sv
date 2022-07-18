interface fifo_if_t #
(
    parameter   integer     DATA_WIDTH    =   512 
);

    logic                                    data_vld   ;
    logic                                    read       ;
    logic [DATA_WIDTH-1:0]                   data       ;

    modport     slave ( input   data_vld, data, 
                        output  read
                    );

    modport     master ( output  data_vld, data,
                         input   read
                    );

endinterface