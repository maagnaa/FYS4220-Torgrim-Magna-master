vlib work
vmap work work

quietly set prj_path "../.."
vcom -2008 -check_synthesis $prj_path/hdl/i2c_master.vhd
vcom -2008 ../../hdl/tb/tmp175_simmodel.vhd
vcom -2008 ../../hdl/tb/i2c_master_pkg.vhd
vcom -2008 ../../hdl/tb/i2c_master_tb.vhd