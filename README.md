# seradmin

Script para hardenning e administração de servidores linux

# Quando executado, o script deverá:

- Criar usuários e adicioná-lo no grupo sudo
- Listar os usuários criados
- Todos os usuários criados compartilharão a mesma pasta home do usuário inicial
- Listar as permissões do usuário
- Conectar remotamente via ssh para executar essas ações em servidores remotos

# O hardenning deverá:

- Instalar, configurar e ativar o ufw
- Tráfego de saída bloqueado por padrão
- Tráfego de entrada permitida por padrão
- Permitir acesso via SSH apenas aos hosts e subredes dos administradores
- Permitir comunicação interna apenas para as os servidores que realmente precisem acessar recursos da máquina
- Ocultar os banners de serviços e SO

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

# Atualizações do .env e usuarios.csv

Para manter o arquivo .env no repositório remoto como modelo, enquanto faz alterações apenas localmente, você precisa usar um recurso específico do Git chamado `--skip-worktree` ou `--assume-unchanged`.

## Uso de `--skip-worktree`

Execute este comando no terminal:

```bash
git update-index --skip-worktree conf/.env
git update-index --skip-worktree usuarios.csv
```

Isso fará o Git:

- Manter o arquivo no repositório remoto
- Ignorar todas as mudanças locais que você fizer
- Não tentar atualizar este arquivo durante git pull

## Diferença entre as opções:

- `--skip-worktree`: Melhor para arquivos de configuração que você editará frequentemente (seu caso)
- `--assume-unchanged`: Melhor para arquivos que raramente mudam e apenas para otimizar performance

## Para reverter posteriormente:

Se um dia precisar enviar suas alterações para o Git, você pode reverter com:

```bash
git update-index --no-skip-worktree conf/.env
git update-index --no-skip-worktree usuarios.csv
```

# Observação importante:

- Esta configuração é apenas local e não é compartilhada com outros desenvolvedores
- Se fizer um novo clone do repositório, precisará executar o comando novamente

Essa abordagem permite manter o arquivo `.env` como modelo no repositório remoto, enquanto você faz alterações locais sem risco de subir essas mudanças.

