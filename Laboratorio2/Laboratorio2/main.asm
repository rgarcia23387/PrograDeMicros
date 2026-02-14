/*
* Laboratorio2.asm
*
* Creado: 13/02/2026 17:19:56
* Autor : Rodrigo Garcia
* Descripción: Botones y Timer0
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P

// Constantes del programa
.equ    DEBOUNCE_MS = 50            ; Tiempo de antirebote en milisegundos

.dseg
.org    SRAM_START
debounce_timer:     .byte   1       ; Variable para tiempo de antirebote

.cseg
.org 0x0000
    RJMP    SETUP                   ; Saltar a configuración

/****************************************/
// Tabla de 7 segmentos
tabla_7seg:
    .db 0b00111111, 0b00000110, 0b01011011, 0b01001111  ; 0,1,2,3
    .db 0b01100110, 0b01101101, 0b01111101, 0b00000111  ; 4,5,6,7
    .db 0b01111111, 0b01101111, 0b01110111, 0b01111100  ; 8,9,A,b
    .db 0b00111001, 0b01011110, 0b01111001, 0b01110001  ; C,d,E,F

/****************************************/
// Configuración de la pila
SETUP:
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16
    
/****************************************/
// Configuracion MCU
    ; Definir registros como variables
    .def    temp        = R16        ; Registro temporal
    .def    contador    = R17        ; Valor actual (0-15)
    .def    estado_B1   = R18        ; Estado del botón B1 
    .def    estado_B2   = R19        ; Estado del botón B2
    .def    temp2       = R20        ; Registro auxiliar
    .def    flag_espera = R21        ; Flag para saber si estamos en antirebote

    ; Configurar puertos
    ; Puerto D: PD1-PD7 como salidas (display)
    LDI     temp, 0b11111110         ; PD1-PD7 salidas, PD0 entrada
    OUT     DDRD, temp
    CLR     temp
    OUT     PORTD, temp              ; Display apagado al inicio

    ; Puerto C: PC0 y PC1 como entradas (botones)
    LDI     temp, 0b00000011         ; Habilitar pull-up en PC0 y PC1
    OUT     PORTC, temp
    CLR     temp
    OUT     DDRC, temp               ; PC0 y PC1 como entradas

    ; Inicializar variables
    CLR     contador                
    CLR     estado_B1              
    CLR     estado_B2               
    CLR     flag_espera              ; todos empiezan en 0
    CLR     temp2
    STS     debounce_timer, temp2    ; debounce_timer = 0

    ; Mostrar valor inicial en display
    RCALL   DISPLAY_UPDATE

/****************************************/
// Loop Infinito
MAIN_LOOP:
    ; Leer botones y manejar máquina de estados 
    RCALL   MANEJAR_BOTONES

    ; Pequeño delay para evitar lecturas demasiado rápidas 
    RCALL   DELAY_10MS

    RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines

; Subrutina: MANEJAR_BOTONES - Máquina de estados para antirebote
MANEJAR_BOTONES:
    PUSH    temp
    PUSH    temp2

    ; Manejar Botón 1 (PC0)
    IN      temp, PINC
    ANDI    temp, (1<<PC0)           ; Enmascarar solo bit PC0
    
    ; Comparar con estado anterior
    CPSE    temp, estado_B1           ; Si son iguales, saltar
    RCALL   CAMBIO_B1                 ; Si cambiaron, manejar cambio

    ; Manejar Botón 2 (PC1)
    IN      temp, PINC
    ANDI    temp, (1<<PC1)           ; Enmascarar solo bit PC1
    
    ; Comparar con estado anterior
    CPSE    temp, estado_B2           ; Si son iguales, saltar
    RCALL   CAMBIO_B2                 ; Si cambiaron, manejar cambio

    POP     temp2
    POP     temp
    RET

; Subrutina: CAMBIO_B1 - Detecta cambio en botón 1
CAMBIO_B1:
    ; Guardar nuevo estado
    MOV     estado_B1, temp

    ; Verificar si fue presión (pasó de 1 a 0)
    ANDI    temp, (1<<PC0)           ; Si temp tiene 0, es presión
    BRNE    CAMBIO_B1_FIN             ; Si no es 0, fue liberación

    ; Es una presión - iniciar antirebote 
    LDI     temp2, 5                  ; 5 × 10ms = 50ms
    STS     debounce_timer, temp2
    LDI     flag_espera, 1             ; Marcar que estamos en antirebote

CAMBIO_B1_DEBOUNCE:
    RCALL   DELAY_10MS
    LDS     temp2, debounce_timer
    DEC     temp2
    STS     debounce_timer, temp2
    BRNE    CAMBIO_B1_DEBOUNCE

    ; Verificar que el botón SIGUE presionado después del antirebote
    SBIC    PINC, PC0                  ; Si PC0 = 0 (sigue presionado)
    RJMP    CAMBIO_B1_FIN               ; Si ya no está presionado, salir

    ; Botón confirmado: incrementar contador
    INC     contador
    CPI     contador, 16
    BRNE    B1_NO_RESET
    CLR     contador
B1_NO_RESET:
    RCALL   DISPLAY_UPDATE

CAMBIO_B1_FIN:
    CLR     flag_espera
    RET

; Subrutina: CAMBIO_B2 - Detecta cambio en botón 2
CAMBIO_B2:
    ; Guardar nuevo estado
    MOV     estado_B2, temp

    ; Verificar si fue presión
    ANDI    temp, (1<<PC1)           ; Si temp tiene 0, es presión
    BRNE    CAMBIO_B2_FIN             ; Si no es 0, fue liberación

    ; Es una presión - iniciar antirebote
    LDI     temp2, 5                  ; 5 × 10ms = 50ms
    STS     debounce_timer, temp2
    LDI     flag_espera, 1             ; Marcar que estamos en antirebote

CAMBIO_B2_DEBOUNCE:
    RCALL   DELAY_10MS
    LDS     temp2, debounce_timer
    DEC     temp2
    STS     debounce_timer, temp2
    BRNE    CAMBIO_B2_DEBOUNCE

    ; Verificar que el botón SIGUE presionado después del antirebote
    SBIC    PINC, PC1                  ; Si PC1 = 0 
    RJMP    CAMBIO_B2_FIN               ; Si ya no está presionado, salir

    ; Botón confirmado: decrementar contador
    DEC     contador
    CPI     contador, 255
    BRNE    B2_NO_RESET
    LDI     contador, 15
B2_NO_RESET:
    RCALL   DISPLAY_UPDATE

CAMBIO_B2_FIN:
    CLR     flag_espera
    RET

; Subrutina: DISPLAY_UPDATE - Actualiza display con valor de contador
DISPLAY_UPDATE:
    PUSH    temp
    PUSH    ZH
    PUSH    ZL

    ; Cargar dirección de la tabla
    LDI     ZH, HIGH(tabla_7seg*2)
    LDI     ZL, LOW(tabla_7seg*2)
    ADD     ZL, contador
    CLR     temp
    ADC     ZH, temp
    LPM     temp, Z                  ; Leer patrón de segmentos

    ; Desplazar para alinear con PD1-PD7
    ; Un desplazamiento a la izquierda logra esto
    LSL     temp                      ; Desplazar izquierda
    OUT     PORTD, temp               ; Escribir en display

    POP     ZL
    POP     ZH
    POP     temp
    RET

; Subrutina: DELAY_10MS - Delay de aproximadamente 10 ms
DELAY_10MS:
    PUSH    temp
    PUSH    R20

    ; Guardar configuración actual del Timer0
    IN      temp, TCCR0B
    PUSH    temp
    IN      temp, TCNT0
    PUSH    temp

    ; Configurar Timer0 para delay
    CLR     temp
    OUT     TCCR0A, temp               ; Modo normal
    LDI     temp, (1<<CS02)|(1<<CS00)  ; Prescaler 1024
    OUT     TCCR0B, temp
    CLR     temp
    OUT     TCNT0, temp                 ; Empezar desde 0
    LDI     R20, 156                    ; Valor para 10ms

DELAY_LOOP:
    IN      temp, TIFR0
    SBRS    temp, TOV0
    RJMP    DELAY_CHECK
    ; Si desbordó, reiniciar contador
    LDI     temp, (1<<TOV0)
    OUT     TIFR0, temp
    LDI     R20, 156
DELAY_CHECK:
    DEC     R20
    BRNE    DELAY_LOOP

    ; Restaurar configuración original del Timer0
    POP     temp
    OUT     TCNT0, temp
    POP     temp
    OUT     TCCR0B, temp

    POP     R20
    POP     temp
    RET

/****************************************/
// Interrupt routines
/****************************************/