/*
 * Proyecto1_Reloj.asm
 *
 * Creado:  27/02/2026 16:50:27
 * Autor :  Rodrigo García
 * Descripcion: Reloj digital de 24 horas con display de 7 segmentos multiplexado.
 *				Muestra hora, fecha y alarma configurable.
 *              Utiliza Timer0 para el multiplexado, Timer1 para contar el tiempo, e interrupciones Pin-Change para los botones.
 */

/****************************************/
// Encabezado (Definicion de Registros, Variables y Constantes)

.include "M328PDEF.inc"     // Definiciones especificas del ATMega328P

// Registros de uso general 
.DEF modo_actual    = R20   // Modo actual del reloj (0 a 5)
.DEF accion_boton   = R22   // Accion pendiente de boton (0=nada, 1=UP, 2=DOWN)
.DEF turno_display  = R25   // Turno del multiplexado (0 a 3)

/****************************************/
// Variables en memoria RAM

.DSEG
.ORG SRAM_START

// Tiempo actual 
min_unidades:       .BYTE 1     // Unidades de los minutos 
min_decenas:        .BYTE 1     // Decenas de los minutos  
hora_unidades:      .BYTE 1     // Unidades de la hora     
hora_decenas:       .BYTE 1     // Decenas de la hora      

// Fecha actual 
fecha_dia:          .BYTE 1     // Dia actual   
fecha_mes:          .BYTE 1     // Mes actual   

// Configuracion de alarma 
alarma_min_u:       .BYTE 1     // Unidades de minutos de la alarma
alarma_min_d:       .BYTE 1     // Decenas de minutos de la alarma
alarma_hora_u:      .BYTE 1     // Unidades de hora de la alarma
alarma_hora_d:      .BYTE 1     // Decenas de hora de la alarma
alarma_activa:      .BYTE 1     // 1 = alarma habilitada, 0 = deshabilitada
alarma_sonando:     .BYTE 1     // 1 = buzzer sonando en este momento

//  Buffer de digitos para el display 
digito1:            .BYTE 1     // Display 1  - Decenas de hora
digito2:            .BYTE 1     // Display 2  - Unidades de hora
digito3:            .BYTE 1     // Display 3  - Decenas de minuto
digito4:            .BYTE 1     // Display 4  - Unidades de minuto

//  Banderas del sistema 
flag_parpadeo:      .BYTE 1     // Alterna 0/1 cada 500ms, parpadeo en config
flag_puntos:        .BYTE 1     // 1 = mostrar puntos DP encendidos
flag_minuto:        .BYTE 1     // Bandera de cambio de minuto 
contador_500ms:     .BYTE 1     // Cuenta intervalos de 500ms hasta 1 minuto
estado_anterior_c:  .BYTE 1     // Estado previo de PC0/PC1 para antirrebote
estado_anterior_b:  .BYTE 1     // Estado previo de PB0 para antirrebote

/****************************************/

.CSEG
.ORG 0x0000
    RJMP    inicio              // Vector de reset, saltar al inicio del programa

//  Vectores de interrupcion 
.ORG PCI0addr                   // Pin Change 0 - boton DOWN
    RJMP    isr_boton_down

.ORG PCI1addr                   // Pin Change 1 - botones MODO y UP
    RJMP    isr_botones_modo_up

.ORG OC1Aaddr                   // Timer1 Compare A - control de tiempo (500ms)
    RJMP    isr_timer1

.ORG OVF0addr                   // Timer0 Overflow - multiplexado del display
    RJMP    isr_timer0_mux

/****************************************/
// Tablas en memoria de programa 

// Tabla de patrones para display 7 segmentos
tabla_segmentos:
    .DB 0b01011111, 0b00000110, 0b00111011, 0b00101111  // 0, 1, 2, 3
    .DB 0b01100110, 0b01101101, 0b01111101, 0b00000111  // 4, 5, 6, 7
    .DB 0b01111111, 0b01101111, 0b00000000, 0b00000000  // 8, 9, APAGADO, PAD

// Tabla de dias maximos por mes
tabla_dias_mes:
    .DB 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

/****************************************/
// Configuracion de la pila

inicio:
    LDI     R16, LOW(RAMEND)    // Apuntar el stack al final de la RAM
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16

/****************************************/
// Configuracion MCU

SETUP:
    CLI                         // Deshabilitar interrupciones durante la configuracion

    // PORTD: salida para los segmentos del display
    LDI     R16, 0xFF
    OUT     DDRD, R16
    LDI     R16, 0x00
    OUT     PORTD, R16          // Apagar todos los segmentos al inicio

    // PORTC: PC2-PC5 salidas transistores, PC0-PC1 entradas con pull-up 
    LDI     R16, 0b00111100
    OUT     DDRC, R16
    LDI     R16, 0b00000011     // Pull-up en PC0 (MODO) y PC1 (UP)
    OUT     PORTC, R16

    // PORTB: PB1/PB2/PB3 salidas, PB0 entrada con pull-up 
    LDI     R16, 0b00001110     // PB1=LED_FECHA, PB2=LED_HORA, PB3=BUZZER
    OUT     DDRB, R16
    LDI     R16, 0b00000001     // Pull-up en PB0, DOWN
    OUT     PORTB, R16

    // Limpiar todas las variables del sistema
    LDI     R16, 0
    STS     alarma_activa,      R16
    STS     alarma_sonando,     R16
    STS     digito1,            R16
    STS     digito2,            R16
    STS     digito3,            R16
    STS     digito4,            R16
    STS     flag_parpadeo,      R16
    STS     flag_puntos,        R16
    STS     flag_minuto,        R16
    STS     contador_500ms,     R16

    //  Hora inicial: 12:00
    LDI     R16, 0
    STS     min_unidades,   R16
    STS     min_decenas,    R16
    LDI     R16, 2
    STS     hora_unidades,  R16     // Hora = 12
    LDI     R16, 1
    STS     hora_decenas,   R16

    //  Fecha inicial: 01/01
    LDI     R16, 1
    STS     fecha_dia,  R16
    STS     fecha_mes,  R16

    //  Alarma inicial: 07:00 
    LDI     R16, 0
    STS     alarma_min_u,   R16
    STS     alarma_min_d,   R16
    LDI     R16, 7
    STS     alarma_hora_u,  R16     // Alarma = 07:00
    LDI     R16, 0
    STS     alarma_hora_d,  R16

    //  Leer estado inicial de botones para evitar falsas interrupciones 
    IN      R16, PINC
    ANDI    R16, 0x03
    STS     estado_anterior_c, R16
    IN      R16, PINB
    ANDI    R16, 0x01
    STS     estado_anterior_b, R16

    //  Limpiar registros de control 
    CLR     modo_actual
    CLR     accion_boton
    CLR     turno_display

    //  Timer0: genera interrupcion cada 4ms para el multiplexado 
    // Prescaler 256 sobre 16MHz - overflow cada 4ms
    LDI     R16, (1 << CS02)
    OUT     TCCR0B, R16
    LDI     R16, 0
    OUT     TCNT0, R16
    LDS     R16, TIMSK0
    ORI     R16, (1 << TOIE0)
    STS     TIMSK0, R16

    //  Timer1: genera interrupcion cada 500ms para el control de tiempo 
    // Modo CTC, Prescaler 256: OCR1A = 31249 -> interrupcion cada 500ms 
    LDI     R16, 0x00
    STS     TCCR1A, R16
    LDI     R16, (1 << WGM12)
    STS     TCCR1B, R16
    LDI     R16, HIGH(31249)
    STS     OCR1AH, R16
    LDI     R16, LOW(31249)
    STS     OCR1AL, R16
    LDI     R16, (1 << OCIE1A)
    STS     TIMSK1, R16
    LDS     R16, TCCR1B
    ORI     R16, (1 << CS12)    // Activar prescaler 256
    STS     TCCR1B, R16

    //  Interrupciones Pin-Change para detectar pulsaciones de botones 
    LDI     R16, (1 << PCIE1) | (1 << PCIE0)
    STS     PCICR, R16
    LDI     R16, 0b00000011     // Monitorear PC0 y PC1
    STS     PCMSK1, R16
    LDI     R16, 0b00000001     // Monitorear PB0
    STS     PCMSK0, R16

    SEI                         // Habilitar interrupciones globales

/****************************************/
// Loop Infinito

MAIN_LOOP:

    // Redirigir al bloque de codigo del modo activo
    CPI     modo_actual, 0
    BRNE    chk_modo_1
    RJMP    modo_ver_hora
chk_modo_1:
    CPI     modo_actual, 1
    BRNE    chk_modo_2
    RJMP    modo_ver_fecha
chk_modo_2:
    CPI     modo_actual, 2
    BRNE    chk_modo_3
    RJMP    modo_ver_alarma
chk_modo_3:
    CPI     modo_actual, 3
    BRNE    chk_modo_4
    RJMP    modo_config_hora
chk_modo_4:
    CPI     modo_actual, 4
    BRNE    chk_modo_5
    RJMP    modo_config_fecha
chk_modo_5:
    CPI     modo_actual, 5
    BRNE    modo_invalido
    RJMP    modo_config_alarma
modo_invalido:
    CLR     modo_actual         // Modo invalido: volver al modo 0
    RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines

// MODO 0: VER HORA
// Muestra la hora actual en formato HH:MM.
// Los puntos centrales parpadean cada 500ms indicando que el reloj corre.
// LED HORA encendido como indicador de modo.
modo_ver_hora:
    CBI     PORTB, 1            // Apagar LED FECHA
    SBI     PORTB, 2            // Encender LED HORA

    LDS     R16, hora_decenas
    STS     digito1, R16
    LDS     R16, hora_unidades
    STS     digito2, R16
    LDS     R16, min_decenas
    STS     digito3, R16
    LDS     R16, min_unidades
    STS     digito4, R16

    LDS     R16, flag_parpadeo
    STS     flag_puntos, R16    // Los puntos siguen el ritmo del parpadeo
    RJMP    MAIN_LOOP

// MODO 1: VER FECHA
// Muestra la fecha en formato DD/MM con puntos fijos.
// LED FECHA encendido como indicador de modo.
modo_ver_fecha:
    SBI     PORTB, 1            // Encender LED FECHA
    CBI     PORTB, 2            // Apagar LED HORA

    LDI     R16, 1
    STS     flag_puntos, R16    // Punto fijo para separar DD/MM

    LDS     R16, fecha_dia
    RCALL   dividir_por_10
    STS     digito1, R17        // Decenas del dia
    STS     digito2, R18        // Unidades del dia

    LDS     R16, fecha_mes
    RCALL   dividir_por_10
    STS     digito3, R17        // Decenas del mes
    STS     digito4, R18        // Unidades del mes
    RJMP    MAIN_LOOP

// MODO 2: VER ALARMA
// Muestra la hora configurada para la alarma.
// LED HORA: encendido = alarma habilitada / apagado = deshabilitada.
// Boton UP: activa o desactiva la alarma.
modo_ver_alarma:
    CBI     PORTB, 1

    LDS     R16, alarma_activa
    CPI     R16, 1
    BRNE    alarma_led_apagado
    SBI     PORTB, 2            // LED encendido = alarma ON
    RJMP    alarma_mostrar_digitos
alarma_led_apagado:
    CBI     PORTB, 2            // LED apagado = alarma OFF

alarma_mostrar_digitos:
    LDI     R16, 0
    STS     flag_puntos, R16

    LDS     R16, alarma_hora_d
    STS     digito1, R16
    LDS     R16, alarma_hora_u
    STS     digito2, R16
    LDS     R16, alarma_min_d
    STS     digito3, R16
    LDS     R16, alarma_min_u
    STS     digito4, R16

    CPI     accion_boton, 1
    BRNE    fin_modo_alarma
    LDS     R16, alarma_activa
    LDI     R17, 1
    EOR     R16, R17            // Alternar entre habilitada y deshabilitada
    STS     alarma_activa, R16
    CPI     R16, 0
    BRNE    fin_modo_alarma
    STS     alarma_sonando, R16
    CBI     PORTB, 3            // Si se desactivo, apagar buzzer

fin_modo_alarma:
    CLR     accion_boton
    RJMP    MAIN_LOOP

// MODO 3: CONFIGURAR HORA
// Los digitos parpadean para indicar que se esta en modo configuracion.
// UP = sumar 1 minuto | DOWN = sumar 1 hora
// El tiempo se pausa mientras se configura.
modo_config_hora:
    CBI     PORTB, 1
    CBI     PORTB, 2

    LDS     R16, flag_parpadeo
    CPI     R16, 1
    BREQ    config_hora_apagar_display

    LDS     R16, hora_decenas
    STS     digito1, R16
    LDS     R16, hora_unidades
    STS     digito2, R16
    LDS     R16, min_decenas
    STS     digito3, R16
    LDS     R16, min_unidades
    STS     digito4, R16
    RJMP    config_hora_leer_botones

config_hora_apagar_display:
    LDI     R16, 10             // Indice 10 = patron apagado en la tabla
    STS     digito1, R16
    STS     digito2, R16
    STS     digito3, R16
    STS     digito4, R16

config_hora_leer_botones:
    CPI     accion_boton, 0
    BREQ    fin_config_hora
    CPI     accion_boton, 1
    BREQ    config_hora_up
    CPI     accion_boton, 2
    BREQ    config_hora_down
    RJMP    fin_config_hora

config_hora_up:
    RCALL   sumar_minuto
    RJMP    config_hora_limpiar

config_hora_down:
    RCALL   sumar_hora
    RJMP    config_hora_limpiar

config_hora_limpiar:
    CLR     accion_boton

fin_config_hora:
    RJMP    MAIN_LOOP

// MODO 4: CONFIGURAR FECHA
// Los digitos parpadean para indicar configuracion.
// UP = sumar 1 dia | DOWN = sumar 1 mes
modo_config_fecha:
    SBI     PORTB, 1
    CBI     PORTB, 2

    LDI     R16, 1
    STS     flag_puntos, R16

    LDS     R16, flag_parpadeo
    CPI     R16, 1
    BREQ    config_fecha_apagar_display

    LDS     R16, fecha_dia
    RCALL   dividir_por_10
    STS     digito1, R17
    STS     digito2, R18
    LDS     R16, fecha_mes
    RCALL   dividir_por_10
    STS     digito3, R17
    STS     digito4, R18
    RJMP    config_fecha_leer_botones

config_fecha_apagar_display:
    LDI     R16, 10
    STS     digito1, R16
    STS     digito2, R16
    STS     digito3, R16
    STS     digito4, R16

config_fecha_leer_botones:
    CPI     accion_boton, 0
    BREQ    fin_config_fecha
    CPI     accion_boton, 1
    BREQ    config_fecha_up
    CPI     accion_boton, 2
    BREQ    config_fecha_down
    RJMP    fin_config_fecha

config_fecha_up:
    RCALL   sumar_dia
    RJMP    config_fecha_limpiar

config_fecha_down:
    RCALL   sumar_mes
    RJMP    config_fecha_limpiar

config_fecha_limpiar:
    CLR     accion_boton

fin_config_fecha:
    RJMP    MAIN_LOOP

// MODO 5: CONFIGURAR ALARMA
// Los digitos parpadean para indicar configuracion.
// UP = sumar 1 minuto | DOWN = sumar 1 hora
modo_config_alarma:
    CBI     PORTB, 1
    SBI     PORTB, 2

    LDI     R16, 0
    STS     flag_puntos, R16

    LDS     R16, flag_parpadeo
    CPI     R16, 1
    BREQ    config_alarma_apagar_display

    LDS     R16, alarma_hora_d
    STS     digito1, R16
    LDS     R16, alarma_hora_u
    STS     digito2, R16
    LDS     R16, alarma_min_d
    STS     digito3, R16
    LDS     R16, alarma_min_u
    STS     digito4, R16
    RJMP    config_alarma_leer_botones

config_alarma_apagar_display:
    LDI     R16, 10
    STS     digito1, R16
    STS     digito2, R16
    STS     digito3, R16
    STS     digito4, R16

config_alarma_leer_botones:
    CPI     accion_boton, 0
    BREQ    fin_config_alarma
    CPI     accion_boton, 1
    BREQ    config_alarma_up
    CPI     accion_boton, 2
    BREQ    config_alarma_down
    RJMP    fin_config_alarma

config_alarma_up:
    RCALL   sumar_minuto_alarma
    RJMP    config_alarma_limpiar

config_alarma_down:
    RCALL   sumar_hora_alarma
    RJMP    config_alarma_limpiar

config_alarma_limpiar:
    CLR     accion_boton

fin_config_alarma:
    RJMP    MAIN_LOOP

// SUBRUTINA: dividir_por_10
// Divide R16 entre 10 por restas sucesivas.
// Resultado: R17 = decenas, R18 = unidades 
dividir_por_10:
    CLR     R17
dividir_loop:
    CPI     R16, 10
    BRLO    dividir_fin
    SUBI    R16, 10
    INC     R17
    RJMP    dividir_loop
dividir_fin:
    MOV     R18, R16
    RET

// SUBRUTINA: sumar_minuto
// Suma 1 a los minutos del reloj con overflow a 00 al llegar a 60.
sumar_minuto:
    LDS     R16, min_unidades
    INC     R16
    CPI     R16, 10
    BRNE    guardar_min_u
    LDI     R16, 0
    STS     min_unidades, R16
    LDS     R16, min_decenas
    INC     R16
    CPI     R16, 6
    BRNE    guardar_min_d
    LDI     R16, 0
guardar_min_d:
    STS     min_decenas, R16
    RET
guardar_min_u:
    STS     min_unidades, R16
    RET

// SUBRUTINA: sumar_hora
// Suma 1 a las horas del reloj. Overflow de 23 a 00.
sumar_hora:
    LDS     R16, hora_unidades
    LDS     R17, hora_decenas
    INC     R16
    CPI     R17, 2
    BRNE    sumar_hora_chk10
    CPI     R16, 4              // Si decenas=2 y unidades llegan a 4 - overflow
    BRNE    guardar_hora_u
    LDI     R16, 0
    LDI     R17, 0
    STS     hora_unidades, R16
    STS     hora_decenas,  R17
    RET
sumar_hora_chk10:
    CPI     R16, 10
    BRNE    guardar_hora_u
    LDI     R16, 0
    STS     hora_unidades, R16
    INC     R17
    STS     hora_decenas,  R17
    RET
guardar_hora_u:
    STS     hora_unidades, R16
    RET

// SUBRUTINA: sumar_dia
// Suma 1 al dia. Usa la tabla de dias por mes para saber el maximo.
// Al pasar el maximo, vuelve al dia 1.
sumar_dia:
    LDS     R16, fecha_dia
    INC     R16
    LDS     R17, fecha_mes
    DEC     R17
    LDI     ZH, HIGH(tabla_dias_mes * 2)
    LDI     ZL, LOW(tabla_dias_mes * 2)
    ADD     ZL, R17
    BRCC    sumar_dia_nc
    INC     ZH
sumar_dia_nc:
    LPM     R17, Z              // R17 = maximo de dias del mes actual
    CP      R16, R17
    BRLO    guardar_dia
    BREQ    guardar_dia
    LDI     R16, 1              // Overflow: volver al dia 1
guardar_dia:
    STS     fecha_dia, R16
    RET

// SUBRUTINA: sumar_mes
// Suma 1 al mes con overflow de 12 a 1.
// Ajusta el dia si el dia actual supera el maximo del nuevo mes.
sumar_mes:
    LDS     R16, fecha_mes
    INC     R16
    CPI     R16, 13
    BRNE    guardar_mes
    LDI     R16, 1
guardar_mes:
    STS     fecha_mes, R16
    RCALL   ajustar_dia_al_mes
    RET

// SUBRUTINA: ajustar_dia_al_mes
// Si el dia actual supera el maximo del mes, lo recorta al ultimo dia valido.
ajustar_dia_al_mes:
    LDS     R17, fecha_mes
    DEC     R17
    LDI     ZH, HIGH(tabla_dias_mes * 2)
    LDI     ZL, LOW(tabla_dias_mes * 2)
    ADD     ZL, R17
    BRCC    ajustar_dia_nc
    INC     ZH
ajustar_dia_nc:
    LPM     R17, Z
    LDS     R16, fecha_dia
    CP      R17, R16
    BRSH    ajustar_dia_ok      // Si maximo >= dia, no hay que ajustar
    STS     fecha_dia, R17      // Si el dia excede el maximo, cortar
ajustar_dia_ok:
    RET

// SUBRUTINA: sumar_minuto_alarma
// Suma 1 a los minutos de la alarma. Igual logica que sumar_minuto.
sumar_minuto_alarma:
    LDS     R16, alarma_min_u
    INC     R16
    CPI     R16, 10
    BRNE    guardar_alm_min_u
    LDI     R16, 0
    STS     alarma_min_u, R16
    LDS     R16, alarma_min_d
    INC     R16
    CPI     R16, 6
    BRNE    guardar_alm_min_d
    LDI     R16, 0
guardar_alm_min_d:
    STS     alarma_min_d, R16
    RET
guardar_alm_min_u:
    STS     alarma_min_u, R16
    RET

// SUBRUTINA: sumar_hora_alarma
// Suma 1 a la hora de la alarma. Igual logica que sumar_hora.
sumar_hora_alarma:
    LDS     R16, alarma_hora_u
    LDS     R17, alarma_hora_d
    INC     R16
    CPI     R17, 2
    BRNE    sumar_ha_chk10
    CPI     R16, 4
    BRNE    guardar_alm_hora_u
    LDI     R16, 0
    LDI     R17, 0
    STS     alarma_hora_u, R16
    STS     alarma_hora_d, R17
    RET
sumar_ha_chk10:
    CPI     R16, 10
    BRNE    guardar_alm_hora_u
    LDI     R16, 0
    STS     alarma_hora_u, R16
    INC     R17
    STS     alarma_hora_d, R17
    RET
guardar_alm_hora_u:
    STS     alarma_hora_u, R16
    RET

// SUBRUTINA: verificar_alarma
// Compara la hora actual digito por digito con la hora de la alarma.
// Si coinciden y la alarma esta habilitada, enciende el buzzer.
verificar_alarma:
    LDS     R16, alarma_activa
    CPI     R16, 1
    BRNE    fin_verificar_alarma

    LDS     R16, hora_decenas
    LDS     R17, alarma_hora_d
    CP      R16, R17
    BRNE    fin_verificar_alarma

    LDS     R16, hora_unidades
    LDS     R17, alarma_hora_u
    CP      R16, R17
    BRNE    fin_verificar_alarma

    LDS     R16, min_decenas
    LDS     R17, alarma_min_d
    CP      R16, R17
    BRNE    fin_verificar_alarma

    LDS     R16, min_unidades
    LDS     R17, alarma_min_u
    CP      R16, R17
    BRNE    fin_verificar_alarma

    // Hora y minutos coinciden: encender buzzer
    LDI     R16, 1
    STS     alarma_sonando, R16
    SBI     PORTB, 3

fin_verificar_alarma:
    RET

/****************************************/
// Interrupt routines

// ISR: isr_timer0_mux  (llamada cada 4ms)
// Apaga todos los displays, avanza al siguiente turno y enciende
// un solo display con su patron de segmentos correspondiente.
// Esto crea la ilusion de que todos los displays estan encendidos.
isr_timer0_mux:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16
    PUSH    R24

    // Apagar todos los transistores
    CBI     PORTC, 2
    CBI     PORTC, 3
    CBI     PORTC, 4
    CBI     PORTC, 5

    // Avanzar turno
    INC     turno_display
    ANDI    turno_display, 0x03

    CPI     turno_display, 0
    BREQ    mux_disp1
    CPI     turno_display, 1
    BREQ    mux_disp2
    CPI     turno_display, 2
    BREQ    mux_disp3
    RJMP    mux_disp4

mux_disp1:
    LDS     R16, digito1
    RCALL   cargar_patron_segmentos
    OUT     PORTD, R24
    SBI     PORTC, 2
    RJMP    fin_mux

mux_disp2:
    LDS     R16, digito2
    RCALL   cargar_patron_segmentos
    LDS     R16, flag_puntos        // Agregar punto decimal si corresponde
    SBRC    R16, 0
    ORI     R24, 0x80
    OUT     PORTD, R24
    SBI     PORTC, 3
    RJMP    fin_mux

mux_disp3:
    LDS     R16, digito3
    RCALL   cargar_patron_segmentos
    LDS     R16, flag_puntos
    SBRC    R16, 0
    ORI     R24, 0x80
    OUT     PORTD, R24
    SBI     PORTC, 4
    RJMP    fin_mux

mux_disp4:
    LDS     R16, digito4
    RCALL   cargar_patron_segmentos
    OUT     PORTD, R24
    SBI     PORTC, 5

fin_mux:
    POP     R24
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI


// SUBRUTINA: cargar_patron_segmentos
// Recibe el indice del digito en R16 (0=cero ... 9=nueve, 10=apagado).
// Busca el patron en la tabla Flash y lo retorna en R24.
cargar_patron_segmentos:
    LDI     ZH, HIGH(tabla_segmentos * 2)
    LDI     ZL, LOW(tabla_segmentos * 2)
    ADD     ZL, R16
    BRCC    cps_nc
    INC     ZH
cps_nc:
    LPM     R24, Z
    RET


// ISR: isr_timer1  (llamada cada 500ms)
// Alterna el parpadeo de los displays en modos de configuracion.
// Cuenta 120 interrupciones (60 segundos) para avanzar 1 minuto.
// El conteo se pausa si se esta configurando la hora o la fecha.
// Al cumplirse 1 minuto, incrementa el tiempo y verifica la alarma.
isr_timer1:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16
    PUSH    R17

    // Alternar el estado de parpadeo cada 500ms
    LDS     R16, flag_parpadeo
    LDI     R17, 1
    EOR     R16, R17
    STS     flag_parpadeo, R16

    // Incrementar el contador de intervalos de 500ms
    LDS     R16, contador_500ms
    INC     R16
    STS     contador_500ms, R16

    // Pausar el avance del tiempo durante la configuracion
    CPI     modo_actual, 3
    BREQ    fin_timer1
    CPI     modo_actual, 4
    BREQ    fin_timer1

    // Verificar si se completo 1 minuto (120 x 500ms = 60 segundos)
    CPI     R16, 120
    BRNE    fin_timer1

    CLR     R16
    STS     contador_500ms, R16

    RCALL   avanzar_minuto_auto     // Avanzar minutos, y hora si corresponde
    RCALL   verificar_alarma        // Disparar alarma si la hora coincide

fin_timer1:
    POP     R17
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI

// SUBRUTINA: avanzar_minuto_auto
// Incrementa los minutos. Al llegar a 60 los reinicia y avanza la hora.
avanzar_minuto_auto:
    LDS     R16, min_unidades
    INC     R16
    CPI     R16, 10
    BRNE    guardar_minu_auto
    LDI     R16, 0
    STS     min_unidades, R16
    LDS     R16, min_decenas
    INC     R16
    CPI     R16, 6
    BRNE    guardar_mind_auto
    LDI     R16, 0
    STS     min_decenas, R16
    RCALL   avanzar_hora_auto
    RET
guardar_mind_auto:
    STS     min_decenas, R16
    RET
guardar_minu_auto:
    STS     min_unidades, R16
    RET

// SUBRUTINA: avanzar_hora_auto
// Incrementa la hora. Al llegar a 24:00 reinicia a 00:00 y avanza el dia.
avanzar_hora_auto:
    LDS     R16, hora_unidades
    LDS     R17, hora_decenas
    INC     R16
    CPI     R17, 2
    BRNE    avanzar_hora_chk10
    CPI     R16, 4
    BRNE    guardar_hru_auto
    LDI     R16, 0
    LDI     R17, 0
    STS     hora_unidades, R16
    STS     hora_decenas,  R17
    RCALL   avanzar_dia_auto    // Medianoche: avanzar al siguiente dia
    RET
avanzar_hora_chk10:
    CPI     R16, 10
    BRNE    guardar_hru_auto
    LDI     R16, 0
    STS     hora_unidades, R16
    INC     R17
    STS     hora_decenas,  R17
    RET
guardar_hru_auto:
    STS     hora_unidades, R16
    RET

// SUBRUTINA: avanzar_dia_auto
// Avanza el dia respetando los dias del mes.
// Al terminar el mes avanza al siguiente. Diciembre vuelve a enero.
avanzar_dia_auto:
    LDS     R16, fecha_dia
    INC     R16
    LDS     R17, fecha_mes
    DEC     R17
    LDI     ZH, HIGH(tabla_dias_mes * 2)
    LDI     ZL, LOW(tabla_dias_mes * 2)
    ADD     ZL, R17
    BRCC    avanzar_dia_nc
    INC     ZH
avanzar_dia_nc:
    LPM     R17, Z
    CP      R16, R17
    BRLO    guardar_dia_auto
    BREQ    guardar_dia_auto
    LDI     R16, 1              // Nuevo mes: reiniciar al dia 1
    LDS     R17, fecha_mes
    INC     R17
    CPI     R17, 13
    BRNE    guardar_mes_auto
    LDI     R17, 1              // Nuevo anio: volver a enero
guardar_mes_auto:
    STS     fecha_mes, R17
guardar_dia_auto:
    STS     fecha_dia, R16
    RET

// ISR: isr_botones_modo_up  (Pin Change en PC0 y PC1)
// Detecta cuando se presiona MODO (PC0) o UP (PC1).
// Compara con el estado anterior para ignorar rebotes y flancos de subida.
isr_botones_modo_up:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16
    PUSH    R17

    IN      R16, PINC
    ANDI    R16, 0x03               // Solo leer PC0 y PC1

    LDS     R17, estado_anterior_c
    CP      R16, R17
    BREQ    fin_isr_modo_up         // Sin cambio real, ignorar

    STS     estado_anterior_c, R16

    SBRS    R16, 0                  // PC0=0 significa MODO presionado
    RCALL   accion_cambiar_modo

    SBRS    R16, 1                  // PC1=0 significa UP presionado
    LDI     accion_boton, 1

fin_isr_modo_up:
    POP     R17
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI

// ISR: isr_boton_down  (Pin Change en PB0)
// Detecta cuando se presiona el boton DOWN.
isr_boton_down:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16
    PUSH    R17

    IN      R16, PINB
    ANDI    R16, 0x01               // Solo leer PB0

    LDS     R17, estado_anterior_b
    CP      R16, R17
    BREQ    fin_isr_down

    STS     estado_anterior_b, R16

    SBRS    R16, 0                  // PB0=0 significa DOWN presionado
    LDI     accion_boton, 2

fin_isr_down:
    POP     R17
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI

// SUBRUTINA: accion_cambiar_modo
// Al presionar MODO: si la alarma esta sonando, la apaga.
// Si no, avanza al siguiente modo (0->1->2->3->4->5->0).

accion_cambiar_modo:
    LDS     R17, alarma_sonando
    CPI     R17, 1
    BRNE    cambiar_modo_normal

    LDI     R17, 0
    STS     alarma_sonando, R17
    CBI     PORTB, 3                // Apagar buzzer si la alarma estaba sonando
    RET

cambiar_modo_normal:
    INC     modo_actual
    CPI     modo_actual, 6
    BRNE    modo_valido
    CLR     modo_actual             // Despues del modo 5, volver al modo 0
modo_valido:
    RET

/****************************************/