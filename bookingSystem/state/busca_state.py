"""Estado da página de busca de espaços (todos os papéis).

Só usabilidade: tipos permitidos ao papel, regras do tipo, formato de data e
hora, ocupação e deslocamento por prioridade são decididos no Xano. "Livre" e
"deslocável" são informativos: a reserva confere tudo de novo no momento da
criação (C6, design D13 e D14; C8, design D7 e D8). Desde a C9, o espaço
ocupado e não deslocável pode oferecer "Entrar na fila" (`pode_entrar_fila`),
e o espaço em cuja fila o usuário já está mostra essa indicação (`na_fila`).
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.horarios import minutos_para_hhmm

# Opção "sem filtro" dos seletores de unidade e tipo
TODOS = "todos"

MOTIVOS_HORARIO = {
    "TIPO_SEM_REGRAS": "tipo sem regras",
    "FIM_NAO_DEPOIS_DO_INICIO": "o fim deve ser depois do início",
    "DIAS_DIFERENTES": "início e fim em dias diferentes",
    "DIA_SEM_FUNCIONAMENTO": "dia sem funcionamento",
    "FORA_DA_GRANULARIDADE": "horário fora da granularidade",
    "ANTES_DA_ABERTURA": "início antes da abertura",
    "DEPOIS_DO_FECHAMENTO": "fim depois do fechamento",
    "DURACAO_ABAIXO_DA_MINIMA": "duração abaixo da mínima",
    "DURACAO_ACIMA_DA_MAXIMA": "duração acima da máxima",
    "ANTECEDENCIA_MINIMA": "antecedência menor que a mínima",
    "ANTECEDENCIA_MAXIMA": "antecedência maior que a máxima",
}


def _tipo_para_tela(tipo: dict) -> dict[str, str]:
    abertura = minutos_para_hhmm(tipo.get("hora_abertura_minutos"))
    fechamento = minutos_para_hhmm(tipo.get("hora_fechamento_minutos"))
    return {
        "id": str(tipo["id"]),
        "nome": tipo["nome"],
        "regras": (
            f"{abertura} às {fechamento}, de {tipo['duracao_min_minutos']} a "
            f"{tipo['duracao_max_minutos']} minutos"
            + ("; exige aprovação" if tipo.get("exige_aprovacao") else "")
        ),
    }


def _texto_deslocamento(quantidade: int) -> str:
    """Aviso da confirmação: quantas reservas o pedido vai deslocar."""
    if quantidade == 1:
        return "1 reserva de prioridade menor será cancelada para esta reserva."
    return (
        f"{quantidade} reservas de prioridade menor serão canceladas para esta "
        "reserva."
    )


def _espaco_para_tela(espaco: dict) -> dict[str, str]:
    if "dentro_das_regras" not in espaco:
        horario = ""
    elif espaco["dentro_das_regras"]:
        horario = "Dentro das regras do tipo"
    else:
        horario = "Fora das regras: " + ", ".join(
            MOTIVOS_HORARIO.get(m, m) for m in espaco.get("motivos") or []
        )
    if "ocupado" not in espaco:
        ocupacao = ""
    elif espaco.get("bloqueado"):
        # Bloqueio ativo no horário (C11): o Xano já o marca não deslocável e sem fila
        ocupacao = "Bloqueado"
    else:
        ocupacao = "Ocupado" if espaco["ocupado"] else "Livre"
    return {
        "id": str(espaco["id"]),
        "nome": espaco["nome"],
        "codigo": espaco["codigo"],
        "localizacao": espaco.get("localizacao") or "",
        "unidade": espaco["unidade"]["nome"],
        "tipo": espaco["tipo"]["nome"],
        "capacidade": str(espaco["capacidade"]),
        "recursos": ", ".join(
            f"{r['quantidade']}x {r['nome']}" for r in espaco.get("recursos") or []
        ),
        "exige_aprovacao": "sim" if espaco.get("exige_aprovacao") else "nao",
        "horario": horario,
        "dentro": "sim" if espaco.get("dentro_das_regras") else "nao",
        "ocupacao": ocupacao,
        "pode_reservar": (
            "sim"
            if espaco.get("dentro_das_regras") and espaco.get("ocupado") is False
            else "nao"
        ),
        # Ocupado por reservas que o usuário pode deslocar (C8); o Xano já só
        # marca deslocável o que está dentro das regras
        "pode_deslocar": (
            "sim"
            if espaco.get("dentro_das_regras")
            and espaco.get("ocupado") is True
            and espaco.get("deslocavel") is True
            else "nao"
        ),
        "deslocaria": str(espaco.get("deslocaria") or 0),
        # Fila de espera (C9, design D9): o Xano decide as duas indicações
        "pode_entrar_fila": "sim" if espaco.get("pode_entrar_fila") else "nao",
        "na_fila": "sim" if espaco.get("na_fila") else "nao",
    }


def _id_escolhido(valor) -> int | None:
    texto = str(valor or "").strip()
    return int(texto) if texto.isdigit() else None


class BuscaState(rx.State):
    """Filtros da busca e os espaços encontrados."""

    unidades: list[dict[str, str]] = []
    tipos: list[dict[str, str]] = []
    recursos: list[dict[str, str]] = []
    resultados: list[dict[str, str]] = []
    buscou: bool = False
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    # Último pedido de horário buscado: é o que "Reservar" envia
    pedido: dict[str, str] = {}
    _ultimos_filtros: dict = {}

    reservar_aberta: bool = False
    reservar: dict[str, str] = {}
    # Recusa da reserva mostrada dentro da confirmação (spec busca-espacos)
    erro_dialogo: str = ""
    # Deslocamento por prioridade confirmado no diálogo aberto e o aviso (C8)
    deslocar: bool = False
    aviso_deslocamento: str = ""

    # Entrada na fila de espera (C9)
    fila_aberta: bool = False
    fila: dict[str, str] = {}
    erro_fila: str = ""

    @rx.var
    def opcoes_unidade(self) -> list[dict[str, str]]:
        return [{"id": TODOS, "nome": "Todas as unidades"}, *self.unidades]

    @rx.var
    def opcoes_tipo(self) -> list[dict[str, str]]:
        return [{"id": TODOS, "nome": "Todos os tipos"}, *self.tipos]

    @rx.var
    def pedido_texto(self) -> str:
        """Ex.: 11/11/2026, das 10:00 às 11:00."""
        if not self.pedido:
            return ""
        ano, mes, dia = self.pedido["data"].split("-")
        return (
            f"{dia}/{mes}/{ano}, das {self.pedido['hora_inicio']} "
            f"às {self.pedido['hora_fim']}"
        )

    @rx.var
    def botao_reservar(self) -> str:
        return "Deslocar e reservar" if self.deslocar else "Reservar"

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            filtros = await api.filtros_busca(token)
            unidades = await api.listar_unidades_ativas()
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.unidades = [{"id": str(u["id"]), "nome": u["nome"]} for u in unidades]
        self.tipos = [_tipo_para_tela(t) for t in filtros["tipos"]]
        self.recursos = [
            {"id": str(r["id"]), "nome": r["nome"]} for r in filtros["recursos"]
        ]

    @rx.event
    def abrir(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.resultados = []
        self.buscou = False
        self.pedido = {}
        return BuscaState.carregar

    async def _consultar(self, filtros: dict):
        self.resultados = []
        self.buscou = False
        token = await token_da_sessao(self)
        try:
            espacos = await api.buscar_espacos(token, filtros)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.resultados = [_espaco_para_tela(e) for e in espacos]
        self.buscou = True

    @rx.event
    async def buscar(self, dados: dict):
        """Só envia a busca no clique (plano Free do Xano: poucas requisições)."""
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.resultados = []
        self.buscou = False
        self.pedido = {}
        horario = {
            campo: str(dados.get(campo, "") or "").strip()
            for campo in ("data", "hora_inicio", "hora_fim")
        }
        if any(horario.values()) and not all(horario.values()):
            self.mensagem_erro = (
                "Informe a data, a hora de início e a hora de fim juntas."
            )
            return
        filtros = {
            "unidade_id": _id_escolhido(dados.get("unidade_id")),
            "tipo_espaco_id": _id_escolhido(dados.get("tipo_espaco_id")),
            "capacidade_minima": _id_escolhido(dados.get("capacidade_minima")),
            "recursos_ids": [
                int(r["id"]) for r in self.recursos if dados.get("rec_" + r["id"])
            ],
            **horario,
        }
        self._ultimos_filtros = {
            c: v for c, v in filtros.items() if v not in (None, "")
        }
        if all(horario.values()):
            self.pedido = horario
        return await self._consultar(self._ultimos_filtros)

    # ---------- reservar ----------

    @rx.event
    def abrir_reservar(self, espaco: dict):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""
        self.reservar = espaco
        self.deslocar = espaco.get("pode_deslocar") == "sim"
        self.aviso_deslocamento = (
            _texto_deslocamento(int(espaco.get("deslocaria") or 0))
            if self.deslocar
            else ""
        )
        self.reservar_aberta = True

    @rx.event
    def mudar_reservar(self, aberta: bool):
        self.reservar_aberta = aberta

    @rx.event
    async def confirmar_reservar(self, _dados: dict):
        self.erro_dialogo = ""
        token = await token_da_sessao(self)
        try:
            resposta = await api.criar_reserva(
                token,
                int(self.reservar["id"]),
                self.pedido["data"],
                self.pedido["hora_inicio"],
                self.pedido["hora_fim"],
                deslocar=self.deslocar,
            )
        except api.ErroValidacao as erro:
            # Ex.: horário ocupado depois da busca; a confirmação não fecha
            self.erro_dialogo = erro.mensagem
            return
        except api.ErroApi as erro:
            self.reservar_aberta = False
            return await tratar_erro_api(self, erro)
        if resposta.get("requer_confirmacao"):
            # Ocupado depois da busca por reservas deslocáveis: nada foi
            # gravado, e só um novo clique confirma o deslocamento (C8, D8)
            self.deslocar = True
            self.aviso_deslocamento = resposta["mensagem"]
            return
        self.reservar_aberta = False
        self.mensagem_sucesso = resposta["mensagem"]
        # Atualiza livre e ocupado com o mesmo pedido
        return await self._consultar(self._ultimos_filtros)

    # ---------- fila de espera (C9) ----------

    @rx.event
    def abrir_fila(self, espaco: dict):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_fila = ""
        self.fila = espaco
        self.fila_aberta = True

    @rx.event
    def mudar_fila(self, aberta: bool):
        self.fila_aberta = aberta

    @rx.event
    async def confirmar_fila(self, _dados: dict):
        self.erro_fila = ""
        token = await token_da_sessao(self)
        try:
            resposta = await api.entrar_fila(
                token,
                int(self.fila["id"]),
                self.pedido["data"],
                self.pedido["hora_inicio"],
                self.pedido["hora_fim"],
            )
        except api.ErroValidacao as erro:
            # Ex.: o horário ficou livre depois da busca; a confirmação não fecha
            self.erro_fila = erro.mensagem
            return
        except api.ErroApi as erro:
            self.fila_aberta = False
            return await tratar_erro_api(self, erro)
        self.fila_aberta = False
        self.mensagem_sucesso = resposta["mensagem"]
        return await self._consultar(self._ultimos_filtros)
