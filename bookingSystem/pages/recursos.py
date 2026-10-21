"""Página do catálogo de recursos (só administrador)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.recursos_state import RecursosState

# Mesmo limite validado no Xano (design D2)
MAX_NOME = 60


def linha_recurso(recurso: rx.Var[dict[str, str]]) -> rx.Component:
    em_uso = recurso["espacos"] != "0"
    return rx.table.row(
        rx.table.cell(recurso["nome"]),
        rx.table.cell(recurso["espacos"]),
        rx.table.cell(
            rx.hstack(
                rx.button(
                    "Renomear",
                    size="1",
                    variant="soft",
                    on_click=RecursosState.abrir_editar(recurso),
                ),
                # Só recursos sem uso podem ser excluídos (spec recursos)
                rx.cond(
                    em_uso,
                    rx.fragment(),
                    rx.button(
                        "Excluir",
                        size="1",
                        color_scheme="red",
                        variant="soft",
                        on_click=RecursosState.excluir(recurso["id"]),
                    ),
                ),
                spacing="2",
            )
        ),
    )


def tabela_recursos() -> rx.Component:
    return rx.table.root(
        rx.table.header(
            rx.table.row(
                *[
                    rx.table.column_header_cell(titulo)
                    for titulo in ("Recurso", "Espaços que usam", "")
                ]
            )
        ),
        rx.table.body(rx.foreach(RecursosState.recursos, linha_recurso)),
        width="100%",
    )


def campo_nome(valor: rx.Var[str] | str = "") -> rx.Component:
    return rx.input(
        name="nome",
        default_value=valor,
        placeholder="Nome do recurso",
        max_length=MAX_NOME,
        width="100%",
    )


def recursos() -> rx.Component:
    return layout_autenticado(
        rx.heading("Recursos", size="5"),
        mensagem(RecursosState.mensagem_erro, "red"),
        mensagem(RecursosState.mensagem_sucesso, "green"),
        rx.button("Novo recurso", on_click=RecursosState.mudar_criar(True)),
        tabela_recursos(),
        dialogo(
            RecursosState.criar_aberta,
            RecursosState.mudar_criar,
            "Novo recurso",
            RecursosState.confirmar_criar,
            mensagem(RecursosState.erro_dialogo, "red"),
            campo_nome(),
            botao="Criar",
            limpar_ao_enviar=False,
        ),
        dialogo(
            RecursosState.editar_aberta,
            RecursosState.mudar_editar,
            "Renomear recurso",
            RecursosState.confirmar_editar,
            mensagem(RecursosState.erro_dialogo, "red"),
            campo_nome(RecursosState.editar_nome),
            rx.text(
                "O novo nome vale para todos os espaços que têm o recurso.",
                size="1",
            ),
            botao="Salvar",
            limpar_ao_enviar=False,
        ),
        permitido=AuthState.e_admin,
    )
