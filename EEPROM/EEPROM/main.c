/*
 * EEPROM.c
 *
 * Created: 22/04/2026 16:17:48
 * Author: 
 * Description: 
 */
/****************************************/
// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>


#include ""
/****************************************/
// Function prototypes
const char* L1_on = "L1:1";
const char* L1_off = "L1:0";

char* comando = "----";
/****************************************/
// Main Function
int main(void)
{
	cli ();
	// PD5 y PD6 como salidas inicialmente apagadas.
	DDRD |= (1<<DDD6) | (1<<DDD5);
	PORTD &= ~((1<<PORTD6) | (1<<PORTD5));
	// PD2 como entrada con Pull Up activado
	DDRD  &= ~(1<<DDD2);
	PORTD |= (1<<PORTD2);
	// Habilitar interrupciones a PD2
	PCICR |= (1<<PCIE2);
	PCMSK2 |= (1<<PCINT18);
	initUART();
	sei();
	while (1)
	{
	}
}
/****************************************/
// NON-Interrupt subroutines

/****************************************/
// Interrupt routines
ISR(USART_RX_vect)
{
	char bufferRX = UDR0;
	writeChar(bufferRX);
	if (bufferRX != '\n')
	{
		*(comando+num_receive) = bufferRX;
		num_receive++;
	}
	else{
		*(comando+0) = '-';
	}
// 	if (bufferRX == "a")
// 	{
// 		PORTD ^= (1<<PORTD5);
// 	}
}

ISR(PCINT2_vect)
{
	if (bufferRX == "a")
	{
		PORTD ^= (1<<PORTD5);3....
	}
}

