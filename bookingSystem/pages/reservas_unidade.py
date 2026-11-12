"""Página "Reservas da unidade" (coordenador e admin)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem, seletor
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.pages.minhas_reservas import CORES_SITUACAO
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.reservas_unidade_state import (
    TODAS_UNIDADES,
    TODOS_ESPACOS,
    ReservasUnidadeState,
)


def campo(rotulo: str, controle: rx.Component) -> rx.Component:
    return rx.vstack(
        rx.text(rotulo, size="2", weight="medium"), controle, spacing="1"
    )


def filtros() -> rx.Component:
    return rx.form(
        rx.hstack(
            campo(
                "Unidade",
                rx.select.root(
                    rx.select.trigger(placeholder="Todas as unidades", width="100%"),
                    rx.select.content(
                        rx.foreach(
                            ReservasUnidadeState.opcoes_unidade,
                            lambda opcao: rx.select.item(
                                opcao["nome"], value=opcao["id"]
                            ),
                        ),
                    ),
                    name="unidade_id",
                    default_value=TODAS_UNIDADES,
                    on_change=ReservasUnidadeState.escolher_unidade,
                ),
            ),
            campo(
                "Espaço",
                # A key recria o seletor quando a unidade muda: o espaço escolhido
                # antes não fica preso a uma unidade que deixou de ser filtrada
                rx.box(
                    seletor(
                        "espaco_id",
                        ReservasUnidadeState.opcoes_espaco,
                        "Todos os espaços",
                        valor_inicial=TODOS_ESPACOS,
                    ),
                    key=ReservasUnidadeState.unidade_escolhida,
                ),
            ),
            campo(
                "Situação",
                seletor(
                    "situacao",
                    ReservasUnidadeState.opcoes_situacao,
                    "Pendentes",
                    valor_inicial="PENDENTE",
                ),
            ),
            campo("De", rx.input(name="data_inicial", type="date")),
            campo("Até", rx.input(name="data_final", type="date")),
            rx.button("Filtrar", type="submit"),
            spacing="4",
            wrap="wrap",
            align="end",
        ),
        on_submit=ReservasUnidadeState.filtrar,
        width="100%",
    )


def acoes(reserva: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.cond(
        reserva["status"] == "PENDENTE",
        rx.hstack(
            rx.button(
                "Aprovar",
                size="1",
                on_click=ReservasUnidadeState.aprovar(reserva["id"]),
            ),
            rx.button(
                "Recusar",
                size="1",
                color_scheme="red",
                variant="soft",
                on_click=ReservasUnidadeState.abrir_recusa(reserva),
            ),
            spacing="2",
        ),
    )


def linha(reserva: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.table.row(
        rx.table.cell(
            rx.text(reserva["dono"], weight="medium"),
            rx.text(reserva["email"], size="1"),
            rx.text(reserva["papel"], size="1", color_scheme="gray"),
        ),
        rx.table.cell(
            rx.text(reserva["codigo"] + " — " + reserva["espaco"], weight="medium"),
            rx.text(reserva["unidade"] + " · " + reserva["tipo"], size="1"),
        ),
        rx.table.cell(reserva["data"]),
        rx.table.cell(reserva["horario"]),
        rx.table.cell(
            rx.vstack(
                rx.badge(
                    reserva["situacao"],
                    color_scheme=rx.match(
                        reserva["status"], *CORES_SITUACAO.items(), "gray"
                    ),
                ),
                rx.cond(
                    reserva["detalhe"] != "", rx.text(reserva["detalhe"], size="1")
                ),
                spacing="1",
            )
        ),
        rx.table.cell(rx.text(reserva["criado_em"], size="1")),
        rx.table.cell(acoes(reserva)),
    )


def tabela() -> rx.Component:
    return rx.cond(
        ReservasUnidadeState.reservas.length() > 0,
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in (
                            "Quem reservou",
                            "Espaço",
                            "Data",
                            "Horário",
                            "Situação",
                            "Criada em",
                            "",
                        )
                    ]
                )
            ),
            rx.table.body(rx.foreach(ReservasUnidadeState.reservas, linha)),
            width="100%",
        ),
        rx.text(
            rx.cond(
                ReservasUnidadeState.situacao_listada == "PENDENTE",
                "Nenhuma reserva pendente.",
                "Nenhuma reserva atende aos filtros.",
            ),
            size="2",
            color_scheme="gray",
        ),
    )


def dialogo_recusa() -> rx.Component:
    reserva = ReservasUnidadeState.recusa
    return dialogo(
        ReservasUnidadeState.recusa_aberta,
        ReservasUnidadeState.mudar_recusa,
        "Recusar a reserva de " + reserva["dono"],
        ReservasUnidadeState.confirmar_recusa,
        rx.text(
            reserva["codigo"]
            + " — "
            + reserva["espaco"]
            + ", "
            + reserva["data"]
            + ", "
            + reserva["horario"],
            size="2",
        ),
        rx.text("O motivo será mostrado à pessoa que fez a reserva.", size="2"),
        rx.text_area(
            name="motivo",
            placeholder="Motivo da recusa (obrigatório)",
            max_length=500,
            required=True,
            width="100%",
        ),
        mensagem(ReservasUnidadeState.erro_dialogo, "red"),
        botao="Recusar",
        limpar_ao_enviar=False,
    )


def reservas_unidade() -> rx.Component:
    return layout_autenticado(
        rx.heading("Reservas da unidade", size="5"),
        rx.text(
            "As pendentes podem ser decididas até o início; depois disso, expiram.",
            size="2",
            color_scheme="gray",
        ),
        filtros(),
        mensagem(ReservasUnidadeState.mensagem_erro, "red"),
        mensagem(ReservasUnidadeState.mensagem_sucesso, "green"),
        mensagem(ReservasUnidadeState.aviso_limitada, "orange"),
        rx.cond(ReservasUnidadeState.carregou, tabela(), rx.spinner()),
        dialogo_recusa(),
        permitido=AuthState.e_gestor,
    )
