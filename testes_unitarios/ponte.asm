; Expõe as funções de tarefa3-Grupo16.asm aos testes em C, sem alterar o programa.

; renomeia o _start para que o C forneça o ponto de entrada
%define _start programa_principal

    global le_string, escreve_string, abre_arquivo, fecha_arquivo, le_byte_arquivo
    global grava_string_arquivo, gera_string_hexadecimal, decodifica_utf8, mesmo_arquivo
    global encerra_com_erro, chama2, registrador_alterado

%include "tarefa3-Grupo16.asm"

SENTINELA equ 0x6969696969696969

; marca a falha se o registrador não tiver mais o valor sentinela
%macro confere 1
    cmp %1, r12
    je  %%ok
    mov byte [registrador_alterado], 1
%%ok:
%endmacro

section .bss

registrador_alterado resb 1

section .text

; long chama2(void* f, long a, long b)
; adapta a System V à convenção por pilha e confere os registradores preservados.
; rax também entra com a sentinela, para testar as funções sem retorno.
chama2:
    push    rbx
    push    r12
    push    r13
    mov     r13, rdi
    push    rdx
    push    rsi
    mov     r12, SENTINELA
    mov     rax, r12
    mov     rbx, r12
    mov     rcx, r12
    mov     rdx, r12
    mov     rsi, r12
    mov     rdi, r12
    mov     r8, r12
    mov     r9, r12
    mov     r10, r12
    mov     r11, r12
    call    r13
    confere rbx
    confere rcx
    confere rdx
    confere rsi
    confere rdi
    confere r8
    confere r9
    confere r10
    confere r11
    add     rsp, 16
    pop     r13
    pop     r12
    pop     rbx
    ret

; informa ao ligador que a pilha não precisa ser executável, pois o NASM não gera esta nota
    section .note.GNU-stack noalloc noexec nowrite progbits
