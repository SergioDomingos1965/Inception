• O erro acontece porque o MariaDB está a recusar o host de origem do container WordPress: wordpress.inception.

  A razão mais provável no teu projeto é esta:

  1. O utilizador do banco só é criado na primeira inicialização do volume MariaDB.
     Em Documents/Inception/srcs/requirements/mariadb/tools/run.sh:7 até Documents/Inception/srcs/requirements/mariadb/
     tools/run.sh:11, o script só marca INITIALIZED=1 quando /var/lib/mysql/mysql ainda não existe.
  2. O CREATE USER '${MYSQL_USER}'@'%' só roda dentro desse if.
     Isso está em Documents/Inception/srcs/requirements/mariadb/tools/run.sh:33 até Documents/Inception/srcs/requirements/
     mariadb/tools/run.sh:40.
  3. O teu volume persistente já existe.
     O compose monta /home/sedoming/data/mariadb em Documents/Inception/srcs/docker-compose.yml:51, e esse diretório já
     contém uma base inicializada.

  Resultado: se esse volume foi criado numa execução antiga, com permissões diferentes, o utilizador wpuser pode estar
  gravado como algo tipo 'wpuser'@'localhost' ou sem permissão para wordpress.inception. Como agora o bootstrap não volta
  a criar/grantar esse user, o WordPress falha com:

  Error 1130: Host 'wordpress.inception' is not allowed to connect

  Há ainda um bug no script do WordPress: ele imprime Connected to MySQL server mesmo sem confirmar que o loop realmente
  conseguiu autenticar. Isso está em Documents/Inception/srcs/requirements/wordpress/tools/run.sh:10 até Documents/
  Inception/srcs/requirements/wordpress/tools/run.sh:17. Portanto esse log é enganador.

  Em resumo: o problema não parece ser o docker-compose; parece ser estado antigo persistido no volume do MariaDB.

  Se quiseres, no próximo passo eu posso corrigir isso no projeto de duas formas:

  1. ajustar o bootstrap do MariaDB para reaplicar CREATE USER/GRANT mesmo com volume existente;
  2. corrigir o script do WordPress para falhar corretamente se o banco não aceitar a ligação.
