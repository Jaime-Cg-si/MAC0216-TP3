; elimina o aviso de DEFAULT ABS implícito do NASM 3
default rel

global _start

TAM_NOME equ 256 ; tamanho dos buffers de nome, contando o NUL

section .data

msg_entrada db "Digite o nome do arquivo de entrada: ", 0
msg_saida   db "Digite o nome do arquivo de saída: ", 0

msg_erro_nome    db "Erro: nome de arquivo muito longo.", 10, 0
msg_erro_entrada db "Erro: não foi possível abrir o arquivo de entrada.", 10, 0
msg_erro_saida   db "Erro: não foi possível abrir o arquivo de saída.", 10, 0
msg_erro_mesmo   db "Erro: entrada e saída são o mesmo arquivo.", 10, 0
msg_erro_leitura db "Erro: falha ao ler o arquivo de entrada.", 10, 0
msg_erro_escrita db "Erro: falha ao gravar o arquivo de saída.", 10, 0

section .bss

nome_entrada  resb TAM_NOME
nome_saida    resb TAM_NOME
byte_arq      resb 1
buffer_hex    resb 20 ; "0x" + 16 dígitos + LF + NUL
descr_entrada resq 1
descr_saida   resq 1
code_point    resq 1

section .text

_start:
; solicita e lê nome do arquivo de entrada

; exibe mensagem de entrada
    push qword msg_entrada             ; empilha mensagem de entrada
    call escreve_string                ; chama função escreve_string(char* mensagem)
    add  rsp, 8                        ; coloca pilha livre

; recebe nome do arquivo de entrada
    push qword TAM_NOME                ; tamanho máximo, contando o NUL
    push qword nome_entrada            ; buffer do nome
    call le_string                     ; chama função
    add  rsp, 16                       ; coloca pilha livre
    cmp  rax, TAM_NOME - 1             ; buffer cheio: o nome pode ter sido cortado
    jae  .erro_nome                    ; não abre um arquivo com nome errado

; solicita e lê nome do arquivo de saída

; exibe mensagem de arquivo saída
    push qword msg_saida               ; empilha a mensagem de saída
    call escreve_string                ; chama função
    add  rsp, 8                        ; coloca pilha livre

; recebe nome do arquivo de saída
    push qword TAM_NOME                ; tamanho máximo, contando o NUL
    push qword nome_saida              ; buffer do nome
    call le_string                     ; chama função
    add  rsp, 16                       ; coloca pilha livre
    cmp  rax, TAM_NOME - 1             ; buffer cheio: o nome pode ter sido cortado
    jae  .erro_nome                    ; não cria um arquivo com nome errado

; abre arquivos usando abre_arquivo

; abre arquivo de entrada
    push qword 0                       ; modo de abertura - leitura
    push qword nome_entrada            ; endereço de onde começa string
    call abre_arquivo                  ; chama função
    mov  [descr_entrada], rax          ; copia descritor entrada
    add  rsp, 16                       ; coloca pilha livre
    cmp  rax, 0                        ; descritor negativo indica erro
    jl   .erro_abre_entrada            ; encerra antes de tocar na saída

; impede que a abertura com truncamento apague o arquivo de entrada
    push qword nome_saida              ; nome do arquivo de saída
    push qword [descr_entrada]         ; descritor do arquivo de entrada
    call mesmo_arquivo                 ; chama função
    add  rsp, 16                       ; coloca pilha livre
    cmp  rax, 0                        ; 0 indica arquivos diferentes
    jne  .erro_mesmo_arquivo           ; encerra sem truncar

; abre arquivo de saída
    push qword 577                     ; modo abertura - escrita, criação truncamento
    push qword nome_saida              ; endereço de onde começa o nome do arquivo de saída
    call abre_arquivo                  ; chama função
    mov  [descr_saida], rax            ; copia descritor saída
    add  rsp, 16                       ; coloca pilha livre
    cmp  rax, 0                        ; descritor negativo indica erro
    jl   .erro_abre_saida              ; encerra informando a falha

; loop de leitura: cada iteração processa um caractere UTF-8
.laco_leitura:
    push qword byte_arq                ; carrega byte a ser lido (atualizado pela própria sys_read)
    push qword [descr_entrada]         ; carrega o descritor do arquivo a ser lido
    call le_byte_arquivo               ; chama função
    add  rsp, 16                       ; coloca pilha livre

; entra no loop enquanto o byte lido for 1
    cmp   rax, 0                       ; compara o retorno da leitura com 0 (fim do arquivo)
    je    .fim_arquivo                 ; encerra o laço no fim do arquivo
    jl    .erro_leitura                ; retorno negativo indica erro
    movzx rbx, byte [byte_arq]         ; salva o byte lido em rbx, zerando as demais posições

; identifica o tamanho da sequência e reconstrói o code point
    push qword rbx                     ; byte inicial da sequência
    push qword [descr_entrada]         ; descritor do arquivo de entrada
    call decodifica_utf8               ; chama função
    add  rsp, 16                       ; coloca pilha livre
    cmp  rax, 0                        ; verifica erro na leitura da continuação
    jl   .erro_leitura                 ; encerra informando a falha
    mov  rbx, rax                      ; code point em rbx

; chama gera_string_hexadecimal e grava_string_arquivo

; chama gera_string_hexadecimal
    push qword buffer_hex              ; carrega buffer para escrita do código
    push qword rbx                     ; carrega codepoint, assumindo que está em rbx
    call gera_string_hexadecimal       ; chama função
    add  rsp, 16                       ; coloca pilha livre

; chama grava_string_arquivo
    push qword buffer_hex              ; carrega buffer para escrita no arquivo
    push qword [descr_saida]           ; descritor arquivo saída
    call grava_string_arquivo          ; chama função
    add  rsp, 16                       ; coloca pilha livre
    cmp  rax, 0                        ; retorno negativo indica erro
    jl   .erro_escrita                 ; encerra informando a falha

    jmp .laco_leitura

.fim_arquivo:
; fecha os arquivos e encerra com sys_exit
; fecha o arquivo de entrada
    push qword [descr_entrada]
    call fecha_arquivo                 ; chama a função
    add  rsp, 8                        ; coloca pilha livre

; fecha o arquivo de saída
    push qword [descr_saida]
    call fecha_arquivo
    add  rsp, 8
    cmp  rax, 0                        ; o fechamento pode revelar falha de gravação
    jge  fim_programa                  ; encerra programa com sucesso
    push qword msg_erro_escrita        ; mensagem de erro
    call encerra_com_erro              ; não retorna

; trata erros
.erro_nome:
    push qword msg_erro_nome           ; nenhum arquivo aberto
    call encerra_com_erro              ; não retorna

.erro_abre_entrada:
    push qword msg_erro_entrada        ; nenhum arquivo aberto
    call encerra_com_erro              ; não retorna

.erro_mesmo_arquivo:
    mov rbx, msg_erro_mesmo            ; apenas a entrada está aberta
    jmp .fecha_entrada_e_encerra

.erro_abre_saida:
    mov rbx, msg_erro_saida            ; apenas a entrada está aberta
    jmp .fecha_entrada_e_encerra

.erro_leitura:
    mov rbx, msg_erro_leitura          ; os dois arquivos estão abertos
    jmp .fecha_saida_e_encerra

.erro_escrita:
    mov rbx, msg_erro_escrita          ; os dois arquivos estão abertos

.fecha_saida_e_encerra:
    push qword [descr_saida]
    call fecha_arquivo
    add  rsp, 8

.fecha_entrada_e_encerra:
    push qword [descr_entrada]
    call fecha_arquivo
    add  rsp, 8
    push rbx                           ; mensagem de erro
    call encerra_com_erro              ; não retorna

; ;
fim_programa:
; ------------------------------------
; syscall: sys_exit
    mov     rax, 60                    ; sys_exit
    mov     rdi, 0                     ; sucesso
    syscall
; ------------------------------------

; encerra_com_erro(char* mensagem)
; escreve a mensagem e encerra o programa com status 1 e não retorna
encerra_com_erro:
    push rbp                           ; rbp antigo
    mov  rbp, rsp                      ; setta novo rbp
    push qword [rbp+16]                ; mensagem de erro
    call escreve_string                ; chama função
    add  rsp, 8                        ; coloca pilha livre

; ------------------------------------
; syscall: sys_exit
    mov     rax, 60                    ; sys_exit
    mov     rdi, 1                     ; erro
    syscall
; ------------------------------------

; mesmo_arquivo(int descritor_arquivo, char* nome_arquivo)
; compara dispositivo e inode, o que também detecta links e caminhos alternativos.
; retorno: rax = 1 se forem o mesmo arquivo ou se não for possível verificar o
; descritor, 0 se forem diferentes ou se o nome ainda não existir.
mesmo_arquivo:
    push rbp                           ; rbp antigo
    mov  rbp, rsp                      ; setta novo rbp
    push rdi                           ; rdi antigo
    push rsi                           ; rsi antigo
    push rcx                           ; rcx antigo (destruído pela syscall)
    push r11                           ; r11 antigo (destruído pela syscall)
    push r8                            ; r8 antigo
    sub  rsp, 288                      ; duas struct stat de 144 bytes

; ------------------------------------
; syscall: sys_fstat
    mov     rax, 5                     ; sys_fstat
    mov     rdi, [rbp+16]              ; descritor do arquivo
    mov     rsi, rsp                   ; primeira struct stat
    syscall
; ------------------------------------
    cmp rax, 0                         ; verifica erro
    jl  .iguais                        ; sem verificação, não arrisca truncar

; ------------------------------------
; syscall: sys_stat
    mov     rax, 4                     ; sys_stat
    mov     rdi, [rbp+24]              ; nome do arquivo
    lea     rsi, [rsp+144]             ; segunda struct stat
    syscall
; ------------------------------------
    cmp rax, 0                         ; verifica erro
    jl  .diferentes                    ; nome inexistente não pode ser a entrada

    mov r8, [rsp]                      ; st_dev da entrada
    cmp r8, [rsp+144]                  ; compara com st_dev da saída
    jne .diferentes
    mov r8, [rsp+8]                    ; st_ino da entrada
    cmp r8, [rsp+152]                  ; compara com st_ino da saída
    jne .diferentes

.iguais:
    mov rax, 1                         ; mesmo arquivo
    jmp .retorno

.diferentes:
    mov rax, 0                         ; arquivos diferentes

.retorno:
    add rsp, 288                       ; libera as structs
    pop r8                             ; restaura r8
    pop r11                            ; restaura r11
    pop rcx                            ; restaura rcx
    pop rsi                            ; restaura rsi
    pop rdi                            ; restaura rdi
    pop rbp                            ; restaura rbp
    ret                                ; retorna

; decodifica_utf8(int descritor_arquivo, int byte_inicial)
; identifica o tamanho da sequência pelo byte inicial, lê os bytes de continuação e
; reconstrói o code point.
;   0xxxxxxx                            -> 1 byte
;   110xxxxx 10xxxxxx                   -> 2 bytes
;   1110xxxx 10xxxxxx 10xxxxxx          -> 3 bytes
;   11110xxx 10xxxxxx 10xxxxxx 10xxxxxx -> 4 bytes
; retorno: rax = code point, ou valor negativo se a leitura falhar ou o arquivo
; terminar no meio da sequência.
decodifica_utf8:
    push rbp                           ; rbp antigo
    mov  rbp, rsp                      ; setta novo rbp
    push rbx                           ; rbx antigo -> code point parcial
    push rcx                           ; rcx antigo -> continuações restantes

    mov rbx, [rbp+24]                  ; carrega byte inicial
    cmp rbx, 0x80                      ; 0xxxxxxx
    jb  .um_byte
    cmp rbx, 0xE0                      ; 110xxxxx
    jb  .dois_bytes
    cmp rbx, 0xF0                      ; 1110xxxx
    jb  .tres_bytes

    and rbx, 0x07                      ; 11110xxx: mantém 3 bits
    mov rcx, 3                         ; 3 bytes de continuação
    jmp .continuacao

.um_byte:
    mov rcx, 0                         ; sem bytes de continuação
    jmp .continuacao

.dois_bytes:
    and rbx, 0x1F                      ; mantém 5 bits
    mov rcx, 1                         ; 1 byte de continuação
    jmp .continuacao

.tres_bytes:
    and rbx, 0x0F                      ; mantém 4 bits
    mov rcx, 2                         ; 2 bytes de continuação

.continuacao:
    cmp  rcx, 0                        ; verifica se restam continuações
    je   .pronto
    push qword byte_arq                ; destino do byte lido
    push qword [rbp+16]                ; descritor do arquivo
    call le_byte_arquivo               ; chama função
    add  rsp, 16                       ; coloca pilha livre
    cmp  rax, 1                        ; verifica se leu o byte
    jne  .falha

    movzx rax, byte [byte_arq]         ; carrega byte de continuação
    and   rax, 0x3F                    ; mantém 6 bits
    shl   rbx, 6                       ; abre espaço para os novos bits
    or    rbx, rax                     ; acrescenta os novos bits
    dec   rcx                          ; contabiliza continuação
    jmp   .continuacao                 ; reinicia laço

.falha:
    cmp rax, 0                         ; erro da syscall já é negativo
    jl  .retorno
    mov rax, -1                        ; fim de arquivo no meio da sequência
    jmp .retorno

.pronto:
    mov rax, rbx                       ; retorna code point

.retorno:
    pop rcx                            ; restaura rcx
    pop rbx                            ; restaura rbx
    pop rbp                            ; restaura rbp
    ret                                ; retorna

; fecha_arquivo(int descritor_arquivo)
; retorno: rax = 0 em caso de sucesso, ou valor negativo em caso de erro.
fecha_arquivo:
    push rbp                           ; empilha rbp anterior
    mov  rbp, rsp                      ; setta o novo rbp
    push rdi                           ; empilha rdi anterior
    push rcx                           ; empilha rcx anterior (destruído pela syscall)
    push r11                           ; empilha r11 anterior (destruído pela syscall)

; ------------------------------------
; syscall: sys_close
    mov     rax, 3                     ; sys_close
    mov     rdi, [rbp+16]              ; rdi recebe o descritor
    syscall
; ------------------------------------
    pop r11                            ; restaura r11
    pop rcx                            ; restaura rcx
    pop rdi                            ; restaura rdi
    pop rbp                            ; restaura rbp
    ret

abre_arquivo:
    push rbp                           ; salva rbp antigo
    mov  rbp, rsp                      ; setta novo rbp
    push rdi                           ; salva rdi antigo
    push rsi                           ; salva rsi antigo
    push rdx                           ; salva rdx antigo
    push rcx                           ; salva rcx antigo (destruído pela syscall)
    push r11                           ; salva r11 antigo (destruído pela syscall)

; ------------------------------------
; syscall: sys_open
    mov     rax, 2                     ; sys_open
    mov     rdi, [rbp+16]              ; endereço do começo do nome do arquivo
    mov     rsi, [rbp+24]              ; modo de abertura
    mov     rdx, 438                   ; permissões do enunciado
    syscall
; ------------------------------------
; rax agora contém o descritor do arquivo
    pop r11                            ; restaura r11
    pop rcx                            ; restaura rcx
    pop rdx                            ; restaura rdx
    pop rsi                            ; restaura rsi
    pop rdi                            ; restaura rdi
    pop rbp                            ; restaura rbp
    ret

le_byte_arquivo:
    push rbp                           ; rbp antigo
    mov  rbp, rsp                      ; setta novo rbp
    push rdi                           ; rdi antigo
    push rsi                           ; rsi antigo
    push rdx                           ; rdx antigo
    push rcx                           ; rcx antigo (destruído pela syscall)
    push r11                           ; r11 antigo (destruído pela syscall)

; ------------------------------------
; syscall: sys_read
    mov     rax, 0                     ; sys_read
    mov     rdi, [rbp+16]              ; carrega descritor em rdi
    mov     rsi, [rbp+24]              ; carrega byte_arq em rsi
    mov     rdx, 1                     ; lê 1 byte
    syscall
; ------------------------------------
    pop r11                            ; restaura r11
    pop rcx                            ; restaura rcx
    pop rdx                            ; restaura rdx
    pop rsi                            ; restaura rsi
    pop rdi                            ; restaura rdi
    pop rbp                            ; restaura rbp
    ret                                ; retorna

; le_string(char* buffer, int tam_max)
; lê uma linha da entrada padrão, um byte por vez, e a armazena terminada em NUL.
; guarda no máximo tam_max - 1 caracteres e descarta o restante da linha, para que
; ele não seja lido como a próxima string.
; retorno: rax = quantidade de caracteres armazenados.
le_string:
    push rbp                           ; rbp antigo
    mov  rbp, rsp                      ; setta novo rbp
    push rdi                           ; rdi antigo
    push rsi                           ; rsi antigo
    push rdx                           ; rdx antigo
    push rcx                           ; rcx antigo (destruído pela syscall)
    push r11                           ; r11 antigo (destruído pela syscall)
    push r8                            ; r8 antigo -> buffer
    push r9                            ; r9 antigo -> limite de caracteres
    push r10                           ; r10 antigo -> quantidade armazenada
    sub  rsp, 8                        ; variável local: byte lido

    mov r8, [rbp+16]                   ; início do buffer
    mov r9, [rbp+24]                   ; tamanho máximo
    dec r9                             ; reserva uma posição para o NUL
    mov r10, 0                         ; nenhum caractere armazenado

.laco:
; ------------------------------------
; syscall: sys_read
    mov     rax, 0                     ; sys_read
    mov     rdi, 0                     ; stdin
    mov     rsi, rsp                   ; endereço da variável local
    mov     rdx, 1                     ; lê 1 byte
    syscall
; ------------------------------------
    cmp rax, 1                         ; verifica se leu um byte
    jne .fim                           ; fim da entrada ou erro
    mov al, [rsp]                      ; carrega o byte lido
    cmp al, 10                         ; verifica ENTER (LF)
    je  .fim                           ; encerra sem armazenar o LF
    cmp r10, r9                        ; verifica limite do buffer
    jge .laco                          ; buffer cheio: descarta o byte
    mov [r8+r10], al                   ; armazena o caractere
    inc r10                            ; contabiliza caractere
    jmp .laco                          ; reinicia laço

.fim:
    cmp r9, 0                          ; tam_max <= 0 não tem espaço para o NUL
    jl  .retorno                       ; não escreve no buffer
    mov byte [r8+r10], 0               ; termina a string com NUL

.retorno:
    mov rax, r10                       ; retorna quantidade armazenada
    add rsp, 8                         ; libera variável local
    pop r10                            ; restaura r10
    pop r9                             ; restaura r9
    pop r8                             ; restaura r8
    pop r11                            ; restaura r11
    pop rcx                            ; restaura rcx
    pop rdx                            ; restaura rdx
    pop rsi                            ; restaura rsi
    pop rdi                            ; restaura rdi
    pop rbp                            ; restaura rbp
    ret                                ; retorna

escreve_string:
    push rbp                           ; rbp antigo
    mov  rbp, rsp                      ; setta novo rbp
    push rdi                           ; rdi antigo
    push rsi                           ; rsi antigo
    push rdx                           ; rdx antigo
    push rbx                           ; rbx antigo -> contador
    push rcx                           ; rcx antigo -> i
    push r11                           ; r11 antigo (destruído pela syscall)
    push rax                           ; rax antigo (função sem retorno)

; prepara o loop
    mov rsi, [rbp+16]                  ; aponta rsi começo da mensagem
    mov rbx, 0                         ; zera contador
    mov rcx, 0                         ; zera i

; loop descobre tamanho mensagem
.laco:
    cmp byte [rsi+rcx], 0              ; verifica fim da string
    je  .fim                           ; encerra laço e imprime
    inc rbx                            ; contabiliza caractere
    inc rcx                            ; avança próximo caractere
    jmp .laco                          ; reinicia laço

.fim:
; ------------------------------------
; syscall: sys_write
    mov     rax, 1                     ; sys_write
    mov     rdi, 1                     ; stdout
    mov     rsi, [rbp+16]              ; começo mensagem
    mov     rdx, rbx                   ; tamanho calculado
    syscall
; ------------------------------------
    pop rax                            ; restaura rax
    pop r11                            ; restaura r11
    pop rcx                            ; restaura rcx
    pop rbx                            ; restaura rbx
    pop rdx                            ; restaura rdx
    pop rsi                            ; restaura rsi
    pop rdi                            ; restaura rdi
    pop rbp                            ; restaura rbp
    ret                                ; retorna

; grava_string_arquivo(int descritor_arquivo, char* buffer)
; repete a escrita até gravar toda a string, sem o NUL.
; retorno: rax = bytes gravados, ou valor negativo em caso de erro.
grava_string_arquivo:
    push rbp                           ; rbp antigo
    mov  rbp, rsp                      ; setta novo rbp
    push rdi                           ; rdi antigo
    push rsi                           ; rsi antigo
    push rdx                           ; rdx antigo
    push rbx                           ; rbx antigo -> contador
    push rcx                           ; rcx antigo -> i
    push r11                           ; r11 antigo (destruído pela syscall)

; prepara laço
    mov rsi, [rbp+24]                  ; rsi aponta começo mensagem
    mov rbx, 0                         ; zera contador
    mov rcx, 0                         ; zera apontador

.laco:

    cmp byte [rsi + rcx], 0            ; verifica fim string
    je  .fim                           ; encerra loop
    inc rbx                            ; contabiliza caractere
    inc rcx                            ; incrementa apontador
    jmp .laco                          ; fecha laço

.fim:
    mov rdi, [rbp+16]                  ; descritor arquivo
    mov rsi, [rbp+24]                  ; começo mensagem
    mov rdx, rbx                       ; bytes restantes

.escreve:
    cmp rdx, 0                         ; verifica se restam bytes
    je  .sucesso
; ------------------------------------
; syscall: sys_write
    mov     rax, 1                     ; sys_write
    syscall
; ------------------------------------
    cmp rax, 0                         ; verifica resultado
    jl  .retorno                       ; devolve o erro da syscall
    je  .sem_progresso                 ; evita laço infinito
    add rsi, rax                       ; avança no buffer
    sub rdx, rax                       ; desconta bytes gravados
    jmp .escreve                       ; grava o restante

.sem_progresso:
    mov rax, -5                        ; -EIO
    jmp .retorno

.sucesso:
    mov rax, rbx                       ; retorna total gravado

.retorno:
    pop r11                            ; restaura r11
    pop rcx                            ; restaura rcx
    pop rbx                            ; restaura rbx
    pop rdx                            ; restaura rdx
    pop rsi                            ; restaura rsi
    pop rdi                            ; restaura rdi
    pop rbp                            ; restaura rbp
    ret                                ; retorna

; gera_string_hexadecimal(int valor, char* buffer)
gera_string_hexadecimal:
    push rbp                           ; rbp antigo
    mov  rbp, rsp                      ; novo rbp
    push rax                           ; rax antigo
    push rbx                           ; rbx antigo
    push rcx                           ; rcx antigo
    push rdx                           ; rdx antigo
    push r8                            ; r8 antigo
    push r9                            ; r9 antigo

; 1. determina o valor hex
    mov rax, [rbp+16]                  ; carrega dividendo
    mov rbx, 16                        ; carrega divisor
    mov r8, 0                          ; contador elementos empilhados

.laco_divisao:
    mov  rdx, 0                        ; zera resto
    div  rbx                           ; rdx tem o resto e rax o quociente
    push rdx                           ; empilha resto, para desempilhar na ordem certa
    inc  r8                            ; aumenta contador elementos empilhados
    cmp  rax, 0                        ; verifica se o quociente é zero
    jne  .laco_divisao                 ; reinicia caso ainda tenha código

; 2. inclui o '0x'
    mov rcx, [rbp+24]                  ; carrega início buffer
    mov r9, 0                          ; indicador posição livre p/ escrita
    mov byte [rcx + r9], '0'           ; começa o '0x', colocando apenas 0
    inc r9                             ; próxima posição livre
    mov byte [rcx+r9], 'x'             ; agora sim '0x'
    inc r9                             ; próxima posição livre

.traduz:
; 3. traduz todos os códigos para caracteres
    cmp r8, 0                          ; verifica se restam elementos empilhados
    jle .pronto                        ; termina de carregar o buffer
    dec r8                             ; contabiliza o caractere
    pop rdx                            ; carrega em rdx o caractere
    cmp rdx, 9                         ; verifica se é um dígito (0-9) ou caractere (A-F)
    jg  .letra                         ; letra
    add rdx, '0'                       ; transforma o dígito em caractere
    mov byte [rcx+r9], dl              ; carrega caractere no buffer
    inc r9                             ; próxima posição livre
    jmp .traduz                        ; reinicia laço

.letra:
    add rdx, 'A' - 10                  ; converte letra para caractere
    mov byte [rcx+r9], dl              ; carrega caractere no buffer
    inc r9                             ; próxima posição livre
    jmp .traduz                        ; reinicia laço

.pronto:
    mov byte [rcx+r9], 10              ; adiciona LF
    inc r9                             ; próxima posição livre
    mov byte [rcx+r9], 0               ; adiciona NUL

; restaura os registradores
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ret
