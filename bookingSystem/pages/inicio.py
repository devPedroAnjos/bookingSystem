"""Página inicial do usuário autenticado."""

import reflex as rx

from bookingSystem.pages.componentes import mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState


def inicio() -> rx.Component:
    return layout_autenticado(
        mensagem(AuthState.mensagem_erro, "red"),
        rx.text("Olá, ", rx.text.strong(AuthState.nome), "!", size="4"),
    )
