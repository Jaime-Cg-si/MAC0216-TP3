#!/usr/bin/env bash
# Compila tarefa3-Grupo16.asm e roda os testes.
#
# Uso: ./run_tests.sh [nome...]
#
# Sem argumentos, roda todos os testes. Cada nome pode ser:
#   {arquivo}  compara a saída de arquivos_enunciado/{arquivo}.txt com
#              arquivos_enunciado/{arquivo}_saida.txt
#   exaustivo  converte todos os code points válidos do Unicode
#   erros      verifica status, mensagem e arquivos nos casos de erro e de borda
#   unitario   testa cada função de tarefa3-Grupo16.asm isoladamente (requer gcc)
#
# Exemplo: ./run_tests.sh 2_multibyte unitario

set -u

# Registra o resultado de um teste: relata {nome} como OK se {falha} estiver vazia.
relata() {
    local nome="$1" falha="$2"
    if [ -z "${falha}" ]; then
        echo "OK ${nome}"
    else
        echo "FALHOU ${nome}: ${falha}"
        failed=1
    fi
}

# Compara a saída de arquivos_enunciado/{nome}.txt com a saída esperada em arquivos_enunciado/{nome}_saida.txt.
teste_arquivo() {
    local t="$1"
    printf 'arquivos_enunciado/%s.txt\n%s/%s.txt\n' "${t}" "${tempdir}" "${t}" | "${main}" >/dev/null
    if cmp "${tempdir}/${t}.txt" "arquivos_enunciado/${t}_saida.txt"; then
        relata "${t}" ""
    else
        relata "${t}" "saída diferente da esperada"
    fi
}

# Converte todos os escalares Unicode, exceto os substitutos (U+D800 a U+DFFF). A entrada
# tem mais de 4 MiB, então as sequências também cruzam fronteiras de página.
teste_exaustivo() {
    local entrada="${tempdir}/exaustivo.in"
    local saida="${tempdir}/exaustivo.out"
    local esperado="${tempdir}/exaustivo.esperado"

    if ! python3 -I -c '
import sys
cps = [c for c in range(0x110000) if not 0xD800 <= c <= 0xDFFF]
open(sys.argv[1], "wb").write("".join(map(chr, cps)).encode("utf-8"))
open(sys.argv[2], "w").write("".join(f"0x{c:X}\n" for c in cps))
' "${entrada}" "${esperado}"; then
        relata exaustivo "não foi possível gerar a entrada"
        return
    fi

    printf '%s\n%s\n' "${entrada}" "${saida}" | "${main}" >/dev/null
    local status=$?
    if [ "${status}" -ne 0 ]; then
        relata exaustivo "status ${status}"
    elif ! cmp "${saida}" "${esperado}"; then
        relata exaustivo "saída diferente da esperada"
    else
        relata exaustivo ""
    fi
    rm -f "${entrada}" "${esperado}" "${saida}"
}

# Recria o diretório de trabalho dos casos de erro.
prepara_caso() {
    rm -rf "${caso_dir}"
    mkdir -p "${caso_dir}/d"
    printf 'x\n' >"${caso_dir}/i.txt"
    printf 'manter\n' >"${caso_dir}/o.txt"
    ln -s i.txt "${caso_dir}/l.txt"
    ln "${caso_dir}/i.txt" "${caso_dir}/h.txt"
    : >"${caso_dir}/vazio.txt"
    printf '\xC3' >"${caso_dir}/t2.txt"
    printf '\xE2\x82' >"${caso_dir}/t3.txt"
    printf '\xF0\x9F\x98' >"${caso_dir}/t4.txt"
    printf 'q\n' >"${caso_dir}/${nome_254}"
}

# Uso: caso {nome} {status} {mensagem} {stdin} {arquivo} [conteúdo]
#
# Roda o programa com {stdin} (interpretado por printf %b) e confere o status, a mensagem e o
# {arquivo}: ele deve ter exatamente [conteúdo] ou, sem esse argumento, não existir.
caso() {
    local nome="$1" status_esperado="$2" msg="$3" stdin="$4" arquivo="$5"
    local saida_prog status falha=""

    prepara_caso
    saida_prog="$(cd "${caso_dir}" && printf '%b' "${stdin}" | "${main}")"
    status=$?

    if [ "${status}" -ne "${status_esperado}" ]; then
        falha="status ${status}, esperado ${status_esperado}"
    elif [[ "${saida_prog}" != *"${msg}"* ]]; then
        falha="mensagem esperada ausente: ${msg}"
    elif [ "$#" -ge 6 ]; then
        if [ ! -f "${caso_dir}/${arquivo}" ]; then
            falha="${arquivo} não existe"
        elif ! printf '%b' "$6" | cmp -s - "${caso_dir}/${arquivo}"; then
            falha="conteúdo incorreto em ${arquivo}"
        fi
    elif [ -e "${caso_dir}/${arquivo}" ]; then
        falha="${arquivo} não deveria existir"
    fi
    relata "erros: ${nome}" "${falha}"
}

teste_erros() {
    local msg_nome="Erro: nome de arquivo muito longo."
    local msg_entrada="Erro: não foi possível abrir o arquivo de entrada."
    local msg_saida="Erro: não foi possível abrir o arquivo de saída."
    local msg_mesmo="Erro: entrada e saída são o mesmo arquivo."
    local msg_leitura="Erro: falha ao ler o arquivo de entrada."
    local msg_escrita="Erro: falha ao gravar o arquivo de saída."

    caso_dir="${tempdir}/caso"
    nome_254="$(printf 'a%.0s' {1..254})"
    local nome_255="${nome_254}a" nome_300
    nome_300="$(printf 'b%.0s' {1..300})"
    local saida_x='0x78\n0xA\n'

    # a entrada nunca pode ser truncada por ser também a saída
    caso "saída igual à entrada" 1 "${msg_mesmo}" 'i.txt\ni.txt\n' i.txt 'x\n'
    caso "saída por caminho alternativo" 1 "${msg_mesmo}" 'i.txt\nd/../i.txt\n' i.txt 'x\n'
    caso "saída por symlink" 1 "${msg_mesmo}" 'i.txt\nl.txt\n' i.txt 'x\n'
    caso "saída por hardlink" 1 "${msg_mesmo}" 'i.txt\nh.txt\n' i.txt 'x\n'

    # uma entrada inválida não pode criar nem apagar a saída
    caso "entrada diretório preserva saída" 1 "${msg_leitura}" 'd\no.txt\n' o.txt 'manter\n'
    caso "entrada diretório não cria saída" 1 "${msg_leitura}" 'd\nnovo.txt\n' novo.txt
    caso "entrada inexistente preserva saída" 1 "${msg_entrada}" 'nao.txt\no.txt\n' o.txt 'manter\n'
    caso "entrada inexistente não cria saída" 1 "${msg_entrada}" 'nao.txt\nnovo.txt\n' novo.txt
    caso "nome de entrada vazio" 1 "${msg_entrada}" '\nnovo.txt\n' novo.txt
    caso "stdin vazio" 1 "${msg_entrada}" '' novo.txt

    # falhas na saída
    caso "saída é diretório" 1 "${msg_saida}" 'i.txt\nd\n' i.txt 'x\n'
    caso "saída em caminho inexistente" 1 "${msg_saida}" 'i.txt\nnao/o.txt\n' nao/o.txt
    caso "nome de saída vazio" 1 "${msg_saida}" 'i.txt\n\n' i.txt 'x\n'
    caso "stdin sem segundo nome" 1 "${msg_saida}" 'i.txt' i.txt 'x\n'
    if [ -w /dev/full ]; then
        caso "disco cheio" 1 "${msg_escrita}" 'i.txt\n/dev/full\n' i.txt 'x\n'
    fi

    # sequências UTF-8 cortadas pelo fim do arquivo
    caso "UTF-8 truncado em 2 bytes" 1 "${msg_leitura}" 't2.txt\nnovo.txt\n' novo.txt ''
    caso "UTF-8 truncado em 3 bytes" 1 "${msg_leitura}" 't3.txt\nnovo.txt\n' novo.txt ''
    caso "UTF-8 truncado em 4 bytes" 1 "${msg_leitura}" 't4.txt\nnovo.txt\n' novo.txt ''

    # limites do nome de arquivo
    caso "entrada com 254 caracteres" 0 "" "${nome_254}\\nnovo.txt\\n" novo.txt '0x71\n0xA\n'
    caso "saída com 254 caracteres" 0 "" "i.txt\\n${nome_254}\\n" "${nome_254}" "${saida_x}"
    caso "entrada com 255 caracteres" 1 "${msg_nome}" "${nome_255}\\nnovo.txt\\n" novo.txt
    caso "saída com 255 caracteres" 1 "${msg_nome}" "i.txt\\n${nome_255}\\n" "${nome_255}"
    caso "entrada com 300 caracteres" 1 "${msg_nome}" "${nome_300}\\nnovo.txt\\n" novo.txt
    caso "saída com 300 caracteres" 1 "${msg_nome}" "i.txt\\n${nome_300}\\n" "${nome_300}"

    # casos de borda válidos
    caso "entrada vazia cria saída vazia" 0 "" 'vazio.txt\nnovo.txt\n' novo.txt ''
    caso "entrada vazia trunca saída" 0 "" 'vazio.txt\no.txt\n' o.txt ''
    caso "sobrescreve saída maior" 0 "" 'i.txt\no.txt\n' o.txt "${saida_x}"
    caso "segundo nome sem LF final" 0 "" 'i.txt\nnovo.txt' novo.txt "${saida_x}"

    rm -rf "${caso_dir}"
}

# Compila e roda os testes de testes_unitarios/, com um resultado por função.
teste_unitario() {
    local bin="${tempdir}/unit/testes"

    if ! make -s -C testes_unitarios BUILD_DIR="${tempdir}/unit" "${bin}"; then
        relata unitário "não foi possível compilar"
        return
    fi

    "${bin}" </dev/null | sed -E 's/^(OK|FALHOU) /\1 unitário: /'
    local status="${PIPESTATUS[0]}"

    # status 1 já foi relatado por função; outro valor indica falha na própria execução
    if [ "${status}" -eq 1 ]; then
        failed=1
    elif [ "${status}" -ne 0 ]; then
        relata unitário "status ${status}"
    fi
}

main() {
    cd "$(dirname "${BASH_SOURCE[0]}")" || exit 2

    tempdir="$(mktemp -d)" || exit 2
    trap 'rm -rf "${tempdir}"' EXIT

    make -s BUILD_DIR="${tempdir}" || exit 2
    main="${tempdir}/main"

    if [ "$#" -gt 0 ]; then
        tests=("$@")
    else
        tests=()
        for f in arquivos_enunciado/teste*.txt; do
            case "${f}" in
            *_saida.txt) continue ;;
            *) tests+=("$(basename "${f}" .txt)") ;;
            esac
        done
        tests+=(exaustivo erros unitario)
    fi

    for t in "${tests[@]}"; do
        case "${t}" in
        exaustivo) teste_exaustivo ;;
        erros) teste_erros ;;
        unitario) teste_unitario ;;
        *) teste_arquivo "${t}" ;;
        esac
    done

    exit "${failed}"
}

failed=0

main "$@"
