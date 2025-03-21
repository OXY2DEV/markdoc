FROM pandoc/core:latest
ENV CONFIG="{ 'help.txt': [ 'README.md' ] }"

CMD echo "$CONFIG" 
