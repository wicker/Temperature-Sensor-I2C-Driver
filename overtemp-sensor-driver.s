@ Author: Jenner Hanni - Winter 2013 - ECE372
@ Project #2b - LM75 Temperature Sensor - Overtemp/Undertemp LED Driver
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
@ Initialize GPIO 96 as an input and rising edge detect @
@-------------------------------------------------------@

LDR R0, =GAFR3L @ Load pointer to GAFR2_L register
LDR R1, [R0]    @ Read GAFR2_L to get current value
BIC R1, #0x01   @ Set bits 0 and 1 to set alternate function #1
STR R1, [R0]    @ Write word back to the GAFR2_L

LDR R0, =GPCR3	@ Point to GPCR3 register
LDR R1, [R0]    @ Read current value of GPCR3 register
ORR R1, #0x01	@ Word to clear bit 0
STR R1, [R0]	@ Write to GPCR3

LDR R0, =GPDR3	@ Point to GPDR3 register
LDR R1, [R0]	@ Read GPDR3 to get current value
BIC R1, #0x01   @ Clear bit 0 to make GPIO 96 an input
STR R1, [R0]	@ Write word back to the GPDR3

LDR R0, =GRER3	@ Point to GRER3 register
LDR R1, [R0]	@ Read current value of GRER3 register
ORR R1, #0x01   @ Load mask to set bit 0
STR R1, [R0]	@ Write word back to GRER3 register

@-------------------------------------------------------@
@ Initialize GPIO 73 as an input and rising edge detect @
@-------------------------------------------------------@

LDR R0, =GAFR2L @ Load pointer to GAFR2_L register
LDR R1, [R0]    @ Read GAFR2_L to get current value
BIC R1, #CAFRL  @ Clear bits 19 and 20 to make GPIO 73 not an alternate function
STR R1, [R0]    @ Write word back to the GAFR2_L

LDR R0, =GPCR2	@ Point to GPCR2 register
LDR R1, [R0]    @ Read current value of GPCR2 register
MOV R1, #BIT9	@ Word to clear bit 9
STR R1, [R0]	@ Write to GPCR2

LDR R0, =GPDR2	@ Point to GPDR2 register
LDR R1, [R0]	@ Read GPDR2 to get current value
BIC R1, #BIT9   @ Clear bit 9 to make GPIO 73 an input
STR R1, [R0]	@ Write word back to the GPDR2

LDR R0, =GRER2	@ Point to GRER2 register
LDR R1, [R0]	@ Read current value of GRER2 register
ORR R1, #BIT9   @ Load mask to set bit 9
STR R1, [R0]	@ Write word back to GRER2 register

@---------------------------------@
@ Initialize GPIO 67 as an output @
@---------------------------------@

@LDR R0, =GPCR2	@ Point to GPCR2 register
@LDR R1, [R0]    @ Read current value of GPCR2 register
@ORR R1, #0x08	@ Word to clear bit 3
@STR R1, [R0]	@ Write to GPCR2

LDR R0, =GPDR2	@ Point to GPDR2 register
LDR R1, [R0]	@ Read GPDR2 to get current value
ORR R1, #0x08   @ Set bit 3 to make GPIO 67 an output
STR R1, [R0]	@ Write word back to the GPDR2

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

	LDR R0, =GEDR3  @ Point at GEDR3
	LDR R1, [R0]	@ Read GEDR3
	TST R1, #0x01   @ Check if LM75 OS is the source
	BNE OS_SVC	@ Yes, go handle the temp sensor
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

	@ Write 30 degrees Celsius to Tos internal register
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x90		@ Load the value to write to the slave address
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #START		@ Load the value for START
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x03		@ Load the value of the Tos pointer
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #MORE		@ Load the value to request the write
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x1E		@ Load the MSB value of 30 deg C for Tos
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #MORE		@ Load the value to request the write
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x00		@ Load the LSB value of 30 deg C for Tos
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #MORE		@ Load the value to request the write
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	@LDR R0, =ICR		@ Point to ICR
	@MOV R1, #STOP		@ Load the value for STOP
	@STR R1, [R0]		@ Write to ICR
	@BL POLLTB

	@ Write 28 degrees Celsius to Thyst internal register
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x90		@ Load the value to write to the slave address
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #START		@ Load the value for START
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x02		@ Load the value of the Thyst pointer
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #MORE		@ Load the value to request the write
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x1C		@ Load the MSB value of 28 deg C for Thyst
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #MORE		@ Load the value to request the write
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x00		@ Load the LSB value of 28 deg C for Thyst
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #MORE		@ Load the value to request the write
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	@LDR R0, =ICR		@ Point to ICR
	@MOV R1, #STOP		@ Load the value for STOP
	@STR R1, [R0]		@ Write to ICR

	LDMFD SP!,{R0-R2,LR}	@ Restore the registers
	SUBS PC, LR, #4		@ Return from interrupt (to wait loop)

@------------------------------------------------------------@
@ OS_SVC - The interrupt came from our button on GPIO pin 96 @
@------------------------------------------------------------@

OS_SVC:

	@ Clear the interrupt
	LDR R0, =GEDR3		@ Point to GEDR3
	LDR R1, [R0]		@ Read the current value from GEDR3
	ORR R1, #0x01		@ Set bit 0 to clear the interrupt from pin 96
	STR R1, [R0]		@ Write to GEDR3

	@ First start to reset the pointer at the TEMP internal register
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x91		@ Load the value to read from the slave address
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #START		@ Load the value for START
	STR R1, [R0]		@ Write to ICR
	BL POLLTB
	LDR R0, =IDBR		@ Point to IDBR
	MOV R1, #0x00		@ Load the value to point to the temp register
	STR R1, [R0]		@ Write to IDBR
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #MORE		@ Load the value for an acknowledgement
	STR R1, [R0]		@ Write to ICR
	BL POLLTB

	@ Repeated start get the actual data
	@LDR R0, =IDBR		@ Point to IDBR
	@MOV R1, #0x91		@ Load the value to read from the slave address
	@STR R1, [R0]		@ Write to IDBR
	@LDR R0, =ICR		@ Point to ICR
	@MOV R1, #START		@ Load the value for START
	@STR R1, [R0]		@ Write to ICR
	@BL POLLTB
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
	ORR R3, R3, R1		@ Put the value of that bit in the LSB of R3 
				@ to get the complete temperature value
	LDR R0, =ICR		@ Point to ICR
	MOV R1, #STOP		@ Load the value for STOP
	STR R1, [R0]		@ Write to ICR

	@ Test temp value to determine whether to light LED or not
	TST R3, #0x1E		@ Test if the value in R3 is greater than Tos
	BGT LED_ON		@ If yes, break to turn LED on

	TST R3, #0x1C		@ Test if the value in R3 is less than Thyst
	BLE LED_OFF		@ If yes, break to turn LED off

	B EXIT			@ If neither, fall through to exit
				@ This should not have triggered OS if neither

@--------------------------@
@ LED_ON - Turn the LED on @
@--------------------------@

LED_ON: 
	LDR R0, =GPSR2		@ Point to GPSR2
	LDR R1, [R0]		@ Read from GPSR2
	ORR R1, R1, #0x08	@ Value to set bit 3 to 1 to output LED high
	STR R1, [R0]		@ Write back to GPSR2
	LDMFD SP!,{R0-R2,LR}	@ Restore the registers
	SUBS PC, LR, #4		@ Return from interrupt (to wait loop)

@----------------------------@
@ LED_OFF - Turn the LED off @
@----------------------------@

LED_OFF:
	LDR R0, =GPCR2		@ Point to GPCR2
	LDR R1, [R0]		@ Read from GPCR2
	BIC R1, R1, #0x08	@ Value to clear bit 3 to output LED low
	STR R1, [R0]		@ Write back to GPCR2
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
