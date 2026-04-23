/*
 * pwm2_lib.c
 *
 * Created: 17/04/2026 17:15:45
 * Author: Rodrigo Garcia
 * Description: Control de servo mediante PWM.
 */

// Encabezado
#include "pwm2_lib.h"

// Implementacion
// Configura el Timer2 en modo Phase Correct PWM.
void PWM2_init(void)
{
    // PB3 (OC2A, pin D11) como salida fisica 
    DDRB |= (1 << PB3);
	
    TCCR2A = (1 << COM2A1) | (1 << WGM21) | (1 << WGM20);
    TCCR2B = (1 << CS22) | (1 << CS21) | (1 << CS20);

    // Posicion inicial: 0 grados.
    OCR2A = SERVO2_MIN;
}

// Mapea ADC (0-1023) al rango calibrado de OCR2B (8 a 20).


void PWM2_setServo(uint16_t adcValue)
{
	// Escalar ADC de 10 bits a 8 bits.
	uint8_t valor_adc2 = (uint8_t)(adcValue >> 2);
	//Calcular posicion del servo.
    OCR2A = SERVO2_MIN + ((uint8_t)valor_adc2 * 31 / 255);
}