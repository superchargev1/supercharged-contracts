### Deploy contracts

`yarn hardhat run deploy/SuperCharge/Bookie.ts --network blastSepolia`

`yarn hardhat run deploy/SuperCharge/Events.ts --network blastSepolia`

`yarn hardhat run deploy/SuperCharge/SignatureValidator.ts --network blastSepolia`

`yarn hardhat run deploy/SuperCharge/OrderbookBlast.ts --network blastSepolia`

`yarn hardhat run deploy/SuperCharge/Batching.ts --network blastSepolia`

### Run setup role

1. Config address in .env.dev (.env.prod)

   > BOOKER_ADDRESS=
   > BATCHER_ORDERBOOK_ADDRESS=
   > OPERATOR_ADDRESS=

2. Run the config scripts:

`yarn hardhat run scripts/setup/grantRole.ts --network blastSepolia`

### Upgrade contract to V1.1

`yarn hardhat run deploy/SuperCharge/Events.ts --network blastSepolia`

`yarn hardhat run deploy/SuperCharge/SignatureValidator.ts --network blastSepolia`

`yarn hardhat run deploy/SuperCharge/OrderbookBlast.ts --network blastSepolia`
