#!/bin/bash

# Caminho do arquivo CSV
arquivo="usuarios.csv"

# Senha padrão para todos os usuários
senha_padrao="myNewerAndBestPassword"

# Verifica se o arquivo existe
if [ ! -f "$arquivo" ]; then
    echo "O arquivo $arquivo não existe."
    exit 1
fi

# Lê cada linha do arquivo
while IFS=';' read -r usuario departamento
do
    # Adiciona o usuário ao sistema
    sudo useradd -m -d "/home/${usuario}" -s "/bin/bash" -c "${usuario} - ${departamento}" -U "${usuario}" -G sudo -p "$(echo ${senha_padrao} | openssl passwd -1 -stdin)" && sudo passwd --expire "${usuario}"

    # Informa o administrador sobre a criação do usuário
    echo "Usuário: $usuario criado com sucesso."

done < "$arquivo"
