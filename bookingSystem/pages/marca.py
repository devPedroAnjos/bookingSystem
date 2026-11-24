"""Logotipo "Booking System" com o livro na barra do t (Figma "Design", seção 02; D11).

O SVG vai embutido na página (rx.html), e não como <img>, para o texto usar a
fonte Inter já carregada. O livro fica numa posição fixa sobre o "t", medida
no navegador. O nome é sempre escrito com B e S maiúsculos.
"""

import reflex as rx

# Posição do livro sobre a barra do "t" de "Booking System" em Inter Bold 24, medida no
# navegador com getExtentOfChar(11): centro do "t" menos metade da largura do livro
_LIVRO_X = 138.9

_POSITIVO = f"""<svg width="{{largura}}" viewBox="0 0 198 34" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Booking System" style="display:block">
<text x="2" y="25" style="fill:var(--bs-brand-deep)" font-family="Inter, sans-serif" font-weight="700" font-size="24" letter-spacing="-0.025em">Booking System</text>
<g transform="translate({_LIVRO_X}, 11.1)">
<path d="M2.8 0C1.0 0 0 1.15 0 2.65C0 4.15 1.0 5.3 2.8 5.3H11.6V0H2.8Z" style="fill:var(--bs-brand-deep)"/>
<rect x="2.5" y="0.95" width="8.3" height="1.35" rx="0.25" style="fill:var(--bs-accent)"/>
<rect x="2.5" y="2.95" width="8.3" height="1.35" rx="0.25" style="fill:var(--bs-accent)"/>
<path d="M8.7 5.2H10.5V7.7L9.6 6.95L8.7 7.7V5.2Z" style="fill:var(--bs-brand-deep)"/>
</g></svg>"""

_NEGATIVO = f"""<svg width="{{largura}}" viewBox="0 0 198 34" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Booking System" style="display:block;max-width:100%">
<text x="2" y="25" style="fill:var(--bs-on-brand-deep)" font-family="Inter, sans-serif" font-weight="700" font-size="24" letter-spacing="-0.025em">Booking System</text>
<g transform="translate({_LIVRO_X}, 11.4)">
<path d="M2.6 0C0.9 0 0 1.05 0 2.4C0 3.75 0.9 4.8 2.6 4.8H11.4V2.75H2.85V2.05H11.4V0H2.6Z" style="fill:var(--bs-accent)"/>
<path d="M8.5 4.8H10.3V7.3L9.4 6.55L8.5 7.3V4.8Z" style="fill:var(--bs-accent)"/>
</g></svg>"""


def logotipo(largura: int = 184, negativo: bool = False) -> rx.Component:
    modelo = _NEGATIVO if negativo else _POSITIVO
    return rx.html(modelo.replace("{largura}", str(largura)))
