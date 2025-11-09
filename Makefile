# --------------------------------------------------------------------
# Toolchain (can be overridden externally)
# --------------------------------------------------------------------
CROSS_COMPILE ?= armr5-none-eabi-
CC      := $(CROSS_COMPILE)gcc
AS      := $(CROSS_COMPILE)gcc
LD      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
SIZE    := $(CROSS_COMPILE)size

# --------------------------------------------------------------------
# Paths
# --------------------------------------------------------------------
APP_DIR = application/app
LRU_DIR = application/bsp
BSP_DIR = r5_platform_bsp
LINKER  = linker/lscript.ld
BUILD_DIR = build

# --------------------------------------------------------------------
# Includes
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

# --------------------------------------------------------------------
# Defines
# --------------------------------------------------------------------
DEFINES = \
    -DARMR5 \
    -DPLATFORM_FC200 \
    -DADC_9 \
    -DNO_SYS=1 \
    -DLWIP_NOASSERT \
    -D_SYS__STDINT_H_

# --------------------------------------------------------------------
# Flags
# --------------------------------------------------------------------
CPU_FLAGS = -mcpu=cortex-r5 -mfpu=vfpv3-d16 -mfloat-abi=hard -marm

CFLAGS := -O0 -g -Wall -Wextra -ffreestanding $(CPU_FLAGS) \
          $(DEFINES) $(INCLUDES)

ASFLAGS := $(CPU_FLAGS) -g $(INCLUDES)

LDFLAGS := -T $(LINKER) -Wl,--gc-sections,-Map=$(BUILD_DIR)/app.map \
           -L$(BSP_DIR)/lib -llwip4 -lxil -lm $(CPU_FLAGS)

# --------------------------------------------------------------------
# Source discovery
# --------------------------------------------------------------------
# Find all .c files recursively under application/app/
APP_SRC     = $(shell find $(APP_DIR) -name "*.c")
DRIVER_SRC  = $(shell find $(LRU_DIR)/driver -name "*.c")
KERNEL_SRC  = $(shell find $(LRU_DIR)/kernel -name "*.c")
SOC_SRC     = $(shell find $(LRU_DIR)/soc -name "*.c" -o -name "*.s" -o -name "*.S")
SRU_SRC     = $(shell find $(LRU_DIR)/sru -name "*.c")
GCC_SRC     = $(shell find $(BSP_DIR)/gcc -name "*.c")

SRC = $(APP_SRC) $(DRIVER_SRC) $(KERNEL_SRC) $(SOC_SRC) $(SRU_SRC) $(GCC_SRC)

# Object files in build/ with same subpath as source
OBJ = $(patsubst %.c, $(BUILD_DIR)/%.o, $(SRC))
OBJ := $(patsubst %.s, $(BUILD_DIR)/%.o, $(OBJ))
OBJ := $(patsubst %.S, $(BUILD_DIR)/%.o, $(OBJ))

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

# Optional: Print source files and defines (for debugging)
.PHONY: print-sources print-defines
print-sources:
	@echo "Application sources:"
	@echo "$(APP_SRC)" | tr ' ' '\n'

print-defines:
	@echo "Defined symbols:"
	@echo "$(DEFINES)" | tr ' ' '\n'