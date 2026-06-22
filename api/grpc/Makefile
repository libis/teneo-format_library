### gRPC actions

grpc-shell: ## Open a shell in the gRPC container
	docker compose --profile grpc exec grpc bash

grpc-build: gem-build ## Build the gem and gRPC image
	docker compose --profile grpc build grpc

grpc-up: ## Start the gRPC server
	docker compose --profile grpc up -d

grpc-down: ## Stop the gRPC server
	docker compose --profile grpc down

grpc-logs: ## Show gRPC server logs
	docker compose --profile grpc logs -f grpc || true

grpc-restart: grpc-down grpc-up ## Restart the gRPC server

grpc-generate: ## Generate gRPC Ruby code from protobuf
	cd api && bundle exec rake grpc:generate

