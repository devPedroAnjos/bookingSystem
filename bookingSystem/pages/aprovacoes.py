"""Página de pedidos de cadastro (admin e coordenador)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.contas_state import ContasState


def linha_pedido(pedido: rx.Var[dict[str, str]], situacao: str) -> rx.Component:
    acoes = [
        rx.button(
            "Aprovar",
            size="1",
            on_click=ContasState.aprovar(pedido["id"], situacao),
        )
    ]
    if situacao == "PENDENTE":
        acoes.append(
            rx.button(
                "Recusar",
                size="1",
                color_scheme="red",
                variant="soft",
                on_click=ContasState.abrir_recusa(pedido["id"], pedido["nome"]),
            )
        )
    return rx.table.row(
        rx.table.cell(pedido["nome"]),
        rx.table.cell(pedido["email"]),
        rx.table.cell(pedido["papel"]),
        rx.table.cell(pedido["unidade"]),
        rx.table.cell(pedido["pedido"]),
        rx.table.cell(
            pedido["justificativa"] if situacao == "PENDENTE" else pedido["motivo"]
        ),
        rx.table.cell(rx.hstack(*acoes, spacing="2")),
    )


def tabela_pedidos(
    pedidos: rx.Var[list[dict[str, str]]], situacao: str, ultima_coluna: str
) -> rx.Component:
    return rx.table.root(
        rx.table.header(
            rx.table.row(
                *[
                    rx.table.column_header_cell(titulo)
                    for titulo in (
                        "Nome",
                        "E-mail",
                        "Papel pedido",
                        "Unidade",
                        "Pedido nº",
                        ultima_coluna,
                        "",
                    )
                ]
            )
        ),
        rx.table.body(
            rx.foreach(pedidos, lambda pedido: linha_pedido(pedido, situacao))
        ),
        width="100%",
    )


def dialogo_recusa() -> rx.Component:
    return dialogo(
        ContasState.recusa_aberta,
        ContasState.mudar_recusa,
        "Recusar cadastro de " + ContasState.recusa_nome,
        ContasState.confirmar_recusa,
        rx.text("O motivo será mostrado à pessoa quando ela tentar entrar.", size="2"),
        rx.text_area(
            name="motivo",
            placeholder="Motivo da recusa (obrigatório)",
            max_length=500,
            required=True,
            width="100%",
        ),
        botao="Recusar",
    )


def aprovacoes() -> rx.Component:
    return layout_autenticado(
        rx.heading("Aprovações", size="5"),
        mensagem(ContasState.mensagem_erro, "red"),
        mensagem(ContasState.mensagem_sucesso, "green"),
        rx.heading("Pedidos pendentes", size="3"),
        rx.cond(
            ContasState.pedidos.length() > 0,
            tabela_pedidos(ContasState.pedidos, "PENDENTE", "Justificativa"),
            rx.text("Nenhum pedido pendente.", size="2"),
        ),
        rx.cond(
            AuthState.e_admin,
            rx.vstack(
                rx.heading("Contas recusadas", size="3"),
                rx.cond(
                    ContasState.recusadas.length() > 0,
                    tabela_pedidos(ContasState.recusadas, "RECUSADA", "Motivo"),
                    rx.text("Nenhuma conta recusada.", size="2"),
                ),
                width="100%",
                spacing="3",
            ),
        ),
        dialogo_recusa(),
        permitido=AuthState.e_gestor,
    )
