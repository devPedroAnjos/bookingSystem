"""Página de unidades e coordenação (só administrador)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem, seletor
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.unidades_state import UnidadesState


def linha_unidade(unidade: rx.Var[dict[str, str]]) -> rx.Component:
    ativa = unidade["ativa"] == "sim"
    return rx.table.row(
        rx.table.cell(unidade["nome"]),
        rx.table.cell(unidade["endereco"]),
        rx.table.cell(
            rx.cond(
                ativa,
                rx.badge("Ativa", color_scheme="green"),
                rx.badge("Desativada", color_scheme="gray"),
            )
        ),
        rx.table.cell(
            rx.cond(
                unidade["sem_coordenador"] == "sim",
                rx.badge("Sem coordenador", color_scheme="orange"),
                rx.text(unidade["coordenadores"], size="2"),
            )
        ),
        rx.table.cell(unidade["professores"]),
        rx.table.cell(unidade["pendentes"]),
        rx.table.cell(
            rx.hstack(
                rx.button(
                    "Editar",
                    size="1",
                    variant="soft",
                    on_click=UnidadesState.abrir_editar(unidade),
                ),
                rx.cond(
                    ativa,
                    rx.button(
                        "Desativar",
                        size="1",
                        color_scheme="red",
                        variant="soft",
                        on_click=UnidadesState.abrir_desativar(unidade["id"]),
                    ),
                    rx.button(
                        "Reativar",
                        size="1",
                        on_click=UnidadesState.reativar(unidade["id"]),
                    ),
                ),
                spacing="2",
            )
        ),
    )


def tabela_unidades() -> rx.Component:
    return rx.table.root(
        rx.table.header(
            rx.table.row(
                *[
                    rx.table.column_header_cell(titulo)
                    for titulo in (
                        "Unidade",
                        "Endereço",
                        "Situação",
                        "Coordenadores",
                        "Professores",
                        "Pedidos pendentes",
                        "",
                    )
                ]
            )
        ),
        rx.table.body(rx.foreach(UnidadesState.unidades, linha_unidade)),
        width="100%",
    )


def dialogo_criar() -> rx.Component:
    mover = UnidadesState.criar_modo == "MOVER"
    return dialogo(
        UnidadesState.criar_aberta,
        UnidadesState.mudar_criar,
        "Nova unidade",
        UnidadesState.confirmar_criar,
        rx.input(name="nome", placeholder="Nome", width="100%"),
        rx.input(name="endereco", placeholder="Endereço", width="100%"),
        rx.text("Toda unidade nasce com um coordenador.", size="2"),
        seletor(
            "coordenador_id",
            UnidadesState.coordenadores,
            "Coordenador",
        ),
        rx.radio_group(
            ["ACRESCENTAR", "MOVER"],
            value=UnidadesState.criar_modo,
            on_change=UnidadesState.escolher_modo,
            direction="row",
        ),
        rx.text(
            rx.cond(
                mover,
                "MOVER: o coordenador sai da unidade de origem.",
                "ACRESCENTAR: o coordenador fica também nas unidades atuais.",
            ),
            size="1",
        ),
        rx.cond(
            mover,
            seletor("origem_id", UnidadesState.unidades_ativas, "Unidade de origem"),
        ),
        botao="Criar",
    )


def dialogo_editar() -> rx.Component:
    return dialogo(
        UnidadesState.editar_aberta,
        UnidadesState.mudar_editar,
        "Editar unidade",
        UnidadesState.confirmar_editar,
        rx.input(
            name="nome",
            default_value=UnidadesState.editar_nome,
            placeholder="Nome",
            width="100%",
        ),
        rx.input(
            name="endereco",
            default_value=UnidadesState.editar_endereco,
            placeholder="Endereço",
            width="100%",
        ),
        botao="Salvar",
    )


def destino(pessoa: rx.Var[dict[str, str]], prefixo: str) -> rx.Component:
    return rx.hstack(
        rx.text(pessoa["nome"], size="2", min_width="140px"),
        seletor(prefixo + pessoa["id"], UnidadesState.unidades_ativas, "Destino"),
        width="100%",
        align="center",
    )


def dialogo_desativar() -> rx.Component:
    return dialogo(
        UnidadesState.desativar_aberta,
        UnidadesState.mudar_desativar,
        "Desativar " + UnidadesState.desativar_nome,
        UnidadesState.confirmar_desativar,
        rx.cond(
            UnidadesState.precisam_destino.length() > 0,
            rx.vstack(
                rx.text("Coordenadores que só coordenam esta unidade:", size="2", weight="medium"),
                rx.foreach(
                    UnidadesState.precisam_destino,
                    lambda pessoa: destino(pessoa, "coord_"),
                ),
                width="100%",
            ),
        ),
        rx.cond(
            UnidadesState.professores_destino.length() > 0,
            rx.vstack(
                rx.text("Professores da unidade:", size="2", weight="medium"),
                rx.foreach(
                    UnidadesState.professores_destino,
                    lambda pessoa: destino(pessoa, "prof_"),
                ),
                width="100%",
            ),
        ),
        rx.callout(
            UnidadesState.desativar_pendentes
            + " pedido(s) pendente(s) desta unidade serão recusados "
            "automaticamente, sem consumir pedido.",
            color_scheme="orange",
            width="100%",
        ),
        botao="Desativar",
    )


TITULOS_COORDENACAO = {
    "ACRESCENTAR": "Acrescentar unidade a um coordenador",
    "MOVER": "Mover coordenador",
    "REMOVER": "Remover uma unidade de um coordenador",
}


def dialogo_coordenacao() -> rx.Component:
    acao = UnidadesState.coordenacao_acao
    return dialogo(
        UnidadesState.coordenacao_aberta,
        UnidadesState.mudar_coordenacao,
        rx.match(
            acao,
            *[(chave, titulo) for chave, titulo in TITULOS_COORDENACAO.items()],
            "Coordenação",
        ),
        UnidadesState.confirmar_coordenacao,
        seletor("coordenador_id", UnidadesState.coordenadores, "Coordenador"),
        seletor(
            "unidade_id",
            UnidadesState.unidades_ativas,
            rx.match(
                acao,
                ("MOVER", "Unidade de origem"),
                ("REMOVER", "Unidade a remover"),
                "Unidade a acrescentar",
            ),
        ),
        rx.cond(
            acao == "MOVER",
            seletor("destino_id", UnidadesState.unidades_ativas, "Unidade de destino"),
        ),
    )


def unidades() -> rx.Component:
    return layout_autenticado(
        rx.heading("Unidades", size="5"),
        mensagem(UnidadesState.mensagem_erro, "red"),
        mensagem(UnidadesState.mensagem_sucesso, "green"),
        rx.hstack(
            rx.button("Nova unidade", on_click=UnidadesState.mudar_criar(True)),
            rx.button(
                "Acrescentar coordenador",
                variant="soft",
                on_click=UnidadesState.abrir_coordenacao("ACRESCENTAR"),
            ),
            rx.button(
                "Mover coordenador",
                variant="soft",
                on_click=UnidadesState.abrir_coordenacao("MOVER"),
            ),
            rx.button(
                "Remover coordenação",
                variant="soft",
                on_click=UnidadesState.abrir_coordenacao("REMOVER"),
            ),
            spacing="2",
            wrap="wrap",
        ),
        tabela_unidades(),
        rx.heading("Coordenadores ativos", size="3"),
        rx.foreach(
            UnidadesState.coordenadores,
            lambda c: rx.text(c["nome"], ": ", c["unidades"], size="2"),
        ),
        dialogo_criar(),
        dialogo_editar(),
        dialogo_desativar(),
        dialogo_coordenacao(),
        permitido=AuthState.e_admin,
    )
