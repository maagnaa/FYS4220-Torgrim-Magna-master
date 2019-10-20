/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

#include <stdio.h>
#include <float.h>
#include <io.h>
#include "system.h"
#include "altera_avalon_pio_regs.h"
#include "alt_types.h"
#include "sys/alt_irq.h"
#include "i2c_avalon_wrapper.h"

volatile int edge_capture;


static void handle_button_interrupts(void* context)
{
	// Cast context to edge_capture's type
	// Volatile to avoid compiler optimization
	volatile int* edge_capture_ptr = (volatile int*) context;

	// Read the edge capture register on the button PIO and store value
	*edge_capture_ptr = IORD_ALTERA_AVALON_PIO_EDGE_CAP(INTERRUPT_PIO_BASE);

	// Write to edge capture register to reset it
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(INTERRUPT_PIO_BASE, 0);

	switch (edge_capture)
	{
		/* Key 1 */
		case 0x1:
			printf("Hi from interrupt routine, Key 1 was pressed\n");
			break;
		/* Key 2 */
		case 0x2:
			printf("Hi from interrupt routine, Key 2 was pressed\n");
			break;
		/* Key 3 */
		case 0x4:
			printf("Hi from interrupt routine, Key 3 was pressed\n");
			break;
		/* Key 4 */
		case 0x8:
			printf("Alert from TMP175!\n");
			break;
		/* Default */
		default:
			printf("Hi from interrupt routine, illegal interrupt value \n");
			break;
	}
}

static void init_button_pio()
{
	// Recast the edge_capture pointer to match the alt_irq_register() function prototype
	void* edge_capture_ptr = (void*) &edge_capture;

	// Enable all 4 interrupts
	IOWR_ALTERA_AVALON_PIO_IRQ_MASK(INTERRUPT_PIO_BASE,0xf);

	// Reset the edge capture register
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(INTERRUPT_PIO_BASE, 0);

	// Register the interrupt handler
	alt_ic_isr_register(INTERRUPT_PIO_IRQ_INTERRUPT_CONTROLLER_ID,
						INTERRUPT_PIO_IRQ, handle_button_interrupts,
						edge_capture_ptr, 0x0);
}


int main()
{
  init_button_pio();
  printf("Hello from Nios II!\n");

  int i;
  int rawtemp;
  float readtemp;
  int temp;
  
  /*int swpio;

  while(1)
  {
	  swpio = IORD(SW_PIO_BASE,0); // Read SW values
	  IOWR(LED_PIO_BASE,0,swpio); // Turn on LEDS
  }*/

  if (!check_wrapper_busy())
  	  {
		// Address TMP175 and configure 12 bit resolution
  		  write_to_i2c_device(TMP175_ADDR, TMP175_CONFIG_REG, 1, 0x60);
  	  }



   if (!check_wrapper_busy())
	  	{
	  	rawtemp = read_from_i2c_device(TMP175_ADDR, TMP175_TEMP_REG, 2);
	  	printf("Raw temperature value is: %d\n", rawtemp);
		//To get the correct temperature value, shift rawtemp 4 to the right, the multiply by scaling factor
	  	readtemp = (float)(rawtemp >> 4) * 0.0625;
	  	temp = (int)readtemp & 0xFFF;
	  	printf("True temperature value is %d\n", temp);
		//Write a lower raw temperature value to THIGH to test functionality of alert pin 
		write_to_i2c_device(TMP175_ADDR, TMP175_THIGH_REG, 2, (rawtemp + 100) );
	  	}


  while(1)
  {
	  for (i=0; i<300000; i++); //wait loop
	  if (!check_wrapper_busy())
	  {
		//To get the correct temperature value, shift rawtemp 4 to the right
		rawtemp = (read_from_i2c_device(TMP175_ADDR, TMP175_TEMP_REG, 2)) >> 4;
		printf("Shifted raw temperature value is: %d\n", rawtemp);
		//Multiply by scaling factor
		readtemp = (float)rawtemp * 0.0625;
		temp = (int)readtemp & 0xFFF;
		printf("True temperature value is %d\n", temp);
	  }
  } 



  return 0;
}
