# Apresentação Radisa CRM

Apresentação comercial em PDF (A4, 17 páginas) no padrão visual da Fabersoft, para envio
por WhatsApp. O arquivo pronto é `Radisa-CRM-Apresentacao.pdf`.

- `index.html` + `deck.css`: fonte da apresentação (uma `<section class="page">` por página).
- `assets/`: capa, banner, marca d'água, rodapé e logo recortados do modelo oficial da Fabersoft.
- `fonts/`: Lato e Poppins (SIL Open Font License, licenças ao lado).
- `shots/`: telas do sistema capturadas numa instalação de demonstração com dados fictícios.

Para gerar o PDF de novo depois de editar o HTML (precisa de Node e do pacote `playwright`):

```bash
node render.js index.html Radisa-CRM-Apresentacao.pdf /tmp/previas
```

O script imprime, por página, até onde o conteúdo vai e avisa (`overflow: true`) quando algo
invade o rodapé. Em `/tmp/previas` ficam as prévias em PNG de cada página.
