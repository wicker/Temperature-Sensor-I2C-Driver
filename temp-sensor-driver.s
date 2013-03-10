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
.EQU GRER0,  0x40E00030
.EQU GRER2,  0x40E00038
.EQU GRER3,  0x40E00130
.EQU GEDR0,  0x40E00048
.EQU GEDR2,  0x40E00050
.EQU GEDR3,  0x40E00148
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

.EQU WRITE,  0x00001009   @ Value to write a byte from I2C master to slave
.EQU READ,   0x0000100E   @ Value to read a byte from I2C slave to master

.EQU ICIP,   0x40D00000  @ Interrupt Controller IRQ Pending Register
.EQU ICMR,   0x40D00004  @ Interrupt Controller Mask Register
.EQU ICPR,   0x40D00010  @ Interrupt Controller Pending Register
.EQU ICCR,   0x40D00014  @ Interrupt Controller Control Register
.EQU ICLR,   0x40D00008  @ Interrupt Controller Level Register

.EQU ICR,    0x40301690	 @ I2C Bus Control Register
.EQU ISR,    0x40301698	 @ I2C Bus Status Register
.EQU IDBR,   0x40301688	 @ I2C Data Buffer Register
.EQU ISAR,   0x403016A0	 @ I2C Slave Address Register

@-------------------------------------------@
@ Set GPIO 73 back to Alternate Function 00 @
@-------------------------------------------@

LDR R0, =GAFR2L @ Load pointer to GAFR2_L register
LDR R1, [R0]    @ Read GAFR2_L to get current value
BIC R1, #CAFRL  @ Clear bits 19 and 20 to make GPIO 73 not an alternate function
STR R1, [R0]    @ Write word back to the GAFR2_L

@-------------------------------------------------------@
@ Initialize GPIO 73 as an input and rising edge detect @
@-------------------------------------------------------@

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
MOVW R2, #4      @ Load top half-word into R2
MOVT R2, #0400   @ Load bottom half-word into R2
ORR R1, R2	 @ Set bit 10 and 18 to unmask IM10
STR R0, [R1] 	 @ Write word back to ICMR register

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
@ Set fast mode and enable both I2C and SCL, no other interrupts
MOVW R2, #0000   @ Load top half-word into R2
MOVT R2, #8060   @ Load bottom half-word into R2
STR R1, [R0]    @ Write word back to ICR register

LDR R0, =ISAR   @ Load pointer to address of ISAR register
MOV R1, #0x49   @ Write value of slave address + set the read (LSB) bit to 1
STR R1, [R0]    @ Write word back to the ISAR register

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
	STMFD SP!, {R0-R1, LR}	@ Save registers on stack
	LDR R0, =ICIP	@ Point at IRQ Pending Register (ICIP)
	LDR R1, [R0]	@ Read ICIP
	TST R1, #BIT10	@ Check if GPIO 119:2 IRQ interrupt on IP<10> asserted
	BNE BTN_SVC	@ Yes, must be button press, go service the button

        TST R1, #BIT18  @ Check if I2C bus IRQ interrupt on IP<18> asserted
	BNE I2C_SVC     @ Yes, must be I2C interrupt, go service the bus
			@ No, must be other IRQ, pass on: 

@-----------------------------------------------------------@
@ PASSON - The interrupt is not from our button or the UART @
@-----------------------------------------------------------@

PASSON: 
	LDMFD SP!, {R0-R1,LR}		@ Restore the registers
	LDR PC, =BTLDR_IRQ_ADDRESS	@ Go to bootloader IRQ service procedure

@-------------------------------------------------------------@
@ BTN_SVC - The interrupt came from our button on GPIO pin 73 @
@-------------------------------------------------------------@

BTN_SVC:
	LDR R0, =GEDR2		@ Point to GEDR2 
	LDR R1, [R0]		@ Read the current value from GEDR2
	ORR R1, #BIT9		@ Set bit 9 to clear the interrupt from pin 73
	STR R1, [R0]		@ Write to GEDR2

	LDR R0, =ICR 		@ Point to ICR
	MOVW R1, #0x0
	MOVT R1, #0x1009	@ Load the current value from ICR
	STR R1, [R0]		@ Write to ICR

	LDMFD SP!, {R0-R1,LR}	@ Restore registers, including return address
	SUBS PC, LR, #4		@ Return from interrupt to wait loop

@-----------------------------------------------@
@ I2C_SVC - The interrupt came from the I2C bus @
@-----------------------------------------------@

I2C_SVC:
	STMFD SP!,{R2-R5}  @ Save additional registers

	LDR R0, =ISR	@ Point to ISR
	LDR R1, [R0]	@ Read ISR
	TST R1, #BIT6	@ Check if the ITE interrupt is asserted
	BNE ITE_SVC	@ If yes, go service the ITE interrupt
	TST R1, #BIT7   @ Check if the IRF interrupt is asserted
	BNE IRF_SVC     @ If yes, go service the IRF interrupt
	B GOBCK		@ Otherwise go back to the loop

@-----------------------------------------------------------@
@ ITE_SVC - The interrupt came from the IDBR Transmit-Empty @ 
@-----------------------------------------------------------@

ITE_SVC:
	LDR R0, =ISR 	@ Point to ISR
	MOV R1, #BIT6	@ Load word to clear ITE interrupt
	STR R1, [R0]	@ Write to ISR

	LDR R0, =ICR	@ Point to ICR
	MOVW R1, #0x00  @ Empty top of R1
	MOVT R1, #0x100E @ Load the rest of the word to start the read
	STR R1, [R0]    @ Write to ICR

	B GOBCK		@ Go back to the loop to wait for the byte to be read

@-----------------------------------------------------------@
@ IRF_SVC - The interrupt came from the IDBR Transmit-Empty @ 
@-----------------------------------------------------------@

IRF_SVC:
	LDR R0, =ISR 	@ Point to ISR
	MOV R1, #BIT7	@ Load word to clear IRF interrupt
	STR R1, [R0]	@ Write to ISR

	LDR R0, =IDBR	@ Point to IDBR
	LDR R5, [R0]	@ Read IDBR

	LDR R0, =ICR    @ Point to ICR
	MOV R1, #0x06	@ Load word to write ACKNAK and STOP 
	STR R1, [R0]    @ Write to ICR

	B GOBCK		@ Go back to the loop to wait for the byte to be read

@------------------------------------@
@ GOBCK - Restore from the interrupt @
@------------------------------------@

GOBCK:
	LDMFD SP!, {R0-R1,LR}	@ Restore original registers, including return address
	SUBS PC, LR, #4		@ Return from interrupt (to wait loop)

@--------------------@
@ Build literal pool @
@--------------------@

BTLDR_IRQ_ADDRESS: .word 0

.data

.end
