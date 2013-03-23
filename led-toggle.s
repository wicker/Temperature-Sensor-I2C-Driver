@ Author: Jenner Hanni - Winter 2013 - ECE372
@ Project #2b supplemental - Test the LED toggling on button press
@
@ ============================================================================ @
@ INITIALIZING PHASE            					       @
@ ============================================================================ @

.text
.global _start
_start:

@------------------@
@ Define addresses @
@------------------@

.EQU TOS,    0x1F
.EQU THYST,  0x1E

.EQU GPCR3,  0x40E00124
.EQU GPDR3,  0x40E0010C
.EQU GEDR3,  0x40E00148
.EQU GRER3,  0x40E00130
.EQU GAFR3L, 0x40E0006C

.EQU GPSR2,  0x40E0002C
.EQU GPCR2,  0x40E0002C
.EQU GPDR2,  0x40E00014
.EQU GRER2,  0x40E00038
.EQU GEDR2,  0x40E00050
.EQU GAFR2L, 0x40E00064

.EQU CAFRL,  0x000C0000   @ Value to clear or set bits 19 and 20

.EQU BIT3,   0x00000008   @ Value to clear or set bit 3
.EQU BIT7,   0x00000080   @ Value to clear or set bit 7
.EQU BIT9,   0x00000200   @ Value to clear or set bit 9
.EQU BIT10,  0x00000400   @ Value to clear or set bit 10

.EQU START,  0x00000069   @ ICR value where TB = 1, START = 1
.EQU MORE,   0x00000068   @ ICR value where TB = 1
.EQU ACK,    0x0000006C   @ ICR value where TB = 1, ACKNAK = 1
.EQU STOP,   0x0000006A   @ ICR value where TB = 1, STOP = 1

.EQU ICIP,   0x40D00000  @ Interrupt Controller IRQ Pending Register
.EQU ICMR,   0x40D00004  @ Interrupt Controller Mask Register

.EQU ICR,    0x40301690	 @ I2C Bus Control Register
.EQU ISR,    0x40301698	 @ I2C Bus Status Register
.EQU IDBR,   0x40301688	 @ I2C Data Buffer Register

@-------------------------------------------------------@
@ Initialize GPIO 73 as an input and rising edge detect @
@-------------------------------------------------------@

LDR R0, =GAFR2L @ Load pointer to GAFR2_L register
LDR R1, [R0]    @ Read GAFR2_L to get current value
BIC R1, #CAFRL  @ Clear bits 19 and 20 to make GPIO 73 not an alternate function
STR R1, [R0]    @ Write word back to the GAFR2_L

LDR R0, =GPCR2	@ Point to GPCR2 register
LDR R1, [R0]    @ Read current value of GPCR2 register
ORR R1, #BIT9	@ Word to clear bit 9
STR R1, [R0]	@ Write to GPCR2

LDR R0, =GPDR2	@ Point to GPDR2 register
LDR R1, [R0]	@ Read GPDR2 to get current value
BIC R1, #BIT9   @ Clear bit 9 to make GPIO 73 an input
STR R1, [R0]	@ Write word back to the GPDR2

LDR R0, =GRER2	@ Point to GRER2 register
LDR R1, [R0]	@ Read current value of GRER2 register
ORR R1, #BIT9   @ Load mask to set bit 9
STR R1, [R0]	@ Write word back to GRER2 register

@--------------------------------------------------------------@
@ Initialize GPIO 67 as an output, set low, set ONOROFF to OFF @
@--------------------------------------------------------------@

LDR R0, =GPCR2	@ Point to GPCR2 register
LDR R1, [R0]    @ Read current value of GPCR2 register
ORR R1, #0x08	@ Word to clear bit 3 to set pin low
STR R1, [R0]	@ Write to GPCR2

LDR R0, =GPDR2	@ Point to GPDR2 register
LDR R1, [R0]	@ Read GPDR2 to get current value
ORR R1, #0x08   @ Set bit 3 to make GPIO 67 an output
STR R1, [R0]	@ Write word back to the GPDR2

LDR R0,=ONOROFF	@ Point to the ONOROFF variable in memory
MOV R1, #0xA	@ Load value for OFF
STRB R1, [R0]	@ Write the byte for OFF back to memory

@-----------------------------------------------------------------@
@ Hook IRQ procedure address and install our IRQ_DIRECTOR address @
@-----------------------------------------------------------------@

MOV R0, #0x18	@ Load IRQ interrupt vector address 0x18
LDR R1, [R0]	@ Read instruction from interrupt vector table at 0x18
LDR R2, =0xFF   @ Construct mask (FFF or FF)?
AND R1, R1, R2	@ Mask all but offset part of instruction
ADD R1,R1,#0x20	@ Build absolute address of IRQ procedure in literal pool
LDR R2, [R1]	@ Read BTLDR IRQ address from literal pool
STR R2, BTLDR_IRQ_ADDRESS	@ Save BTLDR IRQ address for use in IRQ_DIRECTOR
LDR R3, =IRQ_DIRECTOR		@ Load absolute address of our interrupt director
STR R3, [R1]	@ Store this address literal pool

@----------------------------------------------------------------------------@
@ Initialize interrupt controller for button on IP<10> and I2C bus on IP<18> @
@----------------------------------------------------------------------------@

LDR R0, =ICMR	 @ Load pointer to address of ICMR register
LDR R1, [R0]	 @ Read current value of ICMR
ORR R1, #0x400
STR R1, [R0] 	 @ Write word back to ICMR register

@------------------------------------------------------------------------@
@ Make sure IRQ interrupt on processor enabled by clearing bit 7 in CPSR @
@------------------------------------------------------------------------@

MRS R3, CPSR	@ Copy CPSR to R3
BIC R3, #BIT7	@ Clear bit 7 (IRQ Enable bit)
MSR CPSR_c, R3	@ Write new counter value back in memory
		@ _c means modify the lower eight bits only

@ ============================================================================ @
@ RUNTIME PHASE								       @
@ ============================================================================ @

@----------------------------------------@
@ Wait in the main loop for an interrupt @
@----------------------------------------@

LOOP: 	NOP
	B LOOP

@-----------------------------------------------------------------------------@
@ IRQ_DIRECTOR - An interrupt has been detected! Test it to determine source. @
@-----------------------------------------------------------------------------@

IRQ_DIRECTOR:
	STMFD SP!, {R0-R2, LR}	@ Save registers on stack
	LDR R0, =ICIP	@ Point at IRQ Pending Register (ICIP)
	LDR R1, [R0]	@ Read ICIP
	TST R1, #BIT10	@ Check if GPIO 119:2 IRQ interrupt on IP<10> asserted
	BEQ PASSON	@ If no, must be some other source, break to PASSON

	LDR R0, =GEDR2	@ Point at GEDR2 
	LDR R1, [R0]	@ Read GEDR2
	TST R1, #BIT9	@ Check if GPIO pin 73 is the source
	BNE BTN_SVC	@ Yes, go service the button

@-----------------------------------------------------------@
@ PASSON - The interrupt is not from our button or the UART @
@-----------------------------------------------------------@

PASSON: 
	LDMFD SP!, {R0-R2,LR}		@ Restore the registers
	SUBS PC, LR, #4			@ Return to wait loop
@-------------------------------------------------------------@
@ BTN_SVC - The interrupt came from our button on GPIO pin 73 @
@-------------------------------------------------------------@

BTN_SVC:

	@ Clear the interupt
	LDR R0, =GEDR2		@ Point to GEDR2 
	LDR R1, [R0]		@ Read the current value from GEDR2
	ORR R1, #BIT9		@ Set bit 9 to clear the interrupt from pin 73
	STR R1, [R0]		@ Write to GEDR2

	LDR R0,=ONOROFF	@ Point to the ONOROFF variable in memory
	LDR R1, [R0]	@ Read value
	CMP R1, #0xA	@ Is the value 0x0A (OFF)
	BEQ LEDOFF	@ Yes, it's off so go turn it on
		
	@ Otherwise, it's on so turn it off
	LDR R0, =GPCR2		@ Point to GPCR2
	LDR R1, [R0]		@ Read from GPCR2
	ORR R1, R1, #0x08	@ Value to set bit 3 to 1 to output LED low
	STR R1, [R0]		@ Write back to GPSR2

	@ Set the value of the ONOROFF variable to 0x0A (OFF) 
	LDR R0, =ONOROFF	@ Point to ONOROFF variable
	MOV R1, #0x0A		@ Load value for ON state
	STRB R1, [R0]		@ Write the ON byte back to ONOROFF

	LDMFD SP!,{R0-R2,LR}	@ Restore the registers
	SUBS PC, LR, #4		@ Return from interrupt (to wait loop)

@-----------------------------------------------------@
@ LEDOFF - LED is off, turn it on and update variable @
@-----------------------------------------------------@

LEDOFF:
	@ Activate the LED
	LDR R0, =GPSR2		@ Point to GPSR2
	LDR R1, [R0]		@ Read from GPSR2
	ORR R1, R1, #0x08	@ Value to set bit 3 to 1 to output LED high
	STR R1, [R0]		@ Write back to GPSR2

	@ Set the value of the ONOROFF variable to 0x0B (ON) 
	LDR R0, =ONOROFF	@ Point to ONOROFF variable
	MOV R1, #0x0B		@ Load value for ON state
	STRB R1, [R0]		@ Write the ON byte back to ONOROFF

	LDMFD SP!,{R0-R2,LR}	@ Restore the registers
	SUBS PC, LR, #4		@ Return from interrupt (to wait loop)

@--------------------@
@ Build literal pool @
@--------------------@

BTLDR_IRQ_ADDRESS: .word 0

.data
ONOROFF: 	.word 0x0		@ 0xA means on, 0xB is off 

.end
