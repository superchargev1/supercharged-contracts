import hre, { ethers, upgrades, network } from "hardhat";
import "dotenv/config";
import { formatEther } from "ethers";
import { getContracts, writeContract } from "../../utils/utils";
import { assert } from "console";

async function main() {
  const [deployer] = await ethers.getSigners();
  const networkName = network.name;
  const FactoryName = "OrderbookBlast";

  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Balance: ",
    formatEther(await deployer.provider.getBalance(deployer.address))
  );

  const contracts = getContracts();
  console.log(contracts);

  let proxy: any = contracts?.[networkName]?.[FactoryName];

  if (!proxy) {
    console.log("Deploying contract...");
    assert(contracts?.[networkName]["Bookie"], "Bookie contract not found");
    assert(contracts?.[networkName]["Events"], "Events contract not found");
    assert(
      contracts?.[networkName]["SignatureValidator"],
      "SignatureValidator contract not found"
    );
    assert(contracts?.[networkName]["USDB"], "USDB contract not found");
    const Factory = await ethers.getContractFactory(FactoryName, deployer);
    const contract = await upgrades.deployProxy(
      Factory,
      [
        contracts?.[networkName]["Bookie"],
        contracts?.[networkName]["Events"],
        contracts?.[networkName]["SignatureValidator"],
        contracts?.[networkName]["USDB"],
      ],
      {
        initializer: "initialize",
      }
    );
    await contract.waitForDeployment();
    proxy = await contract.getAddress();
    const implemented = await upgrades.erc1967.getImplementationAddress(proxy);
    console.log("PredictMarket Contract", proxy);
    console.log("Implemented Address", implemented);

    // write to data
    writeContract(networkName, FactoryName, proxy);
    writeContract(networkName, FactoryName + "-implemented", implemented);
  } else {
    // const proxy = contracts[networkName][FactoryName]
    const oldImplemented = await upgrades.erc1967.getImplementationAddress(
      proxy
    );
    console.log("Upgrading contract");
    const Factory = await ethers.getContractFactory(FactoryName, deployer);
    const contract = await upgrades.upgradeProxy(proxy, Factory);
    // new implemented
    const implemented = await upgrades.erc1967.getImplementationAddress(proxy);

    console.log("Upgrade", oldImplemented, implemented);
    writeContract(
      networkName,
      FactoryName + "-implemented-old",
      oldImplemented
    );
    writeContract(networkName, FactoryName + "-implemented", implemented);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
