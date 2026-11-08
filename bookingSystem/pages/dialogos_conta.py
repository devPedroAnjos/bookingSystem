"""Diálogos de inativar, reativar e redefinir senha.

Usados pelas páginas de usuários e de administradores, cada uma com o próprio
State (ambos herdam `AcoesContaMixin`).
"""

import reflex as rx

from bookingSystem.pages.componentes import (
    aviso_impacto,
    campo_senha,
    campos_motivo,
    dialogo,
    mensagem,
    seletor,
)
from bookingSystem.state.motivos import MOTIVOS_CONTA


def _aviso(texto: str | rx.Var[str]) -> rx.Component:
    return rx.text(texto, size="2", color_scheme="gray")


def dialogo_inativacao(estado) -> rx.Component:
    return dialogo(
        estado.inativacao_aberta,
        estado.mudar_inativacao,
        "Inativar " + estado.alvo_nome,
        estado.confirmar_inativacao,
        _aviso(
            "A pessoa perde o acesso na hora. As reservas dela que ainda não "
            "começaram são canceladas; a que estiver em andamento continua. O "
            "motivo fica só no registro de auditoria e não é mostrado a ela."
        ),
        rx.cond(
            estado.alvo_papel == "COORDENADOR",
            _aviso(
                "As coordenações ficam guardadas para a reativação; a unidade "
                "pode ficar sem coordenador ativo."
            ),
        ),
        mensagem(estado.erro_dialogo, "red"),
        campos_motivo(MOTIVOS_CONTA, aviso_outro=False),
        aviso_impacto(),
        botao="Inativar",
        limpar_ao_enviar=False,
    )


def dialogo_reativacao(estado) -> rx.Component:
    coordenador = estado.alvo_papel == "COORDENADOR"
    unidades = estado.unidades_ativas
    return dialogo(
        estado.reativacao_aberta,
        estado.mudar_reativacao,
        "Reativar " + estado.alvo_nome,
        estado.confirmar_reativacao,
        rx.cond(
            estado.alvo_papel == "ADMIN",
            _aviso("A conta volta a ocupar uma vaga no limite de administradores."),
        ),
        mensagem(estado.erro_dialogo, "red"),
        rx.cond(
            estado.reativacao_pede_unidades,
            rx.vstack(
                _aviso(
                    rx.cond(
                        coordenador,
                        "Nenhuma das unidades antigas pode ser mantida. "
                        "Escolha as unidades que a pessoa vai coordenar.",
                        "A unidade do professor está desativada. Escolha a nova.",
                    )
                ),
                seletor(
                    "unidade1",
                    unidades,
                    rx.cond(coordenador, "Unidade a coordenar", "Nova unidade"),
                ),
                rx.cond(
                    coordenador,
                    seletor("unidade2", unidades, "Segunda unidade (opcional)"),
                ),
                spacing="3",
                width="100%",
            ),
        ),
        botao="Reativar",
    )


def dialogo_redefinicao(estado) -> rx.Component:
    return dialogo(
        estado.redefinicao_aberta,
        estado.mudar_redefinicao,
        "Redefinir a senha de " + estado.alvo_nome,
        estado.confirmar_redefinicao,
        _aviso(
            "As sessões abertas da pessoa são encerradas, e ela terá de trocar "
            "a senha no próximo acesso. Entregue a senha provisória por um "
            "canal seguro."
        ),
        mensagem(estado.erro_dialogo, "red"),
        campo_senha("senha_provisoria", "Senha provisória (mínimo de 8 caracteres)"),
        campo_senha("confirmacao", "Confirme a senha provisória"),
        botao="Redefinir",
    )


def dialogos_situacao(estado) -> rx.Component:
    return rx.fragment(
        dialogo_inativacao(estado),
        dialogo_reativacao(estado),
        dialogo_redefinicao(estado),
    )
