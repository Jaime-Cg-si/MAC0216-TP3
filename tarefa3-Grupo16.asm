
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
    ;solicitar e ler nome do arquivo de entrada

    ;exibindo mensagem de entrada
    push qword msg_entrada                  ;empilha mensagem de entrada
    call escreve_string                     ;chamada função escreve_string(char* mensagem)
    add rsp, 8                              ;coloca pilha livre

    ;TODO: receber arquivo de entrada

    ;solicitar e ler nome do arquivo de saída

    ;exibindo mensagem de arquivo saída
    push qword msg_saida                    ;empilha a mensagem de saída
    call escreve_string                     ;chamada função
    add rsp, 8                              ;coloca pilha livre

    ;TODO: receber arquivo de saída


    ; abrir arquivos usando abre_arquivo

    ;Abrindo arquivo de entrada
    push qword 0                            ;modo de abertura - leitura
    push qword nome_entrada                 ;endereço de onde começa string
    call abre_arquivo                       ;chamada função
    mov [descr_entrada], rax                ;copia descritor entrada
    add rsp, 16                             ;coloca pilha livre

    ;Abrindo arquivo de saída
    push qword 577                          ;modo abertura - escrita, criação truncamento
    push qword nome_saida                   ;endereço de onde começa o nome do arquivo de saída
    call abre_arquivo                       ;chamada função
    mov [descr_saida], rax                  ;copia descritor saída
    add rsp, 16                             ;coloca pilha livre

    ; TODO: loop de leitura byte a byte
    .laco_leitura:

        push qword byte_arq                     ;carregando byte a ser lido (atualizado pela própria sys_read)
        push qword [descr_entrada]              ;carregando o descritor do arquivo a ser lido
        call le_byte_arquivo                    ;chamada função
        add rsp, 16                             ;coloca pilha livre

        ;entrando no loop. Enquanto o byte lido for 1
        cmp rax, 0                              ;compara o retorno da leitura com 0 (fim do arquivo)
        jle .fim_arquivo                        ;arquivo de leitura acabou (ou deu erro na leitura)
        movzx rbx, byte [byte_arq]              ;salva o byte lido em rbx, zerando as demais posições

        ; TODO: determinar se a sequência UTF-8 possui 1, 2, 3 ou 4 bytes
        ; TODO: combinar bits para reconstruir o code point


        ;chamar gera_string_hexadecimal e grava_string_arquivo

        ;chamando gera_string_hexadecimal
        push qword buffer_hex                   ;carregando buffer para escrita do código
        push qword rbx                          ;carregando codepoint, assumindo que está em RBX
        call gera_string_hexadecimal            ;chamada função
        add rsp, 16                             ;coloca pilha livre


        jmp .laco_leitura

    .fim_arquivo:
        ; fechar os arquivos e encerrar com sys_exit
        ;fecha o arquivo de entrada
        push qword [descr_entrada]
        call fecha_arquivo                      ;chamada da função
        add rsp, 8                              ;coloca pilha livre 

        ;fecha o arquivo de saída
        push qword [descr_saida]
        call fecha_arquivo
        add rsp, 8
        jmp fim_programa                        ;encerra programa
    
;;
fim_programa:
; -------------------------------------------
; Syscall: sys_exit
    mov rax, 60                             ;sys_exit
    mov rdi, 0                              ;sucesso
    syscall
; -------------------------------------------
;
;
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
;
;
abre_arquivo:

    push rbp                               ;salva rbp antigo
    mov rbp, rsp                           ;setta novo rbp
    push rdi                               ;salva rdi antigo
    push rsi                               ;salva rsi antigo
    push rdx                               ;salva rdx antigo
; -------------------------------------------
; Syscall: sys_open
    mov rax, 2                             ;sys_open
    mov rdi, [rbp+16]                      ;endereço do começo do nome do arquivo
    mov rsi, [rbp+24]                      ;modo de abertura
    mov rdx, 438                           ;permissões do enunciado
    syscall
; -------------------------------------------
    ;RAX agora contém o descritor do arquivo
    pop rdx                                ;restaura rdx
    pop rsi                                ;restaura rsi
    pop rdi                                ;restaura rdi
    pop rbp                                ;restaura rbp
    ret
;
;
le_byte_arquivo:
    push rbp                               ;rbp antigo
    mov rbp, rsp                           ;setta novo rbp
    push rdi                               ;rdi antigo
    push rsi                               ;rsi antigo
    push rdx                               ;rdx antigo
; -------------------------------------------
; Syscall: sys_read
    mov rax, 0                            ;sys_read
    mov rdi, [rbp+16]                      ;carrega descritor em rdi
    mov rsi, [rbp+24]                      ;carrega byte_arq em rsi
    mov rdx, 1                             ;lê 1 byte
    syscall
; -------------------------------------------
    pop rdx                                ;restaura rdx
    pop rsi                                ;restaura rsi
    pop rdi                                ;restaura rdi
    pop rbp                                ;restaura rbp
    ret                                    ;retorno
;
;
escreve_string:
    push rbp                               ;rbp antigo
    mov rbp, rsp                           ;setta novo rbp
    push rdi                               ;rdi antigo
    push rsi                               ;rsi antigo
    push rdx                               ;rdx antigo
    push rbx                               ;rbx antigo -> contador
    push rcx                               ;rcx antigo -> i

    ;preparação para o loop
    mov rsi, [rbp+16]                      ;apontar rsi começo da mensagem
    mov rbx, 0                             ;zerar contador
    mov rcx, 0                             ;zerar i

    ;loop descobrir tamanho mensagem
.laco:
    cmp byte [rsi+rcx], 0                       ;verifica string acabou
    je .fim                                ;encerrar laço e imprimir
    inc rbx                                ;contabiliza caracter
    inc rcx                                ;avança próximo caracter
    jmp .laco                              ;reinicia laço

.fim:
; -------------------------------------------
; Syscall: sys_write
    mov rax, 1                             ;sys_write
    mov rdi, 1                             ;stdout
    mov rsi, [rbp+16]                      ;começo mensagem
    mov rdx, rbx                           ;tamanho calculado
    syscall
; -------------------------------------------
    pop rcx                                ;restaura rcx
    pop rbx                                ;restaura rbx
    pop rdx                                ;restaura rdx
    pop rsi                                ;restaura rsi
    pop rdi                                ;restaura rdi
    pop rbp                                ;restaura rbp
    ret                                    ;retorno
;
;
; grava_string_arquivo(int descritor_arquivo, char* buffer)
grava_string_arquivo:
    push rbp                               ;rbp antigo
    mov rbp, rsp                           ;setta novo rbp
    push rdi                               ;rdi antigo
    push rsi                               ;rsi antigo
    push rdx                               ;rdx antigo
    push rbx                               ;rbx antigo -> contador
    push rcx                               ;rcx antigo -> i

    ;preparação laço
    mov rsi, [rbp+24]                      ;rsi aponta começo mensagem
    mov rbx, 0                             ;zera contador
    mov rcx, 0                             ;zera apontador

.laco:

    cmp byte [rsi + rcx], 0                ;verifica fim string
    je .fim                                ;encerra loop
    inc rbx                                ;contabiliza caracter
    inc rcx                                ;incrementa apontador
    jmp .laco                              ;fecha laço

.fim:
; -------------------------------------------
; Syscall: sys_write
    mov rax, 1                             ;sys_write
    mov rdi, [rbp+ 16]                     ;descritor arquivo
    mov rsi, [rbp+24]                      ;começo mensagem
    mov rdx, rbx                           ;tamanho mensagem
    syscall
; -------------------------------------------
    pop rcx                                ;restaura rcx
    pop rbx                                ;restaura rbx
    pop rdx                                ;restaura rdx
    pop rsi                                ;restaura rsi
    pop rdi                                ;restaura rdi
    pop rbp                                ;restaura rbp
    ret                                    ;retorno
;
;
;gera_string_hexadecimal(int valor, char* buffer)
gera_string_hexadecimal:
    push rbp                               ;rbp antigo
    mov rbp, rsp                           ;novo rbp
    push rax                               ;rax antigo
    push rbx                               ;rbx antigo
    push rcx                               ;rcx antigo
    push rdx                               ;rdx antigo
    push r8                                ;r8 antigo
    push r9                                ;r9 antigo

    ;1. Determinar o valor hex
    mov rax, [rbp+16]                      ;carrega dividendo
    mov rbx, 16                            ;carrega divisor
    mov r8, 0                              ;contador elementos empilhados

.laco_divisao:
    mov rdx, 0                             ;zerar resto
    div rbx                                ;RDX tem o resto e RAX o quociente
    push rdx                               ;empilha resto, para desempilhar na ordem certa
    inc r8                                 ;aumenta contador elementos empilhados
    cmp rax, 0                             ;quociente zerou
    jne .laco_divisao                      ;reinicia caso ainda tenha código

    ;2. Inclusão do '0x'
    mov rcx, [rbp+24]                      ;carrega início buffer
    mov r9, 0                              ;indicador posição livre p/ escrita
    mov byte [rcx + r9], '0'                    ;começa o '0x', colocando apenas 0
    inc r9                                 ;próxima posição livre
    mov byte [rcx+r9], 'x'                      ;agora sim '0x'
    inc r9                                 ;próxima posição livre

    ;3. Tradução de todos os códigos para caracteres
.traduz:
    cmp r8, 0                              ;verifica se acabaram os elementos empilhados
    jle .pronto                            ;termina de carregar o buffer
    dec r8                                 ;contabiliza o caracter
    pop rdx                                ;carrega em rdx o caracter
    cmp rdx, 9                             ;verifica se é um dígito (0-9) ou caracter (A-F)
    jg .letra                              ;letra
    add rdx, '0'                           ;transforma o dígito em caracter
    mov byte [rcx+r9], dl                  ;carrega caracter no buffer
    inc r9                                 ;próxima posição livre
    jmp .traduz                            ;reinicia laço

.letra:
    add rdx, 'A' - 10                      ;converte letra para caracter
    mov byte [rcx+r9], dl                  ;carrega caracter no buffer
    inc r9                                 ;próxima posição livre
    jmp .traduz                            ;reinicia laço

.pronto:
    mov byte [rcx+r9], 10                  ;adiciona o Line Feed
    inc r9                                 ;próxima posição livre
    mov byte [rcx+r9], 0                   ;adiciona NUL
    ;restauro dos registradores
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ;retorno
    ret

