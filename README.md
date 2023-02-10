## Simple Serial Disk Writer

### ***USE AT YOUR OWN RISK!***
### ***This code has very little sanity checking***
### ***And yes, I know it's hot garbage :)***

A tool to push disk images from a modern PC to a vintage DOS 8086+ system.

ssdw.com runs on the vintage PC

ssdw-send.py runs on the modern PC

null modem cable between them

**On the modern PC you'll likely need Python 3.6+**

**Or just download a zip with it packaged up here:**
[binaries-DOS-and-WIN7-32.zip](https://github.com/IntergalacticMicrosystems/SSDW/raw/main/binaries-DOS-and-WIN7-32.zip)

**To install the packages needed, you can use pip:**
```
pip install pyserial
pip install pynput
```

Disk images need to be raw full-size images.

ssdw-send.py sets the track/head/sectors based on the file size

**Example usage:**

**To write an image to drive A on the vintage PC:**

Start on the Vintage PC first

Vintage PC:

```
ssdw 1 2
```

Modern PC:

```
python ssdw-send.py --file dos360k.img --drive 0 --port COM1 --baud 9600
```
