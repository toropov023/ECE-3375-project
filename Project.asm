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
	ldaa 	  #$0F
	STAA 	  DDRB		  ; Set port B for in[7..4], out[3..0]
			
	ldaa 	  #$0
	staa 	  lastbtn
	ldaa 	  #$0
	staa 	  countValue
	
ReScan:			des	 	   	  ; Create room on the stack for the return value
				jsr ScanOnce  ; Do one scan of the keypad
				pula		  ; Get the return value
				cmpa #$FF	  ; Invalid return value
				beq ReScan
				psha	  	  ; Store the current return value
				ldy #!50  	  ; 50 ms debounce delay
				pshy
				jsr Delay
				ins		 	  ; Only clean up one byte, since we need RValue
				jsr ScanOnce  ; Do another scan
				pula		  ; Get the return value
				pulb		  ; Get the previous return value
				cba			  ; Are they the same?
				bne ReScan	  ; If not, do nothing
								
				;At this point key is in A and B
				;cmpa lastBtn
				;beq ReScan
				;staa lastBtn
				
				cmpa #$01	 ; Is button pressed 1?
				beq COUNT	 ; If yes, branch to count
				
				cmpa #$02	 ; If not, is it 2?
				beq RESET	 ; If yes, branch to reset
				
				bra ReScan	 ; Otherwise, branch to ReScan
				
										
ScanOnce:       clrb
top:            ldx #OutputMasks	; This lookup table contains the
                ldaa b,x			; single-zero outputs for the
                staa PORTB			; columns
				jsr Delay1MS		; Wait so the output can settle
                ldaa PORTB			; Read the input
                lsra 				; Shift right four times.  The rows
                lsra				; are in the high order bits
                lsra
                lsra
                anda #$0F			; Input $F means no key pressed
                cmpa #$0F			; Input anything else means keypressed
                beq next_test		; On $F, move to the next column
                ldx #ColAddr		; On not-$F, load the current column
                ldy b,x				; look-up table
                ldaa a,y			 ; At this point, A contains the solution
				tsx
                staa 2,x  	 	  	; Write the answer to the stack
				rts	 				; and return
next_test:      incb				; We need to increment twice so B will 
                incb				; properly index the row and column tables
                cmpb #8				; When B reaches 8, we're done
                blt top
                ldaa #$FF			; If B reached 8, return $FF to indicate
				tsx	 				; no key pressed
				staa 2,x
				rts                

				
RESET: 		  CLRB
			  STAB	countValue
			  BRA 	DONE
			  
COUNT: 		  LDAB	countValue
			  CMPB	#$08	  	   ; Compare if last value is 99($64)/8($08)
			  BEQ	RESET
			  INCB
			  STAB	countValue
DONE:		  JSR 	DISPLAY
			  BRA 	ReScan	  
	   
DISPLAY: 	  LDAA	countValue
			  JSR	CONVERSION
			  STAB	PORTA
	   		  RTS			
				
				

Delay1MS:  	LDX #!2000 		  ; Modify to change delay
DelayLoop:	DEX				  ; Time
			BNE DelayLoop
			RTS
			
; 50ms debounce delay				
Delay:      tsx
            ldy 2,x		 ; The decrement can't be done in place.
            dey	   		 ; DEC 2,X is a one byte operation
            sty 2,x		 ; That's why I use Y as a temp.
            beq DelayEnd
            jsr Delay1MS
            bra Delay
DelayEnd    rts             
			
			
			

;Keypad stuff
; OK.  Valid values are single zeros, so that's 7, B, D, E.  Others fault                
ColOne:         db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$0A,$FF,$FF,$FF,$07,$FF,$04,$01,$FF
ColTwo:         db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$08,$FF,$05,$02,$FF
ColThree:       db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$0B,$FF,$FF,$FF,$09,$FF,$06,$03,$FF
ColFour:        db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$0C,$FF,$FF,$FF,$0D,$FF,$0E,$0F,$FF

ColAddr:        dw  ColOne,ColTwo,ColThree,ColFour

; Output mask must be padded, so we can step by 2s through the ColAddr array
OutputMasks:    db $E,$FF,$D,$Ff,$B,$FF,$7,$FF

countValue:   db   1		  ; Store counter
lastBtn:	  db   1		  ; Last pressed key


;Conversion to compare with decimal for trial with LEDs
CONVERSION: 	CMPA #!0
				BEQ CASE1
				CMPA #!1
				BEQ CASE2
				CMPA #!2
				BEQ CASE3
				CMPA #!3
				BEQ CASE4
				CMPA #!4
				BEQ CASE5
				CMPA #!5
				BEQ CASE6
				CMPA #!6
				BEQ CASE7
				CMPA #!7
				BEQ CASE8
				CMPA #!8
				BEQ CASE9

CASE1: 		LDAB #$00
       		RTS
CASE2: 		LDAB #$01
	   		RTS
CASE3: 		LDAB #$03
	   		RTS
CASE4: 		LDAB #$07
	   		RTS
CASE5: 		LDAB #$0F
	   		RTS
CASE6: 		LDAB #$1F
	   		RTS
CASE7: 		LDAB #$3F
	   		RTS
CASE8: 		LDAB #$7F
	   		RTS 	
CASE9: 		LDAB #$FF
	   		RTS