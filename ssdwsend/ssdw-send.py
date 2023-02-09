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

import serial
from pynput.keyboard import Key, Listener
import os
import argparse
import sys

ap = argparse.ArgumentParser(description="Simple Serial Disk Writer - sender",formatter_class=argparse.ArgumentDefaultsHelpFormatter)
ap.add_argument("-f", "--file", required=True, help="file")
ap.add_argument("-d", "--drive", type=int, required=True, help="drive: Usually 0 = Drive A, 1 = B, etc.)")
ap.add_argument("-p", "--port", required=True, help="port: COM1, COM2, etc. (on Windows)")
ap.add_argument("-b", "--baud", type=int, required=True, help="baud rate: eg: 9600, 115200")
ap.add_argument("-c", "--rtscts", action="store_true", default=False, help="rtscts enable: True or False")
ap.add_argument("-t", "--timeout", type=int, default=5, help="timeout in seconds")
ap.add_argument("-r", "--retries", type=int, default=3, help="disk track write retries")

args=vars(ap.parse_args())

file = args["file"]
drive = args["drive"]
port = args["port"]
rtscts = args["rtscts"]
baud = args["baud"]
timeout = args["timeout"]
retries = args["retries"]

diskTypes = {
    163840 : [40,1,8],
    184320 : [40,1,9],
    327680 : [40,2,8],
    368640 : [40,2,9],
    737280 : [80,2,9],
    1228800 : [80,2,15],
    1474560 : [80,2,18]
}

startCode = 0x90
escAbort = False

print("Press ESC to abort.")

def on_press(key):
    global escAbort
    if key == Key.esc:    
        print("ESC Pressed")    
        escAbort = True
        return False

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

def sendData(data):
    global startCode
    global ser
    global escAbort

    bytesData = bytes(data)

    rtn = False
    chk = computeChecksum(data)

    lenD = len(data)
    lenLow = lenD & 0x00FF
    lenHi = (lenD & 0xFF00) >> 8

    chkLow = chk & 0x00FF
    chkHi = (chk & 0xFF00) >> 8

    while(rtn == False):
        ser.write(bytes([startCode,lenLow,lenHi]))    
        ser.write(bytesData)
        ser.write(bytes([chkLow, chkHi]))
        codeBack = ser.read(1)
        if (len(codeBack) > 0) and (codeBack[0] == (startCode + 2)):
            rtn = True
            startCode ^= 1
            print(".", end="")            
        else:
            print("x", end="")
            if escAbort: rtn=True
    
    return

listener = Listener(on_press=on_press)
listener.start()

ser = serial.Serial(port, baud, timeout=timeout, rtscts=rtscts)

fileSize = os.path.getsize(file)
if fileSize in diskTypes.keys():
    diskType = diskTypes[fileSize]
    maxTrack = diskType[0]
    maxHead = diskType[1]
    maxSector = diskType[2]

    with open(file,"rb") as f:
        errOut = False
        track = 0
        while((track < maxTrack) and (errOut == False) and (escAbort == False)):
            head = 0
            retryCount = 0
            while((head < maxHead) and (errOut == False) and (escAbort == False)):
                sector = 0
                # send the full track to the buffer
                while(sector < maxSector):
                    # command part - 8 bytes
                    #     cmd  sec#    ?    ?    ?    ?    ?    ?
                    data=[0x00,sector,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA]
                    secdata = list(f.read(512))
                    data.extend(secdata)
                    sendData(data)
                    sector += 1

                # write track        
                #          drv  trk  head scts
                data=[0x01,drive,track,head,maxSector,0xAA,0xAA,0xAA]
                sendData(data)
                print(f"{drive:02X}:{track:02X}:{head:02X}", end="")                
                codeBack = ser.read(1)
                if((len(codeBack) > 0) and (codeBack[0]==0)):
                    head += 1
                    print(" OK")
                else:
                    # if disk err, print it, reset disk, start again
                    print(f" ERR = {codeBack[0]:02X}")
                    data=[0x08,drive,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA]
                    sendData(data)
                    codeBack = ser.read(1)                    
                    retryCount += 1                    
                    if retryCount > retries:
                        errOut = True
                    # TODO: handle disk reset error

            track += 1

        # end program
        data=[0xFF,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA]
        sendData(data)
        if escAbort:
            print(f"\n!! ABORTED - ESC Pressed !!")

        if errOut:
            print(f"\n!! ABORTED - more than {retries} retries !!")            
else:
    print(f"Unknown format file size: {fileSize}")

listener.stop()
