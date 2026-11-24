"""Página inicial: cartão da próxima reserva e o feed de espaços (espaco-feed-avaliacoes, D13)."""

import reflex as rx

from bookingSystem.pages.componentes import mensagem
from bookingSystem.pages.feed import feed
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.reservas_state import ReservasState


def cartao_proxima() -> rx.Component:
    """Próxima reserva indicada pelo Xano, com o check-in quando a janela está aberta."""
    reserva = ReservasState.proxima
    return rx.cond(
        reserva.contains("id"),
        rx.vstack(
            rx.text("PRÓXIMA RESERVA · " + reserva["situacao"], size="1", weight="bold",
                    letter_spacing="0.06em", color="var(--bs-green-200)"),
            rx.text(reserva["data"] + " · " + reserva["horario"], size="6", weight="bold"),
            rx.text(reserva["espaco"] + " · " + reserva["unidade"], size="2",
                    color="var(--bs-green-100)"),
            rx.cond(
                reserva["check_in"] != "",
                rx.hstack(rx.icon("circle-check", size=15),
                          rx.text("Check-in às " + reserva["check_in"], size="2"),
                          spacing="1", align="center", color="var(--bs-accent)"),
                rx.cond(
                    reserva["checkin_possivel"] == "sim",
                    rx.vstack(
                        rx.hstack(rx.icon("clock", size=15), rx.text(reserva["janela"], size="2"),
                                  spacing="1", align="center", color="var(--bs-accent)"),
                        rx.button(
                            rx.icon("qr-code", size=16), "Fazer check-in",
                            on_click=ReservasState.fazer_checkin(reserva["id"]),
                            size="3", width="100%",
                            background="var(--bs-accent)", color="var(--bs-on-accent)",
                        ),
                        spacing="2", width="100%",
                    ),
                ),
            ),
            spacing="2",
            padding="20px",
            border_radius="var(--bs-radius-lg)",
            background="var(--bs-brand-deep)",
            color="var(--bs-on-brand-deep)",
            width="100%",
            max_width="380px",
        ),
    )


def inicio() -> rx.Component:
    return layout_autenticado(
        mensagem(AuthState.mensagem_erro, "red"),
        rx.heading("Olá, " + AuthState.primeiro_nome, size="7"),
        mensagem(ReservasState.mensagem_erro, "red"),
        mensagem(ReservasState.mensagem_sucesso, "green"),
        cartao_proxima(),
        feed(),
    )
