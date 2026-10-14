"""Aplicação Reflex do BookingSystem: registro das páginas."""

import reflex as rx

from bookingSystem.pages.cadastro import cadastro
from bookingSystem.pages.inicio import inicio
from bookingSystem.pages.login import login
from bookingSystem.state.auth_state import ROTA_INICIO, ROTA_LOGIN, AuthState

app = rx.App()
app.add_page(
    login,
    route=ROTA_LOGIN,
    title="Entrar | BookingSystem",
    on_load=AuthState.abrir_formulario,
)
app.add_page(
    cadastro,
    route="/cadastro",
    title="Criar conta | BookingSystem",
    on_load=AuthState.abrir_formulario,
)
app.add_page(
    inicio,
    route=ROTA_INICIO,
    title="Início | BookingSystem",
    on_load=AuthState.verificar_sessao,
)
app.add_page(rx.fragment, route="/", on_load=rx.redirect(ROTA_INICIO))
