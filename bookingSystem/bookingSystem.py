"""Aplicação Reflex do BookingSystem: registro das páginas.

As guardas por papel no on_load são usabilidade; o Xano decide o acesso.
"""

import reflex as rx

from bookingSystem.pages.administradores import administradores
from bookingSystem.pages.aprovacoes import aprovacoes
from bookingSystem.pages.cadastro import cadastro
from bookingSystem.pages.inicio import inicio
from bookingSystem.pages.login import login
from bookingSystem.pages.parametros import parametros
from bookingSystem.pages.trocar_senha import trocar_senha
from bookingSystem.pages.unidades import unidades
from bookingSystem.pages.usuarios import usuarios
from bookingSystem.state.admins_state import AdminsState
from bookingSystem.state.auth_state import (
    ROTA_INICIO,
    ROTA_LOGIN,
    ROTA_TROCAR_SENHA,
    AuthState,
)
from bookingSystem.state.contas_state import ContasState
from bookingSystem.state.parametros_state import ParametrosState
from bookingSystem.state.senha_state import SenhaState
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
app.add_page(
    trocar_senha,
    route=ROTA_TROCAR_SENHA,
    title="Trocar senha | BookingSystem",
    on_load=[AuthState.verificar_sessao_troca_senha, SenhaState.abrir],
)
app.add_page(
    administradores,
    route="/administradores",
    title="Administradores | BookingSystem",
    on_load=[AuthState.exigir_principal, AdminsState.abrir],
)
app.add_page(
    parametros,
    route="/parametros",
    title="Parâmetros | BookingSystem",
    on_load=[AuthState.exigir_principal, ParametrosState.abrir],
)
app.add_page(rx.fragment, route="/", on_load=rx.redirect(ROTA_INICIO))
