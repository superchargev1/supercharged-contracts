import { ethers, network } from "hardhat";
import { getContracts } from "../utils/utils";

const WEI = 10 ** 18;
async function main(address: string) {
  const [deployer] = await ethers.getSigners();
  const networkName = network.name;
  const FactoryName = "MockUSDC";

  const contracts = getContracts();
  const Factory = await ethers.getContractFactory(FactoryName, deployer);
  const mockUSDC = new ethers.Contract(
    contracts?.[networkName]?.[FactoryName],
    Factory.interface,
    deployer
  );
  await (
    await mockUSDC.connect(deployer).transfer(address, BigInt(10000 * WEI))
  ).wait();
}

main("0x0D1bF830D7dD8A70E074973795B827B0E9ca28ea")
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
