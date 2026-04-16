/*
 * Laboratorio4.c
 *
 * Created: 9/04/2026 23:50:12
 * Author: Rodrigo García
 * Description: Contador binario de 8 bits con 2 pushbuttons
 *				Lectura de potenciómetro con visualización de numeros Hexadecimales.
				Alarma al detectar que ADC es mayor que el contador.
 */
/****************************************/
// Encabezado (Libraries)
/****************************************/
#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

/****************************************/
// Defines
/****************************************/

// Botones (PORTC)
#define BTN_UP          (1 << PC2)  // Pushbutton incremento
#define BTN_DOWN        (1 << PC3)  // Pushbutton decremento
#define DEBOUNCE_MS     30          // Tiempo antirebote software (ms)

// Control displays (PORTC)
#define DISP1_PIN       (1 << PC4)  // Transistor display izquierdo (nibble alto)
#define DISP2_PIN       (1 << PC5)  // Transistor display derecho  (nibble bajo)

// --- LED de alarma (PORTD) ---
#define ALARM_PIN       (1 << PD7)  // LED de alarma: se enciende si ADC > counter

// --- ADC ---
#define ADC_CHANNEL     6           // Canal ADC6 para el potenciómetro

/*
 * Timer1 en modo CTC con prescaler 64:
 * OCR1A = (F_CPU / (Prescaler * Frecuencia)) - 1
 * OCR1A = (16000000 / (64 * 333)) - 1 = 749 -> interrupción cada ~3ms
 */
#define TIMER1_OCR      749

// Tabla de segmentos 0-F (hexadecimal)
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

// Inicialización
void        initPorts(void);
void        initADC(void);
void        initTimer1(void);

// Parte 1 - Contador
void        updateLEDs(uint8_t value);
uint8_t     debounce(uint8_t pin_mask);

// Parte 2 - ADC y displays
uint16_t    readADC(uint8_t channel);
void        encenderDisplay(uint8_t digito, uint8_t selector);

// Post Lab - Alarma
void        checkAlarma(uint8_t adcValue, uint8_t counterValue);

/****************************************/
// Variables
/****************************************/
volatile uint8_t counter    = 0;  // Contador binario de 8 bits 
volatile uint8_t disp_alto  = 0;  // Nibble alto del valor hex 
volatile uint8_t disp_bajo  = 0;  // Nibble bajo del valor hex 
volatile uint8_t disp_turno = 0;  // Bandera multiplexeo

/****************************************/
// Main Function
/****************************************/
int main(void)
{
    // Inicializar hardware
    initPorts();
    initADC();
    initTimer1();
    sei();                              // Habilitar interrupciones globales

    while (1)
    {
         // PARTE 1: Contador con pushbuttons 

        // Botón UP (PC2), incrementar contador
        if (debounce(BTN_UP))
        {
            counter++;                  // Desbordamiento natural: 255 -> 0
            updateLEDs(counter);
            while (!(PINC & BTN_UP));
            _delay_ms(DEBOUNCE_MS);
        }

        // Botón DOWN (PC3), decrementar contador
        if (debounce(BTN_DOWN))
        {
            counter--;                  // Desbordamiento natural: 0 -> 255
            updateLEDs(counter);
            while (!(PINC & BTN_DOWN));
            _delay_ms(DEBOUNCE_MS);
        }
		
         // PARTE 2: Lectura ADC y conversión a hexadecimal 
        uint8_t adcByte = (uint8_t)(readADC(ADC_CHANNEL) >> 2);

        // Separar en nibbles para los displays
        disp_alto = (adcByte >> 4) & 0x0F;  // Nibble alto, display izquierdo
        disp_bajo =  adcByte       & 0x0F;  // Nibble bajo, display derecho

         // Comparación ADC vs Contador

        checkAlarma(adcByte, counter);
    }
}

/****************************************/
// NON-Interrupt subroutines
/****************************************/

// Puertos
void initPorts(void)
{
    // PB0-PB5: Salidas para LEDs del contador (bits 0-5) ---
    DDRB  |=  (1<<PB0)|(1<<PB1)|(1<<PB2)|(1<<PB3)|(1<<PB4)|(1<<PB5);
    PORTB &= ~((1<<PB0)|(1<<PB1)|(1<<PB2)|(1<<PB3)|(1<<PB4)|(1<<PB5));

    // PORTC: LEDs bits 6-7, botones y transistores displays
    DDRC  |=  (1<<PC0)|(1<<PC1)|(1<<PC4)|(1<<PC5); // Salidas
    DDRC  &= ~(BTN_UP | BTN_DOWN);                  // PC2-PC3 como entradas
    PORTC |=  (BTN_UP | BTN_DOWN);                  // Activar pull-ups en botones
    PORTC &= ~((1<<PC0)|(1<<PC1)|(1<<PC4)|(1<<PC5));// Salidas apagadas

    // PORTD: Segmentos A-G y LED de alarma 
    // 0x7F configura PD0-PD6 como salidas (segmentos)
    // ALARM_PIN = (1<<PD7) agrega PD7 como salida (LED alarma)
    DDRD  |=  0x7F | ALARM_PIN;
    PORTD &= ~(0x7F | ALARM_PIN);  // Todo apagado inicialmente
}

// Modulo ADC
void initADC(void)
{
    ADMUX  = (1 << REFS0);
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}

// Configuración Timer 1
void initTimer1(void)
{
    TCCR1B |= (1 << WGM12);
    TCCR1B |= (1 << CS11) | (1 << CS10);
    OCR1A   = TIMER1_OCR;
    TIMSK1 |= (1 << OCIE1A);
}

// Conversión ADC
uint16_t readADC(uint8_t channel)
{
    ADMUX   = (ADMUX & 0xF0) | (channel & 0x0F); // Seleccionar canal
    ADCSRA |= (1 << ADSC);                        // Iniciar conversión
    while (ADCSRA & (1 << ADSC));                 // Esperar fin de conversión
    return ADC;                                    // Retornar resultado 10 bits
}

// Actualizar LEDs

void updateLEDs(uint8_t value)
{
    PORTB = (PORTB & 0xC0) | (value & 0x3F);

    uint8_t highBits = (value >> 6) & 0x03;
    PORTC = (PORTC & 0xFC) | highBits;
}

//Antirebotes
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
    // Apagar ambos transistores para evitar ghosting
    PORTC &= ~(DISP1_PIN | DISP2_PIN);

    // Escribir segmentos en PD0-PD6 protegiendo PD7 (alarma).
    PORTD = (PORTD & 0x80) | (segmentos[digito] & 0x7F);

    // Activar transistor del display correspondiente
    PORTC |= selector;
}

// Checkar Alarma
void checkAlarma(uint8_t adcValue, uint8_t counterValue)
{
    if (adcValue > counterValue)
    {

         // ADC mayor que contador: ALARMA ACTIVA
        PORTD |= ALARM_PIN;
    }
    else
    {
         // ADC menor o igual al contador: ALARMA INACTIVA
        PORTD &= ~ALARM_PIN;
    }
}

/****************************************/
// Interrupt routines
/****************************************/

// ISR - Timer1 Compare Match A (cada 3ms)

ISR(TIMER1_COMPA_vect)
{
    if (disp_turno == 0)
    {
        encenderDisplay(disp_alto, DISP1_PIN);  // Display izq: nibble alto
        disp_turno = 1;
    }
    else
    {
        encenderDisplay(disp_bajo, DISP2_PIN);  // Display der: nibble bajo
        disp_turno = 0;
    }
}