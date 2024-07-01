import { ethers, network } from "hardhat";
import { getContracts } from "../utils/utils";

import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { Contract, Wallet } from "ethers";

enum OrderType {
  BuyYes = 0,
  SellYes = 1,
  BuyNo = 2,
  SellNo = 3,
}

async function signatureOrderBuyTrx(
  booker: Wallet,
  address: string,
  orderType: OrderType,
  outcomeId: BigInt,
  price: number,
  value: BigInt,
  contract: Contract
) {
  try {
    const message = ethers.getBytes(
      ethers.keccak256(
        ethers.solidityPacked(
          ["address", "address", "uint8", "uint256", "uint256", "uint256"],
          [
            await contract.getAddress(),
            address,
            orderType,
            outcomeId,
            price,
            value,
          ]
        )
      )
    );
    return await booker.signMessage(message);
  } catch (error) {
    console.log("🚀 ~ OrderbookContract ~ error:", error);
    throw error;
  }
}

async function main(
  address: string,
  outcomeId: BigInt,
  orderType: OrderType,
  price: number,
  value: BigInt
) {
  const bookerPk =
    "a1bf0881178e942466e37df9a741ea58c471313a6feff79a925c6c20f3de2b13";
  console.log("bookerPk: ", bookerPk);
  const [deployer] = await ethers.getSigners();
  const networkName = network.name;
  const provider = deployer.provider;
  const booker = new ethers.Wallet(bookerPk || "", provider);
  const contracts = getContracts();
  const OrderbookArtifact = await ethers.getContractFactory("Orderbook");
  const USDBArtifact = await ethers.getContractFactory("MockUSDC");
  const scUSDArtifact = await ethers.getContractFactory("scUSD");
  const scUSD = new ethers.Contract(
    contracts[networkName]["scUSD"],
    scUSDArtifact.interface,
    deployer
  );
  const orderbook = new ethers.Contract(
    contracts[networkName]["Orderbook"],
    OrderbookArtifact.interface,
    deployer
  );
  //deposit USDB to get scUSD
  const usdbContract = new ethers.Contract(
    contracts[networkName]["USDB"],
    USDBArtifact.interface,
    deployer
  );
  //   await (
  //     await usdbContract.approve(
  //       await scUSD.getAddress(),
  //       10000000000000000000000n
  //     )
  //   ).wait();
  //   await (
  //     await scUSD.connect(deployer).deposit(10000000000000000000000n)
  //   ).wait();
  //approve scUSD to orderbook
  await (
    await scUSD
      .connect(deployer)
      .approve(await orderbook.getAddress(), 10000000000000000000000n)
  ).wait();
  const signature = await signatureOrderBuyTrx(
    booker,
    address,
    orderType,
    outcomeId,
    price,
    value,
    orderbook
  );
  console.log("signature: ", signature);
  const tx = await (
    await orderbook.limitBuy(orderType, outcomeId, price, value, 5, signature)
  ).wait();
}

main(
  "0xc9fDdfD1582865a5eac20089Cb7088f361a2860E",
  18446744078004518914n,
  OrderType.BuyYes,
  900000,
  9000000n
)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
