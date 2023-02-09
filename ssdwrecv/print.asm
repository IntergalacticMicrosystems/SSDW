;=========================================================================
; Pulled on 2023/2/8 from bios.asm here:
; https://github.com/skiselev/8088_bios
; Mods: 
; pull out just the print functions
; print renamed -> printz
; add printc
;-------------------------------------------------------------------------
;
; Compiles with NASM 2.13.02, might work with other versions
;
; Copyright (C) 2010 - 2023 Sergey Kiselev.
; Provided for hobbyist use on the Xi 8088 and Micro 8088 boards.
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;=========================================================================

;=========================================================================
; print - print one char to the console
; Input:
;	AL - char to print
; Output:
;	none
;-------------------------------------------------------------------------
printc:
	pushf
	push	ax
	push	bx
	mov	ah,0Eh
	mov	bl,0Fh
	int	10h
	pop	bx
	pop	ax
	popf
	ret

;=========================================================================
; printz - print ASCIIZ string to the console
; Input:
;	CS:SI - pointer to string to print
; Output:
;	none
;-------------------------------------------------------------------------
printz:
	pushf
	push	ax
	push	bx
	push	si
	push	ds
	push	cs
	pop	ds
	cld
.1:
	lodsb
	or	al,al
	jz	.exit
	mov	ah,0Eh
	mov	bl,0Fh
	int	10h
	jmp	.1
.exit:
	pop	ds
	pop	si
	pop	bx
	pop	ax
	popf
	ret

;=========================================================================
; print_hex - print 16-bit number in hexadecimal
; Input:
;	AX - number to print
; Output:
;	none
;-------------------------------------------------------------------------
print_hex:
	xchg	al,ah
	call	print_byte		; print the upper byte
	xchg	al,ah
	call	print_byte		; print the lower byte
	ret

;=========================================================================
; print_byte - print a byte in hexadecimal
; Input:
;	AL - byte to print
; Output:
;	none
;-------------------------------------------------------------------------
print_byte:
	rol	al,1
	rol	al,1
	rol	al,1
	rol	al,1
	call	print_digit
	rol	al,1
	rol	al,1
	rol	al,1
	rol	al,1
	call	print_digit
	ret

;=========================================================================
; print_dec - print 16-bit number in decimal
; Input:
;	AX - number to print
; Output:
;	none
;-------------------------------------------------------------------------
print_dec:
	push	ax
	push	cx
	push	dx
	mov	cx,10		; base = 10
	call	.print_rec
	pop	dx
	pop	cx
	pop	ax
	ret

.print_rec:			; print all digits recursively
	push	dx
	xor	dx,dx		; DX = 0
	div	cx		; AX = DX:AX / 10, DX = DX:AX % 10
	cmp	ax,0
	je	.below10
	call	.print_rec	; print number / 10 recursively
.below10:
	mov	ax,dx		; reminder is in DX
	call	print_digit	; print reminder
	pop	dx
	ret

;=========================================================================
; print_digit - print hexadecimal digit
; Input:
;	AL - bits 3...0 - digit to print (0...F)
; Output:
;	none
;-------------------------------------------------------------------------
print_digit:
	push	ax
	push	bx
	and	al,0Fh
	add	al,'0'			; convert to ASCII
	cmp	al,'9'			; less or equal 9?
	jna	.1
	add	al,'A'-'9'-1		; a hex digit
.1:
	mov	ah,0Eh			; Int 10 function 0Eh - teletype output
	mov	bl,07h			; just in case we're in graphic mode
	int	10h
	pop	bx
	pop	ax
	ret

