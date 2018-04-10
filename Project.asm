;*** PORTS **** 
DDRA  EQU $0002
PORTA EQU $0000
PUCR  EQU $000C
PORTB EQU $01
DDRB  EQU $03
PORTM EQU $0250
DDRM  EQU $0252
PSHBTN EQU $3451
;**************

; Include .hc12 directive, in case you need MUL
.hc12

	org $400
	LDS	#$4000
	
	LDAA 	  #$FF		  ; Initialize DDRA so PORTA is all outputs
	STAA 	  DDRA	
	ldaa 	  #$0F		  ;0F
	STAA 	  DDRB		  ; Set port B for in[7..4], out[3..0]
	
	JSR InitLCD				;Initialize LCD
	
	des
	CLRB
	STAB 0,SP
	
ReScan:	des	 	  ; Create room on the stack for the return value
		jsr ScanOnce      ; Do one scan of the keypad
		pula		  ; Get the return value
		cmpa #$FF	  ; Invalid return value
		beq ReScan
		psha	  	  ; Store the current return value
		ldy #!50  	  ; 50 ms debounce delay
		pshy
		jsr Delay
		ins		  ; Only clean up one byte, since we need RValue
		jsr ScanOnce 	  ; Do another scan
		
		;At this point key is in A and B
		pula		  ; Get the return value
		pulb		  ; Get the previous return value
		cba		  ; Are they the same?
		bne ReScan	  ; If not, do nothing

		;Check if user is golding the bottom
		;CMPA lastBtn
		;BEQ ReScan	;Ignore if the same button
		;STAA lastBtn

		cmpa #$01	 ; Is button pressed 1?
		beq COUNT	 ; If yes, branch to count

		cmpa #$02	 ; If not, is it 2?
		beq RESET	 ; If yes, branch to reset

		bra ReScan	 ; Otherwise, branch to ReScan
				
										
ScanOnce:       clrb
top:            ldx #OutputMasks	; This lookup table contains the
                ldaa b,x		; single-zero outputs for the
                staa PORTB		; columns
		jsr Delay1MS		; Wait so the output can settle
                ldaa PORTB		; Read the input
                lsra 			; Shift right four times.  The rows
                lsra			; are in the high order bits
                lsra
                lsra
                anda #$0F		; Input $F means no key pressed
                cmpa #$0F		; Input anything else means keypressed
                beq next_test		; On $F, move to the next column
                ldx #ColAddr		; On not-$F, load the current column
                ldy b,x			; look-up table
                ldaa a,y		; At this point, A contains the solution
		tsx
                staa 2,x  	 	; Write the answer to the stack
		rts	 		; and return
next_test:      incb			; We need to increment twice so B will 
                incb			; properly index the row and column tables
                cmpb #8			; When B reaches 8, we're done
                blt top
                ldaa #$FF		; If B reached 8, return $FF to indicate
		tsx	 		; no key pressed
		staa 2,x
		rts                

				
RESET: 	  PULB
		  CLRB
		  PSHB
		  BRA 	DONE
			  
COUNT: 	  LDAB  0,SP
		  CMPB	#$64	  	   ; Compare if last value is 99($64) 
		  
		  BEQ	RESET
		  INC	0,SP
		  
DONE:	  JSR 	writeToLcd
		  BRA 	ReScan
				

writeToLcd:	;Write countValue to LCD.		
		LDAA #$01
		STAA PORTA
		LDAA #$10
		STAA PORTM
		BCLR PORTM,$10
		JSR  Delay1MS
		BSET PORTM,$10
		
		JSR DelayL
						
		;Init LCD to write
		BSET PORTM,$14	
		
		
		;Split into two digits
		LDX	    #!10
		CLRA
		LDAB 	$3FFF
		IDIV		 		  ;X has the first digit, D has the second
		PSHB				  ;Save second digit for later use
		
		;Write first digit
		PSHX
		PULA
		PULA
		ADDA	#$30	  	  ;Add 0011 0000 to the digit 
						 	  ; to get the LCD character (refer to LCD manual)
		STAA	PORTA
		BCLR	PORTM,$10
		JSR 	Delay1MS
		BSET	PORTM,$10
		
		;Write second digit
		PULA		  	   ;Now we can get that second digit we saved before
		ADDA	#$30	   ;Add 0011 0000 to the digit 
						   ; to get the LCD character (refer to LCD manual)
		STAA	PORTA
		BCLR	PORTM,$10
		JSR 	Delay1MS
		BSET	PORTM,$10
		
		RTS
				

DelayL:		LDY	#!100
DELAY2		JSR	Delay1MS
			DEY
			BNE DELAY2
			RTS

Delay1MS:  	LDX #!2000
DelayLoop:	DEX
		BNE DelayLoop
		RTS
		
Delay:      tsx
            ldy 2,x		 ; The decrement can't be done in place.
            dey	   		 ; DEC 2,X is a one byte operation
            sty 2,x		 ; That's why I use Y as a temp.
            beq DelayEnd
            jsr Delay1MS
            bra Delay
DelayEnd    rts             

;LCD init
InitLCD:	
		ldaa #$FF 	; Set port A to output for now
		staa DDRA
		
        ldaa #$1C 	; Set port M bits 4,3,2
		staa DDRM

		LDAA #$30	; We need to send this command a bunch of times
		psha
		LDAA #5
		psha
		jsr SendWithDelay
		pula

		ldaa #1
		psha
		jsr SendWithDelay
		jsr SendWithDelay
		jsr SendWithDelay
		pula
		pula

		ldaa #$08
		psha
		ldaa #1
		psha
		jsr SendWithDelay
		pula
		pula

		ldaa #1
		psha
		psha
		jsr SendWithDelay
		pula
		pula

		ldaa #6
		psha
		ldaa #1
		psha
		jsr SendWithDelay
		pula
		pula

		ldaa #$0E
		psha
		ldaa #1
		psha
		jsr SendWithDelay
		pula
		pula
		
		rts

SendWithDelay:
		TSX
		LDAA 3,x
		STAA PORTA

		bset PORTM,$10	 ; Turn on bit 4
		jsr Delay1MS
		bclr PORTM,$10	 ; Turn off bit 4

		tsx
		ldaa 2,x
		psha
		clra
		psha
		jsr Delay
		pula
		pula
		rts
		

;Keypad stuff
; OK.  Valid values are single zeros, so that's 7, B, D, E.  Others fault                
ColOne:         db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$0A,$FF,$FF,$FF,$07,$FF,$04,$01,$FF
ColTwo:         db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$08,$FF,$05,$02,$FF
ColThree:       db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$0B,$FF,$FF,$FF,$09,$FF,$06,$03,$FF
ColFour:        db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$0C,$FF,$FF,$FF,$0D,$FF,$0E,$0F,$FF

ColAddr:        dw  ColOne,ColTwo,ColThree,ColFour

; Output mask must be padded, so we can step by 2s through the ColAddr array
OutputMasks:    db $E,$FF,$D,$Ff,$B,$FF,$7,$FF
