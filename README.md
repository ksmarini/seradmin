# seradmin
Script para hardenning e administração de servidores linux 

# Quando executado, o script deverá:
* Criar usuários e adicioná-lo no grupo sudo
* Listar os usuários criados
* Todos os usuários criados compartilharão a mesma pasta home do usuário inicial
* Listar as permissões do usuário
* Conectar remotamente via ssh para executar essas ações em servidores remotos

# O hardenning deverá:
* Instalar, configurar e ativar o ufw
* Tráfego de saída bloqueado por padrão
* Tráfego de entrada permitida por padrão
* Permitir acesso via SSH apenas aos hosts e subredes dos administradores
* Permitir comunicação interna apenas para as os servidores que realmente precisem acessar recursos da máquina
* Ocultar os banners de serviços e SO

# Como Usar o script cria_usuario.sh:
1. Configure as variáveis de ambiente antes de executar:

```bash
export SMTP_SERVER="seuwebmail.gov.br:587" SMTP_USER="seu_usuario@gov.br" SMTP_PASSWORD='sua_senha_dificil' FROM_EMAIL="seu_email@gov.br"
```
2. Crie o arquivo CSV no formato:

```csv
usuario;departamento;email
fulano;infraestrutura;fulano@gov.br
cicrano;desenvovimento;cicrano@gov.br
beltrano;devops;beltrano@gov.br
```

3. Execute o script como root:

```bash
sudo -E ./cria_usuarios.sh
```
 **Dica importante**: O parâmetro `-E` no `sudo` preserva as variáveis de ambiente definidas.
