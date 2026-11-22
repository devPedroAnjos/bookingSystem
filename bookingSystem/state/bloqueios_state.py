"""Estado da página de bloqueios (admin e coordenador, no próprio escopo, C11).

Só usabilidade: escopo, período, reserva em andamento e os efeitos sobre
reservas e filas são decididos no Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.motivos import TIPOS_BLOQUEIO

TAMANHO_MAXIMO_MOTIVO = 500
TODAS = "todas"


def _bloqueio_para_tela(bloqueio: dict) -> dict[str, str]:
    return {
        "id": str(bloqueio["id"]),
        "espaco": f"{bloqueio['espaco_codigo']} — {bloqueio['espaco_nome']}",
        "unidade": bloqueio["unidade"],
        "tipo": TIPOS_BLOQUEIO.get(bloqueio["tipo"], bloqueio["tipo"]),
        "motivo": bloqueio["motivo"],
        "inicio": bloqueio["inicio"],
        "fim": bloqueio["fim"],
        "criado_por": bloqueio.get("criado_por") or "",
    }


def _campos_bloqueio(dados: dict) -> tuple[dict, str]:
    """Campos do formulário e o erro de usabilidade ("" quando está ok)."""
    campos = {
        chave: str(dados.get(chave, "") or "").strip()
        for chave in (
            "espaco_id", "tipo", "motivo",
            "data_inicio", "hora_inicio", "data_fim", "hora_fim",
        )
    }
    if not all(campos.values()) or not campos["espaco_id"].isdigit():
        return campos, (
            "Informe o espaço, o tipo, o motivo e a data e a hora de início "
            "e de fim."
        )
    if len(campos["motivo"]) > TAMANHO_MAXIMO_MOTIVO:
        return campos, "O motivo deve ter no máximo 500 caracteres."
    campos["espaco_id"] = int(campos["espaco_id"])
    return campos, ""


class BloqueiosState(rx.State):
    """Bloqueios do escopo, com a criação e a remoção."""

    bloqueios: list[dict[str, str]] = []
    unidades: list[dict[str, str]] = []
    espacos: list[dict[str, str]] = []
    filtro_unidade: str = TODAS
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    erro_dialogo: str = ""

    criar_aberta: bool = False

    remover_aberta: bool = False
    remover_id: str = ""
    remover_texto: str = ""

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        unidade = None if self.filtro_unidade == TODAS else int(self.filtro_unidade)
        try:
            bloqueios = await api.listar_bloqueios(token, unidade)
            unidades = await api.listar_unidades_geridas(token)
            espacos = await api.listar_espacos_geridos(token)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.bloqueios = [_bloqueio_para_tela(b) for b in bloqueios]
        self.unidades = [{"id": str(u["id"]), "nome": u["nome"]} for u in unidades]
        self.espacos = [
            {
                "id": str(e["id"]),
                "nome": f"{e['codigo']} — {e['nome']} ({e['unidade']['nome']})",
            }
            for e in espacos
            if e["ativo"]
        ]

    @rx.event
    def abrir(self):
        self._limpar_mensagens()
        self.filtro_unidade = TODAS
        return BloqueiosState.carregar

    @rx.event
    def filtrar_unidade(self, unidade_id: str):
        self.filtro_unidade = unidade_id
        return BloqueiosState.carregar

    # ---------- criar ----------

    @rx.event
    def mudar_criar(self, aberta: bool):
        self._limpar_mensagens()
        self.criar_aberta = aberta

    @rx.event
    async def confirmar_criar(self, dados: dict):
        """A recusa do Xano aparece dentro do diálogo, que continua aberto."""
        self._limpar_mensagens()
        campos, erro = _campos_bloqueio(dados)
        if erro:
            self.erro_dialogo = erro
            return
        token = await token_da_sessao(self)
        try:
            resposta = await api.criar_bloqueio(token, campos)
        except api.ErroApi as erro_api:
            if isinstance(erro_api, (api.NaoAutenticado, api.AcessoNegado)):
                self.criar_aberta = False
                return await tratar_erro_api(self, erro_api)
            self.erro_dialogo = erro_api.mensagem
            return
        self.criar_aberta = False
        self.mensagem_sucesso = resposta["mensagem"]
        return BloqueiosState.carregar

    # ---------- remover ----------

    @rx.event
    def abrir_remover(self, bloqueio: dict):
        self._limpar_mensagens()
        self.remover_id = bloqueio["id"]
        self.remover_texto = (
            f"{bloqueio['espaco']}, de {bloqueio['inicio']} a {bloqueio['fim']}"
        )
        self.remover_aberta = True

    @rx.event
    def mudar_remover(self, aberta: bool):
        self.remover_aberta = aberta

    @rx.event
    async def confirmar_remover(self, dados: dict):
        self.remover_aberta = False
        token = await token_da_sessao(self)
        try:
            resposta = await api.remover_bloqueio(token, int(self.remover_id))
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            if redirecionamento is not None:
                return redirecionamento
            return BloqueiosState.carregar
        self.mensagem_sucesso = resposta["mensagem"]
        return BloqueiosState.carregar
