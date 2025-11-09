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
    -I$(LRU_DIR) \
    -I$(LRU_DIR)/driver \
    -I$(LRU_DIR)/kernel \
    -I$(LRU_DIR)/soc \
    -I$(LRU_DIR)/sru

# --------------------------------------------------------------------
# Flags
# --------------------------------------------------------------------
CPU_FLAGS = -mcpu=cortex-r5 -mfpu=vfpv3-d16 -mfloat-abi=hard -marm

CFLAGS := -O0 -g -Wall -Wextra -ffreestanding $(CPU_FLAGS) -DARMv5 \
          -DNO_SYS=1 -DLWIP_NOASSERT $(INCLUDES)

ASFLAGS := $(CPU_FLAGS) -g $(INCLUDES)

LDFLAGS := -T $(LINKER) -Wl,--gc-sections,-Map=$(BUILD_DIR)/app.map \
           -L$(BSP_DIR)/lib -lxil -llwip4 $(CPU_FLAGS)

# --------------------------------------------------------------------
# Source discovery
# --------------------------------------------------------------------
APP_SRC     = $(wildcard $(APP_DIR)/*.c)
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

TARGET = $(BUILD_DIR)/app.elf
BIN    = $(BUILD_DIR)/app.bin
HEX    = $(BUILD_DIR)/app.hex

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
