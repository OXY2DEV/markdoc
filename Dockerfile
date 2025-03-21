FROM pandoc/core:latest
ENV config="{ 'help.txt': [ 'README.md' ] }"

CMD echo "$config" 
