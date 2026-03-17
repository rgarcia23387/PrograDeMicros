/*
* Proyecto1_Reloj.asm
*
* Creado: 27/02/2026 16:50:27
* Autor : Rodrigo García
* Descripción: 
*/
/****************************************/
/*
* Proyecto1_Reloj.asm
*
* Creado: 27/02/2026 16:50:27
* Autor : Rodrigo García
* Descripción: Reloj digital con dos puntos encendidos al inicio del segundo
*/
/****************************************/

.include "M328PDEF.inc"

/******** REGISTROS ********/

.def temp = r16
.def blink = r17
.def temp2 = r18

.def mux = r19
.def ms = r20
.def cont_seg = r21

.def hora = r22
.def minuto = r23
.def segundo = r24

.def dig1 = r25
.def dig2 = r14
.def dig3 = r15
.def dig4 = r13

/****************************************/

.cseg
.org 0x0000
rjmp SETUP

.org OVF0addr
rjmp TIMER0_ISR

/****************************************/

tabla7seg:
.db 0b01011111, 0b00000110, 0b00111011, 0b00101111
.db 0b01100110, 0b01101101, 0b01111101, 0b00000111
.db 0b01111111, 0b01101111

/****************************************/

SETUP:

LDI temp, LOW(RAMEND)
OUT SPL, temp
LDI temp, HIGH(RAMEND)
OUT SPH, temp

LDI temp, 0xFF
OUT DDRD, temp

LDI temp, 0b00111100
OUT DDRC, temp

LDI hora, 12
LDI minuto, 0
LDI segundo, 0

LDI mux, 0
LDI ms, 0
LDI cont_seg, 0
LDI blink, 0

; LED rojo (opcional)
SBI DDRB, 2
SBI PORTB, 2

; Timer0
LDI temp, 0b00000011
OUT TCCR0B, temp

LDI temp, (1<<TOIE0)
STS TIMSK0, temp

SEI

/****************************************/

MAIN_LOOP:

MOV temp, hora
LDI temp2, 10
RCALL DIV10
MOV dig1, temp2
MOV dig2, temp

MOV temp, minuto
LDI temp2, 10
RCALL DIV10
MOV dig3, temp2
MOV dig4, temp

RJMP MAIN_LOOP

/****************************************/

DIV10:

CLR temp2

DIV_LOOP:
SUBI temp, 10
BRCS DIV_END
INC temp2
RJMP DIV_LOOP

DIV_END:
SUBI temp, -10
RET

/****************************************/

TIMER0_ISR:

PUSH temp
PUSH temp2
IN temp, SREG
PUSH temp

LDI temp, 6
OUT TCNT0, temp

; apagar displays
CBI PORTC, 2
CBI PORTC, 3
CBI PORTC, 4
CBI PORTC, 5

; seleccionar display
CPI mux, 0
BREQ DISP1
CPI mux, 1
BREQ DISP2
CPI mux, 2
BREQ DISP3
RJMP DISP4

DISP1:
MOV temp, dig1
RJMP MOSTRAR

DISP2:
MOV temp, dig2
RJMP MOSTRAR

DISP3:
MOV temp, dig3
RJMP MOSTRAR

DISP4:
MOV temp, dig4

MOSTRAR:

LDI ZH, HIGH(tabla7seg<<1)
LDI ZL, LOW(tabla7seg<<1)

ADD ZL, temp
LPM temp, Z

; Control de parpadeo de puntos - SOLO EN DISPLAYS DE MINUTOS
MOV temp2, blink
CPI temp2, 1
BRNE NO_DP

; Encender DP solo en displays de minutos (mux=1 y mux=2)
CPI mux, 1
BREQ ENCENDER_DP
CPI mux, 2
BREQ ENCENDER_DP
RJMP NO_DP

ENCENDER_DP:
ORI temp, 0b10000000

NO_DP:

OUT PORTD, temp

; activar display
CPI mux, 0
BREQ ON1
CPI mux, 1
BREQ ON2
CPI mux, 2
BREQ ON3
RJMP ON4

ON1:
SBI PORTC, 2
RJMP NEXT

ON2:
SBI PORTC, 3
RJMP NEXT

ON3:
SBI PORTC, 4
RJMP NEXT

ON4:
SBI PORTC, 5

NEXT:

INC mux
CPI mux, 4
BRLO CONTADOR
LDI mux, 0

/****************************************/
/* CONTROL DE TIEMPO CON PARPADEO AL INICIO DEL SEGUNDO */

CONTADOR:

INC ms
CPI ms, 250              ; 250 * 4ms = 1 segundo exacto
BRLO FIN_ISR

LDI ms, 0

INC cont_seg             ; cont_seg se incrementa cada segundo

; CONTROL DE PARPADEO - Encendido al inicio del segundo (primeros 500ms)
CPI cont_seg, 1          ; ¿Primeros 250ms? (valor bajo para encender rápido)
BRNE CHECK_500MS
LDI blink, 1             ; Encender los dos puntos
RJMP CHECK_SECOND

CHECK_500MS:
CPI cont_seg, 3          ; ¿A los 750ms? (apagar antes del final)
BRNE CHECK_SECOND
LDI blink, 0             ; Apagar los dos puntos

CHECK_SECOND:
CPI cont_seg, 4          ; ¿Ha pasado 1 segundo completo?
BRNE FIN_ISR

LDI cont_seg, 0          ; Reiniciar contador de segundos

; Incrementar tiempo
INC segundo
CPI segundo, 60
BRLO FIN_ISR

LDI segundo, 0

INC minuto
CPI minuto, 60
BRLO FIN_ISR

LDI minuto, 0

INC hora
CPI hora, 24
BRLO FIN_ISR

LDI hora, 0

/****************************************/

FIN_ISR:

POP temp
OUT SREG, temp
POP temp2
POP temp

RETI