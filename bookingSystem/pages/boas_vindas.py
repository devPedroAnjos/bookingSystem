"""Tela de boas-vindas sem sessão (spec interface-web; change espaco-feed-avaliacoes, D18)."""

import reflex as rx

from bookingSystem.pages.marca import logotipo


def faixas() -> rx.Component:
    """Detalhe gráfico do Figma: cinco faixas, a do meio em lima."""
    cores = ("rgba(255,255,255,0.14)", "rgba(66,165,116,0.45)", "var(--bs-accent)",
             "rgba(66,165,116,0.45)", "rgba(255,255,255,0.14)")
    return rx.hstack(
        *[rx.box(width="34px", height="8px", border_radius="999px", background=cor) for cor in cores],
        spacing="2",
    )


def boas_vindas() -> rx.Component:
    return rx.center(
        rx.vstack(
            logotipo(460, negativo=True),
            rx.text("Reserve salas, laboratórios, bibliotecas e auditórios em poucos cliques.",
                    size="5", weight="medium", text_align="center", color="var(--bs-on-brand-deep-soft)"),
            rx.text("A plataforma da instituição para encontrar, reservar e avaliar os espaços "
                    "de todas as unidades.", size="3", text_align="center", color="var(--bs-on-brand-deep-muted)",
                    max_width="440px"),
            faixas(),
            rx.vstack(
                rx.link(rx.button("Entrar", size="3", width="100%", background="var(--bs-accent)",
                                  color="var(--bs-on-accent)"), href="/login", width="100%"),
                rx.link(rx.button("Criar conta", size="3", width="100%", variant="outline",
                                  color="var(--bs-on-brand-deep)", style={"border-color": "var(--bs-on-brand-deep-line)"}),
                        href="/cadastro", width="100%"),
                spacing="3",
                width="100%",
                max_width="340px",
            ),
            spacing="5",
            align="center",
            width="100%",
            max_width="600px",
        ),
        min_height="100vh",
        padding="40px 24px",
        background="var(--bs-brand-deep)",
    )
