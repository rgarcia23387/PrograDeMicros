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

/*
 * El servo necesita una señal de 50Hz (periodo de 20ms).
 * Con Timer1 en modo Fast PWM y prescaler 8:
 *
 * Frecuencia del tick = F_CPU / Prescaler = 16MHz / 8 = 2,000,000 Hz
 * Periodo de cada tick = 1 / 2,000,000 = 0.5 microsegundos
 *
 * Para periodo de 20ms necesitamos:
 * TOP = (20ms / 0.5us) - 1 = 40,000 - 1 = 39,999
 */
#define PWM_TOP         39999   // Valor TOP para periodo de 20ms (50Hz)

/*
 * Valores de comparación para el ancho de pulso del servo:
 *   0.5ms = 0° (posición mínima)  ? 0.5ms    / 0.5us = 1000 ticks
 *   2.5ms = 180° (posición máxima)? 2.5ms  / 0.5us = 5000 ticks
 */
#define SERVO_MIN       1000    // Pulso de 0.5ms  = posición 0°
#define SERVO_MAX       5000    // Pulso de 2.5ms  = posición 180°

/****************************************/
// Prototipos de funciones de la librería
/****************************************/

/*
 * PWM_init
 * Configura el Timer1 en modo Fast PWM con TOP en ICR1.
 */
void PWM_init(void);

// PWM Servo
/*
 * Recibe un valor del ADC (0-1023) y lo mapea al rango
 * del servo (SERVO_MIN a SERVO_MAX), actualizando OCR1A.
 *
 * Parámetro:
 *   adcValue: lectura del ADC de 10 bits (0 a 1023)
 */
void PWM_setServo(uint16_t adcValue);

#endif /* PWM_LIB_H_ */