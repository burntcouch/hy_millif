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
    ERR_entry RPTR_ERR    ; RT stack full/empty  - error $01
    ERR_entry SPTR_ERR    ; DS stack full/empty  - error $02
    ERR_entry DIV_ERR    ; divide by zero - error $03
    ERR_entry OOM_ERR    ; out of memory  - error $04
    ERR_entry UKW_ERR    ; no existing word - error $05
    ERR_entry SEC_ERR    ; writing to dangerous RAM areas - error $06
    ERR_entry SYS_ERR    ; error on return from SYSCALL - error $07
LASTERR = 7
;
;  error messages
RPTR_ERR:
    .byte " !RT PTR ERROR!"
    .byte 0
SPTR_ERR:
    .byte " !DS PTR ERROR!"
    .byte 0
DIV_ERR:
    .byte " !DIV ZERO!"
    .byte 0
OOM_ERR:
    .byte " !LOW MEM!"
    .byte 0
UKW_ERR:
    .byte " !UNK WORD!"
    .byte 0
SEC_ERR:
    .byte " !SECURITY!"
    .byte 0
SYS_ERR:
    .byte " !SYS ERR!"
    .byte 0
;
;  used by DISASM, may be handy elsewhere eventually
;
WRITE_HSTRING:
                phx
                sta  TEMP8
                sty  TEMP8+1
                lda  (TEMP8)       ; Length of HString
                tax
                ldy  #0
@write_loop:
                iny
                lda  (TEMP8),Y
                jsr  WRITE_CHAR
                dex
                bne  @write_loop
                plx
                rts   
    
;-------------------------------------------------------------
;                MATH routines
;         with MULT16 / DIV16, signs handled by calling word.
;         we just do the math here.
;
; MULT16 not quite right; no fuck!  Complete botch, start again. (3/27)
;
MULT16:                ; 16 x 16 multiply; TEMP1 and TEMP2 are #'s, TEMP1 will be result
    stz TEMP3          ; with TEMP3 as high bytes
    stz TEMP3+1      
    ldx #17
    clc
MULTLOOP:
    ror TEMP3+1        ; RIGHT.  if you need to go backwards, go backwards stupid fuck.
    ror TEMP3
    ror TEMP1+1
    ror TEMP1
    bcc MULTDECCNT
    clc
    lda TEMP2
    adc TEMP3
    sta TEMP3
    lda TEMP2+1
    adc TEMP3+1
    sta TEMP3+1
MULTDECCNT:
    dex
    bne MULTLOOP
    rts
    
;
;
       ; 16 x 16 divide; TEMP1 and TEMP2 #'s - TEMP3 is 'overflow'
       ;  TEMP2 divisor, TEMP1 dividend, TEMP1 + 3 = result + remainder  
DIV16:
    stz TEMP3
    stz TEMP3+1
    ldx #16
UDIVLP:
    rol TEMP1              
    rol TEMP1+1
    rol TEMP3
    rol TEMP3+1
UDIVCHK:
    sec
    lda TEMP3
    sbc TEMP2
    tay
    lda TEMP3+1
    sbc TEMP2+1
    bcc UDIVCNT
    sty TEMP3
    sta TEMP3+1
UDIVCNT:    
    dex
    bne UDIVLP
    rol TEMP1
    rol TEMP1+1
    rts
;
;     galois32o - LSFR psuedo-random # generator
;
;  -- boilerplate --
; 6502 LFSR PRNG - 32-bit
; Brad Smith, 2019
; http://rainwarrior.ca
;
;
galois32o:
	; rotate the middle bytes left
	ldy RSEED+2 ; will move to RSEED+3 at the end
	lda RSEED+1
	sta RSEED+2
	; compute RSEED+1 ($C5>>1 = %1100010)
	lda RSEED+3 ; original high byte
	lsr
	sta RSEED+1 ; reverse: 100011
	lsr
	lsr
	lsr
	lsr
	eor RSEED+1
	lsr
	eor RSEED+1
	eor RSEED+0 ; combine with original low byte
	sta RSEED+1
	; compute RSEED+0 ($C5 = %11000101)
	lda RSEED+3 ; original high byte
	asl
	eor RSEED+3
	asl
	asl
	asl
	asl
	eor RSEED+3
	asl
	asl
	eor RSEED+3
	sty RSEED+3 ; finish rotating byte 2 into 3
	sta RSEED+0
	rts
;-------------------------------------------------------------------
;              get delimited text from INBUF, store in string
;

.ifndef TXT2STACK
;
;  uses TEMP1, TEMP2, TEMP3, TEMP5, TEMP6, X, Y
;
TEXTGET:
    stz TEMP1+1          ; will store length here
    lda #$04
    sta TEMP2            ; record type is 'sz'
    stz TEMP2+1
    stz TEMP6            ; to save y for later copy
    ldy #1               ; skip len of first token
TX2SKSPC:
    lda (NXTTOK),y
    cmp #$20             ; skip leading spaces
    bne TX2SK00
    iny
    bra TX2SKSPC
TX2SK00:
    cmp #'q'
    bne TX2NOGOOD
    iny
    lda (NXTTOK),y
    cmp #'^'
    bne TX2NOGOOD   
    iny
    sty TEMP6             ; temp6 stores pos of first char
TX2SCAN:
    lda (NXTTOK),y         ; find delimiting '^' 
    iny
    cmp #'^'
    beq TX2FOUND
    tya
    clc
    adc NXTTOK
    cmp #MAXSTR
    bcs TX2NOGOOD
    bra TX2SCAN
TX2FOUND:
    dey
    sty TEMP5        ; temp5 pos+1 last letter
    tya
    sec
    sbc TEMP6       
    sta TEMP1        ; and this should be the length
    inc TEMP1        ; and add one for zero at end
    
    jsr MALLOC      ; TEMP1 now has address on mem stack
    
    ldy #0
    lda (TEMP1),y
    sta TEMP2
    iny
    lda (TEMP1),y
    sta TEMP2+1    ; address in memory area

    ; now for math.  NXTTOK ptr needs to be ref'd with same y
    ; as TEMP2, so we need to match them up...and we are hitting
    ; the record at +3, so....TEMP6 is start
    lda TEMP2
    sec
    sbc TEMP6
    bcs TX2SK01
    dec TEMP2+1
TX2SK01:
    clc
    adc #3
    bcc TX2SK02
    inc TEMP2+1
TX2SK02:    
    ldy TEMP6
TX2CPYLOOP:
    lda (NXTTOK),y
    sta (TEMP2),y
    iny
    cpy TEMP5
    bne TX2CPYLOOP
TX2SK99:
    lda #0
    sta (TEMP2),y    ; put zero on end
    jsr spush_0    ; push address from mem stack on DS
    lda TEMP5
    sec
    sbc TEMP6
    clc
    adc #4
    tax
    clc
    jmp TX2END
TX2NOGOOD:
    sec
TX2END:
    rts
;
;  end of TXG2  (new text capture)
;

.else  ;  TXT2STACK

TEXTGET:
    stz TEMP6
		stz TEMP1
		stz TEMP1+1
    ldy #1               ; skip len
TXTSKIPSPC:
    lda (NXTTOK),y
    cmp #$20             ; skip leading spaces
    bne TXTSPCS
    iny
    bra TXTSKIPSPC
TXTSPCS:
    cmp #'q'
    bne TEXTNOGOOD
    iny
    lda (NXTTOK),y
    cmp #'^'
    bne TEXTNOGOOD
    sta TEMP3              ; remember....
    iny
TXTSCAN:
    lda (NXTTOK),y         ; find delimiting '^' 
    iny
    cmp #'^'
    beq TXTFOUND
    tya
    clc
    adc NXTTOK
    cmp #MAXSTR
    bcs TEXTNOGOOD
    bra TXTSCAN
TXTFOUND:
    ldx #0
    dey
    dey              ; now points at last letter
    tya
    sec
    sbc TEMP3        ; and this should be the length
    stx TEMP3
    and #1
    beq TEXTGLOOP
    inc TEMP3
    inx
TEXTGLOOP:
    lda (NXTTOK),y         
    cmp #'^'               ; when we hit the other end again...
    beq TEXTOK
    sta TEMP6
    
.ifdef DEBUG
    jsr DUMPREG          ; DEBUG
.endif

    txa
    and #1
    bne TEXTODD
    lda TEMP6
    sta TEMP1
    stz TEMP1+1
    bra TEXTSKIP2
TEXTODD:
    lda TEMP6
    sta TEMP1+1
    phx
    phy
    jsr spush_0
    ply
    plx
TEXTSKIP2:
    inx
    dey
.ifdef DEBUG
    jsr DUMPREG          ; DEBUG
.endif    
   bra TEXTGLOOP
TEXTOK:
    phy
    phx
    txa
    and #1
    beq TEXTCONT
    jsr spush_0
TEXTCONT:
    plx
    txa
    sec
    sbc TEMP3
    sta TEMP3
    stz TEMP3+1
    jsr spush_2         ; push length on top
    ply
    clc
    bra TEXTGEND
TEXTNOGOOD:
    sec
TEXTGEND:
    rts

.endif  ; ---TXT2STACK
    
;-----------------------   NUMBER CONVERSIONS
;
DEC2ASCII:       ;  X is # - return as two digits in TEMP3, TEMP3+1
    lda #$30
    sta TEMP3+1
    txa
    sta TEMP3
D2ASCLOOP:
    sec
    sbc #$0A
    bcc D2ASCNEXT
    inc TEMP3+1
    bra D2ASCLOOP
D2ASCNEXT:
    clc
    adc #$3A
    sta TEMP3
    rts

.ifdef numbers
;------------------------
;      CONVERT DIGITS, PUSH on DS

DIGCONVT:    ;  Y is index into NXTPTR, X is length
		stz TEMP1
		stz TEMP1+1
    stz TEMP2            ; no necc for bin or hex, but
		stz TEMP2+1          ; since is convenient....
		stz TEMP6
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
		inc TEMP6
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
    jmp DIGCONV_ERR              ; not really an error, just return and let 'find' to it
  .endif     
DIGCONV_LOOP:
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
DIGDEC:                           
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
		lda TEMP6                ; check for minus
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
H2NUM: .byte $27,$10
 .byte $03,$E8
 .byte $00,$64
 .byte $00,$0A
HEX2DEC:            ; low/high in A,Y - use X, TEMP1, TEMP3, TEMP4, TEMP6
   sty TEMP3+1
   sta TEMP3
   ldx #0
H2DDIV10:
   lda H2NUM,x
   sta TEMP4+1
   inx
   lda H2NUM,x
   sta TEMP4
   inx
   stz TEMP6
H2DLOOP:
   lda TEMP3+1
   cmp TEMP4+1
   bcc  H2DSK1
   bne  H2DSK0
   lda TEMP3
   cmp TEMP4
   bcc  H2DSK1
H2DSK0:
   lda TEMP3
   sec
   sbc TEMP4
   sta TEMP3
   lda TEMP3+1
   sbc TEMP4+1
   sta TEMP3+1
   inc TEMP6
   bra H2DLOOP
H2DSK1:
   lda TEMP6
   clc
   adc #$30
   sta TEMP1
   stz TEMP1+1
   phx
   jsr spush_0          ; remember!  A/X both destroyed with push and pull!
   plx
   cpx #8
   beq H2DFIN
   jmp H2DDIV10
H2DFIN:
   lda TEMP3
   clc
   adc #$30
   sta TEMP1
   stz TEMP1+1
   jsr spush_0   
   rts

;
;
.endif    ; numbers
;--------------------------------- CLEAR ------------------------------
;
;  zero out $C8 - $FF, meet and greet
;  zero out INBUF also
;
HYWELCOME:
    .byte CR, LF
    .byte "HyForth 0.85 04-24-2026"
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
        bne   DREGELSE
        jsr   $FE00                ; go to Wozmon if necc
DREGELSE:
        cmp   #$0D                 ; continue on enter
        beq   DREGNXT
        jmp   DPFCHECK             ; otherwise print eveything again
DREGNXT:
        ply     ; and restore everything
        plx
        pla
        plp
        rts    
;
;   subs for particular pages
;
DUMPTIB:              ; dump TIB
        php
        pha
        lda #>INBUF
        sta TEMP0+1
        jmp DUMPPDBG
DUMPSTACK:            ; dump DS/RT stack area
        php
        pha
        lda #>DS
        sta TEMP0+1
        jmp DUMPPDBG       
DUMPZP:               ; dump ZP
        php
        pha
        stz TEMP0+1
        jmp DUMPPDBG
.endif

DUMPPAGE:              ; general purpose page dumper
                       ; TEMP0 starts at zero, TEMP0+1 is page #
        php
        pha
DUMPPDBG:
        ldy #0
        sty TEMP0
DUMPLOOP:
        lda TEMP0+1
        jsr WRITE_BYTE
        tya
        jsr WRITE_BYTE
        lda #':'
        jsr WRITE_CHAR
DPLOOP2:
        lda (TEMP0), y
        jsr WRITE_BYTE
        lda #$20
        jsr WRITE_CHAR
        iny
        tya
        and #$0F       ; 00001111  
        beq  DPSKIP  
        bra  DPLOOP2
DPSKIP:
        lda #$20
        jsr WRITE_CHAR
        phy
        tya           
        sec
        sbc #$10      ; subtract 16 to rewind the line
        tay
DPPLOOP:
        lda (TEMP0), y   ; printable ascii
        cmp #$20
        bcc PPERIOD
        cmp #$7F
        bcs PPERIOD
        jsr WRITE_CHAR
        bra DPPSKIP
PPERIOD:
        lda #'.'
        jsr WRITE_CHAR        
DPPSKIP:
        iny
        tya
        and #$0F
        beq DPPEND
        bra DPPLOOP
DPPEND:
        ply
        WCRLF_np
        tya                ; need this to check y = 0
        bne DUMPLOOP       
DUMPSTKEND:
        WCRLF_np
        pla
        plp
        rts
;
;
;   DSS version of DISASM
;
; Offsets into MNEMONIC_STR
MN_adc := $2B
MN_and := $24
MN_asl := $10
MN_bbr := $90
MN_bbs := $66
MN_bcc := $71
MN_bcs := $38
MN_beq := $84
MN_bit := $57
MN_bmi := $52
MN_bne := $6B
MN_bpl := $45
MN_bra := $0E
MN_brk := $91
MN_bvc := $61
MN_bvs := $09
MN_clc := $2D
MN_cld := $2F
MN_cli := $89
MN_clv := $78
MN_cmp := $19
MN_cpx := $73
MN_cpy := $63
MN_stp := $7B
MN_dec := $76
MN_dex := $04
MN_dey := $26
MN_eor := $6D
MN_inc := $17
MN_inx := $54
MN_iny := $8B
MN_jmp := $94
MN_jsr := $4D
MN_lda := $22
MN_ldx := $30
MN_ldy := $12
MN_lsr := $1E
MN_nop := $5C
MN_ora := $6E
MN_pha := $7F
MN_php := $7D
MN_phx := $5E
MN_phy := $98
MN_pla := $29
MN_plp := $96
MN_plx := $46
MN_ply := $1B
MN_rmb := $82
MN_rol := $20
MN_ror := $33
MN_rti := $4F
MN_rts := $35
MN_sbc := $37
MN_sec := $87
MN_sed := $02
MN_sei := $0B
MN_smb := $8E
MN_sta := $49
MN_stx := $41
MN_sty := $3A
MN_stz := $68
MN_tax := $4A
MN_tay := $59
MN_trb := $07
MN_tsb := $36
MN_tsx := $3E
MN_txa := $42
MN_txs := $00
MN_tya := $3B
MN_wai := $15

AM_ACC   := 0     ;                     %0000
AM_REL   := 1     ; $rr => $aaaa        %0001
AM_ZPREL := 2     ; $zz,$rr => $aaaa    %0010
AM_ZP    := 3     ; $zz                 %0011
AM_ABSX  := 4     ; $aaaa,X             %0100
AM_ZPX   := 5     ; $zz,X               %0101
AM_ABSY  := 6     ; $aaaa,Y             %0110
AM_ZPY   := 7     ; $zz,Y               %0111
AM_IMP   := 8     ;                     %1000
AM_IMM   := 9     ; #$ii                %1001
AM_IND   := $A    ; ($aaaa)             %1010
AM_ZPIND := $B    ; ($zz)               %1011
AM_ABSIX := $C    ; ($aaaa,X)           %1110 
AM_ZPIX  := $D    ; ($zz,X)             %1101
AM_ABS   := $E    ; $aaaa               %1100
AM_ZPIY  := $F    ; ($zz),Y             %1111

.define M2(even, odd) (even + (odd*16))

MN_OFFSETS:
    .byte MN_brk, MN_ora, MN_nop, MN_nop, MN_tsb, MN_ora, MN_asl, MN_rmb, MN_php, MN_ora, MN_asl, MN_nop, MN_tsb, MN_ora, MN_asl, MN_bbr
    .byte MN_bpl, MN_ora, MN_ora, MN_nop, MN_trb, MN_ora, MN_asl, MN_rmb, MN_clc, MN_ora, MN_inc, MN_nop, MN_trb, MN_ora, MN_asl, MN_bbr
    .byte MN_jsr, MN_and, MN_nop, MN_nop, MN_bit, MN_and, MN_rol, MN_rmb, MN_plp, MN_and, MN_rol, MN_nop, MN_bit, MN_and, MN_rol, MN_bbr
    .byte MN_bmi, MN_and, MN_and, MN_nop, MN_bit, MN_and, MN_rol, MN_rmb, MN_sec, MN_and, MN_dec, MN_nop, MN_bit, MN_and, MN_rol, MN_bbr
    .byte MN_rti, MN_eor, MN_nop, MN_nop, MN_nop, MN_eor, MN_lsr, MN_rmb, MN_pha, MN_eor, MN_lsr, MN_nop, MN_jmp, MN_eor, MN_lsr, MN_bbr
    .byte MN_bvc, MN_eor, MN_eor, MN_nop, MN_nop, MN_eor, MN_lsr, MN_rmb, MN_cli, MN_eor, MN_phy, MN_nop, MN_nop, MN_eor, MN_lsr, MN_bbr
    .byte MN_rts, MN_adc, MN_nop, MN_nop, MN_stz, MN_adc, MN_ror, MN_rmb, MN_pla, MN_adc, MN_ror, MN_nop, MN_jmp, MN_adc, MN_ror, MN_bbr
    .byte MN_bvs, MN_adc, MN_adc, MN_nop, MN_stz, MN_adc, MN_ror, MN_rmb, MN_sei, MN_adc, MN_ply, MN_nop, MN_jmp, MN_adc, MN_ror, MN_bbr
    .byte MN_bra, MN_sta, MN_nop, MN_nop, MN_sty, MN_sta, MN_stx, MN_smb, MN_dey, MN_bit, MN_txa, MN_nop, MN_sty, MN_sta, MN_stx, MN_bbs
    .byte MN_bcc, MN_sta, MN_sta, MN_nop, MN_sty, MN_sta, MN_stx, MN_smb, MN_tya, MN_sta, MN_txs, MN_nop, MN_stz, MN_sta, MN_stz, MN_bbs
    .byte MN_ldy, MN_lda, MN_ldx, MN_nop, MN_ldy, MN_lda, MN_ldx, MN_smb, MN_tay, MN_lda, MN_tax, MN_nop, MN_ldy, MN_lda, MN_ldx, MN_bbs
    .byte MN_bcs, MN_lda, MN_lda, MN_nop, MN_ldy, MN_lda, MN_ldx, MN_smb, MN_clv, MN_lda, MN_tsx, MN_nop, MN_ldy, MN_lda, MN_ldx, MN_bbs
    .byte MN_cpy, MN_cmp, MN_nop, MN_nop, MN_cpy, MN_cmp, MN_dec, MN_smb, MN_iny, MN_cmp, MN_dex, MN_wai, MN_cpy, MN_cmp, MN_dec, MN_bbs
    .byte MN_bne, MN_cmp, MN_cmp, MN_nop, MN_nop, MN_cmp, MN_dec, MN_smb, MN_cld, MN_cmp, MN_phx, MN_stp, MN_nop, MN_cmp, MN_dec, MN_bbs
    .byte MN_cpx, MN_sbc, MN_nop, MN_nop, MN_cpx, MN_sbc, MN_inc, MN_smb, MN_inx, MN_sbc, MN_nop, MN_nop, MN_cpx, MN_sbc, MN_inc, MN_bbs
    .byte MN_beq, MN_sbc, MN_sbc, MN_nop, MN_nop, MN_sbc, MN_inc, MN_smb, MN_sed, MN_sbc, MN_plx, MN_nop, MN_nop, MN_sbc, MN_inc, MN_bbs

MN_AMODE_EVEN:
    .byte $88,$33,$08,$EE	; %0000xxx0
    .byte $B1,$53,$08,$4E	; %0001xxx0
    .byte $8E,$33,$08,$EE	; %0010xxx0
    .byte $B1,$55,$08,$44	; %0011xxx0
    .byte $88,$38,$08,$EE	; %0100xxx0
    .byte $B1,$58,$88,$48	; %0101xxx0
    .byte $88,$33,$08,$EA	; %0110xxx0
    .byte $B1,$55,$88,$4C	; %0111xxx0
    .byte $81,$33,$88,$EE	; %1000xxx0
    .byte $B1,$75,$88,$4E	; %1001xxx0
    .byte $99,$33,$88,$EE	; %1010xxx0
    .byte $B1,$75,$88,$64	; %1011xxx0
    .byte $89,$33,$88,$EE	; %1100xxx0
    .byte $B1,$58,$88,$48	; %1101xxx0
    .byte $89,$33,$88,$EE	; %1110xxx0
    .byte $B1,$58,$88,$48	; %1111xxx0
; 
    .byte $8D,$33,$89,$2E	; %xxx0xxx1
    .byte $8F,$35,$86,$24	; %xxx1xxx1

; 0..3 = even indexes, 4..7 = odd
;extra bytes:
;x000 = 0
;xxx1 = 1
;xyy0 = 2 (yy != 00)
;x1xx = Indexed
;   x10x = Indexed by X
;   x11x = Indexed by Y
;1xxx = Indirect (xxx != 000 and xxx != 1x0)

; x000: one byte
; xxx1: two byte
; xxx0 (!x000): three byte
; x10x == ,X
; x11x == ,Y

MNEMONIC_STR:
    .byte "TXSEDEXTRBVSEIBRASLDYWAINCMPLYLSROLDANDEYPLADCLCLDXRORTSBCSTYATSXSTXABPLXSTAXJSRTIBMINXBITAYNOPHXBVCPYBBSTZBNEORABCCPXDECLVSTPHPHARMBEQSECLINYSMBBRKJMPLPHY"

NamedHString HS_RelPrefix, " => $"

; ZP_XAM, ZP_XAM+1: Address to Disassemble
; .A.Y: Start address of instruction to disassemble
; C=0 means single instruction, C=1 means number of instructions/bytes to print in .X
; set ZP_D_STATE=1 to print disassembly, ZP_D_STATE=0 to print bytes
;
;  ZEROPAGE usage:  see 'hyforth.s' for details, but....
;
;  ZP_XAM is defined in the OS at $31
;  ZP_D_ICOUNT => TEMP3
;  ZP_D_EXBYTES => TEMP3+1
;  ZP_D_STATE => TEMP4
;  ZP_D_MODE => TEMP4+1
;  ZP_D_INST => TEMP6
;  ZP_TEMP => TEMP5
;  TEMP8 at $D0  (for WRITE_HSTRING and etc.)
;
DISASM_AY:
    sty         ZP_XAM + 1
    sta         ZP_XAM
    bcc         DISASM
    clc
    stx         ZP_D_ICOUNT
    bne         DISASM_LOOP
    rts

DISASM:                         ; assume ZP_XAM already has address
    stz         ZP_D_ICOUNT     ; and just do one instruction
    inc         ZP_D_ICOUNT

DISASM_LOOP:
    lda #$0D
    jsr WRITE_CHAR
    lda #$0A
    jsr WRITE_CHAR
    lda  ZP_XAM+1              ; print address 
    jsr  WRITE_BYTE
    lda  ZP_XAM
    jsr  WRITE_BYTE
    lda #':'
    jsr  WRITE_CHAR
    
    jsr         _disasm_load_inst
    jsr         _disasm_print_inst_bytes
    lda         ZP_D_STATE
    bne         disa001
    jmp         END_OF_PRINT

disa001:
    ldy         #0
    jsr         _disasm_print_padding
    lda      #$20
    jsr      WRITE_CHAR
    lda      #'|'
    jsr      WRITE_CHAR
    lda      #$20
    jsr      WRITE_CHAR
    ldx         ZP_D_INST
    lda         MN_OFFSETS, x
    tax
    lda         MNEMONIC_STR, x
    ora  #$20                         ; lower case?
    jsr         WRITE_CHAR
    lda         MNEMONIC_STR+1, x
    ora  #$20                         ; lower case?
    jsr         WRITE_CHAR
    lda         MNEMONIC_STR+2, x
    ora  #$20                         ; lower case?
    jsr         WRITE_CHAR    
    lda         ZP_D_EXBYTES
    bne         disa002
    jmp         END_OF_PRINT       ; one-byte inst prints only mnemonic

disa002:
    lda         ZP_D_INST
    tax
    and         #7
    cmp         #7                  ; BBR, BBS, RMB, SMB
    bne         @ex_space
    txa
    SR_N        4
    and         #7
    jsr    WRITE_BYTE
    bra         @skip_ex_space      ; skip one space

@ex_space:
    lda #$20
    jsr WRITE_CHAR

@skip_ex_space:
    lda #$20
    jsr WRITE_CHAR
    ldx         ZP_D_MODE
    cpx         #AM_IND             ; indirect
    bcc         @not_indirect
    cpx         #AM_ABS             ; but not absolute
    beq         @not_indirect
    lda     #'('
    jsr     WRITE_CHAR

@not_indirect:
    cpx         #AM_IMM
    bne         @not_immediate
    jsr         _disasm_immediate
    jmp         END_OF_PRINT

@not_immediate:
    cpx         #AM_ZP              ; relative?
    bcs         @not_relative
    jsr         _disasm_zeropage
    txa
    lsr                             ; shift LOb to C
    bcs         @not_zprel          ; AM_REL = 1, AM_ZPREL = 2, so skip ZP part if LOb is 1
    lda  #','
    jsr  WRITE_CHAR
    lda  #$20
    jsr  WRITE_CHAR
    jsr         _disasm_zeropage

@not_zprel:
    lda             #<HS_RelPrefix
    ldy             #>HS_RelPrefix
    jsr             WRITE_HSTRING
    
    clc
    ldy         ZP_D_EXBYTES
    stz         TEMP5
    lda         ZP_D_INST, y
    bpl         @skip_ff_set
    dec         TEMP5                           

@skip_ff_set:
    adc         ZP_XAM
    tax
    lda         ZP_XAM + 1
    adc         TEMP5
    jsr WRITE_BYTE
    txa
    jsr WRITE_BYTE
    bra         END_OF_PRINT

@not_relative:
    lda         ZP_D_EXBYTES
    cmp         #1
    beq         @two_byte_inst      ; inst is two bytes (vs three)?
    jsr         _disasm_absolute
    bra         @continue_multibyte

@two_byte_inst:
    jsr         _disasm_zeropage

@continue_multibyte:
    cpx         #AM_ABS             ; absolute?
    beq         END_OF_PRINT
    cpx         #AM_ZPIY
    bne         @not_zpiy
    lda   #')'
    jsr   WRITE_CHAR

@not_zpiy:
    bbr2        ZP_D_MODE, @not_indexed   ; indexed?
    txa
    lsr
    lsr                                   ; shift LOb to C
    jsr         _disasm_commaXY

@not_indexed:
    cpx         #AM_IND
    bmi         END_OF_PRINT
    cpx         #AM_ABS
    bcs         END_OF_PRINT          ; AM_ABS or AM_ZPIY?  Skip trailing RPAREN
    lda    #')'
    jsr   WRITE_CHAR

END_OF_PRINT:
    dec         ZP_D_ICOUNT
    beq         @done
    jmp         DISASM_LOOP

@done:

    rts

;---------------------------------------
; Helper procedures

_disasm_load_inst:
    ldy         #0
    ldx         ZP_D_STATE
    beq         @done               ; if not in DISASM mode, just print one byte
    lda         (ZP_XAM)
    lsr                             ; /2 and shift LOb to C
    bcc         @shift_mode         ; is even bytecode?
    and         #$0F
    ora         #$80

@shift_mode:
    lsr
    tax
    lda         MN_AMODE_EVEN, x
    bcc         @no_shift
    SR_N        4

@no_shift:
    and         #$0F
    sta         ZP_D_MODE
    and         #7                  ; test if bits 0..2 are zeros (one-byte inst)
    beq         @done
    iny
    and         #1
    bne         @done               ; odd modes are 2-byte inst
    iny

@done:
    sty         ZP_D_EXBYTES
    ldy         #0

disa003:
    jsr         _disasm_inst_byte
    cpy         ZP_D_EXBYTES
    beq         disa004
    iny
    bra         disa003

disa004:
    rts

;AM_ACC   := 0     ;                     %0000
;AM_REL   := 1     ; $rr => $aaaa        %0001
;AM_ZPREL := 2     ; $zz,$rr => $aaaa    %0010
;AM_ZP    := 3     ; $zz                 %0011
;AM_ABSX  := 4     ; $aaaa,X             %0100
;AM_ZPX   := 5     ; $zz,X               %0101
;AM_ABSY  := 6     ; $aaaa,Y             %0110
;AM_ZPY   := 7     ; $zz,Y               %0111
;AM_IMP   := 8     ;                     %1000
;AM_IMM   := 9     ; #$ii                %1001
;AM_IND   := $A    ; ($aaaa)             %1010
;AM_ZPIND := $B    ; ($zz)               %1011
;AM_ABSIX := $C    ; ($aaaa,X)           %1100 
;AM_ZPIX  := $D    ; ($zz,X)             %1101
;AM_ABS   := $E    ; $aaaa               %1110
;AM_ZPIY  := $F    ; ($zz),Y             %1111

_disasm_inst_byte:
    lda         (ZP_XAM)
    sta         ZP_D_INST, y
    inc         ZP_XAM
    bne         disa005
    inc         ZP_XAM + 1

disa005:
    rts

_disasm_print_inst_bytes:    
    ldy         #0
    bra         disa006

disa007:
    iny

disa006:
    lda   #$20
    jsr   WRITE_CHAR
    lda   ZP_D_INST, y                
    jsr   WRITE_BYTE
    cpy         ZP_D_EXBYTES
    bcc         disa007
    rts

_disasm_print_padding:
    lda         ZP_D_EXBYTES
    cmp         #1
    beq         disa008
    eor         #2
    beq         disa010

disa008:
    tax

disa009:
    lda #$20
    jsr WRITE_CHAR
    lda #$20
    jsr WRITE_CHAR
    lda #$20
    jsr WRITE_CHAR
    dex
    bne         disa009

disa010:
    rts

; Carry: 1 = Y, Carry: 0 = X
_disasm_commaXY:
    lda   #','
    jsr   WRITE_CHAR
    lda         #'X'
    bcc         disa011
    inc
disa011:
    jsr  WRITE_CHAR
    rts                           ; not sure here but...

_disasm_absolute:
    iny
    iny
    lda  #'$'
    jsr  WRITE_CHAR
    lda   ZP_D_INST,y
    jsr   WRITE_BYTE
    dey
    lda   ZP_D_INST,y
    jsr   WRITE_BYTE
    rts
    
_disasm_immediate:
    lda  #'#'
    jsr  WRITE_CHAR
    ; fall through

_disasm_zeropage:
    iny
    lda  #'$'
    jsr  WRITE_CHAR
    lda   ZP_D_INST,y
    jsr   WRITE_BYTE
    rts    
        
; ---------------- end of DISASM
;     
;
; ---------------- end of upper.s
;