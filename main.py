import paramiko

print("Criar um venv e instalar a biblioteca paramiko")

# Falta adicionar a varredura do users.txt para cadastrar os usuários do arquivo

sudo useradd -m -d /home/$USUARIO -s /bin/bash -c "$USUARIO - Depto Qualidade" -U $USUARIO -G sudo -p $(echo Mudar123 | openssl passwd -1 -stdin) && sudo passwd --expire $USUARIO

try:
    ssh_client.connect(hostname, port, username, password)
    
    # Comandos para criar o novo usuário e definir a senha
    comando = f'sudo useradd -m -d /home/{usuario} -s /bin/bash -c "{usuario} - Depto de Redes" -U {usuario} -G sudo -p $(echo {senha} | openssl passwd -1 -stdin) && sudo passwd --expire {usuario}'
    
    # Execute os comandos remotamente
    stdin, stdout, stderr = ssh_client.exec_command(comando)
    stdin.write(f'{senha}')
    stdin.flush()
    
    # Verifique se a criação do usuário foi bem-sucedida
    if not stderr.read():
        stdin, stdout, stderr = ssh_client.exec_command(comando)
        if not stderr.read():
            print(f'Usuário {usuario} foi criado com sucesso.')
        else:
            print(f'Erro ao definir a senha para o usuário {usuario}.')
    else:
        print(f'Erro ao criar o usuário {usuario}.')
    
except Exception as e:
    print(f'Erro ao conectar via SSH: {str(e)}')
finally:
    ssh_client.close()
