# --- Configuration ---
PYTHON        := python3
AS            := cl65
EMULATOR      := /Applications/CommanderX16/x16emu

STRIP_HEIGHT  ?= 16
LOCAL_COLORS  ?= 128

PROJECT_NAME  := demodata
SRC_DIR       := src
SRC_FILES     := $(wildcard $(SRC_DIR)/*.s)

INC_DIRS      := src/inc

BUILD_DIR     := build
DATA_DIR      := data
ASSETS_DIR    := assets
TOOLS_DIR     := tools

# --- Input and output files ---
RAW_IMAGE     := $(ASSETS_DIR)/images/input.png
PYTHON_SCRIPT := $(TOOLS_DIR)/converter.py
GENERATED_S   := $(DATA_DIR)/$(PROJECT_NAME)_palettes.s $(DATA_DIR)/$(PROJECT_NAME)_pixels.s
FINAL_PRG     := $(BUILD_DIR)/$(PROJECT_NAME).prg

# --- Compiler flags ---
AS_FLAGS      := -t cx16 -u __EXEHDR__ --mapfile $(BUILD_DIR)/map.txt

.PHONY: all assets run clean

# ==============================================================================
# TARGETS
# ==============================================================================

all: $(FINAL_PRG)

run: all
	$(EMULATOR) -scale 2 -prg $(FINAL_PRG) -run -debug

assets: $(GENERATED_S)

clean:
	@echo "Cleaning up folders build/ and data/..."
	rm -rf $(BUILD_DIR) $(DATA_DIR)

# ==============================================================================
# BUILD RULES
# ==============================================================================

$(FINAL_PRG): $(SRC_FILES) $(GENERATED_S)
	@echo "Compiling and linking the project..."
	@mkdir -p $(BUILD_DIR)
	$(AS) $(AS_FLAGS) -o $@ $(SRC_FILES)

$(GENERATED_S): $(RAW_IMAGE) $(PYTHON_SCRIPT)
	@echo "Generating resources from the image (strip height: $(STRIP_HEIGHT)px, local colors: $(LOCAL_COLORS))..."
	@mkdir -p $(DATA_DIR)
	$(PYTHON) $(PYTHON_SCRIPT) $(RAW_IMAGE) $(DATA_DIR)/$(PROJECT_NAME) --strip-height $(STRIP_HEIGHT) --local-colors $(LOCAL_COLORS)