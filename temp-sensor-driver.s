@ Author: Jenner Hanni - Winter 2013 - ECE372
@ Project #2 - LM75 Temperature Sensor
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

.EQU GPCR2,  0x40E0002C
.EQU GPDR2,  0x40E00014
.EQU GRER2,  0x40E00038
.EQU GEDR2,  0x40E00050
.EQU GAFR2L, 0x40E00064

.EQU CAFRL,  0x000C0000   @ Value to clear or set bits 19 and 20

.EQU BIT0,   0x00000001   @ Value to clear or set bit 0
.EQU BIT3,   0x00000008   @ Value to clear or set bit 3
.EQU BIT4,   0x00000010   @ Value to clear or set bit 4
.EQU BIT6,   0x00000040   @ Value to clear or set bit 6
.EQU BIT7,   0x00000080   @ Value to clear or set bit 7
.EQU BIT9,   0x00000200   @ Value to clear or set bit 9
.EQU BIT10,  0x00000400   @ Value to clear or set bit 10
.EQU BIT14,  0x00004000   @ Value to clear or set bit 14
.EQU BIT20,  0x00100000   @ Value to clear or set bit 20
.EQU B1018,  0x00040400   @ Value to clear or set bits 10 and 18
.EQU BIT18,  0x00040000   @ Value to clear or set bit 18

.EQU START,  0x00000069   @ ICR value where TB = 1, START = 1
.EQU MORE,   0x00000068   @ ICR value where TB = 1
.EQU ACK,    0x0000006C   @ ICR value where TB = 1, ACKNAK = 1
.EQU STOP,   0x0000006A   @ ICR value where TB = 1, STOP = 1

.EQU ICIP,   0x40D00000  @ Interrupt Controller IRQ Pending Register
.EQU ICMR,   0x40D00004  @ Interrupt Controller Mask Register

.EQU ICR,    0x40301690	 @ I2C Bus Control Register
.EQU ISR,    0x40301698	 @ I2C Bus Status Register
.EQU IDBR,   0x40301688	 @ I2C Data Buffer Register
.EQU ISAR,   0x403016A0	 @ I2C Slave Address Register

@-------------------------------------------------------@
@ Initialize GPIO 73 as an input and rising edge detect @
@-------------------------------------------------------@

LDR R0, =GAFR2L @ Load pointer to GAFR2_L register
LDR R1, [R0]    @ Read GAFR2_L to get current value
BIC R1, #CAFRL  @ Clear bits 19 and 20 to make GPIO 73 not an alternate function
STR R1, [R0]    @ Write word back to the GAFR2_L

LDR R0, =GPCR2	@ Point to GPCR2 register
LDR R1, [R0]    @ Read current value of GPCR2 register
ORR R1, #BIT9	@ Word to clear bit 9, sign off when output
STR R2, [R0]	@ Write to GPCR2

LDR R0, =GPDR2	@ Point to GPDR2 register
LDR R1, [R0]	@ Read GPDR2 to get current value
BIC R1, #BIT9   @ Clear bit 9 to make GPIO 73 an input
STR R1, [R0]	@ Write word back to the GPDR2

LDR R0, =GRER2	@ Point to GRER2 register
LDR R1, [R0]	@ Read current value of GRER2 register
ORR R1, #BIT9   @ Load mask to set bit 9
STR R1, [R0]	@ Write word back to GRER2 register

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
MOV R2, #0x40000 @ Load mask 
ORR R2, #0x400
ORR R1, R1, R2	 @ Set bit 10 and 18 to unmask IM10
STR R1, [R0] 	 @ Write word back to ICMR register

@------------------------------------------------------------------------@
@ Make sure IRQ interrupt on processor enabled by clearing bit 7 in CPSR @
@------------------------------------------------------------------------@

MRS R3, CPSR	@ Copy CPSR to R3
BIC R3, #BIT7	@ Clear bit 7 (IRQ Enable bit)
MSR CPSR_c, R3	@ Write new counter value back in memory
		@ _c means modify the lower eight bits only

@-------------------------------@
@ Initialize the I2C Controller @
@-------------------------------@

LDR R0, =ICR    @ Load pointer to address of ICR register
MOV R1, #0x60   @ Set bits to enable fast mode, I2C unit, and SCL 
STR R1, [R0]    @ Write word back to ICR register

@LDR R0, =ISAR   @ Load pointer to address of ISAR register
@MOV R1, #0x48   @ Write value of slave address
@STR R1, [R0]    @ Write word back to the ISAR register

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
	BNE BTN_SVC	@ Yes, must be button press, go service the button
			@ No, must be other IRQ, pass on: 

@-----------------------------------------------------------@
@ PASSON - The interrupt is not from our button or the UART @
@-----------------------------------------------------------@

PASSON: 
	LDMFD SP!, {R0-R2,LR}		@ Restore the registers
	LDR PC, =BTLDR_IRQ_ADDRESS	@ Go to bootloader IRQ service procedure

@-------------------------------------------------------------@
@ BTN_SVC - The interrupt came from our button on GPIO pin 73 @
@-------------------------------------------------------------@

BTN_SVC:
	LDR R0, =GEDR2		@ Point to GEDR2 
	LDR R1, [R0]		@ Read the current value from GEDR2
	ORR R1, #BIT9		@ Set bit 9 to clear the interrupt from pin 73
	STR R1, [R0]		@ Write to GEDR2

	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x91		@ Load the value to read from the slave address
	STR R1, [R0]		@ Write to IDBR

	LDR R0, =ICR		@ Point to ICR
	MOV R1, #START		@ Load the value for START
	STR R1, [R0]		@ Write to ICR

	BL POLLTB

	LDR R0, =ICR		@ Point to ICR
	MOV R1, #MORE		@ Load the value to request the read
	STR R1, [R0]		@ Write to ICR

	BL POLLTB

	LDR R0, =IDBR		@ Point to IDBR
	LDR R3, [R0]		@ Save the read temperature byte in R3
	LSL R3, #1		@ Shift the temperature byte left by 1 bit

	LDR R0, =ICR		@ Point to ICR
	MOV R1, #ACK		@ Load the value to acknowledge the byte received
	STR R1, [R0]		@ Write to ICR

	BL POLLTB

	LDR R0, =IDBR		@ Point to IDBR
	LDR R1, [R0]		@ Save the read temperature byte in R1
	AND R1, #0x80		@ Retain only the value in bit 7
	LSR R1, #7		@ Move that value to bit 0 of R1
	AND R3, R3, R1		@ Put the value of that bit in the LSB of R3 
				@ to get the complete temperature value

	LDR R0, =ICR		@ Point to ICR
	MOV R1, #STOP		@ Load the value for STOP
	STR R1, [R0]		@ Write to ICR

	LDMFD SP!,{R0-R2,LR}	@ Restore the registers
	SUBS PC, LR, #4		@ Return from interrupt (to wait loop)

@--------------------------------------------------@
@ POLLTB - Wait for acknowledgement from the slave @
@--------------------------------------------------@

POLLTB: 
	LDR R0, =ISR		@ Point to ISR
	LDR R1, [R0]		@ Read value from ISR
	TST R1, #BIT10		@ Test if BED on bit 10 is set = ACK error
	BNE EXIT		@ If yes, exit on error

	LDR R0, =ICR		@ Point to ICR
	LDR R1, [R0]		@ Read value from ICR to do the check
	TST R1, #BIT3		@ Check if TB = 1 for tx/rx not done yet
	BNE POLLTB		@ If yes, loop until TB = 0
	MOV PC, LR		@ Otherwise, it's done, return to caller

@----------------------------------------@
@ EXIT - NOPs for testing and breakpoint @
@----------------------------------------@

EXIT:
	MOV R1, #1		@ If yes, return error code = 1 in R1
	NOP
	

@--------------------@
@ Build literal pool @
@--------------------@

BTLDR_IRQ_ADDRESS: .word 0

.data

.end
