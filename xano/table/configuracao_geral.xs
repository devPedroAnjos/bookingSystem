// Parâmetros globais do sistema (registro único). Cada change acrescenta os parâmetros que usar.
table configuracao_geral {
  auth = false

  schema {
    int id
  
    // Domínios de e-mail aceitos no cadastro (comparação exata com a parte após o @)
    text[] dominios_email
  
    // Limites da coordenação e do cadastro, preenchidos pelo bootstrap
    int? max_coordenadores_unidade?
  
    int? max_unidades_coordenador?
    int? max_pedidos_cadastro?
  
    // Máximo de administradores ativos, contando o principal
    int? max_admins?
  }

  index = [{type: "primary", field: [{name: "id"}]}]
  guid = "VPFHLbqxacmD0JuqMtUJsYRt2Mg"
}