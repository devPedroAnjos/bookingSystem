"""Página inicial do usuário autenticado."""

import reflex as rx

from bookingSystem.pages.componentes import mensagem
from bookingSystem.state.auth_state import AuthState


def inicio() -> rx.Component:
    return rx.container(
        rx.cond(
            AuthState.nome != "",
            rx.vstack(
                rx.hstack(
                    rx.heading("BookingSystem", size="6"),
                    rx.spacer(),
                    rx.button("Sair", on_click=AuthState.sair, variant="soft"),
                    width="100%",
                    align="center",
                ),
                mensagem(AuthState.mensagem_erro, "red"),
                rx.text(
                    "Olá, ", rx.text.strong(AuthState.nome), "!", size="4"
                ),
                rx.badge(AuthState.nome_papel, size="2"),
                spacing="4",
                padding_y="24px",
            ),
            rx.center(rx.spinner(), min_height="50vh"),
        ),
    )
