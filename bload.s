;
;  BLOAD test code
;
bload0:
.byte 6
.byte "BLtest"
     bit #0
     lda #$0D
     jsr WRITE_CHAR
     lda #$0A
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
.byte 7
.byte "BLtest2"
     bit #0
     lda #$0D
     jsr WRITE_CHAR
     lda #$0A
     jsr WRITE_CHAR
     lda #'!'
     jsr WRITE_CHAR
     lda #'T'
     jsr WRITE_CHAR
     lda #'E'
     jsr WRITE_CHAR
     lda #'S'
     jsr WRITE_CHAR
     lda #'T'
     jsr WRITE_CHAR
     lda #'Y'
     jsr WRITE_CHAR
     lda #$0D
     jsr WRITE_CHAR
     lda #$0A
     jsr WRITE_CHAR
     jmp next
.byte 0, 0
.byte "END"
bload0_end: