
; Esqueleto NASM x86-64 Linux

global _start

section .data
    msg_entrada db "Digite o nome do arquivo de entrada: ", 0
    msg_saida   db "Digite o nome do arquivo de saída: ", 0

section .bss
    nome_entrada resb 256
    nome_saida   resb 256
    byte_arq     resb 1
    buffer_hex   resb 16
    descr_entrada resq 1
    descr_saida   resq 1
    code_point    resq 1

section .text


_start:
    ; TODO: solicitar e ler nome do arquivo de entrada
    ; TODO: solicitar e ler nome do arquivo de saída
    ; TODO: abrir arquivos usando abre_arquivo
    ; TODO: loop de leitura byte a byte
    ; TODO: determinar se a sequência UTF-8 possui 1, 2, 3 ou 4 bytes
    ; TODO: combinar bits para reconstruir o code point
    ; TODO: chamar gera_string_hexadecimal e grava_string_arquivo

    ; fechar os arquivos e encerrar com sys_exit
    push qword [descr_entrada]
    call fecha_arquivo                      ;chamada da função
    add rsp, 8                              ;coloca pilha livre 
    jmp fim_programa                        ;encerra programa

fim_programa:
; -------------------------------------------
; Syscall: sys_exit
    mov rax, 60                             ;sys_exit
    mov rdi, 0                              ;sucesso
    syscall
; -------------------------------------------

fecha_arquivo:
    push rbp                                ;empilha rbp anterior
    mov rbp, rsp                            ;setta o novo rbp
    push rdi                                ;empilha rdi anterior
; -------------------------------------------
; Syscall: sys_close
    mov rax, 3                              ;sys_close
    mov rdi, [rbp+16]                       ;rdi recebe o descritor
    syscall
; -------------------------------------------
    pop rdi                                 ;restaurar rdi
    pop rbp                                 ;restaurar rbp
    ret




