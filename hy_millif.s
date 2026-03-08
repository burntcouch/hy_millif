;----------------------------------------------------------------------
;
;  Patrick Struthers - March 2026
;      - THANKS to AGSB for the starting point here....
;
;  The HyForth project starts here with AGSB's core Forth engine;
;  the engine will be moved to ROM and the heap will be copied to RAM
;  on cold start.
;  
;  The ulitmate purpose of working this port through is to develop a
;  flexible and powerful operating system for the Hydra-16 of reasonable
;  efficiency and minimal memory footprint.  HyForth will grow and 
;  shrink in RAM footprint according to context.
;
; ---------------------------------------------------------------------
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

.feature string_escapes
.feature org_per_seg
.feature dollar_is_pc
.feature pc_assignment

;---------------------------------------------------------------------
; macros for dictionary, creates code as follows:
;
;   h_name:
;   .word  link_to_previous_entry
;   .byte  strlen(name) + flags
;   .byte  name
;   name:
;
; label for primitives
;
.macro makelabel arg1, arg2
.ident (.concat (arg1, arg2)):
.endmacro
;
; header for primitives
; the entry point for dictionary is h_~name~
; the entry point for code is ~name~
;
.macro def_word name, label, flag
makelabel "h_", label
.ident(.sprintf("H%04X", hcount + 1)):
  .word .ident (.sprintf ("H%04X", hcount))
hcount .set hcount + 1
  .byte .strlen(name) + flag + 0 ; nice trick !
  .byte name
makelabel "", label
.endmacro
;
;  macros for PGS stuff
;
.macro WCRLF_np                ; no push of A
       lda #CR
       jsr WRITE_CHAR
       lda #LF
       jsr WRITE_CHAR
.endmacro

.macro WCRLF
       pha
       lda #CR
       jsr WRITE_CHAR
       lda #LF
       jsr WRITE_CHAR
       pla
.endmacro

.macro  WSEQ_np  strlbl
     phy
     ldy #0
@wsqloop:
     lda strlbl, y
     beq @wsqend
     iny
     jsr WRITE_CHAR
     bra @wsqloop
@wsqend:
     WCRLF_np
     ply
.endmacro

.macro WSEQ  strlbl
      pha
      WSEQ_np  strlbl
      pla
.endmacro

;
;  for error messages
;
.macro ERR_entry errmsg
    .byte <errmsg
    .byte >errmsg
    emcount .set emcount + 1
.endmacro

.macro WERR errptr
;.macro WERR
    .local werrloop, werrend
    WCRLF_np
    ldy #0
    lda (errptr),y
    sta TEMP0
    iny
    lda (errptr),y
    sta TEMP0+1
    ldy #0
werrloop:
    lda (TEMP0),y
    beq werrend
    iny
 ;   jsr DUMPREG
    jsr WRITE_CHAR
    bra werrloop
werrend:    
    WCRLF_np
    rts
.endmacro
;---------------------------------------------------------------------
; variables for macros

hcount .set 0
emcount .set 0             ; # of error messages set up

H0000 = 0

;---------------------------------------------------------------------
; uncomment to include the extras (sic)
use_extras := 1 

; uncomment to include the extensions (sic)
use_extensions := 1 

numbers := 1

;
;  for PGS hyforth stuff
;
; error codes
;
ERR_PTR := $01
ERR_NUM := $02
ERR_MEM := $03
ERR_UKW := $04

BACKSPC := $08
CR := $0D
LF := $0A

DEBUG := 1

CODESTART = $0600

; cell size, two bytes, 16-bit
CELL = 2    
; highlander, immediate flag.
FLAG_IMM = 1<<7

; terminal input buffer, forward
; getline, token, skip, scan, depends on page boundary
; INBUF = $0400  (see segment STACKS below)

; reserve 255 bytes, (72 is enough) 
; moves forwards
INBUF_end = $FF

; data stack, 36 cells,
; moves backwards, push decreases before copy
DSEND = $7E

; return stack, 36 cells, 
; moves backwards, push decreases before copy
RTEND = $FE

; reserved for scribbles
SCRIBB = RTEND

WRITE_CHAR = $F803
READ_CHAR = $F800
WRITE_BYTE = $F8A3
INROM = $A000

;----------------------------------------------------------------------
; no values here or must be a BSS
.segment "ZP"
.org $D0

mainoff: 
   .res 2          ; ptr to start of main
endsoff:
   .res 2          ; ptr to ends
ramstart:
   .res 2          ; start of code
TEMP0:
   .res 2          ; temp
DFLAG:
   .res 1          ; debug flag
ERRFLAG:
   .res 1          ; error type, 0 = none
ERRPTR:
   .res 2          ; ptr to mitigation/message
SCRATCH:        
   .res 4          ; spare space

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

TEMP1:    .word $0 ; first
TEMP2:    .word $0 ; second
TEMP3:    .word $0 ; third    rename TEMP3
TEMP4:    .word $0 ; fourth   rename TEMP4

; used, reserved

NXTTOK:   .word $0 ; next token in tib (INBUF)
BACKHEAP:   .word $0 ; hold 'here while compile

.segment "STACKS"
.org $0400
INBUF:
      .res 256
DS:
      .res 126
      .res 2
RT:
      .res 126
      .res 2
      
.segment "CODE" 

;
; leave space for page zero, hard stack, 
; and buffer, locals, forth stacks
;
; ************ the real deal...
;
.org $0600
    
main:
    jmp cold
;
;  various handy strings
;   
RSV_OKAY:
    .byte "....OK"
    .byte 0
NOT_OKAY:
    .byte " ?!?"
    .byte 0  
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
    sta ERRFLAG                ; clear ERROR flag

;---------------------------------------------------------------------
; various reinitialization points
;
reset:
    ldy #>INBUF                 ; DS, TIB and RT all in same page
                     
    sty CURBUF + 1
    sty NXTTOK + 1
    
    ldy #>DS                     ; DS and RT are now half page each
    sty DSPTR + 1
    ldy #>RT    
    sty RTPTR + 1 
    
abort:
    lda #0
    sta DFLAG
  ;  jsr DUMPREG
    
    jsr wrterror                 ; print any error messages

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
   ; WSEQ_np RSV_OKAY   ;-- more trouble than worth right now
    
resolve:           ; get a token
    jsr token
    
.ifdef DEBUG
    lda DFLAG
    bne RVPSKIP    
    WCRLF_np
    lda #'P'
    jsr WRITE_CHAR
RVPSKIP:
.endif

find:                ; load last
    lda LASTHEAP + 1
    sta TEMP2 + 1
    lda LASTHEAP
    sta TEMP2
    
RESLOOP:              ; lsb linked list
    lda TEMP2
    sta WORDPTR
    ora TEMP2+1             ; only zero if both are zero
    bne RESEACH              ; PGS - did he forget this?
                           ; MAY be the big fix.  Nothing quite
                           ; right before hand, but the logic
                           ; seemed right.
                     
    jsr DEC2BIN      ; no words matched, so check for valid number    
    bcc RESEACH      ; and put on stack
                    ; or jmp to WORDNOTFOUND if no match.                          
                           
WORDNOTFOUND:                          
    ;WSEQ NOT_OKAY            ; "?!" message
    lda #ERR_UKW
    sta ERRFLAG
    jmp abort  ; end of dictionary, no more words to search, abort

RESEACH:                        ; msb linked list 
    lda TEMP2 + 1
    sta WORDPTR + 1           ; update next link 
    
    ldx #WORDPTR       
    ldy #TEMP2      
    jsr copyfrom
    ldy #0              ; compare words
    lda (WORDPTR), y    ; save the flag, first byte is (size and flag) 
    sta STATUS + 1

; compare chars
@equal:
    lda (NXTTOK), y
    cmp #$20            ; space ends
    beq @done
    sec                 ; verify 
    sbc (WORDPTR), y     
    asl                 ; clean 7-bit ascii
    bne RESLOOP

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

.ifdef DEBUG
    lda DFLAG
    bne CMPSKIP    
    WCRLF_np
    lda #'C'
    jsr WRITE_CHAR
CMPSKIP:
.endif
 
    jsr wcomma
    bcs immediate
    jmp resolve
    
immediate:
execute:

.ifdef DEBUG
    lda DFLAG
    bne EXESKIP    
    WCRLF_np
    lda #'E'
    jsr WRITE_CHAR
EXESKIP:
.endif
    
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
    cmp #CR      
    beq @ends
    cmp #BACKSPC         ; handle backspace
    bne @loop
    dey
    dey
    lda INBUF, y      ; make sure prev char not overwritten
    bra @loop
@ends:                ; clear all if y eq \0
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    lda #$20
    sta INBUF       ; start with space
    sta INBUF, y        ; ends with space
    lda #0            ; mark eol with \0
    sta INBUF + 1, y
; start it
    sta CURBUF


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
byes:
    jmp $FE00                   ; exit to WozMon

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
; classic heap moves always forward
;
wcomma:
    ldy #WORDPTR                  ; dammit, quit using parens!
comma: 
    ldx #NEXTHEAP                 ; dammit, quit using parens!
    ; fall through
;---------------------------------------------------------------------
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
;
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
;------------------------PUSH a cell--------------------------------
spush_0:             ; push TEMP1 to stack, probably top of stack
    ldy #TEMP1

;---------------------------------------------------------------------
; PUSH a cell 
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
spush:
    ldx #DSPTR
    lda DSPTR
    cmp #<DS
    beq ptrerr
    jmp push
rpush:
    ldx #RTPTR
    lda RTPTR
    cmp #<RT
    beq ptrerr
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

ptrerr:
    lda #ERR_PTR
    sta ERRFLAG
    pla
    pla
    jmp abort
;
;---------------------------PULL a cell------------------------------------
spull_1:                    ; pull from TEMP2 from stack
    ldy #TEMP2
    jsr spull
    ; fall through

;---------------------------------------------------------------------
spull_0:
    ldy #TEMP1             ; pull from TEMP1 from stack
    ; fall through

;-------------------------------------------------------
; PULL a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
spull:
    ldx #DSPTR
    lda DSPTR
    cmp #DSEND
    beq ptrerr
    jmp pull
rpull:
    ldx #RTPTR
    lda RTPTR
    cmp #RTEND
    beq ptrerr

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
; add a byte in A to a word in page zero. offset by X
addwx:
    clc
    adc 0, x
    sta 0, x
    bcc @ends
    inc 1, x
    clc ; keep carry clean
@ends:
    rts
;---------------------------------------------------------------------
;  error messaging
;
wrterror:
    lda #>err_jumptable
    sta ERRPTR+1
    lda ERRFLAG
    beq ERREND
    asl a
;    jsr DUMPREG
    clc
    adc #<err_jumptable
;    jsr DUMPREG
    sta ERRPTR
    bcc ERRSKIP
    inc ERRPTR+1
ERRSKIP:
    WERR ERRPTR
ERREND:
    lda #0
    sta ERRFLAG
    sta ERRPTR
    sta ERRPTR+1
    rts
;
;  
err_jumptable:
    .res 2
    ERR_entry PTR_ERR    ; stack full  - error 1
    ERR_entry NUM_ERR    ; number not right - error 2
    ERR_entry OOM_ERR    ; out of memory  - error 3
    ERR_entry UKW_ERR    ; no existing word - error 4
LASTERR = 4
;
;  error messages
PTR_ERR:
    .byte " !PTR ERROR!"
    .byte 0
NUM_ERR:
    .byte " !BAD #!"
    .byte 0
OOM_ERR:
    .byte " !LOW MEM!"
    .byte 0
UKW_ERR:
    .byte " !UNK WORD!"
    .byte 0
;
;----------------------------------------------------------------------
;    
primitives:

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
    sta TEMP1
    lda DSPTR + 1
    sta TEMP1 + 1
    WCRLF_np
    lda #'S'
    jsr WRITE_CHAR
    lda #DSEND
    jsr list
    WCRLF_np
    jmp next

;----------------------------------------------------------------------
; ( -- ) ae list of return stack
def_word "%R", "rplist", 0
    lda RTPTR
    sta TEMP1
    lda RTPTR + 1
    sta TEMP1 + 1
    WCRLF_np
    lda #'R'
    jsr WRITE_CHAR
    lda #RTEND
    jsr list
    WCRLF_np
    jmp next

;----------------------------------------------------------------------
;  list a sequence of references
list:

    sec                 ; calc diff and length of list
    sbc TEMP1
    lsr

    tax                 ; hide in X

    lda TEMP1 + 1       ; print addr of pointer
    jsr puthex
    lda TEMP1
    jsr puthex

    lda #' '
    jsr WRITE_CHAR

    txa
    jsr puthex         ; print # of entries?

    lda #' '
    jsr WRITE_CHAR

    txa
    beq @ends

    ldy #0
@loop:
    lda #' '
    jsr WRITE_CHAR
    iny
    lda (TEMP1),y 
    jsr puthex
    dey
    lda (TEMP1),y 
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
    sta TEMP1
    lda #>ends + 1
    sta TEMP1 + 1

    ldx #TEMP1
    ldy #0

@loop:
    lda TEMP1
    cmp NEXTHEAP
    bne @dumpcont
    lda TEMP1+1
    cmp NEXTHEAP+1
    beq @dumpend
@dumpcont:    
    lda (TEMP1),y
    jsr WRITE_BYTE          ; was WRITE_CHAR
    lda #$20
    jsr WRITE_CHAR
    jsr incwx
    bra @loop
    
@dumpend:    
    WCRLF_np
    clc  ; clean
    jmp next 

;----------------------------------------------------------------------
; ( -- ) words in dictionary, 
def_word "words", "words", 0

.ifdef DEBUG
    jsr DUMPREG
.endif  

; load last
    lda LASTHEAP + 1
    sta TEMP2 + 1
    lda LASTHEAP
    sta TEMP2

; load here
    lda NEXTHEAP + 1
    sta TEMP3 + 1
    lda NEXTHEAP
    sta TEMP3
    
WORDLOOP1:

.ifdef DEBUG
    jsr DUMPREG
.endif  

; lsb linked list
    lda TEMP2
    sta TEMP1

; verify \0x0
    ora TEMP2 + 1
    bne WORDSKIP1
    jmp WORDSEND
    
WORDSKIP1:
; msb linked list
    lda TEMP2 + 1
    sta TEMP1 + 1

    WCRLF_np
    
; put address
    lda #' '
    jsr WRITE_CHAR

    lda TEMP1 + 1
    jsr puthex
    lda TEMP1
    jsr puthex

; put link
    lda #' '
    jsr WRITE_CHAR

    ldy #1
    lda (TEMP1), y
    jsr puthex
    dey 
    lda (TEMP1), y
    jsr puthex

    ldx #TEMP1
    lda #2
    jsr addwx

; put size + flag, name
    ldy #0
    jsr show_name

; update
    iny
    tya
    ldx #TEMP1
    jsr addwx

; show CFA
    lda #' '
    jsr WRITE_CHAR
    
    lda TEMP1 + 1
    jsr puthex
    lda TEMP1
    jsr puthex

; check if is a primitive
    lda TEMP1 + 1
    cmp #>ends + 1
    bmi WORDSCONT

; list references
    ldy #0
    jsr show_refer

WORDSCONT:
    
    lda TEMP2
    sta TEMP3
    lda TEMP2 + 1
    sta TEMP3 + 1

    ldy #0
    lda (TEMP3), y
    sta TEMP2
    iny
    lda (TEMP3), y
    sta TEMP2 + 1

    ldx #TEMP3
    lda #2
    jsr addwx

    jmp WORDLOOP1

WORDSEND:
    WCRLF_np
    clc  ; clean
    jmp next

;----------------------------------------------------------------------
; ae put size and name 
show_name:
    lda #' '
    jsr WRITE_CHAR

    lda (TEMP1), y
    jsr puthex
    
    lda #' '
    jsr WRITE_CHAR

    lda (TEMP1), y
    and #$7F
    tax

SHWNAMELOOP1:
    iny
    lda (TEMP1), y
    jsr WRITE_CHAR
    dex
    bne SHWNAMELOOP1
    rts

;----------------------------------------------------------------------
show_refer:
; ae put references PFA ... 

    ldx #(TEMP1)

SHWREFLOOP:
    lda #' '
    jsr WRITE_CHAR

    lda TEMP1 + 1
    jsr puthex
    lda TEMP1
    jsr puthex

    lda #':'
    jsr WRITE_CHAR
    
    iny 
    lda (TEMP1), y
    jsr puthex
    dey
    lda (TEMP1), y
    jsr puthex

    lda #2
    jsr addwx

; check if ends

    lda TEMP1
    cmp TEMP3
    bne SHWREFLOOP
    lda TEMP1 + 1
    cmp TEMP3 + 1
    bne SHWREFLOOP
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

    lda (TEMP1), y
    cmp #>exit
    bne @loop1

    dey 
    lda (TEMP1), y
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
    jsr spull_0
    lda TEMP1 + 1
    jsr puthex
    lda TEMP1
    jsr puthex
    jsr spush_0
    jmp next

;----------------------------------------------------------------------
; code a byte into ASCII hexadecimal 
puthex:
    pha                    ; hide it
    lsr                    ; shift down msb nybble
    ror
    ror
    ror
    jsr @conv             ; jump below to print it
    pla                   ; pull again
@conv:
    and #$0F              ; mask off msb nybble
    ora #$30
    cmp #$3A
    bcc @ends
    adc #$06
@ends:
    clc  ; clean
    jsr WRITE_CHAR
    rts                    ; sigh.  clever but susceptible to assplosion

.ifdef numbers

mult16:


;----------------------------------------------------------------------
; code a ASCII decimal into a # and put on stack
;  
;  ASCII digits to 16-bit hex number, signed
;
DEC2BIN:
    ldy #0
    sty TEMP4
    sty TEMP1
    sty TEMP1 + 1
    lda (NXTTOK), y
    cmp #'-'
    bne D2BSKIP3
    inc TEMP4           ; store sign
    iny          
D2BLOOP:
    pha
    asl TEMP1           ; multx10: shift left twice,
    rol TEMP1 + 1
    asl TEMP1
    rol TEMP1 + 1
    pla    
    clc                    
    adc TEMP1            ; ...add again,
    sta TEMP1
    bcc D2BSKIP2
    inc TEMP1 + 1
D2BSKIP2:
    asl TEMP1           ; ...shift left once.
    rol TEMP1 + 1
D2BSKIP3:
    jsr GETDEC
    bcs XDECERR
    clc                ; and add next digit
    adc TEMP1
    bcc D2BSKIP4
    inc TEMP1 + 1
D2BSKIP4:
    iny
    lda TEMP1 + 1
    cmp #$80
    bcc D2BLOOP
    jsr XDECERR
D2BCONT:    
    ldy TEMP4
    beq D2BEXIT
    eor #$FF          ; 1's complement
    sta TEMP1 + 1
    lda TEMP1 + 1
    eor #$FF
    sta TEMP1
    inc TEMP1
    bcc D2BEXIT
    inc TEMP1 + 1
D2BEXIT:
    clc
    jmp keeps
    
GETDEC:
    lda (NXTTOK), y
    cmp #$20
    bne  GETDECCONT
    pla
    pla
    jmp  D2BCONT
GETDECCONT:
    sec
    sbc #$30
    bmi XDECERR         ; branch and gobble rts if not a digit
    cmp #10
    bcc GETDECEND       ; carry set means not a digit
    jmp XDECERR
GETDECEND:
    rts
    
XDECERR:
    pla
    pla
    sec               ; carry set means error
    rts

;
;  this APPEARS to convert four hex ASCII charactes into two BCD bytes -> TEMP1 (16 bits)
;  sigh.  This is NOT something that '+' can work with.  Need a real binary conversion.
number:

    ldy #0

    jsr @very
    asl
    asl
    asl
    asl
    sta TEMP1 + 1

    iny 
    jsr @very
    ora TEMP1 + 1
    sta TEMP1 + 1
    
    iny 
    jsr @very
    asl
    asl
    asl
    asl
    sta TEMP1

    iny 
    jsr @very
    ora TEMP1
    sta TEMP1

    clc ; clean
    rts

@very:
    lda (NXTTOK), y
    sec
    sbc #$30
    bmi @erro           ; branch and gobble rts if not a digit
    cmp #10
    bcc @ends
    sbc #$07
    ; any valid digit, A-Z, do not care 
@ends:
    rts

@erro:
    pla             ; gobble rts from @very?  Dammit!
    pla
    rts            ; return from number w/o doing anything

.endif

;---------------------------------------------------------------------
;
; extensions
;
;---------------------------------------------------------------------
extensions:

;---------------------------------------------------------------------
; ( w -- w/2 ) ; shift right
def_word "2/", "shr", 0
    jsr spull_0
    lsr TEMP1 + 1
    ror TEMP1
    ;jmp this  
    jsr spush_0

;---------------------------------------------------------------------
; ( a -- ) execute a jump to a reference at top of data stack
def_word "exec", "exec", 0 
    jsr spull_0
    jmp (TEMP1)

;---------------------------------------------------------------------
; ( -- ) execute a jump to a reference at IP
def_word ":$", "docode", 0 
    jmp (INSTPTR)

;---------------------------------------------------------------------
; ( -- ) execute a jump to next
def_word ";$", "donext", 0 
    jmp next



;---------------------------------------------------------------------
; core primitives minimal 
; start of dictionary
;---------------------------------------------------------------------
core_dict:

;---------------------------------------------------------------------
; ( -- u ) ; tos + 1 unchanged
def_word "key", "key", 0
KEYRDLP:
    jsr READ_CHAR
    bcc KEYRDLP
    sta TEMP1
    jmp this    
    
;---------------------------------------------------------------------
; ( u -- ) ; tos + 1 unchanged
def_word "emit", "emit", 0
    jsr spull_0
    lda TEMP1
    jsr WRITE_CHAR
    jmp next  ; uncomment if carry could be set

;---------------------------------------------------------------------
; ( a w -- ) ; [a] = w
def_word "!", "store", 0
storew:
    jsr spull_1
    ldx #TEMP2
    ldy #TEMP1
    jsr copyinto
    jmp next  ; uncomment if carry could be set

;---------------------------------------------------------------------
; ( w1 w2 -- NOT(w1 AND w2) )
def_word "nand", "nand", 0
    jsr spull_1             ; load TEMP1 from stack
    lda TEMP2
    and TEMP1
    eor #$FF            ; toggles FIRST byte okay, but...
    sta TEMP1
    lda TEMP2 + 1
    and TEMP1 + 1
    eor #$FF
     ; sta TEMP1 + 1 at 'keeps'
    jmp keeps  ; uncomment if carry could be set

;---------------------------------------------------------------------
; ( w1 w2 -- w1+w2 ) 
def_word "+", "plus", 0
    jsr spull_1        ; load TEMP1 from stack
    clc         
    lda TEMP2
    adc TEMP1
    sta TEMP1
    lda TEMP2 + 1
    adc TEMP1 + 1     ; sta TEMP1 + 1 at 'keeps'
    jmp keeps

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0
fetchw:
    jsr spull_0
    ldx #(TEMP1)
    ldy #(TEMP2)
    jsr copyfrom
    ; fall through

;---------------------------------------------------------------------
copys:
    lda 0, y
    sta TEMP1
    lda 1, y

keeps:
    sta TEMP1 + 1

this:
    jsr spush_0

jmpnext:
    jmp next
    
;---------------------------------------------------------------------
; ( 0 -- $0000) | ( n -- $FFFF) not zero at top ?
def_word "0#", "zeroq", 0
    jsr spull_0
    lda TEMP1 + 1
    ora TEMP1
    beq isfalse  ; is \0 ?
istrue:
    lda #$FF
isfalse:
    sta TEMP1                                                         
    jmp keeps  

;---------------------------------------------------------------------
; ( -- state ) a variable return an reference
def_word "s@", "state", 0 
    lda #<STATUS
    sta TEMP1
    lda #>STATUS
    jmp keeps   ; always taken

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

    jmp next

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
    ldy #LASTHEAP
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
    jmp next
    ;bcc next    ; always taken

;----------------------------------------------------------------------
; ( -- ) toggle debug
def_word "debug", "debug", 0
     lda DFLAG
     cmp #1
     beq @make0
     lda #1
     bra @store
@make0:
     lda #0
@store:
     sta DFLAG   
     jmp next

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
    ldy #INSTPTR
    jsr rpull

next:
; WORDPTR = (INSTPTR) ; INSTPTR += 2
    ldx #INSTPTR
    ldy #WORDPTR
    jsr copyfrom

pick:
; compare pages (MSBs)
    lda WORDPTR + 1
    cmp #>ends + 1
    bmi jump

nest:   ; enter
; push, *rp = INSTPTR, rp -=2
    ldy #INSTPTR
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
;
;
.org $7000
;  zero out $E0 - $FF, meet and greet
;  zero out INBUF also
;
debug_ram:
    .res 32
HYWELCOME:
    .byte CR, LF
    .byte "HyForth 0.1 03-2026"
    .byte CR, LF, $00
CLEAR:
    lda #1
    sta DFLAG                 ; debug OFF by default
zpclear:
    ldx #$E0                  ; whoops, this is all the ZP that is used
    lda #0
zerolp:
    sta  $00,x
    inx
    bne zerolp    
    ldx  #0
inbufzlp:                      ; and then clear out INBUF
    sta  INBUF,x
    inx
    bne  inbufzlp
    ldx  #0
stackslp:                      ; and then clear out DS / RT
    sta  DS,x
    inx
    bne  stackslp
        ;  meet and greet
    ldy  #0
hywelclp:
    lda  HYWELCOME,y
    beq  CLREXIT
    jsr  WRITE_CHAR
    iny
    bra  hywelclp 
CLREXIT:    
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
DUMPMSG1:
        .byte "<spc> to continue, x for Wozmon, z for ZP, t for TIB, s for stack"
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
        WCRLF_np
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
        WCRLF_np
        ldy   #0
DUMPLP1:                               ; print message
        lda   DUMPMSG1, y
        beq   DREGLP1
        jsr   WRITE_CHAR
        iny
        bra   DUMPLP1        
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
        sty TEMP0
        lda #>INBUF
        sta TEMP0+1
        bra DSTKLP1

DUMPSTACK:            ; dump STACK
        php
        pha
        ldy #0
        sty TEMP0
        lda #1
        sta TEMP0+1
        bra DSTKLP1
DUMPZP:               ; dump ZP
        php
        pha
        ldy #0
        sty TEMP0
        sty TEMP0+1   
DSTKLP1:
        tya
        jsr WRITE_BYTE
        lda #':'
        jsr WRITE_CHAR
DSTKLP2:
        lda (TEMP0), y
        jsr WRITE_BYTE
        lda #$20
        jsr WRITE_CHAR
        iny
        tya
        and #$0F       ; 00001111  
        beq  DSTKSKL   
        bra  DSTKLP2
DSTKSKL:
        WCRLF_np
        tya
        bne DSTKLP1        
DUMPSTKEND:
        WCRLF_np
        pla
        plp
        rts
.endif
DEBUG_END:
;
;  COPYTORAM
;
FFILL:
        .res $80
        
COPYMAIN = main - CODESTART + INROM
RAMST = main
COPYENDS = ends - CODESTART + INROM

DBGST = ends - CODESTART + INROM
DBGRAMST = debug_ram
DBGEND = DBGST + DEBUG_END - debug_ram

COPYTORAM:
    WCRLF_np
    WCRLF_np
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
    ldx  #2
DEBUGTORAM:
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
    bne SKIP2
    inc mainoff + 1
SKIP2:
    inc ramstart
    bne SKIP3
    inc ramstart+1
SKIP3:
    bra COPYLOOP
COPYEXIT:
    lda ramstart+1
    jsr WRITE_BYTE
    lda ramstart
    jsr WRITE_BYTE
    WCRLF_np
;
;       now do debug stuff
    dex
    beq  CPEND
    lda #>DBGST
    sta mainoff+1  
    lda #<DBGST
    sta mainoff
    ;
    lda #<DBGEND
    sta endsoff
    lda #>DBGEND
    sta endsoff+1
    ;
    lda #>DBGRAMST
    sta ramstart+1
    jsr WRITE_BYTE
    lda #<DBGRAMST
    sta ramstart
    jsr WRITE_BYTE
    bra DEBUGTORAM
CPEND:    
    jmp $FE00

CODEEND: 
; include training data
    .res 16
.include "ftrain.s"
     


    