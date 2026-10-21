"""Página de espaços (admin em todas as unidades, coordenador nas próprias)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem, seletor
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.espacos_state import EspacosState

# Mesmos limites validados no Xano (design D2)
MAX_NOME = 100
MAX_CODIGO = 20
MAX_LOCALIZACAO = 150
MAX_DESCRICAO = 500


def situacao(espaco: rx.Var[dict[str, str]]) -> rx.Component:
    """Situação do espaço e, quando não é reservável, o motivo em destaque."""
    return rx.vstack(
        rx.cond(
            espaco["ativo"] == "sim",
            rx.badge("Ativo", color_scheme="green"),
            rx.badge("Desativado", color_scheme="gray"),
        ),
        rx.cond(
            espaco["reservavel"] == "sim",
            rx.badge("Reservável", color_scheme="green", variant="outline"),
            rx.badge(
                "Não reservável: " + espaco["motivos"], color_scheme="orange"
            ),
        ),
        spacing="1",
    )


def linha_espaco(espaco: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.table.row(
        rx.table.cell(
            rx.text(espaco["nome"], weight="medium"),
            rx.text(espaco["localizacao"], size="1"),
        ),
        rx.table.cell(espaco["codigo"]),
        rx.table.cell(espaco["unidade_nome"]),
        rx.table.cell(espaco["tipo_nome"]),
        rx.table.cell(espaco["capacidade"]),
        rx.table.cell(rx.text(espaco["recursos"], size="2")),
        rx.table.cell(situacao(espaco)),
        rx.table.cell(
            rx.hstack(
                rx.button(
                    "Editar",
                    size="1",
                    variant="soft",
                    on_click=EspacosState.abrir_editar(espaco),
                ),
                rx.button(
                    "Recursos",
                    size="1",
                    variant="soft",
                    on_click=EspacosState.abrir_recursos(espaco["id"]),
                ),
                rx.cond(
                    espaco["ativo"] == "sim",
                    rx.button(
                        "Desativar",
                        size="1",
                        color_scheme="red",
                        variant="soft",
                        on_click=EspacosState.desativar(espaco["id"]),
                    ),
                    rx.button(
                        "Reativar",
                        size="1",
                        on_click=EspacosState.reativar(espaco["id"]),
                    ),
                ),
                # Só o admin muda a unidade de um espaço (spec espacos)
                rx.cond(
                    AuthState.e_admin,
                    rx.button(
                        "Mover",
                        size="1",
                        variant="soft",
                        on_click=EspacosState.abrir_mover(espaco),
                    ),
                ),
                spacing="2",
                wrap="wrap",
            )
        ),
    )


def tabela_espacos() -> rx.Component:
    return rx.table.root(
        rx.table.header(
            rx.table.row(
                *[
                    rx.table.column_header_cell(titulo)
                    for titulo in (
                        "Espaço",
                        "Código",
                        "Unidade",
                        "Tipo",
                        "Capacidade",
                        "Recursos",
                        "Situação",
                        "",
                    )
                ]
            )
        ),
        rx.table.body(rx.foreach(EspacosState.espacos_filtrados, linha_espaco)),
        width="100%",
    )


def filtro_unidade() -> rx.Component:
    return rx.select.root(
        rx.select.trigger(placeholder="Todas as unidades"),
        rx.select.content(
            rx.select.item("Todas as unidades", value="todas"),
            rx.foreach(
                EspacosState.unidades_filtro,
                lambda unidade: rx.select.item(unidade["nome"], value=unidade["id"]),
            ),
        ),
        on_change=EspacosState.filtrar_unidade,
    )


def campos_espaco(espaco: rx.Var[dict[str, str]] | None = None):
    """Campos de texto e número comuns a criar e editar."""

    def valor(campo: str):
        return "" if espaco is None else espaco[campo]

    return (
        rx.input(
            name="nome",
            default_value=valor("nome"),
            placeholder="Nome",
            max_length=MAX_NOME,
            width="100%",
        ),
        rx.input(
            name="codigo",
            default_value=valor("codigo"),
            placeholder="Código (único na unidade)",
            max_length=MAX_CODIGO,
            width="100%",
        ),
        rx.input(
            name="capacidade",
            default_value=valor("capacidade"),
            placeholder="Capacidade",
            type="number",
            min=1,
            width="100%",
        ),
        rx.input(
            name="localizacao",
            default_value=valor("localizacao"),
            placeholder="Localização (opcional, ex.: Bloco B, 2º andar)",
            max_length=MAX_LOCALIZACAO,
            width="100%",
        ),
        rx.text_area(
            name="descricao",
            default_value=valor("descricao"),
            placeholder="Descrição (opcional)",
            max_length=MAX_DESCRICAO,
            width="100%",
        ),
    )


def dialogo_criar() -> rx.Component:
    return dialogo(
        EspacosState.criar_aberta,
        EspacosState.mudar_criar,
        "Novo espaço",
        EspacosState.confirmar_criar,
        mensagem(EspacosState.erro_dialogo, "red"),
        seletor("unidade_id", EspacosState.unidades_ativas, "Unidade"),
        seletor("tipo_espaco_id", EspacosState.tipos_ativos, "Tipo de espaço"),
        *campos_espaco(),
        rx.text("O espaço nasce ativo e sem recursos.", size="1"),
        botao="Criar",
        limpar_ao_enviar=False,
    )


def dialogo_editar() -> rx.Component:
    return dialogo(
        EspacosState.editar_aberta,
        EspacosState.mudar_editar,
        "Editar " + EspacosState.editar["nome"],
        EspacosState.confirmar_editar,
        mensagem(EspacosState.erro_dialogo, "red"),
        seletor(
            "tipo_espaco_id",
            EspacosState.tipos_edicao,
            "Tipo de espaço",
            valor_inicial=EspacosState.editar["tipo_id"],
        ),
        *campos_espaco(EspacosState.editar),
        botao="Salvar",
        limpar_ao_enviar=False,
    )


def quantidade_recurso(recurso: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.hstack(
        rx.text(recurso["nome"], size="2", min_width="180px"),
        rx.input(
            name="rec_" + recurso["id"],
            default_value=recurso["quantidade"],
            type="number",
            min=0,
            width="90px",
        ),
        align="center",
        width="100%",
    )


def dialogo_recursos() -> rx.Component:
    return dialogo(
        EspacosState.recursos_aberta,
        EspacosState.mudar_recursos,
        "Recursos de " + EspacosState.recursos_espaco_nome,
        EspacosState.confirmar_recursos,
        rx.text("Informe a quantidade de cada recurso (0 para não ter).", size="2"),
        mensagem(EspacosState.erro_dialogo, "red"),
        rx.foreach(EspacosState.recursos_edicao, quantidade_recurso),
        botao="Salvar",
        limpar_ao_enviar=False,
    )


def dialogo_mover() -> rx.Component:
    return dialogo(
        EspacosState.mover_aberta,
        EspacosState.mudar_mover,
        "Mover " + EspacosState.mover_espaco_nome,
        EspacosState.confirmar_mover,
        mensagem(EspacosState.erro_dialogo, "red"),
        seletor("unidade_id", EspacosState.destinos_mover, "Unidade de destino"),
        rx.text("O espaço mantém tipo, situação e recursos.", size="1"),
        botao="Mover",
        limpar_ao_enviar=False,
    )


def espacos() -> rx.Component:
    return layout_autenticado(
        rx.heading("Espaços", size="5"),
        mensagem(EspacosState.mensagem_erro, "red"),
        mensagem(EspacosState.mensagem_sucesso, "green"),
        rx.hstack(
            rx.button("Novo espaço", on_click=EspacosState.mudar_criar(True)),
            filtro_unidade(),
            spacing="3",
            align="center",
        ),
        tabela_espacos(),
        dialogo_criar(),
        dialogo_editar(),
        dialogo_recursos(),
        dialogo_mover(),
        permitido=AuthState.e_gestor,
    )
