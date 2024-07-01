yarn hardhat run deploy/SuperCharge/Bookie.ts --network blastSepolia && \
yarn hardhat run deploy/SuperCharge/Events.ts --network blastSepolia && \
yarn hardhat run deploy/SuperCharge/SignatureValidator.ts --network blastSepolia && \
yarn hardhat run deploy/SuperCharge/OrderbookBlast.ts --network blastSepolia && \
yarn hardhat run deploy/SuperCharge/Batching.ts --network blastSepolia && \
BOOKER_ADDRESS=0x9aDAB1499D78C02ea83Ea1ccEcf733B5b3522913 \
BATCHER_ORDERBOOK_ADDRESS=0x2960cf69B6Ed014ad55fAe18ADE914344bFF7C1A \
OPERATOR_ADDRESS=0xAF2D96d3FE6bA02a508aa136fA73216755D7e750 \
RESOLVER_ADDRESS=0xcda3C6C722c06488E337f2B925e5B004d1D160Bf \
BLAST_OPERATOR_ADDRESS_PK=89c83ef27364979cfb63487b33885e1d99d4d0633e8ff41d7689d5267e3b4cf0 \
yarn hardhat run scripts/setup/grantRole.ts --network blastSepolia