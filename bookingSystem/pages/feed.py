"""Feed de espaços da Início (spec busca-espacos, "Tela de busca"; D13 e D14).

Extraído da antiga página "Buscar espaços": o formulário, os diálogos de
reservar e de entrar na fila e as regras são os mesmos; a lista virou cartões.
O cartão restrito aparece acinzentado, com cadeado e o aviso do Xano, sem link
nem ações. Só usa os tokens do tema (var(--bs-*)).
"""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem, seletor
from bookingSystem.state.busca_state import TODOS, BuscaState


def campo(rotulo: str, controle: rx.Component) -> rx.Component:
    return rx.vstack(
        rx.text(rotulo, size="2", weight="medium"), controle, spacing="1"
    )


def caixa_recurso(recurso: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.checkbox(recurso["nome"], name="rec_" + recurso["id"])


def filtros_avancados() -> rx.Component:
    return rx.vstack(
        rx.hstack(
            campo(
                "Unidade",
                seletor("unidade_id", BuscaState.opcoes_unidade, "Todas as unidades",
                        valor_inicial=TODOS),
            ),
            campo(
                "Tipo de espaço",
                seletor("tipo_espaco_id", BuscaState.opcoes_tipo, "Todos os tipos",
                        valor_inicial=TODOS),
            ),
            campo(
                "Capacidade mínima",
                rx.input(name="capacidade_minima", type="number", min=1, width="120px"),
            ),
            campo("Data", rx.input(name="data", type="date")),
            campo("Início", rx.input(name="hora_inicio", type="time")),
            campo("Fim", rx.input(name="hora_fim", type="time")),
            spacing="4",
            wrap="wrap",
        ),
        rx.cond(
            BuscaState.recursos.length() > 0,
            campo(
                "Recursos (o espaço precisa ter todos os marcados)",
                rx.hstack(rx.foreach(BuscaState.recursos, caixa_recurso),
                          spacing="4", wrap="wrap"),
            ),
        ),
        rx.text(
            "Data e horário são opcionais; informados, cada espaço diz se o pedido "
            "está dentro das regras do tipo e se está livre, e os livres podem ser "
            "reservados. Um espaço ocupado por reservas de prioridade menor que a "
            "sua pode ser reservado deslocando-as, com confirmação. Nos demais "
            "espaços ocupados, você pode entrar na fila de espera do horário.",
            size="1",
            color="var(--bs-ink-muted)",
        ),
        spacing="3",
        width="100%",
    )


def formulario() -> rx.Component:
    return rx.form(
        rx.vstack(
            rx.hstack(
                rx.heading("Encontre um espaço", size="4"),
                width="100%",
            ),
            rx.hstack(
                rx.input(
                    rx.input.slot(rx.icon("search", size=16)),
                    name="texto",
                    placeholder="Buscar por nome, código, local, unidade ou tipo...",
                    max_length=100,
                    width="100%",
                    size="3",
                ),
                rx.button("Buscar", type="submit", size="3"),
                width="100%",
                spacing="2",
            ),
            filtros_avancados(),
            spacing="3",
            width="100%",
        ),
        on_submit=BuscaState.buscar,
        width="100%",
        background="var(--bs-surface)",
        border="1px solid var(--bs-line)",
        border_radius="var(--bs-radius-lg)",
        padding="20px",
        box_shadow="var(--bs-shadow-1)",
    )


def regras_dos_tipos() -> rx.Component:
    return rx.vstack(
        rx.text("Tipos que você pode reservar", size="2", weight="medium"),
        rx.foreach(
            BuscaState.tipos,
            lambda tipo: rx.text(tipo["nome"] + ": " + tipo["regras"], size="1",
                                 color="var(--bs-ink-muted)"),
        ),
        spacing="1",
    )


def icone_tipo(nome: rx.Var[str], tamanho: int = 28) -> rx.Component:
    """Ícone Lucide escolhido pelo estado (rx.icon precisa de nome fixo)."""
    cor = "var(--bs-primary)"
    return rx.match(
        nome,
        ("book-open", rx.icon("book-open", size=tamanho, color=cor)),
        ("flask-conical", rx.icon("flask-conical", size=tamanho, color=cor)),
        ("theater", rx.icon("theater", size=tamanho, color=cor)),
        ("presentation", rx.icon("presentation", size=tamanho, color=cor)),
        rx.icon("door-open", size=tamanho, color=cor),
    )


def topo_cartao(espaco: rx.Var[dict[str, str]]) -> rx.Component:
    """Foto de capa ou, sem foto, faixa com a cor e o ícone do tipo."""
    return rx.cond(
        espaco["foto"] != "",
        rx.image(src=espaco["foto"], loading="lazy", width="100%", height="140px",
                 object_fit="cover", alt=espaco["nome"]),
        rx.flex(
            rx.badge(espaco["tipo"], variant="surface", radius="full"),
            rx.spacer(),
            icone_tipo(espaco["icone"]),
            background=espaco["cor"],
            height="110px",
            padding="14px 16px",
            align="end",
            width="100%",
        ),
    )


def acoes_horario(espaco: rx.Var[dict[str, str]]) -> rx.Component:
    """Indicações e ações do horário pedido (iguais às da antiga busca)."""
    return rx.cond(
        espaco["horario"] != "",
        rx.vstack(
            rx.text(espaco["horario"], size="1",
                    color=rx.cond(espaco["dentro"] == "sim", "var(--bs-primary)", "var(--bs-danger)")),
            rx.hstack(
                rx.badge(
                    espaco["ocupacao"],
                    color_scheme=rx.match(espaco["ocupacao"], ("Livre", "green"),
                                          ("Bloqueado", "red"), "gray"),
                ),
                rx.spacer(),
                rx.cond(
                    espaco["pode_reservar"] == "sim",
                    rx.button("Reservar", size="1", on_click=BuscaState.abrir_reservar(espaco)),
                    rx.cond(
                        espaco["pode_deslocar"] == "sim",
                        rx.button("Deslocar e reservar", size="1", color_scheme="orange",
                                  on_click=BuscaState.abrir_reservar(espaco)),
                        acao_fila(espaco),
                    ),
                ),
                width="100%",
                align="center",
            ),
            spacing="2",
            width="100%",
            padding_top="10px",
            border_top="1px solid var(--bs-line)",
        ),
    )


def acao_fila(espaco: rx.Var[dict[str, str]]) -> rx.Component:
    """Espaço ocupado e não deslocável: entrar na fila ou a indicação (C9)."""
    return rx.cond(
        espaco["na_fila"] == "sim",
        rx.badge("Você está na fila", color_scheme="blue"),
        rx.cond(
            espaco["pode_entrar_fila"] == "sim",
            rx.button("Entrar na fila", size="1", variant="soft",
                      on_click=BuscaState.abrir_fila(espaco)),
        ),
    )


def dados_cartao(espaco: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.vstack(
        rx.hstack(
            rx.text(espaco["nome"], weight="bold", size="3"),
            rx.spacer(),
            rx.cond(
                espaco["restrito"] == "sim",
                rx.icon("lock", size=16, color="var(--bs-ink-muted)"),
                rx.cond(
                    espaco["media"] != "",
                    rx.hstack(rx.icon("star", size=14, color="var(--bs-star)", fill="var(--bs-star)"),
                              rx.text(espaco["media"], size="1", weight="medium"),
                              spacing="1", align="center"),
                    rx.text("Sem avaliações", size="1", color="var(--bs-ink-muted)"),
                ),
            ),
            width="100%",
            align="start",
        ),
        rx.text(espaco["codigo"] + " · " + espaco["unidade"], size="1", color="var(--bs-ink-muted)"),
        rx.hstack(rx.icon("map-pin", size=14), rx.text(espaco["localizacao"], size="1"),
                  spacing="1", align="center", color="var(--bs-ink-muted)"),
        rx.hstack(rx.icon("users", size=14), rx.text("Até " + espaco["capacidade"] + " pessoas", size="1"),
                  spacing="1", align="center", color="var(--bs-ink-muted)"),
        rx.cond(
            espaco["recursos"] != "",
            rx.text(espaco["recursos"], size="1", color="var(--bs-ink-muted)"),
        ),
        rx.cond(
            espaco["restrito"] == "sim",
            rx.vstack(
                rx.badge(rx.icon("lock", size=12), "Restrito", color_scheme="gray"),
                rx.text(espaco["restricao"], size="1", color="var(--bs-ink-muted)"),
                spacing="1",
            ),
        ),
        spacing="1",
        padding="14px 16px 16px",
        width="100%",
    )


def cartao_espaco(espaco: rx.Var[dict[str, str]]) -> rx.Component:
    """Restrito: acinzentado, sem link nem ações. Demais: abre a página do espaço."""
    return rx.cond(
        espaco["restrito"] == "sim",
        rx.box(topo_cartao(espaco), dados_cartao(espaco),
               class_name="bs-cartao-espaco bs-cartao-restrito"),
        rx.box(
            rx.link(rx.box(topo_cartao(espaco), dados_cartao(espaco)),
                    href=espaco["link"], underline="none", color="inherit"),
            rx.box(acoes_horario(espaco), padding="0 16px 14px"),
            class_name="bs-cartao-espaco",
        ),
    )


def resultados() -> rx.Component:
    return rx.cond(
        BuscaState.resultados.length() > 0,
        rx.grid(
            rx.foreach(BuscaState.resultados, cartao_espaco),
            columns=rx.breakpoints(initial="1", sm="2", lg="3"),
            spacing="5",
            width="100%",
        ),
        rx.cond(
            BuscaState.buscou,
            rx.callout("Nenhum espaço atende aos filtros.", width="100%"),
        ),
    )


def dialogo_reservar() -> rx.Component:
    espaco = BuscaState.reservar
    return dialogo(
        BuscaState.reservar_aberta,
        BuscaState.mudar_reservar,
        "Reservar " + espaco["codigo"],
        BuscaState.confirmar_reservar,
        rx.text(espaco["nome"] + " — " + espaco["unidade"], size="2"),
        rx.text(BuscaState.pedido_texto, size="2", weight="medium"),
        # Quantas reservas de prioridade menor serão canceladas (C8), sem nomes
        mensagem(BuscaState.aviso_deslocamento, "orange"),
        rx.cond(
            espaco["exige_aprovacao"] == "sim",
            rx.callout(
                "Este tipo de espaço exige aprovação para o seu papel: a reserva "
                "fica aguardando aprovação.",
                color_scheme="orange",
                width="100%",
            ),
        ),
        mensagem(BuscaState.erro_dialogo, "red"),
        botao=BuscaState.botao_reservar,
        limpar_ao_enviar=False,
    )


def dialogo_fila() -> rx.Component:
    espaco = BuscaState.fila
    return dialogo(
        BuscaState.fila_aberta,
        BuscaState.mudar_fila,
        "Entrar na fila de " + espaco["codigo"],
        BuscaState.confirmar_fila,
        rx.text(espaco["nome"] + " — " + espaco["unidade"], size="2"),
        rx.text(BuscaState.pedido_texto, size="2", weight="medium"),
        rx.callout(
            "Quando a vaga for liberada, ela aparece no topo das páginas e em "
            "\"Minhas reservas\", e você precisa confirmar dentro do prazo da "
            "fila. Quem tem prioridade maior passa à frente.",
            color_scheme="blue",
            width="100%",
        ),
        mensagem(BuscaState.erro_fila, "red"),
        botao="Entrar na fila",
        limpar_ao_enviar=False,
    )


def feed() -> rx.Component:
    return rx.vstack(
        formulario(),
        rx.callout(
            "A disponibilidade é conferida de novo no momento da reserva.",
            color_scheme="blue",
            width="100%",
            size="1",
        ),
        mensagem(BuscaState.mensagem_erro, "red"),
        mensagem(BuscaState.mensagem_sucesso, "green"),
        regras_dos_tipos(),
        rx.heading("Espaços", size="5"),
        resultados(),
        dialogo_reservar(),
        dialogo_fila(),
        spacing="4",
        width="100%",
    )
