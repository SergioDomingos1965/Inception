# Variáveis para facilitar a leitura e manutenção
USER = $(shell whoami)
COMPOSE_FILE = srcs/docker-compose.yml
DATA_DIR = /home/$(USER)/data

# Regra padrão: monta a infraestrutura inteira
all: setup up

# Cria as pastas na máquina hospedeira (VM) que servirão de "despensa" (Volumes)
setup:
	@mkdir -p $(DATA_DIR)/mariadb
	@mkdir -p $(DATA_DIR)/wordpress

# Levanta a orquestra
up:
	@docker compose -f $(COMPOSE_FILE) up -d --build

# Desliga os containers, mas mantém as imagens e volumes intactos
down:
	@docker compose -f $(COMPOSE_FILE) down

# Para os containers (Pausa)
stop:
	@docker compose -f $(COMPOSE_FILE) stop

# Inicia containers que estavam parados
start:
	@docker compose -f $(COMPOSE_FILE) start

# Limpeza básica (Remove containers parados)
clean: down
	@docker system prune -f

# Destruição total: apaga tudo! (Containers, imagens, networks e os arquivos persistidos)
fclean: clean
	@docker system prune -a -f --volumes
	@docker volume rm $$(docker volume ls -q) 2>/dev/null || true
	@docker run --rm -v $(DATA_DIR):/data debian:bookworm sh -c "rm -rf /data/*"

# Reinicia do zero: Limpa tudo e constrói de novo
re: fclean all

.PHONY: all setup up down stop start clean fclean re
