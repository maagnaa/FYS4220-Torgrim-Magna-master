# FYS4220-Torgrim-Magna

# Lab 2
### Lab 2 Part 1 - I2C Master Trigger Signals
#### Simulation Waveforms
![alt text](/snapshots/Lab2-1.PNG "I2C Master Trigger Signals")

### Lab 2 Final Simulation - I2C Master 
#### Simulation Waveforms
![alt text](/snapshots/L2-2.PNG "I2C Master Trigger Signals")

Comments: 
We added an internal busy signal, busy_i, to avoid attempting to set an output inside a process. 
In processes p_sclk and p_ctrl we changed the name of the cnt variable to cnt_half_period and cnt_period respectively, as this made it easier for us to see what was going on. 
Other comments are found in the code. 

# Lab 3
## Lab 3 Part 1 - Simulation of I2C master with UVVM
There was an error concerning the trigger signals that caused them to glitch out of phase and produce start/stop conditions that where not intended. This was fixed by rewriting p_sclk and adding a mechanism for synchronization between the counter variables in p_sclk and p_ctrl. 
Below is a screenshot showing the trigger signals at an arbitraty point in simulation, where they where out of sync with the SCL clock.
![alt text](/snapshots/LAB3-1-SCL-MADNESS.PNG "I2C Master Trigger Signals, having glided out of sync with the SCL clock")

## Lab 3 Part 2 - I2C master controller
The 12 most significant bits of the temperature sensor were 0001 0111 1000, which is 376 in decimal. Multiplying this by 0.0625 (from the 12 bit resolution) gave a temperature of 23.5 degrees. 

# Lab 4
## Lab 4 Part 1 - Basic NIOS-II System
From the compilation report flow summary, we can see the resource usage for the design.

![alt text](/snapshots/lab4_resources.PNG "Compilation report summary")

From this screenshot we can see that the design uses 819 adaptive logic modules (ALMs), or 3% of the available ALM resources. 
Furthermore, the amount of registers utilized is 1201, and the block memory utilization is a modest 4% of the available BRAM.

#### Adding Software Functionality to the NIOS II
In this part of the Lab we programmed the NIOS II with a simple Hello World program that printed "HELLO FROM NIOS II!" to the console. Each time we pressed push button KEY0 the message was printed again, ie. the processor was reset. This is explained by the fact that we have connected push button KEY0 to the reset pin of the NIOS II processor in the system_top.vhd designfile.


![alt text](/snapshots/lab4_hello.PNG "HELLOES")

## Lab 4 Part 2 - Implement the I2C communication IP

![alt text](/snapshots/lab4_2_resources.PNG "Compilation report summary")

The number of adaptive logic modules (ALMs) have increased from 819 to 932, but this is still 3% of the available ALM resources. 
The amount of registers utilized is now 1453 instead of 1201, and the block memory utilization is still 4% of the available BRAM.


![alt text](/snapshots/lab4_temp.PNG "Temperatur readout")

The raw temperature value read from the 12 MSB of the temperature register was 405, which corresponds to approximately 25 degrees (we had to cast the value to an ineteger, as the printf function did not allow floating point values). 
We set the THIGH register to a value a little above the unshifted raw temperature so we would get an alert if the temperature increased. This is demonstrated in the above screenshot.

# Lab 5
## Lab 5 Part 1 - μC/OS-II basic system and semaphores

![alt text](/snapshots/lab5_1_helloes.PNG "Helloes")

We observe that Task1, which has the highest priority, interrupts Task2 before it has finished printing. This is shown in the screenshot above.

![alt text](/snapshots/lab5_1_helloes_with_sem2_paint.PNG "Helloes again")

The screenshot above shows what happens when semaphores are added to the task, with timing explicitly printed. We added some extra timing parameters as can be seen in the screenshot to better understand when the semaphore was available and when not. We see in this screenshot a deviant case where Task 1 takes a lot of time to complete, apparently because it waits for the semaphore for 179 ticks, but we cannot explain why this happens since Task 1 doesnt start (T:5145) before 15 ticks after the previous Task 2 has finished (T:5130).

![alt text](/snapshots/lab5_1_temp.PNG "Temperature")

We added some more delay to Task1 and Task2 so the console would not be flooded by Hello messages. The temperature is read and printed as shown above. 

## Lab 5 Part 2 - Synchronization of tasks

The snapshot belows shows the console results after synchronizing the interrupt from Key 1 using a synchronization semaphore.

![alt text](/snapshots/lab5_2_interrupt.PNG "Lab5-2-1")

When using a mailbox to change the temperature sampling time, we checked that it initially waited the expected 5 seconds. This is shown in the next screenshot. 

![alt text](/snapshots/Lab5_2_initwait.PNG "Lab5-2-2a")

Then, having used the altera pio macros to read the value of the switches and passed it using the mailbox:

![alt text](/snapshots/lab5_2_wait400_1600.PNG "Lab5-2-2b")


