"""Ações sobre a situação e a senha de uma conta, comuns a duas páginas.

`AcoesContaMixin` dá a `ContasState` (usuários) e a `AdminsState`
(administradores) os mesmos diálogos de inativar, reativar e redefinir senha.
Cada State tem as próprias mensagens e diz, em `_recarregar`, qual lista
atualizar. Só usabilidade: permissões, limites e vagas são do Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api
from bookingSystem.state.motivos import abrir_dialogo_com_impacto, ler_motivo
from bookingSystem.state.senha_state import TAMANHO_MINIMO_SENHA


def sim_nao(valor) -> str:
    return "sim" if valor else "nao"


def unidades_escolhidas(dados: dict) -> list[int]:
    """Ids dos seletores `unidade1` e `unidade2`, sem repetição."""
    escolhidas = {
        str(dados.get(campo, "") or "") for campo in ("unidade1", "unidade2")
    }
    return sorted(int(u) for u in escolhidas if u.isdigit())


def erro_senha_provisoria(dados: dict) -> str:
    """Confere `senha_provisoria` e `confirmacao`; devolve "" quando está ok."""
    senha = str(dados.get("senha_provisoria", ""))
    if len(senha) < TAMANHO_MINIMO_SENHA:
        return "A senha provisória deve ter pelo menos 8 caracteres."
    if senha != str(dados.get("confirmacao", "")):
        return "A confirmação não confere com a senha provisória."
    return ""


def _precisa_escolher_unidades(conta: dict, ativas: set[str]) -> bool:
    """Prevê se a reativação vai exigir unidades (a API confirma ao enviar)."""
    if conta["papel"] == "PROFESSOR":
        return conta["unidade_id"] not in ativas
    if conta["papel"] == "COORDENADOR":
        coordenadas = set(filter(None, conta["coordena_ids"].split(",")))
        return not coordenadas & ativas
    return False


class AcoesContaMixin(rx.State, mixin=True):
    """Diálogos de inativação, reativação e redefinição de senha."""

    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    erro_dialogo: str = ""
    unidades_ativas: list[dict[str, str]] = []

    alvo_id: str = ""
    alvo_nome: str = ""
    alvo_papel: str = ""
    inativacao_aberta: bool = False
    reativacao_aberta: bool = False
    reativacao_pede_unidades: bool = False
    redefinicao_aberta: bool = False

    def _limpar_mensagens(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""

    def _recarregar(self):
        """Evento que atualiza a lista da página depois de uma ação."""
        raise NotImplementedError

    async def _carregar_unidades_ativas(self):
        unidades = await api.listar_unidades_ativas()
        self.unidades_ativas = [
            {"id": str(u["id"]), "nome": u["nome"]} for u in unidades
        ]

    def _escolher_alvo(self, conta: dict):
        self._limpar_mensagens()
        self.alvo_id = conta["id"]
        self.alvo_nome = conta["nome"]
        self.alvo_papel = conta["papel"]

    async def _enviar(self, chamada):
        """Envia a ação ao Xano, mostra a resposta e recarrega a lista."""
        token = await token_da_sessao(self)
        try:
            resposta = await chamada(token)
        except api.ErroApi as erro:
            redirecionamento = await tratar_erro_api(self, erro)
            return redirecionamento or self._recarregar()
        return self._mostrar_resposta(resposta)

    def _mostrar_resposta(self, resposta: dict):
        self.mensagem_sucesso = resposta["mensagem"]
        for chave, texto in (
            ("coordenacoes_removidas", " Deixou de coordenar: "),
            (
                "coordenacoes_descartadas",
                " Não voltou a coordenar (unidade desativada ou sem vaga): ",
            ),
        ):
            nomes = [c["nome"] for c in resposta.get(chave) or []]
            if nomes:
                self.mensagem_sucesso += texto + ", ".join(nomes) + "."
        return self._recarregar()

    # ---------- inativação ----------

    @rx.event
    def abrir_inativacao(self, conta: dict):
        self._escolher_alvo(conta)
        self.inativacao_aberta = True
        return abrir_dialogo_com_impacto("usuario_id", conta["id"])

    @rx.event
    def mudar_inativacao(self, aberta: bool):
        self.inativacao_aberta = aberta

    @rx.event
    async def confirmar_inativacao(self, dados: dict):
        codigo, descricao, self.erro_dialogo = ler_motivo(dados)
        if self.erro_dialogo:
            return
        self.inativacao_aberta = False
        alvo = int(self.alvo_id)
        return await self._enviar(
            lambda token: api.inativar_conta(token, alvo, codigo, descricao)
        )

    # ---------- reativação ----------

    @rx.event
    def abrir_reativacao(self, conta: dict):
        self._escolher_alvo(conta)
        ativas = {u["id"] for u in self.unidades_ativas}
        self.reativacao_pede_unidades = _precisa_escolher_unidades(conta, ativas)
        self.reativacao_aberta = True

    @rx.event
    def mudar_reativacao(self, aberta: bool):
        self.reativacao_aberta = aberta

    @rx.event
    async def confirmar_reativacao(self, dados: dict):
        argumentos: dict = {}
        if self.reativacao_pede_unidades:
            escolhidas = unidades_escolhidas(dados)
            if not escolhidas:
                self.erro_dialogo = "Escolha a unidade antes de reativar."
                return
            if self.alvo_papel == "COORDENADOR":
                argumentos["unidades_ids"] = escolhidas
            else:
                argumentos["unidade_id"] = escolhidas[0]
        token = await token_da_sessao(self)
        try:
            resposta = await api.reativar_conta(
                token, int(self.alvo_id), **argumentos
            )
        except api.ErroValidacao as erro:
            # Ex.: coordenador sem vaga nas unidades antigas; a API pede unidades
            if self.alvo_papel in ("COORDENADOR", "PROFESSOR"):
                self.reativacao_pede_unidades = True
                self.erro_dialogo = erro.mensagem
                return
            self.reativacao_aberta = False
            return await tratar_erro_api(self, erro)
        except api.ErroApi as erro:
            self.reativacao_aberta = False
            return await tratar_erro_api(self, erro)
        self.reativacao_aberta = False
        return self._mostrar_resposta(resposta)

    # ---------- redefinição de senha ----------

    @rx.event
    def abrir_redefinicao(self, conta: dict):
        self._escolher_alvo(conta)
        self.redefinicao_aberta = True

    @rx.event
    def mudar_redefinicao(self, aberta: bool):
        self.redefinicao_aberta = aberta

    @rx.event
    async def confirmar_redefinicao(self, dados: dict):
        self.erro_dialogo = erro_senha_provisoria(dados)
        if self.erro_dialogo:
            return
        senha = str(dados["senha_provisoria"])
        self.redefinicao_aberta = False
        alvo = int(self.alvo_id)
        return await self._enviar(
            lambda token: api.redefinir_senha(token, alvo, senha)
        )
