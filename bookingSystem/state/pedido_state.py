"""Estado do painel de pedido recusado na página de login.

A senha nunca fica no State: a consulta usa a senha do próprio login, só dentro
do handler, e o reenvio pede a senha de novo no formulário.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api


class PedidoState(rx.State):
    """Motivo da recusa, pedidos restantes e reenvio do pedido."""

    recusado: bool = False
    email: str = ""
    motivo: str = ""
    pedidos_restantes: int = 0
    papel: str = "PROFESSOR"
    unidades: list[dict[str, str]] = []
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""

    @rx.var
    def pode_reenviar(self) -> bool:
        return self.recusado and self.pedidos_restantes > 0

    def _limpar(self):
        self.recusado = False
        self.email = ""
        self.motivo = ""
        self.pedidos_restantes = 0
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""

    async def _carregar_recusa(self, email: str, senha: str):
        """Consulta o pedido depois de um login negado (conta não ativa)."""
        try:
            situacao = await api.consultar_situacao_pedido(email, senha)
            unidades = await api.listar_unidades_ativas()
        except api.ErroApi:
            return
        if situacao["status_conta"] != "RECUSADA":
            return
        self.recusado = True
        self.email = email
        self.motivo = situacao.get("motivo_recusa_cadastro") or ""
        self.pedidos_restantes = int(situacao.get("pedidos_restantes") or 0)
        self.papel = situacao.get("papel") or "PROFESSOR"
        self.unidades = [
            {"id": str(u["id"]), "nome": u["nome"]} for u in unidades
        ]

    @rx.event
    def escolher_papel(self, papel: str):
        self.papel = papel

    @rx.event
    async def reenviar(self, dados: dict):
        senha = str(dados.get("senha", ""))
        unidade = str(dados.get("unidade_id", "") or "")
        justificativa = str(dados.get("justificativa", "")).strip()
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        if not senha or not unidade.isdigit():
            self.mensagem_erro = "Informe a senha e escolha a unidade."
            return
        try:
            resposta = await api.reenviar_pedido(
                self.email, senha, self.papel, int(unidade), justificativa
            )
        except api.ErroApi as erro:
            self.mensagem_erro = erro.mensagem
            return
        self.recusado = False
        self.mensagem_sucesso = resposta["mensagem"]
