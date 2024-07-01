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

  const credits = await orderBook.getClaimEvent(
    2,
    [10],
    "0xedA27C3aE1c3B5b1f352AA974F5B0Ce7b91D5215"
  );
  console.log(credits);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
