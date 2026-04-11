/*
 * Laboratorio4.c
 *
 * Created: 9/04/2026 23:50:12
 * Author: Rodrigo García
 * Description: Contador binario de 8 bits con 2 pushbuttons
 *				Lectura de potenciómetro con visualización de numeros Hexadecimales.
 */
/****************************************/
// Encabezado (Libraries)
/****************************************/
#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

// Botones 
#define BTN_UP          (1 << PC2)   // Pushbutton incremento
#define BTN_DOWN        (1 << PC3)   // Pushbutton decremento
#define DEBOUNCE_MS     30           // Tiempo antirebote 

// Control displays 
#define DISP1_PIN       (1 << PC4)   // Transistor display izquierdo 
#define DISP2_PIN       (1 << PC5)   // Transistor display derecho 

// ADC
#define ADC_CHANNEL     6            // Canal ADC6 para el potenciómetro

/*
 * Valor del Timer1 para interrumpir cada 3ms
 * Fórmula: OCR1A = (F_CPU / (Prescaler * Frecuencia)) - 1
 * Con Prescaler=64 y frecuencia=333Hz (cada 3ms):
 * OCR1A = (16000000 / (64 * 333)) - 1 = 749
 */
#define TIMER1_OCR      749

// Tabla de segmentos para dígitos
/****************************************/
const uint8_t segmentos[16] = {
    0b00111111,  // 0
    0b00000110,  // 1
    0b01011011,  // 2
    0b01001111,  // 3
    0b01100110,  // 4
    0b01101101,  // 5
    0b01111101,  // 6
    0b00000111,  // 7
    0b01111111,  // 8
    0b01101111,  // 9
	0b01110111,  // A
	0b01111100,  // B
	0b00111001,  // C
	0b01011110,  // D
	0b01111001,  // E
	0b01110001,  // F
};

/****************************************/
// Function prototypes
/****************************************/

// Parte 1
void     initPorts(void);
void     initADC(void);
void     initTimer1(void);

void     updateLEDs(uint8_t value);
uint8_t  debounce(uint8_t pin_mask);

// Parte 2
uint16_t readADC(uint8_t channel);
void     encenderDisplay(uint8_t digito, uint8_t selector);

// Variables Globales
volatile uint8_t counter    = 0;  // Contador binario 8 bits
volatile uint8_t disp_alto  = 0;  // Nibble alto del valor hex, izq.
volatile uint8_t disp_bajo  = 0;  // Nibble bajo del valor hex, der.
volatile uint8_t disp_turno = 0;  // Bandera multiplexeo: 0=disp1, 1=disp2
/****************************************/
// Main Function
/****************************************/
int main(void)
{
    initPorts();
    initADC();
    initTimer1();
    sei();                          // Habilitar interrupciones globales

    while (1)
    {

         // Contador con pushbuttons

        if (debounce(BTN_UP))
        {
            counter++;              // Desbordamiento natural: 255 -> 0
            updateLEDs(counter);
            while (!(PINC & BTN_UP));
            _delay_ms(DEBOUNCE_MS);
        }

        if (debounce(BTN_DOWN))
        {
            counter--;              // Desbordamiento natural: 0 -> 255
            updateLEDs(counter);
            while (!(PINC & BTN_DOWN));
            _delay_ms(DEBOUNCE_MS);
        }


         // Lectura ADC y conversión a hexadecimal
        uint8_t adcByte = (uint8_t)(readADC(ADC_CHANNEL) >> 2);

         // Separar el byte en dos nibbles
        disp_alto = (adcByte >> 4) & 0x0F;   // Nibble alto
        disp_bajo =  adcByte       & 0x0F;   // Nibble bajo
    }
}

/****************************************/
// NON-Interrupt subroutines
/****************************************/
//Puertos
void initPorts(void)
{
    // PB0-PB5 como salidas (LEDs)
    DDRB  |=  (1<<PB0)|(1<<PB1)|(1<<PB2)|(1<<PB3)|(1<<PB4)|(1<<PB5);
    PORTB &= ~((1<<PB0)|(1<<PB1)|(1<<PB2)|(1<<PB3)|(1<<PB4)|(1<<PB5));

    // PC0-PC1: salidas LEDs bits 6-7
    // PC2-PC3: entradas con pull-up 
    // PC4-PC5: salidas transistores displays
    DDRC  |=  (1<<PC0)|(1<<PC1)|(1<<PC4)|(1<<PC5);
    DDRC  &= ~(BTN_UP | BTN_DOWN);
    PORTC |=  (BTN_UP | BTN_DOWN);
    PORTC &= ~((1<<PC0)|(1<<PC1)|(1<<PC4)|(1<<PC5));

    // PD0-PD6 como salidas
    DDRD  |=  0x7F;
    PORTD &= ~0x7F;
}


// Iniciar ADC
void initADC(void)
{
    ADMUX  = (1 << REFS0);
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}

// Iniciar Timer 1
void initTimer1(void)
{
    TCCR1B |= (1 << WGM12);
    TCCR1B |= (1 << CS11) | (1 << CS10);
    OCR1A   = TIMER1_OCR;
    TIMSK1 |= (1 << OCIE1A);
}
// Leer ADC
uint16_t readADC(uint8_t channel)
{
    ADMUX   = (ADMUX & 0xF0) | (channel & 0x0F);
    ADCSRA |= (1 << ADSC);
    while (ADCSRA & (1 << ADSC));
    return ADC;
}

// Actualizar los LEDs
void updateLEDs(uint8_t value)
{
    // 6 bits bajos a PORTB (máscara 0xC0 protege PB6-PB7 del cristal)
    PORTB = (PORTB & 0xC0) | (value & 0x3F);

    // 2 bits altos a PC0-PC1 (máscara 0xFC protege PC2-PC5)
    uint8_t highBits = (value >> 6) & 0x03;
    PORTC = (PORTC & 0xFC) | highBits;
}


// Antirebote
uint8_t debounce(uint8_t pin_mask)
{
    if (!(PINC & pin_mask))
    {
        _delay_ms(DEBOUNCE_MS);
        if (!(PINC & pin_mask))
            return 1;
    }
    return 0;
}

// Encender Display
void encenderDisplay(uint8_t digito, uint8_t selector)
{
    PORTC &= ~(DISP1_PIN | DISP2_PIN);                     // Apagar ambos
    PORTD  = (PORTD & 0x80) | (segmentos[digito] & 0x7F);  // Escribir segmentos
    PORTC |= selector;                                       // Activar display
}
/****************************************/
// Interrupt routines
/****************************************/

// ISR - Timer1 Compare Match A, cada 3ms
ISR(TIMER1_COMPA_vect)
{
    if (disp_turno == 0)
    {
        encenderDisplay(disp_alto, DISP1_PIN);   // Display izq: nibble alto 
        disp_turno = 1;
    }
    else
    {
        encenderDisplay(disp_bajo, DISP2_PIN);   // Display der: nibble bajo
        disp_turno = 0;
    }
}