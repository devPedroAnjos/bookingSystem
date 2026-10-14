"""Cliente único da API do Xano.

Nenhum outro módulo do frontend faz chamadas HTTP ao backend. As URLs
base de cada grupo de API vêm de variáveis de ambiente. Token e senha
nunca são registrados em log.
"""

import os
from typing import Any

import httpx

_TIMEOUT_SEGUNDOS = 15.0
_MENSAGEM_PADRAO = "Não foi possível falar com o servidor. Tente novamente."
_MENSAGEM_LIMITE = (
    "Muitas tentativas em pouco tempo. "
    "Aguarde alguns segundos e tente novamente."
)


class ErroApi(Exception):
    """Falha sem tratamento específico (servidor, rede ou limite de uso)."""

    def __init__(self, mensagem: str = _MENSAGEM_PADRAO):
        super().__init__(mensagem)
        self.mensagem = mensagem


class ErroValidacao(ErroApi):
    """A API recusou os dados enviados (HTTP 400)."""


class NaoAutenticado(ErroApi):
    """Credenciais inválidas ou token ausente, inválido ou expirado (401)."""


class AcessoNegado(ErroApi):
    """A conta existe, mas o acesso não está liberado (HTTP 403)."""


_ERROS_POR_STATUS = {
    400: ErroValidacao,
    401: NaoAutenticado,
    403: AcessoNegado,
}


def _url(variavel: str, rota: str) -> str:
    base = os.environ.get(variavel, "").rstrip("/")
    if not base:
        raise ErroApi(_MENSAGEM_PADRAO)
    return f"{base}/{rota}"


def _mensagem_da_resposta(resposta: httpx.Response) -> str:
    try:
        mensagem = resposta.json().get("message")
    except ValueError:
        mensagem = None
    return mensagem or _MENSAGEM_PADRAO


async def _requisitar(
    metodo: str,
    url: str,
    token: str | None = None,
    dados: dict[str, Any] | None = None,
) -> Any:
    cabecalhos = {"Authorization": f"Bearer {token}"} if token else {}
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT_SEGUNDOS) as cliente:
            resposta = await cliente.request(
                metodo, url, json=dados, headers=cabecalhos
            )
    except httpx.HTTPError as erro:
        raise ErroApi() from erro

    if resposta.status_code < 400:
        return resposta.json()
    if resposta.status_code == 429:
        raise ErroApi(_MENSAGEM_LIMITE)

    excecao = _ERROS_POR_STATUS.get(resposta.status_code)
    if excecao is None:
        raise ErroApi()
    raise excecao(_mensagem_da_resposta(resposta))


async def cadastrar(
    nome: str,
    email: str,
    senha: str,
    vinculo: str,
    unidade_vinculo_id: int | None = None,
) -> dict[str, Any]:
    """Cria a conta. Devolve a mensagem e a situação da conta (sem token)."""
    dados = {"nome": nome, "email": email, "senha": senha, "vinculo": vinculo}
    if unidade_vinculo_id is not None:
        dados["unidade_vinculo_id"] = unidade_vinculo_id
    return await _requisitar(
        "POST", _url("XANO_API_AUTH_URL", "cadastro"), dados=dados
    )


async def login(email: str, senha: str) -> dict[str, Any]:
    """Autentica e devolve o token e os dados básicos do usuário."""
    return await _requisitar(
        "POST",
        _url("XANO_API_AUTH_URL", "login"),
        dados={"email": email, "senha": senha},
    )


async def obter_usuario_atual(token: str) -> dict[str, Any]:
    """Devolve o usuário do token, se a conta continuar ativa."""
    return await _requisitar(
        "GET", _url("XANO_API_AUTH_URL", "me"), token=token
    )


async def listar_unidades_ativas() -> list[dict[str, Any]]:
    """Lista pública das unidades ativas (id e nome), ordenada por nome."""
    return await _requisitar("GET", _url("XANO_API_UNIDADES_URL", "ativas"))
