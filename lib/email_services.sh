#!/usr/bin/env bash

# Módulo aprimorado para serviços de e-mail
# Depende de logging.sh

# Valida o formato de um endereço de e-mail
validate_email_format() {
  local email="$1"
  if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    return 0
  else
    log_error "Endereço de e-mail '$email' possui formato inválido."
    return 1
  fi
}

# Obtém informações do sistema para incluir nos e-mails
get_system_info() {
  local info_type="$1"

  case "$info_type" in
  "ip")
    # Obtém o endereço IP principal da máquina
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$ip" ]] && ip=$(hostname)
    echo "$ip"
    ;;
  "hostname")
    # Obtém o nome do host
    hostname
    ;;
  "os")
    # Obtém informações sobre o sistema operacional
    if [ -f /etc/os-release ]; then
      source /etc/os-release
      echo "${PRETTY_NAME:-${NAME:-"Linux"}}"
    else
      echo "Linux"
    fi
    ;;
  "kernel")
    # Obtém a versão do kernel
    uname -r
    ;;
  "uptime")
    # Obtém o uptime do sistema
    uptime -p
    ;;
  *)
    log_error "Tipo de informação do sistema desconhecido: $info_type"
    return 1
    ;;
  esac
}

# Cria o corpo do e-mail com informações do usuário e do sistema usando templates
create_email_body() {
  local username="$1"
  local password="$2"
  local format="${3:-plain}" # plain ou html
  local template_dir="${PROJECT_ROOT}/templates"

  # Obter informações do sistema
  local hostname=$(get_system_info "hostname")
  local ip_address=$(get_system_info "ip")
  local os_info=$(get_system_info "os")
  local kernel_version=$(get_system_info "kernel")
  local uptime=$(get_system_info "uptime")

  # Selecionar o template apropriado
  local template_file
  if [[ "$format" == "html" ]]; then
    template_file="${template_dir}/email_html.tpl"
  else
    template_file="${template_dir}/email_text.tpl"
  fi

  # Verificar se o template existe
  if [[ ! -f "$template_file" ]]; then
    log_error "Template de e-mail não encontrado: $template_file"
    return 1
  fi

  # Ler o template
  local template
  template=$(cat "$template_file") || {
    log_error "Não foi possível ler o template: $template_file"
    return 1
  }

  # Substituir placeholders usando sed para maior robustez
  # Escapar caracteres especiais nas variáveis para uso seguro com sed
  local username_esc=$(printf '%s\n' "$username" | sed 's/[\/&]/\\&/g')
  local password_esc=$(printf '%s\n' "$password" | sed 's/[\/&]/\\&/g')
  local hostname_esc=$(printf '%s\n' "$hostname" | sed 's/[\/&]/\\&/g')
  local ip_address_esc=$(printf '%s\n' "$ip_address" | sed 's/[\/&]/\\&/g')
  local os_info_esc=$(printf '%s\n' "$os_info" | sed 's/[\/&]/\\&/g')
  local kernel_version_esc=$(printf '%s\n' "$kernel_version" | sed 's/[\/&]/\\&/g')
  local uptime_esc=$(printf '%s\n' "$uptime" | sed 's/[\/&]/\\&/g')

  # Aplicar substituições
  local body="$template"
  body=$(echo "$body" | sed "s/{{USERNAME}}/$username_esc/g")
  body=$(echo "$body" | sed "s/{{PASSWORD}}/$password_esc/g")
  body=$(echo "$body" | sed "s/{{HOSTNAME}}/$hostname_esc/g")
  body=$(echo "$body" | sed "s/{{IP_ADDRESS}}/$ip_address_esc/g")
  body=$(echo "$body" | sed "s/{{OS_INFO}}/$os_info_esc/g")
  body=$(echo "$body" | sed "s/{{KERNEL_VERSION}}/$kernel_version_esc/g")
  body=$(echo "$body" | sed "s/{{UPTIME}}/$uptime_esc/g")

  echo "$body"
  return 0
}

# Envia e-mail com credenciais do usuário
send_user_credentials_email() {
  local to_email="$1"
  local username="$2"
  local password="$3"
  local use_html="${4:-false}"
  local dry_run="${5:-false}"

  # Validar parâmetros
  if [[ -z "$to_email" || -z "$username" || -z "$password" ]]; then
    log_error "Parâmetros insuficientes para envio de e-mail."
    return 1
  fi

  # Validar formato do e-mail
  if ! validate_email_format "$to_email"; then
    return 1
  fi

  # Determinar formato do e-mail
  local format="plain"
  [[ "$use_html" == "true" ]] && format="html"

  # Criar corpo do e-mail
  local body
  body=$(create_email_body "$username" "$password" "$format")
  if [[ $? -ne 0 ]]; then
    log_error "Falha ao criar corpo do e-mail para o usuário '$username'."
    return 1
  fi

  # Definir assunto do e-mail
  local hostname=$(get_system_info "hostname")
  local subject="${EMAIL_SUBJECT_PREFIX:-[IMPORTANTE]} Credenciais de Acesso - Servidor $hostname"

  # Modo de simulação
  if [[ "$dry_run" == "true" ]]; then
    log_info "Simulação: Enviaria e-mail para '$to_email' com assunto '$subject'."
    log_info "Conteúdo do e-mail (simulação):"
    echo "--- INÍCIO CORPO E-MAIL (SIMULAÇÃO) ---"
    echo -e "[ESTE É UM E-MAIL DE SIMULAÇÃO - NENHUMA CONTA FOI CRIADA]\\n\\n$body"
    echo "--- FIM CORPO E-MAIL (SIMULAÇÃO) ---"
    return 0
  fi

  # Verificar variáveis de ambiente necessárias
  if [[ -z "${SMTP_SERVER:-}" || -z "${SMTP_USER:-}" || -z "${SMTP_PASSWORD:-}" || -z "${FROM_EMAIL:-}" ]]; then
    log_error "Variáveis de ambiente para SMTP não definidas."
    return 1
  fi

  # Preparar comando de envio de e-mail
  local content_type="text/plain"
  [[ "$format" == "html" ]] && content_type="text/html"

  # Criar arquivo temporário para o e-mail
  local temp_email_file
  temp_email_file=$(mktemp)

  # Criar cabeçalhos e corpo do e-mail
  {
    echo "Subject: $subject"
    echo "From: ${FROM_EMAIL}"
    echo "To: ${to_email}"
    echo "Content-Type: ${content_type}; charset=UTF-8"
    echo "MIME-Version: 1.0"
    echo ""
    echo "$body"
  } >"$temp_email_file"

  # Enviar e-mail usando curl com o arquivo temporário
  if ! curl --ssl-reqd \
    --url "smtp://${SMTP_SERVER}" \
    --user "${SMTP_USER}:${SMTP_PASSWORD}" \
    --mail-from "${FROM_EMAIL}" \
    --mail-rcpt "${to_email}" \
    --upload-file "$temp_email_file" \
    &>/dev/null; then
    log_error "Falha ao enviar e-mail para '$to_email'."
    rm -f "$temp_email_file"
    return 1
  fi

  # Remover arquivo temporário
  rm -f "$temp_email_file"

  log_info "E-mail enviado com sucesso para '$to_email'."
  return 0
}

# Exportar funções para uso em subshells
export -f validate_email_format get_system_info create_email_body send_user_credentials_email
