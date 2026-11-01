set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports sys_clk_125]
create_clock -name sys_clk_125 -period 8.000 [get_ports sys_clk_125]
