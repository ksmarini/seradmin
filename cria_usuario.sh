#!/bin/bash

##############################################
# Script para Criação de Usuários em Sistema Linux
#
# Este script lê um arquivo CSV contendo informações de usuários (usuario;departamento;email)
# e cria usuários no sistema com permissões específicas. Ele também pode enviar
# credenciais temporárias via e-mail.
#
# Requisitos:
# - As variáveis de ambiente necessárias devem ser definidas.
# - O script deve ser executado como root para realizar as operações de
#   criação de usuários.
#
# Opções:
#  -n, --dry-run: Ativa o modo Dry Run (simulação, nenhuma alteração real será feita).
##############################################

# Variáveis de ambiente necessárias
# export SMTP_SERVER="servidor.gov.br:587"
# export SMTP_USER="suaconta@gov.br"
# export SMTP_PASSWORD="senha_secreta"
# export FROM_EMAIL="seuemail@gov.br"
#
# Para exportar todas as variáveis em uma única linha, use o seguinte comando:
# export SMTP_SERVER="servidor.gov.br:587" SMTP_USER="suaconta@gov.br" SMTP_PASSWORD="senha_secreta" FROM_EMAIL="seuemail@gov.br"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CSV_FILE="${SCRIPT_DIR}/usuarios.csv"     # Caminho para o arquivo CSV com dados de usuários
LOG_FILE="${SCRIPT_DIR}/user_creator.log" # Caminho para o arquivo de log
ADMIN_GROUP="sudo"                        # Grupo para conceder privilégios de administrador

DRY_RUN=false # Flag para indicar se o modo de simulação está ativado

##############################################
# Processamento de Opções de Linha de Comando
##############################################
usage() {
  echo "Uso: $0 [-n | --dry-run]" >&2
  echo "  -n, --dry-run: Ativa o modo Dry Run (simulação, nenhuma alteração real será feita)." >&2
  exit 1
}

# Processar argumentos de linha de comando
# Loop para processar todas as opções fornecidas
# Consumirá os argumentos que são opções reconhecidas
while [[ $# -gt 0 ]]; do
  case "$1" in
  -n | --dry-run) # Verifica primeiro as opções nomeadas
    DRY_RUN=true
    shift # Remove a opção da lista de argumentos
    ;;
  --)     # Marca o fim das opções; todos os argumentos subsequentes são posicionais
    shift # Remove o '--'
    break # Para de processar opções
    ;;
  -*) # Opção desconhecida (começa com - mas não é -n nem --dry-run)
    echo "Opção inválida: $1" >&2
    usage
    ;;
  *) # Argumento não é uma opção (não começa com -)
    # Este script não espera argumentos posicionais além das opções.
    # Se um argumento não-opção for encontrado, paramos de processar opções.
    break # Para de processar opções
    ;;
  esac
done

# Se, após o loop, ainda houver argumentos e o script não os espera,
# você pode adicionar uma verificação aqui:
# if [[ $# -gt 0 ]]; then
#     echo "Argumentos inesperados: $@" >&2
#     usage
# fi

##############################################
# Funções Básicas
##############################################

# Função para registrar mensagens no log
log() {
  # Adiciona um prefixo [DRY RUN] se estiver no modo de simulação
  local prefix=""
  # A condição verifica se DRY_RUN é true e se a mensagem já não é uma das específicas do modo dry run
  if [ "$DRY_RUN" = "true" ] && ! [[ "$1" =~ ^(\[DRY RUN\]|MODO\ DRY\ RUN\ ATIVADO) ]]; then
    prefix="[DRY RUN] "
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${prefix}$1" | tee -a "$LOG_FILE"
}
# ... (o restante do seu script permanece o mesmo a partir daqui) ...
# Função para registrar mensagens de informação
log_info() {
  log "INFO: $1"
}

# Função para registrar mensagens de aviso
log_warn() {
  log "AVISO: $1"
}

# Função para registrar mensagens de erro
log_error() {
  log "ERRO: $1"
}

# Gerar uma senha aleatória
generate_password() {
  if command -v openssl &>/dev/null; then
    openssl rand -base64 12 # Gera 12 caracteres alfanuméricos aleatórios
  else
    tr -dc 'A-Za-z0-9!@#$%&*+=?' </dev/urandom | head -c 16
  fi
}

# Obtém o endereço IP da máquina
get_ip() {
  local ip
  ip=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null)
  if [[ -z "$ip" ]]; then
    ip=$(hostname -I | awk '{print $1}' 2>/dev/null) # Pega o primeiro IP
  fi
  if [[ -z "$ip" ]]; then
    log_warn "Não foi possível determinar o endereço IP principal. Tentando com 'hostname'."
    ip=$(hostname)
  fi
  echo "$ip"
}

# Valida um endereço de e-mail
validate_email() {
  # Retorna 0 para sucesso, 1 para falha
  # A expressão regular valida o formato do e-mail.
  [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# Envia um e-mail
send_email() {
  local to="$1"
  local subject="$2"
  local body="$3"
  local curl_exit_code

  if [ "$DRY_RUN" = "true" ]; then
    log_info "Simulação: Enviaria e-mail para '$to' com assunto '$subject'."
    log_info "Conteúdo do e-mail (simulação):"
    echo "--- INÍCIO CORPO E-MAIL (SIMULAÇÃO) ---" >&2 # Mostrar no console
    echo "$body" >&2
    echo "--- FIM CORPO E-MAIL (SIMULAÇÃO) ---" >&2
    return 0 # Simula sucesso
  fi

  # Validação das variáveis SMTP antes de tentar o envio real
  for var in SMTP_SERVER SMTP_USER SMTP_PASSWORD FROM_EMAIL; do
    if [ -z "${!var:-}" ]; then
      log_error "Variável SMTP obrigatória '$var' não definida."
      return 1
    fi
  done

  # Envio real do e-mail utilizando curl
  curl -sS --connect-timeout 30 --ssl-reqd \
    --url "smtp://${SMTP_SERVER}" \
    --user "${SMTP_USER}:${SMTP_PASSWORD}" \
    --mail-from "${FROM_EMAIL}" \
    --mail-rcpt "${to}" \
    --upload-file - <<EOF
From: ${FROM_EMAIL}
To: ${to}
Subject: ${subject}
Content-Type: text/plain; charset="utf-8"

${body}
EOF
  curl_exit_code=$?
  return $curl_exit_code
}

# Verifica comandos necessários
check_dependencies() {
  local dependencies=("openssl" "sudo" "curl" "hostname" "awk" "ip" "tr" "head" "tee" "grep" "useradd" "passwd" "chmod" "chown" "date")
  local missing_cmds=()
  for cmd in "${dependencies[@]}"; do
    command -v "$cmd" &>/dev/null || missing_cmds+=("$cmd")
  done

  if [ ${#missing_cmds[@]} -gt 0 ]; then
    log_error "Comandos necessários não encontrados: ${missing_cmds[*]}"
    exit 1
  fi
}

##############################################
# Validação Inicial
##############################################

# A mensagem de log_info será prefixada com [DRY RUN] se DRY_RUN for true.
log_info "Verificando o estado do script."

if [ "$DRY_RUN" = "true" ]; then
  # Esta mensagem específica não será prefixada duas vezes devido à lógica na função log()
  log_info "MODO DRY RUN ATIVADO. Nenhuma alteração real será feita no sistema."
fi

# Verifica variáveis críticas de ambiente
if [ "$DRY_RUN" = "false" ]; then
  missing_vars=()
  for var in SMTP_SERVER SMTP_USER SMTP_PASSWORD FROM_EMAIL; do
    [ -z "${!var:-}" ] && missing_vars+=("$var")
  done

  if [ ${#missing_vars[@]} -gt 0 ]; then
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

# Valida as dependências do script
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

IP_ADDRESS=$(get_ip)         # Obtém o IP da máquina
CURRENT_HOSTNAME=$(hostname) # Nome do host atual
EMAIL_SUBJECT="[IMPORTANTE] Credenciais de Acesso - Servidor $CURRENT_HOSTNAME"

# Habilitar extglob para trim de espaços (Bash 4+)
shopt -s extglob

# Processa cada linha do arquivo CSV
while IFS=';' read -r usuario_raw departamento_raw email_raw || [[ -n "$usuario_raw" ]]; do
  # Remover espaços no início e fim de cada campo
  usuario="${usuario_raw##*( )}"
  usuario="${usuario%%*( )}"
  departamento="${departamento_raw##*( )}"
  departamento="${departamento%%*( )}"
  email="${email_raw##*( )}"
  email="${email%%*( )}"

  # Pular linhas vazias ou onde usuário/email são vazios após trim
  if [ -z "$usuario" ] && [ -z "$departamento" ] && [ -z "$email" ]; then
    continue # Linha completamente vazia, pular
  fi
  if [ -z "$usuario" ] || [ -z "$email" ]; then
    log_warn "Linha inválida no CSV (usuário ou e-mail faltando): '$usuario_raw;$departamento_raw;$email_raw'"
    continue
  fi

  # Validação do nome de usuário
  if ! [[ "$usuario" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
    log_error "Nome de usuário '$usuario' inválido. Deve começar com letra minúscula ou '_', seguido por letras minúsculas, números, '_', '-'."
    continue
  fi

  # Valida o formato do e-mail
  if ! validate_email "$email"; then
    log_error "E-mail inválido para o usuário '$usuario': '$email'"
    continue
  fi

  # Verifica se o usuário já existe
  if id "$usuario" &>/dev/null; then
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
    hashed_password=$(echo "$password" | openssl passwd -6 -stdin)
    if [ $? -ne 0 ] || [ -z "$hashed_password" ]; then
      log_error "Falha ao gerar hash da senha para o usuário '$usuario'. Pulando este usuário."
      unset password # Limpar senha
      continue
    fi

    # Criação do usuário e configuração de permissões
    if sudo useradd -m -s /bin/bash -G "$ADMIN_GROUP" -c "$usuario - $departamento" -p "$hashed_password" "$usuario"; then
      log_info "SUCESSO: Usuário '$usuario' criado."

      # Ações pós-criação (tentar todas, logar falhas como avisos)
      if ! sudo passwd --expire "$usuario"; then
        log_warn "Falha ao definir expiração de senha para '$usuario'. Verifique manualmente."
      fi
      if ! sudo chmod 700 "/home/$usuario"; then
        log_warn "Falha ao definir chmod 700 para /home/$usuario. Verifique manualmente."
      fi
      if ! sudo chown -R "$usuario:$usuario" "/home/$usuario"; then
        log_warn "Falha ao definir chown para /home/$usuario. Verifique manualmente."
      fi
    else
      log_error "Falha ao criar usuário '$usuario' (useradd falhou)."
      unset password        # Limpar senha se useradd falhar
      unset hashed_password # Limpar hash
      continue              # Pular para o próximo usuário
    fi
    unset hashed_password # Limpar hash após uso
  fi                      # Fim do if DRY_RUN

  # Preparar e enviar e-mail para o usuário
  email_body_prefix=""
  if [ "$DRY_RUN" = "true" ]; then
    email_body_prefix="[ESTE É UM E-MAIL DE SIMULAÇÃO - NENHUMA CONTA FOI CRIADA]\n\n"
  fi

  # Corpo do e-mail
  email_body="${email_body_prefix}Caro(a) $usuario,

Sua conta com acesso administrativo no servidor $IP_ADDRESS ($CURRENT_HOSTNAME) foi criada.

Para acessar, use:
ssh $usuario@$IP_ADDRESS

Credenciais temporárias:
• Usuário: $usuario
• Senha: $password"

  if [ "$DRY_RUN" = "true" ]; then
    email_body+="\n\n(Esta senha NÃO foi definida no sistema durante a simulação)"
  fi

  email_body+="\n\nFAÇA LOGIN IMEDIATAMENTE PARA ALTERAR A SENHA DO PRIMEIRO ACESSO.
Dúvidas? Não responda esse e-mail.
Contate nossa equipe através do nosso funcional (69) 98400-0000.

Atenciosamente,
Departamento de Redes"

  # Envia o e-mail (ou simula o envio)
  # Guardar o código de retorno da função send_email
  send_email "$email" "$EMAIL_SUBJECT" "$email_body"
  send_email_rc=$?                    # CAPTURA O CÓDIGO DE SAÍDA IMEDIATAMENTE APÓS A EXECUÇÃO DA FUNÇÃO
  if [ "$send_email_rc" -ne 0 ]; then # Verifica se o código de saída é diferente de zero (falha)
    if [ "$DRY_RUN" = "false" ]; then # Logar falha do envio real
      log_error "Falha ao enviar e-mail para '$email' (Curl exit code: $send_email_rc). Verifique as configurações SMTP."
    fi
  else
    if [ "$DRY_RUN" = "false" ]; then # Logar sucesso do envio real
      log_info "SUCESSO: E-mail enviado para '$email' referente ao usuário '$usuario'."
    fi
  fi

  unset password                                              # Limpar senha da memória
  log "-----------------------------------------------------" # Separador visual no log

done < <(grep -vE '^\s*#|^\s*$' "$CSV_FILE" || {
  log_warn "Arquivo CSV '$CSV_FILE' está vazio ou contém apenas comentários/linhas em branco."
  echo
})

# Desabilitar extglob
shopt -u extglob

log_info "Processo concluído. Verifique o log completo em: $LOG_FILE"
