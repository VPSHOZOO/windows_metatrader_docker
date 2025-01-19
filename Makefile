# Colors for terminal output
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

.PHONY: all clean config help

help:
	@echo "$(GREEN)Available commands:$(NC)"
	@echo "  make config   - Create new docker-compose configuration file"
	@echo "  make clean    - Remove generated configuration file"
	@echo "  make help     - Show this help message"

config:
	@chmod +x generate_compose.bash
	@./generate_compose.bash

clean:
	@read -p "Enter filename to remove [$(DEFAULT_FILENAME)]: " filename; \
	filename=$${filename:-$(DEFAULT_FILENAME)}; \
	[[ $$filename != *.yml ]] && filename="$$filename.yml"; \
	rm -f "$$filename"; \
	echo "$(GREEN)$$filename has been removed.$(NC)"
