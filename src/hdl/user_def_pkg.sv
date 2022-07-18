package user_def_pkg;

    // The following parameters specify AXI Lite interface
    parameter integer C_S_AXI_CONTROL_ADDR_WIDTH    =   9   ;
    parameter integer C_S_AXI_CONTROL_DATA_WIDTH    =   32  ;

    // AXI Lite Pipeline stages
    parameter integer C_AXI_LITE_PIPE_NO            =   2   ;

    // The following parameters specify AXI 4 interface
    parameter integer C_M_AXI_ID_WIDTH              =   4   ; 
    parameter integer C_M_AXI_ADDR_WIDTH            =   64  ;
    parameter integer C_M_AXI_DATA_WIDTH            =   512 ;

    // Problem size & record width
    parameter integer C_XFER_SIZE_WIDTH             =   32  ;
    parameter integer C_RECORD_BIT_WIDTH            =   64  ;
    parameter integer C_RECORD_KEY_WIDTH            =   32  ;

    // Merge tree configuration
    parameter integer C_INIT_SORTED_CHUNK           =   2   ;
    parameter integer C_ROOT_BUNDLE_WIDTH           =   8   ;
    parameter integer C_NUM_LEAVES                  =   16  ; 
    parameter integer ROOT_BUNDLE_WIDTH             =   C_ROOT_BUNDLE_WIDTH ;

    // AXI read burst size: 
    // (1) 1 KB is enough for DRAM
    // (2) 1 & 4 KB for the phases in TOPSort
    parameter integer C_AXI_READ_BURST_BYTES_TYPE1  =   1024;
    parameter integer C_AXI_READ_BURST_BYTES_TYPE2  =   4096;

    // Number of leaf buffers that are implemeneted using BRAM
    parameter integer C_NUM_BRAM_NODES              =   4   ;

    // Pipeline stages for tree leaves, currently split leaves into two parts to allow for
    // leaf distribution accross multi dies
    parameter integer C_LEAF_PART_1_NO              =   8   ;
    parameter integer C_LEAF_PART_1_PIPE_NO         =   1   ;
    parameter integer C_LEAF_PART_2_NO              =   C_NUM_LEAVES -  C_LEAF_PART_1_NO;
    parameter integer C_LEAF_PART_2_PIPE_NO         =   2   ;

    // Batch granularity, used for TOPSort only
    parameter integer C_GRAIN_IN_BYTES              =   4096;   
endpackage
