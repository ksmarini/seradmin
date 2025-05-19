#!/usr/bin/env bash

# Configurações rigorosas do shell
set -euo pipefail # -e: Sair em erro, -u: Variáveis não definidas são erro, -o pipefail: Erro em pipe
IFS=$'\n\t'       # Separador de campos interno mais seguro

# Definir versão do sistema
readonly SCRIPT_VERSION="1.2.0"

# Detectar o diretório raiz do projeto se não estiver definido
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
  export PROJECT_ROOT
fi

# Função para exibir a versão do script
show_version() {
  echo "Sistema de Gerenciamento de Usuários v${SCRIPT_VERSION}"
  echo "Copyright $(date +%Y)"
}

# Função para verificar requisitos do sistema
check_system_requirements() {
  # Verificar versão do Bash
  local bash_version
  bash_version=$(bash --version | head -n1 | cut -d' ' -f4 | cut -d'.' -f1)
  if [[ "$bash_version" -lt 4 ]]; then
    echo "ERRO: Este script requer Bash versão 4 ou superior." >&2
    echo "Versão atual: $(bash --version | head -n1)" >&2
    return 1
  fi

  # Verificar se está rodando em sistema Linux
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "AVISO: Este script foi projetado para sistemas Linux." >&2
    echo "Sistema atual: $(uname -s)" >&2
  fi

  return 0
}

# Trap para limpeza ou log na saída
# A função 'cleanup' deve ser definida no script que usa este core.sh se necessário.
_script_name_for_trap_=$(basename "${BASH_SOURCE[-1]}") # Pega o nome do script que está saindo

_core_cleanup() {
  local exit_status=$?

  # Registrar saída do script
  if type log_info &>/dev/null; then
    if [[ $exit_status -eq 0 ]]; then
      log_info "[${_script_name_for_trap_}] Script encerrado com sucesso (status: ${exit_status})"
    else
      log_error "[${_script_name_for_trap_}] Script encerrado com erro (status: ${exit_status})"
    fi
  else
    echo "[${_script_name_for_trap_}] Script encerrado com status: ${exit_status}" >&2
  fi

  # Limpar arquivos temporários
  if [[ -n "${TEMP_FILES:-}" ]]; then
    for temp_file in "${TEMP_FILES[@]}"; do
      if [[ -f "$temp_file" ]]; then
        rm -f "$temp_file"
      fi
    done
  fi

  # Chamar função de limpeza personalizada se existir
  if function_exists "cleanup"; then
    cleanup
  fi

  return "${exit_status}"
}
trap _core_cleanup EXIT

# Função para capturar sinais de interrupção
_handle_interrupt() {
  echo -e "\nOperação interrompida pelo usuário." >&2
  exit 130 # 128 + 2 (SIGINT)
}
trap _handle_interrupt INT

# Função utilitária para verificar se uma função existe
function_exists() {
  declare -F "$1" >/dev/null
  return $?
}

# Função para criar arquivos temporários seguros
create_temp_file() {
  local prefix="${1:-temp}"
  local temp_file

  # Inicializar array se não existir
  if [[ -z "${TEMP_FILES:-}" ]]; then
    TEMP_FILES=()
  fi

  # Criar arquivo temporário
  temp_file=$(mktemp "/tmp/${prefix}.XXXXXX")
  TEMP_FILES+=("$temp_file")

  echo "$temp_file"
}

# Função para verificar se o usuário é root
is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

# Função para verificar se um comando existe
command_exists() {
  command -v "$1" &>/dev/null
}

# Função para obter o valor de uma variável de ambiente ou usar valor padrão
get_env_or_default() {
  local var_name="$1"
  local default_value="$2"

  if [[ -n "${!var_name:-}" ]]; then
    echo "${!var_name}"
  else
    echo "$default_value"
  fi
}

# Função para executar um comando com timeout
run_with_timeout() {
  local timeout_seconds="$1"
  shift
  local cmd=("$@")

  # Verificar se o comando timeout existe
  if command_exists timeout; then
    timeout "$timeout_seconds" "${cmd[@]}"
    return $?
  else
    # Fallback se o comando timeout não existir
    # Executar em background com um timer
    ("${cmd[@]}") &
    local pid=$!

    # Esperar pelo tempo especificado
    local i=0
    while [[ $i -lt $timeout_seconds ]] && kill -0 $pid 2>/dev/null; do
      sleep 1
      i=$((i + 1))
    done

    # Verificar se o processo ainda está rodando
    if kill -0 $pid 2>/dev/null; then
      kill -TERM $pid
      sleep 1
      # Forçar kill se ainda estiver rodando
      if kill -0 $pid 2>/dev/null; then
        kill -KILL $pid
      fi
      return 124 # Código de saída do timeout
    fi

    # Esperar pelo processo e retornar seu código de saída
    wait $pid
    return $?
  fi
}

# Verificar requisitos do sistema ao carregar o script
check_system_requirements || {
  echo "AVISO: O sistema pode não atender a todos os requisitos." >&2
}

# Exportar funções para uso em subshells
export -f function_exists create_temp_file is_root command_exists get_env_or_default run_with_timeout
