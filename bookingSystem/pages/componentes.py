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


def seletor(
    nome: str | rx.Var[str],
    opcoes: rx.Var[list[dict[str, str]]],
    placeholder: str | rx.Var[str],
    rotulo: str = "nome",
) -> rx.Component:
    """Select de formulário a partir de uma lista de {id, nome}."""
    return rx.select.root(
        rx.select.trigger(placeholder=placeholder, width="100%"),
        rx.select.content(
            rx.foreach(
                opcoes,
                lambda opcao: rx.select.item(opcao[rotulo], value=opcao["id"]),
            ),
        ),
        name=nome,
    )


def dialogo(
    aberto: rx.Var[bool],
    ao_mudar,
    titulo: str | rx.Var[str],
    ao_enviar,
    *campos: rx.Component,
    botao: str = "Confirmar",
) -> rx.Component:
    """Diálogo controlado pelo State, com um formulário e Cancelar/Confirmar."""
    return rx.dialog.root(
        rx.dialog.content(
            rx.dialog.title(titulo),
            rx.form(
                rx.vstack(
                    *campos,
                    rx.hstack(
                        rx.dialog.close(
                            rx.button("Cancelar", variant="soft", type="button")
                        ),
                        rx.button(botao, type="submit"),
                        justify="end",
                        width="100%",
                    ),
                    spacing="3",
                    width="100%",
                ),
                on_submit=ao_enviar,
                reset_on_submit=True,
                width="100%",
            ),
        ),
        open=aberto,
        on_open_change=ao_mudar,
    )
