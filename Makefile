# --------------------------------------------------------------------
# Toolchain (Xilinx Cortex-R5)
# --------------------------------------------------------------------
CROSS_COMPILE ?= arm-xilinx-eabi-
CC      := $(CROSS_COMPILE)gcc
AS      := $(CROSS_COMPILE)gcc
LD      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
SIZE    := $(CROSS_COMPILE)size

# --------------------------------------------------------------------
# Paths
# --------------------------------------------------------------------
APP_DIR   = application/app
LRU_DIR   = application/bsp
BSP_DIR   = r5_platform_bsp
LINKER    = linker/lscript.ld
BUILD_DIR = build

# --------------------------------------------------------------------
# Sysroot and standard include paths
# --------------------------------------------------------------------
TOOLCHAIN_ROOT := /opt/armr5/lin/gcc-arm-none-eabi
SYSROOT        := $(TOOLCHAIN_ROOT)/armrm-xilinx-eabi/usr
GCC_VER_PATH   := $(TOOLCHAIN_ROOT)/x86_64-oesdk-linux/usr/lib/arm-xilinx-eabi/gcc/arm-xilinx-eabi/9.2.0

# Multilib directory for hard-float ARM v7
MULTILIB_DIR := thumb/v7+fp/hard

# CRT files
CRT_DIR := $(SYSROOT)/lib/$(MULTILIB_DIR)
CRT0    := $(CRT_DIR)/crt0.o
CRTI    := $(CRT_DIR)/crti.o
CRTN    := $(CRT_DIR)/crtn.o
CRTBEGIN := $(CRT_DIR)/crtbegin.o
CRTEND   := $(CRT_DIR)/crtend.o

# --------------------------------------------------------------------
# Compilation flags
# --------------------------------------------------------------------
CFLAGS := -O0 -g3 -Wall -Wextra -ffreestanding \
          -mcpu=cortex-r5 -mfpu=vfpv3-d16 -mfloat-abi=hard \
          --sysroot=$(SYSROOT) \
          -I$(SYSROOT)/include \
          -I$(GCC_VER_PATH)/include \
          -I$(GCC_VER_PATH)/include-fixed

ASFLAGS := -mcpu=cortex-r5 -mfpu=vfpv3-d16 -mfloat-abi=hard -g

LDFLAGS := -T $(LINKER) \
           -Wl,--gc-sections,-Map=$(BUILD_DIR)/app.map \
           --sysroot=$(SYSROOT) \
           -L$(BSP_DIR)/lib \
           -L$(CRT_DIR) \
           $(CRTI) \
           $(CRTBEGIN) \
           -nostartfiles \
           -Wl,--start-group \
           -llwip4 -lxil -lm -lc -lgcc -lnosys \
           -Wl,--end-group \
           $(CRTEND) \
           $(CRTN) \
           -mcpu=cortex-r5 -mfpu=vfpv3-d16 -mfloat-abi=hard

# --------------------------------------------------------------------
# Includes (project-specific)
# --------------------------------------------------------------------
INCLUDES = \
    -I$(BSP_DIR)/include \
    -I$(APP_DIR) \
    -I$(APP_DIR)/ach \
    -I$(APP_DIR)/bsp_srv \
    -I$(APP_DIR)/bsp_srv/can \
    -I$(APP_DIR)/bsp_srv/gpio \
    -I$(APP_DIR)/bsp_srv/interface \
    -I$(APP_DIR)/bsp_srv/pwm \
    -I$(APP_DIR)/bsp_srv/sys_srv \
    -I$(APP_DIR)/bsp_srv/timer \
    -I$(APP_DIR)/bsp_srv/uart \
    -I$(APP_DIR)/bsp_srv/udp \
    -I$(APP_DIR)/config \
    -I$(APP_DIR)/da \
    -I$(APP_DIR)/fcs_mi \
    -I$(APP_DIR)/fcs_mi/fcs_autogen \
    -I$(APP_DIR)/mavlink_io \
    -I$(APP_DIR)/mavlink_io/mavlink/include \
    -I$(APP_DIR)/mavlink_io/serdes \
    -I$(APP_DIR)/types \
    -I$(APP_DIR)/utils \
    -I$(LRU_DIR) \
    -I$(LRU_DIR)/driver \
    -I$(LRU_DIR)/kernel \
    -I$(LRU_DIR)/soc \
    -I$(LRU_DIR)/sru

CFLAGS += $(INCLUDES)

# --------------------------------------------------------------------
# Defines
# --------------------------------------------------------------------
DEFINES = \
    -DARMR5 \
    -DPLATFORM_FC200 \
    -DADC_9 \
    -D_SYS__STDINT_H_

CFLAGS += $(DEFINES)

# --------------------------------------------------------------------
# Source discovery
# --------------------------------------------------------------------
APP_SRC     = $(shell find $(APP_DIR) -name "*.c")
DRIVER_SRC  = $(shell find $(LRU_DIR)/driver -name "*.c")
KERNEL_SRC  = $(shell find $(LRU_DIR)/kernel -name "*.c")
SOC_SRC     = $(shell find $(LRU_DIR)/soc -name "*.c" -o -name "*.s" -o -name "*.S")
SRU_SRC     = $(shell find $(LRU_DIR)/sru -name "*.c")
GCC_SRC     = $(shell find $(BSP_DIR)/gcc -name "*.c")

SRC = $(APP_SRC) $(DRIVER_SRC) $(KERNEL_SRC) $(SOC_SRC) $(SRU_SRC) $(GCC_SRC)

OBJ = $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRC))
OBJ := $(patsubst %.s,$(BUILD_DIR)/%.o,$(OBJ))
OBJ := $(patsubst %.S,$(BUILD_DIR)/%.o,$(OBJ))

TARGET = $(BUILD_DIR)/fcc_ofp.elf
BIN    = $(BUILD_DIR)/fcc_ofp.bin
HEX    = $(BUILD_DIR)/fcc_ofp.hex

# --------------------------------------------------------------------
# Rules
# --------------------------------------------------------------------
all: $(TARGET) $(BIN) $(HEX)
	@echo "✅ Build complete."
	@$(SIZE) $(TARGET)

# Link
$(TARGET): $(OBJ)
	@echo "🔗 Linking $@"
	$(LD) $(OBJ) $(LDFLAGS) -o $@

# Compile C
$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	@echo "🧩 CC $<"
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

# Assemble .s / .S
$(BUILD_DIR)/%.o: %.s
	@mkdir -p $(dir $@)
	@echo "🧩 AS $<"
	$(AS) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.S
	@mkdir -p $(dir $@)
	@echo "🧩 AS $<"
	$(AS) $(ASFLAGS) -c $< -o $@

# Binary / Hex
$(BIN): $(TARGET)
	@$(OBJCOPY) -O binary $< $@
	@echo "💾 Created $@"

$(HEX): $(TARGET)
	@$(OBJCOPY) -O ihex $< $@
	@echo "💾 Created $@"

# Clean
clean:
	@echo "🧹 Cleaning..."
	rm -rf $(BUILD_DIR)

# Include dependency files if they exist
-include $(OBJ:.o=.d)

.PHONY: all clean print-sources print-defines print-paths verify-crt
print-sources:
	@echo "Application sources:"
	@echo "$(APP_SRC)" | tr ' ' '\n'

print-defines:
	@echo "Defined symbols:"
	@echo "$(DEFINES)" | tr ' ' '\n'

print-paths:
	@echo "Toolchain root: $(TOOLCHAIN_ROOT)"
	@echo "Sysroot: $(SYSROOT)"
	@echo "GCC version path: $(GCC_VER_PATH)"
	@echo "Multilib directory: $(MULTILIB_DIR)"
	@echo "Library path: $(CRT_DIR)"

verify-crt:
	@echo "Verifying CRT files..."
	@ls -la $(CRTI) $(CRTN) $(CRTBEGIN) $(CRTEND) 2>/dev/null || echo "⚠️  CRT files not found!"