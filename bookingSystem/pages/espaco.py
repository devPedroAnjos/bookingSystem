"""Página do espaço (spec pagina-espaco; change espaco-feed-avaliacoes, D15)."""

import reflex as rx

from bookingSystem.pages.feed import icone_tipo
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import ROTA_INICIO
from bookingSystem.state.espaco_state import EspacoState


def item_avaliacao(avaliacao: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.vstack(
        rx.hstack(
            rx.text(avaliacao["autor"], weight="bold", size="2"),
            rx.spacer(),
            rx.text(avaliacao["estrelas"], color="var(--bs-star)", size="3"),
            width="100%",
            align="center",
        ),
        rx.cond(avaliacao["comentario"] != "",
                rx.text(avaliacao["comentario"], size="2", color="var(--bs-ink-muted)")),
        rx.text(avaliacao["data"], size="1", color="var(--bs-ink-muted)"),
        spacing="1",
        width="100%",
        padding_y="12px",
        border_bottom="1px solid var(--bs-line)",
    )


def topo() -> rx.Component:
    espaco = EspacoState.espaco
    return rx.cond(
        espaco["foto"] != "",
        rx.image(src=espaco["foto"], width="100%", height="240px", object_fit="cover",
                 border_radius="var(--bs-radius-lg)", alt=espaco["nome"]),
        rx.flex(
            icone_tipo(espaco["icone"], 48),
            background=espaco["cor"],
            height="160px",
            width="100%",
            align="center",
            justify="center",
            border_radius="var(--bs-radius-lg)",
        ),
    )


def dados() -> rx.Component:
    espaco = EspacoState.espaco
    return rx.vstack(
        rx.badge(espaco["tipo"], variant="soft", radius="full"),
        rx.heading(espaco["nome"], size="7"),
        rx.text(espaco["codigo"] + " · " + espaco["unidade"], color="var(--bs-ink-muted)"),
        rx.hstack(rx.icon("map-pin", size=16), rx.text(espaco["localizacao"]),
                  spacing="1", align="center"),
        rx.hstack(rx.icon("users", size=16), rx.text("Até " + espaco["capacidade"] + " pessoas"),
                  spacing="1", align="center"),
        rx.cond(espaco["descricao"] != "", rx.text(espaco["descricao"], size="2")),
        rx.cond(
            EspacoState.recursos.length() > 0,
            rx.hstack(rx.foreach(EspacoState.recursos, lambda r: rx.badge(r, variant="outline")),
                      wrap="wrap", spacing="2"),
        ),
        rx.cond(espaco["exige_aprovacao"] == "sim",
                rx.badge("Exige aprovação para o seu papel", color_scheme="orange")),
        spacing="2",
        width="100%",
    )


def destaque_media() -> rx.Component:
    espaco = EspacoState.espaco
    return rx.hstack(
        rx.vstack(
            rx.text("MÉDIA DO LOCAL", size="1", weight="bold", letter_spacing="0.06em",
                    color="var(--bs-green-200)"),
            rx.text(espaco["total"] + " avaliação(ões)", size="2", color="var(--bs-green-100)"),
            spacing="1",
        ),
        rx.spacer(),
        rx.text(espaco["media_numero"], size="8", weight="bold", color="var(--bs-accent)"),
        background="var(--bs-brand-deep)",
        color="var(--bs-on-brand-deep)",
        padding="20px",
        border_radius="var(--bs-radius-md)",
        width="100%",
        align="center",
    )


def avaliacoes() -> rx.Component:
    return rx.vstack(
        destaque_media(),
        rx.heading("Avaliações", size="4"),
        rx.cond(
            EspacoState.avaliacoes.length() > 0,
            rx.vstack(rx.foreach(EspacoState.avaliacoes, item_avaliacao), spacing="0", width="100%"),
            rx.text("Este espaço ainda não tem avaliações.", color="var(--bs-ink-muted)"),
        ),
        spacing="3",
        width="100%",
    )


def conteudo() -> rx.Component:
    return rx.cond(
        EspacoState.nao_encontrado,
        rx.vstack(
            rx.callout("Espaço não encontrado.", color_scheme="gray", width="100%"),
            rx.link("Voltar para a Início", href=ROTA_INICIO),
            spacing="3",
        ),
        rx.cond(
            EspacoState.carregou,
            rx.vstack(
                rx.link(rx.hstack(rx.icon("arrow-left", size=16), rx.text("Voltar para os espaços"),
                                  spacing="1", align="center"), href=ROTA_INICIO),
                topo(),
                rx.grid(
                    rx.box(dados(), background="var(--bs-surface)", padding="20px",
                           border="1px solid var(--bs-line)", border_radius="var(--bs-radius-lg)"),
                    rx.box(avaliacoes(), background="var(--bs-surface)", padding="20px",
                           border="1px solid var(--bs-line)", border_radius="var(--bs-radius-lg)"),
                    columns=rx.breakpoints(initial="1", md="2"),
                    spacing="5",
                    width="100%",
                ),
                spacing="4",
                width="100%",
            ),
            rx.center(rx.spinner(), min_height="30vh"),
        ),
    )


def espaco() -> rx.Component:
    return layout_autenticado(conteudo())
