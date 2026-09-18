create_clock -period 10.204 -name clk [get_ports clk]

set_property PACKAGE_PIN K17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property PACKAGE_PIN K18 [get_ports btn0]
set_property IOSTANDARD LVCMOS33 [get_ports btn0]

set_property PACKAGE_PIN P16 [get_ports btn1]
set_property IOSTANDARD LVCMOS33 [get_ports btn1]

set_property PACKAGE_PIN M14 [get_ports {result_nibble[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {result_nibble[0]}]

set_property PACKAGE_PIN M15 [get_ports {result_nibble[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {result_nibble[1]}]

set_property PACKAGE_PIN G14 [get_ports {result_nibble[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {result_nibble[2]}]

set_property PACKAGE_PIN D18 [get_ports {result_nibble[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {result_nibble[3]}]

set_false_path -from [get_ports btn0]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 256 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {digest_o[0]} {digest_o[1]} {digest_o[2]} {digest_o[3]} {digest_o[4]} {digest_o[5]} {digest_o[6]} {digest_o[7]} {digest_o[8]} {digest_o[9]} {digest_o[10]} {digest_o[11]} {digest_o[12]} {digest_o[13]} {digest_o[14]} {digest_o[15]} {digest_o[16]} {digest_o[17]} {digest_o[18]} {digest_o[19]} {digest_o[20]} {digest_o[21]} {digest_o[22]} {digest_o[23]} {digest_o[24]} {digest_o[25]} {digest_o[26]} {digest_o[27]} {digest_o[28]} {digest_o[29]} {digest_o[30]} {digest_o[31]} {digest_o[32]} {digest_o[33]} {digest_o[34]} {digest_o[35]} {digest_o[36]} {digest_o[37]} {digest_o[38]} {digest_o[39]} {digest_o[40]} {digest_o[41]} {digest_o[42]} {digest_o[43]} {digest_o[44]} {digest_o[45]} {digest_o[46]} {digest_o[47]} {digest_o[48]} {digest_o[49]} {digest_o[50]} {digest_o[51]} {digest_o[52]} {digest_o[53]} {digest_o[54]} {digest_o[55]} {digest_o[56]} {digest_o[57]} {digest_o[58]} {digest_o[59]} {digest_o[60]} {digest_o[61]} {digest_o[62]} {digest_o[63]} {digest_o[64]} {digest_o[65]} {digest_o[66]} {digest_o[67]} {digest_o[68]} {digest_o[69]} {digest_o[70]} {digest_o[71]} {digest_o[72]} {digest_o[73]} {digest_o[74]} {digest_o[75]} {digest_o[76]} {digest_o[77]} {digest_o[78]} {digest_o[79]} {digest_o[80]} {digest_o[81]} {digest_o[82]} {digest_o[83]} {digest_o[84]} {digest_o[85]} {digest_o[86]} {digest_o[87]} {digest_o[88]} {digest_o[89]} {digest_o[90]} {digest_o[91]} {digest_o[92]} {digest_o[93]} {digest_o[94]} {digest_o[95]} {digest_o[96]} {digest_o[97]} {digest_o[98]} {digest_o[99]} {digest_o[100]} {digest_o[101]} {digest_o[102]} {digest_o[103]} {digest_o[104]} {digest_o[105]} {digest_o[106]} {digest_o[107]} {digest_o[108]} {digest_o[109]} {digest_o[110]} {digest_o[111]} {digest_o[112]} {digest_o[113]} {digest_o[114]} {digest_o[115]} {digest_o[116]} {digest_o[117]} {digest_o[118]} {digest_o[119]} {digest_o[120]} {digest_o[121]} {digest_o[122]} {digest_o[123]} {digest_o[124]} {digest_o[125]} {digest_o[126]} {digest_o[127]} {digest_o[128]} {digest_o[129]} {digest_o[130]} {digest_o[131]} {digest_o[132]} {digest_o[133]} {digest_o[134]} {digest_o[135]} {digest_o[136]} {digest_o[137]} {digest_o[138]} {digest_o[139]} {digest_o[140]} {digest_o[141]} {digest_o[142]} {digest_o[143]} {digest_o[144]} {digest_o[145]} {digest_o[146]} {digest_o[147]} {digest_o[148]} {digest_o[149]} {digest_o[150]} {digest_o[151]} {digest_o[152]} {digest_o[153]} {digest_o[154]} {digest_o[155]} {digest_o[156]} {digest_o[157]} {digest_o[158]} {digest_o[159]} {digest_o[160]} {digest_o[161]} {digest_o[162]} {digest_o[163]} {digest_o[164]} {digest_o[165]} {digest_o[166]} {digest_o[167]} {digest_o[168]} {digest_o[169]} {digest_o[170]} {digest_o[171]} {digest_o[172]} {digest_o[173]} {digest_o[174]} {digest_o[175]} {digest_o[176]} {digest_o[177]} {digest_o[178]} {digest_o[179]} {digest_o[180]} {digest_o[181]} {digest_o[182]} {digest_o[183]} {digest_o[184]} {digest_o[185]} {digest_o[186]} {digest_o[187]} {digest_o[188]} {digest_o[189]} {digest_o[190]} {digest_o[191]} {digest_o[192]} {digest_o[193]} {digest_o[194]} {digest_o[195]} {digest_o[196]} {digest_o[197]} {digest_o[198]} {digest_o[199]} {digest_o[200]} {digest_o[201]} {digest_o[202]} {digest_o[203]} {digest_o[204]} {digest_o[205]} {digest_o[206]} {digest_o[207]} {digest_o[208]} {digest_o[209]} {digest_o[210]} {digest_o[211]} {digest_o[212]} {digest_o[213]} {digest_o[214]} {digest_o[215]} {digest_o[216]} {digest_o[217]} {digest_o[218]} {digest_o[219]} {digest_o[220]} {digest_o[221]} {digest_o[222]} {digest_o[223]} {digest_o[224]} {digest_o[225]} {digest_o[226]} {digest_o[227]} {digest_o[228]} {digest_o[229]} {digest_o[230]} {digest_o[231]} {digest_o[232]} {digest_o[233]} {digest_o[234]} {digest_o[235]} {digest_o[236]} {digest_o[237]} {digest_o[238]} {digest_o[239]} {digest_o[240]} {digest_o[241]} {digest_o[242]} {digest_o[243]} {digest_o[244]} {digest_o[245]} {digest_o[246]} {digest_o[247]} {digest_o[248]} {digest_o[249]} {digest_o[250]} {digest_o[251]} {digest_o[252]} {digest_o[253]} {digest_o[254]} {digest_o[255]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list block_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list done_o]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list ready_o]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list rst_n]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
