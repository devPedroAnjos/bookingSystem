"""Conversão entre HH:MM (tela) e minutos desde a meia-noite (Xano, design D3)."""

import re

_HHMM = re.compile(r"^([01]\d|2[0-3]):([0-5]\d)$")


def minutos_para_hhmm(minutos: int | None) -> str:
    """480 -> "08:00"; vazio quando o tipo ainda não tem o horário."""
    if minutos is None:
        return ""
    return f"{minutos // 60:02d}:{minutos % 60:02d}"


def hhmm_para_minutos(texto: str) -> int | None:
    """"08:00" -> 480; None quando o texto não é um horário de 00:00 a 23:59."""
    encontrado = _HHMM.match(texto.strip())
    if encontrado is None:
        return None
    return int(encontrado.group(1)) * 60 + int(encontrado.group(2))
