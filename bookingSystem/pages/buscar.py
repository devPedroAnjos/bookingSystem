"""Página de busca de espaços (todos os papéis)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem, seletor
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.busca_state import TODOS, BuscaState


def campo(rotulo: str, controle: rx.Component) -> rx.Component:
    return rx.vstack(
        rx.text(rotulo, size="2", weight="medium"), controle, spacing="1"
    )


def caixa_recurso(recurso: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.checkbox(recurso["nome"], name="rec_" + recurso["id"])


def formulario() -> rx.Component:
    return rx.form(
        rx.vstack(
            rx.hstack(
                campo(
                    "Unidade",
                    seletor(
                        "unidade_id",
                        BuscaState.opcoes_unidade,
                        "Todas as unidades",
                        valor_inicial=TODOS,
                    ),
                ),
                campo(
                    "Tipo de espaço",
                    seletor(
                        "tipo_espaco_id",
                        BuscaState.opcoes_tipo,
                        "Todos os tipos",
                        valor_inicial=TODOS,
                    ),
                ),
                campo(
                    "Capacidade mínima",
                    rx.input(
                        name="capacidade_minima", type="number", min=1, width="120px"
                    ),
                ),
                spacing="4",
                wrap="wrap",
            ),
            rx.cond(
                BuscaState.recursos.length() > 0,
                campo(
                    "Recursos (o espaço precisa ter todos os marcados)",
                    rx.hstack(
                        rx.foreach(BuscaState.recursos, caixa_recurso),
                        spacing="4",
                        wrap="wrap",
                    ),
                ),
            ),
            rx.hstack(
                campo("Data", rx.input(name="data", type="date")),
                campo("Início", rx.input(name="hora_inicio", type="time")),
                campo("Fim", rx.input(name="hora_fim", type="time")),
                spacing="4",
                wrap="wrap",
            ),
            rx.text(
                "Data e horário são opcionais; informados, cada espaço diz se o "
                "pedido está dentro das regras do tipo e se está livre, e os "
                "livres podem ser reservados. Um espaço ocupado por reservas de "
                "prioridade menor que a sua pode ser reservado deslocando-as, "
                "com confirmação.",
                size="1",
            ),
            rx.button("Buscar", type="submit"),
            spacing="4",
            width="100%",
        ),
        on_submit=BuscaState.buscar,
        width="100%",
    )


def regras_dos_tipos() -> rx.Component:
    return rx.vstack(
        rx.text("Tipos que você pode reservar", size="2", weight="medium"),
        rx.foreach(
            BuscaState.tipos,
            lambda tipo: rx.text(tipo["nome"] + ": " + tipo["regras"], size="1"),
        ),
        spacing="1",
    )


def linha_resultado(espaco: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.table.row(
        rx.table.cell(espaco["codigo"]),
        rx.table.cell(
            rx.text(espaco["nome"], weight="medium"),
            rx.text(espaco["localizacao"], size="1"),
        ),
        rx.table.cell(espaco["unidade"]),
        rx.table.cell(
            rx.vstack(
                rx.text(espaco["tipo"]),
                rx.cond(
                    espaco["exige_aprovacao"] == "sim",
                    rx.badge("Exige aprovação", color_scheme="orange"),
                ),
                spacing="1",
            )
        ),
        rx.table.cell(espaco["capacidade"]),
        rx.table.cell(espaco["recursos"]),
        rx.table.cell(
            rx.cond(
                espaco["horario"] != "",
                rx.vstack(
                    rx.text(
                        espaco["horario"],
                        size="2",
                        color_scheme=rx.cond(
                            espaco["dentro"] == "sim", "green", "red"
                        ),
                    ),
                    rx.badge(
                        espaco["ocupacao"],
                        color_scheme=rx.cond(
                            espaco["ocupacao"] == "Livre", "green", "gray"
                        ),
                    ),
                    spacing="1",
                ),
                rx.text("-", size="2"),
            )
        ),
        rx.table.cell(
            rx.cond(
                espaco["pode_reservar"] == "sim",
                rx.button(
                    "Reservar",
                    size="1",
                    on_click=BuscaState.abrir_reservar(espaco),
                ),
                rx.cond(
                    espaco["pode_deslocar"] == "sim",
                    rx.button(
                        "Deslocar e reservar",
                        size="1",
                        color_scheme="orange",
                        on_click=BuscaState.abrir_reservar(espaco),
                    ),
                ),
            )
        ),
    )


def resultados() -> rx.Component:
    return rx.cond(
        BuscaState.resultados.length() > 0,
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in (
                            "Código",
                            "Espaço",
                            "Unidade",
                            "Tipo",
                            "Capacidade",
                            "Recursos",
                            "Horário pedido",
                            "",
                        )
                    ]
                )
            ),
            rx.table.body(rx.foreach(BuscaState.resultados, linha_resultado)),
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


def buscar() -> rx.Component:
    return layout_autenticado(
        rx.heading("Buscar espaços", size="5"),
        rx.callout(
            "A disponibilidade é conferida de novo no momento da reserva.",
            color_scheme="blue",
            width="100%",
        ),
        mensagem(BuscaState.mensagem_erro, "red"),
        mensagem(BuscaState.mensagem_sucesso, "green"),
        formulario(),
        regras_dos_tipos(),
        resultados(),
        dialogo_reservar(),
    )
