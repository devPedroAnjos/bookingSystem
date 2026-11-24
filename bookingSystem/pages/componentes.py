"""Componentes visuais compartilhados pelas páginas."""

import reflex as rx

from bookingSystem.state.motivos import (
    AVISO_OUTRO_VISIVEL,
    OUTRO,
    TAMANHO_MAXIMO_DESCRICAO,
    ImpactoState,
    MotivoState,
)


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
    """Cartão centralizado das páginas de formulário, com o logotipo (D18)."""
    from bookingSystem.pages.marca import logotipo

    return rx.center(
        rx.vstack(
            rx.link(rx.hstack(rx.icon("arrow-left", size=16), rx.text("Voltar"), spacing="1",
                              align="center"),
                    href="/", size="2", color="var(--bs-ink-muted)"),
            rx.box(
                rx.vstack(logotipo(184), *filhos, spacing="4", width="100%"),
                width="100%",
                background="var(--bs-surface)",
                border="1px solid var(--bs-line)",
                border_radius="var(--bs-radius-lg)",
                padding="32px",
                box_shadow="var(--bs-shadow-3)",
            ),
            width="100%",
            max_width="420px",
            spacing="3",
        ),
        min_height="100vh",
        padding="16px",
        background="var(--bs-bg)",
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


def campos_motivo(motivos: dict[str, str], aviso_outro: bool) -> rx.Component:
    """Caixa de seleção do motivo e, em "Outro", o campo de descrição (D17).

    Os nomes `motivo_codigo` e `motivo_descricao` são os da API.
    """
    return rx.vstack(
        rx.select.root(
            rx.select.trigger(placeholder="Motivo", width="100%"),
            rx.select.content(
                *[
                    rx.select.item(rotulo, value=codigo)
                    for codigo, rotulo in motivos.items()
                ]
            ),
            name="motivo_codigo",
            on_change=MotivoState.escolher,
        ),
        rx.cond(
            MotivoState.codigo == OUTRO,
            rx.text_area(
                name="motivo_descricao",
                placeholder="Descreva o motivo",
                max_length=TAMANHO_MAXIMO_DESCRICAO,
                width="100%",
            ),
        ),
        rx.text(AVISO_OUTRO_VISIVEL, size="1") if aviso_outro else rx.fragment(),
        spacing="2",
        width="100%",
    )


def aviso_impacto(prefixo: str = "") -> rx.Component:
    """Reservas afetadas pela ação do diálogo, vindas da rota de impacto (D8)."""
    return rx.cond(
        ImpactoState.aviso != "",
        rx.callout(prefixo + ImpactoState.aviso, color_scheme="orange", width="100%"),
    )


def dialogo(
    aberto: rx.Var[bool],
    ao_mudar,
    titulo: str | rx.Var[str],
    ao_enviar,
    *campos: rx.Component,
    botao: str | rx.Var[str] = "Confirmar",
    limpar_ao_enviar: bool = True,
    botao_desabilitado: rx.Var[bool] | bool = False,
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
                        rx.button(botao, type="submit", disabled=botao_desabilitado),
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
