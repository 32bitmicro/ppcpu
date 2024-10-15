# Makefile for synthesizing the ppcpu design using Yosys
# Paweł Wodnicki (c) 2024

# Include directories
INCLUDE_DIRS = rtl  soc

# List of Verilog source files
SRCS = \
	rtl/config.v \
	rtl/top.v \
	rtl/core/alu.v \
	rtl/core/alu_mul_div.v \
	rtl/core/core.v \
	rtl/core/decode.v \
	rtl/core/execute.v \
	rtl/core/fetch.v \
	rtl/core/memwb.v \
	rtl/core/pc.v \
	rtl/core/rf.v \
	\
	rtl/dcache/dcache_ram.v\
	rtl/dcache/dcache.v\
	\
	rtl/embed/gpio.v \
	rtl/embed/int_ram.v \
	rtl/embed/sspi.v \
	rtl/icache/icache_ram.v \
	rtl/icache/icache.v \
	\
	rtl/interconnect/interconnect_inner.v \
	rtl/interconnect/interconnect_outer.v \
	rtl/interconnect/inner/dmmu.v \
	rtl/interconnect/inner/immu.v \
	rtl/interconnect/inner/intercore_sregs.v \
	rtl/interconnect/inner/mem_dcache_arb.v \
	rtl/interconnect/inner/wishbone_arbiter.v \
	rtl/interconnect/outer/clk_div.v \
	rtl/interconnect/outer/ff_mb_sync.v \
	rtl/interconnect/outer/reset_sync.v \
	rtl/interconnect/outer/wb_compressor.v \
	rtl/interconnect/outer/wb_cross_clk.v \
	rtl/interconnect/outer/wb_decomp.v \
	\
	soc/i2c.v \
	soc/irq_ctrl.v \
	soc/ps2.v \
	soc/sdram.v \
	soc/serialout.v \
	soc/soc_rom.v \
	soc/fpga.v \
	soc/spi.v \
	soc/timer.v \
	soc/uart2.v \
	soc/uart.v \
	soc/vga.v	




# Top module
TOP = fpga

# Output files
SYNTH_OUT = $(TOP)_synth.v
REPORT = yosys_report.txt

# Output files
SYNTH_JSON = $(TOP).json
ASC_FILE = $(TOP).asc
BIN_FILE = $(TOP).bin
REPORT = yosys_report.txt

# FPGA constraints
#BOARD=nandland
BOARD=alchitry-cu

# Configure build 
include fpga/$(BOARD).mk
# FPGA
# PACKAGE
PCF_FILE = fpga/$(BOARD).pcf

# Default target
all: $(BIN_FILE)

# Synthesis step using Yosys
$(SYNTH_JSON): $(SRCS)
	yosys -p "\
		read_verilog -sv $(addprefix -I ,$(INCLUDE_DIRS)) $(SRCS); \
		synth_ice40 -top $(TOP) -json $(SYNTH_JSON);" \
		> $(REPORT)

# Place and Route using NextPNR
$(ASC_FILE): $(SYNTH_JSON) $(PCF_FILE)
	nextpnr-ice40 --$(FPGA) --package $(PACKAGE) --json $(SYNTH_JSON) --pcf $(PCF_FILE) --asc $(ASC_FILE) --pcf-allow-unconstrained

# Generate Bitstream using IcePack
$(BIN_FILE): $(ASC_FILE)
	icepack $(ASC_FILE) $(BIN_FILE)

# Clean target
clean:
	rm -f $(SYNTH_JSON) $(ASC_FILE) $(BIN_FILE) $(REPORT
# Default target

all: synth
    
# Synthesis target
synth: $(SYNTH_OUT)

$(SYNTH_OUT): $(SRCS)
	yosys -p "\
		read_verilog -sv $(addprefix -I ,$(INCLUDE_DIRS)) $(SRCS); \
		synth -top $(TOP); \
		stat -top $(TOP); \
		write_verilog -noattr $(SYNTH_OUT)" \
		> $(REPORT)

# Clean target
clean:
	rm -f $(SYNTH_OUT) $(REPORT)

.PHONY: all synth clean

