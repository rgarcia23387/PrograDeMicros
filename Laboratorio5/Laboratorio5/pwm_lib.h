/*
 * pwm_lib.h
 *
 * Created: 17/04/2026 11:30:28
 * Author: Rodrigo Garcia
 * Description: Control de servo mediante PWM.
 */

#ifndef PWM_LIB_H_   /* Guard para evitar inclusión múltiple del header */
#define PWM_LIB_H_   /* Si el archivo ya fue incluido, se salta todo esto */

#define F_CPU 16000000UL
#include <avr/io.h>

/****************************************/
// Defines de la librería PWM
/****************************************/

// Para periodo de 20ms necesitamos: 39,999.
#define PWM_TOP         39999   // Valor TOP para periodo de 20ms (50Hz)

// Valores de comparación para el ancho de pulso del servo:
#define SERVO_MIN       1000    // Pulso de 0.5ms  = posición 0°
#define SERVO_MAX       5000    // Pulso de 2.5ms  = posición 180°

/****************************************/
// Prototipos de funciones de la librería
/****************************************/
// Configura el Timer1 en modo Fast PWM con TOP en ICR1.
void PWM_init(void);

// Recibe un valor del ADC (0-1023) y lo mapea al rango del servo.
void PWM_setServo(uint16_t adcValue);

#endif 