# FYS4220-Torgrim-Magna
###### Simulation Waveforms Lab 1-1b 
The pink hex_ctrl waveform group is comprised only of the switches relevant to the seven-segment display task [3:0].   
The hex0 waveform group was created to rearrange the order of the hex0 signals to descending [6:0].  
The actual port definition is ascending [0:6] because we copied the select statement given in the course materials.       
![Alt text](/Lab1/screenshots/simulation_lab1_1b.PNG)

###### Simulation Waveforms Lab 1-2 
The waveforms below show that the counter is increased every rising edge of the clock after ena_n goes low. This is consistent with the written code, which states that for every rising edge of the clock if ena_n is low the counter is increased. 
![Alt text](/Lab1/screenshots/simulation_lab1-2.PNG)

In order to make the counter count only once each time a key is pressed, we need to do *edge detection*. That means we must pass the key input (in our case ena_n) through a register and see when the value of ena_n is low, and ena_r (_r stands for registered) is high. To make the check completely synchronous we made two registered versions of ena_n. 

![Alt text](/Lab1/screenshots/simulation_lab1-2_pretty_registers.PNG)

Now simulation shows that the counter only counts when detecting a falling edge on ena_n. 
