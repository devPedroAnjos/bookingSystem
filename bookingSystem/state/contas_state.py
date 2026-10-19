"""Estado das páginas de aprovações e de usuários.

Só usabilidade: quem decide papel, escopo, limites e corrida é o Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import (
    NOMES_PAPEIS,
    AuthState,
    token_da_sessao,
    tratar_erro_api,
)

# Mudanças de papel permitidas (spec papeis): ninguém volta a ser aluno
PROXIMOS_PAPEIS = {
    "ALUNO": ["PROFESSOR"],
    "PROFESSOR": ["COORDENADOR"],
    "COORDENADOR": ["PROFESSOR"],
}

NOMES_SITUACOES = {
    "PENDENTE": "Pendente",
    "ATIVA": "Ativa",
    "RECUSADA": "Recusada",
    "INATIVA": "Inativa",
}


def _pedido_para_tela(pedido: dict) -> dict[str, str]:
    return {
        "id": str(pedido["id"]),
        "nome": pedido["nome"],
        "email": pedido["email"],
        "papel": NOMES_PAPEIS.get(pedido["papel"], pedido["papel"]),
        "unidade": pedido.get("unidade_nome") or "",
        "pedido": str(pedido.get("pedidos_cadastro") or 1),
        "justificativa": pedido.get("justificativa_cadastro") or "",
        "motivo": pedido.get("motivo_recusa_cadastro") or "",
    }


def _usuario_para_tela(usuario: dict) -> dict[str, str]:
    coordena = [c["nome"] for c in usuario.get("coordenacoes") or []]
    return {
        "id": str(usuario["id"]),
        "nome": usuario["nome"],
        "email": usuario["email"],
        "papel": usuario["papel"],
        "papel_nome": NOMES_PAPEIS.get(usuario["papel"], usuario["papel"]),
        "situacao": NOMES_SITUACOES.get(
            usuario["status_conta"], usuario["status_conta"]
        ),
        "ativa": "sim" if usuario["status_conta"] == "ATIVA" else "nao",
        "unidade": usuario.get("unidade_nome") or "",
        "coordena": ", ".join(coordena),
    }


class ContasState(rx.State):
    """Pedidos de cadastro, decisões, usuários, papéis e transferência."""

    pedidos: list[dict[str, str]] = []
    recusadas: list[dict[str, str]] = []
    usuarios: list[dict[str, str]] = []
    unidades_ativas: list[dict[str, str]] = []
    filtro_papel: str = ""
    filtro_situacao: str = ""
    filtro_busca: str = ""
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""

    # Diálogo de recusa
    recusa_aberta: bool = False
    recusa_id: str = ""
    recusa_nome: str = ""

    # Diálogo de mudança de papel
    papel_aberto: bool = False
    papel_alvo_id: str = ""
    papel_alvo_nome: str = ""
    papel_atual: str = ""
    papel_novo: str = ""
    perdas: str = ""

    # Diálogo de transferência
    transferencia_aberta: bool = False
    transferencia_id: str = ""
    transferencia_nome: str = ""

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""

    async def _carregar_unidades_ativas(self):
        unidades = await api.listar_unidades_ativas()
        self.unidades_ativas = [
            {"id": str(u["id"]), "nome": u["nome"]} for u in unidades
        ]

    # ---------- aprovações ----------

    @rx.event
    async def carregar_aprovacoes(self):
        token = await token_da_sessao(self)
        auth = await self.get_state(AuthState)
        try:
            pedidos = await api.listar_pedidos(token)
            recusadas = (
                await api.listar_pedidos(token, "RECUSADA")
                if auth.e_admin
                else []
            )
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.pedidos = [_pedido_para_tela(p) for p in pedidos]
        self.recusadas = [_pedido_para_tela(p) for p in recusadas]

    @rx.event
    async def abrir_aprovacoes(self):
        self._limpar_mensagens()
        return ContasState.carregar_aprovacoes

    @rx.event
    async def aprovar(self, usuario_id: str, situacao: str):
        self._limpar_mensagens()
        token = await token_da_sessao(self)
        try:
            resposta = await api.aprovar_cadastro(
                token, int(usuario_id), situacao
            )
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            if redirecionamento is not None:
                return redirecionamento
            return ContasState.carregar_aprovacoes
        self.mensagem_sucesso = resposta["mensagem"]
        return ContasState.carregar_aprovacoes

    @rx.event
    def abrir_recusa(self, usuario_id: str, nome: str):
        self.recusa_id = usuario_id
        self.recusa_nome = nome
        self.recusa_aberta = True

    @rx.event
    def mudar_recusa(self, aberta: bool):
        self.recusa_aberta = aberta

    @rx.event
    async def confirmar_recusa(self, dados: dict):
        motivo = str(dados.get("motivo", "")).strip()
        self._limpar_mensagens()
        if not motivo:
            self.mensagem_erro = "Informe o motivo da recusa."
            return
        self.recusa_aberta = False
        token = await token_da_sessao(self)
        try:
            resposta = await api.recusar_cadastro(
                token, int(self.recusa_id), motivo
            )
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            if redirecionamento is not None:
                return redirecionamento
            return ContasState.carregar_aprovacoes
        self.mensagem_sucesso = resposta["mensagem"]
        return ContasState.carregar_aprovacoes

    # ---------- usuários ----------

    @rx.event
    async def carregar_usuarios(self):
        token = await token_da_sessao(self)
        try:
            usuarios = await api.listar_usuarios(
                token, self.filtro_papel, self.filtro_situacao, self.filtro_busca
            )
            await self._carregar_unidades_ativas()
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.usuarios = [_usuario_para_tela(u) for u in usuarios]

    @rx.event
    async def abrir_usuarios(self):
        self._limpar_mensagens()
        return ContasState.carregar_usuarios

    @rx.event
    def filtrar(self, dados: dict):
        self.filtro_papel = str(dados.get("papel", "") or "")
        self.filtro_situacao = str(dados.get("situacao", "") or "")
        self.filtro_busca = str(dados.get("busca", "")).strip()
        return ContasState.carregar_usuarios

    @rx.event
    def abrir_papel(self, usuario: dict):
        self._limpar_mensagens()
        self.papel_alvo_id = usuario["id"]
        self.papel_alvo_nome = usuario["nome"]
        self.papel_atual = usuario["papel"]
        proximos = PROXIMOS_PAPEIS.get(usuario["papel"], [])
        self.papel_novo = proximos[0] if proximos else ""
        # Aviso de perda de coordenação (spec papeis)
        self.perdas = usuario["coordena"] if usuario["papel"] == "COORDENADOR" else ""
        self.papel_aberto = True

    @rx.event
    def mudar_papel_dialogo(self, aberto: bool):
        self.papel_aberto = aberto

    @rx.event
    async def confirmar_papel(self, dados: dict):
        self._limpar_mensagens()
        if self.papel_novo == "COORDENADOR":
            escolhidas = {
                str(dados.get(campo, "") or "")
                for campo in ("unidade1", "unidade2")
            }
            unidades_ids = sorted(int(u) for u in escolhidas if u.isdigit())
            if not unidades_ids:
                self.mensagem_erro = "Escolha ao menos uma unidade."
                return
            argumentos = {"unidades_ids": unidades_ids}
        else:
            unidade = str(dados.get("unidade1", "") or "")
            if not unidade.isdigit():
                self.mensagem_erro = "Escolha a unidade do professor."
                return
            argumentos = {"unidade_id": int(unidade)}
        self.papel_aberto = False
        token = await token_da_sessao(self)
        try:
            resposta = await api.alterar_papel(
                token, int(self.papel_alvo_id), self.papel_novo, **argumentos
            )
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        removidas = [c["nome"] for c in resposta.get("coordenacoes_removidas", [])]
        self.mensagem_sucesso = resposta["mensagem"]
        if removidas:
            self.mensagem_sucesso += (
                " Deixou de coordenar: " + ", ".join(removidas) + "."
            )
        return ContasState.carregar_usuarios

    @rx.event
    def abrir_transferencia(self, usuario_id: str, nome: str):
        self._limpar_mensagens()
        self.transferencia_id = usuario_id
        self.transferencia_nome = nome
        self.transferencia_aberta = True

    @rx.event
    def mudar_transferencia(self, aberta: bool):
        self.transferencia_aberta = aberta

    @rx.event
    async def confirmar_transferencia(self, dados: dict):
        self._limpar_mensagens()
        unidade = str(dados.get("unidade_id", "") or "")
        if not unidade.isdigit():
            self.mensagem_erro = "Escolha a unidade de destino."
            return
        self.transferencia_aberta = False
        token = await token_da_sessao(self)
        try:
            resposta = await api.transferir_professor(
                token, int(self.transferencia_id), int(unidade)
            )
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.mensagem_sucesso = resposta["mensagem"]
        return ContasState.carregar_usuarios
