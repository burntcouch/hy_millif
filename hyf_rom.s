;
;  COPYTORAM
;
COPYMAIN = COPYSTART
RAMST = RAMSTART
COPYENDS = ends - RAMSTART + COPYSTART

COPYTORAM:                     ; copies from mainoff thru endsoff to ramstart
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
    jsr MEMCPY
    lda ramstart+1
    jsr WRITE_BYTE
    lda ramstart
    jsr WRITE_BYTE
    WCRLF_np
    jsr MEMCPY
    jmp $FE00 
;

