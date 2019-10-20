view wave
delete wave *

add wave -divider
add wave -divider I2C_master
add wave -divider


add wave -divider i2c_master_inputs
add wave /i2c_master_tb/uut/GC_SYSTEM_CLK
add wave /i2c_master_tb/uut/GC_I2C_CLK
add wave /i2c_master_tb/uut/clk
add wave /i2c_master_tb/uut/rst_n
add wave /i2c_master_tb/uut/valid
add wave /i2c_master_tb/uut/addr
add wave /i2c_master_tb/uut/data_wr
add wave /i2c_master_tb/uut/rnw


#output
add wave -divider i2c_master_ouputs
add wave /i2c_master_tb/uut/busy
add wave /i2c_master_tb/uut/ack_error


#output
add wave -divider scl_related

#internal clk related
add wave /i2c_master_tb/uut/scl_clk
add wave /i2c_master_tb/uut/scl_oe
add wave /i2c_master_tb/uut/scl_high_ena
add wave /i2c_master_tb/uut/state_ena


#data
add wave -divider data_related
add wave /i2c_master_tb/uut/state
add wave /i2c_master_tb/uut/bit_cnt
add wave /i2c_master_tb/uut/data_rd
add wave /i2c_master_tb/uut/data_rx
add wave /i2c_master_tb/uut/data_tx
add wave /i2c_master_tb/uut/sda_i
add wave /i2c_master_tb/uut/addr_rnw_i


#i2c bus
add wave -divider i2c_bus
add wave /i2c_master_tb/uut/sda
add wave /i2c_master_tb/uut/scl


add wave -divider counters
add wave /i2c_master_tb/uut/p_sclk/cnt_period
add wave /i2c_master_tb/uut/p_ctrl/cnt_period


configure wave -namecolwidth 300
configure wave -valuecolwidth 100
configure wave -timelineunits ns
update