#!/usr/bin/env bash

# Configurações de log
LOG_LEVEL=${LOG_LEVEL:-INFO}                                      # Nível de log: DEBUG, INFO, WARN, ERROR
LOG_MAX_SIZE=${LOG_MAX_SIZE:-10485760}                            # Tamanho máximo do arquivo de log (10MB)
LOG_BACKUP_COUNT=${LOG_BACKUP_COUNT:-5}                           # Número de backups a manter
LOG_TIMESTAMP_FORMAT=${LOG_TIMESTAMP_FORMAT:-"%Y-%m-%d %H:%M:%S"} # Formato do timestamp
LOG_USE_COLORS=${LOG_USE_COLORS:-true}                            # Usar cores no terminal

# Cores ANSI para terminal
if [[ "$LOG_USE_COLORS" = "true" ]]; then
  readonly COLOR_RESET="\033[0m"
  readonly COLOR_DEBUG="\033[36m" # Ciano
  readonly COLOR_INFO="\033[32m"  # Verde
  readonly COLOR_WARN="\033[33m"  # Amarelo
  readonly COLOR_ERROR="\033[31m" # Vermelho
  readonly COLOR_BOLD="\033[1m"   # Negrito
else
  readonly COLOR_RESET=""
  readonly COLOR_DEBUG=""
  readonly COLOR_INFO=""
  readonly COLOR_WARN=""
  readonly COLOR_ERROR=""
  readonly COLOR_BOLD=""
fi

# Mapeamento de níveis de log para valores numéricos
declare -A LOG_LEVELS
LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)

# Função para verificar se um nível de log deve ser registrado
should_log() {
  local level="$1"

  # Verificar se o nível é válido
  if [[ -z "${LOG_LEVELS[$level]}" ]]; then
    echo "Nível de log inválido: $level" >&2
    return 1
  fi

  # Verificar se o nível atual é maior ou igual ao nível configurado
  if [[ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[$LOG_LEVEL]} ]]; then
    return 0 # Deve logar
  else
    return 1 # Não deve logar
  fi
}

# Função principal de log
_log_message() {
  local level="$1"
  shift
  local message="$*"

  # Verificar se deve logar este nível
  if ! should_log "$level"; then
    return 0
  fi

  local timestamp
  timestamp=$(date +"$LOG_TIMESTAMP_FORMAT")

  # Selecionar cor com base no nível
  local color=""
  case "$level" in
  DEBUG) color="$COLOR_DEBUG" ;;
  INFO) color="$COLOR_INFO" ;;
  WARN) color="$COLOR_WARN" ;;
  ERROR) color="$COLOR_ERROR" ;;
  *) color="$COLOR_RESET" ;;
  esac

  # Formatar a mensagem para o terminal (com cores)
  local terminal_entry="${color}[${timestamp}] [${COLOR_BOLD}${level}${COLOR_RESET}${color}] ${message}${COLOR_RESET}"

  # Formatar a mensagem para o arquivo de log (sem cores)
  local file_entry="[${timestamp}] [${level}] ${message}"

  # SEMPRE exibir no terminal para visibilidade (usando stderr)
  echo -e "${terminal_entry}" >&2

  # Tenta escrever no arquivo de log
  if [[ -n "${LOG_FILE:-}" ]]; then
    # Criar diretório de log se não existir
    local log_dir
    log_dir=$(dirname "${LOG_FILE}")
    if [[ ! -d "$log_dir" ]]; then
      mkdir -p "$log_dir" 2>/dev/null || true
    fi

    # Tentar escrever no arquivo
    if [[ -w "$log_dir" || -w "${LOG_FILE}" ]]; then
      echo "${file_entry}" >>"${LOG_FILE}"
    else
      echo -e "${COLOR_WARN}[${timestamp}] [WARN] Log file ${LOG_FILE} não gravável.${COLOR_RESET}" >&2
    fi
  fi
}

# Funções específicas para cada nível de log
log_debug() {
  _log_message "DEBUG" "$@"
}

log_info() {
  _log_message "INFO" "$@"
}

log_warn() {
  _log_message "WARN" "$@"
}

log_error() {
  _log_message "ERROR" "$@"
}

# Função para desativar cores (útil para ambientes que não suportam cores)
disable_log_colors() {
  LOG_USE_COLORS=false
  export LOG_USE_COLORS
}

# Função para ativar cores
enable_log_colors() {
  LOG_USE_COLORS=true
  export LOG_USE_COLORS
}

# Exportar funções para uso em subshells
export -f _log_message log_debug log_info log_warn log_error disable_log_colors enable_log_colors
export LOG_LEVEL LOG_LEVELS LOG_USE_COLORS
