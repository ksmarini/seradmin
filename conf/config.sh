#!/usr/bin/env bash

# Este arquivo define constantes e configurações padrão

# Detectar o diretório raiz do projeto
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  # Se não estiver definido, calcular com base no caminho deste script
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
  export PROJECT_ROOT
fi

# Carregar variáveis de ambiente de arquivo .env se existir
ENV_FILE="${PROJECT_ROOT}/conf/.env" # Alterado para procurar em conf/.env
if [[ -f "$ENV_FILE" ]]; then
  echo "Carregando variáveis de ambiente de $ENV_FILE"
  # Ler o arquivo .env linha por linha
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Ignorar comentários e linhas vazias
    if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
      # Exportar a variável
      export "$line"
    fi
  done <"$ENV_FILE"
fi

# Detectar o grupo administrativo correto para a distribuição
if grep -q "Arch Linux" /etc/os-release 2>/dev/null; then
  readonly ADMIN_GROUP="wheel"
else
  # Para Ubuntu/Debian e outros
  readonly ADMIN_GROUP="sudo"
fi
echo "Configurado grupo administrativo: $ADMIN_GROUP"

# Caminhos de arquivos
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly LOG_FILE="${LOG_DIR}/user_creator.log"
readonly CSV_FILE_PATH="${PROJECT_ROOT}/usuarios.csv"
readonly TEMPLATE_DIR="${PROJECT_ROOT}/templates"

# Configurações de CSV
readonly CSV_DELIMITER="${CSV_DELIMITER:-;}"
readonly CSV_HAS_HEADER="${CSV_HAS_HEADER:-false}"
readonly CSV_EXPECTED_COLUMNS="${CSV_EXPECTED_COLUMNS:-3}"

# Configurações de senha
readonly PASSWORD_MIN_LENGTH="${PASSWORD_MIN_LENGTH:-12}"
readonly PASSWORD_REQUIRE_SPECIAL="${PASSWORD_REQUIRE_SPECIAL:-true}"

# Configurações de log
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"           # DEBUG, INFO, WARN, ERROR
readonly LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}" # 10MB
readonly LOG_BACKUP_COUNT="${LOG_BACKUP_COUNT:-5}"
readonly LOG_TIMESTAMP_FORMAT="${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}"
readonly LOG_USE_COLORS="${LOG_USE_COLORS:-true}"

# Configurações de e-mail
readonly EMAIL_USE_HTML="${EMAIL_USE_HTML:-false}"
readonly EMAIL_SUBJECT_PREFIX="${EMAIL_SUBJECT_PREFIX:-[IMPORTANTE]}"

# Garantir a existência dos diretórios necessários
for dir in "${LOG_DIR}" "${TEMPLATE_DIR}"; do
  if [[ ! -d "${dir}" ]]; then
    mkdir -p "${dir}" 2>/dev/null || {
      echo "AVISO: Não foi possível criar o diretório em ${dir}." >&2
    }
  fi
done

# Validar configurações críticas
validate_config() {
  local errors=0

  # Verificar se os diretórios existem
  for dir in "${PROJECT_ROOT}" "${LOG_DIR}" "${TEMPLATE_DIR}"; do
    if [[ ! -d "$dir" ]]; then
      echo "ERRO: Diretório não encontrado: $dir" >&2
      errors=$((errors + 1))
    fi
  done

  # Verificar se os templates existem
  for tpl in "${TEMPLATE_DIR}/email_text.tpl" "${TEMPLATE_DIR}/email_html.tpl"; do
    if [[ ! -f "$tpl" ]]; then
      echo "ERRO: Template não encontrado: $tpl" >&2
      errors=$((errors + 1))
    fi
  done

  # Verificar variáveis de ambiente para envio de e-mail
  if [[ "${DRY_RUN:-false}" = "false" ]]; then
    for var in SMTP_SERVER SMTP_USER SMTP_PASSWORD FROM_EMAIL; do
      if [[ -z "${!var:-}" ]]; then
        echo "ERRO: Variável de ambiente não definida: $var" >&2
        errors=$((errors + 1))
      fi
    done
  fi

  if [[ $errors -gt 0 ]]; then
    echo "Encontrados $errors erros na configuração." >&2
    return 1
  fi

  echo "Configuração validada com sucesso."
  return 0
}

# Exportar variáveis para uso em outros scripts
export ADMIN_GROUP LOG_DIR LOG_FILE CSV_FILE_PATH TEMPLATE_DIR
export CSV_DELIMITER CSV_HAS_HEADER CSV_EXPECTED_COLUMNS
export PASSWORD_MIN_LENGTH PASSWORD_REQUIRE_SPECIAL
export LOG_LEVEL LOG_MAX_SIZE LOG_BACKUP_COUNT LOG_TIMESTAMP_FORMAT LOG_USE_COLORS
export EMAIL_USE_HTML EMAIL_SUBJECT_PREFIX
