<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Credenciais de Acesso - {{HOSTNAME}}</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; }
    .header { background-color: #0056b3; color: white; padding: 20px; text-align: center; }
    .content { padding: 20px; }
    .credentials { background-color: #f5f5f5; border-left: 4px solid #0056b3; padding: 15px; margin: 20px 0; }
    .warning { color: #d9534f; font-weight: bold; }
    .system-info { background-color: #e9ecef; padding: 15px; margin-top: 20px; border-radius: 4px; }
    .footer { font-size: 0.9em; color: #6c757d; border-top: 1px solid #ddd; padding-top: 15px; margin-top: 20px; }
    .no-reply { background-color: #f8d7da; color: #721c24; padding: 10px; text-align: center; font-weight: bold; margin: 20px 0; border: 1px solid #f5c6cb; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="header">
    <h2>Credenciais de Acesso ao Servidor</h2>
  </div>
  <div class="content">
    <p>Caro(a) <strong>{{USERNAME}}</strong>,</p>
    
    <p>Sua conta com acesso administrativo no servidor foi criada com sucesso.</p>
    
    <div class="credentials">
      <h3>Informações de Acesso:</h3>
      <p><strong>Servidor:</strong> {{HOSTNAME}} ({{IP_ADDRESS}})</p>
      <p><strong>Comando SSH:</strong> ssh {{USERNAME}}@{{IP_ADDRESS}}</p>
      <p><strong>Usuário:</strong> {{USERNAME}}</p>
      <p><strong>Senha temporária:</strong> {{PASSWORD}}</p>
    </div>
    
    <p class="warning">IMPORTANTE: Faça login imediatamente para alterar sua senha temporária!</p>
    
    <div class="system-info">
      <h3>Informações do Sistema:</h3>
      <p><strong>Sistema Operacional:</strong> {{OS_INFO}}</p>
      <p><strong>Versão do Kernel:</strong> {{KERNEL_VERSION}}</p>
      <p><strong>Uptime:</strong> {{UPTIME}}</p>
    </div>
    
    <div class="no-reply">
      ATENÇÃO: ESTA É UMA MENSAGEM AUTOMÁTICA. NÃO RESPONDA ESTE E-MAIL.
    </div>

    <div class="system-info">
      <p>Em caso de dúvidas ou precisar de suporte urgente, entre em contato com nossa equipe através do telefone funcional <strong>(69) 98482-6823</strong></p>
      <p>Se precisar de outros serviços ou acompanhar seu chamado, acesse nosso portal: https://dinfo.pm.ro.gov.br</p>
      <p>Nossa equipe atenderá o chamado o mais breve possível</p>
      <p><strong>Departamento de Redes</strong></p>
    </div>
    
  </div>
  <div class="footer">
    <p>Diretoria de Informática - Departamento de Redes</p>
  </div>
</body>
</html>
