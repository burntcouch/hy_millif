;
;  COPYTORAM
;
FFILL:
        .res 32 
COPYMAIN = COPYSTART
RAMST = RAMSTART
COPYENDS = ends - RAMSTART + COPYSTART

COPYTORAM:                     ; copies from mainoff thru endsoff to ramstart
    WCRLF_np
    WCRLF_np
    stz supprint               ; let it print
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
MEMCPY:
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
    lda supprint
    bne SKIP01
    lda #'.'
    jsr WRITE_CHAR
SKIP01:
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
    lda supprint
    bne CPRTS
    lda ramstart+1
    jsr WRITE_BYTE
    lda ramstart
    jsr WRITE_BYTE
    WCRLF_np
;
CPEND:    
    jmp $FE00
CPRTS:
    rts

