import { ethers, network } from "hardhat";
import { getContracts } from "../utils/utils";

async function main() {
  const [deployer] = await ethers.getSigners();
  const provider = deployer.provider;
  const orderbookBatcherPk =
    "9a05307c0d53c3616ce0a92da6184686d3b1fa7c5b4d2171a043b7b33c900099";
  const orderBookBatcher = new ethers.Wallet(
    orderbookBatcherPk || "",
    provider
  );
  const networkName = network.name;
  const batchingArtifact = await ethers.getContractFactory("Batching");
  const contracts = getContracts();
  const batching = new ethers.Contract(
    contracts[networkName]["Batching"],
    batchingArtifact.interface,
    deployer
  );
  await (
    await batching.connect(orderBookBatcher).matchingLimit([1], [0], [[2]])
  ).wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
