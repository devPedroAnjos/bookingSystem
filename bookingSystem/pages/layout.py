"""Layout das páginas autenticadas: cabeçalho, menu por papel e Sair.

O menu só esconde o que o papel não usa (usabilidade); o Xano decide o acesso.
Desde a C9, mostra no topo o aviso de vaga retida pela fila de espera, carregado
pelo `FilaState.carregar` do on_load de cada página.
"""

import reflex as rx

from bookingSystem.state.auth_state import ROTA_TROCAR_SENHA, AuthState
from bookingSystem.state.fila_state import FilaState


def item_menu(texto: str, rota: str) -> rx.Component:
    return rx.link(texto, href=rota, size="3", weight="medium")


def menu() -> rx.Component:
    """Com senha provisória, só a troca de senha (spec senha)."""
    return rx.cond(
        AuthState.senha_provisoria,
        rx.hstack(item_menu("Trocar senha", ROTA_TROCAR_SENHA), align="center"),
        rx.hstack(
            item_menu("Início", "/inicio"),
            item_menu("Buscar espaços", "/buscar"),
            item_menu("Minhas reservas", "/minhas-reservas"),
            rx.cond(AuthState.e_gestor, item_menu("Aprovações", "/aprovacoes")),
            rx.cond(
                AuthState.e_gestor,
                item_menu("Reservas da unidade", "/reservas-unidade"),
            ),
            rx.cond(AuthState.e_gestor, item_menu("Espaços", "/espacos")),
            rx.cond(AuthState.e_admin, item_menu("Usuários", "/usuarios")),
            rx.cond(AuthState.e_admin, item_menu("Unidades", "/unidades")),
            rx.cond(
                AuthState.e_admin, item_menu("Tipos de espaço", "/tipos-espaco")
            ),
            rx.cond(AuthState.e_admin, item_menu("Recursos", "/recursos")),
            rx.cond(AuthState.e_admin, item_menu("Penalidades", "/penalidades")),
            rx.cond(
                AuthState.e_principal,
                item_menu("Administradores", "/administradores"),
            ),
            rx.cond(AuthState.e_principal, item_menu("Parâmetros", "/parametros")),
            item_menu("Trocar senha", ROTA_TROCAR_SENHA),
            spacing="5",
            align="center",
            wrap="wrap",
        ),
    )


def linha_aviso_fila(entrada: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.text(
        "Vaga liberada na fila: ",
        rx.text.strong(entrada["codigo"] + " — " + entrada["espaco"]),
        ", " + entrada["data"] + ", " + entrada["horario"]
        + ". Confirme até " + entrada["prazo"] + ".",
        size="2",
    )


def aviso_fila() -> rx.Component:
    """Aviso de vaga retida em todas as páginas autenticadas (spec fila-espera)."""
    return rx.cond(
        FilaState.avisos.length() > 0,
        # Sem rx.callout.text: ele gera um <p>, e as linhas (rx.text) também são <p>
        rx.callout.root(
            rx.vstack(
                rx.foreach(FilaState.avisos, linha_aviso_fila),
                rx.link("Ir para Minhas reservas", href="/minhas-reservas", size="2"),
                spacing="1",
            ),
            color_scheme="amber",
            width="100%",
        ),
    )


def layout_autenticado(
    *conteudo: rx.Component,
    permitido: rx.Var[bool] | bool = True,
    aceita_senha_provisoria: bool = False,
) -> rx.Component:
    """Envolve o conteúdo com o cabeçalho.

    Mostra um carregando sem sessão, quando o papel não é `permitido` ou,
    fora da troca de senha, enquanto a senha for provisória. Assim a página
    restrita não aparece antes do redirecionamento do on_load.
    """
    liberado = (AuthState.nome != "") & permitido
    if not aceita_senha_provisoria:
        liberado = liberado & ~AuthState.senha_provisoria
    return rx.container(
        rx.cond(
            liberado,
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
                aviso_fila(),
                *conteudo,
                spacing="4",
                padding_y="24px",
                width="100%",
            ),
            rx.center(rx.spinner(), min_height="50vh"),
        ),
        size="4",
    )
