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

// Configura el Timer1 del ATmega328P en modo Fast PWM con TOP en ICR1.
void PWM_init(void)
{
    // Configurar PB1 (OC1A, pin D9) como salida.
    DDRB |= (1 << PB1);

    // Modo no inversor + Fast PWM
    TCCR1A = (1 << COM1A1) | (1 << WGM11);

    // Fast PWM con TOP en ICR1 + prescaler 8
    TCCR1B = (1 << WGM13) | (1 << WGM12) | (1 << CS11);

    // Definir el periodo: 20ms para señal de 50Hz 
    ICR1 = PWM_TOP;

    // Posición inicial del servo: 0° (pulso de 1ms)
    OCR1A = SERVO_MIN;
}

// Mapea el valor del ADC (0-1023) al rango de pulso del servo.
void PWM_setServo(uint16_t adcValue)
{
    OCR1A = SERVO_MIN + ((uint32_t)adcValue * (SERVO_MAX - SERVO_MIN)) / 1023;
}