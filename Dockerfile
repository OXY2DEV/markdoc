FROM pandoc/core:latest

RUN apk add --no-cache bash jq neovim

COPY markdoc.sh /markdoc.sh
RUN chmod +x /markdoc.sh

ENTRYPOINT [ "/markdoc.sh" ]
