import itertools
import logging
import os
import random
import math
import numpy

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiBus, AxiMaster, AxiRam


class TB(object):
    def __init__(self, dut, chan_cnt):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.fork(Clock(dut.ap_clk, 4, units="ns").start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi_control"), dut.ap_clk, dut.ap_rst_n, reset_active_level=False)
        self.axi_ram = []

        for i in range(chan_cnt):
            if (i < 10):
                axi_name = "m0" + str(i) + "_axi"
                axi_ram = AxiRam(AxiBus.from_prefix(dut, axi_name), dut.ap_clk, dut.ap_rst_n, reset_active_level=False, size=2**33)
                self.axi_ram.append(axi_ram)
            else:
                axi_name = "m" + str(i) + "_axi"
                axi_ram = AxiRam(AxiBus.from_prefix(dut, axi_name), dut.ap_clk, dut.ap_rst_n, reset_active_level=False, size=2**33)
                self.axi_ram.append(axi_ram)



    async def reset(self):
        self.dut.ap_rst_n.setimmediatevalue(1)
        for _ in range (4):
            await RisingEdge(self.dut.ap_clk)

        self.dut.ap_rst_n <= 0
        for _ in range (4):
            await RisingEdge(self.dut.ap_clk)

        self.dut.ap_rst_n <= 1
        for _ in range(100):
            await RisingEdge(self.dut.ap_clk)


async def write_reg(tb, dut, addr, data):
    reg_data = data.to_bytes(4, 'little')
    reg_addr = addr
    await tb.axil_master.write(reg_addr, reg_data)
    await RisingEdge(dut.ap_clk)


async def write_buf(tb, dut, ch, addr, data):
    tb.axi_ram[ch].write(addr, data)
    for _ in range(10):
        await RisingEdge(dut.ap_clk)


async def start_kernel(tb, dut):
    reg_data = [0x01]
    await tb.axil_master.write(0x00, reg_data)
    await RisingEdge(dut.ap_clk)


async def poll_kernel_done(tb, dut):
    read_data = await tb.axil_master.read(0x00, 4)
    ctrl_byte = read_data.data[0]
    #Keep polling
    while (ctrl_byte & 0x02 == 0):
        read_data = await tb.axil_master.read(0x00, 4)
        ctrl_byte = read_data.data[0]
    tb.log.info("Kernel is done!")


async def bytearray_2_key(src, dst):
    src_len = len(src)
    for index in range(0, src_len, 8):
        data_bytes = src[index:index+4]
        dst.append(int.from_bytes(data_bytes, 'little'))


async def gen_phase1_data(arr_len, ch_cnt, byte_arr):
    for i in range(4):
        arr = []
        for j in range (arr_len // 4):
            arr.append(ch_cnt * arr_len + i * (arr_len // 4) + j)
        random.shuffle(arr)
        for index in range(arr_len // 4):
            for _ in range(2):
                data_bytes = bytearray(arr[index].to_bytes(4, 'little'))
                byte_arr.extend(data_bytes)


async def gen_phase2_data_uniform(arr_len, ch_cnt, byte_arr):
    arr = []
    for i in range(ch_cnt, 16 * arr_len, 16):
        arr.append(i)

    for index in range(arr_len):
        for _ in range(2):
            data_bytes = bytearray(arr[index].to_bytes(4, 'little'))
            byte_arr.extend(data_bytes)

async def gen_phase2_data_same(arr_len, ch_cnt, byte_arr, val):
    arr = []
    for i in range(ch_cnt, 16 * arr_len, 16):
        arr.append(val)

    for index in range(arr_len):
        for _ in range(2):
            data_bytes = bytearray(arr[index].to_bytes(4, 'little'))
            byte_arr.extend(data_bytes)


async def gen_data(arr_len, ch_no, in_buf):
    arr = []
    for i in range(arr_len * ch_no):
        arr.append(i)
    random.shuffle(arr)

    for i in range(ch_no):
        in_data = bytearray()
        for j in range(arr_len):
            for _ in range(2):
                data_bytes = bytearray(arr[i*arr_len+j].to_bytes(4, 'little'))
                in_data.extend(data_bytes)
        in_buf.append(in_data)


async def run_test_phase1(dut):

    #Specify the number of elements
    elem_size = 8
    elem_pow = 15
    chan_no = 16
    init_sort_pow = 0
    final_sort_pow = 1
    elem_num = 2**elem_pow
    size = elem_size*elem_num

    #number of pass
    num_pass = int(math.ceil((elem_pow - init_sort_pow - final_sort_pow) / 4))

    #instantiate a tb object
    tb = TB(dut, chan_no)
    await tb.reset()

    #Prepare input buffer a
    in_buf = [] 
    for ch in range(chan_no):
        in_data = bytearray()
        await gen_phase1_data(elem_num, ch, in_data)
        in_buf.append(in_data)

    #Send scalar: size[31:0]
    await write_reg(tb, dut, 0x10, size)
    #Send scalar: size[63:32]
    await write_reg(tb, dut, 0x14, 0x00000000)
    #Send scalar: num_pass[7:0]
    await write_reg(tb, dut, 0x18, num_pass)
    #Send ptr_0[31:0]
    await write_reg(tb, dut, 0x1c, 0x00000000)
    #Send ptr_0[63:32]
    await write_reg(tb, dut, 0x20, 0x00000000)

    #Send input buffer
    for ch in range(chan_no):
        in_ptr = 0x00000000_00000000 + 0x00000000_20000000 * ch
        await write_buf(tb, dut, ch, in_ptr, in_buf[ch])

    for _ in range (100):
        await RisingEdge(dut.ap_clk)

    #Start the kernel
    await start_kernel(tb, dut)

    #Polling the ap_ctrl register
    poll_thread = cocotb.fork(poll_kernel_done(tb, dut))

    await poll_thread

    for _ in range (10):
        await RisingEdge(dut.ap_clk)

    check_status = True
    for ch in range(chan_no):
        in_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (2 * ch)
        out_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (2 * ch + 1)
        #Read sorted outputs
        if (num_pass % 2 == 1):
            read_data = tb.axi_ram[ch].read(out_ptr, size)
        else:
            read_data = tb.axi_ram[ch].read(in_ptr, size)
    
        #Check sorted outputs
        data_check = []
        await bytearray_2_key(read_data, data_check)
        
        for i in range(elem_num):
            if (data_check[i] != ch * elem_num + i):
                tb.log.debug("Channel %d: %dth element %d is not expected!", ch, i, data_check[i])
                check_status = False
                break
        '''
        fileName = "result_ch_" + str(ch)
        with open(fileName, 'w') as f:
            for i in range(elem_num):
                f.write(f'{data_check[i]:08x}\n')
        '''
        
        '''
        for i in range(4):
            for j in range(elem_num // 4 - 1):
                if (data_check[i * (elem_num // 4) + j] >= data_check[i * (elem_num // 4) + j + 1]):
                    tb.log.debug("Channel %d: %dth element %d is larger than %dth element %d", ch, i * (elem_num // 4) + j, data_check[i * (elem_num // 4) + j], i * (elem_num // 4) + j + 1, data_check[i * (elem_num // 4) + j + 1])
                    check_status = False
                    break
        '''
    
    tb.log.debug("Number of tested elements is %d", elem_num * chan_no)
    if (check_status):
        tb.log.debug("Test succeeds!")
    else:
        tb.log.debug("Test fails!")


async def run_test_phase2_uniform(dut):

    #Specify the number of elements
    elem_size = 8
    elem_per_chan_pow = 15
    chan_no = 16
    elem_num_per_chan = 2**elem_per_chan_pow
    size = elem_size*elem_num_per_chan
    batch_size = 4096
    elem_per_batch = batch_size // elem_size
    batch_per_chan = size // batch_size

    #number of pass
    num_pass = int(math.ceil((elem_per_chan_pow) / 4))

    #instantiate a tb object
    tb = TB(dut, chan_no)
    await tb.reset()

    #Prepare input buffer
    in_buf = []
    for ch in range (16):
        input_data = bytearray()
        await gen_phase2_data_uniform(elem_num_per_chan, ch, input_data)
        in_buf.append(input_data)

    #Send scalar: size[31:0]
    await write_reg(tb, dut, 0x10, size)
    #Send scalar: size[63:32]
    await write_reg(tb, dut, 0x14, 0x00000000)
    #Send scalar: num_pass[7:0]
    await write_reg(tb, dut, 0x18, num_pass)
    #Send ptr_0[31:0]
    await write_reg(tb, dut, 0x1c, 0x00000000)
    #Send ptr_0[63:32]
    await write_reg(tb, dut, 0x20, 0x00000000)

    #Send input buffer
    for i in range(4):
        for j in range(4):
            if (num_pass % 2 == 1):
                in_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (8*i+2*j+1)
                await write_buf(tb, dut, 4*i, in_ptr, in_buf[4*i+j])
            else:
                in_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (8*i+2*j)
                await write_buf(tb, dut, 4*i, in_ptr, in_buf[4*i+j])


    for _ in range (10):
        await RisingEdge(dut.ap_clk)

    
    #Start the kernel
    await start_kernel(tb, dut)

    #Polling the ap_ctrl register
    poll_thread = cocotb.fork(poll_kernel_done(tb, dut))

    await poll_thread

    for _ in range (10):
        await RisingEdge(dut.ap_clk)

    check_status = True
    #each group has 4 channels
    for i in range(4):
        #number of batches that each channel has
        for j in range(batch_per_chan):
            #4 groups
            for k in range(4):
                if (num_pass % 2 == 1):
                    data_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (k * 8 + 2 * i) + j * batch_size
                else:
                    data_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (k * 8 + 2 * i + 1) + j * batch_size
                read_data = tb.axi_ram[4*k].read(data_ptr, batch_size)
    
                #Check sorted outputs
                data_check = []
                await bytearray_2_key(read_data, data_check)
                for l in range(elem_per_batch):
                    data_expect = elem_per_batch * (i * batch_per_chan * 4 + j * 4 + k) + l
                    if (data_check[l] != data_expect):
                        tb.log.debug("element %d is not expected, expect %d, i: %d, j: %d, k: %d, l: %d", data_check[i], data_expect, i, j, k, l)
                        check_status = False
                        break
                if (check_status == False):
                    break
            if (check_status == False):
                break
        if (check_status == False):
            break
    
    tb.log.debug("Number of tested elements is %d", elem_num_per_chan * 16)
    if (check_status):
        tb.log.debug("Phase 2 Uniform Test succeeds!")
    else:
        tb.log.debug("Phase 2 Uniform Test fails!")


async def run_test_phase2_same(dut):

    #Specify the number of elements
    elem_size = 8
    elem_per_chan_pow = 13
    chan_no = 16
    elem_num_per_chan = 2**elem_per_chan_pow
    size = elem_size*elem_num_per_chan
    batch_size = 4096
    elem_per_batch = batch_size // elem_size
    batch_per_chan = size // batch_size
    elem_val = 4

    #number of pass
    num_pass = int(math.ceil((elem_per_chan_pow) / 4))

    #instantiate a tb object
    tb = TB(dut, chan_no)
    await tb.reset()

    #Prepare input buffer
    in_buf = []
    for ch in range (16):
        input_data = bytearray()
        await gen_phase2_data_same(elem_num_per_chan, ch, input_data, elem_val)
        in_buf.append(input_data)

    #Send scalar: size[31:0]
    await write_reg(tb, dut, 0x10, size)
    #Send scalar: size[63:32]
    await write_reg(tb, dut, 0x14, 0x00000000)
    #Send scalar: num_pass[7:0]
    await write_reg(tb, dut, 0x18, num_pass)
    #Send ptr_0[31:0]
    await write_reg(tb, dut, 0x1c, 0x00000000)
    #Send ptr_0[63:32]
    await write_reg(tb, dut, 0x20, 0x00000000)

    #Send input buffer
    for i in range(4):
        for j in range(4):
            if (num_pass % 2 == 1):
                in_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (8*i+2*j+1)
                await write_buf(tb, dut, 4*i, in_ptr, in_buf[4*i+j])
            else:
                in_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (8*i+2*j)
                await write_buf(tb, dut, 4*i, in_ptr, in_buf[4*i+j])


    for _ in range (10):
        await RisingEdge(dut.ap_clk)

    
    #Start the kernel
    await start_kernel(tb, dut)

    #Polling the ap_ctrl register
    poll_thread = cocotb.fork(poll_kernel_done(tb, dut))

    await poll_thread

    for _ in range (10):
        await RisingEdge(dut.ap_clk)

    check_status = True
    #each group has 4 channels
    for i in range(4):
        #number of batches that each channel has
        for j in range(batch_per_chan):
            #4 groups
            for k in range(4):
                if (num_pass % 2 == 1):
                    data_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (k * 8 + 2 * i) + j * batch_size
                else:
                    data_ptr = 0x00000000_00000000 + 0x00000000_10000000 * (k * 8 + 2 * i + 1) + j * batch_size
                read_data = tb.axi_ram[4*k].read(data_ptr, batch_size)
    
                #Check sorted outputs
                data_check = []
                await bytearray_2_key(read_data, data_check)
                for l in range(elem_per_batch):
                    data_expect = elem_val
                    if (data_check[l] != data_expect):
                        tb.log.debug("element %d is not expected, expect %d, i: %d, j: %d, k: %d, l: %d", data_check[i], data_expect, i, j, k, l)
                        check_status = False
                        break
                if (check_status == False):
                    break
            if (check_status == False):
                break
        if (check_status == False):
            break
    
    tb.log.debug("Number of tested elements is %d", elem_num_per_chan * 16)
    if (check_status):
        tb.log.debug("Phase 2 Same Test succeeds!")
    else:
        tb.log.debug("Phase 2 Same Test fails!")



if cocotb.SIM_NAME:
    #factory = TestFactory(run_test_phase1)
    #factory = TestFactory(run_test_phase2_uniform)
    #factory = TestFactory(run_test_phase2_same)
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))


def test_merge_sort_complete(request):
    dut = "merge_sort_complete"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.sv"),
    ]

    parameters = {}

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
