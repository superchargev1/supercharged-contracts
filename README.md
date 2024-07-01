### Deploy contracts

1. yarn hardhat run deploy/SuperCharge/Bookie.ts --network blastSepolia
2. yarn hardhat run deploy/SuperCharge/Events.ts --network blastSepolia
3. yarn hardhat run deploy/SuperCharge/SignatureValidator.ts --network blastSepolia
4. yarn hardhat run deploy/SuperCharge/OrderbookBlast.ts --network blastSepolia
5. yarn hardhat run deploy/SuperCharge/Batching.ts --network blastSepolia

### Run setup role

# Config address in .env.dev (.env.prod)

# BOOKER_ADDRESS= \

# BATCHER_ORDERBOOK_ADDRESS= \

# OPERATOR_ADDRESS= \

# RESOLVER_ADDRESS= \

1. yarn hardhat run scripts/setup/grantRole.ts --network blastSepolia

### Upgrade contract to V1.1

1. yarn hardhat run deploy/SuperCharge/Events.ts --network blastSepolia
2. yarn hardhat run deploy/SuperCharge/SignatureValidator.ts --network blastSepolia
3. yarn hardhat run deploy/SuperCharge/OrderbookBlast.ts --network blastSepolia
