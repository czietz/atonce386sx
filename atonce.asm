; Sample code to call 68k code from ATonce386SX in Atari ST
; Copyright (C) 2025 Christian Zietz <czietz@gmx.net>


; On the ATonce386SX (PC add-on card for Atari ST computers) there is no
; documented API to call 68000 code from the x86, necessary, e.g., to
; access Atari peripherals. One can exploit an undocumented way, though.
; Access to the x86 IO ports triggers calls to the 68k CPU. The table of
; handler routines -- one table for writes, one table for reads, one entry
; for each 16 IO ports -- is accessible from the x86.

; The drawback: The address of this table could be different depending on
; the ATonce386SX software version. This code is intended for version 5.25,
; BIOS date 09/03/92.

; This sample code writes the color red to first Shifter palette entry. Thus,
; it requires a color monitor to have a visible effect. Build it with NASM.


; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to
; deal in the Software without restriction, including without limitation the
; rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
; sell copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:

; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
; IN THE SOFTWARE.

CPU 386
ORG 100h
; address of IO port handler routines in ATonce386SX BIOS 09/03/92
port0 EQU 1C0Eh
; address of memory translation table in ATonce386SX BIOS 09/03/92
tbl EQU 1BA4h
; color red
color EQU 0700h

; check supported SW version by checking BIOS date
MOV AX,0F000h
MOV ES,AX
CMP WORD [ES:0FFF5h], 3930h ; "09"
JNE badversion
CMP WORD [ES:0FFF8h], 3330h ; "03"
JNE badversion
CMP WORD [ES:0FFFBh], 3239h ; "92"
JE main

badversion:
; print message
MOV DX, badmsg
MOV AH, 09h
INT 21h

; terminate
MOV AX,4C01h
INT 21h

main:
; calculate 68k address of 68k code
MOV AX,code_68k
CALL x86_to_68k
; endianess swap
XCHG AH,AL
XCHG DH,DL

; save old IO port 0-F write handler and...
; store 68k address as handler for IO port 0-F write
PUSH WORD [ES:port0]
PUSH WORD [ES:port0+2]
MOV WORD [ES:port0],DX
MOV WORD [ES:port0+2],AX

; call 68k code by performing a write to IO port 0
MOV AX,color    ; value to load into palette
OUT 0h,AX

; restore old handler
POP WORD [ES:port0+2]
POP WORD [ES:port0]

; terminate
MOV AX,4C00h
INT 21h

; routine to translate an address from the ATonce's x86
; memory space into the ATonce's 68k memory space
; in: address in DS:AX, ES = 0F000h (BIOS segment)
; out: address in DX:AX
x86_to_68k:
PUSH BX
PUSH CX
; calculate linear x86 address: (DS<<4) + AX
MOV DX,DS
MOV CX,DX
SHR DX,12
SHL CX,4
ADD AX,CX
ADC DX,0
; address translation of highest nibble, using table from BIOS
AND DX,0Fh
MOV BX,tbl
ADD BX,DX
MOV DL,ES:[BX]
POP CX
POP BX
RET

ALIGN 2
; MC68000 code: as an example, load Shifter palette entry 0.
; data written to IO port 0 is stored at 0x30000 in 68k memory.
; D0 is allowed to be clobbered
code_68k:
DB 30h, 39h, 00h, 03h, 00h, 00h ; MOVE.W 0x30000,D0
DB 0E0h,58h                     ; ROR.W #8,D0 (endianess swap)
DB 31h,0C0h,82h,40h             ; MOVE.W D0, 0xFFFF8240.W
DB 4Eh, 75h                     ; RTS

badmsg:
DB "This ATonce SW version is not supported.",13,10,"$"