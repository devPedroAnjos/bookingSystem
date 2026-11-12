"""Estado da página "Reservas da unidade" (coordenador e admin).

Só usabilidade: escopo, situação efetiva, período, teto de 200 itens e a
decisão são do Xano (C7, design D9 e D10). As recusas de validação (400)
aparecem na própria página ou no diálogo de recusa.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.motivos import texto_cancelamento
from bookingSystem.state.reservas_state import SITUACOES

TODAS_UNIDADES = "todas"
TODOS_ESPACOS = "todos"

FILTROS_SITUACAO = [
    {"id": "PENDENTE", "nome": "Pendentes"},
    {"id": "CONFIRMADA", "nome": "Confirmadas"},
    {"id": "RECUSADA", "nome": "Recusadas"},
    {"id": "EXPIRADA", "nome": "Expiradas"},
    {"id": "CANCELADA", "nome": "Canceladas"},
    {"id": "TODAS", "nome": "Todas"},
]

# Nível gravado na criação (não é o papel atual); 3 vale para coordenador e admin
PAPEIS_POR_NIVEL = {1: "Aluno", 2: "Professor", 3: "Coordenação/administração"}

AVISO_LIMITADA = "Mostrando as 200 primeiras; use o período ou o espaço para refinar."


def _data_br(data: str) -> str:
    ano, mes, dia = data.split("-")
    return f"{dia}/{mes}/{ano}"


def _detalhe(reserva: dict) -> str:
    """Decisão ou cancelamento, conforme a situação."""
    status = reserva["status"]
    decisor = reserva.get("decidido_por") or ""
    quando = reserva.get("decidido_em") or ""
    if status == "RECUSADA":
        motivo = reserva.get("motivo_recusa") or ""
        return f"Recusada por {decisor} em {quando}: {motivo}"
    if status == "CONFIRMADA" and decisor:
        return f"Aprovada por {decisor} em {quando}"
    if status == "CANCELADA":
        texto = texto_cancelamento(reserva)
        # Na inativação de conta o backend não informa quem cancelou
        if reserva.get("cancelado_por"):
            texto += f" — por {reserva['cancelado_por']}"
        return texto
    return ""


def _reserva_para_tela(reserva: dict) -> dict[str, str]:
    return {
        "id": str(reserva["id"]),
        "dono": reserva["dono"]["nome"],
        "email": reserva["dono"]["email"],
        "papel": PAPEIS_POR_NIVEL.get(reserva["nivel_prioridade"], ""),
        "codigo": reserva["espaco"]["codigo"],
        "espaco": reserva["espaco"]["nome"],
        "unidade": reserva["unidade"]["nome"],
        "tipo": reserva["tipo"]["nome"],
        "data": _data_br(reserva["data"]),
        "horario": f"{reserva['hora_inicio']} às {reserva['hora_fim']}",
        "status": reserva["status"],
        "situacao": SITUACOES.get(reserva["status"], reserva["status"]),
        "criado_em": reserva.get("criado_em") or "",
        "detalhe": _detalhe(reserva),
    }


def _filtros_da_tela(dados: dict) -> dict[str, str]:
    """Filtros do formulário no formato da API; "todas" e vazio não vão."""
    unidade = str(dados.get("unidade_id") or "")
    espaco = str(dados.get("espaco_id") or "")
    return {
        "unidade_id": "" if unidade == TODAS_UNIDADES else unidade,
        "espaco_id": "" if espaco == TODOS_ESPACOS else espaco,
        "situacao": str(dados.get("situacao") or "PENDENTE"),
        "data_inicial": str(dados.get("data_inicial") or "").strip(),
        "data_final": str(dados.get("data_final") or "").strip(),
    }


class ReservasUnidadeState(rx.State):
    """Lista filtrada das reservas no escopo do gestor e a decisão das pendentes."""

    reservas: list[dict[str, str]] = []
    limitada: bool = False
    carregou: bool = False
    situacao_listada: str = "PENDENTE"
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""

    unidades: list[dict[str, str]] = []
    espacos: list[dict[str, str]] = []
    unidade_escolhida: str = TODAS_UNIDADES

    _filtros: dict[str, str] = {}

    recusa_aberta: bool = False
    recusa: dict[str, str] = {}
    erro_dialogo: str = ""

    @rx.var
    def opcoes_unidade(self) -> list[dict[str, str]]:
        return [{"id": TODAS_UNIDADES, "nome": "Todas as unidades"}, *self.unidades]

    @rx.var
    def opcoes_espaco(self) -> list[dict[str, str]]:
        """Espaços da unidade escolhida (todos, sem unidade escolhida)."""
        espacos = [
            e
            for e in self.espacos
            if self.unidade_escolhida == TODAS_UNIDADES
            or e["unidade_id"] == self.unidade_escolhida
        ]
        return [{"id": TODOS_ESPACOS, "nome": "Todos os espaços"}, *espacos]

    @rx.var
    def opcoes_situacao(self) -> list[dict[str, str]]:
        return FILTROS_SITUACAO

    @rx.var
    def aviso_limitada(self) -> str:
        return AVISO_LIMITADA if self.limitada else ""

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""

    @rx.event
    def abrir(self):
        self._limpar_mensagens()
        self.reservas = []
        self.limitada = False
        self.carregou = False
        self.unidade_escolhida = TODAS_UNIDADES
        self._filtros = {"situacao": "PENDENTE"}
        return ReservasUnidadeState.carregar_opcoes

    @rx.event
    async def carregar_opcoes(self):
        token = await token_da_sessao(self)
        try:
            unidades = await api.listar_unidades_geridas(token)
            espacos = await api.listar_espacos_geridos(token)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.unidades = [{"id": str(u["id"]), "nome": u["nome"]} for u in unidades]
        self.espacos = [
            {
                "id": str(e["id"]),
                "nome": f"{e['codigo']} — {e['nome']}",
                "unidade_id": str(e["unidade"]["id"]),
            }
            for e in espacos
        ]
        return ReservasUnidadeState.carregar

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            resposta = await api.reservas_unidade(token, self._filtros)
        except api.ErroValidacao as erro:
            self.mensagem_erro = erro.mensagem
            self.reservas = []
            self.carregou = True
            return
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.reservas = [_reserva_para_tela(r) for r in resposta["reservas"]]
        self.limitada = bool(resposta.get("limitada"))
        self.situacao_listada = self._filtros.get("situacao") or "PENDENTE"
        self.carregou = True

    @rx.event
    def escolher_unidade(self, unidade_id: str):
        self.unidade_escolhida = unidade_id

    def _espaco_fora_da_unidade(self, filtros: dict[str, str]) -> bool:
        """Espaço escolhido que não pertence à unidade escolhida (usabilidade)."""
        if not filtros["unidade_id"] or not filtros["espaco_id"]:
            return False
        espaco = next(
            (e for e in self.espacos if e["id"] == filtros["espaco_id"]), None
        )
        return espaco is not None and espaco["unidade_id"] != filtros["unidade_id"]

    @rx.event
    def filtrar(self, dados: dict):
        """Só consulta no clique (plano gratuito do Xano: poucas requisições)."""
        self._limpar_mensagens()
        filtros = _filtros_da_tela(dados)
        if self._espaco_fora_da_unidade(filtros):
            filtros["espaco_id"] = ""
        self._filtros = filtros
        self.carregou = False
        return ReservasUnidadeState.carregar

    @rx.event
    async def aprovar(self, reserva_id: str):
        self._limpar_mensagens()
        token = await token_da_sessao(self)
        try:
            resposta = await api.aprovar_reserva(token, int(reserva_id))
        except api.ErroValidacao as erro:
            # Ex.: o prazo de decisão terminou com a página aberta
            self.mensagem_erro = erro.mensagem
            return ReservasUnidadeState.carregar
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.mensagem_sucesso = resposta["mensagem"]
        return ReservasUnidadeState.carregar

    @rx.event
    def abrir_recusa(self, reserva: dict):
        self._limpar_mensagens()
        self.erro_dialogo = ""
        self.recusa = reserva
        self.recusa_aberta = True

    @rx.event
    def mudar_recusa(self, aberta: bool):
        self.recusa_aberta = aberta

    @rx.event
    async def confirmar_recusa(self, dados: dict):
        self.erro_dialogo = ""
        motivo = str(dados.get("motivo", "")).strip()
        if not motivo:
            self.erro_dialogo = "Informe o motivo da recusa."
            return
        token = await token_da_sessao(self)
        try:
            resposta = await api.recusar_reserva(
                token, int(self.recusa["id"]), motivo
            )
        except api.ErroValidacao as erro:
            self.erro_dialogo = erro.mensagem
            return
        except api.ErroApi as erro:
            self.recusa_aberta = False
            return await tratar_erro_api(self, erro)
        self.recusa_aberta = False
        self.mensagem_sucesso = resposta["mensagem"]
        return ReservasUnidadeState.carregar
