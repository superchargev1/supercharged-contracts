import { ethers, network } from "hardhat";
import { getContracts } from "../../utils/utils";
import { assert } from "console";

async function main() {
  const OPERATOR_ROLE = ethers.solidityPackedKeccak256(
    ["string"],
    ["OPERATOR_ROLE"]
  );
  const RESOLVER_ROLE = ethers.solidityPackedKeccak256(
    ["string"],
    ["RESOLVER_ROLE"]
  );
  const BOOKER_ROLE = ethers.solidityPackedKeccak256(
    ["string"],
    ["BOOKER_ROLE"]
  );
  const BLAST_POINT_OPERATOR_ROLE = ethers.solidityPackedKeccak256(
    ["string"],
    ["BLAST_POINT_OPERATOR_ROLE"]
  );
  const BATCHING = ethers.solidityPackedKeccak256(["string"], ["BATCHING"]);
  const ORDERBOOK_BATCHER_ROLE = ethers.solidityPackedKeccak256(
    ["string"],
    ["ORDERBOOK_BATCHER_ROLE"]
  );
  const ORDERBOOK = ethers.solidityPackedKeccak256(["string"], ["ORDERBOOK"]);

  //operator, resolver and batcher burn, close, open and booker
  //please redefine when deploy to mainnet

  const booker = process.env.BOOKER_ADDRESS;
  const orderBookBatcher = process.env.BATCHER_ORDERBOOK_ADDRESS;
  const operator = process.env.OPERATOR_ADDRESS;
  const resolver = process.env.RESOLVER_ADDRESS;
  const blastOperatorPk = process.env.BLAST_OPERATOR_ADDRESS_PK;

  assert(booker, "booker address is not defined");
  assert(orderBookBatcher, "orderBookBatcher address is not defined");
  assert(operator, "operator address is not defined");
  assert(resolver, "resolver address is not defined");
  assert(blastOperatorPk, "blastOperator private key is not defined");

  const [deployer] = await ethers.getSigners();
  const blastOperator = new ethers.Wallet(
    blastOperatorPk ?? "",
    deployer.provider
  );
  const contracts = getContracts();
  const networkName = network.name;
  const FactoryName = "Bookie";
  const bookieArtifact = await ethers.getContractFactory(FactoryName);
  const bookie = new ethers.Contract(
    contracts?.[networkName]?.[FactoryName],
    bookieArtifact.interface,
    deployer
  );
  const OrderbookArtifact = await ethers.getContractFactory("OrderbookBlast");
  const orderbook = new ethers.Contract(
    contracts?.[networkName]?.["OrderbookBlast"],
    OrderbookArtifact.interface,
    deployer
  );
  //grant the roles
  await (await bookie.grantRole(OPERATOR_ROLE, operator)).wait();
  await (await bookie.grantRole(RESOLVER_ROLE, resolver)).wait();
  await (await bookie.grantRole(BLAST_POINT_OPERATOR_ROLE, operator)).wait();
  await (
    await bookie.setAddress(BATCHING, contracts?.[networkName]?.["Batching"])
  ).wait();
  await (await bookie.grantRole(BOOKER_ROLE, booker)).wait();
  await (
    await bookie.grantRole(ORDERBOOK_BATCHER_ROLE, orderBookBatcher)
  ).wait();
  await (
    await bookie.setAddress(
      ORDERBOOK,
      contracts?.[networkName]?.["OrderbookBlast"]
    )
  ).wait();
  await (
    await orderbook.connect(blastOperator).configurePointsOperator()
  ).wait();
  await (await orderbook.initBlastYield()).wait();
  // await (
  //   await orderbook
  //     .connect(blastOperator)
  //     .configurePointsOperatorOnBehalf(await orderbook.getAddress())
  // ).wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
