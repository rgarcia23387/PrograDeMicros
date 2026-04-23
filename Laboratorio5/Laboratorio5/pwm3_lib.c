/*
 * pwm3_lib.c
 *
 * Created: 22/04/2026 10:35:52
 * Author: Rodrigo García
  * Description: Implementacion del PWM usando interrupciones del Timer0.
 */ 

/****************************************/
// Encabezado
/****************************************/
#include "pwm3_lib.h"
/****************************************/
// Variables internas de la libreria
/****************************************/
// contador interno que se incrementa en cada interrupcion.
static volatile uint8_t counter = 0;

 // valor de comparacion que define el ancho del pulso.
static volatile uint8_t duty = 0;

/****************************************/
// Implementacion de funciones
/****************************************/

// Configura Timer0 en modo CTC para interrupciones periodicas.

void PWM3_init(void)
{
    // PB0 como salida para el LED.
    DDRB |= LED_PIN;

    // Apagar LED inicialmente.
    PORTB &= ~LED_PIN;

    // TCCR0A: Modo CTC
    TCCR0A = (1 << WGM01);

    // TCCR0B con prescaler 64.
    TCCR0B = (1 << CS01) | (1 << CS00);
	
    OCR0A = 9;

    // Habilitar interrupcion por comparacion A del Timer0.
    TIMSK0 |= (1 << OCIE0A);
}

// Escala el valor del ADC (0-1023) a duty cycle (0-255).
void PWM3_setDuty(uint16_t adcValue)
{
    duty = (uint8_t)((uint32_t)adcValue * 255 / 1023);
}

/****************************************/
// Interrupt routine
/****************************************/

// ISR Timer0 Compare Match A, se ejecuta cada 40us
ISR(TIMER0_COMPA_vect)
{
    counter++;                  // Incrementar contador 

    if (counter == 0)
    {
        // Inicio de nuevo ciclo PWM, poner LED en alto 
        PORTB |= LED_PIN;
    }

    if (counter == duty)
    {
        // Contador llego al duty cycle: apagar LED 
        PORTB &= ~LED_PIN;
    }
}