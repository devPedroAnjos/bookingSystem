"""Página de tipos de espaço (só administrador)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.tipos_espaco_state import TiposEspacoState

# Mesmos limites validados no Xano (design D2)
MAX_NOME = 60
MAX_DESCRICAO = 300


def linha_tipo(tipo: rx.Var[dict[str, str]]) -> rx.Component:
    ativo = tipo["ativo"] == "sim"
    return rx.table.row(
        rx.table.cell(tipo["nome"]),
        rx.table.cell(tipo["descricao"]),
        rx.table.cell(
            rx.hstack(
                rx.cond(
                    ativo,
                    rx.badge("Ativo", color_scheme="green"),
                    rx.badge("Desativado", color_scheme="orange"),
                ),
                rx.cond(
                    tipo["com_regras"] == "nao",
                    rx.badge("Sem regras", color_scheme="red"),
                ),
                spacing="2",
                wrap="wrap",
            )
        ),
        rx.table.cell(
            tipo["espacos_ativos"] + " em " + tipo["unidades"] + " unidade(s)"
        ),
        rx.table.cell(
            rx.hstack(
                rx.button(
                    "Editar",
                    size="1",
                    variant="soft",
                    on_click=TiposEspacoState.abrir_editar(tipo),
                ),
                rx.button(
                    "Regras",
                    size="1",
                    variant="soft",
                    on_click=TiposEspacoState.abrir_regras(tipo),
                ),
                rx.cond(
                    ativo,
                    rx.button(
                        "Desativar",
                        size="1",
                        color_scheme="red",
                        variant="soft",
                        on_click=TiposEspacoState.abrir_desativar(tipo),
                    ),
                    rx.button(
                        "Reativar",
                        size="1",
                        on_click=TiposEspacoState.reativar(tipo["id"]),
                    ),
                ),
                spacing="2",
            )
        ),
    )


def tabela_tipos() -> rx.Component:
    return rx.table.root(
        rx.table.header(
            rx.table.row(
                *[
                    rx.table.column_header_cell(titulo)
                    for titulo in (
                        "Tipo", "Descrição", "Situação", "Espaços ativos", ""
                    )
                ]
            )
        ),
        rx.table.body(rx.foreach(TiposEspacoState.tipos, linha_tipo)),
        width="100%",
    )


def campos_tipo(nome: rx.Var[str] | str = "", descricao: rx.Var[str] | str = ""):
    return (
        rx.input(
            name="nome",
            default_value=nome,
            placeholder="Nome",
            max_length=MAX_NOME,
            width="100%",
        ),
        rx.text_area(
            name="descricao",
            default_value=descricao,
            placeholder="Descrição (opcional)",
            max_length=MAX_DESCRICAO,
            width="100%",
        ),
    )


def dialogo_criar() -> rx.Component:
    return dialogo(
        TiposEspacoState.criar_aberta,
        TiposEspacoState.mudar_criar,
        "Novo tipo de espaço",
        TiposEspacoState.confirmar_criar,
        mensagem(TiposEspacoState.erro_dialogo, "red"),
        *campos_tipo(),
        rx.text(
            "O tipo nasce sem regras e não é reservável até você definir as "
            "regras dele (botão Regras).",
            size="1",
        ),
        botao="Criar",
        limpar_ao_enviar=False,
    )


def dialogo_editar() -> rx.Component:
    return dialogo(
        TiposEspacoState.editar_aberta,
        TiposEspacoState.mudar_editar,
        "Editar tipo de espaço",
        TiposEspacoState.confirmar_editar,
        mensagem(TiposEspacoState.erro_dialogo, "red"),
        *campos_tipo(
            TiposEspacoState.editar_nome, TiposEspacoState.editar_descricao
        ),
        botao="Salvar",
        limpar_ao_enviar=False,
    )


def dialogo_desativar() -> rx.Component:
    return dialogo(
        TiposEspacoState.desativar_aberta,
        TiposEspacoState.mudar_desativar,
        "Desativar " + TiposEspacoState.desativar_nome,
        TiposEspacoState.confirmar_desativar,
        rx.callout(
            TiposEspacoState.desativar_espacos
            + " espaço(s) ativo(s) de "
            + TiposEspacoState.desativar_unidades
            + " unidade(s) deixarão de ser reserváveis enquanto o tipo "
            "estiver desativado. Os espaços não são alterados.",
            color_scheme="orange",
            width="100%",
        ),
        botao="Desativar",
    )


ROTULOS_REGRAS_NUMERICAS = {
    "duracao_min_minutos": "Duração mínima (minutos)",
    "duracao_max_minutos": "Duração máxima (minutos)",
    "antecedencia_min_minutos": "Antecedência mínima (minutos)",
    "antecedencia_max_dias": "Antecedência máxima (dias)",
    "max_reservas_ativas_usuario": "Reservas ativas por usuário",
}
ROTULOS_REGRAS_HORARIO = {
    "hora_abertura_minutos": "Abertura (HH:MM)",
    "hora_fechamento_minutos": "Fechamento (HH:MM)",
}


def campo_regra(rotulo: str, controle: rx.Component) -> rx.Component:
    return rx.hstack(
        rx.text(rotulo, size="2", min_width="220px"),
        controle,
        align="center",
        width="100%",
    )


def caixa_regra(campo: str, rotulo: str) -> rx.Component:
    return rx.checkbox(
        rotulo,
        name=campo,
        default_checked=TiposEspacoState.regras_marcadas[campo],
    )


def regra_do_papel(papel: str, nome: str) -> rx.Component:
    return rx.hstack(
        rx.text(nome, size="2", weight="medium", min_width="90px"),
        caixa_regra(papel + "_pode_reservar", "Pode reservar"),
        caixa_regra(papel + "_exige_aprovacao", "Exige aprovação"),
        spacing="4",
        align="center",
    )


def dialogo_regras() -> rx.Component:
    return dialogo(
        TiposEspacoState.regras_aberta,
        TiposEspacoState.mudar_regras,
        "Regras de " + TiposEspacoState.regras_nome,
        TiposEspacoState.confirmar_regras,
        mensagem(TiposEspacoState.erro_dialogo, "red"),
        *[
            campo_regra(
                rotulo,
                rx.input(
                    name=nome,
                    type="number",
                    min=0,
                    default_value=TiposEspacoState.regras_valores[nome],
                    width="110px",
                ),
            )
            for nome, rotulo in ROTULOS_REGRAS_NUMERICAS.items()
        ],
        *[
            campo_regra(
                rotulo,
                rx.input(
                    name=nome,
                    placeholder="HH:MM",
                    max_length=5,
                    default_value=TiposEspacoState.regras_valores[nome],
                    width="110px",
                ),
            )
            for nome, rotulo in ROTULOS_REGRAS_HORARIO.items()
        ],
        caixa_regra("permite_recorrencia", "Permite reserva recorrente"),
        rx.divider(),
        rx.text(
            "Coordenadores e administradores reservam todos os tipos, sem "
            "aprovação.",
            size="1",
        ),
        regra_do_papel("aluno", "Aluno"),
        regra_do_papel("professor", "Professor"),
        botao="Salvar",
        limpar_ao_enviar=False,
    )


def tipos_espaco() -> rx.Component:
    return layout_autenticado(
        rx.heading("Tipos de espaço", size="5"),
        mensagem(TiposEspacoState.mensagem_erro, "red"),
        mensagem(TiposEspacoState.mensagem_sucesso, "green"),
        rx.button("Novo tipo", on_click=TiposEspacoState.mudar_criar(True)),
        tabela_tipos(),
        dialogo_criar(),
        dialogo_editar(),
        dialogo_desativar(),
        dialogo_regras(),
        permitido=AuthState.e_admin,
    )
