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
.debuginfo
.setcpu "65C02"

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
;---------------------------------------------------------------------
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

;---------------------------------------------------------------------
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
;               CONFIGURATION OPTIONS
;---------------------------------------------------------------------

; number conversion
numbers := 1      ; include DEC/BIN/HEX conversion
NEWNUMS := 1
SINGLE := 1     ; single digits hard coded?

DEBUG := 1        ; enable inclusion of debug code

HYWORDS := 1      ; add in some hardcoded numbers / logic

;---------------------------------------------------------------------
;                     for PGS hyforth stuff
;
; error codes
;
ERR_PTR := $01
ERR_NUM := $02
ERR_MEM := $03
ERR_UKW := $04
;
;---------------------------------------------------------------------
;                CHARACTER CONSTANTS
BACKSPC := $08
CR := $0D
LF := $0A

;
;                 CORE ENGINE CONSTANTS
;
CODESTART = $0600

; cell size, two bytes, 16-bit
CELL = 2    
; highlander, immediate flag.
FLAG_IMM = 1<<7

; terminal input buffer, forward
; getline, token, skip, scan, depends on page boundary
; INBUF = $0400  (see segment STACKS below)
; moves forwards
INBUF_end = $FF

; data stacks
; moves backwards, push decreases before copy
DSEND = $7E

; return stack
; moves backwards, push decreases before copy
RTEND = $FE

; reserved for scribbles
SCRIBB = RTEND

WRITE_CHAR = $F803
READ_CHAR = $F800
WRITE_BYTE = $F8A3
WOZMON = $FE00
INROM = $A000

;----------------------------------------------------------------------
;                   ZERO PAGE USAGE
;----------------------------------------------------------------------
.segment "ZP"
.org $D8

;
;                   HyForth setup stuff
;
DFLAG:
   .res 1          ; debug flag
ERRFLAG:
   .res 1          ; error type, 0 = none
ERRPTR:
   .res 2          ; ptr to mitigation/message
DIGBASE:
   .res 1          ; base for number conversion
SCR1:        
   .res 2          ; spare space
SCR2:
   .res 1          ; spare space
;
;
nil:               ; at $E0 now
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

mainoff:                            ; use for COPYTORAM
TEMP1:    .word $0 ; first
endsoff:
TEMP2:    .word $0 ; second
ramstart:
TEMP3:    .word $0 ; third   
TEMP0:
TEMP4:    .word $0 ; fourth 

; used, reserved

NXTTOK:   .word $0 ; next token in tib (INBUF)
BACKHEAP:   .word $0 ; hold 'here while compile
;
;  $FC - $FF in reserve
;
;   HYDRA-16 read buffer usually at $200 or $300?  Avoid conflict for now...
;
;----------------------------------------------------------------------
;                   FORTH STACKS
;----------------------------------------------------------------------
.segment "STACKS"
.org $0400
INBUF:
      .res 256
DS:                          ; data stack (S)
      .res 126
      .res 2
RT:                          ; return stack (R)
      .res 126
      .res 2
;
;
.segment "ROM"              ; regular core
;
;
; ************ the real deal...
;
.org $A000
    
main:
    jmp cold
    jmp COPYTORAM

cold:
    cld
    jsr CLEAR          ; zero out zero page, INBUF, DS, and RT

warm:
; link list of headers
    lda #>h_exit
    sta LASTHEAP + 1
    lda #<h_exit
    sta LASTHEAP

; next heap free cell 
    lda #>ends + 1
    sta NEXTHEAP + 1
    stz NEXTHEAP
    stz ERRFLAG                ; clear ERROR flag

;---------------------------------------------------------------------
; various reinitialization points
;
reset:
    ldy #>INBUF                 ; INBUF (TIB) page
    sty CURBUF + 1
    sty NXTTOK + 1
    
    ldy #>DS                     ; DS and RT are now half page each
    sty DSPTR + 1
    ldy #>RT    
    sty RTPTR + 1 
    
    lda #1                       ; DEBUG OFF by default
    sta DFLAG    
    
abort:                            ; clear DS
    ldy #<DSEND
    sty DSPTR
quit:                             ; clear RT
    ldy #<RTEND
    sty RTPTR

errrtn:                          ; DS/RT pointers left alone
    jsr wrterror                 ; print any error messages   
    ldy #0          ; reset INBUF
    stz INBUF     ; clear INBUF stuff
    stz CURBUF    ; clear cursor  (pointer into INBUF)
    stz STATUS    ; status is 'interpret' == \0
    
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
    
    lda DFLAG                 ; DEBUG
    bne RVPSKIP    
    WCRLF_np
    lda #'P'
    jsr WRITE_CHAR            ; DEBUG
    
RVPSKIP:

find:                ; load last word on heap
    lda LASTHEAP + 1
    sta TEMP2 + 1
    lda LASTHEAP
    sta TEMP2
    
RESLOOP:              ; lsb linked list
    lda TEMP2
    sta WORDPTR
    ora TEMP2+1             ; only zero if both are zero
    bne RESEACH              ; PGS - did he forget this?                       
                           
WORDNOTFOUND:                          
    ;WSEQ NOT_OKAY            ; "?!" message
    lda #ERR_UKW
    sta ERRFLAG
    jmp errrtn ; end of dictionary, no more words to search, abort

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
;
; immediate ? if < \0
    lda STATUS + 1   
    bmi immediate      
;
compile:
    lda DFLAG
    bne CMPSKIP    
    WCRLF_np
    lda #'C'
    jsr WRITE_CHAR   
CMPSKIP:
    jsr wcomma
    bcs immediate
    jmp resolve
;    
immediate:
execute:
    lda DFLAG
    bne EXESKIP    
    WCRLF_np
    lda #'E'
    jsr WRITE_CHAR 
EXESKIP:
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
    jsr DUMPREG                        ; DEBUG
    
    tya
    sec
    sbc NXTTOK     
    ldy NXTTOK    ; keep it
    dey
    sta INBUF, y  ; store size for counted string 
    sty NXTTOK
    ;
    ;  During interpretive mode at least...do number conversions here, before 
    ;  looking at word list; will be pushed on stack.
    ;
    ;  This SHOULD have a general digit converter (any base up to 16); return C = 1 if no conversion
    ;   if SINGLE is defined, this will skip single digit numbers and use hardcoded ones.
    ;
.ifdef NEWNUMS
      ldy #0
      lda (NXTTOK),y
      tax                ; store size in X, pass to conversion 
      jsr DIGCONVT
      bcs TOKENEND       ; if some error in conversion, skip
      ; falls through to TOKCLR0
.endif  ; 'new nums' switching

TOKCLR0:
      ldy #0
      lda (NXTTOK),y
      tax
      inx      
      lda #$20
TOKCLR:
      sta (NXTTOK),y
      iny
      dex
      bne TOKCLR
      
      jsr DUMPREG
      
      jmp token               ; and get next token
                              ; maybe works?
TOKENEND:
    jsr DUMPREG
    
    clc     ; clean - setup token  
    rts

;---------------------------------------------------------------------
;          decwx, heap moves (comma/wcomma?  why?)
;
; decrement a word in page zero. offset by X
decwx:
    lda 0, x
    bne decwx_end
    dec 1, x
decwx_end:
    dec 0, x
    rts

;---------------------------------------------------------------------
; heap linked list (moves forward)
;
wcomma:
    ldy #WORDPTR                  ; copy addr at WORDPTR, change addr fld NEXTHEAP points to
comma: 
    ldx #NEXTHEAP                 ; Y has source of address, change addr fld NEXTHEAP points to
    ; fall through - to?  copyinto, then rts
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
    jmp incwx                        ; incwx ends with rts!
;---------------------------------------------------------------------
;
; generics - PUSH, PULL, incwx/addwx, copyfrom
;
;------------------------PUSH a cell--------------------------------
spush_2:
    ldy #TEMP3       ; push TEMP3 on top
    jmp spush
spush_1:
    ldy #TEMP2       ; push TEMP2 on top
    jmp spush        
spush_0:             ; push TEMP1 to stack, probably top of stack
    ldy #TEMP1
     ; fall through
;---------------------------------------------------------------------
; PUSH a cell 
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
spush:
    ldx #DSPTR
    lda DSPTR
    cmp #<DS                ; ditto
    beq ptrerr              ; ditto
    jmp push
rpush:
    ldx #RTPTR
    lda RTPTR               ; ditto
    cmp #<RT                ; ditto
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
;
;                      pointer error (DS or RT)
ptrerr:                      ; pop jsr off stack, throw error
    lda #ERR_PTR
    sta ERRFLAG
    pla
    pla
    jmp errrtn
;
;---------------------------PULL a cell------------------------------------
;
spull_2:
    ldy #TEMP3              ; pull TEMP3 from top
    jmp spull
;
spull_1:                    ; pull TEMP2 from top
    ldy #TEMP2
    jmp spull                 ; why was it jsr?
;
;---------------------------------------------------------------------
spull_0:
    ldy #TEMP1             ; pull TEMP1 from top of DS
;
; PULL a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
;
spull:
    ldx #DSPTR
    lda DSPTR         ; pointer bounds checking
    cmp #DSEND        ; ditto
    beq ptrerr        ; ditto
    jmp pull
rpull:
    ldx #RTPTR
    lda RTPTR        ; pointer bounds checking
    cmp #RTEND        ; ditto
    beq ptrerr        ; ditto

;---------------------------------------------------------------------
;
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
pull:
copyfrom:
    lda (0, x)
    sta 0, y
    jsr incwx
    lda (0, x)
    sta 1, y
  ; fall through to increment, then return
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
    bcc addwx_end
    inc 1, x
    clc ; keep carry clean
addwx_end:
    rts
    
ENGINEEND:
;                           END OF CORE ENGINE
;----------------------------------------------------------------------
;
;
;------------------------------------------------------------------------
;    UPPER RAM stuff.  error messaging, CLEAR on start, debug, utilities
;------------------------------------------------------------------------
;
upper_ram:
.include "upper.s"
UPPER_END:
;
;------------------------------------------------------------------------
;                            ROM ONLY stuff
;
.include "hyf_rom.s"
;
ROMCODEEND:                         ; end of all code
;-----------------------------------------------------------------------
;                            TRAINING DATA
;
; include training data
    .res 16
.include "ftrain.s"
;
;  end of hyforth.s
;

    .res 16

COPYSTART:
.segment "CODE"
.org $0600
RAMSTART:
     jmp main                   ; should be at $A000 now
     
primitives:
.include "primitives.s"
;
;---------------------ADD IN EXTRA HARDCODED LOGIC / NUMERALS / ETC--
.ifdef HYWORDS
   .include "hywords.s"
.endif
;---------------------------------------------------------------------
;   real core functions
;
;---------------------------------------------------------------------
;   COMPILE (:), FINISH (;), FETCH (@), STORE (!)
;      including:  keeps, this, next, finish
;       ...and other stuff.
;---------------------------------------------------------------------
; ( a -- ) execute a jump to a reference at top of data stack
def_word "exec", "exec", 0 
    jsr spull_0
    jmp (TEMP1)        ; assumes an address on top of DS

;---------------------------------------------------------------------
; ( -- ) execute a jump to a reference at IP
def_word ":$", "docode", 0 
    jmp (INSTPTR)                 ;  DOCODE (thus the ':')

;---------------------------------------------------------------------
; ( -- ) execute a jump to next
def_word ";$", "donext", 0        ;  'next' (thus the ';')
    jmp next
;---------------------------------------------------------------------
;
; ( w a -- ) ; [a] = w    (w is word, a is an address)          
def_word "!", "store", 0 
storew:
    jsr spull_1             ; get address, store in TEMP2
    jsr spull_0             ; get data, store in TEMP1
    ldx #TEMP2              ;  [a]
    ldy #TEMP1              ;   w
    jsr copyinto            ; copy TEMP2 stuff to addr in TEMP1 (opposite of @)..
    jmp next                ;            ...(see below)
;
;--------------------------------------------FETCH--------------------
; ( a -- w ) ; w = [a]     
def_word "@", "fetch", 0      ; replace addr of data on top of DS, with data pointed to
fetchw:
    jsr spull_0             ; get addr from DS
    ldx #TEMP1
    ldy #TEMP2
    jsr copyfrom            ; copies data from [TEMP1] => TEMP2
;---------------------------------------------------------------------
;            NEXT entry point for most primitives
;---------------------------------------------------------------------
copys:                      ; copy from cell at y (zp) to TEMP1
    lda 0, y               
    sta TEMP1
    lda 1, y
keeps:                      ; saves bytes since have to get here anyway
    sta TEMP1 + 1
this:                       ; same as above
    jsr spush_0             ; then pushes on stack?
;jmpnext:                   ; is this label needed?  apparently not...
    jmp next

;-----------------------IMMEDIATE, '[', ']', ','-----------------------
def_word "I", "Imm", 0   
wimm:                        ; jmp here if proccessing a compiled
    lda LASTHEAP+1                ;  ...word that needs to be 'immediate'.
    sta TEMP4+1
    lda LASTHEAP               ; get addr of 'last' compiled word
    clc
    adc #2                     ; calc where length byte is
    sta TEMP4                  
    bcc IMMSKIP
    inc TEMP4+1
IMMSKIP:
    ldy #0
    lda (TEMP4),y
    ora #$80                 ; set bit 7 and store
    sta (TEMP4),y
    jmp next

def_word "[", "leftbrack", FLAG_IMM       ; switch to 'interpretive mode?'
    stz STATUS
    jmp next

def_word "]", "rtbrack", 0               ; and then back to compile?
    lda #1
    sta STATUS
    jmp next
    
def_word ",", "xcomma", 0
    jsr spull_0
    ldy #0
    lda TEMP1
    sta (NEXTHEAP),y
    iny
    lda TEMP1+1
    sta (NEXTHEAP),y
    lda NEXTHEAP
    clc
    adc #2
    sta NEXTHEAP
    bcc COMMASKIP
    inc NEXTHEAP+1
COMMASKIP:
    jmp next
    
;--------------------------------------------SEMIS-----------------
def_word ";", "semis",  FLAG_IMM
; update LASTHEAP, panic if colon not lead elsewhere 
    lda BACKHEAP 
    sta LASTHEAP
    lda BACKHEAP + 1 
    sta LASTHEAP + 1

; stat is 'interpret'
    stz STATUS

; compound words must ends with exit
finish:
    lda #<exit
    sta WORDPTR
    lda #>exit
    sta WORDPTR + 1
    jsr wcomma                  ; change NEXTHEAP to point to addr of 'exit'

    jmp next
;
;
;------------------------------------------COMPILE------------------
def_word ":", "colon", 0
; save here, panic if semis not follow elsewhere
    lda NEXTHEAP
    sta BACKHEAP 
    lda NEXTHEAP + 1
    sta BACKHEAP + 1 

; stat is 'compile'
    lda #1
    sta STATUS

COMPHEADER:
; copy LASTHEAP into (NEXTHEAP)
    ldy #LASTHEAP
    jsr comma                    ; change NEXTHEAP to point to LASTHEAP

; keep processing tokens
    jsr token

; copy it
    ldy #0
COMPLOOP:    
    lda (NXTTOK), y
    cmp #$20            ; stops at space
    beq COMPEND
    sta (NEXTHEAP), y
    iny
    bne COMPLOOP

COMPEND:
; update here - only copies...one byte?
    tya
    ldx #(NEXTHEAP)
    jsr addwx

;~~~~~~~~ all done....
    jmp next
;---------------------------------------------------------------------
; Thread Code Engine
;
;   INSTPTR is IP, WORDPTR is W
;
;     unnest, next, pick, nest, and jump
;
;   nest aka ENTER or DOCOL  (do colon?)
;   unnest aka EXIT or semis?
;
;---------------------------------------------------------------------
; ( -- ) 
def_word "exit", "exit", 0
unnest:                      ;    this is EXIT but not all of it...
; get IP from RT, incr RTPTR: INSTPTR = [RTPTR], RTPTR += 2 
    ldy #INSTPTR
    jsr rpull

next:                        ;    go on to next word, update W, incr IP
; WORDPTR = (INSTPTR) ; INSTPTR += 2
    ldx #INSTPTR
    ldy #WORDPTR
    jsr copyfrom

pick:                      ; FIX, this sucks - NEED TO SWITCH a DIFFERENT WAY here
; compare pages (MSBs)
    lda WORDPTR + 1
    cmp #>ends + 1
    bmi jump              ; jump over nest if not a compiled word

nest:   ; enter
; push, *rp = INSTPTR, rp -=2   ; push [IP] on RT, decrement RTPTR
    ldy #INSTPTR
    jsr rpush
    lda WORDPTR                 ; update IP to W
    sta INSTPTR
    lda WORDPTR + 1
    sta INSTPTR + 1
    jmp next

jump: 
    jmp (WORDPTR)

;~~~~~~~~
           
;-----------------------------------------------------------------------
; BEWARE, MUST BE AT END! MINIMAL THREAD CODE DEPENDS ON IT!
;
ends:                            ; end marker of hardcoded primitives
;
;-----------------------------------------------------------------------
;
;

    