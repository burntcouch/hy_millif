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
;  list a sequence of references
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
    jsr WRITE_BYTE         ; print # of entries?

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
    ora TEMP2 + 1    ; check if $00-00
    bne WORDSKIP1
    jmp WORDSEND  
WORDSKIP1:

    lda TEMP2 + 1    ; msb linked list
    sta TEMP1 + 1

    WCRLF_np
    
; print address
    lda #' '
    jsr WRITE_CHAR

    lda TEMP1 + 1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE

; print link
    lda #' '
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

    lda (TEMP1), y
    jsr WRITE_BYTE
    
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
; print references PFA ... 
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
    jsr spull_1             ; load TEMP1 from stack
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

;---------------------------------------------------------------------
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
;
;------------------------END of primitives.s
;