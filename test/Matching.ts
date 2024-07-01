import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { Contract } from "ethers";
import { ethers, upgrades } from "hardhat";

describe("Matching", () => {
  async function deployMatching() {
    const [owner, otherAccount, otherAccount1, otherAccount2] =
      await ethers.getSigners();
    const Bookie = await ethers.getContractFactory("Bookie", owner);
    const bookie = await upgrades.deployProxy(Bookie, [], {
      initializer: "initialize",
    });
    const MockUSDC = await ethers.getContractFactory("MockUSDC", owner);
    const mockUSDC = await MockUSDC.deploy(10000000000000000000000000n);
    //deploy Credit
    const Credit = await ethers.getContractFactory("scUSD", owner);
    const credit = await upgrades.deployProxy(
      Credit,
      [owner.address, await mockUSDC.getAddress()],
      {
        initializer: "initialize",
      }
    );
    const Events = await ethers.getContractFactory("Events");
    const events = await upgrades.deployProxy(
      Events,
      [await bookie.getAddress()],
      {}
    );
    const OrderBook = await ethers.getContractFactory("Orderbook");
    const orderBook = await upgrades.deployProxy(
      OrderBook,
      [
        await bookie.getAddress(),
        await credit.getAddress(),
        await events.getAddress(),
      ],
      { initializer: "initialize" }
    );
    const Batching = await ethers.getContractFactory("Batching");
    const batching = await upgrades.deployProxy(
      Batching,
      [await bookie.getAddress(), await x1000v2.getAddress()],
      {
        initializer: "initialize",
      }
    );
    await (
      await batching
        .connect(owner)
        .setOrderbookContractAddress(await orderBook.getAddress())
    ).wait();

    //Deploy Matching
    const Matching = await ethers.getContractFactory("Matching");
    const matching = await upgrades.deployProxy(
      Matching,
      [await bookie.getAddress(), await orderBook.getAddress()],
      {
        initializer: "initialize",
      }
    );
    return {
      events,
      orderBook,
      bookie,
      mockUSDC,
      credit,
      owner,
      otherAccount,
      otherAccount1,
      otherAccount2,
      batching,
      matching,
    };
  }

  it.only("Should deploy success", async () => {
    const {
      events,
      orderBook,
      bookie,
      mockUSDC,
      credit,
      owner,
      otherAccount,
      otherAccount1,
      otherAccount2,
    } = await deployMatching();
  });
});
