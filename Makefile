-include .env

.PHONY: all test clean coverage typechain deploy-main

all: clean install build

# function: generate abi for given contract name (key)
# requires contract name to match the file name
define generate_abi
    $(eval $@_CONTRACT_NAME = $(1))
		$(eval $@_CONTRACT_PATH = $(2))
		forge inspect --optimize --optimizer-runs 2000 contracts/${$@_CONTRACT_PATH}/${$@_CONTRACT_NAME}.sol:${$@_CONTRACT_NAME} abi > abi/${$@_CONTRACT_NAME}.json
endef

# Clean the repo
forge-clean :; forge clean
clean :; npx hardhat clean

# Remove modules
forge-remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; npm install

# Update Dependencies
forge-update :; forge update

forge-build :; forge build
build :; npx hardhat compile

test :; forge test

snapshot :; forge snapshot

slither :; slither ./contracts

# glob doesn't work for nested folders, so we do it manually
format:
	npx prettier --write contracts/*.sol
	npx prettier --write contracts/**/*.sol
	npx prettier --write contracts/**/**/*.sol
	npx prettier --write contracts/**/**/**/*.sol
	npx prettier --write contracts/**/**/**/**/*.sol

# generate forge coverage on pinned mainnet fork
# process lcov file, ignore test, script, and contracts/mocks folders
# generate html report from lcov.info (ignore "line ... has branchcov but no linecov data" error)
coverage:
	mkdir -p coverage
	forge coverage --report lcov --fork-url https://rpc.ankr.com/eth --fork-block-number 19042069
	lcov --remove lcov.info -o coverage/lcov.info 'test/*' --rc branch_coverage=1
	genhtml coverage/lcov.info -o coverage --rc branch_coverage=1 --ignore-errors category

abi:
	mkdir -p abi
	@$(call generate_abi,"AccessController",".")
	@$(call generate_abi,"DisputeModule","./modules/dispute-module")
	@$(call generate_abi,"RoyaltyModule","./modules/royalty-module")
	@$(call generate_abi,"TaggingModule","./modules/tagging")
	@$(call generate_abi,"IPAccountRegistry","./registries")
	@$(call generate_abi,"IPRecordRegistry","./registries")
	@$(call generate_abi,"LicenseRegistry","./registries")
	@$(call generate_abi,"ModuleRegistry","./registries")
	@$(call generate_abi,"IPMetadataResolver","./resolvers")

# typechain:
# 	make abi
# 	rm -rf ./types-typechain
# 	npx typechain --target ethers-v6 ./abi/*.json --out-dir ./types-typechain
typechain :; npx hardhat typechain

# solhint should be installed globally
lint :; npx solhint contracts/**/*.sol && npx solhint contracts/*.sol

deploy-goerli :; npx hardhat run ./script/deploy-reveal-engine.js --network goerli
verify-goerli :; npx hardhat verify --network goerli ${contract}

anvil :; anvil -m 'test test test test test test test test test test test junk'

# run: RPC_URL=https://rpc.url make deploy-main
deploy-main :; forge script script/foundry/deployment/Main.s.sol:Main --rpc-url ${RPC_URL} --broadcast --verify -vvvv
