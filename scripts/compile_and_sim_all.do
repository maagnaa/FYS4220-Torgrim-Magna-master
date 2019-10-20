quit -sim

quietly set prj_path "../.."

do $prj_path/scripts/compile_uvvm_util.do
do $prj_path/scripts/compile_src.do
vsim i2c_master_tb
do $prj_path/scripts/wave_i2c_master.do
run -all