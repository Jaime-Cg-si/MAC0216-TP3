#!/usr/bin/env bash
# Compila tarefa3-Grupo16.asm e roda os testes.
#
# Uso: ./run_tests.sh [nome...]
#
# Sem argumentos, roda todos os testes. Cada nome pode ser:
#   {arquivo}  compara a saída de arquivos_enunciado/{arquivo}.txt com
#              arquivos_enunciado/{arquivo}_saida.txt
#   exaustivo  converte todos os code points válidos do Unicode
#
# Exemplo: ./run_tests.sh teste2_multibyte exaustivo

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

# Converte todos os escalares Unicode, exceto os substitutos (U+D800 a U+DFFF). A entrada
# tem mais de 4 MiB, então as sequências também cruzam fronteiras de página.
teste_exaustivo() {
    local entrada="$tempdir/exaustivo.in"
    local saida="$tempdir/exaustivo.out"
    local esperado="$tempdir/exaustivo.esperado"

    if ! python3 -I -c '
import sys
cps = [c for c in range(0x110000) if not 0xD800 <= c <= 0xDFFF]
open(sys.argv[1], "wb").write("".join(map(chr, cps)).encode("utf-8"))
open(sys.argv[2], "w").write("".join(f"0x{c:X}\n" for c in cps))
' "$entrada" "$esperado"; then
        relata exaustivo "não foi possível gerar a entrada"
        return
    fi

    printf '%s\n%s\n' "$entrada" "$saida" | "$main" >/dev/null
    local status=$?
    if [ "$status" -ne 0 ]; then
        relata exaustivo "status $status"
    elif ! cmp "$saida" "$esperado"; then
        relata exaustivo "saída diferente da esperada"
    else
        relata exaustivo ""
    fi
    rm -f "$entrada" "$esperado" "$saida"
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
        tests+=(exaustivo)
    fi

    for t in "${tests[@]}"; do
        case "$t" in
        exaustivo) teste_exaustivo ;;
        *) teste_arquivo "$t" ;;
        esac
    done

    exit "$failed"
}

failed=0

main "$@"
