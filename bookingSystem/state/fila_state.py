"""Estado da fila de espera do usuário (C9, design D10).

Só usabilidade: a lista, a situação efetiva, a posição e o prazo vêm do Xano
(`minha_fila`), que também faz a fila andar quando há vencimento a gravar.
`carregar` roda no on_load de todas as páginas autenticadas, depois da guarda,
para o aviso de vaga retida no topo; em "Minhas reservas", alimenta também a
seção "Fila de espera". Confirmar e desistir são revalidados no Xano.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import AuthState, tratar_erro_api
from bookingSystem.state.motivos import SITUACOES_FILA
from bookingSystem.state.reservas_state import ReservasState

CONFIRMAR = "confirmar"
DESISTIR = "desistir"


def _data_br(data: str) -> str:
    ano, mes, dia = data.split("-")
    return f"{dia}/{mes}/{ano}"


def _entrada_para_tela(entrada: dict) -> dict[str, str]:
    prazo = ""
    if entrada.get("prazo_data") and entrada.get("prazo_hora"):
        prazo = f"{_data_br(entrada['prazo_data'])} às {entrada['prazo_hora']}"
    posicao = entrada.get("posicao")
    return {
        "id": str(entrada["id"]),
        "codigo": entrada["espaco"]["codigo"],
        "espaco": entrada["espaco"]["nome"],
        "unidade": entrada["unidade"]["nome"],
        "tipo": entrada["tipo"]["nome"],
        "data": _data_br(entrada["data"]),
        "horario": f"{entrada['hora_inicio']} às {entrada['hora_fim']}",
        "status": entrada["status"],
        "situacao": SITUACOES_FILA.get(entrada["status"], entrada["status"]),
        "posicao": str(posicao) if posicao else "",
        "prazo": prazo,
    }


class FilaState(rx.State):
    """Entradas de fila do usuário e o aviso de vaga retida."""

    ativas: list[dict[str, str]] = []
    finalizadas: list[dict[str, str]] = []
    avisos: list[dict[str, str]] = []
    carregou: bool = False
    mensagem_erro: str = ""
    mensagem_sucesso: str = ""

    acao_aberta: bool = False
    acao: str = ""
    entrada: dict[str, str] = {}
    erro_dialogo: str = ""

    @rx.event
    async def carregar(self):
        """Sem sessão ou com senha provisória, não consulta nada."""
        auth = await self.get_state(AuthState)
        if not auth._token or auth.senha_provisoria:
            self.avisos = []
            return
        try:
            resposta = await api.minha_fila(auth._token)
        except api.NaoAutenticado as erro:
            return await tratar_erro_api(self, erro)
        except api.ErroApi:
            # O aviso não pode impedir o uso da página; a seção mostra a falha
            self.mensagem_erro = "Não foi possível carregar a fila de espera."
            return
        self.ativas = [_entrada_para_tela(e) for e in resposta["ativas"]]
        self.finalizadas = [_entrada_para_tela(e) for e in resposta["finalizadas"]]
        self.avisos = [_entrada_para_tela(e) for e in resposta["avisos"]]
        self.carregou = True

    @rx.event
    def limpar(self):
        """No login e no cadastro: nada da conta anterior aparece para a próxima."""
        self.ativas = []
        self.finalizadas = []
        self.avisos = []
        self.carregou = False
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""

    @rx.event
    def abrir(self):
        """Usado por "Minhas reservas": limpa as mensagens e recarrega."""
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.carregou = False
        return FilaState.carregar

    @rx.event
    def abrir_acao(self, entrada: dict, acao: str):
        self.mensagem_erro = ""
        self.mensagem_sucesso = ""
        self.erro_dialogo = ""
        self.entrada = entrada
        self.acao = acao
        self.acao_aberta = True

    @rx.event
    def mudar_acao(self, aberta: bool):
        self.acao_aberta = aberta

    @rx.var
    def titulo_acao(self) -> str:
        codigo = self.entrada.get("codigo", "")
        if self.acao == CONFIRMAR:
            return f"Confirmar a vaga em {codigo}"
        if self.entrada.get("status") == "NOTIFICADA":
            return f"Desistir da vaga em {codigo}"
        return f"Sair da fila de {codigo}"

    @rx.var
    def botao_acao(self) -> str:
        if self.acao == CONFIRMAR:
            return "Confirmar a reserva"
        if self.entrada.get("status") == "NOTIFICADA":
            return "Desistir da vaga"
        return "Sair da fila"

    @rx.var
    def aviso_acao(self) -> str:
        if self.acao == CONFIRMAR:
            return (
                "A reserva é criada agora, com as regras do tipo conferidas de novo."
            )
        if self.entrada.get("status") == "NOTIFICADA":
            return "A vaga passa para o próximo da fila."
        return "Você deixa a fila deste horário."

    @rx.event
    async def confirmar_acao(self, _dados: dict):
        self.erro_dialogo = ""
        auth = await self.get_state(AuthState)
        entrada_id = int(self.entrada["id"])
        try:
            if self.acao == CONFIRMAR:
                resposta = await api.confirmar_fila(auth._token, entrada_id)
            else:
                resposta = await api.desistir_fila(auth._token, entrada_id)
        except api.ErroValidacao as erro:
            # Ex.: o prazo venceu depois de a página carregar
            self.erro_dialogo = erro.mensagem
            return
        except api.ErroApi as erro:
            self.acao_aberta = False
            return await tratar_erro_api(self, erro)
        self.acao_aberta = False
        self.mensagem_sucesso = resposta["mensagem"]
        return [FilaState.carregar, ReservasState.carregar]
