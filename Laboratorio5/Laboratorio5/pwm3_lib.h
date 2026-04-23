/*
 * pwm3_lib.h
 *
 * Created: 22/04/2026 10:35:14
 * Author: Rodrigo García
 * Description: Libreria propia para PWM para el Timer0 para generar interrupciones periodicas.
 */

#ifndef PWM3_LIB_H_
#define PWM3_LIB_H_

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>

/****************************************/
// Defines
/****************************************/
// Pin del LED en PORTB
#define LED_PIN         (1 << PB0)

//Resolucion del PWM manual: 256 pasos (0-255).
#define PWM3_RESOLUTION  255
/****************************************/
// Prototipos
/****************************************/


// Configura el Timer0 en modo CTC para generar interrupciones.
void PWM3_init(void);

// Recibe el valor del ADC (0-1023) y lo escala a 0-255.
void PWM3_setDuty(uint16_t adcValue);

#endif /* PWM3_LIB_H_ */