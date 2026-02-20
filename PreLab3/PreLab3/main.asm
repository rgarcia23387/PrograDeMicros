/*
* PreLab3.asm
*
* Creado: 20/02/2026 
* Autor : Rodrigo García 
* Descripción: Interrupciones
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P

.def temp        = R16
.def botones     = R17
.def contador4b  = R18
.def cambios     = R19
.def anterior    = R20

.dseg
.org SRAM_START

.cseg
.org 0x0000
    rjmp SETUP              ; Vector RESET

.org PCI1addr
    rjmp ISR_BOTONES        ; Vector PCINT1 (Puerto C)

 /****************************************/
// Configuración de la pila
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16

/****************************************/
// Configuración de MCU 
SETUP:

    ; LEDs PB0–PB3 como salida
    LDI     temp, 0x0F
    OUT     DDRB, temp

    ; Botones PC0 y PC1 como entrada
    CBI     DDRC, 0
    CBI     DDRC, 1

    ; Activar pull-ups internos
    SBI     PORTC, 0
    SBI     PORTC, 1

    ; Inicializar contador
    CLR     contador4b
    OUT     PORTB, contador4b

    ; Guardar estado inicial botones
    IN      anterior, PINC
    ANDI    anterior, 0x03

    ; Habilitar grupo PCINT1 (Puerto C)
    LDI     temp, (1<<PCIE1)
    STS     PCICR, temp

    ; Habilitar PCINT8 (PC0) y PCINT9 (PC1)
    LDI     temp, (1<<PCINT8)|(1<<PCINT9)
    STS     PCMSK1, temp

    SEI     ; Habilitar interrupciones globales


/****************************************/
// Loop Infinito
MAIN_LOOP:

    rjmp MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines
/****************************************/
// Interrupt routines

ISR_BOTONES:

    PUSH    temp
    IN      temp, SREG
    PUSH    temp
    PUSH    cambios

    ; Leer estado actual botones
    IN      botones, PINC
    ANDI    botones, 0x03

    ; Detectar flanco de bajada (1?0)
    MOV     cambios, anterior
    EOR     cambios, botones
    AND     cambios, anterior

    MOV     anterior, botones

    ; -------- Incremento (PC0) --------
    SBRS    cambios, 0
    RJMP    REVISAR_DEC

    INC     contador4b
    ANDI    contador4b, 0x0F

REVISAR_DEC:
    ; -------- Decremento (PC1) --------
    SBRS    cambios, 1
    RJMP    ACTUALIZAR

    DEC     contador4b
    ANDI    contador4b, 0x0F

ACTUALIZAR:
    OUT     PORTB, contador4b

    POP     cambios
    POP     temp
    OUT     SREG, temp
    POP     temp

    RETI
/****************************************/