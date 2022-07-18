#include "xcl2.hpp"
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <cmath>
#include <vector>

//#define WRITEOUTPUT

#define TREE_COUNT 16
#define LOG_LEAF_COUNT 4
#define BANK_OFFSET 0
#define RECORD_IN_BYTES 8
#define INIT_SORTED_CHUNK 2
#define SORTED_CHUN_POST_P1 4
#define COARSE_BATCH_SIZE 4096

// Number of HBM PCs required
#define MAX_HBM_PC_COUNT 32
#define PC_NAME(n) n | XCL_MEM_TOPOLOGY
const int pc[MAX_HBM_PC_COUNT] = {
    PC_NAME(0),  PC_NAME(1),  PC_NAME(2),  PC_NAME(3),  PC_NAME(4),  PC_NAME(5),  PC_NAME(6),  PC_NAME(7),
    PC_NAME(8),  PC_NAME(9),  PC_NAME(10), PC_NAME(11), PC_NAME(12), PC_NAME(13), PC_NAME(14), PC_NAME(15),
    PC_NAME(16), PC_NAME(17), PC_NAME(18), PC_NAME(19), PC_NAME(20), PC_NAME(21), PC_NAME(22), PC_NAME(23),
    PC_NAME(24), PC_NAME(25), PC_NAME(26), PC_NAME(27), PC_NAME(28), PC_NAME(29), PC_NAME(30), PC_NAME(31)};

int main(int argc, char** argv)
{
    if (argc != 4) {
        std::cout << "Usage: " << argv[0] << " <XCLBIN File> + filepath + #num_element per channel in power of 2" << std::endl;
        return EXIT_FAILURE;
    }

    std::string binaryFile = argv[1];
    std::string inFile = argv[2];
    std::string pow_specified = argv[3];

    uint64_t i, j, k, l;

    // Timer
    struct timeval startTime, stopTime;
    double exec_time;
    double exec_bandwidth;
    double krnl_exec_time;
    double krnl_exec_bandwidth;
    uint64_t krnl_start, krnl_end;

    // Get the problem size
    uint64_t pow_num = std::stoul(pow_specified);
    const uint64_t elem_per_chan = ((uint64_t)1 << pow_num);
    const uint64_t elem_cnt = elem_per_chan * TREE_COUNT;
    auto char_per_line = (2 * RECORD_IN_BYTES + 1);
    const uint64_t char_cnt = char_per_line * elem_cnt - 1; // each record ends with '\n'
    

    // Calculate number of passes for each channel
    uint8_t num_pass = (uint8_t) std::ceil(std::log2(elem_per_chan / SORTED_CHUN_POST_P1 / INIT_SORTED_CHUNK) / LOG_LEAF_COUNT);
    std::cout << "Number of pass is " << static_cast<uint16_t>(num_pass) << std::endl;

    // Allocate Memory in Host Memory
    std::vector<uint64_t,aligned_allocator<uint64_t>> h_input(elem_cnt);
    std::vector<uint64_t,aligned_allocator<uint64_t>> h_output(elem_cnt);
    
    // Read input
    FILE *readFile;
    readFile = fopen(inFile.c_str(), "r");     
    unsigned char *charBuffer;
    charBuffer = (unsigned char *)malloc(char_cnt * sizeof(unsigned char));
    fread(charBuffer, 1, char_cnt, readFile);
    for (i = 0; i < elem_cnt; i++) {
        h_input[i] = 0;
        for (j = 0; j < 2*RECORD_IN_BYTES; j++) { // process per line
            h_input[i] = (h_input[i] << 4) + (charBuffer[char_per_line*i+j] > '9' ? (charBuffer[char_per_line*i+j]-87) : (charBuffer[char_per_line*i+j]-'0'));
        }
    }
    free(charBuffer);   
    fclose(readFile);
    // Fill output buffer with pattern 0
    for(i = 0; i < elem_cnt; i++) {
        h_output[i] = 0; 
    }
    
//OPENCL HOST CODE AREA START

    cl_int err;
    std::vector<cl::Device> devices = xcl::get_xil_devices();
    cl::Device device = devices[1];

    OCL_CHECK(err, cl::Context context({device}, NULL, NULL, NULL, &err));
    OCL_CHECK(err, cl::CommandQueue q(context, {device}, CL_QUEUE_PROFILING_ENABLE, &err));
    OCL_CHECK(err, std::string device_name = device.getInfo<CL_DEVICE_NAME>(&err));

    cl::Event krnlEvent;

    //Create Program and Kernel
    auto fileBuf = xcl::read_binary_file(binaryFile);
    cl::Program::Binaries bins{{fileBuf.data(), fileBuf.size()}};
    devices.resize(1);
    OCL_CHECK(err, cl::Program program(context, {device}, bins, NULL, &err));
    OCL_CHECK(err, cl::Kernel krnl_sorter(program,"merge_sort_complete", &err));


    // Allocate Buffer in Global Memory
    std::vector<cl::Buffer> buffer_0(TREE_COUNT);
    std::vector<cl::Buffer> buffer_1(TREE_COUNT);
    uint64_t byte_per_chan = elem_per_chan * RECORD_IN_BYTES;
    std::cout << "Bytes per channel is " << byte_per_chan << '\n';

    cl_mem_ext_ptr_t inBufExt[TREE_COUNT];
    cl_mem_ext_ptr_t outBufExt[TREE_COUNT];
    for (i = 0; i < TREE_COUNT; i++) {
        inBufExt[i].obj = h_input.data() + elem_per_chan * i;
        inBufExt[i].param = 0;
        inBufExt[i].flags = ( BANK_OFFSET + (2*i) ) | XCL_MEM_TOPOLOGY;

        outBufExt[i].obj = h_output.data() + elem_per_chan * i;
        outBufExt[i].param = 0;
        outBufExt[i].flags = ( BANK_OFFSET + (2*i+1) ) | XCL_MEM_TOPOLOGY;
    }
    for (i = 0; i < TREE_COUNT; i++) {
        OCL_CHECK(err, buffer_0[i] = cl::Buffer(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,
                byte_per_chan, &inBufExt[i], &err));
        OCL_CHECK(err, buffer_1[i] = cl::Buffer(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,
                byte_per_chan, &outBufExt[i], &err));
    }
    
    // Set the Kernel Arguments
    int nargs=0;
    OCL_CHECK(err, err = krnl_sorter.setArg(nargs++, byte_per_chan));
    OCL_CHECK(err, err = krnl_sorter.setArg(nargs++, num_pass));
    for (i = 0; i < TREE_COUNT; i++) {
        OCL_CHECK(err, err = krnl_sorter.setArg(nargs++, buffer_0[i]));
        OCL_CHECK(err, err = krnl_sorter.setArg(nargs++, buffer_1[i]));
    }


    // Start execution
    gettimeofday(&startTime, NULL);
    //Copy input data from to device global memory
    for (i = 0; i < TREE_COUNT; i++) {
        OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_0[i]},0/* 0 means from host*/));
    }
    OCL_CHECK(err, err = q.finish());
    std::cout << "Copy data from host to FPGA is done!" << std::endl;
    
#ifdef CHECK_INPUT
    FILE *checkFile = fopen("checkFile.txt", "w");

    // clear the input buffers
    for(i = 0; i < total_words; i++) {
        h_input[i] = 0;
    }

    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer00},CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q.finish());

    // write the input buffers to files
    //for(i = 0; i < total_words + actual_offset; i++) {
    for(i = 0; i < total_words; i++) {
        fprintf(checkFile, "%08x\n", h_input[i]);
    }

    fclose(checkFile);
#endif

    //Launch the Kernel
    OCL_CHECK(err, err = q.enqueueTask(krnl_sorter, NULL, &krnlEvent));
    clWaitForEvents(1, (const cl_event*) &krnlEvent);
    std::cout << "Kernel execution is done!" << std::endl;

    //Copy Result from Device Global Memory to Host Local Memory
    if (num_pass % 2 == 1)
    {
        for (i = 0; i < TREE_COUNT; i++) {
            OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_0[i]}, CL_MIGRATE_MEM_OBJECT_HOST));
        }
    }
    else
    {
        for (i = 0; i < TREE_COUNT; i++) {
            OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_1[i]}, CL_MIGRATE_MEM_OBJECT_HOST));
        }
    }
    OCL_CHECK(err, err = q.finish());
    
    std::cout << "Copy data from FPGA to host is done!" << std::endl;

    gettimeofday(&stopTime, NULL);

    krnlEvent.getProfilingInfo(CL_PROFILING_COMMAND_START, &krnl_start);
    krnlEvent.getProfilingInfo(CL_PROFILING_COMMAND_END, &krnl_end);
//OPENCL HOST CODE AREA END

    std::cout << "Kernel execution stopped here" << std::endl;

#ifdef WRITEOUTPUT
    std::string outFile = "hw_output_1^" + pow_specified + ".txt";
    FILE *hardFile = fopen(outFile.c_str(), "w");
    // store the hardware sorted input data into text file
    if (num_pass % 2 == 1)
    {
    	for(i = 0; i < (total_words); i++) {
            fprintf(hardFile, "%08x\n", h_output[i]);
    	}
    }
    else
    {
	for(i = 0; i < (total_words); i++) {
	    fprintf(hardFile, "%08x\n", h_input[i]);
        }
    }
    fclose(hardFile);
#endif 


    // Debug
#ifdef DEBUG
    FILE *debugOutFile = fopen("readOutFile.txt", "w");

    // clear the input buffers
    for(i = 0; i < total_input_words; i++) {
        h_input[i] = 0;
    }

    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer00},CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q.finish());

    // write the input buffers to files
    for(i = 0; i < total_words; i++) {
    	fprintf(debugOutFile, "%08x\n", h_input[i]);
    }

    fclose(debugOutFile);

#endif

    // Check Results
    int check_status = 0;
    uint64_t elem_per_batch = COARSE_BATCH_SIZE / RECORD_IN_BYTES;
    uint64_t batch_per_chan = elem_per_chan / elem_per_batch;
    if (num_pass % 2 == 1)
    {
        // each group has 4 channels
        for (i = 0; i < 4; i++) {
            for (j = 0; j < batch_per_chan; j++) {
                // there are 4 axi groups
                for (k = 0; k < 4; k++) {
                    for (l = 0; l < elem_per_batch; l++){
                        uint64_t index = elem_per_batch * batch_per_chan * (4 * k + i) + j * elem_per_batch + l;
                        uint64_t data_expect = elem_per_batch * (i * batch_per_chan * 4 + j * 4 + k) + l;
                        if ((h_input[index] & 0x00000000ffffffff) != data_expect) {
                            std::cout << data_expect << "th element " << h_input[index] << " is not matched, , i: " << i << " j: " << j <<  " k: " << k << " l: " << l << std::endl;
                            check_status = 1;
                            goto PRINT_RESULT;
                        }
                    }
                }
            }
        }
    } else {
        // each group has 4 channels
        for (i = 0; i < 4; i++) {
            for (j = 0; j < batch_per_chan; j++) {
                // there are 4 axi groups
                for (k = 0; k < 4; k++) {
                    for (l = 0; l < elem_per_batch; l++){
                        uint64_t index = elem_per_batch * batch_per_chan * (4 * k + i) + j * elem_per_batch + l;
                        uint64_t data_expect = elem_per_batch * (i * batch_per_chan * 4 + j * 4 + k) + l;
                        if ((h_output[index] & 0x00000000ffffffff) != data_expect) {
                            std::cout << data_expect << "th element " << h_output[index] << " is not matched, , i: " << i << " j: " << j <<  " k: " << k << " l: " << l << std::endl;
                            check_status = 1;
                            goto PRINT_RESULT;
                        }
                    }
                }
            }
        }
    }


PRINT_RESULT:
    std::cout << "TEST " << (check_status ? "FAILED" : "PASSED") << std::endl;

    krnl_exec_time = (krnl_end - krnl_start) / 1000000000.0;
    std::cout << "kernel execution time is " << krnl_exec_time << "s\n";
    krnl_exec_bandwidth = (elem_cnt * RECORD_IN_BYTES / 1000000000.0) / krnl_exec_time; 
    std::cout << "Kernel performance is " << krnl_exec_bandwidth << "GB/s" << std::endl;

    exec_time = (stopTime.tv_usec - startTime.tv_usec) / 1000000.0 + (stopTime.tv_sec - startTime.tv_sec);
    std::cout << "Execution time is " << exec_time << "s\n";
    exec_bandwidth = (elem_cnt * RECORD_IN_BYTES / 1000000000.0) / exec_time;
    std::cout << "End-to-end bandwidth is " << exec_bandwidth << "GB/s" << std::endl;


    return (check_status ? EXIT_FAILURE :  EXIT_SUCCESS);
}

