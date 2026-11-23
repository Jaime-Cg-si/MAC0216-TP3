#!/usr/bin/env bash
# Compila tarefa3-Grupo16.asm e roda os testes.
#
# Uso: ./run_tests.sh [nome...]
#
# Sem argumentos, roda todos os testes. Cada nome pode ser:
#   {arquivo}  compara a saída de arquivos_enunciado/{arquivo}.txt com
#              arquivos_enunciado/{arquivo}_saida.txt
#
# Exemplo: ./run_tests.sh teste1_ascii teste2_multibyte

set -u

# Registra o resultado de um teste: relata {nome} como OK se {falha} estiver vazia.
relata() {
    local nome="$1" falha="$2"
    if [ -z "$falha" ]; then
        echo "OK $nome"
    else
        echo "FALHOU $nome: $falha"
        failed=1
    fi
}

# Compara a saída de arquivos_enunciado/{nome}.txt com a saída esperada em arquivos_enunciado/{nome}_saida.txt.
teste_arquivo() {
    local t="$1"
    printf 'arquivos_enunciado/%s.txt\n%s/%s.txt\n' "$t" "$tempdir" "$t" | "$main" >/dev/null
    if cmp "$tempdir/$t.txt" "arquivos_enunciado/${t}_saida.txt"; then
        relata "$t" ""
    else
        relata "$t" "saída diferente da esperada"
    fi
}

main() {
    cd "$(dirname "${BASH_SOURCE[0]}")" || exit 2

    tempdir="$(mktemp -d)" || exit 2
    trap 'rm -rf "$tempdir"' EXIT

    make -s BUILD_DIR="$tempdir" || exit 2
    main="$tempdir/main"

    if [ "$#" -gt 0 ]; then
        tests=("$@")
    else
        tests=()
        for f in arquivos_enunciado/teste*.txt; do
            case "$f" in
            *_saida.txt) continue ;;
            esac
            tests+=("$(basename "$f" .txt)")
        done
    fi

    for t in "${tests[@]}"; do
        case "$t" in
        *) teste_arquivo "$t" ;;
        esac
    done

    exit "$failed"
}

failed=0

main "$@"
