# Tico — identidade visual

Tico é o pequeno companheiro que transforma gestos no trackpad em ações e
fluxos no macOS. A marca deve parecer ágil, simpática e inteligente, sem ficar
infantil.

## Conceito

O símbolo combina:

- dois pontos, representando as pontas dos dedos;
- um traço em `U`, representando um gesto contínuo;
- um pequeno rosto em espaço negativo, representando o companheiro Tico.

O símbolo canônico deve manter sempre a mesma geometria. Expressões alternativas
ou mudanças na posição dos pontos não fazem parte da marca principal.

## Cores

### Modo claro

| Token | Cor |
| --- | --- |
| Background | `#F8F7FC` |
| Surface | `#FFFFFF` |
| Primary | `#6366F1` |
| Accent | `#FF6B6B` |
| Text | `#111827` |
| Secondary text | `#5B6475` |

### Modo escuro

| Token | Cor |
| --- | --- |
| Background | `#0B1220` |
| Surface | `#151E2E` |
| Primary | `#7C8CFF` |
| Accent | `#FF7A72` |
| Text | `#F3F5FA` |
| Secondary text | `#AAB3C2` |

As cores de dark mode são adaptações ópticas, não simples inversões das cores
claras.

## Tipografia

- Marca e materiais institucionais: **Sora SemiBold**.
- Interface macOS: **SF Pro**, usando os estilos nativos do sistema.

## Uso

- Tamanho digital mínimo do símbolo: `16 px`.
- Preferir `24 px` ou mais quando o rosto interno precisar permanecer evidente.
- Manter área livre ao redor da marca equivalente ao diâmetro de um dos pontos.
- Em uma cor, usar preto sobre fundos claros e branco sobre fundos escuros.
- Não alterar a posição dos pontos, criar novas expressões ou trocar as cores
  entre os elementos.

## Referência visual

A prancha-mestre está em `tico-identity-master.png`.

## Assets de produção

Os masters ficam em `Masters/`:

- `tico-symbol-light.png` e `tico-symbol-dark.png`;
- `tico-symbol-monochrome-black.png` e
  `tico-symbol-monochrome-white.png`;
- `tico-wordmark-light.png` e `tico-wordmark-dark.png`;
- `tico-app-icon-master-1024.png`;
- `Tico.iconset/` e `Tico.icns`.

Os arquivos usados pelo app ficam em
`Sources/Tico/Resources/Brand/`.

Todos os exports são derivados da mesma silhueta pelo script
`script/generate_tico_brand_assets.py`. A fonte Sora e a respectiva licença OFL
ficam junto aos masters e não são incorporadas ao bundle do app.

Para regenerar:

```sh
python3 script/generate_tico_brand_assets.py \
  --source Design/Brand/Tico/Masters/tico-symbol-raw.png \
  --font Design/Brand/Tico/Masters/Sora-VariableFont_wght.ttf \
  --design-dir Design/Brand/Tico/Masters \
  --resources-dir Sources/Tico/Resources/Brand
```
