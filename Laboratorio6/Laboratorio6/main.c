/*
 * Laboratorio6.c
 *
 * Created: 24/04/2026 11:38:30
 * Author: Rodrigo García
 * Description: Laboratorio Completo - Menu de opciones para ver el valor del potenciometro y enviar ASCII
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
void cadena(char  txt[]);
void ADC_init(void);
unsigned int ADC_read(void);
void numero(unsigned int num);
void menu(void);

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

    // Inicializar UART y ADC
    UART_init(UBRR_VAL);
	ADC_init();

    // Habilitar interrupciones globales
    sei();

    // Primer Mensaje
    cadena(" Laboratorio 6 - UART \n");
	
    // Parte 1: Enviar un caracter desde el MCU hacia la PC
    // UART_transmit('R');     // Enviar letra 'A' a la hiperterminal

    // Parte 2: Recibir un caracter y mostrarlo en los LEDs
    // unsigned char received;

    while (1)
    {
       menu(); // Mostrar menu y ver opciones.
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

void cadena(char txt[])
{
    for (unsigned char i = 0; txt[i] != '\0'; i++)
    {
	    UART_transmit(txt[i]);
    }
}

// mostrar_en_LEDs: Muestra el byte recibido en los 8 LEDs
void mostrar_en_LEDs(unsigned char dato)
{
    // Bits bajos a Puerto B
    PORTB = (PORTB & 0xC0) | (dato & 0x3F);

    // Bits altos desplazados a PC0 y PC1
    PORTC = (PORTC & 0xFC) | ((dato >> 6) & 0x03);
}

// Configurar Modulo ADC
void ADC_init(void)
{
	ADMUX = (1 << REFS0) | (1 << MUX1); // Referencia AVCC y Canal ADC2
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);  // Habilitar ADC con Prescaler 128
	
}

// Leer el Valor del ADC
unsigned int ADC_read(void)
{
	ADCSRA |= (1 << ADSC); //Iniciar la conversion
	while (ADCSRA & (1 << ADSC)); // Esperar que termine
	return ADC; // REtornar valor 
}
void numero(unsigned int num)
{
	char buffer[6];
	unsigned char i = 0;
	    // Caso especial: si num es 0
	    if (num == 0)
	    {
		    UART_transmit('0');
		    return;
	    }

	    // Extraer digitos de derecha a izquierda
	    while (num > 0)
	    {
		    buffer[i] = (num % 10) + '0';  // Convertir digito a ASCII
		    num /= 10;
		    i++;
	    }

	    // Enviar digitos de izquierda a derecha 
	    for (unsigned char j = i; j > 0; j--)
	    {
		    UART_transmit(buffer[j - 1]);
	    }
}
void menu(void)
{
    unsigned char opcion;
    unsigned int valorADC;

    // Mostrar menu
    cadena("\n----------------------\n");
    cadena("        MENU          \n");
    cadena("----------------------\n");
    cadena("1. Leer Potenciometro \n");
    cadena("2. Enviar ASCII       \n");
    cadena("----------------------\n");
    cadena("Ingrese opcion: ");

    // Esperar opcion del usuario
    opcion = UART_receive();
    UART_transmit(opcion);              // Eco de la opcion
    cadena("\n");

    // Ejecutar segun opcion
    switch (opcion)
    {
		case '1':
		// Leer potenciometro y mostrar valor de 0 a 255
		valorADC = ADC_read();
		unsigned char valor8bits = (unsigned char)(valorADC >> 2);  //8 bits

		cadena("Valor Potenciometro: ");
		numero(valor8bits);
		cadena("/255\n");

		// Mostrar en LEDs
		mostrar_en_LEDs(valor8bits);
		_delay_ms(500);
		break;

	    case '2':
	    // Recibir un caracter ASCII y mostrarlo en LEDs
	    cadena("Escriba un caracter: ");
	    unsigned char ascii = UART_receive();
	    UART_transmit(ascii);       // Eco del caracter
	    cadena("\nCaracter recibido: ");
	    UART_transmit(ascii);
	    cadena("\nValor ASCII: ");
	    numero(ascii);
	    cadena("\n");
	    mostrar_en_LEDs(ascii);     // Mostrar en LEDs
	    _delay_ms(500);
	    break;

	    default:
	    // Opcion invalida
	    cadena("Opcion invalida, intente de nuevo.\n");
	    break;
    }
}
/****************************************/
// Interrupt routines
/****************************************/