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
