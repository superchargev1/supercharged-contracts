import { ethers, network } from "hardhat";
import { getContracts } from "../utils/utils";

async function main() {
  const [deployer] = await ethers.getSigners();
  const provider = deployer.provider;
  const networkName = network.name;
  const contracts = getContracts();
  const OrderbookArtifact = await ethers.getContractFactory("Orderbook");
  const orderBook = new ethers.Contract(
    contracts[networkName]["Orderbook"],
    OrderbookArtifact.interface,
    provider
  );
  const credits = await orderBook.getOutcomeBalance(
    184467440780045189134n,
    "0xc9fDdfD1582865a5eac20089Cb7088f361a2860E"
  );
  console.log(credits);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
