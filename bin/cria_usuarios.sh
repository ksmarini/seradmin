#!/bin/bash

##############################################
# Script para Criação de Usuários em Sistema Linux
#
# Este script lê um arquivo CSV contendo informações de usuários (usuario;departamento;email)
# e cria usuários no sistema com permissões específicas. Ele também envia
# credenciais temporárias via e-mail com informações detalhadas do sistema.
#
# Requisitos:
# - As variáveis de ambiente necessárias devem ser definidas.
# - O script deve ser executado como root para realizar as operações de
#   criação de usuários.
#
# Opções:
#  -n, --dry-run: Ativa o modo Dry Run (simulação, nenhuma alteração real será feita).
#  -t, --text: Envia e-mails em formato texto simples em vez de HTML.
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

DRY_RUN=false # Flag para indicar se o modo de simulação está ativado
USE_HTML=true # Flag para indicar se os e-mails devem ser enviados em formato HTML (agora padrão é true)

# Garantir que o diretório de logs exista
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Garantir que o diretório de templates exista
if [ ! -d "$TEMPLATE_DIR" ]; then
  mkdir -p "$TEMPLATE_DIR" 2>/dev/null || {
    echo "ERRO: Não foi possível criar o diretório de templates em ${TEMPLATE_DIR}." >&2
    exit 1
  }
fi

# Verificar se os templates existem
if [ ! -f "${TEMPLATE_DIR}/email_text.tpl" ] || [ ! -f "${TEMPLATE_DIR}/email_html.tpl" ]; then
  echo "ERRO: Templates de e-mail não encontrados em ${TEMPLATE_DIR}." >&2
  echo "Certifique-se de que os arquivos email_text.tpl e email_html.tpl existem neste diretório." >&2
  exit 1
fi

# Carregar bibliotecas
source "${PROJECT_ROOT}/lib/core.sh"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/system_checks.sh"
source "${PROJECT_ROOT}/lib/csv_utils.sh"
source "${PROJECT_ROOT}/lib/user_operations.sh"
source "${PROJECT_ROOT}/lib/email_services.sh" # Usar a versão com suporte a templates

# Registrar o grupo administrativo no log
log_info "Configurado grupo administrativo: $ADMIN_GROUP"

##############################################
# Processamento de Opções de Linha de Comando
##############################################
usage() {
  echo "Uso: $0 [-n | --dry-run] [-t | --text]" >&2
  echo "  -n, --dry-run: Ativa o modo Dry Run (simulação, nenhuma alteração real será feita)." >&2
  echo "  -t, --text: Envia e-mails em formato texto simples em vez de HTML." >&2
  exit 1
}

# Processar argumentos de linha de comando
while [[ $# -gt 0 ]]; do
  case "$1" in
  -n | --dry-run)
    DRY_RUN=true
    shift
    ;;
  -t | --text)
    USE_HTML=false
    shift
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

##############################################
# Validação Inicial
##############################################

# A mensagem de log_info será prefixada com [DRY RUN] se DRY_RUN for true.
log_info "Verificando o estado do script."

if [ "$DRY_RUN" = "true" ]; then
  log_info "MODO DRY RUN ATIVADO. Nenhuma alteração real será feita no sistema."
fi

if [ "$USE_HTML" = "false" ]; then
  log_info "Modo texto simples ativado para e-mails."
fi

# Verifica variáveis críticas de ambiente - MELHORIA: Verificar mesmo em modo dry-run
missing_vars=()
for var in SMTP_SERVER SMTP_USER SMTP_PASSWORD FROM_EMAIL; do
  [ -z "${!var:-}" ] && missing_vars+=("$var")
done

if [ ${#missing_vars[@]} -gt 0 ]; then
  if [ "$DRY_RUN" = "true" ]; then
    log_warn "Variáveis de ambiente para envio de e-mail não definidas:"
    printf '• %s\n' "${missing_vars[@]}" >&2
    log_warn "Estas variáveis serão necessárias para execução real."
  else
    log_error "Variáveis de ambiente para envio de e-mail não definidas:"
    printf '• %s\n' "${missing_vars[@]}" >&2
    log_info "Defina-as com 'export' antes de executar o script."
    exit 1
  fi
fi

# Verifica se o script está sendo executado como root
if [ "$(id -u)" -ne 0 ]; then
  if [ "$DRY_RUN" = "true" ]; then
    log_warn "O script normalmente requer execução como root."
  else
    log_error "Este script deve ser executado como root!"
    exit 1
  fi
fi

# Adicionar 'cat' à lista de dependências para leitura de templates
check_dependencies

##############################################
# Processamento Principal
##############################################

log_info "Iniciando processo de criação de usuários."

# Valida se o arquivo CSV existe e é legível
if [ ! -f "$CSV_FILE" ]; then
  log_error "Arquivo CSV '$CSV_FILE' não encontrado."
  exit 1
elif [ ! -r "$CSV_FILE" ]; then
  log_error "Arquivo CSV '$CSV_FILE' não pode ser lido (verifique as permissões)."
  exit 1
fi

# Habilitar extglob para trim de espaços (Bash 4+)
shopt -s extglob

# Processa cada linha do arquivo CSV
while IFS=';' read -r usuario_raw departamento_raw email_raw || [[ -n "$usuario_raw" ]]; do
  # Remover espaços no início e fim de cada campo
  usuario=$(trim_whitespace "$usuario_raw")
  departamento=$(trim_whitespace "$departamento_raw")
  email=$(trim_whitespace "$email_raw")

  # Pular linhas vazias ou onde usuário/email são vazios após trim
  if [ -z "$usuario" ] && [ -z "$departamento" ] && [ -z "$email" ]; then
    continue # Linha completamente vazia, pular
  fi
  if [ -z "$usuario" ] || [ -z "$email" ]; then
    log_warn "Linha inválida no CSV (usuário ou e-mail faltando): '$usuario_raw;$departamento_raw;$email_raw'"
    continue
  fi

  # Validação do nome de usuário
  if ! validate_username_format "$usuario"; then
    continue
  fi

  # Valida o formato do e-mail
  if ! validate_email_format "$email"; then
    continue
  fi

  # Verifica se o usuário já existe
  if user_exists "$usuario"; then
    log_warn "Usuário '$usuario' já existe. Pulando..."
    continue
  fi

  # Gera uma senha e realiza o processo de criação do usuário
  password=$(generate_password)

  if [ "$DRY_RUN" = "true" ]; then
    log_info "Simulação para usuário '$usuario':"
    log_info "  Criaria usuário: $usuario"
    log_info "  Comando (simulado): sudo useradd -m -s /bin/bash -G \"$ADMIN_GROUP\" -c \"$usuario - $departamento\" -p 'HASH_DA_SENHA' \"$usuario\""
    log_info "  Comando (simulado): sudo passwd --expire \"$usuario\""
    log_info "  Comando (simulado): sudo chmod 700 \"/home/$usuario\""
    log_info "  Comando (simulado): sudo chown -R \"$usuario:$usuario\" \"/home/$usuario\""
  else
    log_info "Processando criação do usuário '$usuario'..."

    # Criar o usuário usando a função centralizada
    if ! create_system_user "$usuario" "$departamento" "$password" "$ADMIN_GROUP"; then
      unset password # Limpar senha
      continue
    fi
  fi

  # Enviar e-mail com credenciais do usuário usando o sistema de templates
  send_user_credentials_email "$email" "$usuario" "$password" "$USE_HTML" "$DRY_RUN"
  send_email_rc=$?

  if [ "$send_email_rc" -ne 0 ]; then
    if [ "$DRY_RUN" = "false" ]; then
      log_error "Falha ao enviar e-mail para '$email'. Verifique as configurações SMTP e os templates."
    fi
  else
    if [ "$DRY_RUN" = "false" ]; then
      log_info "SUCESSO: E-mail enviado para '$email' referente ao usuário '$usuario'."
    fi
  fi

  unset password                                                   # Limpar senha da memória
  log_info "-----------------------------------------------------" # Separador visual no log

done < <(read_csv_content "$CSV_FILE")

# Desabilitar extglob
shopt -u extglob

log_info "Processo concluído. Verifique o log completo em: $LOG_FILE"
