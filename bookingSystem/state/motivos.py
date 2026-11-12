"""Motivos das desativações e da inativação de conta, e aviso de impacto (C6).

Os códigos são validados no Xano (`validar_motivo`); aqui só há os rótulos e
a validação de usabilidade. As listas do Xano e as daqui mudam juntas.
`MotivoState` e `ImpactoState` são compartilhados pelos diálogos de desativar
espaço, tipo e unidade e de inativar conta, porque só um fica aberto por vez.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao

OUTRO = "OUTRO"
TAMANHO_MAXIMO_DESCRICAO = 500

MOTIVOS_DESATIVACAO = {
    "MANUTENCAO_REFORMA": "Manutenção ou reforma",
    "INFRAESTRUTURA": "Problema de infraestrutura",
    "SEGURANCA_INTERDICAO": "Interdição ou risco à segurança",
    "EQUIPAMENTOS_INDISPONIVEIS": "Equipamentos ou recursos indisponíveis",
    "MUDANCA_DE_USO": "Mudança de uso",
    "BAIXA_UTILIZACAO": "Baixa utilização",
    "ENCERRAMENTO_ATIVIDADES": "Encerramento das atividades no local",
    OUTRO: "Outro",
}

MOTIVOS_CONTA = {
    "DESLIGAMENTO_INSTITUICAO": "Desligamento da instituição",
    "CONCLUSAO_CURSO": "Conclusão de curso",
    "TRANCAMENTO_AFASTAMENTO": "Trancamento ou afastamento",
    "USO_INDEVIDO": "Uso indevido do sistema",
    "CONTA_DUPLICADA": "Conta duplicada",
    "PEDIDO_TITULAR": "Pedido do titular",
    OUTRO: "Outro",
}

MOTIVOS_CANCELAMENTO = {
    "USUARIO": "cancelada por você",
    "USUARIO_TARDIO": "cancelada por você depois do prazo",
    "BLOQUEIO": "bloqueio do espaço",
    "PRIORIDADE": "substituída por reserva de prioridade maior",
    "SERIE": "cancelamento da série",
    "CONTA_INATIVADA": "conta inativada",
    "ESPACO_INDISPONIVEL": "espaço indisponível",
}

AVISO_OUTRO_VISIVEL = (
    'O texto de "Outro" fica visível para quem tiver a reserva cancelada.'
)


def ler_motivo(dados: dict) -> tuple[str, str, str]:
    """Código, descrição e o erro de usabilidade ("" quando está ok)."""
    codigo = str(dados.get("motivo_codigo", "") or "").strip()
    descricao = str(dados.get("motivo_descricao", "") or "").strip()
    if not codigo:
        return codigo, descricao, "Escolha o motivo."
    if codigo != OUTRO:
        return codigo, "", ""
    if not descricao:
        return codigo, descricao, "Descreva o motivo."
    if len(descricao) > TAMANHO_MAXIMO_DESCRICAO:
        return codigo, descricao, (
            "A descrição do motivo deve ter no máximo 500 caracteres."
        )
    return codigo, descricao, ""


def texto_cancelamento(reserva: dict) -> str:
    """Motivo do cancelamento para a tela; na desativação, com o motivo dela.

    Mover o espaço e trocar o tipo não têm motivo próprio (detalhe vazio), e a
    inativação de conta nunca traz o motivo (spec situacao-conta).
    """
    motivo = reserva.get("motivo_cancelamento")
    if not motivo:
        return ""
    texto = MOTIVOS_CANCELAMENTO.get(motivo, motivo)
    detalhe = reserva.get("motivo_detalhe")
    if detalhe == OUTRO and reserva.get("motivo_descricao"):
        texto += f" ({reserva['motivo_descricao']})"
    elif detalhe:
        texto += f" ({MOTIVOS_DESATIVACAO.get(detalhe, detalhe)})"
    return texto


def texto_motivo(reserva: dict) -> str:
    """Motivo mostrado ao lado da situação: o da recusa ou o do cancelamento (C7)."""
    if reserva.get("status") == "RECUSADA":
        return reserva.get("motivo_recusa") or ""
    return texto_cancelamento(reserva)


def texto_impacto(impacto: dict) -> str:
    """Aviso do diálogo a partir da rota impacto_reservas (design D8)."""
    if impacto.get("em_andamento_ate"):
        return (
            f"Há reserva em andamento até {impacto['em_andamento_ate']}; a ação "
            "só será aceita depois desse horário."
        )
    quantidade = impacto.get("reservas") or 0
    if quantidade == 0:
        return "Nenhuma reserva será cancelada."
    if quantidade == 1:
        return "1 reserva será cancelada."
    return f"{quantidade} reservas serão canceladas."


class MotivoState(rx.State):
    """Motivo escolhido no diálogo aberto: mostra a descrição só em "Outro"."""

    codigo: str = ""

    @rx.event
    def escolher(self, codigo: str):
        self.codigo = codigo

    @rx.event
    def limpar(self):
        self.codigo = ""


class ImpactoState(rx.State):
    """Aviso de reservas afetadas pela ação do diálogo aberto."""

    aviso: str = ""

    @rx.event
    async def consultar(self, alvo: str, alvo_id: int):
        """Só informativo: a ação recalcula tudo no Xano ao ser executada."""
        # Envia já a troca do aviso, para não mostrar o número de outro alvo
        self.aviso = "Consultando as reservas afetadas..."
        yield
        token = await token_da_sessao(self)
        try:
            impacto = await api.impacto_reservas(token, alvo, alvo_id)
        except api.ErroApi:
            self.aviso = "Não foi possível consultar as reservas afetadas."
            return
        self.aviso = texto_impacto(impacto)


def abrir_dialogo_com_impacto(alvo: str, alvo_id: str) -> list:
    """Eventos comuns ao abrir um diálogo de desativar, mover ou inativar."""
    return [MotivoState.limpar, ImpactoState.consultar(alvo, int(alvo_id))]
