;
;   upper.s  - utility functions for HyForth - eventually ROM resident
;
;---------------------------------------------------------------------
;  error messaging
;
wrterror:
    lda #>err_jumptable
    sta ERRPTR+1
    lda ERRFLAG
    beq ERREND
    asl a
    clc
    adc #<err_jumptable
    sta ERRPTR
    bcc ERRSKIP
    inc ERRPTR+1
ERRSKIP:
    WERR ERRPTR
ERREND:
    lda #0
    sta ERRFLAG
    sta ERRPTR
    sta ERRPTR+1
    rts
;
;  
err_jumptable:
    .res 2
    ERR_entry PTR_ERR    ; stack full  - error 1
    ERR_entry NUM_ERR    ; number not right - error 2
    ERR_entry OOM_ERR    ; out of memory  - error 3
    ERR_entry UKW_ERR    ; no existing word - error 4
LASTERR = 4
;
;  error messages
PTR_ERR:
    .byte " !PTR ERROR!"
    .byte 0
NUM_ERR:
    .byte " !BAD #!"
    .byte 0
OOM_ERR:
    .byte " !LOW MEM!"
    .byte 0
UKW_ERR:
    .byte " !UNK WORD!"
    .byte 0
;
;
;-----------------------   NUMBER CONVERSIONS
;

.ifdef numbers
;------------------------
;      CONVERT DIGITS, PUSH on DS

DIGCONVT:    ;  Y is index into NXTPTR, X is length
		stz TEMP1
		stz TEMP1+1
    stz TEMP2            ; no necc for bin or hex, but
		stz TEMP2+1          ; since is convenient....
		stz TEMP4
    ldy #1               ; skip over length
		lda #10
		sta DIGBASE
		lda (NXTTOK),y
		cmp #'-'
		beq DIGCONV_MINUS
		cmp #'$'
		beq DIGHEX1
		cmp #'%'
		beq DIGBIN1
    bra DIG_SNG
DIGCONV_MINUS:
		inc TEMP4
		jmp DIG_XY
DIGBIN1:
    lda #2
		sta DIGBASE
    jmp DIG_XY
DIGHEX1:
    lda #16
		sta DIGBASE
DIG_XY:
		iny
		dex
DIG_SNG:
  .ifdef SINGLE
		cpx #1                       ; skip single digit, handle hard-wired or...
		bne DIGCONV_LOOP             ; only one digit left, we can handle that elsewhere
    jmp DIGCONV_ERR
  .endif     
DIGCONV_LOOP:

    jsr DUMPREG

		jsr GETDIG
    bcc DIGCONT0
    jmp DIGCONV_ERR
DIGCONT0:
    pha                         ; else save it to add in a bit
    asl TEMP1                     ; do first shift
		rol TEMP1+1
		lda DIGBASE                  ; check base that was set above
		cmp #10
		beq DIGDEC                     ; it's DEC, go there
    cmp #2
		beq DIGBIN                     ; it's BIN, go there
    bra DIGHEX                     ; Go to hex if others not true
DIGDEC:                            ; ADDING or SHIFTING WRONG
    asl TEMP1                      ; 2nd shift; upper nybble doesn't end up right
		rol TEMP1+1
		lda TEMP1                      ; load results of two shifts
		clc
		adc TEMP2                      ; add in previous total from last loop
    sta TEMP1
    lda TEMP1+1                    ; and same with second digit, and the carry
		adc TEMP2+1
    sta TEMP1+1
DIGDEC2:
    asl TEMP1                      ; final shift
		rol TEMP1+1
		pla                            ; bring back read digit
		cmp #10                        ; make sure it's not hex, mostly
		bcc DIGCONT                    ; jump to continue
    jmp DIGCONV_ERR                ; else throw error
DIGHEX:
    asl TEMP1
		rol TEMP1+1
		asl TEMP1
		rol TEMP1+1
		asl TEMP1
		rol TEMP1+1                    ; shifted three more times
		pla
		jmp DIGCONT
DIGBIN:                           ; already did the single shift
    pla
    cmp #2
    bcs DIGCONV_ERR           ; fall through to the additon of new digit
DIGCONT:
		clc                      ; add digit finally
		adc TEMP1
		sta TEMP1
		sta TEMP2               ; copy to intermediate result in case another dec digit
		bcc DIGCONT2
		inc TEMP1+1             ; and inc 2nd byte if necc.
DIGCONT2:
    lda DIGBASE
    cmp #10
    bne DIGCONT3
    lda TEMP1+1
    sta TEMP2+1              ; save it for next round, regardless
    cmp #$80                 ; check to see if > $8000
		bcs DIGCONV_ERR
DIGCONT3:
		iny
		dex
		bne DIGCONV_LOOP
    lda DIGBASE
    cmp #10
    bne DIGCONT4
DECFINISH:
		lda TEMP4                ; check for minus
		beq DIGCONT4
    lda TEMP1
    eor #$FF
    sta TEMP1
		lda TEMP1+1
		eor #$FF
    sta TEMP1+1
		inc TEMP1
		bne DIGCONT4
		inc TEMP1+1
DIGCONT4:
    jsr spush_0     ; push TEMP1 on to stack 
    clc
		rts
DIGCONV_ERR:
    jsr DUMPREG
    sec
		rts

;--------------------------
GETDIG:    ; y is index to next char in NXTTOK
		lda (NXTTOK),y
		sec
		sbc #$30
		bcc GETDIG_ERR
		cmp #10
		bcc GETDIG_RTN
		sbc #7
		cmp #10
		bcc GETDIG_ERR
		cmp #16
    bcs GETDIG_ERR
GETDIG_RTN:         ; pass carry clear for good digit
		clc
		rts
GETDIG_ERR:          ; pass carry set for no digit
    sec
    rts
;  end of new number conv
;
.endif    ; numbers
;--------------------------------- CLEAR ------------------------------
;
;  zero out $E0 - $FF, meet and greet
;  zero out INBUF also
;
HYWELCOME:
    .byte CR, LF
    .byte "HyForth 0.61 03-20-2026"
    .byte CR, LF, $00
CLEAR:
    lda #1
    sta DFLAG                 ; debug OFF by default
zpclear:
    ldx #ZPSTART                  ; whoops, this is all the ZP that is used
    lda #0
zerolp:
    sta  $00,x
    inx
    bne zerolp    
    ldx  #0
inbufzlp:                      ; and then clear out INBUF
    sta  INBUF,x
    inx
    bne  inbufzlp
    ldx  #0
stackslp:                      ; and then clear out DS / RT
    sta  DS,x
    inx
    bne  stackslp
        ;  meet and greet
    ldy  #0
hywelclp:
    lda  HYWELCOME,y
    beq  CLREXIT
    jsr  WRITE_CHAR
    iny
    bra  hywelclp 
CLREXIT:    
    rts
;
;
.ifdef DEBUG 
;      argh.
;   Include DEBUG code here
;   
;
;  debug stuff   ------------------------------ DUMPREG ---------------------
;
DUMPTXT1:
        .byte "SP/PC/nv-bdizc/A/X/Y -> "
        .byte 0
DUMPMSG1:
        .byte "<spc> to continue, x for Wozmon, z for ZP, t for TIB, s for stacks"
        .byte $0D, $0A, 0

DUMPREG:       ; dump registers safely and print
        php                     ; -3
        pha                     ; -4
        phx                     ; -5
        phy                     ; -6
        lda   DFLAG
        beq   DPFCHECK
        jmp   DREGNXT
DPFCHECK:
        ldy   #0
        WCRLF_np
DUMPLP0:        
        lda   DUMPTXT1, y
        beq   DUMPCON
        jsr   WRITE_CHAR
        iny
        bra   DUMPLP0
DUMPCON:
        tsx                     ; -6
        txa
        clc
        adc   #6
        jsr   WRITE_BYTE        ; print stack pointer b4 jump
        lda   #'/'
        jsr   WRITE_CHAR 
        inx                     ; -5
        inx                     ; -4
        inx                     ; -3
        inx                     ; -2
        inx                     ; -1
        lda   $0100,x              ; get PC LSB
        tay 
        inx                     ; 0
        lda   $0100,x              ; get PC MSB
        jsr   WRITE_BYTE           
        tya
        jsr   WRITE_BYTE        
        lda   #'/'
        jsr   WRITE_CHAR  
        ;   whew
        ;
        dex                      ; -1
        dex                      ; -2
        lda   $0100,x            ; get status byte
        ldy   #8
DUMPLP2:
        rol
        pha
        bcc   DUMPSKx            ; NV-BDIZC
        lda   #$31
        bra   DUMPSKy
DUMPSKx: 
        lda   #$30      
DUMPSKy:
        jsr   WRITE_CHAR         ; print y-th bit
        pla
        dey   
        bne   DUMPLP2
        lda   #'/'
        jsr   WRITE_CHAR
        dex                       ; -3
        lda   $0100,x 
        jsr   WRITE_BYTE           ; print A
        lda   #'/'
        jsr   WRITE_CHAR
        dex                        ; -4
        lda   $0100,x 
        jsr   WRITE_BYTE           ; print X
        lda   #'/'
        jsr   WRITE_CHAR
        dex                        ; -5
        lda   $0100,x 
        jsr   WRITE_BYTE           ; print Y
        WCRLF_np
        ldy   #0
DUMPLP1:                               ; print message
        lda   DUMPMSG1, y
        beq   DREGLP1
        jsr   WRITE_CHAR
        iny
        bra   DUMPLP1        
DREGLP1: 
        jsr   READ_CHAR              ; wait for a key
        bcc   DREGLP1
        cmp   #'s'                  ; print out stacks?
        bne   DREGSK3
        jsr   DUMPSTACK
DREGSK3:
        cmp   #'z'                  ; print out zp?
        bne  DREGSK5
        jsr  DUMPZP
DREGSK5:
        cmp   #'t'                  ; print out INBUF?
        bne  DREGSK4
        jsr  DUMPTIB
DREGSK4:        
        cmp   #'x'
        bne   DREGNXT
        jsr   $FE00                ; go to Wozmon if necc
DREGNXT:
        ply     ; and restore everything
        plx
        pla
        plp
        rts    

DUMPTIB:              ; dump TIB
        php
        pha
        ldy #0
        sty TEMP0
        lda #>INBUF
        sta TEMP0+1
        bra DSTKLP1

DUMPSTACK:            ; dump DS/RT stack area
        php
        pha
        ldy #0
        sty TEMP0
        lda #>DS
        sta TEMP0+1
        bra DSTKLP1
        
DUMPZP:               ; dump ZP
        php
        pha
        ldy #0
        sty TEMP0
        sty TEMP0+1   
DSTKLP1:
        tya
        jsr WRITE_BYTE
        lda #':'
        jsr WRITE_CHAR
DSTKLP2:
        lda (TEMP0), y
        jsr WRITE_BYTE
        lda #$20
        jsr WRITE_CHAR
        iny
        tya
        and #$0F       ; 00001111  
        beq  DSTKSKL   
        bra  DSTKLP2
DSTKSKL:
        WCRLF_np
        tya
        bne DSTKLP1        
DUMPSTKEND:
        WCRLF_np
        pla
        plp
        rts
.endif
;
; ---------------- end of upper.s
;