"""Estado da página de espaços (admin e coordenador, no próprio escopo).

Só usabilidade: escopo, código único, unidade e tipo ativos e recursos são
validados no Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.motivos import abrir_dialogo_com_impacto, ler_motivo

MOTIVOS = {
    "ESPACO_DESATIVADO": "espaço desativado",
    "UNIDADE_DESATIVADA": "unidade desativada",
    "TIPO_DESATIVADO": "tipo desativado",
}


def _espaco_para_tela(espaco: dict) -> dict[str, str]:
    recursos = espaco.get("recursos") or []
    return {
        "id": str(espaco["id"]),
        "nome": espaco["nome"],
        "codigo": espaco["codigo"],
        "capacidade": str(espaco["capacidade"]),
        "localizacao": espaco.get("localizacao") or "",
        "descricao": espaco.get("descricao") or "",
        "ativo": "sim" if espaco["ativo"] else "nao",
        "unidade_id": str(espaco["unidade"]["id"]),
        "unidade_nome": espaco["unidade"]["nome"],
        "tipo_id": str(espaco["tipo"]["id"]),
        "tipo_nome": espaco["tipo"]["nome"],
        "tipo_ativo": "sim" if espaco["tipo"]["ativo"] else "nao",
        "recursos": ", ".join(
            f"{r['quantidade']}x {r['nome']}" for r in recursos
        ),
        "reservavel": "sim" if espaco["reservavel"] else "nao",
        "motivos": ", ".join(MOTIVOS.get(m, m) for m in espaco["motivos"]),
    }


def _opcao(item: dict) -> dict[str, str]:
    return {"id": str(item["id"]), "nome": item["nome"]}


def _capacidade(dados: dict) -> int | None:
    valor = str(dados.get("capacidade", "") or "").strip()
    return int(valor) if valor.isdigit() and int(valor) >= 1 else None


def _campos_espaco(dados: dict) -> dict | None:
    """Campos comuns de criar e editar, ou None se faltar algo obrigatório."""
    nome = str(dados.get("nome", "")).strip()
    codigo = str(dados.get("codigo", "")).strip()
    tipo = str(dados.get("tipo_espaco_id", "") or "")
    capacidade = _capacidade(dados)
    if not nome or not codigo or not tipo.isdigit() or capacidade is None:
        return None
    return {
        "tipo_espaco_id": int(tipo),
        "nome": nome,
        "codigo": codigo,
        "capacidade": capacidade,
        "localizacao": str(dados.get("localizacao", "")).strip(),
        "descricao": str(dados.get("descricao", "")).strip(),
    }


class EspacosState(rx.State):
    """Espaços do escopo, com os formulários de gestão."""

    espacos: list[dict[str, str]] = []
    unidades_ativas: list[dict[str, str]] = []
    tipos_ativos: list[dict[str, str]] = []
    catalogo: list[dict[str, str]] = []
    filtro_unidade: str = ""
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    # Erro de validação mostrado dentro do diálogo aberto (padrão da C3)
    erro_dialogo: str = ""

    criar_aberta: bool = False

    editar_aberta: bool = False
    editar: dict[str, str] = {}
    tipos_edicao: list[dict[str, str]] = []

    recursos_aberta: bool = False
    recursos_espaco_id: str = ""
    recursos_espaco_nome: str = ""
    recursos_edicao: list[dict[str, str]] = []

    mover_aberta: bool = False
    mover_espaco_id: str = ""
    mover_espaco_nome: str = ""
    destinos_mover: list[dict[str, str]] = []

    desativar_aberta: bool = False
    desativar_id: str = ""
    desativar_nome: str = ""

    _por_id: dict[str, dict] = {}

    @rx.var
    def espacos_filtrados(self) -> list[dict[str, str]]:
        if not self.filtro_unidade:
            return self.espacos
        return [
            e for e in self.espacos if e["unidade_id"] == self.filtro_unidade
        ]

    @rx.var
    def unidades_filtro(self) -> list[dict[str, str]]:
        vistas: dict[str, str] = {}
        for espaco in self.espacos:
            vistas[espaco["unidade_id"]] = espaco["unidade_nome"]
        return [{"id": i, "nome": n} for i, n in vistas.items()]

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            espacos = await api.listar_espacos_geridos(token)
            unidades = await api.listar_unidades_geridas(token)
            tipos = await api.listar_tipos_espaco(token)
            catalogo = await api.listar_recursos(token)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self._por_id = {str(e["id"]): e for e in espacos}
        self.espacos = [_espaco_para_tela(e) for e in espacos]
        self.unidades_ativas = [_opcao(u) for u in unidades if u["ativa"]]
        self.tipos_ativos = [_opcao(t) for t in tipos if t["ativo"]]
        self.catalogo = [_opcao(r) for r in catalogo]

    @rx.event
    def abrir(self):
        self._limpar_mensagens()
        self.filtro_unidade = ""
        return EspacosState.carregar

    @rx.event
    def filtrar_unidade(self, unidade_id: str):
        self.filtro_unidade = "" if unidade_id == "todas" else unidade_id

    async def _executar(self, chamada):
        """Executa uma ação, mostra a mensagem da API e recarrega a lista."""
        try:
            resposta = await chamada
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            if redirecionamento is not None:
                return redirecionamento
            return EspacosState.carregar
        self.mensagem_sucesso = resposta["mensagem"]
        return EspacosState.carregar

    # ---------- criar e editar ----------

    @rx.event
    def mudar_criar(self, aberta: bool):
        self._limpar_mensagens()
        self.criar_aberta = aberta

    @rx.event
    async def confirmar_criar(self, dados: dict):
        self._limpar_mensagens()
        campos = _campos_espaco(dados)
        unidade = str(dados.get("unidade_id", "") or "")
        if campos is None or not unidade.isdigit():
            self.erro_dialogo = (
                "Informe unidade, tipo, nome, código e capacidade (1 ou mais)."
            )
            return
        self.criar_aberta = False
        token = await token_da_sessao(self)
        campos["unidade_id"] = int(unidade)
        return await self._executar(api.criar_espaco(token, campos))

    @rx.event
    def abrir_editar(self, espaco: dict):
        self._limpar_mensagens()
        self.editar = espaco
        # O tipo atual aparece mesmo desativado (spec espacos, Tela de espaços)
        self.tipos_edicao = list(self.tipos_ativos)
        if espaco["tipo_ativo"] != "sim":
            self.tipos_edicao.append({
                "id": espaco["tipo_id"],
                "nome": espaco["tipo_nome"] + " (desativado)",
            })
        self.editar_aberta = True
        # Aviso para o caso de troca de tipo, que cancela reservas (D8)
        return abrir_dialogo_com_impacto("espaco_id", espaco["id"])

    @rx.event
    def mudar_editar(self, aberta: bool):
        self.editar_aberta = aberta

    @rx.event
    async def confirmar_editar(self, dados: dict):
        self._limpar_mensagens()
        campos = _campos_espaco(dados)
        if campos is None:
            self.erro_dialogo = (
                "Informe tipo, nome, código e capacidade (1 ou mais)."
            )
            return
        self.editar_aberta = False
        token = await token_da_sessao(self)
        campos["espaco_id"] = int(self.editar["id"])
        return await self._executar(api.editar_espaco(token, campos))

    # ---------- recursos ----------

    @rx.event
    def abrir_recursos(self, espaco_id: str):
        self._limpar_mensagens()
        atuais = {
            str(r["id"]): str(r["quantidade"])
            for r in self._por_id[espaco_id].get("recursos") or []
        }
        self.recursos_espaco_id = espaco_id
        self.recursos_espaco_nome = self._por_id[espaco_id]["nome"]
        self.recursos_edicao = [
            {**r, "quantidade": atuais.get(r["id"], "0")} for r in self.catalogo
        ]
        self.recursos_aberta = True

    @rx.event
    def mudar_recursos(self, aberta: bool):
        self.recursos_aberta = aberta

    @rx.event
    async def confirmar_recursos(self, dados: dict):
        self._limpar_mensagens()
        recursos = []
        for recurso in self.recursos_edicao:
            valor = str(dados.get("rec_" + recurso["id"], "") or "0").strip()
            if not valor.isdigit():
                self.erro_dialogo = "Use quantidades inteiras (0 para não ter)."
                return
            if int(valor) > 0:
                recursos.append(
                    {"recurso_id": int(recurso["id"]), "quantidade": int(valor)}
                )
        self.recursos_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(
            api.definir_recursos_espaco(
                token, int(self.recursos_espaco_id), recursos
            )
        )

    # ---------- situação e mudança de unidade ----------

    @rx.event
    def abrir_desativar(self, espaco: dict):
        self._limpar_mensagens()
        self.desativar_id = espaco["id"]
        self.desativar_nome = espaco["nome"]
        self.desativar_aberta = True
        return abrir_dialogo_com_impacto("espaco_id", espaco["id"])

    @rx.event
    def mudar_desativar(self, aberta: bool):
        self.desativar_aberta = aberta

    @rx.event
    async def confirmar_desativar(self, dados: dict):
        self._limpar_mensagens()
        codigo, descricao, self.erro_dialogo = ler_motivo(dados)
        if self.erro_dialogo:
            return
        self.desativar_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(
            api.desativar_espaco(token, int(self.desativar_id), codigo, descricao)
        )

    @rx.event
    async def reativar(self, espaco_id: str):
        self._limpar_mensagens()
        token = await token_da_sessao(self)
        return await self._executar(api.reativar_espaco(token, int(espaco_id)))

    @rx.event
    def abrir_mover(self, espaco: dict):
        self._limpar_mensagens()
        self.mover_espaco_id = espaco["id"]
        self.mover_espaco_nome = espaco["nome"]
        self.destinos_mover = [
            u for u in self.unidades_ativas if u["id"] != espaco["unidade_id"]
        ]
        self.mover_aberta = True
        return abrir_dialogo_com_impacto("espaco_id", espaco["id"])

    @rx.event
    def mudar_mover(self, aberta: bool):
        self.mover_aberta = aberta

    @rx.event
    async def confirmar_mover(self, dados: dict):
        self._limpar_mensagens()
        destino = str(dados.get("unidade_id", "") or "")
        if not destino.isdigit():
            self.erro_dialogo = "Escolha a unidade de destino."
            return
        self.mover_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(
            api.mover_espaco(token, int(self.mover_espaco_id), int(destino))
        )
