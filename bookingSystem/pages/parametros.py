"""Página de parâmetros (só o admin principal)."""

import reflex as rx

from bookingSystem.pages.componentes import mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.parametros_state import ParametrosState

ROTULOS_LIMITES = {
    "max_pedidos_cadastro": "Máximo de pedidos de cadastro por conta",
    "max_coordenadores_unidade": "Máximo de coordenadores por unidade",
    "max_unidades_coordenador": "Máximo de unidades por coordenador",
    "max_admins": "Máximo de administradores ativos",
}


def campo(rotulo: str, controle: rx.Component) -> rx.Component:
    return rx.vstack(
        rx.text(rotulo, size="2", weight="medium"), controle, spacing="1", width="100%"
    )


def campo_limite(nome: str) -> rx.Component:
    return campo(
        ROTULOS_LIMITES[nome],
        rx.input(
            name=nome,
            type="number",
            min=1,
            default_value=ParametrosState.limites[nome],
            width="160px",
        ),
    )


def formulario() -> rx.Component:
    return rx.form(
        rx.vstack(
            campo(
                "Domínios de e-mail aceitos (separados por vírgula)",
                rx.text_area(
                    name="dominios",
                    default_value=ParametrosState.dominios,
                    width="100%",
                ),
            ),
            *[campo_limite(nome) for nome in ROTULOS_LIMITES],
            rx.button("Salvar", type="submit"),
            spacing="4",
            width="100%",
            max_width="520px",
        ),
        on_submit=ParametrosState.salvar,
        # Recria o formulário a cada carga, para mostrar os valores salvos
        key=ParametrosState.versao,
        width="100%",
    )


def parametros() -> rx.Component:
    return layout_autenticado(
        rx.heading("Parâmetros", size="5"),
        rx.text(
            "Reduzir um limite não remove ninguém; o novo valor vale para as "
            "próximas ações.",
            size="2",
            color_scheme="gray",
        ),
        mensagem(ParametrosState.mensagem_erro, "red"),
        mensagem(ParametrosState.mensagem_sucesso, "green"),
        rx.cond(ParametrosState.versao > 0, formulario(), rx.spinner()),
        permitido=AuthState.e_principal,
    )
