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
def_word ">in", "inptr", 0                  ; CURBUF - pointer into INBUF (TIB)
    lda #STATUS + 2
REGIN:
    sta TEMP1
    lda #0
    sta TEMP1+1
    jmp this
;    
def_word "last", "last", 0                   ; LASTHEAP addr onto stack
    lda #STATUS + 4
    bra REGIN
;    
def_word "here", "here", 0                   ; NEXTHEAP addr onto stack
    lda #STATUS + 6
    bra REGIN
;
def_word "sp", "sp", 0                       ; DSPTR pointer addr onto stack
    lda #STATUS + 8
    bra REGIN
;
def_word "rp", "rp", 0                       ; RTPTR pointer addr onto stack
    lda #STATUS + 10
    bra REGIN
;

def_word "allot", "allot", 0
    jsr spull_0       ; get byte count from stack, put in TEMP1
    ldy #1
    lda (NEXTHEAP),y
    sta TEMP2+1
    dey
    lda (NEXTHEAP),y
    sta TEMP2
    clc
    adc TEMP1
    sta (NEXTHEAP),y
    lda TEMP2+1
    adc TEMP1+1
    iny
    sta (NEXTHEAP),y
    jmp next
;                             ': >r rp @ @ swap rp @ ! rp @ 2 - rp ! rp @ ! ;'
def_word ">r", "s_to_r", 0
    jsr spull_0   ; put top of stack in TEMP1
    ldy #TEMP1
    jsr rpush
    jmp next
;                             ': r> rp @ @ rp @ 2 + rp ! rp @ @ swap rp @ ! ;'
def_word "r>", "r_to_s", 0 
    ldy #TEMP1
    jsr rpull
    jsr spush_0     ; and push on DS stack
    jmp next
;

; (? -- ?)                - ': lit rp @ @ dup 2 + rp @ ! @ ;'
;      DOESN'T QUITE WORK YET, BUT CLOSE
;
def_word "litx", "literal", 0       ; renaming for now, since don't work
   ldy #TEMP3           
   jsr rpull            ; 'rp @' more or less, w/o push to DS
   ldx #TEMP3           
   jsr FETCH_WX         ; copy from ((RTPTR)) to TEMP2 to TEMP1, push - '@'
                       ; 'dup' - already in TEMP1, so don't need to push/pull again
   lda TEMP1           ; '2 +'
   clc
   adc #2              
   bcc LITSKIP
   inc TEMP1+1
LITSKIP:       
   ldy #TEMP1
   jsr rpush           ; 'rp @ !'  - alreay in TEMP1, don't need to use stack
   jmp fetchw          ; '@'       - regular path.  addr already on stack

.ifdef SINGLE
;----------------------NUMERALS----------------------------------------
; ( -- n ) numeral 1
def_word "$1", "onehex", 0
     jmp ONEHEX
def_word "1", "one", 0
ONEHEX:
     lda #1
DOWITHONE:
     sta TEMP1
     lda #0
     sta TEMP1+1
     jsr spush_0
     jmp next     

; ( -- n ) numeral 2
def_word "$2", "twohex", 0
     lda #2
     jmp DOWITHONE
def_word "2", "two", 0
     lda #2
     jmp DOWITHONE

; ( -- n ) numeral 3
def_word "$3", "threehex", 0
     lda #3
     jmp DOWITHONE
def_word "3", "three", 0
     lda #3
     jmp DOWITHONE

; ( -- n ) numeral 4
def_word "$4", "fourhex", 0
     lda #4
     jmp DOWITHONE
def_word "4", "four", 0
     lda #4
     jmp DOWITHONE

; ( -- n ) numeral 5
def_word "$5", "fivehex", 0
     lda #5
     jmp DOWITHONE
def_word "5", "five", 0
     lda #5
     jmp DOWITHONE

; ( -- n ) numeral 6
def_word "$6", "sixhex", 0
     lda #6
     jmp DOWITHONE
def_word "6", "six", 0
     lda #6
     jmp DOWITHONE

; ( -- n ) numeral 7
def_word "$7", "sevenhex", 0
     lda #7
     jmp DOWITHONE
def_word "7", "seven", 0
     lda #7
     jmp DOWITHONE

; ( -- n ) numeral 8
def_word "$8", "eighthex", 0
     lda #8
     jmp DOWITHONE
def_word "8", "eight", 0
     lda #8
     jmp DOWITHONE

; ( -- n ) numeral 9
def_word "$9", "ninehex", 0
     lda #9
     jmp DOWITHONE  
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
def_word "$0", "zerohex", 0
     jmp DOITZERO
def_word "0", "zero", 0
DOITZERO:
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
.endif   ; SINGLE
     
;----------------------LOGIC FUNCTIONS--------------------------
; ( w1 w2 -- w1 AND w2 )
def_word "and", "xand", 0   ; had to use 'xand' cuz 'and' used for something important...
    jsr spull_1             ; load TEMP2, TEMP1 from stack
    jsr spull_0
    lda TEMP2
    and TEMP1
    sta TEMP1
    lda TEMP2 + 1
    and TEMP1 + 1
    jmp keeps  ; uncomment if carry could be set
;
; ( w1 w2 -- w1 OR w2 )
def_word "or", "or", 0
    jsr spull_1             ; load TEMP2, TEMP1 from stack
    jsr spull_0
    lda TEMP2
    ora TEMP1
    sta TEMP1
    lda TEMP2 + 1
    ora TEMP1 + 1
    jmp keeps  ; sta TEMP1+1 included!
;
; ( w1 w2 -- w1 XOR w2 )
def_word "xor", "xor", 0
    jsr spull_1             ;load TEMP2, TEMP1 from stack
    jsr spull_0
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
; (n1 n2 -- n1=n2)  equal   
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
; (n1 -- n1=0)  equal to zero  
def_word "0=", "eqz", 0
   jsr spull_0
   lda TEMP1
   ora TEMP1+1       ; only zero if both zero
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
   jsr spull_0          ; pull top to TEMP1
 ;  lda TEMP1
 ;  lda TEMP1+1
   jsr spush_0          ; and then push back
   jmp this            ; includes jsr spush_0 for second time
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
; (RT:a a a ... -- RT: )    clear RT
def_word "xR", "xR", 0
   lda #RTEND
   sta RTPTR
   lda #0
   ldy #0
   sta (RTPTR),y
   iny
   sta (RTPTR),y
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
; (a b -- b)
def_word "nip", "nip", 0
   jsr spull_0
   jsr spull_1
   jsr spush_0
   jmp next
;
; (a b -- b a b)
def_word "tuck", "tuck", 0
   jsr spull_0
   jsr spull_1
   jsr spush_0
   jsr spush_1
   jsr spush_0
   jmp next
;
; (a b -- a b a b)
def_word "2dup", "dup2", 0
   jsr spull_1          ; pull top to TEMP2
   jsr spull_0          ; then TEMP1
   jsr spush_0          ; and then push back
   jsr spush_1
   jsr spush_0
   jsr spush_1         
   jmp next             ; includes jsr spush_0 for second time
;
; (a b -- )
def_word "2drop", "drop2", 0
   jsr spull_0
   jsr spull_0
   jmp next
;
; (a b c d -- a b c d a b)
def_word "2over", "over2", 0
   ldy #TEMP4
   jsr spull     ; to TEMP4 'd'
   jsr spull_2  ; TEMP3 'c'
   jsr spull_1  ; TEMP2 'b'
   jsr spull_0  ; TEMP1 'a'
   jsr spush_0  ;  'a'
   jsr spush_1  ;  'b'
   jsr spush_2  ;  'c'
   ldy #TEMP4
   jsr spush    ; 'd'
   jsr spush_0  ;  'a' again
   jsr spush_1  ;  'b' again
   jmp next
;
; (a -- )       load a compile-able script from memory, zero term'd
def_word "cload", "cload", 0
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    lda #'-'
    jsr WRITE_CHAR
    jsr spull_0  ; address from stack to TEMP1
    ldy #0
    lda #$20
    sta INBUF, y   ; put space at start
CLOAD_LP:   
    lda (TEMP1), y
    beq CLOAD_CONT     ; stops at first 0
    jsr WRITE_CHAR     ; echo char out so can see what's being pulled in
    iny           ; yep, skip
    sta INBUF, y
    bra CLOAD_LP
CLOAD_CONT:
    iny
    lda #$20
    sta INBUF,y     ; not sure but won't hurt to add a space
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    lda #$20
    sta INBUF       ; start with space
    sta INBUF, y        ; ends with space
    lda #0            ; mark eol with 0
    sta INBUF + 1, y
; start it
    sta CURBUF
    tya                ; calc next address if want to load more
    clc
    adc TEMP1
    sta TEMP1
    bcc UPDTEMPSKIP
    inc TEMP1+1
UPDTEMPSKIP:
    jsr spush_0        ; push next addr on stack if wanted
    jsr token            ; massage the buffer, oh yeah
    jmp RESFIND           ; works perfectly!
;
;
;----------------------------------------------------------------------------
HYWORDS_END:
;  end hywords.s
;----------------------------------------------------------------------------