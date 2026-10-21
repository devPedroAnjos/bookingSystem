"""Estado da página do catálogo de recursos (só administrador).

Só usabilidade: nome único e "excluir só sem uso" são validados no Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api


def _recurso_para_tela(recurso: dict) -> dict[str, str]:
    return {
        "id": str(recurso["id"]),
        "nome": recurso["nome"],
        "espacos": str(recurso.get("espacos") or 0),
    }


class RecursosState(rx.State):
    """Catálogo de recursos e as ações do admin."""

    recursos: list[dict[str, str]] = []
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    # Erro de validação mostrado dentro do diálogo aberto (padrão da C3)
    erro_dialogo: str = ""

    criar_aberta: bool = False

    editar_aberta: bool = False
    editar_id: str = ""
    editar_nome: str = ""

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            recursos = await api.listar_recursos(token)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.recursos = [_recurso_para_tela(r) for r in recursos]

    @rx.event
    def abrir(self):
        self._limpar_mensagens()
        return RecursosState.carregar

    async def _executar(self, chamada):
        """Executa uma ação, mostra a mensagem da API e recarrega a lista."""
        try:
            resposta = await chamada
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            if redirecionamento is not None:
                return redirecionamento
            return RecursosState.carregar
        self.mensagem_sucesso = resposta["mensagem"]
        return RecursosState.carregar

    @rx.event
    def mudar_criar(self, aberta: bool):
        self._limpar_mensagens()
        self.criar_aberta = aberta

    @rx.event
    async def confirmar_criar(self, dados: dict):
        self._limpar_mensagens()
        nome = str(dados.get("nome", "")).strip()
        if not nome:
            self.erro_dialogo = "Informe o nome do recurso."
            return
        self.criar_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(api.criar_recurso(token, nome))

    @rx.event
    def abrir_editar(self, recurso: dict):
        self._limpar_mensagens()
        self.editar_id = recurso["id"]
        self.editar_nome = recurso["nome"]
        self.editar_aberta = True

    @rx.event
    def mudar_editar(self, aberta: bool):
        self.editar_aberta = aberta

    @rx.event
    async def confirmar_editar(self, dados: dict):
        self._limpar_mensagens()
        nome = str(dados.get("nome", "")).strip()
        if not nome:
            self.erro_dialogo = "Informe o nome do recurso."
            return
        self.editar_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(
            api.editar_recurso(token, int(self.editar_id), nome)
        )

    @rx.event
    async def excluir(self, recurso_id: str):
        self._limpar_mensagens()
        token = await token_da_sessao(self)
        return await self._executar(api.excluir_recurso(token, int(recurso_id)))
