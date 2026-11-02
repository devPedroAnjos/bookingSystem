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
_ESPACOS = "XANO_API_ESPACOS_URL"


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


async def trocar_senha(
    token: str, senha_atual: str, nova_senha: str
) -> dict[str, Any]:
    """Troca a própria senha. Devolve a mensagem e o token novo.

    Os tokens anteriores da conta deixam de valer.
    """
    dados = {"senha_atual": senha_atual, "nova_senha": nova_senha}
    return await _requisitar("POST", _url(_AUTH, "trocar_senha"), token, dados)


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


# ---------- Contas: senha e situação ----------


async def redefinir_senha(
    token: str, usuario_id: int, senha_provisoria: str
) -> dict[str, Any]:
    """Define uma senha provisória; as sessões do titular caem."""
    dados = {"usuario_id": usuario_id, "senha_provisoria": senha_provisoria}
    return await _requisitar(
        "POST", _url(_CONTAS, "redefinir_senha"), token, dados
    )


async def inativar_conta(
    token: str, usuario_id: int, motivo: str
) -> dict[str, Any]:
    """Inativa uma conta ativa; o motivo fica só na auditoria."""
    dados = {"usuario_id": usuario_id, "motivo": motivo}
    return await _requisitar("POST", _url(_CONTAS, "inativar"), token, dados)


async def reativar_conta(
    token: str,
    usuario_id: int,
    unidades_ids: list[int] | None = None,
    unidade_id: int | None = None,
) -> dict[str, Any]:
    """Reativa uma conta inativa.

    Coordenador sem unidade válida exige unidades; professor com unidade
    desativada exige a nova unidade.
    """
    dados: dict[str, Any] = {"usuario_id": usuario_id}
    if unidades_ids is not None:
        dados["unidades_ids"] = unidades_ids
    if unidade_id is not None:
        dados["unidade_id"] = unidade_id
    return await _requisitar("POST", _url(_CONTAS, "reativar"), token, dados)


# ---------- Contas: administradores e parâmetros (admin principal) ----------


async def listar_admins(token: str) -> list[dict[str, Any]]:
    """Administradores, ativos e inativos, com o principal identificado."""
    return await _requisitar("GET", _url(_CONTAS, "admins"), token)


async def promover_admin(token: str, usuario_id: int) -> dict[str, Any]:
    """Promove um coordenador ativo; as coordenações dele são removidas."""
    return await _requisitar(
        "POST", _url(_CONTAS, "promover_admin"), token, {"usuario_id": usuario_id}
    )


async def criar_admin(
    token: str, nome: str, email: str, senha_provisoria: str
) -> dict[str, Any]:
    """Cria um admin secundário com senha provisória."""
    dados = {"nome": nome, "email": email, "senha_provisoria": senha_provisoria}
    return await _requisitar("POST", _url(_CONTAS, "criar_admin"), token, dados)


async def rebaixar_admin(
    token: str, usuario_id: int, unidades_ids: list[int]
) -> dict[str, Any]:
    """Rebaixa um admin secundário a coordenador das unidades escolhidas."""
    dados = {"usuario_id": usuario_id, "unidades_ids": unidades_ids}
    return await _requisitar(
        "POST", _url(_CONTAS, "rebaixar_admin"), token, dados
    )


async def obter_parametros(token: str) -> dict[str, Any]:
    """Domínios de e-mail e limites atuais."""
    return await _requisitar("GET", _url(_CONTAS, "parametros"), token)


async def salvar_parametros(
    token: str, parametros: dict[str, Any]
) -> dict[str, Any]:
    """Grava todos os parâmetros de uma vez (domínios e limites)."""
    return await _requisitar(
        "POST", _url(_CONTAS, "parametros"), token, parametros
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


# ---------- Tipos de espaço ----------


async def listar_tipos_espaco(token: str) -> list[dict[str, Any]]:
    """Tipos de espaço; para o admin, com espaços ativos e unidades."""
    return await _requisitar("GET", _url(_ESPACOS, "tipos"), token)


async def criar_tipo_espaco(
    token: str, nome: str, descricao: str
) -> dict[str, Any]:
    """Cria um tipo de espaço ativo."""
    dados = {"nome": nome, "descricao": descricao}
    return await _requisitar(
        "POST", _url(_ESPACOS, "criar_tipo"), token, dados
    )


async def editar_tipo_espaco(
    token: str, tipo_espaco_id: int, nome: str, descricao: str
) -> dict[str, Any]:
    """Corrige nome e descrição de um tipo de espaço."""
    dados = {
        "tipo_espaco_id": tipo_espaco_id,
        "nome": nome,
        "descricao": descricao,
    }
    return await _requisitar(
        "POST", _url(_ESPACOS, "editar_tipo"), token, dados
    )


async def desativar_tipo_espaco(
    token: str, tipo_espaco_id: int
) -> dict[str, Any]:
    """Desativa o tipo; os espaços dele deixam de ser reserváveis."""
    return await _requisitar(
        "POST",
        _url(_ESPACOS, "desativar_tipo"),
        token,
        {"tipo_espaco_id": tipo_espaco_id},
    )


async def reativar_tipo_espaco(
    token: str, tipo_espaco_id: int
) -> dict[str, Any]:
    """Reativa um tipo de espaço desativado."""
    return await _requisitar(
        "POST",
        _url(_ESPACOS, "reativar_tipo"),
        token,
        {"tipo_espaco_id": tipo_espaco_id},
    )


# ---------- Catálogo de recursos ----------


async def listar_recursos(token: str) -> list[dict[str, Any]]:
    """Catálogo de recursos; para o admin, com quantos espaços usam cada um."""
    return await _requisitar("GET", _url(_ESPACOS, "recursos"), token)


async def criar_recurso(token: str, nome: str) -> dict[str, Any]:
    """Cria um recurso no catálogo."""
    return await _requisitar(
        "POST", _url(_ESPACOS, "criar_recurso"), token, {"nome": nome}
    )


async def editar_recurso(
    token: str, recurso_id: int, nome: str
) -> dict[str, Any]:
    """Renomeia um recurso; vale para todos os espaços que o têm."""
    dados = {"recurso_id": recurso_id, "nome": nome}
    return await _requisitar(
        "POST", _url(_ESPACOS, "editar_recurso"), token, dados
    )


async def excluir_recurso(token: str, recurso_id: int) -> dict[str, Any]:
    """Exclui um recurso que nenhum espaço usa."""
    return await _requisitar(
        "POST",
        _url(_ESPACOS, "excluir_recurso"),
        token,
        {"recurso_id": recurso_id},
    )


# ---------- Espaços ----------


async def listar_espacos_geridos(token: str) -> list[dict[str, Any]]:
    """Espaços no escopo do usuário, com recursos e disponibilidade."""
    return await _requisitar("GET", _url(_ESPACOS, "geridos"), token)


async def criar_espaco(token: str, dados: dict[str, Any]) -> dict[str, Any]:
    """Cria um espaço ativo e sem recursos.

    `dados`: unidade_id, tipo_espaco_id, nome, codigo, capacidade,
    localizacao e descricao.
    """
    return await _requisitar(
        "POST", _url(_ESPACOS, "criar_espaco"), token, dados
    )


async def editar_espaco(token: str, dados: dict[str, Any]) -> dict[str, Any]:
    """Edita um espaço; não muda unidade nem situação.

    `dados`: espaco_id, tipo_espaco_id, nome, codigo, capacidade,
    localizacao e descricao.
    """
    return await _requisitar(
        "POST", _url(_ESPACOS, "editar_espaco"), token, dados
    )


async def definir_recursos_espaco(
    token: str, espaco_id: int, recursos: list[dict[str, int]]
) -> dict[str, Any]:
    """Substitui a lista de recursos (recurso_id e quantidade) do espaço."""
    dados = {"espaco_id": espaco_id, "recursos": recursos}
    return await _requisitar(
        "POST", _url(_ESPACOS, "definir_recursos"), token, dados
    )


async def desativar_espaco(token: str, espaco_id: int) -> dict[str, Any]:
    """Desativa um espaço ativo."""
    return await _requisitar(
        "POST",
        _url(_ESPACOS, "desativar_espaco"),
        token,
        {"espaco_id": espaco_id},
    )


async def reativar_espaco(token: str, espaco_id: int) -> dict[str, Any]:
    """Reativa um espaço desativado."""
    return await _requisitar(
        "POST",
        _url(_ESPACOS, "reativar_espaco"),
        token,
        {"espaco_id": espaco_id},
    )


async def mover_espaco(
    token: str, espaco_id: int, unidade_id: int
) -> dict[str, Any]:
    """Move o espaço para outra unidade ativa (só admin)."""
    dados = {"espaco_id": espaco_id, "unidade_id": unidade_id}
    return await _requisitar(
        "POST", _url(_ESPACOS, "mover_espaco"), token, dados
    )


# ---------- Regras do tipo e busca ----------


async def definir_regras_tipo(
    token: str, tipo_espaco_id: int, regras: dict[str, Any]
) -> dict[str, Any]:
    """Grava as regras de uso do tipo e a regra de aluno e professor.

    `regras`: os oito campos de regra (minutos e dias) e
    aluno/professor_pode_reservar e aluno/professor_exige_aprovacao.
    """
    dados = {"tipo_espaco_id": tipo_espaco_id, **regras}
    return await _requisitar(
        "POST", _url(_ESPACOS, "definir_regras_tipo"), token, dados
    )


async def filtros_busca(token: str) -> dict[str, Any]:
    """Tipos que o papel pode reservar e o catálogo de recursos."""
    return await _requisitar("GET", _url(_ESPACOS, "filtros_busca"), token)


async def buscar_espacos(
    token: str, filtros: dict[str, Any]
) -> list[dict[str, Any]]:
    """Espaços reserváveis pelo usuário, com os filtros informados.

    Com data (AAAA-MM-DD) e horas (HH:MM), cada espaço diz se o pedido
    está dentro das regras do tipo; a ocupação não é verificada.
    """
    return await _requisitar(
        "POST", _url(_ESPACOS, "buscar_espacos"), token, filtros
    )
