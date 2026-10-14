"""Página de login."""

import reflex as rx

from bookingSystem.pages.componentes import cartao, mensagem
from bookingSystem.state.auth_state import AuthState


def login() -> rx.Component:
    return cartao(
        rx.heading("Entrar", size="6"),
        mensagem(AuthState.aviso, "orange"),
        mensagem(AuthState.mensagem_erro, "red"),
        rx.form(
            rx.vstack(
                rx.input(
                    name="email",
                    type="email",
                    placeholder="E-mail institucional",
                    width="100%",
                ),
                rx.input(
                    name="senha",
                    type="password",
                    placeholder="Senha",
                    width="100%",
                ),
                rx.button("Entrar", type="submit", width="100%"),
                spacing="3",
                width="100%",
            ),
            on_submit=AuthState.entrar,
            width="100%",
        ),
        rx.text(
            "Ainda não tem conta? ",
            rx.link("Cadastre-se", href="/cadastro"),
            size="2",
        ),
    )
