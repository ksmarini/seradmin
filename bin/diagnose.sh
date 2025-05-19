#!/usr/bin/env bash

##############################################
# Script de diagnóstico para o sistema de gerenciamento de usuários
# Este script verifica a configuração e o ambiente para identificar problemas
#
# Opções:
#  -v, --verbose: Exibe informações detalhadas durante o diagnóstico
#  -f, --fix: Tenta corrigir problemas simples automaticamente
#  -h, --help: Exibe ajuda sobre o uso do script
##############################################

# Definir o diretório do script e o diretório raiz do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)" # Subir um nível para chegar à raiz
export SCRIPT_DIR PROJECT_ROOT

# Carregar variáveis de ambiente diretamente do arquivo .env
ENV_FILE="${PROJECT_ROOT}/conf/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo "Carregando variáveis de ambiente de $ENV_FILE"

  # Método mais robusto para carregar variáveis com ou sem aspas
  set -a # Ativa exportação automática de variáveis
  source <(grep -v '^#' "$ENV_FILE" | grep -v '^[[:space:]]*$')
  set +a # Desativa exportação automática
else
  echo "AVISO: Arquivo $ENV_FILE não encontrado. Variáveis de ambiente devem ser definidas manualmente."
fi

# Definir caminhos de arquivos relativos à raiz do projeto
CSV_FILE="${PROJECT_ROOT}/usuarios.csv"          # Caminho para o arquivo CSV com dados de usuários
LOG_FILE="${PROJECT_ROOT}/logs/user_creator.log" # Caminho para o arquivo de log
TEMPLATE_DIR="${PROJECT_ROOT}/templates"         # Diretório de templates

# Detectar o grupo administrativo correto para a distribuição
if [[ -n "${ADMIN_GROUP:-}" ]]; then
  # Usar o grupo definido no .env
  echo "Usando grupo administrativo definido na configuração: $ADMIN_GROUP"
else
  # Detectar automaticamente
  if grep -q "Arch Linux" /etc/os-release 2>/dev/null; then
    ADMIN_GROUP="wheel"
  else
    # Para Ubuntu/Debian e outros
    ADMIN_GROUP="sudo"
  fi
  echo "Grupo administrativo detectado automaticamente: $ADMIN_GROUP"
fi

# Definir arquivo de log específico para diagnóstico
DIAG_LOG_FILE="${PROJECT_ROOT}/logs/diagnose_$(date +%Y%m%d_%H%M%S).log"
export LOG_FILE="$DIAG_LOG_FILE"

# Garantir que o diretório de logs exista
mkdir -p "$(dirname "$DIAG_LOG_FILE")" 2>/dev/null || true

# Flags para opções de linha de comando
VERBOSE=false
FIX_ISSUES=false

# Carregar bibliotecas necessárias
source "${PROJECT_ROOT}/lib/core.sh"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/system_checks.sh"
source "${PROJECT_ROOT}/lib/csv_utils.sh"
source "${PROJECT_ROOT}/lib/user_operations.sh"
source "${PROJECT_ROOT}/lib/email_services.sh"

##############################################
# Processamento de Opções de Linha de Comando
##############################################
usage() {
  echo "Uso: $0 [opções]" >&2
  echo "Opções:" >&2
  echo "  -v, --verbose  Exibe informações detalhadas durante o diagnóstico" >&2
  echo "  -f, --fix      Tenta corrigir problemas simples automaticamente" >&2
  echo "  -h, --help     Exibe esta ajuda" >&2
  echo >&2
  echo "Exemplo:" >&2
  echo "  $0 --verbose" >&2
  exit 1
}

# Processar argumentos de linha de comando
while [[ $# -gt 0 ]]; do
  case "$1" in
  -v | --verbose)
    VERBOSE=true
    shift
    ;;
  -f | --fix)
    FIX_ISSUES=true
    shift
    ;;
  -h | --help)
    usage
    ;;
  --)
    shift
    break
    ;;
  -*)
    echo "Opção inválida: $1" >&2
    usage
    ;;
  *)
    break
    ;;
  esac
done

# Função para exibir cabeçalho
print_header() {
  local title="$1"
  local width=60
  local padding=$(((width - ${#title}) / 2))

  log_info ""
  log_info "$(printf '=%.0s' $(seq 1 $width))"
  log_info "$(printf "%${padding}s%s%${padding}s\n" "" "$title" "")"
  log_info "$(printf '=%.0s' $(seq 1 $width))"
  log_info ""
}

# Função para verificar um item e exibir o resultado
check_item() {
  local description="$1"
  local check_command="$2"
  local fix_command="${3:-}"
  local padding_dots=$(printf '%.*s' $((50 - ${#description})) "............................................")

  printf "  %s %s " "$description" "$padding_dots"

  if eval "$check_command"; then
    log_info "$(printf "  %s %s \e[32m[OK]\e[0m" "$description" "$padding_dots")"
    return 0
  else
    log_error "$(printf "  %s %s \e[31m[FALHA]\e[0m" "$description" "$padding_dots")"

    # Tentar corrigir se o modo de correção estiver ativado e um comando de correção for fornecido
    if [[ "$FIX_ISSUES" = "true" && -n "$fix_command" ]]; then
      log_warn "Tentando corrigir: $description"
      if eval "$fix_command"; then
        log_info "Correção aplicada com sucesso!"
        # Verificar novamente após a correção
        if eval "$check_command"; then
          log_info "$(printf "  %s %s \e[32m[CORRIGIDO]\e[0m" "$description" "$padding_dots")"
          return 0
        else
          log_error "A correção não resolveu o problema."
        fi
      else
        log_error "Falha ao aplicar a correção."
      fi
    fi

    return 1
  fi
}

# Iniciar diagnóstico
print_header "DIAGNÓSTICO DO SISTEMA DE GERENCIAMENTO DE USUÁRIOS"
log_info "Data: $(date)"
log_info "Versão: ${SCRIPT_VERSION:-1.0.0}"
log_info "Diretório do projeto: $PROJECT_ROOT"
log_info "Log de diagnóstico: $DIAG_LOG_FILE"
log_info "Grupo administrativo: $ADMIN_GROUP"
log_info ""

if [[ "$VERBOSE" = "true" ]]; then
  log_info "Modo detalhado ativado"
fi

if [[ "$FIX_ISSUES" = "true" ]]; then
  log_info "Modo de correção automática ativado"
fi

# Verificar ambiente do sistema
print_header "AMBIENTE DO SISTEMA"

check_item "Versão do Bash" "bash --version | head -n1 | grep -q 'version [4-9]'"
check_item "Usuário é root ou pode usar sudo" "is_root || command_exists sudo"
check_item "Sistema operacional" "uname -a | grep -q 'Linux'"
check_item "Espaço em disco (mínimo 100MB)" "check_disk_space 100 '/'"

# Verificar dependências
print_header "DEPENDÊNCIAS DO SISTEMA"

for cmd in openssl sudo curl hostname awk ip tr head tee grep useradd passwd chmod chown date cat sed fold shuf; do
  check_item "Comando $cmd" "command_exists $cmd" "[ \"$FIX_ISSUES\" = \"true\" ] && sudo apt-get install -y $cmd 2>/dev/null || sudo pacman -S --noconfirm $cmd 2>/dev/null || true"
done

# Verificar estrutura de diretórios
print_header "ESTRUTURA DE DIRETÓRIOS"

for dir in "${PROJECT_ROOT}/lib" "${PROJECT_ROOT}/conf" "${PROJECT_ROOT}/logs" "${PROJECT_ROOT}/templates"; do
  check_item "Diretório $dir" "[ -d \"$dir\" ]" "mkdir -p \"$dir\""
done

# Verificar arquivos essenciais
print_header "ARQUIVOS ESSENCIAIS"

for file in "${PROJECT_ROOT}/bin/cria_usuarios.sh" "${PROJECT_ROOT}/lib/core.sh" "${PROJECT_ROOT}/lib/logging.sh" "${PROJECT_ROOT}/lib/email_services.sh" "${PROJECT_ROOT}/lib/user_operations.sh" "${PROJECT_ROOT}/lib/csv_utils.sh" "${PROJECT_ROOT}/lib/system_checks.sh" "${PROJECT_ROOT}/conf/config.sh"; do
  check_item "Arquivo $file" "[ -f \"$file\" -a -r \"$file\" ]"
done

# Verificar templates
print_header "TEMPLATES DE E-MAIL"

for tpl in "${PROJECT_ROOT}/templates/email_text.tpl" "${PROJECT_ROOT}/templates/email_html.tpl"; do
  check_item "Template $tpl" "[ -f \"$tpl\" -a -r \"$tpl\" ]"
done

# Verificar arquivo CSV
print_header "ARQUIVO CSV"

check_item "Arquivo CSV existe" "[ -f \"${CSV_FILE}\" -a -r \"${CSV_FILE}\" ]"

if [ -f "${CSV_FILE}" ]; then
  csv_lines=$(grep -v '^\s*#' "${CSV_FILE}" | grep -v '^\s*$' | wc -l)
  check_item "Arquivo CSV contém dados" "[ $csv_lines -gt 0 ]"

  # Verificar formato do CSV
  if command_exists validate_csv_format; then
    check_item "Formato do CSV válido" "validate_csv_format \"${CSV_FILE}\" &>/dev/null"
  else
    # Verificação simplificada se a função não existir
    check_item "Formato do CSV (verificação básica)" "grep -v '^\s*#' \"${CSV_FILE}\" | grep -q ';'"
  fi
fi

# Verificar configurações de e-mail
print_header "CONFIGURAÇÕES DE E-MAIL"

for var in SMTP_SERVER SMTP_USER SMTP_PASSWORD FROM_EMAIL; do
  if [ "$var" = "SMTP_PASSWORD" ]; then
    # Não mostrar a senha, apenas verificar se está definida
    check_item "Variável $var definida" "[ -n \"\${$var:-}\" ]"
  else
    check_item "Variável $var definida" "[ -n \"\${$var:-}\" ]"
    if [ -n "${!var:-}" ] && [ "$VERBOSE" = "true" ]; then
      log_info "    → Valor: ${!var}"
    fi
  fi
done

# Testar conectividade SMTP
if [ -n "${SMTP_SERVER:-}" ]; then
  server_port=(${SMTP_SERVER//:/ })
  server="${server_port[0]}"
  port="${server_port[1]:-587}"

  check_item "Conectividade com servidor SMTP" "timeout 5 bash -c \"</dev/tcp/$server/$port\" &>/dev/null"
fi

# Verificar permissões
print_header "PERMISSÕES"

check_item "Permissão de escrita em logs" "[ -w \"${PROJECT_ROOT}/logs\" ]" "mkdir -p \"${PROJECT_ROOT}/logs\" && chmod 755 \"${PROJECT_ROOT}/logs\""
check_item "Permissão de execução no script principal" "[ -x \"${PROJECT_ROOT}/bin/cria_usuarios.sh\" ]" "chmod +x \"${PROJECT_ROOT}/bin/cria_usuarios.sh\""

# Verificar grupo administrativo
print_header "VERIFICAÇÃO DO GRUPO ADMINISTRATIVO"

check_item "Grupo $ADMIN_GROUP existe" "getent group \"$ADMIN_GROUP\" &>/dev/null"

# Verificar geração de senhas
print_header "VERIFICAÇÃO DE GERAÇÃO DE SENHAS"

if command_exists generate_password; then
  test_password=$(generate_password 2>/dev/null)
  check_item "Geração de senha" "[ -n \"$test_password\" ]"

  if [ -n "$test_password" ] && [ "$VERBOSE" = "true" ]; then
    log_info "    → Senha de teste gerada: $test_password"
  fi

  if command_exists check_password_strength && [ -n "$test_password" ]; then
    check_item "Força da senha" "check_password_strength \"$test_password\""
  fi
fi

# Resumo final
print_header "RESUMO DO DIAGNÓSTICO"

log_info "O diagnóstico foi concluído e salvo em: $DIAG_LOG_FILE"
log_info ""
log_info "Para resolver problemas identificados:"
log_info "1. Verifique as permissões dos diretórios e arquivos"
log_info "2. Certifique-se de que todas as dependências estão instaladas"
log_info "3. Configure corretamente as variáveis de ambiente para SMTP no arquivo .env"
log_info "4. Verifique se os templates de e-mail existem e estão corretos"
log_info ""
log_info "Para mais informações, execute:"
log_info "  $0 --help"

# Salvar uma cópia do diagnóstico no log
if [ -n "$DIAG_LOG_FILE" ]; then
  echo "Diagnóstico concluído em $(date)" >>"$DIAG_LOG_FILE"
fi

exit 0
