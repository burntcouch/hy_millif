;
;  BLOAD test code
;
bload0:
.byte 6
.byte "BLTEST"
     bit $00
     lda #$0D
     jsr WRITE_CHAR
     lda #$0A
     jsr WRITE_CHAR
     lda #$0D
     jsr WRITE_CHAR
     lda #'T'
     jsr WRITE_CHAR
     lda #'E'
     jsr WRITE_CHAR
     lda #'S'
     jsr WRITE_CHAR
     lda #'T'
     jsr WRITE_CHAR
     lda #$0D
     jsr WRITE_CHAR
     lda #$0A
     jsr WRITE_CHAR
     jmp next
.byte 0, 0
bload0_end: