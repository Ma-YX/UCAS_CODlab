CROSS_PREFIX := mips-

CC := $(CROSS_PREFIX)gcc
CXX := $(CROSS_PREFIX)g++
AS := $(CROSS_PREFIX)as
LD := $(CROSS_PREFIX)ld
OBJDUMP := $(CROSS_PREFIX)objdump
OBJCOPY := $(CROSS_PREFIX)objcopy

EXPORT_CC_PATH := export PATH=$(MIPS_TOOLS_PATH):$$PATH

CFLAGS = -fno-pic -static -fno-strict-aliasing -fno-delayed-branch -fno-builtin -ffreestanding \
		-fno-stack-protector -mno-check-zero-division \
		-Wno-unused-function -Wall -Werror -mno-imadd -mno-mad -EL -mips32 -G0 -O0 -I ../include
CFLAGS += -DSETTING_TEST -DMICROBENCH
ASFLAGS := -EL
LDFLAGS := -EL -N -e start -T user.ld

ROOT := $(shell pwd)
OBJ_DIR := $(ROOT)/obj
BIN := $(ROOT)/bin
RAW := $(ROOT)/raw
SIM := $(ROOT)/sim
DISASSEMBLY := $(ROOT)/disassembly

BENCH_DIR := $(shell find src/ -type d)
BENCH := $(BENCH_DIR:src/%=%)
BENCH_O := $(BENCH:%=$(OBJ_DIR)/bench/%.o)
COMMON_C := $(shell find ../common/ -type f -name "*.c")
COMMON_S := $(shell find ../common/ -type f -name "*.S")
COMMON_O := $(patsubst %.S,%.o,$(COMMON_S)) $(patsubst %.c,%.o,$(COMMON_C))

DIR_OBJS := $(BIN) $(RAW) $(SIM) $(DISASSEMBLY)

TARGET := $(BENCH)
BINS := $(addprefix $(BIN)/,$(TARGET))

all: $(BINS)

define TARGET_TEMPLATE
$1_C_SRC = $$(shell find src/$1 -type f -name "*.c")
$1_CXX_SRC = $$(shell find src/$1 -type f -name "*.cpp")
$1_OBJS = $$($1_C_SRC:src/%.c=$$(OBJ_DIR)/%.o) $$($1_CXX_SRC:src/%.cpp=$$(OBJ_DIR)/%.o)

$$(BIN)/$1: $$(COMMON_O) $$(OBJ_DIR)/bench/$1.o $$($1_OBJS)
	@mkdir -p $$(DIR_OBJS)
	@$$(EXPORT_CC_PATH) && $$(LD) $$(LDFLAGS) -o $$@ $$^
	@$$(EXPORT_CC_PATH) && $$(OBJDUMP) -DS $$@ > $$(DISASSEMBLY)/$$(patsubst $$(BIN)/%,%,$$@).S
	@$$(EXPORT_CC_PATH) && $$(OBJCOPY) -S -O binary \
				-j .text -j .text.* -j .MIPS.abiflags \
				-j .data -j .rodata -j .rodata.str1.4 \
				-j .bss --set-section-flags .bss=alloc,contents \
				-j .sbss --set-section-flags .sbss=alloc,contents \
				-j .scommon --set-section-flags .scommon=alloc,contents \
				$$@ $$(RAW)/$$(patsubst $$(BIN)/%,%,$$@).raw
	@xxd -e -c 4 $$(RAW)/$$(patsubst $$(BIN)/%,%,$$@).raw | awk -F ":" '{print $$$$2}' | awk -F " " '{print $$$$1}' \
				> $$(SIM)/$$(patsubst $$(BIN)/%,%,$$@).txt
	@echo "memory_initialization_radix=16;" > $$(SIM)/$$(patsubst $$(BIN)/%,%,$$@).coe
	@echo "memory_initialization_vector=" >> $$(SIM)/$$(patsubst $$(BIN)/%,%,$$@).coe
	@cat $$(SIM)/$$(patsubst $$(BIN)/%,%,$$@).txt | awk '{print $$$$1","}' >> $$(SIM)/$$(patsubst $$(BIN)/%,%,$$@).coe
	@sed -i "$$$$ s/,/;/" $$(SIM)/$$(patsubst $$(BIN)/%,%,$$@).coe
endef

$(foreach bench,$(BENCH),$(eval $(call TARGET_TEMPLATE,$(bench))))

$(OBJ_DIR)/bench/%.o: src/bench.c
	@mkdir -p $(shell dirname $@)
	@$(EXPORT_CC_PATH) && $(CC) -c $(CFLAGS) -DBENCH_$(shell basename $@ .o) $^ -o $@

$(OBJ_DIR)/%.o: src/%.cpp
	@mkdir -p $(shell dirname $@)
	@$(EXPORT_CC_PATH) && $(CXX) -c $(CFLAGS) -O2 -o $@ $<

$(OBJ_DIR)/%.o: src/%.c
	@mkdir -p $(shell dirname $@)
	@$(EXPORT_CC_PATH) && $(CC) -c $(CFLAGS) -O2 -o $@ $<

../common/%.o: ../common/%.S
	@$(EXPORT_CC_PATH) && $(CC) -c $(CFLAGS) -o $@ $<

../common/%.o: ../common/%.c
	@$(EXPORT_CC_PATH) && $(CC) -c $(CFLAGS) -O2 -o $@ $<

clean:
	rm -rf $(DIR_OBJS) obj/ ../common/*.o
