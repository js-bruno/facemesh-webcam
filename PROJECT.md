# meshvtuber — guia do projeto para agentes de IA

> Documento de contexto para outra IA (ou pessoa) entender rapidamente o que é
> este projeto, como ele funciona e o que **não** pode ser mudado sem quebrar a
> fidelidade visual. Escrito em português; identificadores de código em inglês.

---

## 1. Resumo em 5 linhas

- **O que é:** uma réplica no navegador do preview do **Kalidoface 3D**
  (https://3d.kalidoface.com) — o facemesh do MediaPipe desenhado por cima da
  câmera (ou sozinho, no modo padrão).
- **Stack:** HTML + JavaScript puro (sem build, sem framework), MediaPipe
  **Holistic legado** + `drawing_utils`, servido por `python3 -m http.server`.
- **Fidelidade:** o bloco de desenho foi **copiado literalmente** do bundle do
  Kalidoface; mesmas versões de bibliotecas e mesmas cores/espessuras.
- **Estado atual:** modo padrão = **só o mesh** (câmera oculta, fundo preto),
  sem centralização automática e sem suavização extra. Desenho cru do MediaPipe.
- **Tudo offline:** as libs e modelos estão em `lib/` (~65 MB), sem CDN.

Commit atual: `31ad8cf feat: init` (working tree limpo). Existem dois `git stash`
com experimentos de centralização/suavização — ver seção 11.

---

## 2. Objetivo e não-objetivos

**Objetivo**

- Ser visualmente **idêntico** ao preview do Kalidoface 3D (facemesh), de forma
  simples e sem teclas de interação.
- Rodar no navegador e ser usável no **OBS** (Browser Source), inclusive com
  fundo transparente.
- Servir de base para customização futura do avatar (ainda não implementada).

**Não-objetivos (por enquanto)**

- Rigging de avatar VRM / `kalidokit` / troca de modelo 3D.
- Interface de configuração, atalhos de teclado, múltiplos estilos.
- Backend, build step, npm, framework.

---

## 3. Stack e ambiente

| Item | Versão / detalhe |
|---|---|
| MediaPipe Holistic | `@mediapipe/holistic@0.5.1635989137` (API **legada**, não Tasks) |
| Desenho | `@mediapipe/drawing_utils@0.3.1620248257` |
| Modelos | embutidos no pacote (`.tflite` dentro de `holistic_solution_packed_assets.data`) |
| Servidor | `python3 -m http.server 8000` (`serve.sh`) |
| Navegador | Chromium/Firefox em `http://localhost:8000` |

**Por que API legada?** O Kalidoface usa essa API. Migrar para a Tasks API
(`@mediapipe/tasks-vision`) muda nomes de opções, o formato dos resultados e
pode mudar pequenos detalhes visuais. Só migre se for um objetivo explícito.

---

## 4. Como rodar

```bash
cd ~/projects/meshvtuber
./serve.sh            # http://localhost:8000
```

- Abra **http://localhost:8000** e permita a câmera.
- **Precisa ser `localhost` (ou HTTPS)**: `getUserMedia` só funciona em contexto
  seguro. Abrir via `file://` não libera a câmera.
- Para testar sem câmera: `http://localhost:8000/?demo`.

---

## 5. Fluxo de dados

```
getUserMedia() ──> <video id="video">  (fica display:none no modo padrão)
                         │
                         │  drawImage() a cada frame novo
                         ▼
                 <canvas id="srcCanvas">   (canvas-fonte, fora do DOM)
                         │
                         │  holistic.send({ image: srcCanvas })
                         ▼
             @mediapipe/holistic (wasm + WebGL)
                         │
                         │  holistic.onResults(results)
                         ▼
                 desenhar(results)  ── bloco verbatim do Kalidoface
                         │
                         ▼
              <canvas id="canvas">  (visível, por cima do vídeo)
```

Pontos importantes do fluxo:

1. O `<video>`/`<img>` pode ficar **escondido** (`display:none`); por isso o
   frame é copiado para `srcCanvas` antes de ir ao MediaPipe. Em alguns casos,
   mandar o elemento escondido direto ao `holistic.send()` faz o tracking parar
   de atualizar.
2. O canvas visível tem a **resolução da fonte** (ex.: 640×480). O CSS encaixa
   na janela preservando o aspecto (`layout()` calcula `wrap.style.width/height`).
3. Os landmarks vêm normalizados em `[0..1]`; `drawConnectors`/`drawLandmarks`
   multiplicam por `canvas.width/height`.
4. `requestAnimationFrame` roda o loop de envio; um frame só é enviado quando
   `video.currentTime` muda (imagem estática: reenvia a cada 500 ms).

---

## 6. Arquivos

```
meshvtuber/
├── index.html     # app completo (HTML + CSS + JS, ~250 linhas)
├── serve.sh       # python3 -m http.server 8000
├── demo.jpg       # imagem usada no modo ?demo (portrait do MediaPipe)
├── lib/
│   ├── holistic/          # holistic.js + wasm + modelos empacotados
│   └── drawing_utils/     # drawing_utils.js (drawConnectors/drawLandmarks)
├── README.md      # visão geral curta
└── PROJECT.md     # este documento
```

- `lib/holistic/holistic.binarypb` é o grafo do MediaPipe.
- `locateFile` aponta para `lib/holistic/` — tudo local, sem rede.
- `demo.jpg` é o retrato oficial do MediaPipe; detecta rosto + pose parcial.

---

## 7. Decisões críticas (não mexa sem entender)

### 7.1 Nome da opção de íris: `refineFaceLandmarks`

Na API **legada** a opção chama-se `refineFaceLandmarks` (não `refineLandmarks`,
que é o nome da Tasks API). Além disso, no UMD ela é aplicada explicitamente:

```js
holistic.setOptions({ refineFaceLandmarks: true });
```

Sem isso, `faceLandmarks.length` fica em **468** e a íris nunca é desenhada
(pois o bloco só desenha íris quando o array tem **478** pontos).

### 7.2 Canvas-fonte em vez do `<video>` direto

`display:none` + enviar o `<video>` ao `holistic.send()` pode resultar em
tracking congelado/parcial em alguns navegadores. A cópia para `srcCanvas`
resolve e permite esconder a câmera de verdade.

### 7.3 Bloco de desenho é verbatim

Copiado de `yeemachine/kalidoface-3d`, branch `glitch`,
`docs/assets/index.e2bec78d.js` (caso `"holistic"`). Preserve cores e
espessuras — é o que garante a identidade visual:

```js
case "holistic":
  drawConnectors(rt, l.poseLandmarks, POSE_CONNECTIONS, {color: "#00cff7", lineWidth: 4});
  drawLandmarks(rt, l.poseLandmarks, {color: "#ff0364", lineWidth: 2});
  drawConnectors(rt, l.faceLandmarks, FACEMESH_TESSELATION, {color: "#C0C0C070", lineWidth: 1});
  l.faceLandmarks && l.faceLandmarks.length === 478 && drawLandmarks(rt, [l.faceLandmarks[468], l.faceLandmarks[468 + 5]], {color: "#ffe603", lineWidth: 2});
  drawConnectors(rt, l.leftHandLandmarks, HAND_CONNECTIONS, {color: "#eb1064", lineWidth: 5});
  drawLandmarks(rt, l.leftHandLandmarks, {color: "#00cff7", lineWidth: 2});
  drawConnectors(rt, l.rightHandLandmarks, HAND_CONNECTIONS, {color: "#22c3e3", lineWidth: 5});
  drawLandmarks(rt, l.rightHandLandmarks, {color: "#ff0364", lineWidth: 2});
  break;
```

Detalhe fácil de errar: a **mão direita tem cores próprias** (`#22c3e3` nas
linhas e `#ff0364` nos pontos), diferente da esquerda.

### 7.4 Canvas acompanha a fonte, não a janela

`setCanvasSize()` mantém `canvas.width/height` iguais à resolução do vídeo.
O CSS (`width/height: 100%`) faz o encaixe visual. Não desacople os dois sem
revisar as coordenadas normalizadas.

### 7.5 Opções do Holistic

```js
new Holistic({
  locateFile: (file) => "lib/holistic/" + file,
  refineFaceLandmarks: true,
  modelComplexity: 1,      // 0 = pose mais leve/menos precisa
  smoothLandmarks: true,   // suavização nativa do MediaPipe
});
```

### 7.6 Modo `?demo`

Usa `demo.jpg` como fonte (sem câmera) e reenvia o frame a cada 500 ms. É o modo
usado nos testes automatizados (headless), porque não exige permissão de câmera.

### 7.7 Debug

`?debug` mostra no canto superior esquerdo `face=`, `pose=`, `lh=`, `rh=` e
desenha um quadrado 48×48 no canto do canvas:

- **vermelho** = 478 landmarks (íris ativa)
- **verde** = 468 (refine não aplicado — bug)
- **azul** = 0 (rosto não detectado)

### 7.8 Pose facial oculto por padrão

O esqueleto do pose também desenha landmarks no rosto (índices **0–10**: nariz,
olhos, orelhas e boca). Eles são **mascarados por padrão** porque poluem a face;
a malha cinza e a íris amarela continuam normais.

Implementação: `semPoseFacial()` devolve uma cópia do array com os índices 0–10
`undefined`. `drawConnectors`/`drawLandmarks` pulam entradas indefinidas, então
todas as conexões que passam por esses pontos somem sozinhas (inclusive as
ligações orelha–ombro). O corpo (ombros, tronco, braços) e as mãos continuam.

`?poseface=1` restaura o comportamento original do Kalidoface.

> **Único ponto em que o padrão difere do Kalidoface.**

---

## 8. Parâmetros de URL (estado atual)

| URL | Efeito |
|---|---|
| `/` | **só o mesh**, câmera oculta, fundo preto |
| `/?video` | vídeo da câmera com o mesh por cima |
| `/?bg=transparent` | fundo transparente (OBS Browser Source) |
| `/?bg=%23200` | qualquer cor de fundo |
| `/?mirror` | espelha tudo via CSS (`scaleX(-1)`) |
| `/?zoom=1.4` | escala do display (não muda a resolução interna) |
| `/?poseface=1` | mostra o esqueleto do pose no rosto (padrão: oculto) |
| `/?demo` | usa `demo.jpg` em vez da câmera |
| `/?debug` | contadores + quadrado de status no canvas |

Combináveis: `/?demo&debug&bg=transparent`.

---

## 9. Comportamento atual (importante)

- **Sem centralização automática**: o mesh aparece onde a câmera o vê. Se a
  pessoa não estiver no centro do enquadramento, o mesh fica fora do centro.
- **Sem suavização/interpolação extra**: desenha a cada resultado do modelo
  (~25–30 fps), com o `smoothLandmarks` nativo do MediaPipe.
- **Sem fila controlada**: `holistic.send()` é chamado a cada frame novo e não é
  aguardado; se a inferência demorar mais que a câmera, pode acumular latência.
  (Uma versão com “1 frame por vez” + interpolação a 60 fps está no stash — ver
  seção 11.)
- **Pose facial oculto por padrão**: o esqueleto não desenha nariz, olhos,
  orelhas nem boca (índices 0–10). `?poseface=1` restaura. A malha e a íris
  continuam.
- A câmera **continua ativa** no modo padrão; só o vídeo está oculto.

---

## 10. Como testar (usado no desenvolvimento)

### 10.1 Screenshot headless (modo demo, sem câmera)

```bash
cd ~/projects/meshvtuber
./serve.sh &   # ou em outro terminal

timeout 90 chromium --headless=new --no-sandbox --disable-gpu \
  --use-angle=swiftshader --enable-unsafe-swiftshader \
  --screenshot=/tmp/shot.png --window-size=800,640 \
  --virtual-time-budget=12000 "http://localhost:8000/?demo"
```

O que verificar no PNG (com OpenCV/PIL):

| Métrica | Como medir | Esperado (800×640, `demo.jpg`) |
|---|---|---|
| malha cinza | pixels ~`#C0C0C070` compostos sobre fundo | ~5.000–7.000 px |
| íris amarela | pixels exatos `#ffe603` | ~35–40 px |
| corpo ciano / rosa | `#00cff7` / `#ff0364` | milhares de px |
| centro da malha | centróide dos cinzas | ~(400, 320) só se houver centralização |

> O cinza da malha tem alpha (`0x70`): sobre fundo preto ele compõe para
> ~84,84,84; sobre a imagem clara chega perto de 192. Ajuste o threshold ao
> fundo, senão o teste "não encontra" a malha.

### 10.2 Vídeo falso + CDP (movimento real)

Útil para testar tracking e performance sem webcam:

```bash
# vídeo 640x480 com o retrato deslizando
ffmpeg -loop 1 -i demo.jpg -t 6 -r 30 \
  -vf "crop=640:480:x='(iw-640)*abs(sin(t*0.9))':y=0,format=yuv420p" \
  -f yuv4mpegpipe /tmp/fake.y4m -y

chromium --headless=new --no-sandbox --disable-gpu \
  --use-angle=swiftshader --enable-unsafe-swiftshader \
  --use-fake-ui-for-media-stream --use-fake-device-for-media-stream \
  --use-file-for-fake-video-capture=/tmp/fake.y4m \
  --remote-debugging-port=9222 --window-size=800,640 \
  "http://localhost:8000/?debug"

# Node 24+ tem WebSocket nativo: conecte no CDP (/json/list) e avalie JS
# para ler document.getElementById('status').textContent, pixels do canvas etc.
```

Limitações do ambiente de teste:

- WebGL por software (SwiftShader) → inferência lenta (~2–3 fps) e `rAF`
  limitado. **Não** use isso para concluir performance real.
- No GPU real (ex.: RTX 3060) a inferência fica na casa de dezenas de fps.
- Para medir fluidez de verdade seria necessário um compositor a 60 Hz (Xvfb
  ajuda, mas o WebGL continua software). O custo de desenho medido foi
  **~0,8 ms/frame**, então o desenho não é o gargalo.

---

## 11. Stashes (experimentos guardados)

```bash
git stash list
# stash@{0}  2026-11-05 20:01  -> centralização FIXA + suavização + ?points
# stash@{1}  2026-11-05 19:45  -> centralização DINÂMICA + suavização + ?points
```

Ambos foram descartados do estado atual porque, na avaliação do usuário, o
facemesh "ficou pior" (sensação de atraso/borrão e/ou deslocamento). O commit
`31ad8cf` é o estado considerado bom.

Se quiser recuperar algum experimento:

- **Só a suavização** (desenho interpolado a 60 fps + 1 frame por vez):
  aplicar o stash e remover o bloco de centralização.
- **Só a centralização fixa**: aplicar o stash e remover interpolação/fila.
- **Centralização dinâmica** (persegue o rosto): `stash@{1}`.

Cuidado: `git stash apply` mexe em `index.html` e `README.md`; revise o diff
(`git diff`) antes de manter.

---

## 12. Limitações conhecidas / próximos passos

- [ ] Centralização opcional (fixa, calibrada uma vez) sem afetar o tracking.
- [ ] Controle de fila/suavização opcional (`?smooth`) — experimento em stash.
- [ ] Customização de avatar (cores/estilo) — espaço reservado, não implementado.
- [ ] Publicação para OBS com fundo transparente já funciona
      (`/?bg=transparent`), mas o canvas tem a proporção da câmera.
- [ ] Testes automatizados de regressão visual (hoje são scripts manuais).

---

## 13. Regras rápidas para quem for editar

1. **Não** troque o bloco de desenho por uma versão "mais limpa": cores e
   espessuras são o contrato visual.
2. **Não** use `refineLandmarks`; use `refineFaceLandmarks` + `setOptions`.
3. **Não** envie o `<video>` escondido direto ao `holistic.send()`; copie para
   `srcCanvas`.
4. **Não** rode via `file://`; câmera exige `localhost`/HTTPS.
5. **Não** altere `canvas.width/height` para o tamanho da janela; ele deve
   seguir a resolução da fonte.
6. **Não** assuma que headless/SwiftShader representa o desempenho real.
7. **Não** remova o mascaramento do pose facial (índices 0–10) sem que seja
   explicitamente pedido; ele existe para deixar a face limpa. `?poseface=1`
   é a válvula de escape.
8. Qualquer mudança de comportamento deve ser **opt-in por URL** — exceto
   quando o usuário pedir explicitamente para mudar o padrão (como o pose
   facial oculto).
