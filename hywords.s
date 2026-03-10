;
;HyForth extra commands
;
; hywords.s
;
;----------------------------------------------------------------------
;               NEW NEW NEW NEW NEW
;----------------------NUMERALS----------------------------------------
; ( -- n ) numeral 1
def_word "1", "one", 0
     lda #1
DOWITHONE:
     sta TEMP1
     lda #0
     sta TEMP1+1
     jsr spush_0
     jmp next     

; ( -- n ) numeral 2
def_word "2", "two", 0
     lda #2
     jmp DOWITHONE

; ( -- n ) numeral 3
def_word "3", "three", 0
     lda #3
     jmp DOWITHONE

; ( -- n ) numeral 4
def_word "4", "four", 0
     lda #4
     jmp DOWITHONE

; ( -- n ) numeral 5
def_word "5", "five", 0
     lda #5
     jmp DOWITHONE

; ( -- n ) numeral 6
def_word "6", "six", 0
     lda #6
     jmp DOWITHONE

; ( -- n ) numeral 7
def_word "7", "seven", 0
     lda #7
     jmp DOWITHONE

; ( -- n ) numeral 8
def_word "8", "eight", 0
     lda #8
     jmp DOWITHONE

; ( -- n ) numeral 9
def_word "9", "nine", 0
     lda #9
     jmp DOWITHONE  
     
; ( -- n ) numeral -1
def_word "-1", "negone", 0
     lda #$FF
     sta TEMP1
DOWITHNEG:
     sta TEMP1+1
     jsr spush_0
     jmp next 

; ( -- n ) numeral 0
def_word "0", "zero", 0
     lda #0
     sta TEMP1
     sta TEMP1+1
     jsr spush_0
     jmp next
     
; ( -- n ) numeral -2
def_word "-2", "negtwo", 0
     lda #$FE
     sta TEMP1
     jmp DOWITHNEG

; ( -- n ) numeral -3
def_word "-3", "negthree", 0
     lda #$FD
     sta TEMP1
     jmp DOWITHNEG

def_word "-4", "negfour", 0
; ( -- n ) numeral -4
     lda #$FC
     sta TEMP1
     jmp DOWITHNEG

def_word "-5", "negfive", 0
; ( -- n ) numeral -5
     lda #$FB
     sta TEMP1
     jmp DOWITHNEG

def_word "-6", "negsix", 0
; ( -- n ) numeral -6
     lda #$FA
     sta TEMP1
     jmp DOWITHNEG

def_word "-7", "negseven", 0
; ( -- n ) numeral -7
     lda #$F9
     sta TEMP1
     jmp DOWITHNEG

def_word "-8", "negeight", 0
; ( -- n ) numeral -8
     lda #$F8
     sta TEMP1
     jmp DOWITHNEG     
     
def_word "-9", "negnine", 0
; ( -- n ) numeral -9
     lda #$F7
     sta TEMP1
     jmp DOWITHNEG 
  

;----------------------LOGIC FUNCTIONS--------------------------
; ( w1 w2 -- w1 AND w2 )
def_word "and", "xand", 0   ; had to use 'xand' cuz 'and' used for something important...
    jsr spull_1             ; load TEMP1 from stack
    lda TEMP2
    and TEMP1
    sta TEMP1
    lda TEMP2 + 1
    and TEMP1 + 1
    jmp keeps  ; uncomment if carry could be set
 
; ( w1 w2 -- w1 OR w2 )
def_word "or", "or", 0
    jsr spull_1             ; load TEMP1 from stack
    lda TEMP2
    ora TEMP1
    sta TEMP1
    lda TEMP2 + 1
    ora TEMP1 + 1
    jmp keeps  ; sta TEMP1+1 included!
 
; ( w1 w2 -- w1 XOR w2 )
def_word "xor", "xor", 0
    jsr spull_1             ; load TEMP1 from stack
    lda TEMP2
    eor TEMP1
    sta TEMP1
    lda TEMP2 + 1
    eor TEMP1 + 1
    jmp keeps  ; sta TEMP1+1 included!
    
; ( w1 -- NOT w1 )
def_word "not", "not", 0
    jsr spull_0             ; load TEMP1 from stack
    lda TEMP1
    eor #$FF
    sta TEMP1
    lda TEMP1+1
    eor #$FF
    jmp keeps  ; sta TEMP1+1 included!
 
; ( w1 -- NEG w1 )  1's complement
def_word "neg", "neg", 0
    jsr spull_0             ; load TEMP1 from stack
    lda TEMP1
    eor #$FF
    sta TEMP1
    lda TEMP1+1
    eor #$FF
    inc TEMP1
    bne NEGENDS
    inc TEMP1+1
NEGENDS:    
    jmp keeps  ; sta TEMP1+1 included!

;----------------------CLASSIC FORTH-------------------------    
def_word "swap", "swap", 0
   jsr spull_0          ; pull top
   lda TEMP1
   sta TEMP2
   lda TEMP1+1
   sta TEMP2+1
   jsr spull_0          ; pull next, will end up in TEMP1
   jsr spush_1          ; push TEMP2 back on now
   jsr spush_0          ; and then push TEMP1
   jsr next
;
;  end hywords.s
;