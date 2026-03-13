;
;HyForth extra commands
;
; hywords.s
;
;----------------------------------------------------------------------
;               NEW NEW NEW NEW NEW
;
;----------------------------------------------------------------------
; wish list: $A,$B,..,$F, %0, %1, %10, %11
;    dup, over, rot, -, <>, =, gt, ge, lt, le, true, false
;
;----------------------UTILITIES--------------------------------------
def_word "cr", "crlf", 0
     lda #CR
     jsr WRITE_CHAR
     lda #LF
     jsr WRITE_CHAR
     jmp next
;    
def_word ">in", "inptr", 0
    lda #STATUS + 2
REGIN:
    sta TEMP1
    lda #0
    sta TEMP1+1
    jmp this
;    
def_word "last", "last", 0
    lda #STATUS + 4
    bra REGIN
;    
def_word "here", "here", 0
    lda #STATUS + 6
    bra REGIN
;
def_word "sp", "sp", 0
    lda #STATUS + 8
    bra REGIN
;
def_word "rp", "rp", 0
    lda #STATUS + 10
    bra REGIN
;

     
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
  
; ( -- n ) numeral A
def_word "$A", "zeroa", 0
     lda #10
     jmp DOWITHONE

; ( -- n ) numeral B
def_word "$B", "zerob", 0
     lda #11
     jmp DOWITHONE

; ( -- n ) numeral C
def_word "$C", "zeroc", 0
     lda #12
     jmp DOWITHONE

; ( -- n ) numeral D
def_word "$D", "zerod", 0
     lda #13
     jmp DOWITHONE

; ( -- n ) numeral E
def_word "$E", "zeroe", 0
     lda #14
     jmp DOWITHONE

; ( -- n ) numeral F
def_word "$F", "zerof", 0
     lda #15
     jmp DOWITHONE 

; ( -- n ) numeral %0
def_word "%0", "binary0", 0
     lda #0
     jmp DOWITHONE 

; ( -- n ) numeral %1
def_word "%1", "binary1", 0
     lda #1
     jmp DOWITHONE  
     
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
;
; ( w1 w2 -- w1 OR w2 )
def_word "or", "or", 0
    jsr spull_1             ; load TEMP1 from stack
    lda TEMP2
    ora TEMP1
    sta TEMP1
    lda TEMP2 + 1
    ora TEMP1 + 1
    jmp keeps  ; sta TEMP1+1 included!
;
; ( w1 w2 -- w1 XOR w2 )
def_word "xor", "xor", 0
    jsr spull_1             ; load TEMP1 from stack
    lda TEMP2
    eor TEMP1
    sta TEMP1
    lda TEMP2 + 1
    eor TEMP1 + 1
    jmp keeps  ; sta TEMP1+1 included!
;    
; ( w1 -- NOT w1 )
def_word "not", "not", 0
    jsr spull_0             ; load TEMP1 from stack
    lda TEMP1
    eor #$FF
    sta TEMP1
    lda TEMP1+1
    eor #$FF
    jmp keeps  ; sta TEMP1+1 included!
;
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
    jmp next 
;
; (n1 n2 -- n1<>n2)  not equal
def_word "<>", "ne", 0
   jsr spull_1
   jsr spull_0
CMPLINK:
   lda TEMP1
   cmp TEMP2
   bne IEQTRUE
   lda TEMP1+1
   cmp TEMP2+1
   beq IEQFALSE
   jmp IEQTRUE
;
; (n1 n2 -- n1=n2)  not equal   
def_word "=", "eq", 0
   jsr spull_1
   jsr spull_0
   lda TEMP1
   cmp TEMP2
   bne IEQFALSE
   lda TEMP1+1
   cmp TEMP2+1
   bne IEQFALSE
   jmp IEQTRUE
;
; (n1 n2 -- n1>n2)  more than
def_word ">", "gt", 0
   jsr spull_1
   jsr spull_0
   lda TEMP1+1
   cmp TEMP2+1
   bcc IEQFALSE
   bne IEQTRUE
   lda TEMP1
   cmp TEMP2
   bcc IEQFALSE
   beq IEQFALSE
IEQTRUE:  
   lda #$FF
   jmp IEQEND
IEQFALSE:
   lda #0
IEQEND:
   sta TEMP1
   sta TEMP1+1
   jmp this

;   
; (n1 n2 == n1<=n2) less than or equal
def_word "<=", "lte", 0
   jsr spull_1
   jsr spull_0
   lda TEMP1+1
   cmp TEMP2+1
   bcc IEQTRUE
   bne IEQFALSE
   lda TEMP1
   cmp TEMP2
   bcc IEQTRUE
   beq IEQTRUE
   jmp IEQFALSE
   
   
;
; (n1 n2 == n1>=n2) greater than or equal
def_word ">=", "gte", 0
   jsr spull_1
   jsr spull_0
GTELINK:
   lda TEMP1+1
   cmp TEMP2+1
   bcc IEQFALSE
   bne IEQTRUE
   lda TEMP1
   cmp TEMP2
   bcc IEQFALSE
   jmp IEQTRUE
;   
; (n1 n2 == n1<n2) less than
def_word "<", "lt", 0
   jsr spull_1
   jsr spull_0
   lda TEMP1+1
   cmp TEMP2+1
   bcc IEQTRUE
   bne IEQFALSE
   lda TEMP1
   cmp TEMP2
   bcc IEQTRUE
   jmp IEQFALSE
;

;----------------------CLASSIC FORTH-------------------------
; (a b -- b a)    
def_word "swap", "swap", 0
   jsr spull_0          ; pull top
   lda TEMP1
   sta TEMP2
   lda TEMP1+1
   sta TEMP2+1
   jsr spull_0          ; pull next, will end up in TEMP1
   jsr spush_1          ; push TEMP2 back on now
   jmp this            ; includes jsr spush_0
;
;  (a -- a a)
def_word "dup", "dup", 0
   jsr spull_0          ; pull top
   lda TEMP1
   lda TEMP1+1
   jsr spush_0          ; and then push back
   jmp this            ; includes jsr spush_0
;
; (a -- )
def_word "drop", "drop", 0
   jsr spull_0          ; pull top, ends up in TEMP1 but...
   jmp next
;
; (a a a ... -- )    clear DS
def_word "xS", "xS", 0
   lda #DSEND
   sta DSPTR
   lda #0
   ldy #0
   sta (DSPTR),y
   iny
   sta (DSPTR),y
   jmp next
;
; (a b c -- b c a)
def_word "rot", "rot", 0
   jsr spull_0
   jsr spull_1
   jsr spull_2
   jsr spush_1
   jsr spush_0
   jsr spush_2
   jmp next
;
; (a b -- a b a) 
def_word "over", "over", 0
   jsr spull_0
   jsr spull_1
   jsr spush_1
   jsr spush_0
   jsr spush_1
   jmp next
;


;  end hywords.s
;