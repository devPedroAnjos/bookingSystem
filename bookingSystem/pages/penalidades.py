"""Página "Penalidades" (só administrador; C10, spec penalidades)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem, seletor
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.penalidades_state import (
    TAMANHO_MAXIMO_PARECER,
    PenalidadesState,
)


def filtros() -> rx.Component:
    return rx.form(
        rx.hstack(
            seletor(
                "situacao",
                PenalidadesState.filtros_situacao,
                "Situação",
                valor_inicial=PenalidadesState.situacao,
            ),
            rx.input(
                name="busca",
                placeholder="Nome ou e-mail",
                default_value=PenalidadesState.busca,
            ),
            rx.button("Filtrar", type="submit"),
            spacing="2",
            wrap="wrap",
        ),
        on_submit=PenalidadesState.filtrar,
        reset_on_submit=False,
    )


def linha(penalidade: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.table.row(
        rx.table.cell(penalidade["usuario"]),
        rx.table.cell(penalidade["periodo"]),
        rx.table.cell(
            rx.vstack(
                rx.badge(penalidade["situacao"]),
                rx.cond(
                    penalidade["anulacao"] != "",
                    rx.text(penalidade["anulacao"], size="1"),
                ),
                spacing="1",
            )
        ),
        rx.table.cell(rx.text(penalidade["faltas"], size="1")),
        rx.table.cell(
            rx.cond(
                penalidade["pode_anular"] == "sim",
                rx.button(
                    "Anular",
                    size="1",
                    color_scheme="red",
                    variant="soft",
                    on_click=PenalidadesState.abrir_anular(penalidade),
                ),
            )
        ),
    )


def tabela() -> rx.Component:
    return rx.cond(
        PenalidadesState.penalidades.length() > 0,
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in ("Usuário", "Período", "Situação", "Faltas", "")
                    ]
                )
            ),
            rx.table.body(rx.foreach(PenalidadesState.penalidades, linha)),
            width="100%",
        ),
        rx.text("Nenhuma penalidade com esses filtros.", size="2", color_scheme="gray"),
    )


def dialogo_anular() -> rx.Component:
    penalidade = PenalidadesState.anular
    return dialogo(
        PenalidadesState.anular_aberta,
        PenalidadesState.mudar_anular,
        "Anular a penalidade",
        PenalidadesState.confirmar_anular,
        rx.text(penalidade["usuario"] + " — " + penalidade["periodo"], size="2"),
        rx.text(
            "As penalidades encadeadas depois desta são antecipadas. "
            "O parecer fica visível para o usuário, sem o seu nome.",
            size="2",
        ),
        rx.text_area(
            name="parecer",
            placeholder="Parecer (obrigatório)",
            max_length=TAMANHO_MAXIMO_PARECER,
            width="100%",
        ),
        mensagem(PenalidadesState.erro_dialogo, "red"),
        botao="Anular",
        limpar_ao_enviar=False,
    )


def penalidades() -> rx.Component:
    return layout_autenticado(
        rx.heading("Penalidades", size="5"),
        filtros(),
        mensagem(PenalidadesState.mensagem_erro, "red"),
        mensagem(PenalidadesState.mensagem_sucesso, "green"),
        rx.cond(
            PenalidadesState.limitada,
            mensagem(
                "Só as 200 primeiras foram mostradas. Refine a busca.", "orange"
            ),
        ),
        rx.cond(PenalidadesState.carregou, tabela(), rx.spinner()),
        dialogo_anular(),
    )
