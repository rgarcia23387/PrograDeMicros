/*
 * pwm2_lib.h
 *
 * Created: 17/04/2026 17:07:03
 * Author: Rodrigo Garcia
 * Description: Control de servo mediante PWM.
 */ 

#ifndef PWM2_LIB_H_
#define PWM2_LIB_H_

#define F_CPU 16000000UL
#include <avr/io.h>

// Defines de la libreria PWM2
/*
 * Rango calibrado del servo en ticks del Timer2:
 * Cada tick = 64 microsegundos (prescaler 1024 / 16MHz)
 *
 * SERVO2_MIN =  8 ticks -> 8  * 64us = 0.512ms -> 0 grados
 * SERVO2_MAX = 20 ticks -> 20 * 64us = 1.280ms -> ~180 grados
 */
#define SERVO2_MIN      8    // 0 grados
#define SERVO2_MAX      20   // 180 grados (calibrado)


// Prototipos

//Configura Timer2 en modo Phase Correct PWM con prescaler 1024.
// Configura PD3 (OC2B, pin D3) como salida.
// Debe llamarse una sola vez al inicio del programa.
void PWM2_init(void);

// Recibe valor ADC (0-1023) y lo mapea al rango calibrado
void PWM2_setServo(uint16_t adcValue);

#endif