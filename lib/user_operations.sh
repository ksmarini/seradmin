#!/usr/bin/env bash

# Depende de logging.sh e config.sh (para ADMIN_GROUP)

# Valida o nome de usuário (simples, pode ser expandido)
validate_username_format() {
  local username="$1"
  # Deve começar com letra minúscula ou '_', seguido por letras minúsculas, números, '_', '-'
  if [[ "$username" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
    return 0 # Formato válido
  else
    log_error "Nome de usuário '$username' possui formato inválido."
    return 1 # Formato inválido
  fi
}

# Verifica se um usuário existe no sistema
user_exists() {
  local username="$1"
  if id "$username" &>/dev/null; then
    return 0 # Usuário existe
  else
    return 1 # Usuário não existe
  fi
}

# Função para verificar a força da senha
check_password_strength() {
  local password="$1"
  local min_length="${2:-12}" # Tamanho mínimo configurável

  # Verificar tamanho
  if [ ${#password} -lt "$min_length" ]; then
    return 1
  fi

  # Verificar se contém pelo menos um número
  if ! [[ "$password" =~ [0-9] ]]; then
    return 1
  fi

  # Verificar se contém pelo menos uma letra maiúscula
  if ! [[ "$password" =~ [A-Z] ]]; then
    return 1
  fi

  # Verificar se contém pelo menos uma letra minúscula
  if ! [[ "$password" =~ [a-z] ]]; then
    return 1
  fi

  # Verificar se contém pelo menos um caractere especial
  # Usando aspas simples para evitar interpretação do shell
  if ! [[ "$password" =~ ['!@#$%^&*()_+\-=\[\]{};:\",.<>?/\\|'] ]]; then
    return 1
  fi

  return 0 # Senha forte
}

# Função melhorada para gerar senha forte garantida
generate_password() {
  local min_length="${1:-16}"

  # Garantir que temos pelo menos um de cada tipo de caractere
  local upper_chars="ABCDEFGHJKLMNPQRSTUVWXYZ"  # Sem I e O para evitar confusão
  local lower_chars="abcdefghijkmnopqrstuvwxyz" # Sem l para evitar confusão
  local number_chars="23456789"                 # Sem 0 e 1 para evitar confusão
  local special_chars="!@#$%^&*()-_=+[]{}|;:,.<>?"

  # Iniciar com um caractere de cada tipo para garantir os requisitos
  local password=""
  password="${password}${upper_chars:$((RANDOM % ${#upper_chars})):1}"     # Uma maiúscula
  password="${password}${lower_chars:$((RANDOM % ${#lower_chars})):1}"     # Uma minúscula
  password="${password}${number_chars:$((RANDOM % ${#number_chars})):1}"   # Um número
  password="${password}${special_chars:$((RANDOM % ${#special_chars})):1}" # Um especial

  # Completar o restante da senha com caracteres aleatórios
  local remaining_length=$((min_length - 4))
  local all_chars="${upper_chars}${lower_chars}${number_chars}${special_chars}"

  for ((i = 0; i < remaining_length; i++)); do
    password="${password}${all_chars:$((RANDOM % ${#all_chars})):1}"
  done

  # Embaralhar a senha para que os caracteres obrigatórios não fiquem sempre no início
  password=$(echo "$password" | fold -w1 | shuf | tr -d '\n')

  echo "$password"
  return 0
}

# Função para criar um usuário no sistema
create_system_user() {
  local username="$1"
  local department="$2"
  local password="$3"
  local admin_group="${4:-sudo}" # Usar o grupo passado como parâmetro ou sudo como padrão

  # Verificações preliminares
  if [[ -z "$username" ]]; then
    log_error "Nome de usuário não fornecido."
    return 1
  fi

  if [[ -z "$password" ]]; then
    log_error "Senha não fornecida para o usuário '$username'."
    return 1
  fi

  if [[ -z "$admin_group" ]]; then
    log_error "Grupo administrativo não definido. Verifique a configuração."
    return 1
  fi

  # Verificar se o grupo existe
  if ! getent group "$admin_group" &>/dev/null; then
    log_error "Grupo '$admin_group' não existe no sistema."
    return 1
  fi

  log_info "Tentando criar usuário '$username'..."

  # Gerar hash da senha com tratamento de erro
  local hashed_password
  hashed_password=$(echo "$password" | openssl passwd -6 -stdin)
  if [ $? -ne 0 ] || [ -z "$hashed_password" ]; then
    log_error "Falha ao gerar hash da senha para o usuário '$username'."
    return 1
  fi

  # Criar usuário com tratamento de erro detalhado
  if ! sudo useradd -m -s /bin/bash -G "$admin_group" -c "$username - $department" -p "$hashed_password" "$username"; then
    local exit_code=$?
    case $exit_code in
    9)
      log_error "Falha ao criar usuário '$username': Nome de usuário já existe."
      ;;
    10)
      log_error "Falha ao criar usuário '$username': Não foi possível atualizar o arquivo de grupos."
      ;;
    12)
      log_error "Falha ao criar usuário '$username': Não foi possível criar o diretório home."
      ;;
    *)
      log_error "Falha ao criar usuário '$username': Erro desconhecido (código $exit_code)."
      ;;
    esac
    return 1
  fi

  log_info "SUCESSO: Usuário '$username' criado."

  # Ações pós-criação com tratamento de erro individual
  local post_creation_errors=0

  if ! sudo passwd --expire "$username"; then
    log_warn "Falha ao definir expiração de senha para '$username'."
    post_creation_errors=$((post_creation_errors + 1))
  fi

  if ! sudo chmod 700 "/home/$username"; then
    log_warn "Falha ao definir chmod 700 para /home/$username."
    post_creation_errors=$((post_creation_errors + 1))
  fi

  if ! sudo chown -R "$username:$username" "/home/$username"; then
    log_warn "Falha ao definir chown para /home/$username."
    post_creation_errors=$((post_creation_errors + 1))
  fi

  if [ $post_creation_errors -gt 0 ]; then
    log_warn "Usuário '$username' criado, mas com $post_creation_errors erros nas ações pós-criação."
  fi

  return 0
}

# Exportar funções para uso em subshells
export -f validate_username_format user_exists check_password_strength generate_password create_system_user
