CROSS_PREFIX := riscv32-unknown-elf-

CC := $(CROSS_PREFIX)gcc
AS := $(CROSS_PREFIX)as
LD := $(CROSS_PREFIX)ld
OBJDUMP := $(CROSS_PREFIX)objdump
OBJCOPY := $(CROSS_PREFIX)objcopy

EXPORT_CC_PATH := export PATH=$(RV_TOOLS_PATH):$$PATH

CFLAGS = -fno-pic -static -fno-strict-aliasing -fno-delayed-branch -fno-builtin -ffreestanding \
		-fno-stack-protector -Wno-unused-function \
		-Wall -Werror -O0 -I ../include
ASFLAGS := -EL
LDFLAGS := -EL -N -e start -T user.ld

ROOT := $(shell pwd)
OBJ_DIR := $(ROOT)/obj
BIN := $(ROOT)/bin
RAW := $(ROOT)/raw
SIM := $(ROOT)/sim
DISASSEMBLY := $(ROOT)/disassembly

DIR_OBJS := $(BIN) $(RAW) $(SIM) $(DISASSEMBLY)

TARGET := $(patsubst src/%.c,%,$(wildcard src/*.c))
BINS := $(addprefix $(BIN)/,$(TARGET))

.PHONY: FORCE

all: $(BINS)
	@rm -rf $(OBJ_DIR)

$(BIN)/%: ../common/start.o ../common/printf.o $(OBJ_DIR)/%.o
	@mkdir -p $(DIR_OBJS)
	@$(EXPORT_CC_PATH) && $(LD) $(LDFLAGS) -o $@ $^
	@$(EXPORT_CC_PATH) && $(OBJDUMP) -DS $@ > $(DISASSEMBLY)/$(patsubst $(BIN)/%,%,$@).S
	@$(EXPORT_CC_PATH) && $(OBJCOPY) -S -O binary \
				-j .text -j .text.startup -j .sdata \
				-j .data -j .rodata -j .rodata.str1.4 \
				-j .bss --set-section-flags .bss=alloc,contents \
				-j .sbss --set-section-flags .sbss=alloc,contents \
				-j .scommon --set-section-flags .scommon=alloc,contents \
				$@ $(RAW)/$(patsubst $(BIN)/%,%,$@).raw
	@xxd -e -c 4 $(RAW)/$(patsubst $(BIN)/%,%,$@).raw | awk -F ":" '{print $$2}' | awk -F " " '{print $$1}' \
				> $(SIM)/$(patsubst $(BIN)/%,%,$@).txt
	@echo "memory_initialization_radix=16;" > $(SIM)/$(patsubst $(BIN)/%,%,$@).coe
	@echo "memory_initialization_vector=" >> $(SIM)/$(patsubst $(BIN)/%,%,$@).coe
	@cat $(SIM)/$(patsubst $(BIN)/%,%,$@).txt | awk '{print $$1","}' >> $(SIM)/$(patsubst $(BIN)/%,%,$@).coe
	@sed -i "$$ s/,/;/" $(SIM)/$(patsubst $(BIN)/%,%,$@).coe

$(OBJ_DIR)/%.o: src/%.c
	@mkdir -p $(OBJ_DIR)
	@$(EXPORT_CC_PATH) && $(CC) -c $(CFLAGS) -O2 -o $@ $<

../common/start.o: ../common/start.S FORCE
	@$(EXPORT_CC_PATH) && $(CC) -c $(CFLAGS) -o $@ $<

../common/printf.o: ../common/printf.c
	@$(EXPORT_CC_PATH) && $(CC) -c $(CFLAGS) -O2 -o $@ $<

clean:
	rm -rf $(DIR_OBJS) ../common/*.o
