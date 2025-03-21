FROM pandoc/core:latest

COPY markdoc.sh /markdoc.sh
RUN chmod +x /markdoc.sh

ENTRYPOINT [ "/markdoc.sh" ]
