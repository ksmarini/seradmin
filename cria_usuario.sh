#!/bin/bash

##############################################
# Configurações via variáveis de ambiente (OBRIGATÓRIO definir antes de executar!)
##############################################
# Exporte estas variáveis no shell:
# export SMTP_SERVER="servidor.gov.br:587"
# export SMTP_USER="suaconta@gov.br"
# export SMTP_PASSWORD="senha_secreta"
# export FROM_EMAIL="seuemail@gov.br"
##############################################

CSV_FILE="usuarios.csv"                    # Arquivo CSV com: usuario;departamento;email
LOG_FILE="user_creator.log"                 # Arquivo de log
EMAIL_SUBJECT="[IMPORTANTE] Credenciais de Acesso - Servidor de Produção"

##############################################
# Funções básicas
##############################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

generate_password() {
    tr -dc 'A-Za-z0-9!@#$%&*+=?' < /dev/urandom | head -c 16
}

get_ip() {
    hostname -I | awk '{print $1}'
}

validate_email() {
    [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] && return 0 || return 1
}

send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    curl -s --ssl-reqd \
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

    return $?
}

##############################################
# Validação inicial
##############################################

# Verifica variáveis críticas
missing_vars=()
for var in SMTP_SERVER SMTP_USER SMTP_PASSWORD FROM_EMAIL; do
    [ -z "${!var}" ] && missing_vars+=("$var")
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "ERRO: Variáveis não definidas:" >&2
    printf '• %s\n' "${missing_vars[@]}" >&2
    echo "Defina-as com export antes de executar!" >&2
    exit 1
fi

# Verifica root
[ "$(id -u)" -ne 0 ] && echo "ERRO: Execute como root!" | tee -a "$LOG_FILE" && exit 1

# Verifica dependências
for cmd in openssl sudo curl hostname; do
    command -v $cmd &>/dev/null || { log "ERRO: Comando '$cmd' não encontrado!"; exit 1; }
done

##############################################
# Processamento principal
##############################################

log "Iniciando processo de criação de usuários"

IP_ADDRESS=$(get_ip)
HOSTNAME=$(hostname)

while IFS=';' read -r usuario departamento email; do
    
    usuario=$(echo "$usuario" | xargs)
    email=$(echo "$email" | xargs)
    departamento=$(echo "$departamento" | xargs)

    [ -z "$usuario" ] || [ -z "$email" ] && log "AVISO: Linha inválida: $usuario;$departamento;$email" && continue
    validate_email "$email" || { log "ERRO: E-mail inválido para $usuario: $email"; continue; }
    id "$usuario" &>/dev/null && log "AVISO: Usuário $usuario já existe. Pulando..." && continue

    password=$(generate_password)
    
    if sudo useradd -m -s /bin/bash -G sudo -c "$usuario - $departamento" -p "$(openssl passwd -6 "$password")" "$usuario"; then
        sudo passwd --expire "$usuario"
        log "SUCESSO: Usuário $usuario criado"

        sudo chmod 700 "/home/$usuario"
        sudo chown -R "$usuario:$usuario" "/home/$usuario"

	email_body="Caro(a) $usuario,

Sua conta com acesso administrativo no servidor $HOSTNAME com o IP $IP_ADDRESS foi criada.

Credenciais temporárias:
• Usuário: $usuario
• Senha: $password

FAÇA LOGIN IMEDIATAMENTE PARA ALTERAR A SENHA DO PRIMEIRO ACESSO

Dúvidas? Contate nossa equipe através do nosso funcional (99) 90000-0000.

Atenciosamente,
Departamento de Redes"

        send_email "$email" "$EMAIL_SUBJECT" "$email_body" && log "SUCESSO: E-mail enviado para $email" || log "ERRO: Falha ao enviar e-mail para $email"

        unset password
    else
        log "ERRO: Falha ao criar usuário $usuario"
    fi

done < <(grep -v '^#' "$CSV_FILE")

log "Processo concluído. Verifique o log completo em: $LOG_FILE"
