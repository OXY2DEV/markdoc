FROM pandoc/core:latest

RUN apk add --no-cache bash

COPY markdoc.sh /markdoc.sh
RUN chmod +x /markdoc.sh

ENTRYPOINT [ "/markdoc.sh" ]
