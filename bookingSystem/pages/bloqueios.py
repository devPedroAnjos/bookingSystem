"""Página de bloqueios (admin e coordenador, no próprio escopo, C11)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem, seletor
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.bloqueios_state import (
    TAMANHO_MAXIMO_MOTIVO,
    TODAS,
    BloqueiosState,
)
from bookingSystem.state.motivos import TIPOS_BLOQUEIO

AVISO_EFEITOS = (
    "As reservas sobrepostas ao período que ainda não começaram serão canceladas, "
    "e as entradas de fila sobrepostas serão encerradas, sem penalidade. A remoção "
    "do bloqueio não as restaura. Se houver reserva em andamento no período, o "
    "bloqueio é recusado."
)


def campo(rotulo: str, controle: rx.Component) -> rx.Component:
    return rx.vstack(
        rx.text(rotulo, size="2", weight="medium"), controle, spacing="1", width="100%"
    )


def filtro() -> rx.Component:
    return rx.hstack(
        rx.text("Unidade", size="2", weight="medium"),
        rx.select.root(
            rx.select.trigger(width="260px"),
            rx.select.content(
                rx.select.item("Todas as unidades", value=TODAS),
                rx.foreach(
                    BloqueiosState.unidades,
                    lambda u: rx.select.item(u["nome"], value=u["id"]),
                ),
            ),
            value=BloqueiosState.filtro_unidade,
            on_change=BloqueiosState.filtrar_unidade,
        ),
        rx.spacer(),
        rx.button("Novo bloqueio", on_click=BloqueiosState.mudar_criar(True)),
        align="center",
        width="100%",
    )


def linha(bloqueio: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.table.row(
        rx.table.cell(rx.text(bloqueio["espaco"], weight="medium")),
        rx.table.cell(bloqueio["unidade"]),
        rx.table.cell(rx.badge(bloqueio["tipo"], color_scheme="orange")),
        rx.table.cell(bloqueio["motivo"]),
        rx.table.cell(bloqueio["inicio"]),
        rx.table.cell(bloqueio["fim"]),
        rx.table.cell(bloqueio["criado_por"]),
        rx.table.cell(
            rx.button(
                "Remover",
                size="1",
                color_scheme="red",
                variant="soft",
                on_click=BloqueiosState.abrir_remover(bloqueio),
            )
        ),
    )


def lista() -> rx.Component:
    return rx.cond(
        BloqueiosState.bloqueios.length() > 0,
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in (
                            "Espaço", "Unidade", "Tipo", "Motivo",
                            "Início", "Fim", "Criado por", "",
                        )
                    ]
                )
            ),
            rx.table.body(rx.foreach(BloqueiosState.bloqueios, linha)),
            width="100%",
        ),
        rx.callout("Nenhum bloqueio ativo.", width="100%"),
    )


def dialogo_criar() -> rx.Component:
    return dialogo(
        BloqueiosState.criar_aberta,
        BloqueiosState.mudar_criar,
        "Novo bloqueio",
        BloqueiosState.confirmar_criar,
        campo(
            "Espaço",
            seletor("espaco_id", BloqueiosState.espacos, "Escolha o espaço"),
        ),
        campo(
            "Tipo",
            rx.select.root(
                rx.select.trigger(placeholder="Escolha o tipo", width="100%"),
                rx.select.content(
                    *[
                        rx.select.item(rotulo, value=codigo)
                        for codigo, rotulo in TIPOS_BLOQUEIO.items()
                    ]
                ),
                name="tipo",
            ),
        ),
        campo(
            "Motivo",
            rx.text_area(
                name="motivo",
                placeholder="Ex.: troca dos computadores",
                max_length=TAMANHO_MAXIMO_MOTIVO,
                width="100%",
            ),
        ),
        rx.hstack(
            campo("Data de início", rx.input(name="data_inicio", type="date")),
            campo("Hora de início", rx.input(name="hora_inicio", type="time")),
            width="100%",
        ),
        rx.hstack(
            campo("Data de fim", rx.input(name="data_fim", type="date")),
            campo("Hora de fim", rx.input(name="hora_fim", type="time")),
            width="100%",
        ),
        rx.callout(AVISO_EFEITOS, color_scheme="orange", width="100%"),
        mensagem(BloqueiosState.erro_dialogo, "red"),
        botao="Bloquear",
        limpar_ao_enviar=False,
    )


def dialogo_remover() -> rx.Component:
    return dialogo(
        BloqueiosState.remover_aberta,
        BloqueiosState.mudar_remover,
        "Remover bloqueio",
        BloqueiosState.confirmar_remover,
        rx.text(BloqueiosState.remover_texto, size="2"),
        rx.text(
            "O espaço volta a aceitar reservas no período. As reservas canceladas "
            "e as entradas de fila encerradas não são restauradas.",
            size="2",
        ),
        botao="Remover",
    )


def bloqueios() -> rx.Component:
    return layout_autenticado(
        rx.heading("Bloqueios", size="5"),
        mensagem(BloqueiosState.mensagem_erro, "red"),
        mensagem(BloqueiosState.mensagem_sucesso, "green"),
        filtro(),
        lista(),
        dialogo_criar(),
        dialogo_remover(),
        permitido=AuthState.e_gestor,
    )
