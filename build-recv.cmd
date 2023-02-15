REM @ECHO OFF
cd ssdwrecv
"C:\Program Files\NASM\nasm.exe" ssdw.asm -O0 -fbin -l ssdw.lst -Lp -ossdw.com
cd ..
python checksum-file\checksum-file.py -f ssdwrecv\ssdw.com
copy ssdwrecv\ssdw.com binaries
pause
