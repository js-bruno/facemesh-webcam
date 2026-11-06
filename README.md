# meshvtuber 📺

Réplica do **preview do Kalidoface 3D** (https://3d.kalidoface.com) — o facemesh
desenhado no browser, reutilizando o código de desenho do próprio Kalidoface e as
mesmas libs (versões do package-lock dele). Tudo roda 100% offline.

**Padrão: só o mesh** (câmera oculta, fundo preto).

> ℹ️ O **esqueleto do pose no rosto** (linhas azuis + pontos rosas do nariz,
> olhos e orelhas) vem **oculto por padrão**. Use `?poseface=1` para mostrá-lo.

> 📘 Documento detalhado para agentes/IA (arquitetura, decisões e armadilhas):
> [`PROJECT.md`](PROJECT.md).

## Rodar

```bash
cd ~/projects/meshvtuber
./serve.sh          # http://localhost:8000
```
Abra **http://localhost:8000** no Firefox/Chromium e permita a câmera.

## Opções (via URL, sem teclas)

| URL | Efeito |
|---|---|
| `http://localhost:8000` | **só o mesh** (padrão, fundo preto) |
| `http://localhost:8000/?video` | mostra o vídeo da câmera com o mesh por cima |
| `http://localhost:8000/?bg=transparent` | fundo transparente (OBS Browser Source) |
| `http://localhost:8000/?bg=%23200` | qualquer cor de fundo (hex URL-encoded) |
| `http://localhost:8000/?mirror` | espelha (selfie) |
| `http://localhost:8000/?zoom=1.4` | escala do avatar |
| `http://localhost:8000/?poseface=1` | mostra o esqueleto do pose no rosto (padrão: oculto) |
| `http://localhost:8000/?demo` | usa `demo.jpg` em vez da câmera |

Combináveis: `?demo&bg=transparent&zoom=1.3`

Também dá para fixar tudo no objeto `CONFIG` do `index.html`.

## O que é idêntico ao Kalidoface

| Item | Origem |
|---|---|
| Bloco de desenho (caso "holistic") | copiado de `yeemachine/kalidoface-3d` (branch glitch, `index.e2bec78d.js`) |
| `@mediapipe/holistic@0.5.1635989137` | mesma versão do package-lock dele (com os modelos embutidos) |
| `@mediapipe/drawing_utils@0.3.1620248257` | mesmas funções `drawConnectors`/`drawLandmarks` |
| Canvas do tamanho do vídeo + save/clearRect/restore | mesmo fluxo do preview dele |

Cores/espessuras (verbatim do código dele):
- corpo: linhas `#00cff7` (4) + pontos `#ff0364` (2)
- rosto: malha `#C0C0C070` (1) + íris `#ffe603` (2 pontos: 468 e 473)
- mão esquerda: linhas `#eb1064` (5) + pontos `#00cff7` (2)
- mão direita: linhas `#22c3e3` (5) + pontos `#ff0364` (2)

> **Única diferença proposital em relação ao Kalidoface:** o esqueleto do pose
> no rosto (índices 0–10: nariz, olhos, orelhas e boca) é oculto por padrão
> para deixar a face limpa. `?poseface=1` restaura o comportamento original.

## OBS

1. Fonte **Browser** → URL `http://localhost:8000/?bg=transparent`
2. Largura/altura iguais à resolução da câmera (ex.: 640×480) ou maior
3. O mesh aparece sozinho, com fundo transparente por cima do resto da cena

## Estrutura

```
meshvtuber/
├── index.html              # app completo (~150 linhas de JS)
├── serve.sh                # servidor local
├── demo.jpg                # imagem de teste (?demo)
├── lib/holistic/           # lib do MediaPipe (com modelos .tflite/.wasm)
├── lib/drawing_utils/      # funções de desenho
└── README.md
```
