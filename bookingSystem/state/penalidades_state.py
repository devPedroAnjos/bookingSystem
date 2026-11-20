"""Estado da página "Penalidades" (só administrador; C10, spec penalidades).

Só usabilidade: a lista, a situação efetiva e `pode_anular` vêm do Xano
(`penalidades`), que revalida tudo ao anular (`anular_penalidade`). O parecer
é obrigatório e fica visível ao dono da penalidade, sem o nome de quem anulou.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.faltas_state import SITUACOES_PENALIDADE, TIPOS_FALTA

TAMANHO_MAXIMO_PARECER = 500

FILTROS_SITUACAO = [
    {"id": "EM_VIGOR", "nome": "Em vigor"},
    {"id": "ATIVA", "nome": "Ativas (em vigor e futuras)"},
    {"id": "CUMPRIDA", "nome": "Cumpridas"},
    {"id": "ANULADA", "nome": "Anuladas"},
    {"id": "TODAS", "nome": "Todas"},
]


def _texto_faltas(faltas: list[dict]) -> str:
    return "; ".join(
        f"{TIPOS_FALTA.get(f['tipo'], f['tipo'])} em {f['ocorrida_em']} "
        f"({f['espaco_codigo']})"
        for f in faltas
    )


def _penalidade_para_tela(penalidade: dict) -> dict[str, str]:
    situacao = SITUACOES_PENALIDADE.get(penalidade["status"], penalidade["status"])
    if penalidade.get("em_vigor"):
        situacao = "Em vigor"
    anulacao = ""
    if penalidade["status"] == "ANULADA":
        anulacao = (
            f"Anulada por {penalidade.get('anulada_por') or '—'} em "
            f"{penalidade.get('anulada_em') or '—'}: {penalidade.get('parecer') or ''}"
        )
    usuario = penalidade["usuario"]
    return {
        "id": str(penalidade["id"]),
        "usuario": f"{usuario['nome']} ({usuario['email']})",
        "periodo": f"{penalidade['inicio']} a {penalidade['fim']}",
        "situacao": situacao,
        "faltas": _texto_faltas(penalidade.get("faltas") or []),
        "anulacao": anulacao,
        "pode_anular": "sim" if penalidade.get("pode_anular") else "nao",
    }


class PenalidadesState(rx.State):
    """Penalidades de todos os usuários, com filtros e a anulação com parecer."""

    penalidades: list[dict[str, str]] = []
    limitada: bool = False
    situacao: str = "EM_VIGOR"
    busca: str = ""
    carregou: bool = False
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    erro_dialogo: str = ""

    anular_aberta: bool = False
    anular: dict[str, str] = {}

    @rx.var
    def filtros_situacao(self) -> list[dict[str, str]]:
        return FILTROS_SITUACAO

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            resposta = await api.listar_penalidades(token, self.situacao, self.busca)
        except api.ErroValidacao as erro:
            self.mensagem_erro = erro.mensagem
            self.carregou = True
            return
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.penalidades = [_penalidade_para_tela(p) for p in resposta["penalidades"]]
        self.limitada = bool(resposta.get("limitada"))
        self.carregou = True

    @rx.event
    def abrir(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.carregou = False
        return PenalidadesState.carregar

    @rx.event
    def filtrar(self, dados: dict):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.situacao = str(dados.get("situacao") or "EM_VIGOR")
        self.busca = str(dados.get("busca") or "").strip()
        return PenalidadesState.carregar

    @rx.event
    def abrir_anular(self, penalidade: dict):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""
        self.anular = penalidade
        self.anular_aberta = True

    @rx.event
    def mudar_anular(self, aberta: bool):
        self.anular_aberta = aberta

    @rx.event
    async def confirmar_anular(self, dados: dict):
        self.erro_dialogo = ""
        parecer = str(dados.get("parecer") or "").strip()
        if not parecer:
            self.erro_dialogo = "Escreva o parecer da anulação."
            return
        if len(parecer) > TAMANHO_MAXIMO_PARECER:
            self.erro_dialogo = "O parecer deve ter no máximo 500 caracteres."
            return
        token = await token_da_sessao(self)
        try:
            resposta = await api.anular_penalidade(
                token, int(self.anular["id"]), parecer
            )
        except api.ErroValidacao as erro:
            self.erro_dialogo = erro.mensagem
            return
        except api.ErroApi as erro:
            self.anular_aberta = False
            return await tratar_erro_api(self, erro)
        self.anular_aberta = False
        self.mensagem_sucesso = resposta["mensagem"]
        return PenalidadesState.carregar
