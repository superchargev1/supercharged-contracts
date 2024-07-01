import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { MaxInt256 } from "ethers";

describe("X1000V2", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployX1000V2Fixture() {
    const [owner, otherAccount] = await ethers.getSigners();
    //deploy Bookie
    const Bookie = await ethers.getContractFactory("Bookie", owner);
    const bookie = await upgrades.deployProxy(Bookie, [], {
      initializer: "initialize",
    });
    //deploy mockUSDC
    const MockUSDC = await ethers.getContractFactory("MockUSDC", owner);
    const mockUSDC = await MockUSDC.deploy(10000000000000000000000000n);
    //deploy Credit
    const scUSD = await ethers.getContractFactory("scUSD", owner);
    const scUSDContract = await upgrades.deployProxy(
      scUSD,
      [owner.address, await mockUSDC.getAddress()],
      {
        initializer: "initialize",
      }
    );
    //deploy x1000
    const X1000V2 = await ethers.getContractFactory("X1000V2", owner);
    const x1000V2 = await upgrades.deployProxy(
      X1000V2,
      [await bookie.getAddress(), await scUSDContract.getAddress()],
      {
        initializer: "initialize",
      }
    );
    await x1000V2.waitForDeployment();
    //deploy batching
    const Batching = await ethers.getContractFactory("Batching", owner);
    const batching = await upgrades.deployProxy(
      Batching,
      [await bookie.getAddress(), await x1000V2.getAddress()],
      {
        initializer: "initialize",
      }
    );
    await batching.waitForDeployment();
    //set exclude
    await (
      await scUSDContract.setExcludeFromLimit(await x1000V2.getAddress(), true)
    ).wait();
    await (
      await scUSDContract.setExcludeFromLimit(await scUSDContract.getAddress(), true)
    ).wait();
    return { x1000V2, bookie, mockUSDC, batching, nUSD: scUSDContract, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should deploy success", async function () {
      const {
        x1000V2,
        bookie,
        mockUSDC,
        batching,
        credit,
        owner,
        otherAccount,
      } = await loadFixture(deployX1000V2Fixture);
    });
    it("Should topup system success", async function () {
      const {
        x1000V2,
        bookie,
        mockUSDC,
        batching,
        credit,
        owner,
        otherAccount,
      } = await loadFixture(deployX1000V2Fixture);
      await (
        await mockUSDC
          .connect(owner)
          .approve(await credit.getAddress(), 1000000000000)
      ).wait();
      expect(
        await mockUSDC.allowance(
          await owner.getAddress(),
          await credit.getAddress()
        )
      ).to.eq(1000000000000);
      await (await credit.topupSystem(1000000000000)).wait();
      expect(await credit.platformCredit()).to.equal(1000000000000);
    });
    // it.only("Should topup user success", async function () {
    //   const { x1000V2, bookie, mockUSDC, credit, owner, otherAccount } =
    //     await loadFixture(deployX1000V2Fixture);
    //   await (
    //     await mockUSDC
    //       .connect(owner)
    //       .approve(await credit.getAddress(), 1000000000000)
    //   ).wait();
    //   expect(
    //     await mockUSDC.allowance(
    //       await owner.getAddress(),
    //       await credit.getAddress()
    //     )
    //   ).to.eq(1000000000000);
    //   await (
    //     await mockUSDC.setTransferable(await credit.getAddress(), true)
    //   ).wait();
    //   await (await credit.topupSystem(1000000000000)).wait();
    //   expect(await credit.platformCredit()).to.equal(1000000000000);
    //   //fund mockUSDC to user
    //   await (
    //     await mockUSDC.connect(owner).transfer(otherAccount.address, 1000000000)
    //   ).wait();
    //   //approve mockUSDC to credit
    //   await (
    //     await mockUSDC
    //       .connect(otherAccount)
    //       .approve(await credit.getAddress(), 1000000000)
    //   ).wait();
    //   //topup user
    //   await (await credit.connect(otherAccount).topup(1000000000)).wait();
    //   expect(await credit.getCredit(otherAccount.address)).to.equal(1000000000);
    // });
    it.only("Should open position success", async function () {
      const { x1000V2, bookie, mockUSDC, batching, nUSD, owner, otherAccount } =
        await loadFixture(deployX1000V2Fixture);
      //funding usdb to x1000
      await (
        await mockUSDC
          .connect(owner)
          .approve(await x1000V2.getAddress(), 1000000000000000000000n)
      ).wait();
      await (
        await x1000V2.connect(owner).fundingTo(1000000000000000000000n)
      ).wait();
      //funding usdb to user
      await (
        await mockUSDC
          .connect(owner)
          .transfer(otherAccount.address, 1000000000000000000000n)
      ).wait();
      //deposit
      await (
        await mockUSDC
          .connect(otherAccount)
          .approve(await nUSD.getAddress(), 500000000000000000000n)
      ).wait();
      await await nUSD.connect(otherAccount).deposit(500000000000000000000n);
      // check the balance
      console.log("balance: ", await nUSD.balanceOf(otherAccount.address));
      expect(await nUSD.balanceOf(otherAccount.address)).to.eq(500000000n);
      //grant role
      const X1000 = ethers.solidityPackedKeccak256(["string"], ["X1000V2"]);
      const BATCHING = ethers.solidityPackedKeccak256(["string"], ["BATCHING"]);
      await (await bookie.setAddress(X1000, await x1000V2.getAddress())).wait();
      await (
        await bookie.grantRole(
          ethers.solidityPackedKeccak256(["string"], ["X1000_BATCHER_ROLE"]),
          otherAccount.address
        )
      ).wait();
      await (
        await bookie.grantRole(
          ethers.solidityPackedKeccak256(
            ["string"],
            ["X1000_BATCHER_CLOSE_ROLE"]
          ),
          otherAccount.address
        )
      ).wait();
      await (
        await bookie.setAddress(BATCHING, await batching.getAddress())
      ).wait();
      //approve for x1000 contract spend maxint
      await (
        await nUSD
          .connect(otherAccount)
          .approve(await x1000V2.getAddress(), MaxInt256)
      ).wait();
      //open position
      await (
        await batching.connect(otherAccount).openBatchPosition([
          {
            plId: 1,
            account: otherAccount.address,
            poolId: ethers.encodeBytes32String("ETH"),
            value: 100000000,
            leverage: 100000000,
            price: 2322420000,
            isLong: true,
          },
        ])
      ).wait();
    });
    it.only("Should funding contract success", async function () {
      const { x1000V2, bookie, mockUSDC, batching, nUSD, owner, otherAccount } =
        await loadFixture(deployX1000V2Fixture);
      await (
        await mockUSDC
          .connect(owner)
          .approve(await x1000V2.getAddress(), 1000000000000000000000n)
      ).wait();
      //check the allowance
      expect(
        await mockUSDC.allowance(owner.address, await x1000V2.getAddress())
      ).to.eq(1000000000000000000000n);
      await (
        await x1000V2.connect(owner).fundingTo(1000000000000000000000n)
      ).wait();
    });
    it.only("Should deposit and daily usage success", async function () {
      const { x1000V2, bookie, mockUSDC, batching, nUSD, owner, otherAccount } =
        await loadFixture(deployX1000V2Fixture);
      //funding usdb to user
      await (
        await mockUSDC
          .connect(owner)
          .transfer(otherAccount.address, 10000000000000000000000n)
      ).wait();
      //deposit
      await (
        await mockUSDC
          .connect(otherAccount)
          .approve(await nUSD.getAddress(), 2000000000000000000000n)
      ).wait();
      await (
        await nUSD.connect(otherAccount).deposit(2000000000000000000000n)
      ).wait();
      //check the daily usage
      const usage = await nUSD.getDailyUsage(otherAccount.address);
      console.log("usage: ", usage);
      //withdraw
      await (await nUSD.connect(otherAccount).withdraw(500000000n)).wait();
      const usage1 = await nUSD.getDailyUsage(otherAccount.address);
      console.log("usage after withdraw: ", usage1);
      //grant role
      const X1000 = ethers.solidityPackedKeccak256(["string"], ["X1000V2"]);
      const BATCHING = ethers.solidityPackedKeccak256(["string"], ["BATCHING"]);
      await (await bookie.setAddress(X1000, await x1000V2.getAddress())).wait();
      await (
        await bookie.grantRole(
          ethers.solidityPackedKeccak256(["string"], ["X1000_BATCHER_ROLE"]),
          otherAccount.address
        )
      ).wait();
      await (
        await bookie.grantRole(
          ethers.solidityPackedKeccak256(
            ["string"],
            ["X1000_BATCHER_CLOSE_ROLE"]
          ),
          otherAccount.address
        )
      ).wait();
      await (
        await bookie.setAddress(BATCHING, await batching.getAddress())
      ).wait();
      //approve for x1000 contract spend maxint
      await (
        await nUSD
          .connect(otherAccount)
          .approve(await x1000V2.getAddress(), MaxInt256)
      ).wait();
      //open position
      await (
        await batching.connect(otherAccount).openBatchPosition([
          {
            plId: 1,
            account: otherAccount.address,
            poolId: ethers.encodeBytes32String("ETH"),
            value: 100000000,
            leverage: 100000000,
            price: 2322420000,
            isLong: true,
          },
        ])
      ).wait();
      //usage after openPosition
      const usage2 = await nUSD.getDailyUsage(otherAccount.address);
      console.log("usage after openPosition: ", usage2);
    });
  });
});
