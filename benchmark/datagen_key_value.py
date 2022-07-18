import itertools
import logging
import os
import random
import math

elem_num_pow = int(input("Enter the number of elements per channel in power of 2: "))
chan_num = int(input("Enter channel number: "))

elem_per_chan = pow(2, elem_num_pow)
elem_num = elem_per_chan * chan_num

fileName = "data_cmpl_kv_1^" + str(elem_num_pow) + "_chan_" + str(chan_num)

with open(fileName, 'w') as f:
    arr = []
    for i in range(elem_num):
        arr.append(i)

    random.shuffle(arr)

    for i in range(elem_num):
        f.write(f'{arr[i]:08x}')
        f.write(f'{arr[i]:08x}\n')
