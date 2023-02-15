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
# pip install py2exe

import serial
import time
import os
import argparse
import sys

ap = argparse.ArgumentParser(description="Bootstrap a small file to a DOS PC",formatter_class=argparse.ArgumentDefaultsHelpFormatter)
ap.add_argument("-f", "--file", default="ssdwrecv/ssdw.com", help="file")
ap.add_argument("-p", "--port", default="COM1", help="port: COM1, COM2, etc. (on Windows)")
#ap.add_argument("-b", "--baud", type=int, default=115200, help="baud rate: eg: 9600, 115200")

args=vars(ap.parse_args())

file = args["file"]
port = args["port"]

ser = serial.Serial(port, 2400, timeout=2, rtscts=False, dsrdtr=False)

data = open(file,"rb").read()

for d in data:
    if d == 0x1A:
        print("File contains 0x1A - won't work.")
        sys.exit()

data = data + bytes([0x1A])

print("On the DOS machine, type CTTY COMx")
print("Replace COMx with the DOS machines com port EG: COM1 ")


while(ser.in_waiting < 3):
    ser.write(bytes([0x0D]))
    time.sleep(1)

d=ser.read_all()
time.sleep(1)
ser.write(bytes("DEL SSDW.COM\r", 'utf-8'))
time.sleep(1)
d=ser.read_all()
time.sleep(1)
ser.write(bytes("COPY COM1 SSDW.COM\r", 'utf-8'))
ser.write(data)
time.sleep(1)
d=ser.read_all()

print(d)

time.sleep(1)
ser.write(bytes("CTTY CON\r", 'utf-8'))
time.sleep(1)
d=ser.read_all()
print(d)

