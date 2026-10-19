"""Página de login, com o painel de pedido recusado."""

import reflex as rx

from bookingSystem.pages.componentes import cartao, mensagem, seletor
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.pedido_state import PedidoState


def formulario_reenvio() -> rx.Component:
    """Pede nova análise: a senha é digitada de novo e não fica no State."""
    return rx.form(
        rx.vstack(
            rx.text(
                "Você pode enviar mais ",
                PedidoState.pedidos_restantes,
                " pedido(s).",
                size="2",
            ),
            rx.select.root(
                rx.select.trigger(width="100%"),
                rx.select.content(
                    rx.select.item("Professor", value="PROFESSOR"),
                    rx.select.item("Coordenador", value="COORDENADOR"),
                ),
                value=PedidoState.papel,
                on_change=PedidoState.escolher_papel,
            ),
            seletor("unidade_id", PedidoState.unidades, "Unidade"),
            rx.text_area(
                name="justificativa",
                placeholder="Justificativa (opcional)",
                max_length=500,
                width="100%",
            ),
            rx.input(
                name="senha",
                type="password",
                placeholder="Confirme sua senha",
                width="100%",
            ),
            rx.button("Pedir nova análise", type="submit", width="100%"),
            spacing="3",
            width="100%",
        ),
        on_submit=PedidoState.reenviar,
        width="100%",
    )


def painel_recusa() -> rx.Component:
    return rx.card(
        rx.vstack(
            rx.heading("Cadastro recusado", size="4"),
            rx.text("Motivo: ", rx.text.strong(PedidoState.motivo), size="2"),
            mensagem(PedidoState.mensagem_erro, "red"),
            rx.cond(
                PedidoState.pode_reenviar,
                formulario_reenvio(),
                rx.text(
                    "Os pedidos de cadastro se esgotaram. "
                    "Procure a administração.",
                    size="2",
                ),
            ),
            spacing="3",
            width="100%",
        ),
        width="100%",
    )


def login() -> rx.Component:
    return cartao(
        rx.heading("Entrar", size="6"),
        mensagem(AuthState.aviso, "orange"),
        rx.cond(
            PedidoState.recusado,
            rx.fragment(),
            mensagem(AuthState.mensagem_erro, "red"),
        ),
        mensagem(PedidoState.mensagem_sucesso, "green"),
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
        rx.cond(PedidoState.recusado, painel_recusa()),
        rx.text(
            "Ainda não tem conta? ",
            rx.link("Cadastre-se", href="/cadastro"),
            size="2",
        ),
    )
