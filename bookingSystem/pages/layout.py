"""Layout das páginas autenticadas: barra no topo, menu por papel e menu do usuário.

espaco-feed-avaliacoes (D12): logotipo, "Início" e "Minhas reservas"; os itens
de gestão ficam no menu "Gestão", com os mesmos testes de papel de antes; nome,
papel, "Trocar senha" e "Sair" ficam no menu do usuário.

O menu só esconde o que o papel não usa (usabilidade); o Xano decide o acesso.
Desde a C9, mostra no topo o aviso de vaga retida pela fila de espera, carregado
pelo `FilaState.carregar` do on_load de cada página.
"""

import reflex as rx

from bookingSystem.pages.marca import logotipo
from bookingSystem.state.auth_state import ROTA_TROCAR_SENHA, AuthState
from bookingSystem.state.fila_state import FilaState


def item_menu(texto: str, rota: str, icone: str) -> rx.Component:
    return rx.link(
        rx.hstack(rx.icon(icone, size=17), rx.text(texto), spacing="2", align="center"),
        href=rota,
        size="2",
        weight="medium",
        underline="none",
        color="var(--bs-ink-muted)",
        padding="8px 12px",
        border_radius="var(--bs-radius-sm)",
        _hover={"background": "var(--bs-surface-sunken)", "color": "var(--bs-ink)"},
    )


def item_gestao(texto: str, rota: str) -> rx.Component:
    return rx.menu.item(rx.link(texto, href=rota, underline="none", color="inherit", width="100%"))


def menu_gestao() -> rx.Component:
    """Itens de gestão agrupados (espaco-feed-avaliacoes, D12); só aparece para gestores."""
    return rx.cond(
        AuthState.e_gestor,
        rx.menu.root(
            rx.menu.trigger(
                rx.button(rx.icon("settings", size=17), "Gestão", rx.icon("chevron-down", size=15),
                          variant="ghost", color="var(--bs-ink-muted)"),
            ),
            rx.menu.content(
                item_gestao("Aprovações", "/aprovacoes"),
                item_gestao("Reservas da unidade", "/reservas-unidade"),
                item_gestao("Espaços", "/espacos"),
                item_gestao("Bloqueios", "/bloqueios"),
                rx.cond(
                    AuthState.e_admin,
                    rx.fragment(
                        rx.menu.separator(),
                        item_gestao("Usuários", "/usuarios"),
                        item_gestao("Unidades", "/unidades"),
                        item_gestao("Tipos de espaço", "/tipos-espaco"),
                        item_gestao("Recursos", "/recursos"),
                        item_gestao("Penalidades", "/penalidades"),
                    ),
                ),
                rx.cond(
                    AuthState.e_principal,
                    rx.fragment(
                        rx.menu.separator(),
                        item_gestao("Administradores", "/administradores"),
                        item_gestao("Parâmetros", "/parametros"),
                    ),
                ),
            ),
        ),
    )


def menu() -> rx.Component:
    """Com senha provisória, a barra não tem itens: só o menu do usuário (spec senha)."""
    return rx.cond(
        AuthState.senha_provisoria,
        rx.fragment(),
        rx.hstack(
            item_menu("Início", "/inicio", "house"),
            item_menu("Minhas reservas", "/minhas-reservas", "calendar-days"),
            menu_gestao(),
            spacing="1",
            align="center",
            wrap="wrap",
        ),
    )


def menu_usuario() -> rx.Component:
    """Chip com nome e papel; abre "Trocar senha" e "Sair" (spec interface-web)."""
    return rx.menu.root(
        rx.menu.trigger(
            rx.button(
                rx.avatar(fallback=AuthState.primeiro_nome[:1], size="1", radius="full",
                          color_scheme="green"),
                rx.text(AuthState.nome, size="2", weight="medium"),
                rx.badge(AuthState.nome_papel, variant="soft", color_scheme="gray"),
                rx.icon("chevron-down", size=15),
                variant="outline",
                radius="full",
                color="var(--bs-ink)",
            ),
        ),
        rx.menu.content(
            rx.menu.item(rx.link("Trocar senha", href=ROTA_TROCAR_SENHA, underline="none", color="inherit")),
            rx.menu.separator(),
            rx.menu.item("Sair", on_click=AuthState.sair, color="red"),
        ),
    )


def barra() -> rx.Component:
    return rx.box(
        rx.hstack(
            rx.link(logotipo(170), href="/inicio", underline="none"),
            menu(),
            rx.spacer(),
            menu_usuario(),
            align="center",
            spacing="5",
            max_width="1240px",
            margin="0 auto",
            height="64px",
            padding_x="24px",
            width="100%",
        ),
        position="sticky",
        top="0",
        z_index="30",
        background="var(--bs-surface)",
        border_bottom="1px solid var(--bs-line)",
        width="100%",
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
    return rx.cond(
        liberado,
        rx.box(
            barra(),
            rx.vstack(
                aviso_fila(),
                *conteudo,
                spacing="4",
                padding="28px 24px 64px",
                max_width="1240px",
                margin="0 auto",
                width="100%",
            ),
            min_height="100vh",
            background="var(--bs-bg)",
        ),
        rx.center(rx.spinner(), min_height="50vh"),
    )
