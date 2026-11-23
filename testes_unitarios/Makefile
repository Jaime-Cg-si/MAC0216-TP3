# Compila e roda os testes unitários das funções de tarefa3-Grupo16.asm.
#
# Uso: make -C testes_unitarios [BUILD_DIR=dir]
#      make -C testes_unitarios clean [BUILD_DIR=dir]

BUILD_DIR ?= ../build/unit

OBJ := $(BUILD_DIR)/ponte.o
BIN := $(BUILD_DIR)/testes

.PHONY: test clean

test: $(BIN)
	@$(BIN)

# -no-pie: tarefa3-Grupo16.asm usa endereços absolutos, como em push qword msg_entrada
$(BIN): testes.c $(OBJ)
	gcc -g -no-pie -Wall -Wextra testes.c $(OBJ) -o $@

$(OBJ): ponte.asm ../tarefa3-Grupo16.asm | $(BUILD_DIR)
	nasm -f elf64 -g -F dwarf -I../ ponte.asm -o $@

$(BUILD_DIR):
	mkdir -p $@

# Remove só os artefatos, pois BUILD_DIR pode conter outros arquivos
clean:
	rm -f $(OBJ) $(BIN)
