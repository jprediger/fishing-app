#!/usr/bin/env bash
#
# validate.sh — Validação robusta do projeto (frontend Flutter + backend Spring Boot).
#
# Roda lint/formatação/análise estática e a suíte de testes dos dois lados,
# coletando TODAS as falhas (não para na primeira) e imprimindo um resumo final.
# Pensado para rodar após cada nova implementação, antes de commitar/abrir PR.
#
# Uso:
#   scripts/validate.sh                 # valida frontend e backend
#   scripts/validate.sh --frontend      # só o app Flutter
#   scripts/validate.sh --backend       # só o backend Spring Boot
#   scripts/validate.sh --fix           # aplica formatadores (dart format / spotlessApply) antes de checar
#   scripts/validate.sh --fast          # pula testes lentos (Testcontainers/Docker) — só lint + compilação
#   scripts/validate.sh --no-color      # saída sem cores
#   scripts/validate.sh -h | --help
#
# Exit code: 0 se tudo passou; caso contrário, o nº de etapas que falharam.

set -uo pipefail

# ------------------------------------------------------------------ paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BACKEND_DIR="$ROOT_DIR/backend"

# ------------------------------------------------------------------ flags
RUN_FRONTEND=0
RUN_BACKEND=0
FIX=0
FAST=0
USE_COLOR=1

while [[ $# -gt 0 ]]; do
	case "$1" in
		--frontend|--app)   RUN_FRONTEND=1 ;;
		--backend)          RUN_BACKEND=1 ;;
		--fix)              FIX=1 ;;
		--fast)             FAST=1 ;;
		--no-color)         USE_COLOR=0 ;;
		-h|--help)
			sed -n '3,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			echo "Argumento desconhecido: $1 (use --help)" >&2
			exit 2
			;;
	esac
	shift
done

# Sem alvo explícito => valida os dois.
if [[ $RUN_FRONTEND -eq 0 && $RUN_BACKEND -eq 0 ]]; then
	RUN_FRONTEND=1
	RUN_BACKEND=1
fi

# ------------------------------------------------------------------ cores
if [[ $USE_COLOR -eq 1 && -t 1 ]]; then
	BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
	BLUE=$'\033[34m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
	BOLD=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; DIM=''; RESET=''
fi

# ------------------------------------------------------------------ estado
STEP_NAMES=()
STEP_STATUS=()   # PASS | FAIL | SKIP
FAILURES=0

section() { printf '\n%s━━ %s ━━%s\n' "$BOLD$BLUE" "$1" "$RESET"; }

# run_step "Nome legível" cmd arg arg...
run_step() {
	local name="$1"; shift
	printf '%s▶ %s%s\n' "$DIM" "$name" "$RESET"
	local start; start=$(date +%s)
	if "$@"; then
		local dur=$(( $(date +%s) - start ))
		printf '%s✔ %s%s %s(%ss)%s\n' "$GREEN" "$name" "$RESET" "$DIM" "$dur" "$RESET"
		STEP_NAMES+=("$name"); STEP_STATUS+=("PASS")
	else
		local dur=$(( $(date +%s) - start ))
		printf '%s✗ %s — FALHOU%s %s(%ss)%s\n' "$RED" "$name" "$RESET" "$DIM" "$dur" "$RESET"
		STEP_NAMES+=("$name"); STEP_STATUS+=("FAIL")
		FAILURES=$(( FAILURES + 1 ))
	fi
}

skip_step() {
	local name="$1"; local why="$2"
	printf '%s⊘ %s — PULADO%s %s(%s)%s\n' "$YELLOW" "$name" "$RESET" "$DIM" "$why" "$RESET"
	STEP_NAMES+=("$name"); STEP_STATUS+=("SKIP")
}

has_docker() { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }

# ------------------------------------------------------------------ frontend
validate_frontend() {
	section "Frontend (Flutter) — $APP_DIR"
	if ! command -v flutter >/dev/null 2>&1; then
		skip_step "Flutter" "binário 'flutter' não encontrado no PATH"
		return
	fi
	cd "$APP_DIR" || return

	run_step "pub get" flutter pub get

	if [[ $FIX -eq 1 ]]; then
		run_step "dart format (apply)" dart format lib test
	else
		run_step "dart format (check)" dart format --output=none --set-exit-if-changed lib test
	fi

	run_step "flutter analyze" flutter analyze --fatal-infos --fatal-warnings

	if [[ $FAST -eq 1 ]]; then
		skip_step "flutter test" "--fast"
	else
		run_step "flutter test" flutter test --coverage
	fi
}

# ------------------------------------------------------------------ backend
validate_backend() {
	section "Backend (Spring Boot) — $BACKEND_DIR"
	cd "$BACKEND_DIR" || return
	local gw="./gradlew"
	[[ -x "$gw" ]] || gw="gradle"
	local gflags=(--console=plain)

	if [[ $FIX -eq 1 ]]; then
		run_step "spotless (apply)" "$gw" "${gflags[@]}" spotlessApply
	else
		run_step "spotless (check)" "$gw" "${gflags[@]}" spotlessCheck
	fi

	if [[ $FAST -eq 1 ]]; then
		run_step "compilação" "$gw" "${gflags[@]}" compileJava compileTestJava
		skip_step "backend test" "--fast"
	elif ! has_docker; then
		run_step "compilação" "$gw" "${gflags[@]}" compileJava compileTestJava
		skip_step "backend test" "Docker indisponível (Testcontainers exige Docker)"
	else
		run_step "backend test + jacoco" "$gw" "${gflags[@]}" test jacocoTestReport
	fi
}

# ------------------------------------------------------------------ run
START_ALL=$(date +%s)
[[ $RUN_FRONTEND -eq 1 ]] && validate_frontend
[[ $RUN_BACKEND -eq 1 ]] && validate_backend

# ------------------------------------------------------------------ resumo
section "Resumo"
for i in "${!STEP_NAMES[@]}"; do
	case "${STEP_STATUS[$i]}" in
		PASS) printf '  %s✔%s  %s\n' "$GREEN" "$RESET" "${STEP_NAMES[$i]}" ;;
		FAIL) printf '  %s✗%s  %s\n' "$RED" "$RESET" "${STEP_NAMES[$i]}" ;;
		SKIP) printf '  %s⊘%s  %s\n' "$YELLOW" "$RESET" "${STEP_NAMES[$i]}" ;;
	esac
done
TOTAL_DUR=$(( $(date +%s) - START_ALL ))

if [[ $FAILURES -eq 0 ]]; then
	printf '\n%s✔ Validação OK%s em %ss.\n' "$BOLD$GREEN" "$RESET" "$TOTAL_DUR"
	[[ $RUN_FRONTEND -eq 1 && $FAST -eq 0 ]] && printf '%s  cobertura frontend: app/coverage/lcov.info%s\n' "$DIM" "$RESET"
	[[ $RUN_BACKEND -eq 1 && $FAST -eq 0 ]] && has_docker && printf '%s  cobertura backend:  backend/build/reports/jacoco/test/html/index.html%s\n' "$DIM" "$RESET"
	exit 0
else
	printf '\n%s✗ %s etapa(s) falharam%s em %ss.\n' "$BOLD$RED" "$FAILURES" "$RESET" "$TOTAL_DUR"
	printf '%sDica: rode novamente com --fix para aplicar formatadores automaticamente.%s\n' "$DIM" "$RESET"
	exit "$FAILURES"
fi
