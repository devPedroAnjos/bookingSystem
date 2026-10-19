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
    404: ErroValidacao,
}

_AUTH = "XANO_API_AUTH_URL"
_UNIDADES = "XANO_API_UNIDADES_URL"
_CONTAS = "XANO_API_CONTAS_URL"


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
    params: dict[str, Any] | None = None,
) -> Any:
    cabecalhos = {"Authorization": f"Bearer {token}"} if token else {}
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT_SEGUNDOS) as cliente:
            resposta = await cliente.request(
                metodo, url, json=dados, params=params, headers=cabecalhos
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
        "POST", _url(_AUTH, "cadastro"), dados=dados
    )


async def login(email: str, senha: str) -> dict[str, Any]:
    """Autentica e devolve o token e os dados básicos do usuário."""
    return await _requisitar(
        "POST",
        _url(_AUTH, "login"),
        dados={"email": email, "senha": senha},
    )


async def obter_usuario_atual(token: str) -> dict[str, Any]:
    """Devolve o usuário do token, se a conta continuar ativa."""
    return await _requisitar(
        "GET", _url(_AUTH, "me"), token=token
    )


async def listar_unidades_ativas() -> list[dict[str, Any]]:
    """Lista pública das unidades ativas (id e nome), ordenada por nome."""
    return await _requisitar("GET", _url(_UNIDADES, "ativas"))


# ---------- Pedido de cadastro (público, com e-mail e senha) ----------


async def consultar_situacao_pedido(email: str, senha: str) -> dict[str, Any]:
    """Situação, motivo e pedidos restantes do próprio pedido de cadastro."""
    return await _requisitar(
        "POST",
        _url(_AUTH, "situacao_pedido"),
        dados={"email": email, "senha": senha},
    )


async def reenviar_pedido(
    email: str,
    senha: str,
    papel: str,
    unidade_id: int,
    justificativa: str = "",
) -> dict[str, Any]:
    """Volta o pedido recusado para análise, com nova unidade e papel."""
    dados = {
        "email": email,
        "senha": senha,
        "papel": papel,
        "unidade_vinculo_id": unidade_id,
        "justificativa": justificativa,
    }
    return await _requisitar("POST", _url(_AUTH, "reenviar_pedido"), dados=dados)


# ---------- Contas: pedidos, decisões, usuários e papéis ----------


async def listar_pedidos(
    token: str, situacao: str = "PENDENTE"
) -> list[dict[str, Any]]:
    """Pedidos de cadastro no escopo do usuário (PENDENTE ou RECUSADA)."""
    return await _requisitar(
        "GET", _url(_CONTAS, "pedidos"), token, params={"situacao": situacao}
    )


async def aprovar_cadastro(
    token: str, usuario_id: int, situacao_esperada: str = "PENDENTE"
) -> dict[str, Any]:
    """Aprova o pedido, se ele ainda estiver na situação que a tela mostrava."""
    dados = {"usuario_id": usuario_id, "situacao_esperada": situacao_esperada}
    return await _requisitar("POST", _url(_CONTAS, "aprovar"), token, dados)


async def recusar_cadastro(
    token: str, usuario_id: int, motivo: str
) -> dict[str, Any]:
    """Recusa um pedido pendente com motivo."""
    dados = {"usuario_id": usuario_id, "motivo": motivo}
    return await _requisitar("POST", _url(_CONTAS, "recusar"), token, dados)


async def listar_usuarios(
    token: str, papel: str = "", status_conta: str = "", busca: str = ""
) -> list[dict[str, Any]]:
    """Usuários com unidade e coordenações (só administrador)."""
    filtros = {"papel": papel, "status_conta": status_conta, "busca": busca}
    params = {chave: valor for chave, valor in filtros.items() if valor}
    return await _requisitar(
        "GET", _url(_CONTAS, "usuarios"), token, params=params
    )


async def alterar_papel(
    token: str,
    usuario_id: int,
    papel: str,
    unidades_ids: list[int] | None = None,
    unidade_id: int | None = None,
) -> dict[str, Any]:
    """Muda o papel; coordenador exige unidades, professor exige unidade."""
    dados: dict[str, Any] = {"usuario_id": usuario_id, "papel": papel}
    if unidades_ids is not None:
        dados["unidades_ids"] = unidades_ids
    if unidade_id is not None:
        dados["unidade_id"] = unidade_id
    return await _requisitar(
        "POST", _url(_CONTAS, "alterar_papel"), token, dados
    )


async def transferir_professor(
    token: str, usuario_id: int, unidade_id: int
) -> dict[str, Any]:
    """Transfere um professor para outra unidade ativa."""
    dados = {"usuario_id": usuario_id, "unidade_id": unidade_id}
    return await _requisitar(
        "POST", _url(_CONTAS, "transferir_professor"), token, dados
    )


# ---------- Unidades e coordenação ----------


async def listar_unidades_geridas(token: str) -> list[dict[str, Any]]:
    """Unidades no escopo do usuário, com coordenadores (e professores)."""
    return await _requisitar("GET", _url(_UNIDADES, "geridas"), token)


async def criar_unidade(
    token: str,
    nome: str,
    endereco: str,
    coordenador_id: int,
    modo: str,
    origem_id: int | None = None,
) -> dict[str, Any]:
    """Cria a unidade movendo ou acrescentando um coordenador."""
    dados: dict[str, Any] = {
        "nome": nome,
        "endereco": endereco,
        "coordenador_id": coordenador_id,
        "modo": modo,
    }
    if origem_id is not None:
        dados["origem_id"] = origem_id
    return await _requisitar("POST", _url(_UNIDADES, "criar"), token, dados)


async def editar_unidade(
    token: str, unidade_id: int, nome: str, endereco: str
) -> dict[str, Any]:
    """Corrige nome e endereço de uma unidade."""
    dados = {"unidade_id": unidade_id, "nome": nome, "endereco": endereco}
    return await _requisitar("POST", _url(_UNIDADES, "editar"), token, dados)


async def desativar_unidade(
    token: str,
    unidade_id: int,
    destinos_coordenadores: list[dict[str, int]],
    destinos_professores: list[dict[str, int]],
) -> dict[str, Any]:
    """Desativa a unidade com os destinos de coordenadores e professores."""
    dados = {
        "unidade_id": unidade_id,
        "destinos_coordenadores": destinos_coordenadores,
        "destinos_professores": destinos_professores,
    }
    return await _requisitar(
        "POST", _url(_UNIDADES, "desativar"), token, dados
    )


async def reativar_unidade(token: str, unidade_id: int) -> dict[str, Any]:
    """Reativa uma unidade desativada."""
    return await _requisitar(
        "POST", _url(_UNIDADES, "reativar"), token, {"unidade_id": unidade_id}
    )


async def acrescentar_coordenador(
    token: str, usuario_id: int, unidade_id: int
) -> dict[str, Any]:
    """Acrescenta uma unidade a um coordenador."""
    dados = {"usuario_id": usuario_id, "unidade_id": unidade_id}
    return await _requisitar(
        "POST", _url(_UNIDADES, "acrescentar_coordenador"), token, dados
    )


async def mover_coordenador(
    token: str, usuario_id: int, origem_id: int, destino_id: int
) -> dict[str, Any]:
    """Move um coordenador da origem para o destino."""
    dados = {
        "usuario_id": usuario_id,
        "origem_id": origem_id,
        "destino_id": destino_id,
    }
    return await _requisitar(
        "POST", _url(_UNIDADES, "mover_coordenador"), token, dados
    )


async def remover_coordenador(
    token: str, usuario_id: int, unidade_id: int
) -> dict[str, Any]:
    """Remove uma das unidades de um coordenador."""
    dados = {"usuario_id": usuario_id, "unidade_id": unidade_id}
    return await _requisitar(
        "POST", _url(_UNIDADES, "remover_coordenador"), token, dados
    )
