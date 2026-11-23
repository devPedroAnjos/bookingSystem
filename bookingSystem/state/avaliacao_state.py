"""Diálogo "Avaliar" de "Minhas reservas" (spec avaliacoes; change espaco-feed-avaliacoes, D16).

Só usabilidade: o envio exige uma nota escolhida, e o comentário tem o mesmo
limite do Xano, que revalida tudo (reserva concluída, prazo e uma por reserva).
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.reservas_state import ReservasState

TAMANHO_MAXIMO_COMENTARIO = 500


class AvaliacaoState(rx.State):
    """Reserva em avaliação, nota escolhida (0 = nenhuma) e a recusa do Xano."""

    aberta: bool = False
    reserva: dict[str, str] = {}
    nota: int = 0
    erro: str = ""

    @rx.event
    def abrir(self, reserva: dict):
        self.reserva = reserva
        self.nota = 0
        self.erro = ""
        self.aberta = True

    @rx.event
    def mudar(self, aberta: bool):
        self.aberta = aberta

    @rx.event
    def escolher(self, nota: int):
        self.nota = nota

    @rx.event
    async def enviar(self, dados: dict):
        self.erro = ""
        if self.nota < 1:
            self.erro = "Escolha uma nota de 1 a 5 estrelas."
            return
        token = await token_da_sessao(self)
        try:
            resposta = await api.avaliar_reserva(
                token,
                int(self.reserva["id"]),
                self.nota,
                str(dados.get("comentario", "") or "").strip(),
            )
        except api.ErroValidacao as erro:
            # Ex.: o prazo terminou depois de a página carregar; o diálogo não fecha
            self.erro = erro.mensagem
            return
        except api.ErroApi as erro:
            self.aberta = False
            return await tratar_erro_api(self, erro)
        self.aberta = False
        reservas = await self.get_state(ReservasState)
        reservas.mensagem_sucesso = resposta["mensagem"]
        return ReservasState.carregar
