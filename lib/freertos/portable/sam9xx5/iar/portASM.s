;/*
; * FreeRTOS Kernel V10.0.0
; * Copyright (C) 2017 Amazon.com, Inc. or its affiliates.  All Rights Reserved.
; *
; * Permission is hereby granted, free of charge, to any person obtaining a copy of
; * this software and associated documentation files (the "Software"), to deal in
; * the Software without restriction, including without limitation the rights to
; * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
; * the Software, and to permit persons to whom the Software is furnished to do so,
; * subject to the following conditions:
; *
; * The above copyright notice and this permission notice shall be included in all
; * copies or substantial portions of the Software. If you wish to use our Amazon
; * FreeRTOS name, please do so in a fair use way that does not cause confusion.
; *
; * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
; * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
; * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
; * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
; * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
; *
; * http://www.FreeRTOS.org
; * http://aws.amazon.com/freertos
; *
; * 1 tab == 4 spaces!
; */


	EXTERN	ulPortYieldRequired
	EXTERN	vApplicationIRQHandler
	
	EXTERN	vTaskSwitchContext
	EXTERN  ulCriticalNesting
	EXTERN	pxCurrentTCB
	EXTERN  ulAsmAPIPriorityMask

	PUBLIC	FreeRTOS_SWI_Handler
	PUBLIC  FreeRTOS_IRQ_Handler
	PUBLIC vPortStartFirstTask



AT91C_BASE_AIC  DEFINE		0xFFFFF000
AIC_EOICR       DEFINE		0x130
AIC_SMR0         DEFINE		0x000
AIC_IVR         DEFINE		0x100

SYS_MODE			EQU		0x1f
SVC_MODE			EQU		0x13
IRQ_MODE			EQU		0x12

	SECTION .text:CODE:ROOT(2)
	ARM

portSAVE_CONTEXT MACRO

	; Push R0 as we are going to use the register. 					
	STMDB	SP!, {R0}

	; Set R0 to point to the task stack pointer. 					
	STMDB	SP, {SP}^
	NOP
	SUB		SP, SP, #4
	LDMIA	SP!, {R0}

	; Push the return address onto the stack. 						
	STMDB	R0!, {LR}

	; Now we have saved LR we can use it instead of R0. 				
	MOV		LR, R0

	; Pop R0 so we can save it onto the system mode stack. 			
	LDMIA	SP!, {R0}

	; Push all the system mode registers onto the task stack. 		
	STMDB	LR, {R0-LR}^
	NOP
	SUB		LR, LR, #60

	; Push the SPSR onto the task stack. 							
	MRS		R0, SPSR
	STMDB	LR!, {R0}

	LDR		R0, =ulCriticalNesting 
	LDR		R0, [R0]
	STMDB	LR!, {R0}

	; Store the new top of stack for the task. 						
	LDR		R1, =pxCurrentTCB
	LDR		R0, [R1]
	STR		LR, [R0]

	ENDM


; /**********************************************************************/

portRESTORE_CONTEXT MACRO

	; Set the LR to the task stack. 									
	LDR		R1, =pxCurrentTCB
	LDR		R0, [R1]
	LDR		LR, [R0]

	; The critical nesting depth is the first item on the stack. 	
	; Load it into the ulCriticalNesting variable. 					
	LDR		R0, =ulCriticalNesting
	LDMFD	LR!, {R1}
	STR		R1, [R0]

	; Get the SPSR from the stack. 									
	LDMFD	LR!, {R0}
	MSR		SPSR_cxsf, R0

	; Restore all system mode registers for the task. 				
	LDMFD	LR, {R0-R14}^
	NOP

	; Restore the return address. 									
	LDR		LR, [LR, #+60]

	; And return - correcting the offset in the LR to obtain the 	
	; correct address. 												
	SUBS	PC, LR, #4

	ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Starting the first task is just a matter of restoring the context that
; was created by pxPortInitialiseStack().
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vPortStartFirstTask:
	portRESTORE_CONTEXT


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SVC handler is used to yield a task.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FreeRTOS_SWI_Handler:
	
	ADD		LR, LR, #4			; Add 4 to the LR to make the LR appear exactly
								; as if the context was saved during and IRQ
								; handler.
								
	portSAVE_CONTEXT			; Save the context of the current task...
	LDR R0, =vTaskSwitchContext	; before selecting the next task to execute.
	mov     lr, pc
	BX R0
	portRESTORE_CONTEXT			; Restore the context of the selected task.
	


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; IRQ interrupt handler used when individual priorities cannot be masked
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FreeRTOS_IRQ_Handler:

	portSAVE_CONTEXT
	
			/* Write in the IVR to support Protect Mode */
			LDR 	lr, =AT91C_BASE_AIC
			LDR 	r0, [r14, #AIC_IVR]
			STR 	lr, [r14, #AIC_IVR]
	
			/* Branch to C portion of the interrupt handler */
			MOV 	lr, pc
			BX		r0
	
			/* Acknowledge interrupt */
			LDR 	lr, =AT91C_BASE_AIC
			STR 	lr, [r14, #AIC_EOICR]
	
			portRESTORE_CONTEXT


	END


