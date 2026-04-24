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

;
.ifdef LUTABLE
BUILDLU:
    lda #>LENLU
    sta LUPTR+1
    lda #<LENLU
    sta LUPTR

    lda LASTHEAP                ; 'last'
    sta TEMP2
    lda LASTHEAP+1
    sta TEMP2+1
    lda NEXTHEAP                ; 'here'
    sta TEMP3
    lda NEXTHEAP+1
    sta TEMP3+1
    jmp BLUSKIP02               ; jump over first entry
    
BLULOOP:

    ldy #0
    lda TEMP3         ; TEMP3 is pointing at length byte
    sta (LUPTR),y     ; copy address to second field
    lda TEMP3+1          
    iny
    sta (LUPTR),y        
    lda LUPTR
    sec
    sbc #2
    sta LUPTR
    bcs BLUSKIP0
    dec LUPTR+1
BLUSKIP0:
    lda TEMP3
    sta TEMP4
    lda TEMP3+1
    sta TEMP4+1    
    ldy #0
    lda (TEMP4),y     ; now get length
    and #$4F          ; mask off imm/comp bits
    inc a             ; add one to get past name?
    clc
    adc TEMP4
    sta TEMP4
    bcc BLUSKIP01
    inc TEMP4+1         ; TEMP4 now points at CFA
BLUSKIP01:
    ldy #0
    lda TEMP4       ; copy CFA to first field
    sta (LUPTR),y
    iny
    lda TEMP4+1
    sta (LUPTR),y
    lda LUPTR
    sec
    sbc #2
    sta LUPTR
    bcs BLUSKIP02
    dec LUPTR+1
BLUSKIP02:
    lda TEMP2       ; lsb linked list
    ora TEMP2 + 1    ; check if TEMP2 = $0000, end if so
    beq BLUEND
    
    lda TEMP2            ; update TEMP2 and TEMP3, advance in linked list
    sta TEMP3
    lda TEMP2 + 1        ; 'last' -> 'here'
    sta TEMP3 + 1
    ldy #0
    lda (TEMP3), y      ;  'last' <- ['here']   updated
    sta TEMP2
    iny
    lda (TEMP3), y
    sta TEMP2 + 1
    ldx #(TEMP3)
    lda #2
    jsr addwx
 
    jmp BLULOOP   
BLUEND:
    rts
.endif

