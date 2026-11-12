"""Página "Minhas reservas" (todos os papéis)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.reservas_state import ReservasState

CORES_SITUACAO = {
    "CONFIRMADA": "green",
    "PENDENTE": "orange",
    "CANCELADA": "gray",
    "RECUSADA": "red",
}


def situacao(reserva: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.vstack(
        rx.badge(
            reserva["situacao"],
            color_scheme=rx.match(
                reserva["status"],
                *CORES_SITUACAO.items(),
                "gray",
            ),
        ),
        rx.cond(reserva["motivo"] != "", rx.text(reserva["motivo"], size="1")),
        spacing="1",
    )


def linha(reserva: rx.Var[dict[str, str]], com_cancelar: bool) -> rx.Component:
    return rx.table.row(
        rx.table.cell(reserva["data"]),
        rx.table.cell(reserva["horario"]),
        rx.table.cell(
            rx.text(reserva["codigo"] + " — " + reserva["espaco"], weight="medium"),
            rx.text(reserva["tipo"], size="1"),
        ),
        rx.table.cell(reserva["unidade"]),
        rx.table.cell(situacao(reserva)),
        rx.table.cell(
            rx.cond(
                reserva["pode_cancelar"] == "sim",
                rx.button(
                    "Cancelar",
                    size="1",
                    color_scheme="red",
                    variant="soft",
                    on_click=ReservasState.abrir_cancelar(reserva),
                ),
            )
            if com_cancelar
            else rx.fragment()
        ),
    )


def tabela(reservas, com_cancelar: bool, vazio: str) -> rx.Component:
    return rx.cond(
        reservas.length() > 0,
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in (
                            "Data",
                            "Horário",
                            "Espaço",
                            "Unidade",
                            "Situação",
                            "",
                        )
                    ]
                )
            ),
            rx.table.body(
                rx.foreach(reservas, lambda reserva: linha(reserva, com_cancelar))
            ),
            width="100%",
        ),
        rx.text(vazio, size="2", color_scheme="gray"),
    )


def dialogo_cancelar() -> rx.Component:
    reserva = ReservasState.cancelar
    return dialogo(
        ReservasState.cancelar_aberta,
        ReservasState.mudar_cancelar,
        "Cancelar a reserva de " + reserva["codigo"],
        ReservasState.confirmar_cancelar,
        rx.text(
            reserva["data"] + ", " + reserva["horario"] + " — " + reserva["espaco"],
            size="2",
        ),
        rx.text("O horário volta a ficar livre para outras pessoas.", size="2"),
        mensagem(ReservasState.erro_dialogo, "red"),
        botao="Cancelar a reserva",
        limpar_ao_enviar=False,
    )


def minhas_reservas() -> rx.Component:
    return layout_autenticado(
        rx.heading("Minhas reservas", size="5"),
        rx.cond(
            ReservasState.prazo_minutos > 0,
            rx.text(
                "Você pode cancelar sem penalidade até "
                + ReservasState.prazo_minutos.to_string()
                + " minutos antes do início.",
                size="2",
                color_scheme="gray",
            ),
        ),
        mensagem(ReservasState.mensagem_erro, "red"),
        mensagem(ReservasState.mensagem_sucesso, "green"),
        rx.cond(
            ReservasState.carregou,
            rx.vstack(
                rx.heading("Próximas", size="4"),
                tabela(ReservasState.proximas, True, "Nenhuma reserva próxima."),
                rx.heading("Histórico", size="4"),
                tabela(ReservasState.historico, False, "Nenhuma reserva no histórico."),
                spacing="4",
                width="100%",
            ),
            rx.spinner(),
        ),
        dialogo_cancelar(),
    )
