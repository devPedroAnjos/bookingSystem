"""Página de administradores (só o admin principal).

Promover coordenador, criar admin, rebaixar a coordenador, inativar, reativar
e redefinir senha. Admins secundários não veem a página (spec administradores).
"""

import reflex as rx

from bookingSystem.pages.componentes import campo_senha, dialogo, mensagem, seletor
from bookingSystem.pages.dialogos_conta import dialogos_situacao
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.admins_state import AdminsState
from bookingSystem.state.auth_state import AuthState


def acoes(admin: rx.Var[dict[str, str]]) -> rx.Component:
    ativa = admin["ativa"] == "sim"
    return rx.cond(
        admin["principal"] == "sim",
        rx.fragment(),
        rx.hstack(
            rx.cond(
                ativa,
                rx.button(
                    "Rebaixar a coordenador",
                    size="1",
                    on_click=AdminsState.abrir_rebaixamento(admin),
                ),
            ),
            rx.cond(
                ativa,
                rx.button(
                    "Redefinir senha",
                    size="1",
                    variant="soft",
                    on_click=AdminsState.abrir_redefinicao(admin),
                ),
            ),
            rx.cond(
                ativa,
                rx.button(
                    "Inativar",
                    size="1",
                    variant="soft",
                    color_scheme="red",
                    on_click=AdminsState.abrir_inativacao(admin),
                ),
                rx.button(
                    "Reativar",
                    size="1",
                    color_scheme="green",
                    on_click=AdminsState.abrir_reativacao(admin),
                ),
            ),
            spacing="2",
            wrap="wrap",
        ),
    )


def linha_admin(admin: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.table.row(
        rx.table.cell(
            rx.hstack(
                rx.text(admin["nome"]),
                rx.cond(admin["principal"] == "sim", rx.badge("Principal")),
                spacing="2",
            )
        ),
        rx.table.cell(admin["email"]),
        rx.table.cell(
            rx.hstack(
                rx.text(admin["situacao"]),
                rx.cond(
                    admin["senha_provisoria"] == "sim",
                    rx.badge("Senha provisória", color_scheme="orange"),
                ),
                spacing="2",
            )
        ),
        rx.table.cell(acoes(admin)),
    )


def dialogo_criacao() -> rx.Component:
    return dialogo(
        AdminsState.criacao_aberta,
        AdminsState.mudar_criacao,
        "Criar administrador",
        AdminsState.confirmar_criacao,
        rx.text(
            "A pessoa entra com a senha provisória e terá de trocá-la no "
            "primeiro acesso.",
            size="2",
            color_scheme="gray",
        ),
        mensagem(AdminsState.erro_dialogo, "red"),
        rx.input(name="nome", placeholder="Nome", width="100%"),
        rx.input(
            name="email",
            type="email",
            placeholder="E-mail institucional",
            width="100%",
        ),
        campo_senha("senha_provisoria", "Senha provisória (mínimo de 8 caracteres)"),
        campo_senha("confirmacao", "Confirme a senha provisória"),
        botao="Criar",
    )


def dialogo_promocao() -> rx.Component:
    return dialogo(
        AdminsState.promocao_aberta,
        AdminsState.mudar_promocao,
        "Promover coordenador a administrador",
        AdminsState.confirmar_promocao,
        rx.callout(
            "A pessoa deixa de coordenar todas as suas unidades, mesmo que "
            "alguma fique sem coordenador.",
            color_scheme="orange",
            width="100%",
        ),
        mensagem(AdminsState.erro_dialogo, "red"),
        seletor("coordenador_id", AdminsState.coordenadores, "Coordenador ativo"),
        botao="Promover",
    )


def dialogo_rebaixamento() -> rx.Component:
    return dialogo(
        AdminsState.rebaixamento_aberto,
        AdminsState.mudar_rebaixamento,
        "Rebaixar " + AdminsState.alvo_nome + " a coordenador",
        AdminsState.confirmar_rebaixamento,
        rx.text(
            "Um administrador só pode ser rebaixado a coordenador. Para virar "
            "professor depois, use \"Mudar papel\" em Usuários.",
            size="2",
            color_scheme="gray",
        ),
        mensagem(AdminsState.erro_dialogo, "red"),
        seletor("unidade1", AdminsState.unidades_ativas, "Unidade a coordenar"),
        seletor("unidade2", AdminsState.unidades_ativas, "Segunda unidade (opcional)"),
        botao="Rebaixar",
    )


def administradores() -> rx.Component:
    return layout_autenticado(
        rx.heading("Administradores", size="5"),
        mensagem(AdminsState.mensagem_erro, "red"),
        mensagem(AdminsState.mensagem_sucesso, "green"),
        rx.hstack(
            rx.text(
                "Administradores ativos: ",
                rx.text.strong(AdminsState.admins_ativos),
                " de ",
                AdminsState.max_admins,
                size="2",
            ),
            rx.spacer(),
            rx.button("Promover coordenador", on_click=AdminsState.abrir_promocao),
            rx.button(
                "Criar administrador",
                variant="soft",
                on_click=AdminsState.abrir_criacao,
            ),
            width="100%",
            align="center",
            spacing="2",
            wrap="wrap",
        ),
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in ("Nome", "E-mail", "Situação", "")
                    ]
                )
            ),
            rx.table.body(rx.foreach(AdminsState.admins, linha_admin)),
            width="100%",
        ),
        dialogo_criacao(),
        dialogo_promocao(),
        dialogo_rebaixamento(),
        dialogos_situacao(AdminsState),
        permitido=AuthState.e_principal,
    )
