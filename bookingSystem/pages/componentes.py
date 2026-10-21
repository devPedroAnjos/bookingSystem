"""Componentes visuais compartilhados pelas páginas."""

import reflex as rx


def mensagem(texto: rx.Var[str], cor: str) -> rx.Component:
    """Mostra a mensagem só quando o texto não está vazio."""
    return rx.cond(
        texto != "", rx.callout(texto, color_scheme=cor, width="100%")
    )


def campo_senha(nome: str, placeholder: str) -> rx.Component:
    """Campo de senha de formulário (o valor não passa pelo State)."""
    return rx.input(
        name=nome, type="password", placeholder=placeholder, width="100%"
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
    valor_inicial: str | rx.Var[str] | None = None,
) -> rx.Component:
    """Select de formulário a partir de uma lista de {id, nome}."""
    extras = {} if valor_inicial is None else {"default_value": valor_inicial}
    return rx.select.root(
        rx.select.trigger(placeholder=placeholder, width="100%"),
        rx.select.content(
            rx.foreach(
                opcoes,
                lambda opcao: rx.select.item(opcao[rotulo], value=opcao["id"]),
            ),
        ),
        name=nome,
        **extras,
    )


def dialogo(
    aberto: rx.Var[bool],
    ao_mudar,
    titulo: str | rx.Var[str],
    ao_enviar,
    *campos: rx.Component,
    botao: str = "Confirmar",
    limpar_ao_enviar: bool = True,
) -> rx.Component:
    """Diálogo controlado pelo State, com um formulário e Cancelar/Confirmar.

    Com limpar_ao_enviar=False, um erro de validação mantém o que foi digitado
    (o conteúdo é remontado a cada abertura, então não fica valor antigo).
    """
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
                reset_on_submit=limpar_ao_enviar,
                width="100%",
            ),
        ),
        open=aberto,
        on_open_change=ao_mudar,
    )
