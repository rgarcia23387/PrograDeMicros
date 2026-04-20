/*
 * pwm_lib.c
 *
 * Created: 17/04/2026 11:30:28
 * Author: Rodrigo Garcia
 * Description: Control de servo mediante PWM.
 */

// Encabezado
#include "pwm_lib.h"   // Incluir el header propio de la librería

// Implementación de funciones


/*
 * PWM_init
 * -------------------------------------------------------------------------
 * Configura el Timer1 del ATmega328P en modo Fast PWM con TOP en ICR1.
 *
 * Registros configurados:
 *
 * TCCR1A:
 *   COM1A1 = 1 -> Modo no inversor: OC1A (PB1) se pone en 1 al inicio
 *                 del ciclo y se pone en 0 cuando el contador llega a OCR1A
 *   WGM11  = 1 -> Parte del modo Fast PWM con TOP en ICR1 (WGM13:10 = 1110)
 *
 * TCCR1B:
 *   WGM13  = 1 -> Completa la configuración Fast PWM con TOP en ICR1
 *   WGM12  = 1 -> Junto con WGM13 y WGM11 forman el modo 14
 *   CS11   = 1 -> Prescaler = 8 (divide 16MHz entre 8 = 2MHz)
 *
 * ICR1 = PWM_TOP = 39999:
 *   Define el periodo de la señal PWM.
 *   El timer cuenta de 0 a 39999 y reinicia.
 *   Duración = 40000 ticks × 0.5µs = 20ms = 50Hz
 *
 * OCR1A = SERVO_MIN:
 *   Valor inicial del ancho de pulso = 1ms = posición 0°
 *
 * DDRB |= (1<<PB1):
 *   PB1 (D9) como salida, obligatorio para que OC1A pueda
 *   controlar físicamente el pin. Sin esto el PWM se genera
 *   internamente pero no sale al pin.
 */
void PWM_init(void)
{
    /* Configurar PB1 (OC1A, pin D9) como salida */
    DDRB |= (1 << PB1);

    /*
     * TCCR1A: COM1A1=1, WGM11=1
     * Modo no inversor + Fast PWM parte 1
     */
    TCCR1A = (1 << COM1A1) | (1 << WGM11);

    /*
     * TCCR1B: WGM13=1, WGM12=1, CS11=1
     * Fast PWM con TOP en ICR1 + prescaler 8
     */
    TCCR1B = (1 << WGM13) | (1 << WGM12) | (1 << CS11);

    /* Definir el periodo: 20ms para señal de 50Hz */
    ICR1 = PWM_TOP;

    /* Posición inicial del servo: 0° (pulso de 1ms) */
    OCR1A = SERVO_MIN;
}

/*
 * PWM_setServo
 * -------------------------------------------------------------------------
 * Mapea el valor del ADC (0-1023) al rango de pulso del servo.
 *
 * Fórmula de mapeo lineal:
 *   OCR1A = SERVO_MIN + (adcValue * (SERVO_MAX - SERVO_MIN)) / 1023
 *
 * Ejemplo:
 *   adcValue = 0    ? OCR1A = 2000 ? pulso 1ms  ? servo en 0°
 *   adcValue = 511  ? OCR1A = 3000 ? pulso 1.5ms ? servo en 90°
 *   adcValue = 1023 ? OCR1A = 4000 ? pulso 2ms  ? servo en 180°
 *
 * Se usa uint32_t en la multiplicación para evitar desbordamiento:
 *   1023 * 2000 = 2,046,000 que no cabe en uint16_t (máximo 65535)
 */
void PWM_setServo(uint16_t adcValue)
{
    OCR1A = SERVO_MIN + ((uint32_t)adcValue * (SERVO_MAX - SERVO_MIN)) / 1023;
}