; -----------------------------------------------------------------------
;  Copyright (C) 2023  Matt Westveld
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; -----------------------------------------------------------------------

[map symbols ssdw.map]

bits 16
cpu 8086

args_len	equ		0x80	; location of argument data length
args_data	equ		0x81	; location of argument data 

cmd_recv_sector equ 	0x00		; cmd: 00, sector # (0-17) , NA
cmd_write_track equ 	0x01		; cmd: 01, drive #, track #, head #, sectors to write
cmd_reset 		equ 	0x08		; cmd: 08, drive #
cmd_quit 		equ 	0xFF		; cmd: FF, NA

org 100h
section .text 

	; check ourselves before we wreck ourselves
	mov cx, [file_len]
	mov si, 0x100
	call compute_checksum
	cmp bx, [file_cksum]
	je start
	mov si, bad_cksum_text
	call printz
	jmp bye

start:
	jmp get_args
init:
	call init_com
; -----------------------------------------------------------------------		
get_frame:
	; wait for our frame startcode
	call recv_byte
	cmp al, [startcode]
	jne get_frame

	; next 2 bytes are the length of the cmd + data (if any)
	call recv_byte
	mov [datalen], al
	call recv_byte
	mov [datalen + 1], al
	mov cx, [datalen]
	cmp cx, 0x208
	ja get_frame	; too big, something wrong, start over

	; grab the data
	mov bx, cmdbuf
.dataloop:
	call recv_byte
	mov [bx],al
	inc bx
	loop .dataloop

	; grab the checksum
	call recv_byte
	mov [chksum],al
	call recv_byte
	mov [chksum+1],al	

	mov si, cmdbuf
	mov cx, [datalen]
	call compute_checksum

	cmp bx, [chksum]
	; if checksum match:
	; 	send startcode + 2
	; 	startcode XOR= 1
	; 	process cmd

	jne badchk
	mov al, '.'	; print period
	call printc
	mov al, [startcode]
	add al, 2
	call send_byte
	mov al, [startcode]
	xor al, 1
	mov [startcode], al
	mov ax,0
	call proc_cmd
	jmp get_frame

	; otherwise:
	; 	send startcode XOR=1 + 2
	; 	loop back and wait again

badchk:	
	mov al, 'x'		; print x
	call printc
	mov al, [startcode]
	xor al, 1
	add al, 2
	call send_byte
	jmp get_frame

%include "print.asm"

; -----------------------------------------------------------------------		
; get and process the command line args
; -----------------------------------------------------------------------	
get_args:
	mov bx, args_data
	mov cx, 0

	; grab 2 single-digit args
	call skip_delim	
	mov al, [bx]
	call is_num
	jnc print_usage		; if first arg not a number, print usage and exit
	mov [port_arg], al
	inc bx	
	mov al, [bx]
	call test_delim
	jne print_usage		; if more than just 1 char, print usage and exit

	call skip_delim
	mov al, [bx]
	call is_num
	jnc print_usage		; if first arg not a number, print usage and exit
	mov [baud_arg], al
	inc bx	
	mov al, [bx]
	call test_delim
	jne print_usage		; if more than just 1 char, print usage and exit

	; process args
	; com port
first_arg:	
	mov al, [port_arg]
	cmp al, '1'
	jne .test2
	mov [com_io], word 0x3F8	
	jmp next_arg
.test2:	
	cmp al, '2'
	jne .test3
	mov [com_io], word 0x2F8
	jmp next_arg
.test3:	
	cmp al, '3'
	jne .test4
	mov [com_io], word 0x3E8
	jmp next_arg
.test4:	
	cmp al, '4'
	jne print_usage
	mov [com_io], word 0x2E8
	nop							; filler to prevent a 1A in the code that breaks bootstrap
	; baud
next_arg:
	; process args
	mov al, [baud_arg]
	cmp al, '1'
	jne .test2
	mov [baud_mult], byte 0x30
	jmp .done_args
.test2:	
	cmp al, '2'
	jne .test3
	mov [baud_mult], byte 0x0C
	jmp .done_args
.test3:	
	cmp al, '3'
	jne .test4
	mov [baud_mult], byte 0x06
	jmp .done_args
.test4:	
	cmp al, '4'
	jne .test5
	mov [baud_mult], byte 0x03
	jmp .done_args
.test5:	
	cmp al, '5'
	jne .test6
	mov [baud_mult], byte 0x02
	jmp .done_args
.test6:	
	cmp al, '6'
	jne print_usage
	mov [baud_mult], byte 0x01
	jmp .done_args		

.done_args:
	jmp init

; set carry if the ascii digit in al is a number 1-9
is_num:
	cmp al, '1'
	jb .nope
	cmp al, '9'
	ja .nope
	stc
	ret
.nope:
	clc
	ret

skip_delim:
	mov al, [bx]
	call test_delim
	jne .end
	inc bx
	jmp skip_delim
.end:
	ret

; -----------------------------------------------------------------------		
; Test if AL contains a DOS delimiter
; -----------------------------------------------------------------------
test_delim:
	cmp al, ' '
	je .yup
	cmp al, ','
	je .yup
	cmp al, 0x09
	je .yup
	cmp al, ';'
	je .yup
	cmp al, '='
	je .yup
	cmp al, 0x0D
.yup:
	ret	


; -----------------------------------------------------------------------		
; print usage text, then exit
; -----------------------------------------------------------------------	
print_usage:
	mov si, usage_text
	call printz
	jmp bye

; -----------------------------------------------------------------------		
; process the command from the buffer
; -----------------------------------------------------------------------	
proc_cmd:
	mov al, [cmdbuf]	; get cmd
	cmp al, cmd_recv_sector
	je copy_sector
	cmp al, cmd_write_track
	je write_track
	cmp al, cmd_reset
	je reset_drive
	cmp al, cmd_quit
	je bye
	; unknown command
	mov al, '?'	; print ?
	call printc
	jmp get_frame

; -----------------------------------------------------------------------		
; cmd: 01, drive #, track #, head #, sectors to write
; -----------------------------------------------------------------------		
write_track:
	call print_track
	mov dl,[cmdbuf+1]		; drive #
	mov ch,[cmdbuf+2]		; track
	mov dh,[cmdbuf+3]		; head
	mov al,[cmdbuf+4]		; sectors to write
	call write_sectors
	mov al, ah
	call send_byte			; send the return code
	cmp al, 0
	je get_frame
	push ax					; print ER and the return code
	mov al, 'E'
	call printc
	mov al, 'R'
	call printc
	pop ax
	;mov ah, al
	call print_byte
	mov al, 0x0A
	call printc
	mov al, 0x0D
	call printc
	jmp get_frame

; -----------------------------------------------------------------------
; prints the track info
; -----------------------------------------------------------------------		
print_track:
	; drive
	mov al,[cmdbuf+1]
	call print_byte
	mov al, ':'
	call printc
	; track
	mov al,[cmdbuf+2]	
	call print_byte
	mov al, ':'
	call printc
	; head
	mov al,[cmdbuf+3]	
	call print_byte
	mov al, 0x0A
	call printc
	mov al, 0x0D
	call printc
	ret

; -----------------------------------------------------------------------
; Copies the 512 byte sector from the recv buffer to the track buffer	
; ----------------------------------------------------------------------		
copy_sector:
	mov ax, 0
	mov ah, [cmdbuf+1]	; sector #  (* 256 since ah)
	rol ah, 1 				; * 2
	; now copy from secbuf to trackbuf
	mov cx, 512
	add ax, trackbuf	
	mov di, ax
	mov si, secbuf			; source
	rep movsb
	jmp get_frame

; -----------------------------------------------------------------------
; Resets the drive - makes it find track 0 again	
; ----------------------------------------------------------------------			
reset_drive:
	mov ah, 0
	mov dl, [cmdbuf+1]
	int 0x13
	mov al, ah
	call send_byte			; send the return code
	ret	


; -----------------------------------------------------------------------		
; BSD Checksum code
; IN:  	DS:SI = points to data to checksum
;		CX = length of data to checksum
; OUT:	BX = checksum
; -----------------------------------------------------------------------		
compute_checksum:
    cld
    mov bx, 0
    mov ax, 0
.loop:
    lodsb
    ror bx, 1
    add bx, ax
	loop .loop
	ret

; -----------------------------------------------------------------------
; Writes a track
; IN:  
;	AL - # of sectors	
;	DL - drive
;	DH - head
;	CH - track
; ----------------------------------------------------------------------
write_sectors:
	mov ah, 3				; writing
	mov cl, 1				; sector to start with
	mov bx, trackbuf  		;  
	int 0x13
	ret

; -----------------------------------------------------------------------	
; return next serial byte in al
; -----------------------------------------------------------------------	

recv_byte:
	; return next serial byte in al
  	; wait for an available byte
 	push dx
	mov dx, [com_io]
	add dx, 4
	mov al, 0x02
	out dx, al		; set RTS

.loop:
	mov dx, [com_io]
	add dx, 5
	in al, dx
	and al, 0x01
	cmp al, 0	
	je .loop

	mov dx, [com_io]
	in al, dx			; get byte
	push ax

	mov dx, [com_io]
	add dx, 4
	mov al, 0x00
	out dx, al		; clear RTS
	
	pop ax
	pop dx
	ret
	
; -----------------------------------------------------------------------	
; send serial byte from AL
; -----------------------------------------------------------------------	
send_byte:	
	push dx
	push ax
	.loop:
	mov dx, [com_io]
	add dx, 5
	in al, dx
	and al, 0x20
	cmp al, 0				; transmit buffer ready?
	je .loop
	pop ax
	mov dx, [com_io]
	out dx, al
	pop dx
	ret
	
; -----------------------------------------------------------------------
;	Setup com port
; -----------------------------------------------------------------------
init_com:
	mov dx, [com_io]
	add dx, 1			; com_io + 1
	mov al, 0x00
	out dx, al

	add dx, 2			; com_io + 2
	mov al, 0x80
	out dx, al

	mov dx, [com_io]		; com_io
	mov al, [baud_mult]
	out dx, al	

	add dx, 1				; com_io + 1
	mov al, 0x00
	out dx, al

	add dx, 2				; com_io + 3
	mov al, 0x03
	out dx, al

	sub dx, 1				; com_io + 2
	mov al, 0xC7
	out dx, al

	add dx, 2				; com_io + 4
	mov al, 0x00
	out dx, al

	ret

; -----------------------------------------------------------------------	
;	Exit to dos
; -----------------------------------------------------------------------	
bye:
	mov ax, 0x4c00
	int 0x21
	
; -----------------------------------------------------------------------	
; -----------------------------------------------------------------------	

section .data
  ; program data
  usage_text db "Usage: See README.TXT",0
  bad_cksum_text db "BAD FILE CHECKSUM",0
  startcode db 0x90
  datalen dw 0x0000
  chksum dw 0xFFFF
  port_arg db "1"
  baud_arg db "1"
  com_io dw 0x03F8
  baud_mult db 0x0C
  ; !! Make sure these are at the end of the file !!
  file_len dw 0x55AA
  file_cksum dw 0x55AA
  
section .bss
	; uninitialized data
	cmdbuf resb 8			; buffer for serial cmd
	secbuf resb 512			; buffer for serial sector data
  	trackbuf resb 9216  	; for storing 1 track (1.44mb = 18 sector tracks = 512 * 18)
