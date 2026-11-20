"""Estado da página "Minhas reservas" (todos os papéis).

Só usabilidade: a lista, a data e as horas em São Paulo e `pode_cancelar` vêm
do Xano (design D9), que revalida o prazo ao cancelar (D6). Desde a C7, o
`status` é a situação efetiva: a pendente vencida chega EXPIRADA e vai para o
histórico; a recusada traz o motivo da recusa.

C10 (design D10): a confirmada sem check-in depois da janela chega
NAO_COMPARECEU e a com check-in depois do fim, CONCLUIDA. O check-in e o
cancelamento tardio são revalidados no Xano; quando o cancelamento passa a
gerar falta depois de a página carregar, a API pede a confirmação e o diálogo
mostra o aviso antes de enviar de novo com `aceitar_falta`.
"""

import time

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.faltas_state import TIPOS_FALTA, FaltasState
from bookingSystem.state.motivos import texto_motivo

ATIVAS = ("PENDENTE", "CONFIRMADA")

SITUACOES = {
    "PENDENTE": "Aguardando aprovação",
    "CONFIRMADA": "Confirmada",
    "CONCLUIDA": "Concluída",
    "NAO_COMPARECEU": "Não compareceu",
    "CANCELADA": "Cancelada",
    "RECUSADA": "Recusada",
    "EXPIRADA": "Expirada",
}


def _data_br(data: str) -> str:
    ano, mes, dia = data.split("-")
    return f"{dia}/{mes}/{ano}"


def _reserva_para_tela(reserva: dict) -> dict[str, str]:
    return {
        "id": str(reserva["id"]),
        "codigo": reserva["espaco"]["codigo"],
        "espaco": reserva["espaco"]["nome"],
        "unidade": reserva["unidade"]["nome"],
        "tipo": reserva["tipo"]["nome"],
        "data": _data_br(reserva["data"]),
        "horario": f"{reserva['hora_inicio']} às {reserva['hora_fim']}",
        "status": reserva["status"],
        "situacao": SITUACOES.get(reserva["status"], reserva["status"]),
        "motivo": texto_motivo(reserva),
        "pode_cancelar": "sim" if reserva.get("pode_cancelar") else "nao",
        "gera_falta": "sim" if reserva.get("cancelamento_gera_falta") else "nao",
        "checkin_possivel": "sim" if reserva.get("checkin_possivel") else "nao",
        "check_in": reserva.get("check_in_hora") or "",
        "janela": (
            f"Check-in das {reserva.get('checkin_abre', '')} às "
            f"{reserva.get('checkin_fecha', '')}"
        ),
        "falta": TIPOS_FALTA.get(reserva.get("falta") or "", ""),
    }


def _e_proxima(reserva: dict, agora_ms: int) -> bool:
    """Pendente ou confirmada que ainda não terminou."""
    return reserva["status"] in ATIVAS and reserva["fim"] > agora_ms


class ReservasState(rx.State):
    """Reservas do usuário, separadas em próximas e histórico."""

    proximas: list[dict[str, str]] = []
    historico: list[dict[str, str]] = []
    prazo_minutos: int = 0
    carregou: bool = False
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    erro_dialogo: str = ""

    cancelar_aberta: bool = False
    cancelar: dict[str, str] = {}

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            resposta = await api.minhas_reservas(token)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        agora_ms = int(time.time() * 1000)
        reservas = resposta["reservas"]
        # A API devolve da mais recente para a mais antiga (D9)
        proximas = [r for r in reservas if _e_proxima(r, agora_ms)]
        self.proximas = [_reserva_para_tela(r) for r in reversed(proximas)]
        self.historico = [
            _reserva_para_tela(r) for r in reservas if not _e_proxima(r, agora_ms)
        ]
        self.prazo_minutos = resposta["prazo_cancelamento_minutos"]
        self.carregou = True

    @rx.event
    def abrir(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.carregou = False
        return ReservasState.carregar

    @rx.event
    async def fazer_checkin(self, reserva_id: str):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        token = await token_da_sessao(self)
        try:
            resposta = await api.fazer_checkin(token, int(reserva_id))
        except api.ErroValidacao as erro:
            # Ex.: a janela fechou depois de a página carregar
            self.mensagem_erro = erro.mensagem
            return [ReservasState.carregar, FaltasState.carregar]
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.mensagem_sucesso = resposta["mensagem"]
        return ReservasState.carregar

    @rx.event
    def abrir_cancelar(self, reserva: dict):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""
        self.cancelar = reserva
        self.cancelar_aberta = True

    @rx.event
    def mudar_cancelar(self, aberta: bool):
        self.cancelar_aberta = aberta

    @rx.event
    async def confirmar_cancelar(self, _dados: dict):
        self.erro_dialogo = ""
        token = await token_da_sessao(self)
        # Só aceita a falta se o diálogo mostrou o aviso antes do clique
        aceitar_falta = self.cancelar.get("gera_falta") == "sim"
        try:
            resposta = await api.cancelar_reserva(
                token, int(self.cancelar["id"]), aceitar_falta
            )
        except api.ErroValidacao as erro:
            # Ex.: a reserva começou depois de a página carregar
            self.erro_dialogo = erro.mensagem
            return
        except api.ErroApi as erro:
            self.cancelar_aberta = False
            return await tratar_erro_api(self, erro)
        if resposta.get("requer_confirmacao"):
            # O prazo venceu depois de a página carregar: mostra o aviso e espera
            # um novo clique, sem fechar o diálogo (spec reservas, tela)
            self.cancelar = {**self.cancelar, "gera_falta": "sim"}
            self.erro_dialogo = resposta["mensagem"]
            return
        self.cancelar_aberta = False
        self.mensagem_sucesso = resposta["mensagem"]
        return [ReservasState.carregar, FaltasState.carregar]
