#!/usr/bin/env bash

# Depende de logging.sh

# Configurações para o processamento de CSV
CSV_HAS_HEADER=${CSV_HAS_HEADER:-false}         # Se o CSV tem linha de cabeçalho
CSV_DELIMITER=${CSV_DELIMITER:-;}               # Delimitador do CSV
CSV_EXPECTED_COLUMNS=${CSV_EXPECTED_COLUMNS:-3} # Número esperado de colunas

# Função para validar o formato do arquivo CSV
validate_csv_format() {
  local csv_file="$1"
  local line_number=0
  local invalid_lines=0
  local total_lines=0

  # Verificar se o arquivo existe e é legível
  if [[ ! -f "$csv_file" ]]; then
    log_error "Arquivo CSV '$csv_file' não encontrado."
    return 1
  elif [[ ! -r "$csv_file" ]]; then
    log_error "Arquivo CSV '$csv_file' não pode ser lido (verifique as permissões)."
    return 1
  fi

  # Ler o arquivo linha por linha
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    total_lines=$((total_lines + 1))

    # Pular comentários e linhas vazias
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
      continue
    fi

    # Pular cabeçalho se configurado
    if [[ "$CSV_HAS_HEADER" = "true" ]] && [[ $line_number -eq 1 ]]; then
      continue
    fi

    # Contar o número de campos
    local field_count
    field_count=$(echo "$line" | awk -F"$CSV_DELIMITER" '{print NF}')

    # Verificar se o número de campos está correto
    if [[ $field_count -ne $CSV_EXPECTED_COLUMNS ]]; then
      log_warn "Linha $line_number: Número incorreto de campos ($field_count, esperado $CSV_EXPECTED_COLUMNS): '$line'"
      invalid_lines=$((invalid_lines + 1))
    fi
  done <"$csv_file"

  # Verificar se há linhas válidas
  if [[ $total_lines -eq 0 ]]; then
    log_error "Arquivo CSV '$csv_file' está vazio."
    return 1
  fi

  # Verificar se todas as linhas são inválidas
  local valid_lines=$((total_lines - invalid_lines))
  if [[ $CSV_HAS_HEADER = "true" ]]; then
    valid_lines=$((valid_lines - 1)) # Descontar o cabeçalho
  fi

  if [[ $valid_lines -eq 0 ]]; then
    log_error "Arquivo CSV '$csv_file' não contém linhas válidas."
    return 1
  fi

  log_info "Arquivo CSV validado: $valid_lines linhas válidas, $invalid_lines linhas inválidas."
  return 0
}

# Função para ler o conteúdo do CSV com suporte a cabeçalho e delimitador configurável
read_csv_content() {
  local csv_file="$1"
  local skip_header=${2:-$CSV_HAS_HEADER}
  local delimiter=${3:-$CSV_DELIMITER}

  # Validar o formato do CSV - REDIRECIONAR SAÍDA PARA /dev/null
  if ! validate_csv_format "$csv_file" >/dev/null; then
    return 1
  fi

  # Construir o comando grep para filtrar linhas
  local grep_cmd="grep -vE '^[[:space:]]*#|^[[:space:]]*$' \"$csv_file\""

  # Adicionar skip de cabeçalho se necessário
  if [[ "$skip_header" = "true" ]]; then
    grep_cmd="$grep_cmd | tail -n +2"
  fi

  # Executar o comando e retornar o resultado
  eval "$grep_cmd" || {
    log_warn "Arquivo CSV '$csv_file' está vazio ou contém apenas comentários/linhas em branco." >&2
    return 0
  }

  return 0
}

# Função para obter os nomes das colunas do cabeçalho
get_csv_header_names() {
  local csv_file="$1"
  local delimiter=${2:-$CSV_DELIMITER}

  if [[ ! -f "$csv_file" ]]; then
    log_error "Arquivo CSV '$csv_file' não encontrado." >&2
    return 1
  fi

  # Ler a primeira linha não comentada
  local header
  header=$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$csv_file" | head -n 1)

  if [[ -z "$header" ]]; then
    log_error "Não foi possível encontrar o cabeçalho no arquivo CSV." >&2
    return 1
  fi

  echo "$header"
  return 0
}

# Função para remover espaços em branco no início e fim de uma string
trim_whitespace() {
  local var="$*"
  # Remover espaços do início
  var="${var#"${var%%[![:space:]]*}"}"
  # Remover espaços do fim
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

# Exportar todas as funções para uso em subshells
export -f validate_csv_format read_csv_content get_csv_header_names trim_whitespace
