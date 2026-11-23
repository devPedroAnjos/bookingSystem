"""Estado da página do espaço (spec pagina-espaco; change espaco-feed-avaliacoes, D15).

Só exibe o que o Xano devolve: o detalhe recusa espaço inexistente, não
reservável ou restrito ao papel com a mesma mensagem, e a página mostra
"Espaço não encontrado". A rota usa o parâmetro `id_espaco`, um nome que não
coincide com nenhuma variável de estado.
"""

import reflex as rx

from bookingSystem.api import xano_cliente as api
from bookingSystem.state.auth_state import NOMES_PAPEIS, token_da_sessao, tratar_erro_api
from bookingSystem.state.busca_state import cor_do_tipo, icone_do_tipo, media_texto


def _avaliacao_para_tela(avaliacao: dict) -> dict[str, str]:
    nota = int(avaliacao.get("nota") or 0)
    return {
        "nota": str(nota),
        "estrelas": "★" * nota + "☆" * (5 - nota),
        "comentario": avaliacao.get("comentario") or "",
        "data": avaliacao.get("data") or "",
        "autor": (avaliacao.get("autor_nome") or "")
        + " · "
        + NOMES_PAPEIS.get(avaliacao.get("autor_papel") or "", avaliacao.get("autor_papel") or ""),
    }


class EspacoState(rx.State):
    """Detalhe do espaço aberto e as avaliações dele."""

    espaco: dict[str, str] = {}
    recursos: list[str] = []
    avaliacoes: list[dict[str, str]] = []
    nao_encontrado: bool = False
    carregou: bool = False

    @rx.event
    async def abrir(self):
        self.espaco = {}
        self.recursos = []
        self.avaliacoes = []
        self.nao_encontrado = False
        self.carregou = False
        texto = str(self.router.page.params.get("id_espaco", "") or "")
        if not texto.isdigit():
            self.nao_encontrado = True
            self.carregou = True
            return
        token = await token_da_sessao(self)
        try:
            detalhe = await api.detalhe_espaco(token, int(texto))
        except api.ErroValidacao:
            self.nao_encontrado = True
            self.carregou = True
            return
        except api.ErroApi as erro:
            return await tratar_erro_api(self, erro)
        self.espaco = {
            "id": str(detalhe["id"]),
            "nome": detalhe["nome"],
            "codigo": detalhe["codigo"],
            "unidade": detalhe["unidade"]["nome"],
            "tipo": detalhe["tipo"]["nome"],
            "capacidade": str(detalhe["capacidade"]),
            "localizacao": detalhe.get("localizacao") or "",
            "descricao": detalhe.get("descricao") or "",
            "exige_aprovacao": "sim" if detalhe.get("exige_aprovacao") else "nao",
            "media": media_texto(detalhe),
            "media_numero": (
                f"{float(detalhe['media_avaliacoes']):.1f}".replace(".", ",")
                if detalhe.get("media_avaliacoes") is not None
                else "–"
            ),
            "total": str(detalhe.get("total_avaliacoes") or 0),
            "foto": detalhe.get("foto_url") or "",
            "icone": icone_do_tipo(detalhe["tipo"]["nome"]),
            "cor": cor_do_tipo(int(detalhe["tipo"]["id"])),
        }
        self.recursos = [
            f"{r['quantidade']}x {r['nome']}" for r in detalhe.get("recursos") or []
        ]
        self.avaliacoes = [_avaliacao_para_tela(a) for a in detalhe.get("avaliacoes") or []]
        self.carregou = True
