-include .env

# Default RPC URL for RISE testnet
RISE_TESTNET_RPC := https://testnet.riselabs.xyz

# Use environment variable if set, otherwise use default
FORK_URL := ${RPC_URL}
ifeq ($(FORK_URL),)
	FORK_URL := $(RISE_TESTNET_RPC)
endif

# deps
update:; forge update
build:; forge build
size:; forge build --sizes

# storage inspection
inspect:; forge inspect ${contract} storageLayout

# deployment
deploy:; forge script script/03_DeployPortfolioMargin.s.sol --rpc-url ${FORK_URL} --broadcast --verify
deploy-mocks:; forge script script/01_DeployMocks.s.sol --rpc-url ${FORK_URL} --broadcast --verify
deploy-update-risex:; forge script script/06_UpdatePortfolioMarginWithRISEx.s.sol --rpc-url ${FORK_URL} --broadcast --private-key ${PRIVATE_KEY}

# demo scripts
demo:; forge script script/05_SimpleDemoUserFlow.s.sol --rpc-url ${FORK_URL} -vvv
demo-broadcast:; BROADCAST=true forge script script/05_SimpleDemoUserFlow.s.sol --rpc-url ${FORK_URL} --broadcast -vvv

# mint USDC to test account
mint-usdc:; forge script script/MintUSDC.s.sol:MintUSDCScript --rpc-url ${FORK_URL} --broadcast --private-key ${PRIVATE_KEY}

# local tests without fork
test-local:; forge test -vv
test-local-gas:; forge test --gas-report

# fork tests - main commands
test:; forge test -vv --fork-url ${FORK_URL}
trace:; forge test -vvv --fork-url ${FORK_URL}
gas:; forge test --fork-url ${FORK_URL} --gas-report

# specific test targeting
test-contract:; forge test -vv --match-contract $(contract) --fork-url ${FORK_URL}
test-contract-gas:; forge test --gas-report --match-contract ${contract} --fork-url ${FORK_URL}
trace-contract:; forge test -vvv --match-contract $(contract) --fork-url ${FORK_URL}

test-test:; forge test -vv --match-test $(test) --fork-url ${FORK_URL}
trace-test:; forge test -vvvv --match-test $(test) --fork-url ${FORK_URL}

# test categories
test-basic:; forge test -vv --match-contract "PortfolioMarginBasicTest" --fork-url ${FORK_URL}
test-risex:; forge test -vv --match-contract "PortfolioMarginRISExTest" --fork-url ${FORK_URL}
test-liquidation:; forge test -vv --match-contract "PortfolioMarginLiquidation*Test" --fork-url ${FORK_URL}
test-morpho:; forge test -vv --match-contract "PortfolioMarginMorphoTest" --fork-url ${FORK_URL}
test-fullops:; forge test -vv --match-contract "PortfolioMarginFullOpsTest" --fork-url ${FORK_URL}
test-markets:; forge test -vv --match-contract "PortfolioMarginMarketsTest" --fork-url ${FORK_URL}

# snapshots
snapshot:; forge snapshot -vv --fork-url ${FORK_URL}
snapshot-diff:; forge snapshot --diff -vv --fork-url ${FORK_URL}

# coverage
coverage:; forge coverage --fork-url ${FORK_URL}
coverage-report:; forge coverage --report lcov --fork-url ${FORK_URL}
coverage-debug:; forge coverage --report debug --fork-url ${FORK_URL}

coverage-html:
	@echo "Running coverage..."
	forge coverage --report lcov --fork-url ${FORK_URL}
	@if [ "`uname`" = "Darwin" ]; then \
		lcov --ignore-errors inconsistent --remove lcov.info 'test/**' --output-file lcov.info; \
		genhtml --ignore-errors inconsistent -o coverage-report lcov.info; \
	else \
		lcov --remove lcov.info 'test/**' --output-file lcov.info; \
		genhtml -o coverage-report lcov.info; \
	fi
	@echo "Coverage report generated at coverage-report/index.html"

# utilities
clean:; forge clean
fmt:; forge fmt
fmt-check:; forge fmt --check

# quick commands
quick-test:; forge test -vv --match-test test_FullUserFlow --fork-url ${FORK_URL}
quick-demo:; forge script script/05_SimpleDemoUserFlow.s.sol --rpc-url ${FORK_URL} -vv

# help
help:
	@echo "Portfolio Margin System - Makefile Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make build          - Build contracts"
	@echo "  make update         - Update dependencies"
	@echo ""
	@echo "Testing (uses fork by default):"
	@echo "  make test           - Run all tests with fork"
	@echo "  make test-local     - Run tests without fork"
	@echo "  make gas            - Run tests with gas report"
	@echo "  make trace          - Run tests with stack traces"
	@echo ""
	@echo "Test Categories:"
	@echo "  make test-basic      - Run basic functionality tests"
	@echo "  make test-liquidation - Run liquidation tests"
	@echo "  make test-fullops    - Run full operation tests"
	@echo "  make test-markets    - Run market management tests"
	@echo ""
	@echo "Specific Tests:"
	@echo "  make test-contract contract=<ContractName>"
	@echo "  make test-test test=<testName>"
	@echo ""
	@echo "Coverage:"
	@echo "  make coverage       - Run coverage analysis"
	@echo "  make coverage-html  - Generate HTML coverage report"
	@echo ""
	@echo "Deployment & Demo:"
	@echo "  make deploy         - Deploy contracts to RISE testnet"
	@echo "  make deploy-update-risex - Deploy updated manager with correct RISEx"
	@echo "  make mint-usdc      - Mint USDC to test account"
	@echo "  make demo           - Run demo script (dry-run)"
	@echo "  make demo-broadcast - Run demo script (execute)"
	@echo ""
	@echo "Fork URL: ${FORK_URL}"
	@echo "Set RPC_URL in .env to override"

.PHONY: test test-local test-contract test-test trace gas coverage clean build help