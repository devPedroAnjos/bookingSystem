import reflex as rx

config = rx.Config(
    app_name="bookingSystem",
    env_file=".env",
    plugins=[
        rx.plugins.SitemapPlugin(),
        rx.plugins.TailwindV4Plugin(),
        # Tema claro do design system (change espaco-feed-avaliacoes, D10); tokens em assets/tema.css
        rx.plugins.RadixThemesPlugin(
            theme=rx.theme(
                appearance="light", accent_color="grass", gray_color="sage", radius="medium"
            )
        ),
    ]
)