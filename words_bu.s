; ( -- ) words in dictionary, 
def_word "wlist", "wlist", 0

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
    
WORD_LOOP:
    inc TEMP5       ; increment 'words per line' count
    lda TEMP2       ; lsb linked list
    sta TEMP1
    ora TEMP2 + 1    ; check if TEMP2 = $0000, end if so
    beq WORD_END
    lda TEMP2 + 1    ; msb linked list
    sta TEMP1 + 1
    
    lda TEMP5        ; check word count, CRLF if 4th one
    cmp #5
    bne WORD_SKIP
    WCRLF_np
    stz TEMP5
    
WORD_SKIP:
; put address
    lda #' '
    jsr WRITE_CHAR
    lda TEMP1 + 1
    jsr WRITE_BYTE
    lda TEMP1
    jsr WRITE_BYTE

; put link
;    lda #' '
;    jsr WRITE_CHAR
;    ldy #1
;    lda (TEMP1), y
;    jsr WRITE_BYTE
;    dey 
;    lda (TEMP1), y
;    jsr WRITE_BYTE

    ldx #TEMP1          ; advance TEMP1 to name+flag
    lda #2
    jsr addwx
    ldy #0                
    jsr show_name        ; put size + flag, name
                         
    iny                  ; update TEMP1 again, point at CFA
    tya
    ldx #TEMP1
    jsr addwx

;    lda #' '             ; show CFA
;    jsr WRITE_CHAR    
;    lda TEMP1 + 1
;    jsr WRITE_BYTE
;    lda TEMP1
;    jsr WRITE_BYTE

; check if is a primitive
;    lda TEMP1 + 1
;    cmp #>ends + 1
;    bmi WORD_CONT
;
; list references
;    ldy #0
;    jsr show_refer
     lda TEMP3           ; instead of printing refs, just advance to TEMP3
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

;----------------------------------------------------------------------
; ae put size and name 
show_name:
    lda #':'
    jsr WRITE_CHAR
    lda (TEMP1), y
    jsr WRITE_BYTE       ; size
    
;    lda #' '
;    jsr WRITE_CHAR

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
    rts

;----------------------------------------------------------------------
show_refer:
; put references PFA ... 

    ldx #(TEMP1)

REFLOOP:
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

    lda TEMP1
    cmp TEMP3
    bne REFLOOP
    lda TEMP1 + 1
    cmp TEMP3 + 1
    bne REFLOOP

REFEND:
    rts