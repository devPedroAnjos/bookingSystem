"""Estado da página de troca de senha.

As senhas chegam só no evento do formulário e não ficam no State. A troca
derruba as outras sessões no Xano; esta continua com o token novo.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import AuthState, tratar_erro_api

TAMANHO_MINIMO_SENHA = 8


class SenhaState(rx.State):
    """Troca da própria senha, inclusive da senha provisória."""

    mensagem_erro: str = ""
    mensagem_sucesso: str = ""

    @rx.event
    def abrir(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""

    @rx.event
    async def trocar(self, dados: dict):
        atual = str(dados.get("senha_atual", ""))
        nova = str(dados.get("nova_senha", ""))
        confirmacao = str(dados.get("confirmacao", ""))
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        if not atual or not nova:
            self.mensagem_erro = "Informe a senha atual e a nova."
            return
        if len(nova) < TAMANHO_MINIMO_SENHA:
            self.mensagem_erro = "A nova senha deve ter pelo menos 8 caracteres."
            return
        if nova != confirmacao:
            self.mensagem_erro = "A confirmação não confere com a nova senha."
            return

        auth = await self.get_state(AuthState)
        try:
            resposta = await api.trocar_senha(auth._token, atual, nova)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        auth._renovar_token(resposta["token"])
        self.mensagem_sucesso = (
            resposta["mensagem"] + " As outras sessões desta conta foram encerradas."
        )
