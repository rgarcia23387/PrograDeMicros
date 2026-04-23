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
#define SERVO2_MIN      8    // 0 grados
#define SERVO2_MAX      39   // 180 grados (calibrado)


// Prototipos

//Configura Timer2 en modo Phase Correct PWM con prescaler 1024.
// Configura PD3 (OC2B, pin D3) como salida.
// Debe llamarse una sola vez al inicio del programa.
void PWM2_init(void);

// Recibe valor ADC (0-1023) y lo mapea al rango calibrado
void PWM2_setServo(uint16_t adcValue);

#endif