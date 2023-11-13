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
