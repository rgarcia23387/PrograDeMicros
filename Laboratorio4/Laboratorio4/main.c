/*
 * Laboratorio4.c
 *
 * Created: 9/04/2026 23:50:12
 * Author: Rodrigo García
 * Description: Contador binario de 8 bits con 2 pushbuttons
 *				Lectura de potenciómetro con visualización del voltaje en dos displays.
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
 * Valor del Timer1 para interrumpir cada ~3ms
 * Fórmula: OCR1A = (F_CPU / (Prescaler * Frecuencia)) - 1
 * Con Prescaler=64 y frecuencia=333Hz (cada 3ms):
 * OCR1A = (16000000 / (64 * 333)) - 1 = 749
 */
#define TIMER1_OCR      749

// Tabla de segmentos para dígitos 0-9
// Display de ánodo común: 1 = segmento ENCENDIDO
/****************************************/
const uint8_t segmentos[10] = {
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
};

/****************************************/
// Function prototypes
/****************************************/

// Parte 1
void     initPorts(void);
void     updateLEDs(uint8_t value);
uint8_t  debounce(uint8_t pin_mask);

// Parte 2
void     initADC(void);
void     initTimer1(void);
uint16_t readADC(uint8_t channel);
void     encenderDisplay(uint8_t digito, uint8_t selector);

// Variables Globales
volatile uint8_t counter      = 0;   // Contador binario de 8 bits 
volatile uint8_t disp_decenas = 0;   // Dígito izquierdo para el display
volatile uint8_t disp_unidades= 0;   // Dígito derecho para el display 
volatile uint8_t disp_turno   = 0;   // 0 = turno display 1, 1 = turno display 2

/****************************************/
// Main Function
/****************************************/
int main(void)
{
    initPorts();
    initADC();
    initTimer1();
    sei();                            // Habilitar interrupciones globales

    while (1)
    {
// Manejo del contador con pushbuttons
// Botón UP, incrementar contador
        if (debounce(BTN_UP))
        {
            counter++;
            updateLEDs(counter);

            while (!(PINC & BTN_UP));
            _delay_ms(DEBOUNCE_MS);
        }

// Botón DOWN, decrementar contador
        if (debounce(BTN_DOWN))
        {
            counter--;
            updateLEDs(counter);

            while (!(PINC & BTN_DOWN));
            _delay_ms(DEBOUNCE_MS);
        }
// Lectura ADC
        uint16_t adcValue = readADC(ADC_CHANNEL);


// Convertir ADC a voltaje en décimas:
// (ADC * 50) / 1023
// Resultado: 0-50, donde 25 = 2.5V, 50 = 5.0V
        uint8_t valorMostrar = (uint8_t)((adcValue * 50UL) / 1023);
        disp_decenas  = valorMostrar / 10;
        disp_unidades = valorMostrar % 10;
    }
}

/****************************************/
// NON-Interrupt subroutines
/****************************************/

// Configura todos los pines del programa:
void initPorts(void)
{
    // PB0-PB5 como salidas 
    DDRB  |=  (1<<PB0)|(1<<PB1)|(1<<PB2)|(1<<PB3)|(1<<PB4)|(1<<PB5);
    PORTB &= ~((1<<PB0)|(1<<PB1)|(1<<PB2)|(1<<PB3)|(1<<PB4)|(1<<PB5));

    // PC0-PC1 salidas 
    // PC2-PC3 entradas con pull-up 
    // PC4-PC5 salidas 
    DDRC  |=  (1<<PC0)|(1<<PC1)|(1<<PC4)|(1<<PC5);
    DDRC  &= ~(BTN_UP | BTN_DOWN);
    PORTC |=  (BTN_UP | BTN_DOWN);
    PORTC &= ~((1<<PC0)|(1<<PC1)|(1<<PC4)|(1<<PC5));

    // PD0-PD6 como salidas 
    DDRD  |=  0x7F;
    PORTD &= ~0x7F;
}


// Inicializa el módulo ADC
void initADC(void)
{
    ADMUX  = (1 << REFS0);
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}


 // Timer1 en modo CTC para generar una interrupción cada ~3ms 
void initTimer1(void)
{
    TCCR1B |= (1 << WGM12);              // Modo CTC
    TCCR1B |= (1 << CS11) | (1 << CS10);// Prescaler = 64
    OCR1A   = TIMER1_OCR;                // Comparador para ~3ms
    TIMSK1 |= (1 << OCIE1A);            // Habilitar interrupción por comparación
}

uint16_t readADC(uint8_t channel)
{
    ADMUX = (ADMUX & 0xF0) | (channel & 0x0F);
    ADCSRA |= (1 << ADSC);
    while (ADCSRA & (1 << ADSC));
    return ADC;
}


// Actualizar LEDs
void updateLEDs(uint8_t value)
{
    PORTB = (PORTB & 0xC0) | (value & 0x3F);

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
        {
            return 1;
        }
    }
    return 0;
}

//Enceder Display
void encenderDisplay(uint8_t digito, uint8_t selector)
{
    PORTC &= ~(DISP1_PIN | DISP2_PIN);
    PORTD  = (PORTD & 0x80) | (segmentos[digito] & 0x7F);
    PORTC |= selector;
}

/****************************************/
// Interrupt routines
/****************************************/
// Timer 1
ISR(TIMER1_COMPA_vect)
{
    if (disp_turno == 0)
    {
        encenderDisplay(disp_decenas, DISP1_PIN);
        disp_turno = 1;
    }
    else
    {
        encenderDisplay(disp_unidades, DISP2_PIN);
        disp_turno = 0;
    }
}