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
    // PD3 (OC2B, pin D3) como salida fisica 
    DDRD |= (1 << PD3);

    /*
     * TCCR2A:
     *   COM2B1 = 1 -> No inversor en OC2B
     *   WGM20  = 1 -> Phase Correct PWM
     */
    TCCR2A = (1 << COM2B1) | (1 << WGM20);

    /*
     * TCCR2B:
     *   CS22=1, CS21=1, CS20=1 -> Prescaler 1024
     */
    TCCR2B = (1 << CS22) | (1 << CS21) | (1 << CS20);

    /* Posicion inicial: 0 grados */
    OCR2B = SERVO2_MIN;
}

// Mapea ADC (0-1023) al rango calibrado de OCR2B (8 a 20).


void PWM2_setServo(uint16_t adcValue)
{
    OCR2B = (uint8_t)(SERVO2_MIN +
            ((uint32_t)adcValue * (SERVO2_MAX - SERVO2_MIN)) / 1023);
}