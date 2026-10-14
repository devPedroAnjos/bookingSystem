"""Componentes visuais compartilhados pelas páginas."""

import reflex as rx


def mensagem(texto: rx.Var[str], cor: str) -> rx.Component:
    """Mostra a mensagem só quando o texto não está vazio."""
    return rx.cond(
        texto != "", rx.callout(texto, color_scheme=cor, width="100%")
    )


def cartao(*filhos: rx.Component) -> rx.Component:
    """Cartão centralizado usado nas páginas de formulário."""
    return rx.center(
        rx.card(
            rx.vstack(*filhos, spacing="4", width="100%"),
            width="100%",
            max_width="420px",
        ),
        min_height="85vh",
        padding="16px",
    )
