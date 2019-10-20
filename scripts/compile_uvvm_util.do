quit -sim

quietly set lib_name "uvvm_util"
quietly set util_part_path "../../uvvm/uvvm_util"

vlib $lib_name
vmap $lib_name  $lib_name

vcom  -2008 -work $lib_name   $util_part_path/src/types_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/adaptations_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/string_methods_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/protected_types_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/hierarchy_linked_list_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/alert_hierarchy_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/license_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/methods_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/bfm_common_pkg.vhd
vcom  -2008 -work $lib_name   $util_part_path/src/uvvm_util_context.vhd