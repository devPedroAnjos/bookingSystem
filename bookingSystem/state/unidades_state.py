"""Estado da página de unidades e coordenação (só administrador).

Só usabilidade: limites, vagas, origem coberta e destinos são validados no Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.motivos import abrir_dialogo_com_impacto, ler_motivo


def _unidade_para_tela(unidade: dict) -> dict[str, str]:
    nomes = [c["nome"] for c in unidade.get("coordenadores") or []]
    return {
        "id": str(unidade["id"]),
        "nome": unidade["nome"],
        "endereco": unidade.get("endereco") or "",
        "ativa": "sim" if unidade["ativa"] else "nao",
        "coordenadores": ", ".join(nomes),
        "sem_coordenador": "sim" if unidade.get("sem_coordenador") else "nao",
        "professores": str(len(unidade.get("professores") or [])),
        "pendentes": str(unidade.get("pedidos_pendentes") or 0),
    }


def _coordenador_para_tela(usuario: dict) -> dict[str, str]:
    coordenacoes = usuario.get("coordenacoes") or []
    return {
        "id": str(usuario["id"]),
        "nome": usuario["nome"],
        "unidades": ", ".join(c["nome"] for c in coordenacoes),
        "qtd": str(len(coordenacoes)),
    }


def _pessoa(item: dict) -> dict[str, str]:
    return {"id": str(item["id"]), "nome": item["nome"]}


def _inteiro(dados: dict, campo: str) -> int | None:
    valor = str(dados.get(campo, "") or "")
    return int(valor) if valor.isdigit() else None


class UnidadesState(rx.State):
    """Unidades geridas, coordenadores ativos e as ações do admin."""

    unidades: list[dict[str, str]] = []
    coordenadores: list[dict[str, str]] = []
    _geridas: list[dict] = []
    _coordenacoes_por_usuario: dict[str, int] = {}
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    # Erro de validação mostrado dentro do diálogo de desativar (padrão da C3)
    erro_dialogo: str = ""

    criar_aberta: bool = False
    criar_modo: str = "ACRESCENTAR"

    editar_aberta: bool = False
    editar_id: str = ""
    editar_nome: str = ""
    editar_endereco: str = ""

    desativar_aberta: bool = False
    desativar_id: str = ""
    desativar_nome: str = ""
    desativar_pendentes: str = "0"
    precisam_destino: list[dict[str, str]] = []
    professores_destino: list[dict[str, str]] = []

    coordenacao_aberta: bool = False
    coordenacao_acao: str = "ACRESCENTAR"

    @rx.var
    def unidades_ativas(self) -> list[dict[str, str]]:
        return [u for u in self.unidades if u["ativa"] == "sim"]

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            geridas = await api.listar_unidades_geridas(token)
            coordenadores = await api.listar_usuarios(
                token, papel="COORDENADOR", status_conta="ATIVA"
            )
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self._geridas = geridas
        self.unidades = [_unidade_para_tela(u) for u in geridas]
        self.coordenadores = [_coordenador_para_tela(c) for c in coordenadores]
        self._coordenacoes_por_usuario = {
            c["id"]: int(c["qtd"]) for c in self.coordenadores
        }

    @rx.event
    def abrir(self):
        self._limpar_mensagens()
        return UnidadesState.carregar

    async def _executar(self, chamada):
        """Executa uma ação, mostra a mensagem da API e recarrega a lista."""
        try:
            resposta = await chamada
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            if redirecionamento is not None:
                return redirecionamento
            return UnidadesState.carregar
        self.mensagem_sucesso = resposta["mensagem"]
        return UnidadesState.carregar

    # ---------- criar ----------

    @rx.event
    def mudar_criar(self, aberta: bool):
        self._limpar_mensagens()
        self.criar_aberta = aberta

    @rx.event
    def escolher_modo(self, modo: str):
        self.criar_modo = modo

    @rx.event
    async def confirmar_criar(self, dados: dict):
        self._limpar_mensagens()
        nome = str(dados.get("nome", "")).strip()
        endereco = str(dados.get("endereco", "")).strip()
        coordenador = _inteiro(dados, "coordenador_id")
        origem = _inteiro(dados, "origem_id")
        if not nome or not endereco or coordenador is None:
            self.mensagem_erro = "Informe nome, endereço e o coordenador."
            return
        if self.criar_modo == "MOVER" and origem is None:
            self.mensagem_erro = "Escolha a unidade de origem do coordenador."
            return
        self.criar_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(
            api.criar_unidade(
                token,
                nome,
                endereco,
                coordenador,
                self.criar_modo,
                origem if self.criar_modo == "MOVER" else None,
            )
        )

    # ---------- editar ----------

    @rx.event
    def abrir_editar(self, unidade: dict):
        self._limpar_mensagens()
        self.editar_id = unidade["id"]
        self.editar_nome = unidade["nome"]
        self.editar_endereco = unidade["endereco"]
        self.editar_aberta = True

    @rx.event
    def mudar_editar(self, aberta: bool):
        self.editar_aberta = aberta

    @rx.event
    async def confirmar_editar(self, dados: dict):
        self._limpar_mensagens()
        nome = str(dados.get("nome", "")).strip()
        endereco = str(dados.get("endereco", "")).strip()
        if not nome or not endereco:
            self.mensagem_erro = "Informe nome e endereço."
            return
        self.editar_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(
            api.editar_unidade(token, int(self.editar_id), nome, endereco)
        )

    # ---------- desativar e reativar ----------

    @rx.event
    def abrir_desativar(self, unidade_id: str):
        self._limpar_mensagens()
        gerida = next(u for u in self._geridas if str(u["id"]) == unidade_id)
        self.desativar_id = unidade_id
        self.desativar_nome = gerida["nome"]
        self.desativar_pendentes = str(gerida.get("pedidos_pendentes") or 0)
        # Só quem coordena apenas esta unidade precisa de destino
        self.precisam_destino = [
            _pessoa(c)
            for c in gerida.get("coordenadores") or []
            if self._coordenacoes_por_usuario.get(str(c["id"]), 0) <= 1
        ]
        self.professores_destino = [
            _pessoa(p) for p in gerida.get("professores") or []
        ]
        self.desativar_aberta = True
        return abrir_dialogo_com_impacto("unidade_id", unidade_id)

    @rx.event
    def mudar_desativar(self, aberta: bool):
        self.desativar_aberta = aberta

    @rx.event
    async def confirmar_desativar(self, dados: dict):
        self._limpar_mensagens()
        destinos_coordenadores = [
            {"usuario_id": int(p["id"]), "unidade_id": _inteiro(dados, f"coord_{p['id']}")}
            for p in self.precisam_destino
        ]
        destinos_professores = [
            {"usuario_id": int(p["id"]), "unidade_id": _inteiro(dados, f"prof_{p['id']}")}
            for p in self.professores_destino
        ]
        faltando = [
            d for d in destinos_coordenadores + destinos_professores
            if d["unidade_id"] is None
        ]
        if faltando:
            self.erro_dialogo = "Escolha uma unidade de destino para cada pessoa."
            return
        codigo, descricao, self.erro_dialogo = ler_motivo(dados)
        if self.erro_dialogo:
            return
        self.desativar_aberta = False
        token = await token_da_sessao(self)
        return await self._executar(
            api.desativar_unidade(
                token,
                int(self.desativar_id),
                destinos_coordenadores,
                destinos_professores,
                codigo,
                descricao,
            )
        )

    @rx.event
    async def reativar(self, unidade_id: str):
        self._limpar_mensagens()
        token = await token_da_sessao(self)
        return await self._executar(api.reativar_unidade(token, int(unidade_id)))

    # ---------- coordenação ----------

    @rx.event
    def abrir_coordenacao(self, acao: str):
        self._limpar_mensagens()
        self.coordenacao_acao = acao
        self.coordenacao_aberta = True

    @rx.event
    def mudar_coordenacao(self, aberta: bool):
        self.coordenacao_aberta = aberta

    @rx.event
    async def confirmar_coordenacao(self, dados: dict):
        self._limpar_mensagens()
        coordenador = _inteiro(dados, "coordenador_id")
        unidade = _inteiro(dados, "unidade_id")
        destino = _inteiro(dados, "destino_id")
        mover = self.coordenacao_acao == "MOVER"
        if coordenador is None or unidade is None or (mover and destino is None):
            self.mensagem_erro = "Preencha todos os campos."
            return
        self.coordenacao_aberta = False
        token = await token_da_sessao(self)
        if mover:
            chamada = api.mover_coordenador(token, coordenador, unidade, destino)
        elif self.coordenacao_acao == "REMOVER":
            chamada = api.remover_coordenador(token, coordenador, unidade)
        else:
            chamada = api.acrescentar_coordenador(token, coordenador, unidade)
        return await self._executar(chamada)
