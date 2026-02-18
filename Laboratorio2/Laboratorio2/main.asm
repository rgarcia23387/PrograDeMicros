/*
* Laboratorio2.asm
*
* Creado: 13/02/2026 17:19:56
* Autor : Rodrigo García
* Descripción: Botones y Timer0
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P


; Constantes (IGUALES a la prueba)
.equ    DESBORDAMIENTOS_100MS = 6
.equ    CICLOS_POR_SEGUNDO = 10

.cseg
.org 0x0000
    RJMP    SETUP

; Tabla de 7 segmentos
tabla_7seg:
    .db 0b00111111, 0b00000110, 0b01011011, 0b01001111
    .db 0b01100110, 0b01101101, 0b01111101, 0b00000111
    .db 0b01111111, 0b01101111, 0b01110111, 0b01111100
    .db 0b00111001, 0b01011110, 0b01111001, 0b01110001

SETUP:
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16

    ; Definir registros 
    .def    temp            = R16
    .def    contador_seg    = R17    
    .def    overflow_count  = R18     
    .def    contador_100ms  = R19    
    .def    contador_botones = R20    
    .def    estado_B1       = R21     
    .def    estado_B2       = R22     
    .def    led_estado      = R23     

    ; --- PUERTO B (LEDs) ---
    LDI     temp, 0b00011111        ; PB0-PB4 salidas
    OUT     DDRB, temp
    CLR     temp
    OUT     PORTB, temp

    ; --- PUERTO D (DISPLAY) ---
    LDI     temp, 0b11111110
    OUT     DDRD, temp
    CLR     temp
    OUT     PORTD, temp

    ; --- PUERTO C (BOTONES) ---
    LDI     temp, 0b00000011
    OUT     PORTC, temp
    CLR     temp
    OUT     DDRC, temp

    ; --- CONFIGURAR TIMER0 ---
    CLR     temp
    OUT     TCCR0A, temp
    LDI     temp, (1<<CS02)|(1<<CS00)
    OUT     TCCR0B, temp
    CLR     temp
    OUT     TCNT0, temp

    ; --- INICIALIZAR VARIABLES ---
    CLR     contador_seg
    CLR     overflow_count
    CLR     contador_100ms
    CLR     contador_botones    
    CLR     estado_B1            
    CLR     estado_B2            
    CLR     led_estado           ; TODAS LAS VARIABLES INICIAN EN 0

    ; Mostrar valores iniciales
    OUT     PORTB, contador_seg  ; LEDs en 0
    RCALL   DISPLAY_UPDATE        ; Display en 0

; ============================================================================
; BUCLE PRINCIPAL 
; ============================================================================
MAIN_LOOP:
    ; --- CÓDIGO DEL TIMER ---
    IN      temp, TIFR0
    SBRS    temp, TOV0
    RJMP    REVISAR_BOTONES      

    LDI     temp, (1<<TOV0)
    OUT     TIFR0, temp

    INC     overflow_count
    CPI     overflow_count, DESBORDAMIENTOS_100MS
    BRNE    REVISAR_BOTONES

    ; 100ms
    CLR     overflow_count
    INC     contador_100ms
    CPI     contador_100ms, CICLOS_POR_SEGUNDO
    BRNE    REVISAR_BOTONES

    ; 1 SEGUNDO 
    CLR     contador_100ms
    INC     contador_seg
    CPI     contador_seg, 16
    BRNE    SEG_NO_RESET
    CLR     contador_seg
SEG_NO_RESET:

    ; ACTUALIZAR LEDs 
    OUT     PORTB, contador_seg

    ; COMPARAR
    CPSE    contador_seg, contador_botones
    RJMP    REVISAR_BOTONES

    ; IGUALES - TOGGLE D12
    CLR     contador_seg
    OUT     PORTB, contador_seg
    
    LDI     temp, (1<<PB4)
    EOR     led_estado, temp
    IN      temp, PORTB
    EOR     temp, led_estado
    OUT     PORTB, temp

; ============================================================================
; REVISAR BOTONES (se ejecuta después de cada revisión del timer)
; ============================================================================
REVISAR_BOTONES:
    ; Botón 1
    IN      temp, PINC
    ANDI    temp, (1<<PC0)
    CPSE    temp, estado_B1
    RCALL   CAMBIO_B1
    MOV     estado_B1, temp

    ; Botón 2
    IN      temp, PINC
    ANDI    temp, (1<<PC1)
    CPSE    temp, estado_B2
    RCALL   CAMBIO_B2
    MOV     estado_B2, temp

    ; Pequeño delay 
    RCALL   DELAY_CORTO
    RJMP    MAIN_LOOP

; ============================================================================
; CAMBIO_B1
; ============================================================================
CAMBIO_B1:
    CPI     temp, 0
    BRNE    CAMBIO_B1_FIN
    
    ; Antirebote simple
    RCALL   DELAY_CORTO
    RCALL   DELAY_CORTO
    RCALL   DELAY_CORTO
    RCALL   DELAY_CORTO
    RCALL   DELAY_CORTO
    
    SBIC    PINC, PC0
    RJMP    CAMBIO_B1_FIN
    
    INC     contador_botones
    CPI     contador_botones, 16
    BRNE    B1_NO_RESET
    CLR     contador_botones
B1_NO_RESET:
    RCALL   DISPLAY_UPDATE
CAMBIO_B1_FIN:
    RET

; ============================================================================
; CAMBIO_B2
; ============================================================================
CAMBIO_B2:
    CPI     temp, 0
    BRNE    CAMBIO_B2_FIN
    
    ; Antirebote simple
    RCALL   DELAY_CORTO
    RCALL   DELAY_CORTO
    RCALL   DELAY_CORTO
    RCALL   DELAY_CORTO
    RCALL   DELAY_CORTO
    
    SBIC    PINC, PC1
    RJMP    CAMBIO_B2_FIN
    
    DEC     contador_botones
    CPI     contador_botones, 255
    BRNE    B2_NO_RESET
    LDI     contador_botones, 15
B2_NO_RESET:
    RCALL   DISPLAY_UPDATE
CAMBIO_B2_FIN:
    RET

; ============================================================================
; DISPLAY_UPDATE
; ============================================================================
DISPLAY_UPDATE:
    PUSH    ZH
    PUSH    ZL
    PUSH    temp
    
    LDI     ZH, HIGH(tabla_7seg*2)
    LDI     ZL, LOW(tabla_7seg*2)
    ADD     ZL, contador_botones
    CLR     temp
    ADC     ZH, temp
    LPM     temp, Z
    LSL     temp
    OUT     PORTD, temp
    
    POP     temp
    POP     ZL
    POP     ZH
    RET

; ============================================================================
; DELAY_CORTO - Un delay pequeño para antirebote (NO usa Timer0)
; ============================================================================
DELAY_CORTO:
    PUSH    R20
    PUSH    R21
    LDI     R20, 50
DELAY_CORTO_1:
    LDI     R21, 255
DELAY_CORTO_2:
    DEC     R21
    BRNE    DELAY_CORTO_2
    DEC     R20
    BRNE    DELAY_CORTO_1
    POP     R21
    POP     R20
    RET