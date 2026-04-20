/*
 * Laboratorio5.c
 *
 * Created: 17/04/2026 11:30:28
 * Author: Rodrigo Garcia
 * Description: Control de servo mediante PWM.
 */

/****************************************/
// Encabezado (Libraries)
/****************************************/
#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include "pwm_lib.h"    // Librería propia para el PWM del Servo 1.
#include "pwm2_lib.h"    // Librería propia para el PWM del Servo 2.

// Defines

#define ADC_CH_POT1     0       // Canal ADC0 para el potenciómetro (pin A0)
#define ADC_CH_POT2     1       // Canal ADC1 para el potenciómetro (pin A1)
#define ADC_STABLE_MS   5       // Pequeño delay para estabilizar lectura ADC

/****************************************/
// Function prototypes
/****************************************/
void        initADC(void);
uint16_t    readADC(uint8_t channel);

/****************************************/
// Main Function
/****************************************/
int main(void)
{
// Iniciar modulos
    initADC();
    PWM_init();
	PWM2_init();

    while (1)
    {
         // Leer el potenciómetro en ADC canal 0
        uint16_t adc1 = readADC(ADC_CH_POT1);
		// Actualizar la posición del servo según el ADC.
		PWM_setServo(adc1);
        // Leer el potenciómetro en ADC canal 1
        uint16_t adc2 = readADC(ADC_CH_POT2);
		// Actualizar la posición del servo según el ADC.
		PWM2_setServo(adc2);

         // Pequeño delay para no actualizar OCR1A más rápido
        _delay_ms(ADC_STABLE_MS);
    }
}

/****************************************/
// NON-Interrupt subroutines
/****************************************/

// Inicio Modulo ADC 
void initADC(void)
{
    ADMUX  = (1 << REFS0);
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}

// Leer ADC
uint16_t readADC(uint8_t channel)
{
    ADMUX   = (ADMUX & 0xF0) | (channel & 0x0F);
    ADCSRA |= (1 << ADSC);
    while (ADCSRA & (1 << ADSC));
    return ADC;
}