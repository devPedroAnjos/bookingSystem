"""Seção "Faltas e penalidades" de "Minhas reservas" (C10, spec penalidades).

Só usabilidade: as faltas, as penalidades, a situação efetiva e `em_vigor`
vêm do Xano (`minhas_faltas`), que grava antes os vencimentos do usuário
(design D3). O parecer da anulação aparece sem o nome de quem anulou.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api

TIPOS_FALTA = {
    "NAO_COMPARECIMENTO": "Não compareceu",
    "CANCELAMENTO_TARDIO": "Cancelou depois do prazo",
}

SITUACOES_PENALIDADE = {
    "ATIVA": "Ativa",
    "CUMPRIDA": "Cumprida",
    "ANULADA": "Anulada",
}


def _data_br(data: str) -> str:
    ano, mes, dia = data.split("-")
    return f"{dia}/{mes}/{ano}"


def _falta_para_tela(falta: dict) -> dict[str, str]:
    espaco = falta.get("espaco") or {}
    return {
        "id": str(falta["id"]),
        "tipo": TIPOS_FALTA.get(falta["tipo"], falta["tipo"]),
        "ocorrida_em": falta["ocorrida_em"],
        "reserva": (
            f"{espaco.get('codigo', '')} — {_data_br(falta['data'])}, "
            f"{falta['hora_inicio']} às {falta['hora_fim']}"
        ),
        "penalidade": "sim" if falta.get("gerou_penalidade") else "nao",
    }


def _penalidade_para_tela(penalidade: dict) -> dict[str, str]:
    situacao = SITUACOES_PENALIDADE.get(penalidade["status"], penalidade["status"])
    if penalidade.get("em_vigor"):
        situacao = "Em vigor"
    return {
        "id": str(penalidade["id"]),
        "periodo": f"{penalidade['inicio']} a {penalidade['fim']}",
        "status": penalidade["status"],
        "situacao": situacao,
        "parecer": penalidade.get("parecer") or "",
    }


class FaltasState(rx.State):
    """Faltas e penalidades do usuário, com a penalidade em vigor em destaque."""

    faltas: list[dict[str, str]] = []
    penalidades: list[dict[str, str]] = []
    em_vigor: bool = False
    ate: str = ""
    carregou: bool = False
    mensagem_erro: str = ""

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            resposta = await api.minhas_faltas(token)
        except api.NaoAutenticado as erro:
            return await tratar_erro_api(self, erro)
        except api.ErroApi:
            # A seção não pode impedir o uso da página
            self.mensagem_erro = "Não foi possível carregar as faltas e penalidades."
            self.carregou = True
            return
        self.faltas = [_falta_para_tela(f) for f in resposta["faltas"]]
        self.penalidades = [
            _penalidade_para_tela(p) for p in resposta["penalidades"]
        ]
        self.em_vigor = bool(resposta.get("em_vigor"))
        self.ate = resposta.get("ate") or ""
        self.carregou = True

    @rx.event
    def abrir(self):
        """Usado por "Minhas reservas": limpa a mensagem e recarrega."""
        self.mensagem_erro = ""
        self.carregou = False
        return FaltasState.carregar

    @rx.event
    def limpar(self):
        """No login e no cadastro: nada da conta anterior aparece para a próxima."""
        self.faltas = []
        self.penalidades = []
        self.em_vigor = False
        self.ate = ""
        self.carregou = False
        self.mensagem_erro = ""
