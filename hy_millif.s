;----------------------------------------------------------------------
;
;   A MilliForth for 6502 
;
;   original for the 6502, by Alvaro G. S. Barcellos, 2023
;
;   https://github.com/agsb 
;   see the disclaimer file in this repo for more information.
;
;   SectorForth and MilliForth was made for x86 arch 
;   and uses full 16-bit registers 
;
;   The way at 6502 is use page zero and lots of lda/sta
;
;   Focus in size not performance.
;
;   why ? For understand better my skills, 6502 code and thread codes
;
;   how ? Programming a new Forth for old 8-bit cpu emulator
;
;   what ? Design the best minimal Forth engine and vocabulary
;
;----------------------------------------------------------------------
;   Changes:
;
;   all data (36 cells) and return (36 cells) stacks, TIB (80 bytes) 
;       and PIC (32 bytes) are in same page $200, 256 bytes; 
;
;   TIB and PIC grows forward, stacks grows backwards;
;
;   no overflow or underflow checks;
;
;   the header order is LINK, SIZE+FLAG, NAME.
;
;   only IMMEDIATE flag used as $80, no hide, no compile;
;
;   As ANSI Forth 1994: FALSE is $0000 ; TRUE is $FFFF ;
;
;----------------------------------------------------------------------
;   Remarks:
;
;       this code uses 
;           Direct Thread Code, aka DTC or
;           Minimal Thread Code, aka MTC.
;
;       use a classic cell with 16-bits. 
;
;       no TOS register, all values keeped at stacks;
;
;       TIB (terminal input buffer) is like a stream;
;
;       Chuck Moore uses 64 columns, be wise, obey rule 72 CPL; 
;
;       words must be between spaces, before and after;
;
;       no line wrap, do not break words between lines;
;
;       only 7-bit ASCII characters, plus \n, no controls;
;           ( later maybe \b backspace and \u cancel )
;
;       words are case-sensitivy and less than 16 characters;
;
;       no need named-'pad' at end of even names;
;
;       no multiuser, no multitask, no checks, not faster;
;
;----------------------------------------------------------------------
;   For 6502:
;
;       a 8-bit processor with 16-bit address space;
;
;       the most significant byte is the page count;
;
;       page zero and page one hardware reserved;
;
;       hardware stack not used for this Forth;
;
;       page zero is used as pseudo registers;
;
;----------------------------------------------------------------------
;   For stacks:
;
;   "when the heap moves forward, move the stack backward" 
;
;   as hardware stacks do: 
;      push is 'store and decrease', pull is 'increase and fetch',
;
;   but see the notes for Devs.
;
;   common memory model organization of Forth: 
;   [INBUF->...<-DSPTR: user forth dictionary :NEXTHEAP->pad...<-RTPTR]
;   then backward stacks allow to use the slack space ... 
;
;   this 6502 Forth memory model blocked in pages of 256 bytes:
;   [page0][page1][page2][core ... forth dictionary ...NEXTHEAP...]
;   
;   At page2: 
;
;   |$00 INBUF> .. $50| <DSPTR..DSEND $98| <RTPTR..RTEND $E0|SCRIBB> ..$FF|
;
;   From page 3 onwards:
;
;   |$0300 cold:, warm:, forth code, init: here> heap ... tail| 
;
;   PIC is a transient area of 32 bytes 
;   PAD could be allocated from here
;
;----------------------------------------------------------------------
;   For Devs:
;
;   the hello_world.forth file states that stacks works
;       to allow : dup sp@ @ ; so sp must point to actual TOS.
;   
;   The movement will be:
;       pull is 'fetch and increase'
;       push is 'decrease and store'
;
;   Never mess with two underscore variables;
;
;   Not using smudge, 
;       colon saves "here" into "back" and 
;       semis loads "LASTHEAPest" from "back";
;
;   Do not risk to put stacks with $FF.
;
;   Also carefull inspect if any label ends with $FF and move it;
;
;   This source is hacked for use with Ca65.
;
;----------------------------------------------------------------------
;
;   Stacks represented as (standart)
;       S:(w1 w2 w3 -- u1 u2)  R:(w1 w2 w3 -- u1 u2)
;       before -- after, top at left.
;
;----------------------------------------------------------------------
;
; Stuff for ca65 compiler
;
.debuginfo
.setcpu "65C02"

.feature c_comments
.feature string_escapes
.feature org_per_seg
.feature dollar_is_pc
.feature pc_assignment

;---------------------------------------------------------------------
; macros for dictionary, makes:
;
;   h_name:
;   .word  link_to_previous_entry
;   .byte  strlen(name) + flags
;   .byte  name
;   name:
;
; label for primitives
.macro makelabel arg1, arg2
.ident (.concat (arg1, arg2)):
.endmacro

; header for primitives
; the entry point for dictionary is h_~name~
; the entry point for code is ~name~
.macro def_word name, label, flag
makelabel "h_", label
.ident(.sprintf("H%04X", hcount + 1)) = *
.word .ident (.sprintf ("H%04X", hcount))
hcount .set hcount + 1
.byte .strlen(name) + flag + 0 ; nice trick !
.byte name
makelabel "", label
.endmacro

;---------------------------------------------------------------------
; variables for macros

hcount .set 0

H0000 = 0

;---------------------------------------------------------------------
; uncomment to include the extras (sic)
use_extras = 1 

; uncomment to include the extensions (sic)
use_extensions = 1 

DEBUG := 1

CODESTART = $0500

; cell size, two bytes, 16-bit
CELL = 2    
; highlander, immediate flag.
FLAG_IMM = 1<<7

; terminal input buffer, forward
; getline, token, skip, scan, depends on page boundary
INBUF = $0400

; reserve 80 bytes, (72 is enough) 
; moves forwards
INBUF_end = $50

; data stack, 36 cells,
; moves backwards, push decreases before copy
DSEND = $98

; return stack, 36 cells, 
; moves backwards, push decreases before copy
RTEND = $E0

; reserved for scribbles
SCRIBB = RTEND

;----------------------------------------------------------------------
; no values here or must be a BSS
.segment "ZERO"
.org $40
mainoff: 
   .res 2
endsoff:
   .res 2
ramstart:
   .res 2
TEMP1:
   .res 2
DFLAG:
   .res 1
   
.org $e0
nil:  ; empty for fixed reference

; as user variables
; order matters for hello_world.forth !

; internal Forth 

STATUS:   .word $0 ; state at lsb, last size+flag at msb
CURBUF:   .word $0 ; CURBUF next free byte in TIB
LASTHEAP:   .word $0 ; last link cell
NEXTHEAP:   .word $0 ; next free cell in heap dictionary

; pointers registers

DSPTR:    .word $0 ; data stack base,
RTPTR:    .word $0 ; return stack base
INSTPTR:    .word $0 ; instruction pointer
WORDPTR:    .word $0 ; word pointer          rename WORDPTR

; free for use

TEMP2:    .word $0 ; first
TEMP3:    .word $0 ; second
TEMP4:    .word $0 ; third    rename TEMP4
TEMP5:    .word $0 ; fourth   rename TEMP5

; used, reserved

NXTTOK:   .word $0 ; next token in tib (INBUF)
BACKHEAP:   .word $0 ; hold 'here while compile

;----------------------------------------------------------------------
;.segment "ONCE" 
; no rom code

;----------------------------------------------------------------------
;.segment "VECTORS" 
; no boot code

;----------------------------------------------------------------------
.segment "CODE" 

WRITE_CHAR = $F803
READ_CHAR = $F800
WRITE_BYTE = $F8A3
INROM = $A000

;
; leave space for page zero, hard stack, 
; and buffer, locals, forth stacks
;
; ************ the real deal...
;
.org CODESTART
    
main:
      
cold:
    cld
    jsr CLEAR          ; zero out zero page

warm:
; link list of headers
    lda #>h_exit
    sta LASTHEAP + 1
    lda #<h_exit
    sta LASTHEAP

; next heap free cell
    lda #>ends + 1
    sta NEXTHEAP + 1
    lda #0
    sta NEXTHEAP

;---------------------------------------------------------------------
; supose never change
reset:
    ldy #>INBUF
    sty DSPTR + 1
    sty RTPTR + 1
    sty CURBUF + 1
    sty NXTTOK + 1

abort:
    ldy #<DSEND
    sty DSPTR

quit:
    ldy #<RTEND
    sty RTPTR


    ldy #0          ; reset INBUF
    sty INBUF     ; clear INBUF stuff
    sty CURBUF    ; clear cursor  (pointer into INBUF)
    sty STATUS    ; status is 'interpret' == \0
    
    .byte $2c       ; mask next two bytes, nice trick !

;---------------------------------------------------------------------
; the outer loop

resolvept:
    .word okey

;---------------------------------------------------------------------
okey:

;;   uncomment for feedback
.ifdef DEBUG
    jsr DUMPREG
.endif
    lda STATUS
    bne resolve
    lda #'O'
    jsr WRITE_CHAR
    lda #'K'
    jsr WRITE_CHAR
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    
resolve:           ; get a token
    jsr token
    lda #'P'
    jsr WRITE_CHAR

find:                ; load last
    lda LASTHEAP + 1
    sta TEMP3 + 1
    lda LASTHEAP
    sta TEMP3
    
@loop:              ; lsb linked list
    lda TEMP3
    sta WORDPTR
    ora TEMP3 + 1              ; verify 00 00 if at start of list
;    beq abort             ; commented out becuz below

    bne @each              ; PGS - did he forget this?
    
;;   uncomment for feedback, comment out "beq abort" above
    lda #'?'
    jsr WRITE_CHAR
    lda #'?'
    jsr WRITE_CHAR
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jmp abort  ; end of dictionary, no more words to search, abort

@each:                        ; msb linked list 
    lda TEMP3 + 1
    sta WORDPTR + 1                        ; update next link 
    
    ldx #WORDPTR      ; from    was (WORDPTR), no such addressing mode
    ldy #TEMP3        ; into    was (TEMP3), no such addressing mode
    jsr copyfrom
    ldy #0         ; compare words
    lda (WORDPTR), y     ; save the flag, first byte is (size and flag) 
    sta STATUS + 1

; compare chars
@equal:
    lda (NXTTOK), y
    cmp #32          ; space ends
    beq @done
    sec              ; verify 
    sbc (WORDPTR), y     
    asl              ; clean 7-bit ascii
    bne @loop

; next char
    iny
    bne @equal

@done:
; update WORDPTR
    tya
    ;; ldx #(WORDPTR) ; set already
    ;; addwx also clear carry
    jsr addwx
    
eval:
; executing ? if == \0
    lda STATUS   
    beq execute

; immediate ? if < \0
    lda STATUS + 1   
    bmi immediate      

compile:
    lda #'C'
    jsr WRITE_CHAR
    jsr wcomma
    bcc resolve

immediate:
execute:

    lda #'E'
    jsr WRITE_CHAR

    lda #>resolvept
    sta INSTPTR + 1
    lda #<resolvept
    sta INSTPTR

    jmp pick

;---------------------------------------------------------------------
try:
    lda INBUF, y                   ; index is in y
    beq getline    ; if \0  - get a line if pointing at 0
    iny
    eor #$20       ; return 0 in  A if a space 
    rts

;---------------------------------------------------------------------
getline:
; drop rts of try, fall through to 'token'
    pla
    pla
    ldy #0   ; leave the first
@loop:


    sta INBUF, y  ; dummy store on first pass, overwritten
    iny
    cpy #INBUF_end
    beq @ends
@readlp:
    jsr READ_CHAR
    bcc @readlp
    cmp #$0D       
    bne @loop
    cmp #$0A
    bne @loop
@ends:                ; clear all if y eq \0
    lda #$20
    sta INBUF       ; start with space
    sta INBUF, y        ; ends with space
    lda #0            ; mark eol with \0
    sta INBUF + 1, y
; start it
    sta CURBUF

.ifdef DEBUG
    jsr DUMPREG
.endif  

;---------------------------------------------------------------------
; in place every token,
; the counter is placed at last space before word
; no rewinds
token:
    ldy CURBUF   ; last position on INBUF

@skip:   ; skip spaces
    jsr try
    beq @skip
    dey   ; keep y == <start of input word> + 1
    sty NXTTOK

@scan:  ; scan spaces
    jsr try
    bne @scan
    dey   ; keep y == <end of input word> + 1  
    sty CURBUF 

@done:  ; find size and store it
    tya
    sec
    sbc NXTTOK     
    ldy NXTTOK    ; keep it
    dey
    sta INBUF, y  ; store size for counted string 
    sty NXTTOK
    clc     ; clean - setup token
    rts

;---------------------------------------------------------------------
;  this code depends on systems or emulators
;
;  Hydra-16
; 
; exit for emulator  
byes:
    jmp $FE00

;---------------------------------------------------------------------
; decrement a word in page zero. offset by X
decwx:
    lda 0, x
    bne @ends
    dec 1, x
@ends:
    dec 0, x
    rts

;---------------------------------------------------------------------
; increment a word in page zero. offset by X
;incwx:
;    inc 0, x
;    bne @ends
;    inc 1, x
;@ends:
;    rts

;---------------------------------------------------------------------
; classic heap moves always forward
;
stawrd:
    sta WORDPTR + 1

wcomma:
    ldy #(WORDPTR)

comma: 
    ldx #(NEXTHEAP)
    ; fall throught

;---------------------------------------------------------------------
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
copyinto:
    lda 0, y
    sta (0, x)
    jsr incwx
    lda 1, y
    sta (0, x)
    jmp incwx

;---------------------------------------------------------------------
;
; generics 
;
;---------------------------------------------------------------------
spush1:
    ldy #(TEMP2)

;---------------------------------------------------------------------
; push a cell 
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
spush:
    ldx #(DSPTR)
    ; jmp push
    .byte $2c   ; mask next two bytes, nice trick !

rpush:
    ldx #(RTPTR)

;---------------------------------------------------------------------
; classic stack backwards
push:
    jsr decwx
    lda 1, y
    sta (0, x)
    jsr decwx
    lda 0, y
    sta (0, x)
    rts  

;---------------------------------------------------------------------
spull2:
    ldy #(TEMP3)
    jsr spull
    ; fall through

;---------------------------------------------------------------------
spull1:
    ldy #(TEMP2)
    ; fall through

;---------------------------------------------------------------------
; pull a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
spull:
    ldx #(DSPTR)
    ; jmp pull
    .byte $2c   ; mask next two bytes, nice trick !

rpull:
    ldx #(RTPTR)

;---------------------------------------------------------------------
; classic stack backwards
pull:   ; fall through, same as copyfrom

;---------------------------------------------------------------------
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
copyfrom:
    lda (0, x)
    sta 0, y
    jsr incwx
    lda (0, x)
    sta 1, y
    ; jmp incwx ; fall through

;---------------------------------------------------------------------
; increment a word in page zero. offset by X
incwx:
    lda #01
;---------------------------------------------------------------------
; add a byte to a word in page zero. offset by X
addwx:
    clc
    adc 0, x
    sta 0, x
    bcc @ends
    inc 1, x
    clc ; keep carry clean
@ends:
    rts

;
;  zero out $50 - $FF, meet and greet
;  zero out INBUF also
;
CLEAR:
    lda #0
    sta DFLAG
zpclear:
    ldx #0
    lda #0
zerolp:
    sta  $50,x
    inx
    bne zerolp    
    ldx #0
inbufzlp:
    sta INBUF,x
    inx
    bne inbufzlp
    
        ;  meet and greet
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    lda #'m'
    jsr WRITE_CHAR
    lda #'F'
    jsr WRITE_CHAR
    lda #'6'
    jsr WRITE_CHAR
    lda #'6'
    jsr WRITE_CHAR
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR    
    rts
;
;    
.ifdef DEBUG 
;      argh.
;   Include DEBUG code here
;   
 ;
;  debug stuff
;
DUMPTXT1:
        .byte "SP/PC/nv-bdizc/A/X/Y -> "
        .byte 0

DUMPREG:       ; dump registers safely and print
        php                     ; -3
        pha                     ; -4
        phx                     ; -5
        phy                     ; -6
        lda   DFLAG
        beq   DPFCHECK
        jmp   DREGNXT
DPFCHECK:
        ldy   #0
        lda   #$0D
        jsr   WRITE_CHAR
        lda   #$0A
        jsr   WRITE_CHAR
DUMPLP0:        
        lda   DUMPTXT1, y
        beq   DUMPCON
        jsr   WRITE_CHAR
        iny
        bra   DUMPLP0
DUMPCON:
        tsx                     ; -6
        txa
        clc
        adc   #6
        jsr   WRITE_BYTE        ; print stack pointer b4 jump
        lda   #'/'
        jsr   WRITE_CHAR 
        inx                     ; -5
        inx                     ; -4
        inx                     ; -3
        inx                     ; -2
        inx                     ; -1
        lda   $0100,x              ; get PC LSB
        tay 
        inx                     ; 0
        lda   $0100,x              ; get PC MSB
        jsr   WRITE_BYTE           
        tya
        jsr   WRITE_BYTE        
        lda   #'/'
        jsr   WRITE_CHAR  
        ;   whew
        ;
        dex                      ; -1
        dex                      ; -2
        lda   $0100,x            ; get status byte
        ldy   #8
DUMPLP2:
        rol
        pha
        bcc   DUMPSKx            ; NV-BDIZC
        lda   #$31
        bra   DUMPSKy
DUMPSKx: 
        lda   #$30      
DUMPSKy:
        jsr   WRITE_CHAR         ; print y-th bit
        pla
        dey   
        bne   DUMPLP2
        lda   #'/'
        jsr   WRITE_CHAR
        dex                       ; -3
        lda   $0100,x 
        jsr   WRITE_BYTE           ; print A
        lda   #'/'
        jsr   WRITE_CHAR
        dex                        ; -4
        lda   $0100,x 
        jsr   WRITE_BYTE           ; print X
        lda   #'/'
        jsr   WRITE_CHAR
        dex                        ; -5
        lda   $0100,x 
        jsr   WRITE_BYTE           ; print Y
        lda   #$0D
        jsr   WRITE_CHAR
        lda   #$0A
        jsr   WRITE_CHAR
DREGLP1: 
        jsr   READ_CHAR              ; wait for a key
        bcc   DREGLP1
        cmp   #'s'                  ; print out stack?
        bne   DREGSK3
        jsr   DUMPSTACK
DREGSK3:
        cmp   #'z'                  ; print out zp?
        bne  DREGSK5
        jsr  DUMPZP
DREGSK5:
        cmp   #'t'                  ; print out INBUF?
        bne  DREGSK4
        jsr  DUMPTIB
DREGSK4:        
        cmp   #'x'
        bne   DREGNXT
        jsr   $FE00                ; go to Wozmon if necc
DREGNXT:
        ply     ; and restore everything
        plx
        pla
        plp
        rts    

DUMPTIB:              ; dump TIB
        php
        pha
        ldy #0
        sty TEMP1
        lda #>INBUF
        sta TEMP1+1
        bra DSTKLP1

DUMPSTACK:            ; dump STACK
        php
        pha
        ldy #0
        sty TEMP1
        lda #1
        sta TEMP1+1
        bra DSTKLP1
DUMPZP:               ; dump ZP
        php
        pha
        ldy #0
        sty TEMP1
        sty TEMP1+1   
DSTKLP1:
        tya
        jsr WRITE_BYTE
        lda #':'
        jsr WRITE_CHAR
DSTKLP2:
        lda (TEMP1), y
        jsr WRITE_BYTE
        lda #$20
        jsr WRITE_CHAR
        iny
        tya
        and #$0F       ; 00001111  
        beq  DSTKSKL   
        bra  DSTKLP2
DSTKSKL:
        lda #$0D
        jsr WRITE_CHAR
        lda #$0A
        jsr WRITE_CHAR
        tya
        bne DSTKLP1        
DUMPSTKEND:
        lda #$0D
        jsr WRITE_CHAR
        lda #$0A
        jsr WRITE_CHAR
        pla
        plp
        rts
.endif
           
;---------------------------------------------------------------------
;
; the primitives, 
; for stacks uses
; a address, c byte ascii, w signed word, u unsigned word 
; cs counted string < 256, sz string with nul ends
; 
;----------------------------------------------------------------------

.ifdef use_extras

;----------------------------------------------------------------------
; extras
;----------------------------------------------------------------------
; ( -- ) ae exit forth
def_word "bye", "bye", 0
    jmp byes

;----------------------------------------------------------------------
; ( -- ) ae abort
def_word "abort", "abort_", 0
    jmp abort

;----------------------------------------------------------------------
; ( -- ) ae list of data stack
def_word "%S", "splist", 0
    lda DSPTR
    sta TEMP2
    lda DSPTR + 1
    sta TEMP2 + 1
    lda #'S'
    jsr WRITE_CHAR
    lda #DSEND
    jsr list
    jmp next

;----------------------------------------------------------------------
; ( -- ) ae list of return stack
def_word "%R", "rplist", 0
    lda RTPTR
    sta TEMP2
    lda RTPTR + 1
    sta TEMP2 + 1
    lda #'R'
    jsr WRITE_CHAR
    lda #RTEND
    jsr list
    jmp next

;----------------------------------------------------------------------
;  ae list a sequence of references
list:

    sec
    sbc TEMP2
    lsr

    tax

    lda TEMP2 + 1
    jsr puthex
    lda TEMP2
    jsr puthex

    lda #' '
    jsr WRITE_CHAR

    txa
    jsr puthex

    lda #' '
    jsr WRITE_CHAR

    txa
    beq @ends

    ldy #0
@loop:
    lda #' '
    jsr WRITE_CHAR
    iny
    lda (TEMP2),y 
    jsr puthex
    dey
    lda (TEMP2),y 
    jsr puthex
    iny 
    iny
    dex
    bne @loop
@ends:
    rts
    
;----------------------------------------------------------------------
; ( -- ) dumps the user dictionary
def_word "dump", "dump", 0

    lda #$0
    sta TEMP2
    lda #>ends + 1
    sta TEMP2 + 1

    ldx #(TEMP2)
    ldy #0

@loop:
    
    lda (TEMP2),y
    jsr WRITE_CHAR
    jsr incwx

    lda TEMP2
    cmp NEXTHEAP
    bne @loop

    lda TEMP2 + 1
    cmp NEXTHEAP + 1
    bne @loop

    clc  ; clean
    jmp next 

;----------------------------------------------------------------------
; ( -- ) words in dictionary, 
def_word "words", "words", 0

; load lastest
    lda LASTHEAP + 1
    sta TEMP3 + 1
    lda LASTHEAP
    sta TEMP3

; load here
    lda NEXTHEAP + 1
    sta TEMP4 + 1
    lda NEXTHEAP
    sta TEMP4
    
@loop:
; lsb linked list
    lda TEMP3
    sta TEMP2

; verify \0x0
    ora TEMP3 + 1
    beq @ends

; msb linked list
    lda TEMP3 + 1
    sta TEMP2 + 1

@each:    

    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    
; put address
    lda #' '
    jsr WRITE_CHAR

    lda TEMP2 + 1
    jsr puthex
    lda TEMP2
    jsr puthex

; put link
    lda #' '
    jsr WRITE_CHAR

    ldy #1
    lda (TEMP2), y
    jsr puthex
    dey 
    lda (TEMP2), y
    jsr puthex

    ldx #(TEMP2)
    lda #2
    jsr addwx

; put size + flag, name
    ldy #0
    jsr show_name

; update
    iny
    tya
    ldx #(TEMP2)
    jsr addwx

; show CFA

    lda #' '
    jsr WRITE_CHAR
    
    lda TEMP2 + 1
    jsr puthex
    lda TEMP2
    jsr puthex

; check if is a primitive
    lda TEMP2 + 1
    cmp #>ends + 1
    bmi @continue

; list references
    ldy #0
    jsr show_refer

@continue:
    
    lda TEMP3
    sta TEMP4
    lda TEMP3 + 1
    sta TEMP4 + 1

    ldy #0
    lda (TEMP4), y
    sta TEMP3
    iny
    lda (TEMP4), y
    sta TEMP3 + 1

    ldx #(TEMP4)
    lda #2
    jsr addwx

    jmp @loop 

@ends:
    clc  ; clean
    jmp next

;----------------------------------------------------------------------
; ae put size and name 
show_name:
    lda #' '
    jsr WRITE_CHAR

    lda (TEMP2), y
    jsr puthex
    
    lda #' '
    jsr WRITE_CHAR

    lda (TEMP2), y
    and #$7F
    tax

 @loop:
    iny
    lda (TEMP2), y
    jsr WRITE_CHAR
    dex
    bne @loop

@ends:
    rts

;----------------------------------------------------------------------
show_refer:
; ae put references PFA ... 

    ldx #(TEMP2)

@loop:
    lda #' '
    jsr WRITE_CHAR

    lda TEMP2 + 1
    jsr puthex
    lda TEMP2
    jsr puthex

    lda #':'
    jsr WRITE_CHAR
    
    iny 
    lda (TEMP2), y
    jsr puthex
    dey
    lda (TEMP2), y
    jsr puthex

    lda #2
    jsr addwx

; check if ends

    lda TEMP2
    cmp TEMP4
    bne @loop
    lda TEMP2 + 1
    cmp TEMP4 + 1
    bne @loop

@ends:
    rts

;----------------------------------------------------------------------
;  ae seek for 'exit to ends a sequence of references
;  max of 254 references in list
;
seek:
    ldy #0
@loop1:
    iny
    beq @ends

    lda (TEMP2), y
    cmp #>exit
    bne @loop1

    dey 
    lda (TEMP2), y
    cmp #<exit
    beq @ends
    
    iny
    bne @loop1

@ends:
    tya
    lsr
    clc  ; clean
    rts

;----------------------------------------------------------------------
; ( u -- u ) print tos in hexadecimal, swaps order
def_word ".", "dot", 0
    lda #' '
    jsr WRITE_CHAR
    jsr spull1
    lda TEMP2 + 1
    jsr puthex
    lda TEMP2
    jsr puthex
    jsr spush1
    jmp next

;----------------------------------------------------------------------
; code a byte in ASCII hexadecimal 
puthex:
    pha
    lsr
    ror
    ror
    ror
    jsr @conv
    pla
@conv:
    and #$0F
    ora #$30
    cmp #$3A
    bcc @ends
    adc #$06
@ends:
    clc  ; clean
    jmp WRITE_CHAR

.endif


.ifdef numbers
;----------------------------------------------------------------------
; code a ASCII $FFFF hexadecimal in a byte
;  
number:

    ldy #0

    jsr @very
    asl
    asl
    asl
    asl
    sta TEMP2 + 1

    iny 
    jsr @very
    ora TEMP2 + 1
    sta TEMP2 + 1
    
    iny 
    jsr @very
    asl
    asl
    asl
    asl
    sta TEMP2

    iny 
    jsr @very
    ora TEMP2
    sta TEMP2

    clc ; clean
    rts

@very:
    lda (NXTTOK), y
    sec
    sbc #$30
    bmi @erro
    cmp #10
    bcc @ends
    sbc #$07
    ; any valid digit, A-Z, do not care 
@ends:
    rts

@erro:
    pla
    pla
    rts

.endif

;---------------------------------------------------------------------
;
; extensions
;
;---------------------------------------------------------------------
.ifdef use_extensions

;---------------------------------------------------------------------
; ( w -- w/2 ) ; shift right
def_word "2/", "shr", 0
    jsr spull1
    lsr TEMP2 + 1
    ror TEMP2
    jmp this

;---------------------------------------------------------------------
; ( a -- ) execute a jump to a reference at top of data stack
def_word "exec", "exec", 0 
    jsr spull1
    jmp (TEMP2)

;---------------------------------------------------------------------
; ( -- ) execute a jump to a reference at IP
def_word ":$", "docode", 0 
    jmp (INSTPTR)

;---------------------------------------------------------------------
; ( -- ) execute a jump to next
def_word ";$", "donext", 0 
    jmp next

.endif

;---------------------------------------------------------------------
; core primitives minimal 
; start of dictionary
;---------------------------------------------------------------------
; ( -- u ) ; tos + 1 unchanged
def_word "key", "key", 0
KEYRDLP:
    jsr READ_CHAR
    bcc KEYRDLP
    sta TEMP2
    ; jmp this  ; uncomment if char could be \0
    bne this    ; always taken
    
;---------------------------------------------------------------------
; ( u -- ) ; tos + 1 unchanged
def_word "emit", "emit", 0
    jsr spull1
    lda TEMP2
    jsr WRITE_CHAR
    ; jmp next  ; uncomment if carry could be set
    bcc jmpnext ; always taken

;---------------------------------------------------------------------
; ( a w -- ) ; [a] = w
def_word "!", "store", 0
storew:
    jsr spull2
    ldx #(TEMP3) 
    ldy #(TEMP2) 
    jsr copyinto
    ; jmp next  ; uncomment if carry could be set
    bcc jmpnext ; always taken

;---------------------------------------------------------------------
; ( w1 w2 -- NOT(w1 AND w2) )
def_word "nand", "nand", 0
    jsr spull2
    lda TEMP3
    and TEMP2
    eor #$FF
    sta TEMP2
    lda TEMP3 + 1
    and TEMP2 + 1
    eor #$FF
    ; jmp keeps  ; uncomment if carry could be set
    bcc keeps ; always taken

;---------------------------------------------------------------------
; ( w1 w2 -- w1+w2 ) 
def_word "+", "plus", 0
    jsr spull2
    clc  ; better safe than sorry
    lda TEMP3
    adc TEMP2
    sta TEMP2
    lda TEMP3 + 1
    adc TEMP2 + 1
    jmp keeps

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0
fetchw:
    jsr spull1
    ldx #(TEMP2)
    ldy #(TEMP3)
    jsr copyfrom
    ; fall throught

;---------------------------------------------------------------------
copys:
    lda 0, y
    sta TEMP2
    lda 1, y

keeps:
    sta TEMP2 + 1

this:
    jsr spush1

jmpnext:
    jmp next

;---------------------------------------------------------------------
; ( 0 -- $0000) | ( n -- $FFFF) not zero at top ?
def_word "0#", "zeroq", 0
    jsr spull1
    lda TEMP2 + 1
    ora TEMP2
    beq isfalse  ; is \0 ?
istrue:
    lda #$FF
isfalse:
    sta TEMP2                                                         
    jmp keeps  

;---------------------------------------------------------------------
; ( -- state ) a variable return an reference
def_word "s@", "state", 0 
    lda #<STATUS
    sta TEMP2
    lda #>STATUS
    ;  jmp keeps ; uncomment if stats not in page $0
    beq keeps   ; always taken

;---------------------------------------------------------------------
def_word ";", "semis",  FLAG_IMM
; update last, panic if colon not lead elsewhere 
    lda BACKHEAP 
    sta LASTHEAP
    lda BACKHEAP + 1 
    sta LASTHEAP + 1

; stat is 'interpret'
    lda #0
    sta STATUS

; compound words must ends with exit
finish:
    lda #<exit
    sta WORDPTR
    lda #>exit
    sta WORDPTR + 1
    jsr wcomma

    ; jmp next
    bcc next    ; always taken

;---------------------------------------------------------------------
def_word ":", "colon", 0
; save here, panic if semis not follow elsewhere
    lda NEXTHEAP
    sta BACKHEAP 
    lda NEXTHEAP + 1
    sta BACKHEAP + 1 

; stat is 'compile'
    lda #1
    sta STATUS

@header:
; copy last into (here)
    ldy #(LASTHEAP)
    jsr comma

; get following token
    jsr token

; copy it
    ldy #0
@loop:    
    lda (NXTTOK), y
    cmp #32    ; stops at space
    beq @ends
    sta (NEXTHEAP), y
    iny
    bne @loop

@ends:
; update here 
    tya
    ldx #(NEXTHEAP)
    jsr addwx

;~~~~~~~~

; done
    ; jmp next
    bcc next    ; always taken

;---------------------------------------------------------------------
; Thread Code Engine
;
;   INSTPTR is IP, WORDPTR is W
;
; for reference: 
;
;   nest aka enter or docol, 
;   unnest aka exit or semis;
;
;---------------------------------------------------------------------
; ( -- ) 
def_word "exit", "exit", 0
unnest: ; exit
; pull, INSTPTR = (RTPTR), RTPTR += 2 
    ldy #(INSTPTR)
    jsr rpull

next:
; WORDPTR = (INSTPTR) ; INSTPTR += 2
    ldx #(INSTPTR)
    ldy #(WORDPTR)
    jsr copyfrom

pick:
; compare pages (MSBs)
    lda WORDPTR + 1
    cmp #>ends + 1
    bmi jump

nest:   ; enter
; push, *rp = INSTPTR, rp -=2
    ldy #(INSTPTR)
    jsr rpush

    lda WORDPTR
    sta INSTPTR
    lda WORDPTR + 1
    sta INSTPTR + 1

    jmp next

jump: 
    jmp (WORDPTR)

;~~~~~~~~

;-----------------------------------------------------------------------
; BEWARE, MUST BE AT END! MINIMAL THREAD CODE DEPENDS ON IT!
ends:

;-----------------------------------------------------------------------
; anything above is not a primitive
;----------------------------------------------------------------------
FFILL:
        .res $342
COPYMAIN = main - CODESTART + INROM
RAMST = main
COPYENDS = ends - CODESTART + INROM

COPYTORAM:
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    ;
    lda #>COPYMAIN
    sta mainoff+1  
    lda #<COPYMAIN
    sta mainoff
    ;
    lda #<COPYENDS
    sta endsoff
    lda #>COPYENDS
    sta endsoff+1
    ;
    lda #>RAMST
    sta ramstart+1
    jsr WRITE_BYTE
    lda #<RAMST
    sta ramstart
    jsr WRITE_BYTE
    ;
    ldy  #0
COPYLOOP:
    lda (mainoff),y
    sta (ramstart),y
    lda mainoff
    cmp endsoff
    bne SKIP1
    lda mainoff+1
    cmp endsoff+1
    beq COPYEXIT
SKIP1:
    lda #'.'
    jsr WRITE_CHAR
    inc mainoff
    inc ramstart
    bne COPYLOOP
    inc mainoff+1
    inc ramstart+1
    ldy #0
    beq COPYLOOP
COPYEXIT:
    lda ramstart+1
    jsr WRITE_BYTE
    lda ramstart
    jsr WRITE_BYTE
     lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR   
    jmp $FE00
;
;             zero out zp $50-$FF
ZEROZERO:
    ldx #0
    lda #0
ZEROLP:
    sta  $50,x
    inx
    bne ZEROLP
    rts

    