"""Estado de autenticação do frontend.

O token fica em `_token`, variável só de backend: o Reflex não a envia ao
navegador. O navegador recebe apenas nome, papel e mensagens. As validações
daqui são só de usabilidade; o Xano revalida tudo.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.pedido_state import PedidoState

ROTA_LOGIN = "/login"
ROTA_INICIO = "/inicio"
ROTA_TROCAR_SENHA = "/trocar-senha"
AVISO_SESSAO_EXPIRADA = "Sua sessão expirou. Entre novamente."
# Resposta 403 do Xano para quem ainda tem senha provisória (design.md da C3, D4)
MENSAGEM_TROQUE_SENHA = "Troque sua senha para continuar."

NOMES_PAPEIS = {
    "ALUNO": "Aluno",
    "PROFESSOR": "Professor",
    "COORDENADOR": "Coordenador",
    "ADMIN": "Administrador",
}


class AuthState(rx.State):
    """Sessão do usuário, login, cadastro e logout."""

    _token: str = ""
    nome: str = ""
    papel: str = ""
    admin_principal: bool = False
    senha_provisoria: bool = False
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    aviso: str = ""
    vinculo: str = "ALUNO"
    unidades: list[dict[str, str]] = []

    @rx.var
    def nome_papel(self) -> str:
        return NOMES_PAPEIS.get(self.papel, self.papel)

    @rx.var
    def e_admin(self) -> bool:
        return self.papel == "ADMIN"

    @rx.var
    def e_gestor(self) -> bool:
        """Admin ou coordenador: quem vê a área de aprovações."""
        return self.papel in ("ADMIN", "COORDENADOR")

    @rx.var
    def e_principal(self) -> bool:
        """Admin principal: o único que vê administradores e parâmetros."""
        return self.papel == "ADMIN" and self.admin_principal

    def _guardar_usuario(self, usuario: dict):
        self.nome = usuario["nome"]
        self.papel = usuario["papel"]
        self.admin_principal = bool(usuario.get("admin_principal"))
        self.senha_provisoria = bool(usuario.get("senha_provisoria"))

    def _renovar_token(self, token: str):
        """Troca o token da sessão pelo emitido após a troca de senha."""
        self._token = token
        self.senha_provisoria = False

    def _limpar_sessao(self):
        self._token = ""
        self.nome = ""
        self.papel = ""
        self.admin_principal = False
        self.senha_provisoria = False

    def _sessao_expirada(self):
        self._limpar_sessao()
        self.aviso = AVISO_SESSAO_EXPIRADA
        return rx.redirect(ROTA_LOGIN)

    @rx.event
    async def abrir_formulario(self):
        """Limpa mensagens antigas ao abrir login ou cadastro.

        O aviso de sessão expirada permanece até o próximo login.
        """
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        pedido = await self.get_state(PedidoState)
        pedido._limpar()

    @rx.event
    async def entrar(self, dados: dict):
        email = str(dados.get("email", "")).strip()
        senha = str(dados.get("senha", ""))
        self.mensagem_erro = ""
        pedido = await self.get_state(PedidoState)
        pedido._limpar()
        if not email or not senha:
            self.mensagem_erro = "Informe o e-mail e a senha."
            return

        try:
            sessao = await api.login(email, senha)
        except api.AcessoNegado as erro:
            self.mensagem_erro = erro.mensagem
            # A senha é usada só aqui, para consultar o pedido; não fica no State
            await pedido._carregar_recusa(email, senha)
            return
        except api.ErroApi as erro:
            self.mensagem_erro = erro.mensagem
            return

        self._token = sessao["token"]
        self._guardar_usuario(sessao["usuario"])
        self.aviso = ""
        if self.senha_provisoria:
            return rx.redirect(ROTA_TROCAR_SENHA)
        return rx.redirect(ROTA_INICIO)

    @rx.event
    async def escolher_vinculo(self, vinculo: str):
        self.vinculo = vinculo
        # Recarrega sempre: uma unidade pode ter sido desativada desde a última consulta
        if vinculo in ("PROFESSOR", "COORDENADOR"):
            try:
                unidades = await api.listar_unidades_ativas()
            except api.ErroApi as erro:
                self.mensagem_erro = erro.mensagem
                return
            self.unidades = [
                {"id": str(u["id"]), "nome": u["nome"]} for u in unidades
            ]

    @rx.event
    async def cadastrar(self, dados: dict):
        nome = str(dados.get("nome", "")).strip()
        email = str(dados.get("email", "")).strip()
        senha = str(dados.get("senha", ""))
        confirmacao = str(dados.get("confirmacao_senha", ""))
        unidade = str(dados.get("unidade_vinculo_id", "") or "")
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""

        if not nome or not email or not senha:
            self.mensagem_erro = "Preencha nome, e-mail e senha."
            return
        if senha != confirmacao:
            self.mensagem_erro = "As senhas não conferem."
            return
        pede_unidade = self.vinculo in ("PROFESSOR", "COORDENADOR")
        unidade_id = None
        if pede_unidade and unidade.isdigit():
            unidade_id = int(unidade)

        try:
            resposta = await api.cadastrar(
                nome, email, senha, self.vinculo, unidade_id
            )
        except api.ErroApi as erro:
            self.mensagem_erro = erro.mensagem
            return
        self.mensagem_sucesso = resposta["mensagem"]

    async def _atualizar_sessao(self, permite_senha_provisoria: bool = False):
        """Confere a sessão no Xano e atualiza os dados do usuário.

        Devolve o redirecionamento quando não há sessão válida ou quando a
        senha provisória ainda precisa ser trocada.
        """
        if not self._token:
            return rx.redirect(ROTA_LOGIN)
        try:
            usuario = await api.obter_usuario_atual(self._token)
        except api.NaoAutenticado:
            return self._sessao_expirada()
        except api.ErroApi as erro:
            self.mensagem_erro = erro.mensagem
            return None
        self._guardar_usuario(usuario)
        if self.senha_provisoria and not permite_senha_provisoria:
            return rx.redirect(ROTA_TROCAR_SENHA)
        return None

    @rx.event
    async def verificar_sessao(self):
        """Exige sessão nas páginas protegidas.

        É só usabilidade: a segurança está no Xano.
        """
        return await self._atualizar_sessao()

    @rx.event
    async def verificar_sessao_troca_senha(self):
        """Guarda da página de troca de senha, aberta também com senha provisória."""
        return await self._atualizar_sessao(permite_senha_provisoria=True)

    @rx.event
    async def exigir_gestor(self):
        """Guarda das páginas de admin e coordenador (usabilidade)."""
        redirecionamento = await self._atualizar_sessao()
        if redirecionamento is not None:
            return redirecionamento
        if not self.e_gestor:
            return rx.redirect(ROTA_INICIO)

    @rx.event
    async def exigir_admin(self):
        """Guarda das páginas só de admin (usabilidade)."""
        redirecionamento = await self._atualizar_sessao()
        if redirecionamento is not None:
            return redirecionamento
        if not self.e_admin:
            return rx.redirect(ROTA_INICIO)

    @rx.event
    async def exigir_principal(self):
        """Guarda das páginas só do admin principal (usabilidade)."""
        redirecionamento = await self._atualizar_sessao()
        if redirecionamento is not None:
            return redirecionamento
        if not self.e_principal:
            return rx.redirect(ROTA_INICIO)

    @rx.event
    def sair(self):
        self._limpar_sessao()
        self.aviso = ""
        return rx.redirect(ROTA_LOGIN)


async def token_da_sessao(estado: rx.State) -> str:
    """Token da sessão atual, lido do AuthState no servidor."""
    auth = await estado.get_state(AuthState)
    return auth._token


async def tratar_erro_api(estado: rx.State, erro: api.ErroApi):
    """Tratamento comum dos States de gestão.

    Sessão inválida volta ao login; senha provisória vai para a troca de
    senha; acesso negado volta ao início; os demais erros viram a mensagem
    da página.
    """
    if isinstance(erro, api.NaoAutenticado):
        auth = await estado.get_state(AuthState)
        return auth._sessao_expirada()
    if isinstance(erro, api.AcessoNegado) and erro.mensagem == MENSAGEM_TROQUE_SENHA:
        auth = await estado.get_state(AuthState)
        auth.senha_provisoria = True
        return rx.redirect(ROTA_TROCAR_SENHA)
    estado.mensagem_erro = erro.mensagem
    if isinstance(erro, api.AcessoNegado):
        return rx.redirect(ROTA_INICIO)
    return None
