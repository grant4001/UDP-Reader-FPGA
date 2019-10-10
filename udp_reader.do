setenv LMC_TIMEUNIT -9
vlib work
vmap work work
vcom -work work "fifo.vhd"
vcom -work work "udp_reader.vhd"
vcom -work work "udp_reader_top.vhd"
vcom -work work "udp_reader_tb.vhd"
vsim +notimingchecks -L work work.udp_reader_tb -wlf udp_reader_sim.wlf

add wave -noupdate -group udp_reader_tb
add wave -noupdate -group udp_reader_tb -radix hexadecimal /udp_reader_tb/*
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst -radix hexadecimal /udp_reader_tb/udp_reader_top_inst/*
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst/udp_reader_inst
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst/udp_reader_inst -radix hexadecimal /udp_reader_tb/udp_reader_top_inst/udp_reader_inst/*
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst/FIN
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst/FIN -radix hexadecimal /udp_reader_tb/udp_reader_top_inst/FIN/*
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst/udp_reader_inst/FMID
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst/udp_reader_inst/FMID -radix hexadecimal /udp_reader_tb/udp_reader_top_inst/udp_reader_inst/FMID/*
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst/FOUT
add wave -noupdate -group udp_reader_tb/udp_reader_top_inst/FOUT -radix hexadecimal /udp_reader_tb/udp_reader_top_inst/FOUT/*
run -all