# MAC0216 Técnicas de programação I - Trabalho prático 3: Conversor NASM de UTF-8 para code points Unicode

## Integrantes do grupo

- Felipe Brancalhão Curcio: 16985106
- Jaime Cavalcanti Guedes: 16875204
- João Pedro Silva Amadio: 13672533
- Murilo Santos de Castro: 17015895

## Visão geral

Programa em assembly NASM para Linux x86-64 que lê um arquivo codificado em UTF-8 e grava em outro
arquivo o code point Unicode de cada caractere, em hexadecimal maiúsculo com prefixo `0x`, um por
linha. O programa usa apenas chamadas de sistema, sem libc nem bibliotecas externas.

## Como compilar e rodar o programa

São necessários `nasm`, `ld` (GNU Binutils) e `make`. `python3` e `gcc` são dependências opcionais,
usadas pelos testes `exaustivo` e `unitario` (ver [Testes](#testes)).

``` sh
make                    # gera build/main
make clean              # remove o objeto e o executável
make BUILD_DIR=dliub    # usa outro diretório de compilação
```

`make run` executa o binário gerado. O programa pede os dois nomes pela entrada padrão e bloqueia
até recebê-los:

``` console
$ make run
Digite o nome do arquivo de entrada: arquivos_enunciado/teste2_multibyte.txt
Digite o nome do arquivo de saída: out.txt
```

Para rodar sem interação, envie os nomes pela entrada padrão, um por linha:

``` sh
printf '%s\n%s' arquivos_enunciado/teste2_multibyte.txt out.txt | make run
```

Caminhos relativos partem do diretório em que o programa foi executado. O arquivo de saída é criado
ou sobrescrito, com permissões `0666` filtradas pela `umask` atual.

## Testes

`run_tests.sh` compila o programa em um diretório temporário e executa os testes, passando nomes de
arquivos pela entrada padrão sem interação com o usuário. O script termina com status 1 se algum
teste falhar. Na última execução, todas as 42 verificações passaram (commit `7c2e2f01`, Linux 7.3.5
x86-64, NASM 3.02, GNU ld 2.47, Python 3.14.10, GCC 16.2.1).

| Grupo | Verificações | O que confirma |
|---|--:|---|
| `teste1_ascii` | 1 | 12 bytes, 12 code points: letras, espaços, pontuação e LF |
| `teste2_multibyte` | 1 | 12 bytes, 5 code points: sequências de 2, 3 e 4 bytes |
| `teste3_misto` | 1 | 32 bytes, 25 code points: acentos, símbolos e várias linhas |
| `exaustivo` | 1 | Todos os 1.112.064 code points válidos (4.382.592 bytes de entrada) |
| Entrada igual à saída | 4 | Mesmo nome, caminho alternativo, symlink e hardlink não truncam a entrada |
| Entrada inválida | 6 | Diretório, arquivo inexistente, nome vazio e stdin vazio não criam nem apagam a saída |
| Falhas na saída | 5 | Diretório, caminho inexistente, nome vazio, nome ausente e disco cheio |
| UTF-8 truncado | 3 | Sequências de 2, 3 e 4 bytes cortadas pelo fim do arquivo |
| Limites do nome | 6 | 254 caracteres são aceitos; 255 e 300 são recusados |
| Casos de borda válidos | 4 | Entrada vazia, sobrescrita de saída maior e último nome sem LF |
| `unitario` | 10 | Cada função isolada: retorno, efeitos, erros e registradores preservados |

Os testes de arquivo e o exaustivo comparam a saída byte a byte com o resultado esperado. Os casos
de erro conferem o status, a mensagem e o conteúdo final dos arquivos.

Os testes unitários, em `testes_unitarios`, chamam cada função de `tarefa3-Grupo16.asm` a partir de
C, por meio de uma ponte em assembly que adapta a convenção de chamada e confere os registradores.
Eles exercitam as falhas de leitura e de `sys_close` nas próprias funções, mas o tratamento desses
dois erros em `_start` não é testado com o programa completo. O caso de disco cheio usa `/dev/full`.

### Como rodar os testes

``` sh
./run_tests.sh [nome...]
```

Sem argumentos, roda todos os testes. Cada nome pode ser:

- `{arquivo}`: compara a saída de `arquivos_enunciado/{arquivo}.txt` com
  `arquivos_enunciado/{arquivo}_saida.txt`
- `exaustivo`: converte todos os code points válidos do Unicode.
- `erros`: verifica status, mensagem e arquivos nos casos de erro e de borda.
- `unitario`: testa cada função de `tarefa3-Grupo16.asm` isoladamente.

Exemplos:

``` sh
./run_tests.sh                           # roda todos os testes
./run_tests.sh teste2_multibyte erros    # roda apenas os dois testes indicados
./run_tests.sh unitario                  # roda apenas os testes unitários
```

## Funcionamento

O fluxo fica em `_start`, no arquivo `tarefa3-Grupo16.asm`:

1.  Lê os nomes dos arquivos de entrada e de saída.
2.  Abre a entrada e recusa a saída se ela for o mesmo arquivo (mesmo dispositivo e inode).
3.  Tenta ler o primeiro byte e termina se falhar. Assim, uma entrada ilegível, como um diretório,
    não apaga a saída existente.
4.  Cria ou trunca a saída.
5.  Para cada caractere, decodifica o UTF-8, gera a string hexadecimal e a grava.
6.  Ao chegar ao fim da entrada, fecha os arquivos e encerra.

O byte inicial determina o tamanho da sequência e quantos de seus bits pertencem ao code point. Cada
byte de continuação contribui com 6 bits:

| Bytes | Formato                               | Faixa              |
|------:|---------------------------------------|--------------------|
|     1 | `0xxxxxxx`                            | U+0000 a U+007F    |
|     2 | `110xxxxx 10xxxxxx`                   | U+0080 a U+07FF    |
|     3 | `1110xxxx 10xxxxxx 10xxxxxx`          | U+0800 a U+FFFF    |
|     4 | `11110xxx 10xxxxxx 10xxxxxx 10xxxxxx` | U+10000 a U+10FFFF |

### Funções

| Função | Responsabilidade | Retorno em `rax` |
|---|---|---|
| `le_string(buffer, tam_max)` | Lê uma linha da entrada padrão, byte a byte | Caracteres armazenados |
| `escreve_string(buffer)` | Escreve uma string na saída padrão | Nenhum |
| `abre_arquivo(nome, modo)` | Abre com modo 0 (leitura) ou 577 (escrita, criação e truncamento) | Descritor ou erro |
| `fecha_arquivo(descritor)` | Fecha um arquivo | 0 ou erro |
| `le_byte_arquivo(descritor, byte)` | Lê um byte | Bytes lidos; 0 no fim do arquivo |
| `grava_string_arquivo(descritor, buffer)` | Grava a string sem o NUL, repetindo escritas parciais | Bytes gravados ou erro |
| `gera_string_hexadecimal(valor, buffer)` | Gera `0x...`, LF e NUL | Nenhum |
| `decodifica_utf8(descritor, byte_inicial)` | Auxiliar: lê as continuações e monta o code point | Code point ou negativo |
| `mesmo_arquivo(descritor, nome)` | Auxiliar: compara dispositivo e inode | 1 se for o mesmo arquivo; 0 se não |
| `encerra_com_erro(mensagem)` | Auxiliar: mostra a mensagem e encerra com status 1 | Não retorna |

### Convenção de chamada

- Os parâmetros têm 8 bytes e são empilhados da direita para a esquerda.
- O chamador limpa a pilha com `add rsp, 8 * n`.
- Cada função cria o frame com `push rbp; mov rbp, rsp`. O 1º parâmetro fica em `[rbp+16]` e o 2º em
  `[rbp+24]`.
- As funções preservam os registradores que usam, exceto `rax` quando há retorno.

## Erros e limitações

O programa termina com status 0 em caso de sucesso. Em caso de erro, mostra uma mensagem na saída
padrão e termina com status 1:

| Mensagem | Causa |
|---|---|
| `Erro: nome de arquivo muito longo.` | Nome com 255 caracteres ou mais |
| `Erro: não foi possível abrir o arquivo de entrada.` | Entrada inexistente, sem permissão ou nome vazio |
| `Erro: não foi possível abrir o arquivo de saída.` | Caminho inválido, sem permissão ou nome vazio |
| `Erro: entrada e saída são o mesmo arquivo.` | Os dois nomes apontam para o mesmo inode |
| `Erro: falha ao ler o arquivo de entrada.` | Erro de leitura ou sequência cortada pelo fim do arquivo |
| `Erro: falha ao gravar o arquivo de saída.` | Erro de gravação ou de fechamento da saída |

: Tabela de erros.

Limitações:

- A entrada deve conter UTF-8 válido, conforme o enunciado. Bytes inválidos, sequências longas
  demais e substitutos não são detectados e geram valores sem significado.
- Se o erro ocorrer durante a conversão, a saída mantém as linhas gravadas até aquele ponto.
- A leitura é feita byte a byte, com uma chamada de sistema por byte. Isso simplifica o programa,
  mas não é eficiente para arquivos muito grandes.
