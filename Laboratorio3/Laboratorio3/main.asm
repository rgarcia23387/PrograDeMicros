/*
* Laboratorio3.asm
*
* Creado: 20/02/2026 16:59:51
* Autor : Rodrigo García
* Descripción: Interrupciones con contador de 4 bits y display.
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P


.def temp        = R16
.def botones     = R17
.def contador4b  = R18      ; Contador LEDs 
.def cambios     = R19
.def anterior    = R20
.def ticks10ms   = R21      ; Cuenta interrupciones de 10ms
.def unidades    = R22      ; Contador displays 
.def decenas     = R23
.def muxFlag     = R24

.dseg
.org SRAM_START

.cseg
.org 0x0000
    rjmp SETUP

.org PCI1addr
    rjmp ISR_BOTONES

.org OC0Aaddr
    rjmp ISR_TIMER0

; Tabla de 7 segmentos
tabla7seg:
    .db 0b00111111, 0b00000110, 0b01011011, 0b01001111 ; 0, 1, 2, 3
    .db 0b01100110, 0b01101101, 0b01111101, 0b00000111 ; 4, 5, 6, 7
    .db 0b01111111, 0b01101111, 0b01110111, 0b01111100 ; 8, 9, A, b
    .db 0b00111001, 0b01011110, 0b01111001, 0b01110001 ; C, d, E, F
 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:
; LEDs PB0–PB3 salida
    LDI temp, 0x0F
    OUT DDRB, temp

; Display 7 segmentos PD1–PD7 salida
    LDI temp, 0xFE
    OUT DDRD, temp

; Transistores PC2 y PC3
    SBI DDRC, 2
    SBI DDRC, 3
    CBI PORTC, 2
    CBI PORTC, 3

; Botones PC0 y PC1 entrada
    CBI DDRC, 0
    CBI DDRC, 1

    SBI PORTC, 0     ; Pull-up
    SBI PORTC, 1     ; Pull-up

; Inicializar variables
    CLR contador4b
    CLR unidades
    CLR decenas
    CLR ticks10ms
    CLR muxFlag

    OUT PORTB, contador4b

; Estado inicial botones
    IN anterior, PINC
    ANDI anterior, 0x03

; PCINT botones
    LDI temp, (1<<PCIE1)
    STS PCICR, temp

    LDI temp, (1<<PCINT8)|(1<<PCINT9)
    STS PCMSK1, temp

; TIMER0 CTC 10ms
    LDI temp, (1<<WGM01)
    OUT TCCR0A, temp

    LDI temp, (1<<CS02)|(1<<CS00)
    OUT TCCR0B, temp

    LDI temp, 155
    OUT OCR0A, temp

    LDI temp, (1<<OCIE0A)
    STS TIMSK0, temp

; Habilitar interrupciones globales
    SEI

/****************************************/
// Loop Infinito
MAIN_LOOP:
    RJMP    MAIN_LOOP ; Como no hace nada, se queda vacio

/****************************************/
// NON-Interrupt subroutines
MOSTRAR_DISPLAY:

    PUSH temp
	
    LDI ZH, HIGH(tabla7seg<<1) ; carga la parte alta de la dirección
    LDI ZL, LOW(tabla7seg<<1) ; carga la parte baja de la dirección

    ADD ZL, R25
    CLR temp
    ADC ZH, temp

    LPM temp, Z

    LSL temp

    OUT PORTD, temp

    POP temp
    RET
/****************************************/
// Interrupt routines

; INTERRUPCIÓN BOTONES (PCINT)
ISR_BOTONES:

    PUSH temp
    IN temp, SREG
    PUSH temp
    PUSH cambios

    IN botones, PINC
    ANDI botones, 0x03

    MOV cambios, anterior
    EOR cambios, botones
    AND cambios, anterior

    MOV anterior, botones

; Incremento (PC0)
    SBRS cambios, 0
    RJMP REVISAR_DEC

    INC contador4b
    ANDI contador4b, 0x0F

REVISAR_DEC:
; Decremento (PC1)
    SBRS cambios, 1
    RJMP ACTUALIZAR_LEDS

    DEC contador4b
    ANDI contador4b, 0x0F

ACTUALIZAR_LEDS:
    OUT PORTB, contador4b

    POP cambios
    POP temp
    OUT SREG, temp
    POP temp
    RETI

; INTERRUPCIÓN TIMER0 (10ms)

ISR_TIMER0:

    PUSH temp
    IN temp, SREG
    PUSH temp

; MULTIPLEXADO 
    LDI temp, 0x01
	EOR muxFlag, temp

    CPI muxFlag, 0
    BRNE SHOW_DEC

; UNIDADES
    MOV R25, unidades
    RCALL MOSTRAR_DISPLAY
    SBI PORTC, 2
    CBI PORTC, 3
    RJMP CONTAR

SHOW_DEC:
; DECENAS
    MOV R25, decenas
    RCALL MOSTRAR_DISPLAY
    SBI PORTC, 3
    CBI PORTC, 2

CONTAR:

; 1 SEGUNDO 
    INC ticks10ms
    CPI ticks10ms, 100
    BRNE FIN_TIMER

    CLR ticks10ms

    INC unidades
    CPI unidades, 10
    BRNE CHECK_60

    CLR unidades
    INC decenas

CHECK_60:
    CPI decenas, 6
    BRNE FIN_TIMER

    CLR unidades
    CLR decenas

FIN_TIMER:
    POP temp
    OUT SREG, temp
    POP temp
    RETI
/****************************************/
