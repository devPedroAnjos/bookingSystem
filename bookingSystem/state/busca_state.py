"""Estado da página de busca de espaços (todos os papéis).

Só usabilidade: tipos permitidos ao papel, regras do tipo e formato de data e
hora são decididos no Xano. A busca não verifica ocupação (design D7).
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


def _espaco_para_tela(espaco: dict) -> dict[str, str]:
    if "dentro_das_regras" not in espaco:
        horario = ""
    elif espaco["dentro_das_regras"]:
        horario = "Dentro das regras do tipo"
    else:
        horario = "Fora das regras: " + ", ".join(
            MOTIVOS_HORARIO.get(m, m) for m in espaco.get("motivos") or []
        )
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

    @rx.var
    def opcoes_unidade(self) -> list[dict[str, str]]:
        return [{"id": TODOS, "nome": "Todas as unidades"}, *self.unidades]

    @rx.var
    def opcoes_tipo(self) -> list[dict[str, str]]:
        return [{"id": TODOS, "nome": "Todos os tipos"}, *self.tipos]

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
        self.resultados = []
        self.buscou = False
        return BuscaState.carregar

    @rx.event
    async def buscar(self, dados: dict):
        """Só envia a busca no clique (plano Free do Xano: poucas requisições)."""
        self.mensagem_erro = ""
        self.resultados = []
        self.buscou = False
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
        token = await token_da_sessao(self)
        try:
            espacos = await api.buscar_espacos(
                token, {c: v for c, v in filtros.items() if v not in (None, "")}
            )
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.resultados = [_espaco_para_tela(e) for e in espacos]
        self.buscou = True
