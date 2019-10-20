/*************************************************************************
* Copyright (c) 2004 Altera Corporation, San Jose, California, USA.      *
* All rights reserved. All use of this software and documentation is     *
* subject to the License Agreement located at the end of this file below.*
**************************************************************************
* Description:                                                           *
* The following is a simple hello world program running MicroC/OS-II.The * 
* purpose of the design is to be a very simple application that just     *
* demonstrates MicroC/OS-II running on NIOS II.The design doesn't account*
* for issues such as checking system call return codes. etc.             *
*                                                                        *
* Requirements:                                                          *
*   -Supported Example Hardware Platforms                                *
*     Standard                                                           *
*     Full Featured                                                      *
*     Low Cost                                                           *
*   -Supported Development Boards                                        *
*     Nios II Development Board, Stratix II Edition                      *
*     Nios Development Board, Stratix Professional Edition               *
*     Nios Development Board, Stratix Edition                            *
*     Nios Development Board, Cyclone Edition                            *
*   -System Library Settings                                             *
*     RTOS Type - MicroC/OS-II                                           *
*     Periodic System Timer                                              *
*   -Know Issues                                                         *
*     If this design is run on the ISS, terminal output will take several*
*     minutes per iteration.                                             *
**************************************************************************/


#include <stdio.h>
#include "includes.h"
#include <string.h>

#include "i2c_avalon_wrapper.h"

/* Definition of Task Stacks */
#define   TASK_STACKSIZE       2048
OS_STK    task1_stk[TASK_STACKSIZE];
OS_STK    task2_stk[TASK_STACKSIZE];
OS_STK	  task_temp_stk[TASK_STACKSIZE];

// Semaphore
OS_EVENT *shared_jtag_sem;

/* Definition of Task Priorities */

#define TASK1_PRIORITY      2
#define TASK2_PRIORITY      3
#define TASK_TEMP_PRIORITY  1

int t1_SemGet;
int t1_SemRelease;

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
		OSTimeDlyHMSM(0, 0, 3, 20);
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
		OSTimeDlyHMSM(0, 0, 3, 4);
	}
}


void task_temperature(void* pdata)
{
	int rawtemp;
	float temp;
	INT8U error_code = OS_NO_ERR;

	if (!check_wrapper_busy())
	{
		// Address TMP175 and configure 12 bit resolution
	  	write_to_i2c_device(TMP175_ADDR, TMP175_CONFIG_REG, 1, 0x60);
	}

	while (1)
	{
		OSSemPend(shared_jtag_sem, 0, &error_code); // ask/wait for semaphore

		if (!check_wrapper_busy())
		{
			//To get the correct temperature value, shift rawtemp 4 to the right
			rawtemp = (read_from_i2c_device(TMP175_ADDR, TMP175_TEMP_REG, 2)) >> 4;
			//Multiply by scaling factor
			temp = rawtemp * 0.0625;
			printf("Temperature value is %.2f\n", temp);
		}

		OSSemPost(shared_jtag_sem); // release semaphore
		OSTimeDlyHMSM(0, 0, 5, 0);
	}
}



/* The main function creates two task and starts multi-tasking */
int main(void)
{
  // Create binary semaphore for protection of JTAG_UART
  shared_jtag_sem = OSSemCreate(1);
  
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

  OSStart();
  return 0;
}

/******************************************************************************
*                                                                             *
* License Agreement                                                           *
*                                                                             *
* Copyright (c) 2004 Altera Corporation, San Jose, California, USA.           *
* All rights reserved.                                                        *
*                                                                             *
* Permission is hereby granted, free of charge, to any person obtaining a     *
* copy of this software and associated documentation files (the "Software"),  *
* to deal in the Software without restriction, including without limitation   *
* the rights to use, copy, modify, merge, publish, distribute, sublicense,    *
* and/or sell copies of the Software, and to permit persons to whom the       *
* Software is furnished to do so, subject to the following conditions:        *
*                                                                             *
* The above copyright notice and this permission notice shall be included in  *
* all copies or substantial portions of the Software.                         *
*                                                                             *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  *
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,    *
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE *
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER      *
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING     *
* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER         *
* DEALINGS IN THE SOFTWARE.                                                   *
*                                                                             *
* This agreement shall be governed in all respects by the laws of the State   *
* of California and by the laws of the United States of America.              *
* Altera does not recommend, suggest or require that this reference design    *
* file be used in conjunction or combination with any other product.          *
******************************************************************************/
