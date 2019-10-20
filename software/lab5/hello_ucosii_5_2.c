
#include <stdio.h>
#include "includes.h"
#include <string.h>

#include <float.h>
#include <io.h>
#include "system.h"
#include "altera_avalon_pio_regs.h"
#include "alt_types.h"
#include "sys/alt_irq.h"

#include "i2c_avalon_wrapper.h"



volatile int edge_capture;

/* Definition of Task Priorities */

#define TASK1_PRIORITY      2
#define TASK2_PRIORITY      3
#define TASK_TEMP_PRIORITY  1
#define TASK_ISR_PRIORITY   4

/* Definition of Task Stacks */
#define   TASK_STACKSIZE       2048
OS_STK    task1_stk[TASK_STACKSIZE];
OS_STK    task2_stk[TASK_STACKSIZE];
OS_STK	  task_temp_stk[TASK_STACKSIZE];
OS_STK    task_isr_stk[TASK_STACKSIZE];

/* Semaphores */
OS_EVENT *shared_jtag_sem;
OS_EVENT *key1_sem;

/* Declare mailbox */
OS_EVENT *MSG_box;

/* Global Variables */
int mailbox_data;
int t1_SemGet;
int t1_SemRelease;

//------------------------------------------------------------------
// Source Code for Button Interrupt Handling
//------------------------------------------------------------------
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
		// Key 1
		case 0x1:
			//printf("Hi from interrupt routine, Key 1 was pressed\n");
			OSSemPost(key1_sem); // post semaphore
			break;
		// Key 2
		case 0x2:
			//printf("Hi from interrupt routine, Key 2 was pressed\n");
			break;
		// Key 3
		case 0x4:
			//printf("Hi from interrupt routine, Key 3 was pressed\n");
			break;
		// Key 4
		case 0x8:
			//printf("Alert from TMP175!\n");
			break;
		// Default
		default:
			//printf("Hi from interrupt routine, illegal interrupt value \n");
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



	//IOADDR_ALTERA_AVALON_PIO_DATA(SW_PIO_BASE);

}


//------------------------------------------------------------------
// Task Functions
//------------------------------------------------------------------

void task1(void* pdata)
{
	int t_start;
	int t_end;
	int t_prev = 0;
	INT8U error_code = OS_NO_ERR;

	while (1)
	{
		t_start = OSTimeGet();

		char text1[] = "Hello from Task1\n";
		int i;
		OSSemPend(shared_jtag_sem, 0, &error_code); // ask/wait for semaphore
		t1_SemGet = OSTimeGet();
		for (i = 0; i < strlen(text1); i++)
		{
			putchar(text1[i]);
		}
		t_end = OSTimeGet();
		printf("T1: (Start,End,Ex.T.,P): (%d , %d, %d, %d)\n", t_start, t_end, t_end-t_start, t_start-t_prev);
		OSSemPost(shared_jtag_sem); // release semaphore
		t1_SemRelease = OSTimeGet();
		t_prev = t_start;
		OSTimeDlyHMSM(0, 0, 2, 0);
	}
}

void task2(void* pdata)
{
	int t_start;
	int t_end;
	int t_prev = 0;
	INT8U error_code = OS_NO_ERR;

	while (1)
	{
		t_start = OSTimeGet();
		char text2[] = "Hello from Task2\n";
		int i;
		OSSemPend(shared_jtag_sem, 0, &error_code); // ask/wait for semaphore

		for (i = 0; i < strlen(text2); i++)
		{
			putchar(text2[i]);
		}
		t_end = OSTimeGet();
		//printf("T2: (Start,End,Ex.T.,P): (%d , %d, %d, %d)\n", t_start, t_end, t_end-t_start, t_start-t_prev);
		printf("T2: (Start,End,Ex.T.,P): (%d , %d, %d, %d), (%d , %d), (%d, %d)\n", t_start, t_end, t_end-t_start, t_start-t_prev, t_start-t1_SemGet, t_start-t1_SemRelease,t1_SemGet, t1_SemRelease);
		OSSemPost(shared_jtag_sem); // release semaphore
		t_prev = t_start;
		OSTimeDlyHMSM(0, 0, 2, 0);
	}
}


void task_temperature(void* pdata)
{
	int rawtemp;
	float temp;
	int int_local = 5000; 	// Local interval variable
	int *int_msg;   		// Local message variable
	int this_pt; 			// current printtime
	int prev_pt = 0; 			// previous printtime

	INT8U error_code = OS_NO_ERR;

	if (!check_wrapper_busy())
	{
		// Address TMP175 and configure 12 bit resolution
	  	write_to_i2c_device(TMP175_ADDR, TMP175_CONFIG_REG, 1, 0x60);
	}


	while (1)
	{
		/* Pend Message and Copy to Local Variable */
		int_msg = (int*)OSMboxPend(MSG_box,int_local,&error_code);
		if (error_code != OS_TIMEOUT)
		{
			int_local = *int_msg;
		}

		OSSemPend(shared_jtag_sem, 0, &error_code); // ask/wait for semaphore

		if (!check_wrapper_busy())
		{
			//To get the correct temperature value, shift rawtemp 4 to the right
			rawtemp = (read_from_i2c_device(TMP175_ADDR, TMP175_TEMP_REG, 2)) >> 4;
			//Multiply by scaling factor
			temp = rawtemp * 0.0625;
			this_pt = OSTimeGet();
			printf("Temperature value is %.2f\nTime interval between previous print and this print: %d ms\n", temp, (this_pt - prev_pt));
			prev_pt = OSTimeGet();
		}

			OSSemPost(shared_jtag_sem); // release semaphore
			//OSTimeDlyHMSM(0, 0, 5, 0);

	}

}

void task_interrupt(void* pdata)
{
	INT8U error_code = OS_NO_ERR;
	int sw_val;
	while(1)
	{
		OSSemPend(key1_sem, 0, &error_code); // ask/wait for semaphore
		sw_val = IORD_ALTERA_AVALON_PIO_DATA(SW_PIO_BASE);
		mailbox_data = sw_val * 100;
		error_code = OSMboxPost(MSG_box,(void *)&mailbox_data);
		printf("Hi from interrupt routine, read switch value is: %d\n", sw_val);
		//printf("Hi from interrupt routine, Key 1 was pressed\n");
	}

}

//------------------------------------------------------------------
// Main Function
//------------------------------------------------------------------
int main(void)
{
  // Initialize Button PIO
  init_button_pio();
  // Create binary semaphore for protection of JTAG_UART
  shared_jtag_sem = OSSemCreate(1);
  // Create Synchronization Semaphore for Interrupt Handling
  key1_sem = OSSemCreate(0);
  // Create Message Queue
  MSG_box = OSMboxCreate((void*)NULL);
  
  OSTaskCreateExt(task1,
                  NULL,
                  (void *)&task1_stk[TASK_STACKSIZE-1],
                  TASK1_PRIORITY,
                  TASK1_PRIORITY,
                  task1_stk,
                  TASK_STACKSIZE,
                  NULL,
                  0);
              
               
  OSTaskCreateExt(task2,
                  NULL,
                  (void *)&task2_stk[TASK_STACKSIZE-1],
                  TASK2_PRIORITY,
                  TASK2_PRIORITY,
                  task2_stk,
                  TASK_STACKSIZE,
                  NULL,
                  0);

  OSTaskCreateExt(task_temperature,
                  NULL,
                  (void *)&task_temp_stk[TASK_STACKSIZE-1],
                  TASK_TEMP_PRIORITY,
                  TASK_TEMP_PRIORITY,
                  task_temp_stk,
                  TASK_STACKSIZE,
                  NULL,
                  0);

  OSTaskCreateExt(task_interrupt,
                  NULL,
                  (void *)&task_isr_stk[TASK_STACKSIZE-1],
                  TASK_ISR_PRIORITY,
                  TASK_ISR_PRIORITY,
                  task_isr_stk,
                  TASK_STACKSIZE,
                  NULL,
                  0);

  OSStart();
  return 0;
}
