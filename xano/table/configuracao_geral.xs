// Parâmetros globais do sistema (registro único). Cada change acrescenta os parâmetros que usar.
table configuracao_geral {
  auth = false

  schema {
    int id
  
    // Domínios de e-mail aceitos no cadastro (comparação exata com a parte após o @)
    text[] dominios_email
  }

  index = [{type: "primary", field: [{name: "id"}]}]
  guid = "VPFHLbqxacmD0JuqMtUJsYRt2Mg"
}