#!/bin/bash
# Explicit developer-only validation. Public sample queries; no user history. Never used by CI.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${LAPIS_LIVE:-}" != 1 ]]; then
    echo 'Opt in with LAPIS_LIVE=1. Review provider terms and IP quota first.' >&2
    exit 2
fi
count="${1:-5}"
if ! [[ "$count" =~ ^[0-9]+$ ]] || (( count < 1 || count > 20 )); then
    echo 'Choose 1...20 searches.' >&2
    exit 2
fi
swift build --product LapisWebSearchCLI >/dev/null
bin="$(swift build --show-bin-path)/LapisWebSearchCLI"
mkdir -p validation-local
queries=(
    'Últimas novedades de inteligencia artificial'
    'Precio de la electricidad hoy en España'
    'Investigaciones recientes sobre modelos pequeños'
    'Apple Foundation Models Swift documentation'
    'MLX Swift LM latest release'
    'Valladolid noticias tecnología'
    'What is retrieval augmented generation?'
    'Modelos de lenguaje locales para iPhone'
    'Swift structured concurrency cancellation documentation'
    'latest on-device AI research November 2026'
    'Museo Nacional de Escultura Valladolid horario'
    'How does photosynthesis work?'
    'Python 3.15 release notes'
    'energía solar autoconsumo España normativa 2026'
    '日本語 Swift concurrency documentation'
    'pequeños modelos lenguaje cuantización MLX Swift'
    'site:developer.apple.com FoundationModels LanguageModelSession'
    'LapisWebSearch nonexistentphrasezqxv91827'
    'Becilla de Valderaduey patrimonio historia'
    'Apple Foundation Models Swift documentation'
)
for ((index=0; index<count; index++)); do
    printf -v filename 'validation-local/%02d.json' "$((index+1))"
    echo "Live Firecrawl search $((index+1))/$count"
    if ! "$bin" search "${queries[index]}" --provider firecrawl --limit 3 --timeout 20 > "$filename"; then
        echo "Stopped on search failure. Inspect $filename; do not bypass restrictions or retry automatically." >&2
        exit 1
    fi
    if (( index + 1 < count )); then sleep 3; fi
done
