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
def_word "odump", "odump", 0
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
def_word "wlist", "wlist", 0
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
    stz TEMP6       ; keep track of words per line
  
    WCRLF_np  
WLSTLOOP1:
    ANSI $30,'m'     ; clear attributes
    inc TEMP6        ; count # of words per line
    lda TEMP2        ; lsb linked list
    sta TEMP1
    ora TEMP2 + 1    ; check if $0000  (end of list)
    bne WLSTSKIP1
    jmp WLSTEND  
WLSTSKIP1:
    lda TEMP2 + 1    ; msb linked list
    sta TEMP1 + 1    ; TEMP1 stores addr of current word now

; print address
    lda #' '
    jsr WRITE_CHAR

    lda TEMP1 + 1 
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE
    
    ldx #TEMP1     ; skip over link address
    lda #2
    jsr addwx
                   ; put size + flag, name
    ldy #0
    jsr show_name   ; return size in TEMP5
                    ; print some spaces based on length of name
    lda #12
    sec
    sbc TEMP5
    tax
WLSTSPCS:
    lda #$20
    jsr WRITE_CHAR
    dex
    bne WLSTSPCS
    lda TEMP6
    cmp #4
    bne WLSTUPD
    WCRLF_np        ; CR if 4th word   
    stz TEMP6
WLSTUPD:
    iny             ; update to point to CFA (code field address)
    tya
    ldx #TEMP1
    jsr addwx       

; check if is a primitive  - FIX THIS, ANOTHER WAY NECC.
;    ANSI $33, $31, 'm'

    lda TEMP2            ; backup TEMP2  ( here -> next )
    sta TEMP3
    lda TEMP2 + 1
    sta TEMP3 + 1

    ldy #0
    lda (TEMP3), y      ;  [TEMP3] -> TEMP2  ( [here] -> TEMP2 ) 
    sta TEMP2
    iny
    lda (TEMP3), y
    sta TEMP2 + 1       ;  so now TEMP2 points to previous word in list 

    ldx #TEMP3            ; TEMP3 += 2     (points at PFA of next word)
    lda #2
    jsr addwx

    jmp WLSTLOOP1

WLSTEND: 
    ANSI $30,'m'     ; clear attributes
    WCRLF_np
    clc  ; clean
    jmp next
;
;-------------------------------------- WORDS ---------------------
; ( -- ) words in dictionary, 
def_word "words", "words", 0

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
    lda TEMP2        ; lsb linked list
    sta TEMP1
    ora TEMP2 + 1    ; check if $0000
    bne WORDSKIP1
    jmp WORDSEND  
WORDSKIP1:

    lda TEMP2 + 1    ; msb linked list
    sta TEMP1 + 1

    WCRLF_np
    
; print address
    lda #'-'
    jsr WRITE_CHAR

    lda TEMP1 + 1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE

; print link
    lda #'-'
    jsr WRITE_CHAR

    ldy #1
    lda (TEMP1), y
    jsr WRITE_BYTE
    dey 
    lda (TEMP1), y
    jsr WRITE_BYTE

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

; show Code Field Address (CFA)
    lda #' '
    jsr WRITE_CHAR
    
    lda TEMP1 + 1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE

; check if is a primitive  - FIX THIS, ANOTHER WAY NECC.
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
; print size and name 
show_name:
    lda #' '
    jsr WRITE_CHAR
    lda (TEMP1), y   ; size + flag
    bpl SHOWNAMESK
    ANSI $33,$31,'m'
SHOWNAMESK:
    and #$7F
    jsr WRITE_BYTE
    tax
    sta TEMP5        ; save size
SHWNAMELOOP1:        ; name
    iny
    lda (TEMP1), y
    jsr WRITE_CHAR
    dex
    bne SHWNAMELOOP1
    ANSI $30,'m'
    rts

;----------------------------------------------------------------------
show_refer:
; print references (PFA - parameter field addresses) 
    ldx #(TEMP1)

SHWREFLOOP:
    lda #' '
    jsr WRITE_CHAR
    lda TEMP1 + 1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE
    lda #':'
    jsr WRITE_CHAR
    iny 
    lda (TEMP1), y
    jsr WRITE_BYTE
    dey
    lda (TEMP1), y
    jsr WRITE_BYTE
    lda #2
    jsr addwx

; check if at the end
    lda TEMP1
    cmp TEMP3
    bne SHWREFLOOP
    lda TEMP1 + 1
    cmp TEMP3 + 1
    bne SHWREFLOOP
    rts

;----------------------------------------------------------------------
;  seek for addr of 'exit' at end of sequence of references
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