import { ethers, network } from "hardhat";
import { getContracts } from "../../utils/utils";

async function main() {
  const funding = process.env.FUNDING;
  const usdbContract = process.env.USDB_CONTRACT;
  const userPk = process.env.USER_PK;
  if (!funding || !usdbContract || !userPk) {
    console.log(
      "define the fund and usdb contract and user privatekey first before running this script"
    );
    return;
  }
  const user = new ethers.Wallet(userPk, ethers.provider);
  const [deployer] = await ethers.getSigners();
  console.log("deployer: ", deployer.address);

  const networkName = network.name;
  const contracts = getContracts();
  const erc20Interface = [
    "function balanceOf(address owner) view returns (uint256)",
    "function transfer(address to, uint256 value) returns (bool)",
    "function approve(address spender, uint256 value) returns (bool)",
  ];
  const usdb = new ethers.Contract(usdbContract, erc20Interface, deployer);
  const nUSDArtifact = await ethers.getContractFactory("scUSD");
  const nUSD = new ethers.Contract(
    contracts?.[networkName]?.["scUSD"],
    nUSDArtifact.interface,
    user
  );
  const x1000Artifact = await ethers.getContractFactory("X1000V2");
  const x1000 = new ethers.Contract(
    contracts?.[networkName]?.["X1000V2"],
    x1000Artifact.interface,
    user
  );
  await (
    await usdb.connect(user).approve(await nUSD.getAddress(), funding)
  ).wait();
  //topup usdb from deployer to nUSD
  await (await nUSD.connect(user).deposit(funding)).wait();
  //get credit platform balance
  const balance = await nUSD.balanceOf(user.address);
  console.log("balance: ", balance);
  //topup nUSD to x1000
  await (
    await nUSD.connect(user).transfer(await x1000.getAddress(), balance)
  ).wait();
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
