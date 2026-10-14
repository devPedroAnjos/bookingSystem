"""Página de cadastro de aluno ou professor."""

import reflex as rx

from bookingSystem.pages.componentes import cartao, mensagem
from bookingSystem.state.auth_state import AuthState


def seletor_vinculo() -> rx.Component:
    return rx.select.root(
        rx.select.trigger(width="100%"),
        rx.select.content(
            rx.select.item("Aluno", value="ALUNO"),
            rx.select.item("Professor", value="PROFESSOR"),
        ),
        value=AuthState.vinculo,
        on_change=AuthState.escolher_vinculo,
    )


def seletor_unidade() -> rx.Component:
    return rx.select.root(
        rx.select.trigger(placeholder="Unidade de vínculo", width="100%"),
        rx.select.content(
            rx.foreach(
                AuthState.unidades,
                lambda unidade: rx.select.item(
                    unidade["nome"], value=unidade["id"]
                ),
            ),
        ),
        name="unidade_vinculo_id",
    )


def campo(nome: str, rotulo: str, tipo: str = "text") -> rx.Component:
    return rx.input(name=nome, type=tipo, placeholder=rotulo, width="100%")


def cadastro() -> rx.Component:
    return cartao(
        rx.heading("Criar conta", size="6"),
        mensagem(AuthState.mensagem_erro, "red"),
        mensagem(AuthState.mensagem_sucesso, "green"),
        rx.form(
            rx.vstack(
                campo("nome", "Nome"),
                campo("email", "E-mail institucional", "email"),
                campo("senha", "Senha (mínimo de 8 caracteres)", "password"),
                campo("confirmacao_senha", "Confirme a senha", "password"),
                rx.text("Vínculo", size="2", weight="medium"),
                seletor_vinculo(),
                rx.cond(AuthState.vinculo == "PROFESSOR", seletor_unidade()),
                rx.button("Cadastrar", type="submit", width="100%"),
                spacing="3",
                width="100%",
            ),
            on_submit=AuthState.cadastrar,
            width="100%",
        ),
        rx.text("Já tem conta? ", rx.link("Entrar", href="/login"), size="2"),
    )
