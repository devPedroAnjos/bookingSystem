"""Estado de autenticação do frontend.

O token fica em `_token`, variável só de backend: o Reflex não a envia ao
navegador. O navegador recebe apenas nome, papel e mensagens. As validações
daqui são só de usabilidade; o Xano revalida tudo.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api

ROTA_LOGIN = "/login"
ROTA_INICIO = "/inicio"
AVISO_SESSAO_EXPIRADA = "Sua sessão expirou. Entre novamente."

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
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""
    aviso: str = ""
    vinculo: str = "ALUNO"
    unidades: list[dict[str, str]] = []

    @rx.var
    def nome_papel(self) -> str:
        return NOMES_PAPEIS.get(self.papel, self.papel)

    def _limpar_sessao(self):
        self._token = ""
        self.nome = ""
        self.papel = ""

    def _sessao_expirada(self):
        self._limpar_sessao()
        self.aviso = AVISO_SESSAO_EXPIRADA
        return rx.redirect(ROTA_LOGIN)

    @rx.event
    def abrir_formulario(self):
        """Limpa mensagens antigas ao abrir login ou cadastro.

        O aviso de sessão expirada permanece até o próximo login.
        """
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""

    @rx.event
    async def entrar(self, dados: dict):
        email = str(dados.get("email", "")).strip()
        senha = str(dados.get("senha", ""))
        self.mensagem_erro = ""
        if not email or not senha:
            self.mensagem_erro = "Informe o e-mail e a senha."
            return

        try:
            sessao = await api.login(email, senha)
        except api.ErroApi as erro:
            self.mensagem_erro = erro.mensagem
            return

        self._token = sessao["token"]
        self.nome = sessao["usuario"]["nome"]
        self.papel = sessao["usuario"]["papel"]
        self.aviso = ""
        return rx.redirect(ROTA_INICIO)

    @rx.event
    async def escolher_vinculo(self, vinculo: str):
        self.vinculo = vinculo
        if vinculo == "PROFESSOR" and not self.unidades:
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
        e_professor = self.vinculo == "PROFESSOR"
        unidade_id = None
        if e_professor and unidade.isdigit():
            unidade_id = int(unidade)

        try:
            resposta = await api.cadastrar(
                nome, email, senha, self.vinculo, unidade_id
            )
        except api.ErroApi as erro:
            self.mensagem_erro = erro.mensagem
            return
        self.mensagem_sucesso = resposta["mensagem"]

    @rx.event
    async def verificar_sessao(self):
        """Exige sessão nas páginas protegidas.

        É só usabilidade: a segurança está no Xano.
        """
        if not self._token:
            return rx.redirect(ROTA_LOGIN)
        try:
            usuario = await api.obter_usuario_atual(self._token)
        except api.NaoAutenticado:
            return self._sessao_expirada()
        except api.ErroApi as erro:
            self.mensagem_erro = erro.mensagem
            return
        self.nome = usuario["nome"]
        self.papel = usuario["papel"]

    @rx.event
    def sair(self):
        self._limpar_sessao()
        self.aviso = ""
        return rx.redirect(ROTA_LOGIN)
