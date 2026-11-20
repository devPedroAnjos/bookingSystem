"""Página de parâmetros (só o admin principal)."""

import reflex as rx

from bookingSystem.pages.componentes import mensagem
from bookingSystem.pages.layout import layout_autenticado
from bookingSystem.state.auth_state import AuthState
from bookingSystem.state.parametros_state import ParametrosState

ROTULOS_LIMITES = {
    "max_pedidos_cadastro": "Máximo de pedidos de cadastro por conta",
    "max_coordenadores_unidade": "Máximo de coordenadores por unidade",
    "max_unidades_coordenador": "Máximo de unidades por coordenador",
    "max_admins": "Máximo de administradores ativos",
    "granularidade_minutos": (
        "Granularidade de horário, em minutos (divisor de 60: 5, 10, 15, 30...)"
    ),
    "prazo_cancelamento_minutos": (
        "Prazo de cancelamento sem penalidade, em minutos antes do início"
    ),
    "prazo_deslocamento_minutos": (
        "Prazo para deslocar por prioridade, em minutos antes do início "
        "(da nova reserva e de cada deslocada)"
    ),
    "prazo_fila_minutos": (
        "Corte da fila de espera, em minutos antes do início (nenhuma "
        "confirmação passa dele)"
    ),
    "prazo_confirmacao_fila_minutos": (
        "Prazo para confirmar a vaga da fila, em minutos a partir do aviso "
        "(limitado ao corte)"
    ),
    "tempo_minimo_fila_minutos": (
        "Tempo mínimo útil da fila, em minutos antes do corte (a fila fecha "
        "nesse ponto)"
    ),
}

NOMES_DIAS = {
    "1": "Segunda",
    "2": "Terça",
    "3": "Quarta",
    "4": "Quinta",
    "5": "Sexta",
    "6": "Sábado",
    "7": "Domingo",
}


def campo_dias() -> rx.Component:
    return campo(
        "Dias de funcionamento",
        rx.hstack(
            *[
                rx.checkbox(
                    nome,
                    name="dia_" + dia,
                    default_checked=ParametrosState.dias[dia],
                )
                for dia, nome in NOMES_DIAS.items()
            ],
            spacing="4",
            wrap="wrap",
        ),
    )


def campo(rotulo: str, controle: rx.Component) -> rx.Component:
    return rx.vstack(
        rx.text(rotulo, size="2", weight="medium"), controle, spacing="1", width="100%"
    )


def campo_limite(nome: str) -> rx.Component:
    return campo(
        ROTULOS_LIMITES[nome],
        rx.input(
            name=nome,
            type="number",
            min=1,
            default_value=ParametrosState.limites[nome],
            width="160px",
        ),
    )


def formulario() -> rx.Component:
    return rx.form(
        rx.vstack(
            campo(
                "Domínios de e-mail aceitos (separados por vírgula)",
                rx.text_area(
                    name="dominios",
                    default_value=ParametrosState.dominios,
                    width="100%",
                ),
            ),
            *[campo_limite(nome) for nome in ROTULOS_LIMITES],
            campo_dias(),
            rx.button("Salvar", type="submit"),
            spacing="4",
            width="100%",
            max_width="520px",
        ),
        on_submit=ParametrosState.salvar,
        # Recria o formulário a cada carga, para mostrar os valores salvos
        key=ParametrosState.versao,
        width="100%",
    )


def parametros() -> rx.Component:
    return layout_autenticado(
        rx.heading("Parâmetros", size="5"),
        rx.text(
            "Reduzir um limite não remove ninguém; o novo valor vale para as "
            "próximas ações.",
            size="2",
            color_scheme="gray",
        ),
        mensagem(ParametrosState.mensagem_erro, "red"),
        mensagem(ParametrosState.mensagem_sucesso, "green"),
        rx.cond(ParametrosState.versao > 0, formulario(), rx.spinner()),
        permitido=AuthState.e_principal,
    )
