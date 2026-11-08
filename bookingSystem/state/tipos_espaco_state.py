"""Estado da página de tipos de espaço (só administrador).

Só usabilidade: nome único, situação e a consistência das regras são
validados no Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.horarios import hhmm_para_minutos, minutos_para_hhmm
from bookingSystem.state.motivos import abrir_dialogo_com_impacto, ler_motivo

# Regras em número inteiro (minutos, dias ou quantidade), como no Xano
REGRAS_NUMERICAS = (
    "duracao_min_minutos",
    "duracao_max_minutos",
    "antecedencia_min_minutos",
    "antecedencia_max_dias",
    "max_reservas_ativas_usuario",
)
# Horários: HH:MM na tela, minutos desde a meia-noite no Xano
REGRAS_HORARIO = ("hora_abertura_minutos", "hora_fechamento_minutos")
REGRAS_SIM_NAO = (
    "permite_recorrencia",
    "aluno_pode_reservar",
    "aluno_exige_aprovacao",
    "professor_pode_reservar",
    "professor_exige_aprovacao",
)


def _tipo_para_tela(tipo: dict) -> dict[str, str]:
    return {
        "id": str(tipo["id"]),
        "nome": tipo["nome"],
        "descricao": tipo.get("descricao") or "",
        "ativo": "sim" if tipo["ativo"] else "nao",
        "com_regras": "sim" if tipo.get("com_regras") else "nao",
        "espacos_ativos": str(tipo.get("espacos_ativos") or 0),
        "unidades": str(tipo.get("unidades") or 0),
    }


def _regras_para_tela(regras: dict) -> dict[str, str]:
    """Valores atuais do diálogo; regra ainda não definida fica vazia."""
    tela = {
        campo: "" if regras.get(campo) is None else str(regras[campo])
        for campo in REGRAS_NUMERICAS
    }
    for campo in REGRAS_HORARIO:
        tela[campo] = minutos_para_hhmm(regras.get(campo))
    return tela


def _regras_do_formulario(dados: dict) -> dict | None:
    """Regras prontas para o Xano, ou None se faltar algo ou o formato for inválido."""
    regras = {}
    for campo in REGRAS_NUMERICAS:
        valor = str(dados.get(campo, "") or "").strip()
        if not valor.isdigit():
            return None
        regras[campo] = int(valor)
    for campo in REGRAS_HORARIO:
        minutos = hhmm_para_minutos(str(dados.get(campo, "") or ""))
        if minutos is None:
            return None
        regras[campo] = minutos
    for campo in REGRAS_SIM_NAO:
        regras[campo] = bool(dados.get(campo))
    return regras


class TiposEspacoState(rx.State):
    """Tipos de espaço e as ações do admin."""

    tipos: list[dict[str, str]] = []
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    # Erro de validação mostrado dentro do diálogo aberto (padrão da C3)
    erro_dialogo: str = ""

    criar_aberta: bool = False

    editar_aberta: bool = False
    editar_id: str = ""
    editar_nome: str = ""
    editar_descricao: str = ""

    desativar_aberta: bool = False
    desativar_id: str = ""
    desativar_nome: str = ""
    desativar_espacos: str = "0"
    desativar_unidades: str = "0"

    regras_aberta: bool = False
    regras_id: str = ""
    regras_nome: str = ""
    regras_valores: dict[str, str] = {}
    regras_marcadas: dict[str, bool] = {}

    _regras_por_id: dict[str, dict] = {}

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            tipos = await api.listar_tipos_espaco(token)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.tipos = [_tipo_para_tela(t) for t in tipos]
        self._regras_por_id = {str(t["id"]): t.get("regras") or {} for t in tipos}

    @rx.event
    def abrir(self):
        self._limpar_mensagens()
        return TiposEspacoState.carregar

    async def _executar(self, chamada):
        """Executa uma ação, mostra a mensagem da API e recarrega a lista."""
        try:
            resposta = await chamada
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            if redirecionamento is not None:
                return redirecionamento
            return TiposEspacoState.carregar
        self.mensagem_sucesso = resposta["mensagem"]
        return TiposEspacoState.carregar

    @rx.event
    def mudar_criar(self, aberta: bool):
        self._limpar_mensagens()
        self.criar_aberta = aberta

    @rx.event
    async def confirmar_criar(self, dados: dict):
        self._limpar_mensagens()
        nome = str(dados.get("nome", "")).strip()
        if not nome:
            self.erro_dialogo = "Informe o nome do tipo de espaço."
            return
        self.criar_aberta = False
        token = await token_da_sessao(self)
        descricao = str(dados.get("descricao", "")).strip()
        return await self._executar(api.criar_tipo_espaco(token, nome, descricao))

    @rx.event
    def abrir_editar(self, tipo: dict):
        self._limpar_mensagens()
        self.editar_id = tipo["id"]
        self.editar_nome = tipo["nome"]
        self.editar_descricao = tipo["descricao"]
        self.editar_aberta = True

    @rx.event
    def mudar_editar(self, aberta: bool):
        self.editar_aberta = aberta

    @rx.event
    async def confirmar_editar(self, dados: dict):
        self._limpar_mensagens()
        nome = str(dados.get("nome", "")).strip()
        if not nome:
            self.erro_dialogo = "Informe o nome do tipo de espaço."
            return
        self.editar_aberta = False
        token = await token_da_sessao(self)
        descricao = str(dados.get("descricao", "")).strip()
        return await self._executar(
            api.editar_tipo_espaco(token, int(self.editar_id), nome, descricao)
        )

    @rx.event
    def abrir_desativar(self, tipo: dict):
        self._limpar_mensagens()
        self.desativar_id = tipo["id"]
        self.desativar_nome = tipo["nome"]
        self.desativar_espacos = tipo["espacos_ativos"]
        self.desativar_unidades = tipo["unidades"]
        self.desativar_aberta = True
        return abrir_dialogo_com_impacto("tipo_espaco_id", tipo["id"])

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
            api.desativar_tipo_espaco(
                token, int(self.desativar_id), codigo, descricao
            )
        )

    @rx.event
    async def reativar(self, tipo_id: str):
        self._limpar_mensagens()
        token = await token_da_sessao(self)
        return await self._executar(api.reativar_tipo_espaco(token, int(tipo_id)))

    # ---------- regras do tipo ----------

    @rx.event
    def abrir_regras(self, tipo: dict):
        self._limpar_mensagens()
        regras = self._regras_por_id.get(tipo["id"], {})
        self.regras_id = tipo["id"]
        self.regras_nome = tipo["nome"]
        self.regras_valores = _regras_para_tela(regras)
        self.regras_marcadas = {
            campo: bool(regras.get(campo)) for campo in REGRAS_SIM_NAO
        }
        self.regras_aberta = True

    @rx.event
    def mudar_regras(self, aberta: bool):
        self.regras_aberta = aberta

    @rx.event
    async def confirmar_regras(self, dados: dict):
        """Mantém o diálogo aberto com o erro do Xano, sem perder o que foi digitado."""
        self._limpar_mensagens()
        regras = _regras_do_formulario(dados)
        if regras is None:
            self.erro_dialogo = (
                "Preencha todas as regras: números inteiros e horários no "
                "formato HH:MM."
            )
            return
        token = await token_da_sessao(self)
        try:
            resposta = await api.definir_regras_tipo(
                token, int(self.regras_id), regras
            )
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            self.erro_dialogo, self.mensagem_erro = self.mensagem_erro, ""
            return redirecionamento
        self.regras_aberta = False
        self.mensagem_sucesso = resposta["mensagem"]
        return TiposEspacoState.carregar
