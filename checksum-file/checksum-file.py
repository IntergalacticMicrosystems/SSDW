#-----------------------------------------------------------------------
# Copyright (C) 2023  Matt Westveld
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#-----------------------------------------------------------------------
# Needs:
# pip install pyserial
# pip install pynput
# pip install py2exe

import serial
from pynput.keyboard import Key, Listener, _win32
from pynput.mouse import _win32
import os
import argparse
import sys

ap = argparse.ArgumentParser(description="Fix last 4 bytes of a com file - set file length and checksum",formatter_class=argparse.ArgumentDefaultsHelpFormatter)
ap.add_argument("-f", "--file", default="ssdwrecv/ssdw.com", help="file")

args=vars(ap.parse_args())

file = args["file"]

def ror16_1(dw):
    return (dw >> 1) | ((dw << 15) & 0b1000_0000_0000_0000)

def computeChecksum(data):
    checksum = 0
    for d in data:
        rored = ror16_1(checksum)
        oldb = format(d,'016b')
        newb = format(rored,'016b')
        checksum = (rored + d) & 0xFFFF
        chkb = format(checksum,'016b')        
    return checksum

data = open(file,"rb").read()
data = data[:-4]                # cut off the len/cksum
dlen = len(data)
cksum = computeChecksum(data)

# add the length and cksum words to the end
lo = dlen & 0x00FF
hi = (dlen & 0xFF00) >> 8
data = data + bytes([lo,hi])
lo = cksum & 0x00FF
hi = (cksum & 0xFF00) >> 8
data = data + bytes([lo,hi])
#data = data + bytes([0x55,0xAA])

open(file,"wb").write(data)

