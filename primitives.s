;
; primitives.s
;
;
;----------------------------------------------------------------------
; ( -- ) ae exit forth
def_word "bye", "bye", 0
    jmp WOZMON               ; jump to WOZMON

;----------------------------------------------------------------------
; ( -- ) ae abort
def_word "abort", "abort_", 0
    jmp abort

; ( -- ) resets buffer to INBUF
def_word "reset", "reset_", 0
    jmp reset

; ( -- ) interpreter 'resolve'
;def_word "interp", "interp", FLAG_COM
;okey:
;    jmp resolve

;----------------------------------------------------------------------
; ( -- ) ae list of data stack
def_word ".S", "splist", 0       ; changed from %S
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

; ( -- ) data stack empty?
def_word "?S", "spp", 0
    stz TEMP1+1
    stz TEMP1
    lda DSPTR
    cmp #DSEND
    bne SPPEND
    lda #$FF
    sta TEMP1
SPPEND:
    jsr spush_0
    jmp next

; ( -- ) return stack empty?
def_word "?R", "rtp", 0
    stz TEMP1+1
    stz TEMP1
    lda RTPTR
    cmp #RTEND
    bne RTPEND
    lda #$FF
    sta TEMP1
RTPEND:
    jsr spush_0
    jmp next   
    
;----------------------------------------------------------------------
; ( -- ) ae list of return stack
def_word ".R", "rplist", 0       ; changed from %R
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
;  list a sequence of references ( for .S and .R )
list:
    sec                 ; calc diff and length of list
    sbc TEMP1
    lsr
    tax                 ; hide in X
    lda TEMP1 + 1       ; print addr of pointer
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE
    lda #' '
    jsr WRITE_CHAR
    txa
    jsr WRITE_BYTE         ; print # of entries
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
    jsr WRITE_BYTE
    dey
    lda (TEMP1),y 
    jsr WRITE_BYTE
    iny 
    iny
    dex
    bne @loop
@ends:
    rts
    
;------------------------------- ODUMP AND DUMP ---------------------------------------
; ( -- ) dumps the user dictionary
;    ( REMOVED as of 4/19/26 )

; ( -- ) dump memory
def_word "dump", "dump", 0
    jsr spull_1             ; TEMP2 LSB is # of pages
    jsr spull_0             ; TEMP1 has starting addr 
    lda TEMP1+1
    sta TEMP0+1
    ldx TEMP2
    bne FDUMPLOOP
    ldx #1                  ; always print at least one page
FDUMPLOOP:
    jsr DUMPPAGE
    inc TEMP0+1
FDUMPGET:
    jsr READ_CHAR           ; wait for char to continue to next page
    bcc FDUMPGET
    dex
    bne FDUMPLOOP
    clc
    jmp next
    
;------------------------------ WLIST -----------------------------------
;
; ( -- ) clean word list, 
def_word "words", "words", 0

; load LASTHEAP
    lda LASTHEAP + 1
    sta TEMP2 + 1
    lda LASTHEAP
    sta TEMP2

; load NEXTHEAP
    lda NEXTHEAP + 1
    sta TEMP3 + 1
    lda NEXTHEAP
    sta TEMP3
    stz TEMP5
    dec TEMP5
    
WORD_LOOP:
    inc TEMP5       ; increment 'words per line' count
    lda TEMP2       ; lsb linked list
    sta TEMP1
    ora TEMP2 + 1    ; check if TEMP2 = $0000, end if so
    beq WORD_END
    lda TEMP2 + 1    ; msb linked list
    sta TEMP1 + 1
    
    lda TEMP5        ; check word count, CRLF if 4th one
    cmp #4
    bne WORD_SKIP
    WCRLF_np
    stz TEMP5
    
WORD_SKIP:               ; TEMP1 has address of work-record, 
; put address            ; (TEMP1) is link to previous record
    lda #' '
    jsr WRITE_CHAR
    lda TEMP1 + 1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE

    ldx #TEMP1          ; advance TEMP1 to size + flag, name
    lda #2
    jsr addwx
    ldy #0                
    jsr show_name        ; put size + flag, name
    
    lda #10
    sec
    sbc TEMP6
    tax
SPCLOOP:
    lda #' '
    jsr WRITE_CHAR
    dex
    bne SPCLOOP
    lda #'|'
    jsr WRITE_CHAR
    
    iny                  ; update TEMP1 again, point at CFA
    tya
    ldx #TEMP1
    jsr addwx

     lda TEMP3           ; instead of printing refs, just advance TEMP1 to TEMP3
     sta TEMP1
     lda TEMP3+1
     sta TEMP1+1

WORD_CONT:
    lda TEMP2            ; update TEMP2 and TEMP3, advance in linked list
    sta TEMP3
    lda TEMP2 + 1
    sta TEMP3 + 1
    ldy #0
    lda (TEMP3), y
    sta TEMP2
    iny
    lda (TEMP3), y
    sta TEMP2 + 1
    ldx #(TEMP3)
    lda #2
    jsr addwx

    jmp WORD_LOOP 

WORD_END:
    clc  ; clean
    jmp next
;
;-------------------------------------- WORDS ---------------------
; ( -- ) words in dictionary, 
;def_word "oldw", "oldw", 0
;
;  removed 4/24/26 - see previous versions of 'primitives.s'
;
;----------------------------------------------------------------------
;
;  routines needed for 'words'
;
; print size and name 
show_name:
     lda #':'
     jsr WRITE_CHAR
;    lda (TEMP1), y
;    jsr WRITE_BYTE       ; size
    
    lda #' '
    jsr WRITE_CHAR
    lda (TEMP1), y
    and #$3F           ; mask off top two bits
    tax
    sta TEMP6          ; save length of name
    
NAMELOOP:              ; name
    iny
    lda (TEMP1), y
    jsr WRITE_CHAR
    dex
    bne NAMELOOP
    lda #' '
    jsr WRITE_CHAR
    rts

;----------------------------------------------------------------------
;
;  holdover from original 'words' but keep for now
;
show_refer:
; print references (PFA - parameter field addresses) 
;    ldx #(TEMP1)
;
;SHWREFLOOP:
;    lda #' '
;    jsr WRITE_CHAR
;    lda TEMP1 + 1
;    jsr WRITE_BYTE
;    lda TEMP1
;    jsr WRITE_BYTE
;    lda #':'
;    jsr WRITE_CHAR
;    iny 
;    lda (TEMP1), y
;    jsr WRITE_BYTE
;    dey
;    lda (TEMP1), y
;    jsr WRITE_BYTE
;    lda #2
;    jsr addwx
;
; check if at the end
;    lda TEMP1
;    cmp TEMP3
;    bne SHWREFLOOP
;    lda TEMP1 + 1
;    cmp TEMP3 + 1
;    bne SHWREFLOOP
;    rts
;
;----------------------------------------------------------------------
;  seek for addr of 'exit' at end of sequence of references
;  max of 254 references in list
;
;  removed 'seek', was not used in original code

;----------------------------------------------------------------------
; ( u -- u ) print top of DS in hexadecimal in MSB:LSB form
def_word ".", "dot", 0
    lda #' '
    jsr WRITE_CHAR
    jsr spull_0
    lda TEMP1 + 1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE
    jmp this      ; 'this' includes jsr spush_0 and next
    
; ( u -- u ) print top of DS in ascii, two bytes, msb first
def_word ".C", "cdot", 0
    jsr spull_0
    lda TEMP1 + 1
    jsr WRITE_CHAR
    lda TEMP1
    jsr WRITE_CHAR
    jmp this       ; 'this' includes jsr spush_0 and next

; (u u ... -- ) print zero term'd, packed string or all of stack as ascii
def_word ".sz", "szdot",0
SZLOOP:
    lda DSPTR
    cmp #DSEND
    beq SZEND
    jsr spull_0
    lda TEMP1 + 1
    beq SZEND
    jsr WRITE_CHAR
    lda TEMP1
    beq SZEND
    jsr WRITE_CHAR    
    bra SZLOOP
SZEND:
    jmp next
;---------------------------------------------------------------------
;
; extensions
;
;---------------------------------------------------------------------
extensions:

;---------------------------------------------------------------------
; ( w n -- w >> n ) ; shift right
def_word ">>", "shr", 0
    jsr spull_1
    lda TEMP2
    beq SRZERO
    jsr spull_0
SRLOOP:
    lsr TEMP1 + 1
    ror TEMP1
    dec TEMP2
    bne SRLOOP
    jmp this         ; 'this' includes jsr spush_0 and next
SRZERO:
    jmp next
    
; ( w n -- w << n ) ; shift left
def_word "<<", "shl", 0
    jsr spull_1
    lda TEMP2
    beq SLZERO
    jsr spull_0
SLLOOP:
    asl TEMP1
    rol TEMP1 + 1
    dec TEMP2
    bne SLLOOP
    jmp this         ; 'this' includes jsr spush_0 and next
SLZERO:
    jmp next

;--------------- bit test/set/clear ----------------------------------
; ( n b -- t? )
def_word "tbit", "tbit", 0            ; nondestructive test bit
    jsr spull_1     ; which bit
    lda TEMP2
    and #$0F        ; only want 0-16
    sta TEMP2
    jsr spull_0
    jsr spush_0     ; backup!
    jsr BITWIND
    lda TEMP1
    and #$01
    beq TBCLR      ; test bit 0
    lda #$FF
    sta TEMP1
    sta TEMP1+1
    bra TBITEND
TBCLR:
    stz TEMP1
    stz TEMP1+1
TBITEND:
    jmp this

; ( n b -- ns )    
def_word "sbit", "sbit", 0             ; set bit
    jsr spull_1     ; which bit
    lda TEMP2
    and #$0F        ; only want 0-16
    sta TEMP2
    jsr spull_0
    jsr BITWIND
    lda TEMP1
    ora #$01        ; set bit 0
    sta TEMP1
    jsr BITUNWIND
    jmp this
    
; ( n b -- nc )    
def_word "cbit", "cbit", 0
    jsr spull_1     ; which bit
    lda TEMP2
    and #$0F        ; only want 0-16
    sta TEMP2
    jsr spull_0     
    jsr BITWIND
    lda TEMP1
    and #$FE       ; clear bit 0
    sta TEMP1
    jsr BITUNWIND
    jmp this

BITWIND:
    stz TEMP3
    stz TEMP3+1
    ldx TEMP2
    beq BITWSKIP
BITWLOOP:
    lsr TEMP1+1
    ror TEMP1
    ror TEMP3+1
    ror TEMP3
    dex
    bne BITWLOOP
BITWSKIP:
    rts
    
BITUNWIND:
    ldx TEMP2
    beq BITUWSKIP
BITUNWLOOP:
    asl TEMP3
    rol TEMP3+1
    rol TEMP1
    rol TEMP1+1
    dex
    bne BITUNWLOOP
BITUWSKIP:
    rts
;---------------------------------------------------------------------
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
    jmp this         ; 'this' includes jsr spush_0 and next    
    
;---------------------------------------------------------------------
; ( u -- ) ; tos + 1 unchanged
def_word "emit", "emit", 0
    jsr spull_0
    lda TEMP1
    jsr WRITE_CHAR
    jmp next

;---------------------------------------------------------------------
; ( w1 w2 -- NOT(w1 AND w2) )
def_word "nand", "nand", 0
    jsr spull_1             ; load TEMP2, TEMP1 from stack
    jsr spull_0
    lda TEMP2
    and TEMP1
    eor #$FF            ; toggles FIRST byte okay, but...
    sta TEMP1
    lda TEMP2 + 1
    and TEMP1 + 1
    eor #$FF           ; and then second.
                       ; sta TEMP1 + 1 at 'keeps', then jsr spush_0 and 'next'
    jmp keeps  ; uncomment if carry could be set

;---------------------PLUS and MINUS----------------------------------
; ( w1 w2 -- w1+w2 ) 
def_word "+", "plus", 0
    jsr spull_1        ; load TEMP2 from stack
    jsr spull_0        ; then TEMP1
    clc         
    lda TEMP2
    adc TEMP1
    sta TEMP1
    lda TEMP2 + 1
    adc TEMP1 + 1     
                    ; sta TEMP1 + 1 at 'keeps', then jsr spush_0 and 'next'
    jmp keeps

; ( w1 w2 -- w1-w2 )          
def_word "-", "minus", 0
    jsr spull_1        ; get TEMP 2 from stack
    jsr spull_0        ; then TEMP 1       
    sec        
    lda TEMP1
    sbc TEMP2
    sta TEMP1
    lda TEMP1 + 1
    sbc TEMP2 + 1     
                   ; sta TEMP1 + 1 at 'keeps', then jsr spush_0 and 'next'
    clc            ; not sure why, but just in case?
    jmp keeps    
    
;---------------------------------------------------------------------
; ( 0 -- $0000) | ( n -- $FFFF)  normalize boolean - change TOS to $0000 if false, $FFFF if TRUE
def_word "nb", "normbool", 0
    jsr spull_0
    lda TEMP1 + 1
    ora TEMP1    ; only zero if both are zero
    beq isfalse  ; is = 0?
istrue:
    lda #$FF
isfalse:
    sta TEMP1             ; keeps includes sta TEMP +1, then jsr spush_0, then jmp next                                           
    jmp keeps            ; urgh.  if zero on top of DS, push back zero; otherwise push $FF

;---------------------------------------------------------------------
; ( -- state ) pushes addr of status word on stack
def_word "s@", "state", 0
    lda #<STATUS
    sta TEMP1
    lda #>STATUS
    jmp keeps   ; pushes addr of status word on stack?  keeps includes sta TEMP+1 etc.

.ifdef DEBUG
;------------------------ADDED for HyForth debugging-------
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
.endif
;
;------------------------END of primitives.s
;