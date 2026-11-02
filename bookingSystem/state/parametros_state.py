"""Estado da página de parâmetros (só o admin principal).

Só usabilidade: o Xano normaliza os domínios e valida os limites.
"""

import re

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import token_da_sessao, tratar_erro_api

LIMITES = (
    "max_pedidos_cadastro",
    "max_coordenadores_unidade",
    "max_unidades_coordenador",
    "max_admins",
    "granularidade_minutos",
)

# Dias de funcionamento em ISO: 1 = segunda a 7 = domingo
DIAS_SEMANA = ("1", "2", "3", "4", "5", "6", "7")


class ParametrosState(rx.State):
    """Domínios de e-mail aceitos e limites do sistema."""

    dominios: str = ""
    limites: dict[str, str] = {}
    dias: dict[str, bool] = {}
    # Muda a cada carga para recriar o formulário com os valores atuais
    versao: int = 0
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""

    @rx.event
    async def carregar(self):
        token = await token_da_sessao(self)
        try:
            parametros = await api.obter_parametros(token)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.dominios = ", ".join(parametros["dominios_email"])
        self.limites = {
            campo: str(parametros.get(campo) or "") for campo in LIMITES
        }
        marcados = {str(dia) for dia in parametros.get("dias_funcionamento") or []}
        self.dias = {dia: dia in marcados for dia in DIAS_SEMANA}
        self.versao += 1

    @rx.event
    def abrir(self):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        return ParametrosState.carregar

    @rx.event
    async def salvar(self, dados: dict):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        texto = str(dados.get("dominios", ""))
        dominios = [d.strip() for d in re.split(r"[,\n]", texto) if d.strip()]
        valores = {campo: str(dados.get(campo, "")).strip() for campo in LIMITES}
        if not all(valor.isdigit() for valor in valores.values()):
            self.mensagem_erro = "Os limites devem ser números inteiros a partir de 1."
            return
        parametros = {campo: int(valor) for campo, valor in valores.items()}
        parametros["dominios_email"] = dominios
        parametros["dias_funcionamento"] = [
            int(dia) for dia in DIAS_SEMANA if dados.get("dia_" + dia)
        ]
        token = await token_da_sessao(self)
        try:
            resposta = await api.salvar_parametros(token, parametros)
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.mensagem_sucesso = resposta["mensagem"]
        return ParametrosState.carregar
