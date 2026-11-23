# Compila e liga tarefa3-Grupo16.asm em $(BUILD_DIR).
#
# Uso: make [BUILD_DIR=dir]
#      make clean [BUILD_DIR=dir]

BUILD_DIR ?= build

OBJ := $(BUILD_DIR)/main.o
BIN := $(BUILD_DIR)/main

.PHONY: all run clean

all: $(BIN)

$(BIN): $(OBJ)
	ld $< -o $@

$(OBJ): tarefa3-Grupo16.asm | $(BUILD_DIR)
	nasm -f elf64 -g -F dwarf $< -o $@

$(BUILD_DIR):
	mkdir -p $@

run: $(BIN)
	@$(BIN)

# Remove só os artefatos, pois BUILD_DIR pode conter outros arquivos
clean:
	rm -f $(OBJ) $(BIN)
