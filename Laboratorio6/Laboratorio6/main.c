/*
 * Laboratorio6.c
 *
 * Created: 24/04/2026 11:38:30
 * Author: Rodrigo García
 * Description: Parte 1: Enviar caracter del MCU a PC via UART.
 *              Parte 2: Recibir caracter desde hiperterminal y mostrarlo en
 *              Puerto B y Puerto C con 8 LEDs.
 */

/****************************************/
// Encabezado (Libraries)
/****************************************/
#define F_CPU 16000000UL        // Frecuencia del Arduino Nano 

#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

// Defines
#define BAUD        9600 // Velocidad de Comunicación
#define UBRR_VAL    (F_CPU / (16UL * BAUD)) - 1   // = 103 para 9600 baud a 16MHz

/****************************************/
// Function prototypes
/****************************************/
void UART_init(unsigned int ubrr);
void UART_transmit(unsigned char data);
unsigned char UART_receive(void);
void mostrar_en_LEDs(unsigned char dato);

/****************************************/
// Main Function
/****************************************/
int main(void)
{
    // Configuracion de puertos

    // Puerto B, PB0-PB5 como salida.
    DDRB = 0x3F;        // 0b00111111
    PORTB = 0x00;

    // Puerto C, PC0 y PC1 como salida
    DDRC = 0x03;        // 0b00000011
    PORTC = 0x00;

    // Inicializar UART
    UART_init(UBRR_VAL);

    // Habilitar interrupciones globales
    sei();

    // Parte 1: Enviar un caracter desde el MCU hacia la PC
    UART_transmit('R');     // Enviar letra 'A' a la hiperterminal

    // Parte 2: Recibir un caracter y mostrarlo en los LEDs
    unsigned char received;

    while (1)
    {
        received = UART_receive();      // Esperar y recibir caracter
        mostrar_en_LEDs(received);      // Mostrar en Puerto B y Puerto C
    }

    return 0;
}

/****************************************/
// NON-Interrupt subroutines
/****************************************/

// UART_init: Configura el modulo UART del Arduino.

void UART_init(unsigned int ubrr)
{
    // Configurar baud rate
    UBRR0H = (unsigned char)(ubrr >> 8);
    UBRR0L = (unsigned char)(ubrr);

    // Habilitar transmisor y receptor
    UCSR0B = (1 << RXEN0) | (1 << TXEN0);

    // Formato: 8 bits de datos, 1 stop bit, sin paridad
    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

// UART_transmit: Envia un byte por UART
void UART_transmit(unsigned char data)
{
    while (!(UCSR0A & (1 << UDRE0)));   // Esperar buffer vacio
    UDR0 = data;
}

// UART_receive: Espera y retorna un byte recibido por UART
unsigned char UART_receive(void)
{
    while (!(UCSR0A & (1 << RXC0)));    // Esperar dato recibido
    return UDR0;
}

// mostrar_en_LEDs: Muestra el byte recibido en los 8 LEDs
void mostrar_en_LEDs(unsigned char dato)
{
    // Bits bajos a Puerto B, protegiendo PB6 y PB7
    PORTB = (PORTB & 0xC0) | (dato & 0x3F);

    // Bits altos desplazados a PC0 y PC1
    PORTC = (PORTC & 0xFC) | ((dato >> 6) & 0x03);
}

/****************************************/
// Interrupt routines
/****************************************/