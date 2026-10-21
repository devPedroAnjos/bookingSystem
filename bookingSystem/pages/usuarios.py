"""Página de usuários (só administrador).

Filtros, papel, transferência, inativação, reativação e redefinição de senha.
"""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem, seletor
from bookingSystem.pages.dialogos_conta import dialogos_situacao
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.contas_state import ContasState


def filtros() -> rx.Component:
    return rx.form(
        rx.hstack(
            rx.select.root(
                rx.select.trigger(placeholder="Papel"),
                rx.select.content(
                    rx.select.item("Aluno", value="ALUNO"),
                    rx.select.item("Professor", value="PROFESSOR"),
                    rx.select.item("Coordenador", value="COORDENADOR"),
                    rx.select.item("Administrador", value="ADMIN"),
                ),
                name="papel",
            ),
            rx.select.root(
                rx.select.trigger(placeholder="Situação"),
                rx.select.content(
                    rx.select.item("Pendente", value="PENDENTE"),
                    rx.select.item("Ativa", value="ATIVA"),
                    rx.select.item("Recusada", value="RECUSADA"),
                    rx.select.item("Inativa", value="INATIVA"),
                ),
                name="situacao",
            ),
            rx.input(name="busca", placeholder="Nome ou e-mail"),
            rx.button("Filtrar", type="submit"),
            rx.button(
                "Limpar",
                type="reset",
                variant="soft",
                on_click=ContasState.filtrar({}),
            ),
            spacing="2",
            wrap="wrap",
        ),
        on_submit=ContasState.filtrar,
        width="100%",
    )


def acoes(usuario: rx.Var[dict[str, str]]) -> rx.Component:
    ativa = usuario["ativa"] == "sim"
    # Ninguém age sobre o principal; sobre outros admins, só o principal (D5)
    pode_agir = (usuario["principal"] != "sim") & (
        (usuario["papel"] != "ADMIN") | AuthState.e_principal
    )
    return rx.hstack(
        rx.cond(
            ativa & (usuario["papel"] != "ADMIN"),
            rx.button(
                "Mudar papel",
                size="1",
                on_click=ContasState.abrir_papel(usuario),
            ),
        ),
        rx.cond(
            ativa & (usuario["papel"] == "PROFESSOR"),
            rx.button(
                "Transferir",
                size="1",
                variant="soft",
                on_click=ContasState.abrir_transferencia(
                    usuario["id"], usuario["nome"]
                ),
            ),
        ),
        rx.cond(
            ativa & pode_agir,
            rx.button(
                "Redefinir senha",
                size="1",
                variant="soft",
                on_click=ContasState.abrir_redefinicao(usuario),
            ),
        ),
        rx.cond(
            ativa & pode_agir,
            rx.button(
                "Inativar",
                size="1",
                variant="soft",
                color_scheme="red",
                on_click=ContasState.abrir_inativacao(usuario),
            ),
        ),
        rx.cond(
            (usuario["inativa"] == "sim") & pode_agir,
            rx.button(
                "Reativar",
                size="1",
                color_scheme="green",
                on_click=ContasState.abrir_reativacao(usuario),
            ),
        ),
        spacing="2",
        wrap="wrap",
    )


def situacao(usuario: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.hstack(
        rx.text(usuario["situacao"]),
        rx.cond(usuario["principal"] == "sim", rx.badge("Principal")),
        rx.cond(
            usuario["senha_provisoria"] == "sim",
            rx.badge("Senha provisória", color_scheme="orange"),
        ),
        spacing="2",
        wrap="wrap",
    )


def linha_usuario(usuario: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.table.row(
        rx.table.cell(usuario["nome"]),
        rx.table.cell(usuario["email"]),
        rx.table.cell(usuario["papel_nome"]),
        rx.table.cell(situacao(usuario)),
        rx.table.cell(
            rx.cond(
                usuario["papel"] == "COORDENADOR",
                usuario["coordena"],
                usuario["unidade"],
            )
        ),
        rx.table.cell(acoes(usuario)),
    )


def dialogo_papel() -> rx.Component:
    coordenador = ContasState.papel_novo == "COORDENADOR"
    return dialogo(
        ContasState.papel_aberto,
        ContasState.mudar_papel_dialogo,
        "Mudar papel de " + ContasState.papel_alvo_nome,
        ContasState.confirmar_papel,
        rx.text(
            "Novo papel: ",
            rx.text.strong(
                rx.cond(coordenador, "Coordenador", "Professor")
            ),
            size="2",
        ),
        rx.cond(
            ContasState.perdas != "",
            rx.callout(
                "Esta pessoa deixará de coordenar: " + ContasState.perdas,
                color_scheme="orange",
                width="100%",
            ),
        ),
        seletor(
            "unidade1",
            ContasState.unidades_ativas,
            rx.cond(coordenador, "Unidade a coordenar", "Unidade do professor"),
        ),
        rx.cond(
            coordenador,
            seletor("unidade2", ContasState.unidades_ativas, "Segunda unidade (opcional)"),
        ),
    )


def dialogo_transferencia() -> rx.Component:
    return dialogo(
        ContasState.transferencia_aberta,
        ContasState.mudar_transferencia,
        "Transferir " + ContasState.transferencia_nome,
        ContasState.confirmar_transferencia,
        seletor("unidade_id", ContasState.unidades_ativas, "Unidade de destino"),
        botao="Transferir",
    )


def usuarios() -> rx.Component:
    return layout_autenticado(
        rx.heading("Usuários", size="5"),
        mensagem(ContasState.mensagem_erro, "red"),
        mensagem(ContasState.mensagem_sucesso, "green"),
        filtros(),
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in (
                            "Nome",
                            "E-mail",
                            "Papel",
                            "Situação",
                            "Unidade(s)",
                            "",
                        )
                    ]
                )
            ),
            rx.table.body(rx.foreach(ContasState.usuarios, linha_usuario)),
            width="100%",
        ),
        dialogo_papel(),
        dialogo_transferencia(),
        dialogos_situacao(ContasState),
        permitido=AuthState.e_admin,
    )
