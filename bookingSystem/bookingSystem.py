"""Aplicação Reflex do BookingSystem: registro das páginas.

As guardas por papel no on_load são usabilidade; o Xano decide o acesso.
"""

import reflex as rx

from bookingSystem.pages.aprovacoes import aprovacoes
from bookingSystem.pages.cadastro import cadastro
from bookingSystem.pages.inicio import inicio
from bookingSystem.pages.login import login
from bookingSystem.pages.unidades import unidades
from bookingSystem.pages.usuarios import usuarios
from bookingSystem.state.auth_state import ROTA_INICIO, ROTA_LOGIN, AuthState
from bookingSystem.state.contas_state import ContasState
from bookingSystem.state.unidades_state import UnidadesState

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
app.add_page(
    aprovacoes,
    route="/aprovacoes",
    title="Aprovações | BookingSystem",
    on_load=[AuthState.exigir_gestor, ContasState.abrir_aprovacoes],
)
app.add_page(
    usuarios,
    route="/usuarios",
    title="Usuários | BookingSystem",
    on_load=[AuthState.exigir_admin, ContasState.abrir_usuarios],
)
app.add_page(
    unidades,
    route="/unidades",
    title="Unidades | BookingSystem",
    on_load=[AuthState.exigir_admin, UnidadesState.abrir],
)
app.add_page(rx.fragment, route="/", on_load=rx.redirect(ROTA_INICIO))
