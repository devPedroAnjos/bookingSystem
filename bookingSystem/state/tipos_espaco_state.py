"""Estado da página de tipos de espaço (só administrador).

Só usabilidade: nome único e situação são validados no Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api


def _tipo_para_tela(tipo: dict) -> dict[str, str]:
    return {
        "id": str(tipo["id"]),
        "nome": tipo["nome"],
        "descricao": tipo.get("descricao") or "",
        "ativo": "sim" if tipo["ativo"] else "nao",
        "espacos_ativos": str(tipo.get("espacos_ativos") or 0),
        "unidades": str(tipo.get("unidades") or 0),
    }


class TiposEspacoState(rx.State):
    """Tipos de espaço e as ações do admin."""

    tipos: list[dict[str, str]] = []
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    # Erro de validação mostrado dentro do diálogo aberto (padrão da C3)
    erro_dialogo: str = ""

    criar_aberta: bool = False

    editar_aberta: bool = False
    editar_id: str = ""
    editar_nome: str = ""
    editar_descricao: str = ""

    desativar_aberta: bool = False
    desativar_id: str = ""
    desativar_nome: str = ""
    desativar_espacos: str = "0"
    desativar_unidades: str = "0"

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            tipos = await api.listar_tipos_espaco(token)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.tipos = [_tipo_para_tela(t) for t in tipos]

    @rx.event
    def abrir(self):
        self._limpar_mensagens()
        return TiposEspacoState.carregar

    async def _executar(self, chamada):
        """Executa uma ação, mostra a mensagem da API e recarrega a lista."""
        try:
            resposta = await chamada
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            if redirecionamento is not None:
                return redirecionamento
            return TiposEspacoState.carregar
        self.mensagem_sucesso = resposta["mensagem"]
        return TiposEspacoState.carregar

    @rx.event
    def mudar_criar(self, aberta: bool):
        self._limpar_mensagens()
        self.criar_aberta = aberta

    @rx.event
    async def confirmar_criar(self, dados: dict):
        self._limpar_mensagens()
        nome = str(dados.get("nome", "")).strip()
        if not nome:
            self.erro_dialogo = "Informe o nome do tipo de espaço."
            return
        self.criar_aberta = False
        token = await token_da_sessao(self)
        descricao = str(dados.get("descricao", "")).strip()
        return await self._executar(api.criar_tipo_espaco(token, nome, descricao))

    @rx.event
    def abrir_editar(self, tipo: dict):
        self._limpar_mensagens()
        self.editar_id = tipo["id"]
        self.editar_nome = tipo["nome"]
        self.editar_descricao = tipo["descricao"]
        self.editar_aberta = True

    @rx.event
    def mudar_editar(self, aberta: bool):
        self.editar_aberta = aberta

    @rx.event
    async def confirmar_editar(self, dados: dict):
        self._limpar_mensagens()
        nome = str(dados.get("nome", "")).strip()
        if not nome:
            self.erro_dialogo = "Informe o nome do tipo de espaço."
            return
        self.editar_aberta = False
        token = await token_da_sessao(self)
        descricao = str(dados.get("descricao", "")).strip()
        return await self._executar(
            api.editar_tipo_espaco(token, int(self.editar_id), nome, descricao)
        )

    @rx.event
    def abrir_desativar(self, tipo: dict):
        self._limpar_mensagens()
        self.desativar_id = tipo["id"]
        self.desativar_nome = tipo["nome"]
        self.desativar_espacos = tipo["espacos_ativos"]
        self.desativar_unidades = tipo["unidades"]
        self.desativar_aberta = True

    @rx.event
    def mudar_desativar(self, aberta: bool):
        self.desativar_aberta = aberta

    @rx.event
    async def confirmar_desativar(self, _dados: dict):
        self._limpar_mensagens()
        self.desativar_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(
            api.desativar_tipo_espaco(token, int(self.desativar_id))
        )

    @rx.event
    async def reativar(self, tipo_id: str):
        self._limpar_mensagens()
        token = await token_da_sessao(self)
        return await self._executar(api.reativar_tipo_espaco(token, int(tipo_id)))
