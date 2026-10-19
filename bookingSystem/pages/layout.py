"""Layout das páginas autenticadas: cabeçalho, menu por papel e Sair.

O menu só esconde o que o papel não usa (usabilidade); o Xano decide o acesso.
"""

import reflex as rx

from bookingSystem.state.auth_state import AuthState


def item_menu(texto: str, rota: str) -> rx.Component:
    return rx.link(texto, href=rota, size="3", weight="medium")


def menu() -> rx.Component:
    return rx.hstack(
        item_menu("Início", "/inicio"),
        rx.cond(AuthState.e_gestor, item_menu("Aprovações", "/aprovacoes")),
        rx.cond(AuthState.e_admin, item_menu("Usuários", "/usuarios")),
        rx.cond(AuthState.e_admin, item_menu("Unidades", "/unidades")),
        spacing="5",
        align="center",
    )


def layout_autenticado(
    *conteudo: rx.Component, permitido: rx.Var[bool] | bool = True
) -> rx.Component:
    """Envolve o conteúdo com o cabeçalho.

    Mostra um carregando sem sessão ou quando o papel não é `permitido`, para
    que a página restrita não apareça antes do redirecionamento do on_load.
    """
    return rx.container(
        rx.cond(
            (AuthState.nome != "") & permitido,
            rx.vstack(
                rx.hstack(
                    rx.heading("BookingSystem", size="6"),
                    menu(),
                    rx.spacer(),
                    rx.text(AuthState.nome, size="2"),
                    rx.badge(AuthState.nome_papel, size="2"),
                    rx.button("Sair", on_click=AuthState.sair, variant="soft"),
                    width="100%",
                    align="center",
                    spacing="4",
                    wrap="wrap",
                ),
                rx.divider(),
                *conteudo,
                spacing="4",
                padding_y="24px",
                width="100%",
            ),
            rx.center(rx.spinner(), min_height="50vh"),
        ),
        size="4",
    )
