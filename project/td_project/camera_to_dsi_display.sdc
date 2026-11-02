create_clock -name {sys_clk_50m} -period 20.000 -waveform {0.000 10.000} [get_ports {I_sys_clk}]
create_clock -name {mipi_rx_ck_pad} -period 2.415 -waveform {0.000 1.208} [get_nets {IO_rx_clk_pad_p}]

derive_clocks

rename_clock -name {pll_clk_100m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {pll_clk_24m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {HDMI_PIXEL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[4]}]
rename_clock -name {HDMI_SERIAL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[5]}]

rename_clock -name {MIPI_RX_BYTE_CLK} [get_clocks {u_mipi_dphy_rx_ph1p_mipiio_wrapper/u_ph1p_mipiio_rx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_RX.o_fabric_div4_8_clk}]

# SC520 I2C uses I_clk with edge enables; scl_clk is not an internal clock.


# Added security traffic uses held-data handshakes and vendor asynchronous FIFOs.
# Bound the physical crossing delays instead of hiding entire clock relationships.
# Bounds are shorter than the relevant handshake settling window and no longer
# than the smaller functional clock period (MIPI 9.660ns, HDMI 13.333ns).
# TD SWUG200 section 3.11: datapath_only removes unrelated clock phase/skew and
# automatically excludes only the hold check on these asynchronous crossings.
# Intra-domain logic, including every synchronizer second stage, stays timed.
set_max_delay -from [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] -to [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] -datapath_only 9.660
set_max_delay -from [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] -to [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] -datapath_only 9.660
set_max_delay -from [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] -to [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}] -datapath_only 9.660
set_max_delay -from [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}] -to [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] -datapath_only 9.660
set_max_delay -from [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] -to [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}] -datapath_only 9.660
set_max_delay -from [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}] -to [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] -datapath_only 9.660
