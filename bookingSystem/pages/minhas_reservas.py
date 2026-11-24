"""Página "Minhas reservas" (todos os papéis)."""

import reflex as rx

from bookingSystem.pages.componentes import dialogo, mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.avaliacao_state import TAMANHO_MAXIMO_COMENTARIO, AvaliacaoState
from bookingSystem.state.faltas_state import FaltasState
from bookingSystem.state.fila_state import CONFIRMAR, DESISTIR, FilaState
from bookingSystem.state.reservas_state import ReservasState

CORES_FILA = {
    "AGUARDANDO": "blue",
    "NOTIFICADA": "amber",
    "ATENDIDA": "green",
}

CORES_SITUACAO = {
    "CONFIRMADA": "green",
    "PENDENTE": "orange",
    "CONCLUIDA": "teal",
    "NAO_COMPARECEU": "red",
    "CANCELADA": "gray",
    "RECUSADA": "red",
}


def situacao(reserva: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.vstack(
        rx.badge(
            reserva["situacao"],
            color_scheme=rx.match(
                reserva["status"],
                *CORES_SITUACAO.items(),
                "gray",
            ),
        ),
        rx.cond(reserva["motivo"] != "", rx.text(reserva["motivo"], size="1")),
        rx.cond(
            reserva["check_in"] != "",
            rx.text("Check-in às " + reserva["check_in"], size="1"),
        ),
        rx.cond(
            reserva["falta"] != "",
            rx.badge("Falta: " + reserva["falta"], color_scheme="red", variant="soft"),
        ),
        rx.cond(
            (reserva["status"] == "CONFIRMADA") & (reserva["check_in"] == ""),
            rx.text(reserva["janela"], size="1", color_scheme="gray"),
        ),
        spacing="1",
    )


def acoes(reserva: rx.Var[dict[str, str]]) -> rx.Component:
    """Fazer check-in (durante a janela) e Cancelar (antes do início, sem check-in)."""
    return rx.hstack(
        rx.cond(
            reserva["checkin_possivel"] == "sim",
            rx.button(
                "Fazer check-in",
                size="1",
                on_click=ReservasState.fazer_checkin(reserva["id"]),
            ),
        ),
        rx.cond(
            reserva["pode_cancelar"] == "sim",
            rx.button(
                "Cancelar",
                size="1",
                color_scheme="red",
                variant="soft",
                on_click=ReservasState.abrir_cancelar(reserva),
            ),
        ),
        spacing="2",
    )


def acao_avaliar(reserva: rx.Var[dict[str, str]]) -> rx.Component:
    """Nota já dada ou "Avaliar" com a data limite (espaco-feed-avaliacoes, D16)."""
    return rx.cond(
        reserva["nota"] != "",
        rx.hstack(rx.icon("star", size=14, color="var(--bs-star)", fill="var(--bs-star)"),
                  rx.text("Sua nota: " + reserva["nota"], size="1"), spacing="1", align="center"),
        rx.cond(
            reserva["pode_avaliar"] == "sim",
            rx.vstack(
                rx.button(rx.icon("star", size=14), "Avaliar", size="1", variant="soft",
                          on_click=AvaliacaoState.abrir(reserva)),
                rx.text("Até " + reserva["avaliar_ate"], size="1", color_scheme="gray"),
                spacing="1",
            ),
        ),
    )


def estrela(valor: int) -> rx.Component:
    return rx.icon_button(
        rx.icon("star", size=28,
                fill=rx.cond(AvaliacaoState.nota >= valor, "var(--bs-star)", "none"),
                color=rx.cond(AvaliacaoState.nota >= valor, "var(--bs-star)", "var(--bs-line-strong)")),
        type="button",
        variant="ghost",
        size="3",
        on_click=AvaliacaoState.escolher(valor),
        aria_label=f"{valor} estrela(s)",
    )


def dialogo_avaliar() -> rx.Component:
    reserva = AvaliacaoState.reserva
    return dialogo(
        AvaliacaoState.aberta,
        AvaliacaoState.mudar,
        "Avaliar " + reserva["codigo"],
        AvaliacaoState.enviar,
        rx.text(reserva["espaco"] + " — " + reserva["data"] + ", " + reserva["horario"], size="2"),
        rx.hstack(*[estrela(valor) for valor in range(1, 6)], spacing="1"),
        rx.text_area(name="comentario", placeholder="Comentário (opcional)",
                     max_length=TAMANHO_MAXIMO_COMENTARIO, width="100%"),
        rx.text("A avaliação aparece na página do espaço com o seu primeiro nome e papel, "
                "e não pode ser editada depois.", size="1", color_scheme="gray"),
        mensagem(AvaliacaoState.erro, "red"),
        botao="Enviar avaliação",
        limpar_ao_enviar=False,
        botao_desabilitado=AvaliacaoState.nota < 1,
    )


def linha(reserva: rx.Var[dict[str, str]], com_cancelar: bool) -> rx.Component:
    return rx.table.row(
        rx.table.cell(reserva["data"]),
        rx.table.cell(reserva["horario"]),
        rx.table.cell(
            rx.text(reserva["codigo"] + " — " + reserva["espaco"], weight="medium"),
            rx.text(reserva["tipo"], size="1"),
        ),
        rx.table.cell(reserva["unidade"]),
        rx.table.cell(situacao(reserva)),
        rx.table.cell(acoes(reserva) if com_cancelar else acao_avaliar(reserva)),
    )


def tabela(reservas, com_cancelar: bool, vazio: str) -> rx.Component:
    return rx.cond(
        reservas.length() > 0,
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in (
                            "Data",
                            "Horário",
                            "Espaço",
                            "Unidade",
                            "Situação",
                            "",
                        )
                    ]
                )
            ),
            rx.table.body(
                rx.foreach(reservas, lambda reserva: linha(reserva, com_cancelar))
            ),
            width="100%",
        ),
        rx.text(vazio, size="2", color_scheme="gray"),
    )


def dialogo_cancelar() -> rx.Component:
    reserva = ReservasState.cancelar
    return dialogo(
        ReservasState.cancelar_aberta,
        ReservasState.mudar_cancelar,
        "Cancelar a reserva de " + reserva["codigo"],
        ReservasState.confirmar_cancelar,
        rx.text(
            reserva["data"] + ", " + reserva["horario"] + " — " + reserva["espaco"],
            size="2",
        ),
        rx.text("O horário volta a ficar livre para outras pessoas.", size="2"),
        rx.cond(
            reserva["gera_falta"] == "sim",
            rx.callout(
                "Faltam menos de "
                + ReservasState.prazo_minutos.to_string()
                + " minutos para o início: este cancelamento gera uma falta.",
                color_scheme="red",
                width="100%",
            ),
        ),
        mensagem(ReservasState.erro_dialogo, "red"),
        botao=rx.cond(
            reserva["gera_falta"] == "sim",
            "Cancelar e aceitar a falta",
            "Cancelar a reserva",
        ),
        limpar_ao_enviar=False,
    )


# ---------- Faltas e penalidades (C10, spec penalidades) ----------


def tabela_faltas() -> rx.Component:
    return rx.table.root(
        rx.table.header(
            rx.table.row(
                *[
                    rx.table.column_header_cell(titulo)
                    for titulo in ("Quando", "Tipo", "Reserva", "Penalidade")
                ]
            )
        ),
        rx.table.body(
            rx.foreach(
                FaltasState.faltas,
                lambda falta: rx.table.row(
                    rx.table.cell(falta["ocorrida_em"]),
                    rx.table.cell(falta["tipo"]),
                    rx.table.cell(falta["reserva"]),
                    rx.table.cell(rx.cond(falta["penalidade"] == "sim", "Gerou", "—")),
                ),
            )
        ),
        width="100%",
    )


def tabela_penalidades() -> rx.Component:
    return rx.table.root(
        rx.table.header(
            rx.table.row(
                *[
                    rx.table.column_header_cell(titulo)
                    for titulo in ("Período", "Situação", "Parecer da anulação")
                ]
            )
        ),
        rx.table.body(
            rx.foreach(
                FaltasState.penalidades,
                lambda penalidade: rx.table.row(
                    rx.table.cell(penalidade["periodo"]),
                    rx.table.cell(rx.badge(penalidade["situacao"])),
                    rx.table.cell(penalidade["parecer"]),
                ),
            )
        ),
        width="100%",
    )


def secao_faltas() -> rx.Component:
    return rx.vstack(
        rx.heading("Faltas e penalidades", size="4"),
        mensagem(FaltasState.mensagem_erro, "red"),
        rx.cond(
            FaltasState.em_vigor,
            rx.callout(
                "Você está com penalidade até "
                + FaltasState.ate
                + ". Até lá, não é possível criar reservas nem entrar em filas.",
                color_scheme="red",
                width="100%",
            ),
        ),
        # Sem o carregamento terminado, "sem faltas" seria uma afirmação falsa
        rx.cond(
            ~FaltasState.carregou,
            rx.spinner(),
            rx.cond(
                (FaltasState.faltas.length() == 0)
                & (FaltasState.penalidades.length() == 0),
                rx.text(
                    "Você não tem faltas nem penalidades.",
                    size="2",
                    color_scheme="gray",
                ),
                rx.vstack(
                    rx.cond(FaltasState.faltas.length() > 0, tabela_faltas()),
                    rx.cond(
                        FaltasState.penalidades.length() > 0, tabela_penalidades()
                    ),
                    spacing="3",
                    width="100%",
                ),
            ),
        ),
        spacing="3",
        width="100%",
    )


# ---------- Fila de espera (C9, spec fila-espera) ----------


def detalhe_fila(entrada: rx.Var[dict[str, str]]) -> rx.Component:
    """Posição na mesma fila (aguardando) ou prazo para confirmar (vaga liberada)."""
    return rx.cond(
        entrada["status"] == "NOTIFICADA",
        rx.text("Confirme até " + entrada["prazo"], size="1", weight="medium"),
        rx.cond(
            entrada["posicao"] != "",
            rx.text("Posição nesta fila: " + entrada["posicao"], size="1"),
        ),
    )


def acoes_fila(entrada: rx.Var[dict[str, str]]) -> rx.Component:
    return rx.cond(
        entrada["status"] == "NOTIFICADA",
        rx.hstack(
            rx.button(
                "Confirmar",
                size="1",
                on_click=FilaState.abrir_acao(entrada, CONFIRMAR),
            ),
            rx.button(
                "Desistir",
                size="1",
                color_scheme="red",
                variant="soft",
                on_click=FilaState.abrir_acao(entrada, DESISTIR),
            ),
            spacing="2",
        ),
        rx.button(
            "Sair da fila",
            size="1",
            color_scheme="red",
            variant="soft",
            on_click=FilaState.abrir_acao(entrada, DESISTIR),
        ),
    )


def linha_fila(entrada: rx.Var[dict[str, str]], com_acoes: bool) -> rx.Component:
    return rx.table.row(
        rx.table.cell(entrada["data"]),
        rx.table.cell(entrada["horario"]),
        rx.table.cell(
            rx.text(entrada["codigo"] + " — " + entrada["espaco"], weight="medium"),
            rx.text(entrada["tipo"], size="1"),
        ),
        rx.table.cell(entrada["unidade"]),
        rx.table.cell(
            rx.vstack(
                rx.badge(
                    entrada["situacao"],
                    color_scheme=rx.match(
                        entrada["status"], *CORES_FILA.items(), "gray"
                    ),
                ),
                detalhe_fila(entrada),
                spacing="1",
            )
        ),
        rx.table.cell(acoes_fila(entrada) if com_acoes else rx.fragment()),
    )


def tabela_fila(entradas, com_acoes: bool, vazio: str) -> rx.Component:
    return rx.cond(
        entradas.length() > 0,
        rx.table.root(
            rx.table.header(
                rx.table.row(
                    *[
                        rx.table.column_header_cell(titulo)
                        for titulo in (
                            "Data",
                            "Horário",
                            "Espaço",
                            "Unidade",
                            "Situação",
                            "",
                        )
                    ]
                )
            ),
            rx.table.body(
                rx.foreach(entradas, lambda entrada: linha_fila(entrada, com_acoes))
            ),
            width="100%",
        ),
        rx.text(vazio, size="2", color_scheme="gray"),
    )


def secao_fila() -> rx.Component:
    return rx.vstack(
        rx.heading("Fila de espera", size="4"),
        mensagem(FilaState.mensagem_erro, "red"),
        mensagem(FilaState.mensagem_sucesso, "green"),
        tabela_fila(FilaState.ativas, True, "Você não está em nenhuma fila."),
        rx.cond(
            FilaState.finalizadas.length() > 0,
            rx.vstack(
                rx.text("Encerradas recentemente", size="2", weight="medium"),
                tabela_fila(FilaState.finalizadas, False, ""),
                spacing="2",
                width="100%",
            ),
        ),
        spacing="3",
        width="100%",
    )


def dialogo_fila() -> rx.Component:
    entrada = FilaState.entrada
    return dialogo(
        FilaState.acao_aberta,
        FilaState.mudar_acao,
        FilaState.titulo_acao,
        FilaState.confirmar_acao,
        rx.text(
            entrada["data"] + ", " + entrada["horario"] + " — " + entrada["espaco"],
            size="2",
        ),
        rx.text(FilaState.aviso_acao, size="2"),
        mensagem(FilaState.erro_dialogo, "red"),
        botao=FilaState.botao_acao,
        limpar_ao_enviar=False,
    )


def minhas_reservas() -> rx.Component:
    return layout_autenticado(
        rx.heading("Minhas reservas", size="5"),
        rx.cond(
            ReservasState.prazo_minutos > 0,
            rx.text(
                "Você pode cancelar sem penalidade até "
                + ReservasState.prazo_minutos.to_string()
                + " minutos antes do início.",
                size="2",
                color_scheme="gray",
            ),
        ),
        mensagem(ReservasState.mensagem_erro, "red"),
        mensagem(ReservasState.mensagem_sucesso, "green"),
        rx.cond(
            ReservasState.carregou,
            rx.vstack(
                rx.heading("Próximas", size="4"),
                tabela(ReservasState.proximas, True, "Nenhuma reserva próxima."),
                secao_faltas(),
                secao_fila(),
                rx.heading("Histórico", size="4"),
                tabela(ReservasState.historico, False, "Nenhuma reserva no histórico."),
                spacing="4",
                width="100%",
            ),
            rx.spinner(),
        ),
        dialogo_cancelar(),
        dialogo_fila(),
        dialogo_avaliar(),
    )
