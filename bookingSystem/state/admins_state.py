"""Estado da página de administradores (só o admin principal).

Só usabilidade: limite de admins, vagas nas unidades e permissões são do Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.acoes_conta import (
    AcoesContaMixin,
    erro_senha_provisoria,
    sim_nao,
    unidades_escolhidas,
)
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api


def _admin_para_tela(admin: dict) -> dict[str, str]:
    ativa = admin["status_conta"] == "ATIVA"
    return {
        "id": str(admin["id"]),
        "nome": admin["nome"],
        "email": admin["email"],
        "papel": "ADMIN",
        "situacao": "Ativa" if ativa else "Inativa",
        "ativa": sim_nao(ativa),
        "principal": sim_nao(admin.get("admin_principal")),
        "senha_provisoria": sim_nao(admin.get("senha_provisoria")),
        # Campos usados pela reativação (um admin não tem unidades)
        "unidade_id": "",
        "coordena_ids": "",
    }


class AdminsState(AcoesContaMixin, rx.State):
    """Admins, promoção de coordenador, criação e rebaixamento."""

    admins: list[dict[str, str]] = []
    coordenadores: list[dict[str, str]] = []
    admins_ativos: int = 0
    max_admins: int = 0

    criacao_aberta: bool = False
    promocao_aberta: bool = False
    rebaixamento_aberto: bool = False

    def _recarregar(self):
        return AdminsState.carregar

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            admins = await api.listar_admins(token)
            coordenadores = await api.listar_usuarios(
                token, papel="COORDENADOR", status_conta="ATIVA"
            )
            parametros = await api.obter_parametros(token)
            await self._carregar_unidades_ativas()
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.admins = [_admin_para_tela(a) for a in admins]
        self.admins_ativos = sum(1 for a in admins if a["status_conta"] == "ATIVA")
        self.max_admins = parametros["max_admins"]
        self.coordenadores = [
            {"id": str(c["id"]), "nome": f"{c['nome']} ({c['email']})"}
            for c in coordenadores
        ]

    @rx.event
    def abrir(self):
        self._limpar_mensagens()
        return AdminsState.carregar

    # ---------- criação ----------

    @rx.event
    def abrir_criacao(self):
        self._limpar_mensagens()
        self.criacao_aberta = True

    @rx.event
    def mudar_criacao(self, aberta: bool):
        self.criacao_aberta = aberta

    @rx.event
    async def confirmar_criacao(self, dados: dict):
        nome = str(dados.get("nome", "")).strip()
        email = str(dados.get("email", "")).strip()
        if not nome or not email:
            self.erro_dialogo = "Informe o nome e o e-mail."
            return
        self.erro_dialogo = erro_senha_provisoria(dados)
        if self.erro_dialogo:
            return
        senha = str(dados["senha_provisoria"])
        self.criacao_aberta = False
        return await self._enviar(
            lambda token: api.criar_admin(token, nome, email, senha)
        )

    # ---------- promoção ----------

    @rx.event
    def abrir_promocao(self):
        self._limpar_mensagens()
        self.promocao_aberta = True

    @rx.event
    def mudar_promocao(self, aberta: bool):
        self.promocao_aberta = aberta

    @rx.event
    async def confirmar_promocao(self, dados: dict):
        coordenador = str(dados.get("coordenador_id", "") or "")
        if not coordenador.isdigit():
            self.erro_dialogo = "Escolha o coordenador."
            return
        self.promocao_aberta = False
        return await self._enviar(
            lambda token: api.promover_admin(token, int(coordenador))
        )

    # ---------- rebaixamento ----------

    @rx.event
    def abrir_rebaixamento(self, conta: dict):
        self._escolher_alvo(conta)
        self.rebaixamento_aberto = True

    @rx.event
    def mudar_rebaixamento(self, aberto: bool):
        self.rebaixamento_aberto = aberto

    @rx.event
    async def confirmar_rebaixamento(self, dados: dict):
        unidades_ids = unidades_escolhidas(dados)
        if not unidades_ids:
            self.erro_dialogo = "Escolha ao menos uma unidade para coordenar."
            return
        self.rebaixamento_aberto = False
        alvo = int(self.alvo_id)
        return await self._enviar(
            lambda token: api.rebaixar_admin(token, alvo, unidades_ids)
        )
