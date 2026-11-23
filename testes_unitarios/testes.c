// Testes unitários das funções de tarefa13-Grupo16.asm, chamadas por meio de ponte.asm.
//
// Cada chamada também confere se a função preservou os registradores. O
// programa termina com status 1 se algum teste falhar.

#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

typedef void funcao(void);

extern funcao le_string, escreve_string, abre_arquivo, fecha_arquivo, le_byte_arquivo;
extern funcao grava_string_arquivo, gera_string_hexadecimal, decodifica_utf8, mesmo_arquivo;
extern funcao encerra_com_erro;
extern long chama2(funcao *f, long a, long b);
extern char registrador_alterado;

#define SENTINELA 0x6969696969696969L
#define GUARDA 0x7F
#define MODO_ESCRITA 577

static int falhas_total, falhas_grupo;

#define CHECA(cond)                                                                                \
    do {                                                                                           \
        if (!(cond)) {                                                                             \
            printf("  FALHOU %s:%d: %s\n", __func__, __LINE__, #cond);                             \
            ++falhas_grupo;                                                                        \
        }                                                                                          \
    } while (0)

// Chama uma função com retorno em rax.
#define CHAMA(f, a, b) chama_((f), (long)(a), (long)(b), __func__, __LINE__, 0)
// Chama uma função sem retorno, que também deve preservar rax.
#define CHAMA_VOID(f, a, b) chama_((f), (long)(a), (long)(b), __func__, __LINE__, 1)

static long chama_(funcao *f, long a, long b, const char *origem, int linha, int sem_retorno) {
    registrador_alterado = 0;
    long r = chama2(f, a, b);
    if (registrador_alterado || (sem_retorno && r != SENTINELA)) {
        printf("  FALHOU %s:%d: registrador não preservado\n", origem, linha);
        ++falhas_grupo;
    }
    return r;
}

static void grupo(const char *nome, void (*teste)(void)) {
    falhas_grupo = 0;
    teste();
    printf("%s %s\n", falhas_grupo ? "FALHOU" : "OK", nome);
    fflush(stdout);
    falhas_total += falhas_grupo;
}

static void cria_arquivo(const char *nome, const char *conteudo) {
    FILE *f = fopen(nome, "w");
    if (!f) {
        perror(nome);
        exit(2);
    }
    fputs(conteudo, f);
    fclose(f);
}

// Lê o arquivo para buf e devolve a quantidade de bytes.
static ssize_t le_arquivo(const char *nome, char *buf, size_t tam) {
    int fd = open(nome, O_RDONLY);
    if (fd < 0)
        return -1;
    ssize_t n = read(fd, buf, tam);
    close(fd);
    return n;
}

// Devolve a ponta de leitura de um pipe que já contém os bytes indicados.
static int pipe_com(const char *dados, size_t n) {
    int p[2];
    if (pipe(p) != 0 || write(p[1], dados, n) != (ssize_t)n) {
        perror("pipe");
        exit(2);
    }
    close(p[1]);
    return p[0];
}

// Substitui a entrada padrão e devolve uma cópia da original.
static int troca_stdin(const char *dados) {
    int original = dup(0);
    int fd = pipe_com(dados, strlen(dados));
    dup2(fd, 0);
    close(fd);
    return original;
}

static void restaura_fd(int original, int alvo) {
    dup2(original, alvo);
    close(original);
}

static void teste_le_string(void) {
    char b[8];
    int original = troca_stdin("abc\n\nabcdefg\nabcdefghij\nfim\nsem");

    memset(b, GUARDA, sizeof(b));
    CHECA(CHAMA(le_string, b, sizeof(b)) == 3);
    CHECA(strcmp(b, "abc") == 0);
    CHECA(b[4] == GUARDA);

    // linha vazia
    CHECA(CHAMA(le_string, b, sizeof(b)) == 0);
    CHECA(b[0] == 0);

    // exatamente tam_max - 1 caracteres
    CHECA(CHAMA(le_string, b, sizeof(b)) == 7);
    CHECA(strcmp(b, "abcdefg") == 0);

    // o excedente é descartado e não vira a próxima string
    char c[10];
    memset(c, GUARDA, sizeof(c));
    CHECA(CHAMA(le_string, c, 8) == 7);
    CHECA(strcmp(c, "abcdefg") == 0);
    CHECA(c[8] == GUARDA);
    CHECA(CHAMA(le_string, b, sizeof(b)) == 3);
    CHECA(strcmp(b, "fim") == 0);

    // fim da entrada sem LF
    CHECA(CHAMA(le_string, b, sizeof(b)) == 3);
    CHECA(strcmp(b, "sem") == 0);

    // fim da entrada sem nenhum caractere
    CHECA(CHAMA(le_string, b, sizeof(b)) == 0);
    CHECA(b[0] == 0);
    restaura_fd(original, 0);

    // tam_max = 1 só comporta o NUL
    original = troca_stdin("xy\nz\n");
    memset(b, GUARDA, sizeof(b));
    CHECA(CHAMA(le_string, b, 1) == 0);
    CHECA(b[0] == 0 && b[1] == GUARDA);
    restaura_fd(original, 0);

    // tam_max = 0 não escreve no buffer
    original = troca_stdin("xy\n");
    memset(b, GUARDA, sizeof(b));
    CHECA(CHAMA(le_string, b, 0) == 0);
    CHECA(b[0] == GUARDA);
    restaura_fd(original, 0);
}

static void confere_escrita(const char *s) {
    char b[64];
    int p[2];
    if (pipe(p) != 0) {
        perror("pipe");
        exit(2);
    }
    fflush(stdout);
    int original = dup(1);
    dup2(p[1], 1);
    close(p[1]);
    CHAMA_VOID(escreve_string, s, 0);
    restaura_fd(original, 1);

    ssize_t n = read(p[0], b, sizeof(b));
    close(p[0]);
    CHECA(n == (ssize_t)strlen(s));
    CHECA(memcmp(b, s, strlen(s)) == 0);
}

static void teste_escreve_string(void) {
    confere_escrita("abc");
    confere_escrita("linha\n");
    confere_escrita("não ASCII: ç😎");

    // string vazia: write de 0 bytes em um pipe não produz dados, então usa
    // arquivo
    fflush(stdout);
    int original = dup(1);
    int fd = open("vazia.txt", O_WRONLY | O_CREAT | O_TRUNC, 0666);
    dup2(fd, 1);
    close(fd);
    CHAMA_VOID(escreve_string, "", 0);
    restaura_fd(original, 1);
    struct stat st;
    CHECA(stat("vazia.txt", &st) == 0 && st.st_size == 0);
}

static void teste_abre_arquivo(void) {
    char b[16];
    struct stat st;

    cria_arquivo("abre.txt", "conteudo");
    long fd = CHAMA(abre_arquivo, "abre.txt", 0);
    CHECA(fd >= 0);
    CHECA(read(fd, b, sizeof(b)) == 8);
    CHECA(write(fd, "x", 1) == -1);
    close(fd);

    CHECA(CHAMA(abre_arquivo, "inexistente.txt", 0) == -ENOENT);
    CHECA(access("inexistente.txt", F_OK) != 0);

    // cria com permissões 438 (0666), filtradas pela umask
    mode_t mascara = umask(0);
    fd = CHAMA(abre_arquivo, "novo.txt", MODO_ESCRITA);
    umask(mascara);
    CHECA(fd >= 0);
    CHECA(write(fd, "ok", 2) == 2);
    CHECA(read(fd, b, 1) == -1);
    close(fd);
    CHECA(stat("novo.txt", &st) == 0 && (st.st_mode & 0777) == 0666);

    // trunca arquivo existente
    fd = CHAMA(abre_arquivo, "abre.txt", MODO_ESCRITA);
    CHECA(fd >= 0);
    close(fd);
    CHECA(stat("abre.txt", &st) == 0 && st.st_size == 0);

    mkdir("dir_abre", 0777);
    CHECA(CHAMA(abre_arquivo, "dir_abre", MODO_ESCRITA) == -EISDIR);
    CHECA(CHAMA(abre_arquivo, "", 0) == -ENOENT);
}

static void teste_fecha_arquivo(void) {
    int fd = open("/dev/null", O_RDONLY);
    CHECA(CHAMA(fecha_arquivo, fd, 0) == 0);
    CHECA(fcntl(fd, F_GETFD) == -1);

    // fechar de novo e descritor inválido
    CHECA(CHAMA(fecha_arquivo, fd, 0) == -EBADF);
    CHECA(CHAMA(fecha_arquivo, -1, 0) == -EBADF);
}

static void teste_le_byte_arquivo(void) {
    char b[3] = {GUARDA, GUARDA, GUARDA};
    int fd = pipe_com("\xC3\n", 2);

    CHECA(CHAMA(le_byte_arquivo, fd, &b[1]) == 1);
    CHECA((unsigned char)b[1] == 0xC3);
    CHECA(b[0] == GUARDA && b[2] == GUARDA);
    CHECA(CHAMA(le_byte_arquivo, fd, &b[1]) == 1);
    CHECA(b[1] == '\n');

    // fim de arquivo não altera o destino
    CHECA(CHAMA(le_byte_arquivo, fd, &b[1]) == 0);
    CHECA(b[1] == '\n');
    close(fd);

    CHECA(CHAMA(le_byte_arquivo, -1, b) == -EBADF);
    mkdir("dir_le", 0777);
    fd = open("dir_le", O_RDONLY);
    CHECA(CHAMA(le_byte_arquivo, fd, b) == -EISDIR);
    close(fd);
}

static void teste_grava_string_arquivo(void) {
    char b[16];
    int fd = open("grava.txt", O_WRONLY | O_CREAT | O_TRUNC, 0666);

    CHECA(CHAMA(grava_string_arquivo, fd, "0x41\n") == 5);
    CHECA(CHAMA(grava_string_arquivo, fd, "") == 0);
    CHECA(CHAMA(grava_string_arquivo, fd, "0xA\n") == 4);
    close(fd);
    CHECA(le_arquivo("grava.txt", b, sizeof(b)) == 9);
    CHECA(memcmp(b, "0x41\n0xA\n", 9) == 0);

    CHECA(CHAMA(grava_string_arquivo, -1, "x") == -EBADF);

    fd = open("/dev/full", O_WRONLY);
    if (fd >= 0) {
        CHECA(CHAMA(grava_string_arquivo, fd, "x") == -ENOSPC);
        close(fd);
    }

    // com limite de 3 bytes, a primeira escrita é parcial e a repetição recebe o erro
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        struct rlimit limite = {3, 3};
        signal(SIGXFSZ, SIG_IGN);
        setrlimit(RLIMIT_FSIZE, &limite);
        fd = open("parcial.txt", O_WRONLY | O_CREAT | O_TRUNC, 0666);
        registrador_alterado = 0;
        long r = chama2(grava_string_arquivo, fd, (long)"abcdef");
        _exit(r == -EFBIG && !registrador_alterado ? 0 : 1);
    }
    int status;
    waitpid(pid, &status, 0);
    CHECA(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    CHECA(le_arquivo("parcial.txt", b, sizeof(b)) == 3);
    CHECA(memcmp(b, "abc", 3) == 0);
}

static void confere_hex(uint64_t valor, const char *esperado) {
    char b[24];
    size_t n = strlen(esperado);

    memset(b, GUARDA, sizeof(b));
    CHAMA_VOID(gera_string_hexadecimal, valor, b);
    CHECA(memcmp(b, esperado, n + 1) == 0);
    CHECA(b[n + 1] == GUARDA);
}

static void teste_gera_string_hexadecimal(void) {
    confere_hex(0, "0x0\n");
    confere_hex(9, "0x9\n");
    confere_hex(0xA, "0xA\n");
    confere_hex(0xF, "0xF\n");
    confere_hex(0x10, "0x10\n");
    confere_hex(0xE7, "0xE7\n");
    confere_hex(0x100, "0x100\n");
    confere_hex(0x770C, "0x770C\n");
    confere_hex(0x1F60E, "0x1F60E\n");
    confere_hex(0x10FFFF, "0x10FFFF\n");
    confere_hex(UINT64_MAX, "0xFFFFFFFFFFFFFFFF\n");
}

static long decodifica(const char *s, size_t n) {
    int fd = pipe_com(s + 1, n - 1);
    long r = CHAMA(decodifica_utf8, fd, (unsigned char)s[0]);

    // não pode consumir bytes além da sequência
    char extra;
    CHECA(read(fd, &extra, 1) == 0);
    close(fd);
    return r;
}

static void teste_decodifica_utf8(void) {
    // limites de cada tamanho
    CHECA(decodifica("\x00", 1) == 0);
    CHECA(decodifica("A", 1) == 0x41);
    CHECA(decodifica("\n", 1) == 0xA);
    CHECA(decodifica("\x7F", 1) == 0x7F);
    CHECA(decodifica("\xC2\x80", 2) == 0x80);
    CHECA(decodifica("\xC3\xA7", 2) == 0xE7);
    CHECA(decodifica("\xDF\xBF", 2) == 0x7FF);
    CHECA(decodifica("\xE0\xA0\x80", 3) == 0x800);
    CHECA(decodifica("\xE7\x9C\x8C", 3) == 0x770C);
    CHECA(decodifica("\xED\x9F\xBF", 3) == 0xD7FF);
    CHECA(decodifica("\xEE\x80\x80", 3) == 0xE000);
    CHECA(decodifica("\xEF\xBF\xBF", 3) == 0xFFFF);
    CHECA(decodifica("\xF0\x90\x80\x80", 4) == 0x10000);
    CHECA(decodifica("\xF0\x9F\x98\x8E", 4) == 0x1F60E);
    CHECA(decodifica("\xF4\x8F\xBF\xBF", 4) == 0x10FFFF);

    // fim de arquivo no meio da sequência
    CHECA(decodifica("\xC3", 1) < 0);
    CHECA(decodifica("\xE2", 1) < 0);
    CHECA(decodifica("\xE2\x82", 2) < 0);
    CHECA(decodifica("\xF0", 1) < 0);
    CHECA(decodifica("\xF0\x9F", 2) < 0);
    CHECA(decodifica("\xF0\x9F\x98", 3) < 0);

    // erro de leitura da continuação
    CHECA(CHAMA(decodifica_utf8, -1, 0xC3) == -EBADF);

    // sequência de 1 byte não lê o descritor
    CHECA(CHAMA(decodifica_utf8, -1, 'A') == 'A');
}

static void teste_mesmo_arquivo(void) {
    cria_arquivo("a.txt", "a");
    cria_arquivo("b.txt", "b");
    symlink("a.txt", "link.txt");
    link("a.txt", "duro.txt");
    mkdir("dir_mesmo", 0777);

    int fd = open("a.txt", O_RDONLY);
    CHECA(CHAMA(mesmo_arquivo, fd, "a.txt") == 1);
    CHECA(CHAMA(mesmo_arquivo, fd, "dir_mesmo/../a.txt") == 1);
    CHECA(CHAMA(mesmo_arquivo, fd, "link.txt") == 1);
    CHECA(CHAMA(mesmo_arquivo, fd, "duro.txt") == 1);
    CHECA(CHAMA(mesmo_arquivo, fd, "b.txt") == 0);
    CHECA(CHAMA(mesmo_arquivo, fd, "inexistente.txt") == 0);
    close(fd);

    // sem poder verificar o descritor, assume o caso seguro
    CHECA(CHAMA(mesmo_arquivo, -1, "a.txt") == 1);
}

static void teste_encerra_com_erro(void) {
    const char *msg = "Erro: mensagem de teste.\n";
    char b[64];
    int p[2];

    if (pipe(p) != 0) {
        perror("pipe");
        exit(2);
    }
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        close(p[0]);
        dup2(p[1], 1);
        close(p[1]);
        chama2(encerra_com_erro, (long)msg, 0);

        // só chega aqui se a função retornar
        _exit(99);
    }
    close(p[1]);
    int status;
    waitpid(pid, &status, 0);
    ssize_t n = read(p[0], b, sizeof(b));
    close(p[0]);
    CHECA(WIFEXITED(status) && WEXITSTATUS(status) == 1);
    CHECA(n == (ssize_t)strlen(msg));
    CHECA(memcmp(b, msg, strlen(msg)) == 0);
}

int main(void) {
    char dir[] = "/tmp/testes_unitXXXXXX";
    char comando[64];

    if (!mkdtemp(dir) || chdir(dir) != 0) {
        perror("diretório temporário");
        return 2;
    }

    grupo("le_string", teste_le_string);
    grupo("escreve_string", teste_escreve_string);
    grupo("abre_arquivo", teste_abre_arquivo);
    grupo("fecha_arquivo", teste_fecha_arquivo);
    grupo("le_byte_arquivo", teste_le_byte_arquivo);
    grupo("grava_string_arquivo", teste_grava_string_arquivo);
    grupo("gera_string_hexadecimal", teste_gera_string_hexadecimal);
    grupo("decodifica_utf8", teste_decodifica_utf8);
    grupo("mesmo_arquivo", teste_mesmo_arquivo);
    grupo("encerra_com_erro", teste_encerra_com_erro);

    if (chdir("/") == 0) {
        snprintf(comando, sizeof(comando), "rm -rf '%s'", dir);
        if (system(comando) != 0)
            fprintf(stderr, "aviso: não foi possível remover %s\n", dir);
    }
    return falhas_total != 0;
}
