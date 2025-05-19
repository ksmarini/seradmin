# Verificar espaço em disco
check_disk_space() {
  local min_space_mb="${1:-100}" # Espaço mínimo em MB
  local mount_point="${2:-/}"    # Ponto de montagem a verificar

  # Obter espaço livre em MB
  local free_space
  free_space=$(df -m "$mount_point" | awk 'NR==2 {print $4}')

  if [[ -z "$free_space" ]]; then
    log_error "Não foi possível determinar o espaço livre em '$mount_point'."
    return 1
  fi

  if [[ $free_space -lt $min_space_mb ]]; then
    log_error "Espaço em disco insuficiente em '$mount_point': $free_space MB (mínimo: $min_space_mb MB)."
    return 1
  fi

  log_info "Espaço em disco suficiente em '$mount_point': $free_space MB."
  return 0
}

# Verificar permissões de diretórios
check_directory_permissions() {
  local directory="$1"
  local required_permission="$2" # r, w, x ou combinações
  local user="${3:-$(whoami)}"

  if [[ ! -d "$directory" ]]; then
    log_error "Diretório '$directory' não existe."
    return 1
  fi

  local has_permission=true

  # Verificar permissão de leitura
  if [[ "$required_permission" == *"r"* ]] && [[ ! -r "$directory" ]]; then
    has_permission=false
  fi

  # Verificar permissão de escrita
  if [[ "$required_permission" == *"w"* ]] && [[ ! -w "$directory" ]]; then
    has_permission=false
  fi

  # Verificar permissão de execução
  if [[ "$required_permission" == *"x"* ]] && [[ ! -x "$directory" ]]; then
    has_permission=false
  fi

  if [[ "$has_permission" = "false" ]]; then
    log_error "Usuário '$user' não tem permissão '$required_permission' no diretório '$directory'."
    return 1
  fi

  log_info "Permissões verificadas para '$directory': OK."
  return 0
}

# Verificar conectividade com servidor SMTP
check_smtp_connectivity() {
  local smtp_server="${1:-$SMTP_SERVER}"
  local timeout="${2:-5}"

  if [[ -z "$smtp_server" ]]; then
    log_error "Servidor SMTP não especificado."
    return 1
  fi

  # Extrair host e porta
  local host port
  host=$(echo "$smtp_server" | cut -d: -f1)
  port=$(echo "$smtp_server" | cut -d: -f2)

  # Se não houver porta, usar 25 como padrão
  if [[ "$host" = "$port" ]]; then
    port=25
  fi

  # Verificar conectividade
  if ! timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
    log_error "Não foi possível conectar ao servidor SMTP $host:$port."
    return 1
  fi

  log_info "Conectividade com servidor SMTP $host:$port: OK."
  return 0
}

# Função expandida para verificar dependências
check_dependencies() {
  # Adicione todos os comandos que seu sistema realmente precisa
  local dependencies=(
    "openssl" "sudo" "curl" "hostname" "awk" "ip" "tr" "head" "tee"
    "grep" "useradd" "passwd" "chmod" "chown" "date" "cat" "df" "timeout"
  )

  if command -v logger &>/dev/null; then # logger é opcional, mas bom ter
    dependencies+=("logger")
  fi

  local missing_cmds=()
  for cmd in "${dependencies[@]}"; do
    command -v "$cmd" &>/dev/null || missing_cmds+=("$cmd")
  done

  if [ ${#missing_cmds[@]} -gt 0 ]; then
    log_error "Comandos necessários não encontrados no sistema: ${missing_cmds[*]}"
    log_error "Por favor, instale os pacotes ausentes e tente novamente."
    return 1 # Retorna falha
  fi

  log_info "Todas as dependências de comandos foram encontradas."

  # Verificar espaço em disco
  check_disk_space 100 "/"

  # Verificar permissões do diretório de logs
  if [[ -n "${LOG_DIR:-}" ]]; then
    check_directory_permissions "$LOG_DIR" "rw"
  fi

  # Verificar conectividade SMTP se não estiver em modo dry run
  if [[ "${DRY_RUN:-false}" = "false" ]] && [[ -n "${SMTP_SERVER:-}" ]]; then
    check_smtp_connectivity "$SMTP_SERVER"
  fi

  return 0 # Retorna sucesso
}
