"""Página de troca de senha, aberta a todos e obrigatória com senha provisória."""

import reflex as rx

from bookingSystem.pages.componentes import campo_senha, mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import ROTA_INICIO, AuthState
from bookingSystem.state.senha_state import SenhaState


def trocar_senha() -> rx.Component:
    return layout_autenticado(
        rx.heading("Trocar senha", size="5"),
        rx.cond(
            AuthState.senha_provisoria,
            rx.callout(
                "Sua senha é provisória. Crie uma senha nova para continuar.",
                color_scheme="orange",
                width="100%",
            ),
        ),
        mensagem(SenhaState.mensagem_erro, "red"),
        mensagem(SenhaState.mensagem_sucesso, "green"),
        rx.cond(
            SenhaState.mensagem_sucesso != "",
            rx.link("Ir para o início", href=ROTA_INICIO, size="2"),
        ),
        rx.form(
            rx.vstack(
                campo_senha("senha_atual", "Senha atual"),
                campo_senha("nova_senha", "Nova senha (mínimo de 8 caracteres)"),
                campo_senha("confirmacao", "Confirme a nova senha"),
                rx.button("Trocar senha", type="submit"),
                spacing="3",
                width="100%",
                max_width="420px",
            ),
            on_submit=SenhaState.trocar,
            reset_on_submit=True,
            width="100%",
        ),
        aceita_senha_provisoria=True,
    )
