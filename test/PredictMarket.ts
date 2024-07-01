import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { Contract, ethers } from "ethers";

describe("PredictMarket", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployX1000V2Fixture() {
    const [owner, otherAccount, otherAccount1, otherAccount2] =
      await ethers.getSigners();

    //deploy Bookie
    const Bookie = await ethers.getContractFactory("Bookie", owner);
    const bookie = await upgrades.deployProxy(Bookie, [], {
      initializer: "initialize",
    });
    //deploy mockUSDC
    const MockUSDC = await ethers.getContractFactory("MockUSDC", owner);
    const mockUSDC = await MockUSDC.deploy(10000000 * 10 ** 6);
    //transfer 1m to owner
    await (
      await mockUSDC.transfer(await owner.getAddress(), 1000000 * 10 ** 6)
    ).wait();
    //deploy Credit
    const Credit = await ethers.getContractFactory("Credit", owner);
    const credit = await upgrades.deployProxy(
      Credit,
      [
        await bookie.getAddress(),
        await mockUSDC.getAddress(),
        10000000,
        2000000000,
      ],
      {
        initializer: "initialize",
      }
    );
    //deploy PredictMarket
    const PredictMarket = await ethers.getContractFactory(
      "PredictMarket",
      owner
    );
    const predictMarket = await upgrades.deployProxy(
      PredictMarket,
      [await bookie.getAddress(), await credit.getAddress()],
      {
        initializer: "initialize",
      }
    );
    return {
      predictMarket,
      bookie,
      mockUSDC,
      credit,
      owner,
      otherAccount,
      otherAccount1,
      otherAccount2,
    };
  }

  async function buyPosition(
    contract: Contract,
    user: HardhatEthersSigner,
    outcome: BigInt,
    amount: BigInt,
    owner: HardhatEthersSigner
  ) {
    const message1 = ethers.getBytes(
      ethers.keccak256(
        ethers.solidityPacked(
          ["address", "address", "uint88", "uint256"],
          [await contract.getAddress(), user.address, amount, outcome]
        )
      )
    );
    const signature1 = await owner.signMessage(message1);
    await (
      await contract.connect(user).buyPosition(amount, outcome, signature1)
    ).wait();
  }

  async function sellPosition(
    contract: Contract,
    user: HardhatEthersSigner,
    posAmount: BigInt,
    outcomeId: BigInt,
    owner: HardhatEthersSigner
  ) {
    const ticketId = ethers.keccak256(
      ethers.solidityPacked(["address", "uint256"], [user.address, outcomeId])
    );
    const messageSell = ethers.getBytes(
      ethers.keccak256(
        ethers.solidityPacked(
          ["address", "address", "uint256", "uint88", "uint256"],
          [
            await contract.getAddress(),
            user.address,
            ticketId,
            posAmount,
            outcomeId,
          ]
        )
      )
    );

    const signatureSell = await owner.signMessage(messageSell);
    await (
      await contract
        .connect(user)
        .sellPosition(ticketId, posAmount, outcomeId, signatureSell)
    ).wait();
  }

  async function fundUser(
    usdcContract: Contract,
    amount: BigInt,
    user: HardhatEthersSigner,
    creditContract: Contract,
    owner: HardhatEthersSigner
  ) {
    await (
      await usdcContract.connect(owner).transfer(user.address, amount)
    ).wait();
    //approve mockUSDC to credit
    await (
      await usdcContract
        .connect(user)
        .approve(await creditContract.getAddress(), amount)
    ).wait();
    //topup user
    await (await creditContract.connect(user).topup(amount)).wait();
  }

  async function getTicketData(
    contract: Contract,
    outcomeId: BigInt,
    user: HardhatEthersSigner
  ) {
    const ticketId = ethers.keccak256(
      ethers.solidityPacked(["address", "uint256"], [user.address, outcomeId])
    );
    return await contract.getTicket(ticketId);
  }

  describe("Deployment", function () {
    it("Should deploy success", async function () {
      const { predictMarket, bookie, mockUSDC, credit, owner, otherAccount } =
        await loadFixture(deployX1000V2Fixture);
    });
    it("Should topup system success", async function () {
      const { predictMarket, bookie, mockUSDC, credit, owner, otherAccount } =
        await loadFixture(deployX1000V2Fixture);
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
    it("Should topup user success", async function () {
      const { predictMarket, bookie, mockUSDC, credit, owner, otherAccount } =
        await loadFixture(deployX1000V2Fixture);
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
      await (
        await mockUSDC.setTransferable(await credit.getAddress(), true)
      ).wait();
      await (await credit.topupSystem(1000000000000)).wait();
      expect(await credit.platformCredit()).to.equal(1000000000000);
      //fund mockUSDC to user
      await (
        await mockUSDC.connect(owner).transfer(otherAccount.address, 1000000000)
      ).wait();
      //approve mockUSDC to credit
      await (
        await mockUSDC
          .connect(otherAccount)
          .approve(await credit.getAddress(), 1000000000)
      ).wait();
      //topup user
      await (await credit.connect(otherAccount).topup(1000000000)).wait();
      expect(await credit.getCredit(otherAccount.address)).to.equal(1000000000);
    });
    it("Should create event success", async function () {
      const { predictMarket, bookie, mockUSDC, credit, owner, otherAccount } =
        await loadFixture(deployX1000V2Fixture);
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
      await (
        await mockUSDC.setTransferable(await credit.getAddress(), true)
      ).wait();
      await (await credit.topupSystem(1000000000000)).wait();
      expect(await credit.platformCredit()).to.equal(1000000000000);
      //fund mockUSDC to user
      await (
        await mockUSDC.connect(owner).transfer(otherAccount.address, 2000000000)
      ).wait();
      //approve mockUSDC to credit
      await (
        await mockUSDC
          .connect(otherAccount)
          .approve(await credit.getAddress(), 1000000000)
      ).wait();
      //topup user
      await (await credit.connect(otherAccount).topup(1000000000)).wait();
      expect(await credit.getCredit(otherAccount.address)).to.equal(1000000000);
      //create event
      const eventId = 1;
      const startTime = Math.floor(Date.now() / 1000);
      const expireTime = Math.floor(new Date("2024-02-05").getTime() / 1000);
      const marketId = 1;
      await (
        await predictMarket.createEvent(eventId, startTime, expireTime, [
          marketId,
        ])
      ).wait();
    });
    it("Should open position success", async function () {
      const { predictMarket, bookie, mockUSDC, credit, owner, otherAccount } =
        await loadFixture(deployX1000V2Fixture);
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
      await (
        await mockUSDC.setTransferable(await credit.getAddress(), true)
      ).wait();
      await (await credit.topupSystem(1000000000000)).wait();
      expect(await credit.platformCredit()).to.equal(1000000000000);
      //fund mockUSDC to user
      await (
        await mockUSDC.connect(owner).transfer(otherAccount.address, 2000000000)
      ).wait();
      //approve mockUSDC to credit
      await (
        await mockUSDC
          .connect(otherAccount)
          .approve(await credit.getAddress(), 1000000000)
      ).wait();
      //topup user
      await (await credit.connect(otherAccount).topup(1000000000)).wait();
      expect(await credit.getCredit(otherAccount.address)).to.equal(1000000000);
      //grant role
      const PREDICT_MARKET = ethers.solidityPackedKeccak256(
        ["string"],
        ["PREDICT_MARKET"]
      );
      await (
        await bookie.setAddress(
          PREDICT_MARKET,
          await predictMarket.getAddress()
        )
      ).wait();
      //create event
      const eventId = 1;
      const startTime = Math.floor(Date.now() / 1000);
      const expireTime = Math.floor(new Date("2024-02-05").getTime() / 1000);
      console.log("expireTime: ", expireTime);
      const marketId = 1;
      await (
        await predictMarket.createEvent(eventId, startTime, expireTime, [
          marketId,
        ])
      ).wait();
      //buy position
      const oddId = 1;
      let _id = BigInt(eventId);
      _id = (_id << BigInt(32)) + BigInt(marketId);
      _id = (_id << BigInt(32)) + BigInt(oddId);
      const outcomeId = ethers.parseEther(ethers.formatEther(_id));

      await (
        await predictMarket
          .connect(otherAccount)
          .buyPosition(10000000, outcomeId)
      ).wait();
      const position = await predictMarket.getPosition(1);
      console.log("position: ", position);
      expect(position[5]).to.equal(1);
    });
    it.only("Should resolve initial success", async function () {
      const {
        predictMarket,
        bookie,
        mockUSDC,
        credit,
        owner,
        otherAccount,
        otherAccount1,
        otherAccount2,
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
      await (
        await mockUSDC.setTransferable(await credit.getAddress(), true)
      ).wait();
      await (await credit.topupSystem(1000000000000)).wait();
      expect(await credit.platformCredit()).to.equal(1000000000000);
      //fund mockUSDC to user
      // await (
      //   await mockUSDC.connect(owner).transfer(otherAccount.address, 2000000000)
      // ).wait();
      // //approve mockUSDC to credit
      // await (
      //   await mockUSDC
      //     .connect(otherAccount)
      //     .approve(await credit.getAddress(), 2000000000)
      // ).wait();
      // //topup user
      // await (await credit.connect(otherAccount).topup(2000000000)).wait();
      await fundUser(
        mockUSDC as any,
        1000000000000n,
        otherAccount,
        credit,
        owner
      );
      await fundUser(
        mockUSDC as any,
        1000000000000n,
        otherAccount1,
        credit,
        owner
      );
      await fundUser(
        mockUSDC as any,
        1000000000000n,
        otherAccount2,
        credit,
        owner
      );
      //grant role
      const PREDICT_MARKET = ethers.solidityPackedKeccak256(
        ["string"],
        ["PREDICT_MARKET"]
      );
      const RESOLVER_ROLE = ethers.solidityPackedKeccak256(
        ["string"],
        ["RESOLVER_ROLE"]
      );
      const BOOKER_ROLE = ethers.solidityPackedKeccak256(
        ["string"],
        ["BOOKER_ROLE"]
      );
      await (
        await bookie.setAddress(
          PREDICT_MARKET,
          await predictMarket.getAddress()
        )
      ).wait();
      await (await bookie.grantRole(RESOLVER_ROLE, owner.address)).wait();
      await (await bookie.grantRole(BOOKER_ROLE, owner.address)).wait();
      //create event
      const eventId = 25;
      const startTime = Math.floor(Date.now() / 1000);
      const expireTime = Math.floor(new Date("2024-02-25").getTime() / 1000);
      console.log("expireTime: ", expireTime);
      await (
        await predictMarket.createEvent(
          eventId,
          startTime,
          expireTime,
          100000000000,
          [461168601971587809319n, 461168601971587809320n],
          [10000000000, 10000000000]
        )
      ).wait();

      console.log("buy 1 ===================");
      await buyPosition(
        predictMarket,
        otherAccount,
        461168601971587809319n,
        100000000n, // 100.000
        owner
      );
      await sellPosition(
        predictMarket,
        otherAccount,
        193175966n,
        461168601971587809319n,
        owner
      );
      // console.log("buy 2 ===================");
      // await buyPosition(
      //   predictMarket,
      //   otherAccount1,
      //   461168601971587809320n,
      //   100000000000n, // 100.000
      //   owner
      // );
      // console.log("buy 3 ===================");
      // await buyPosition(
      //   predictMarket,
      //   otherAccount1,
      //   461168601971587809320n,
      //   10000000000n, //10.000
      //   owner
      // );

      // const eventVolume = await predictMarket.getEventVolume(eventId);
      // const outcomeVolume = await predictMarket.getOutcomeVolume(
      //   461168601971587809320n
      // );
      // console.log("eventVolume: ", eventVolume);
      // console.log("outcomeVolume: ", outcomeVolume);
      // //sell all
      // console.log("sell 3 ======================");
      // await sellPosition(
      //   predictMarket,
      //   otherAccount1,
      //   1000348900n,
      //   461168601971587809320n,
      //   owner
      // );
      // //buy again
      // //pid 4
      // console.log("buy 4 ======================");
      // await buyPosition(
      //   predictMarket,
      //   otherAccount1,
      //   461168601971587809320n,
      //   10000000n, //10
      //   owner
      // );
      // //sell again
      // console.log("sell 4 ======================");
      // await sellPosition(
      //   predictMarket,
      //   otherAccount1,
      //   90462036382n,
      //   461168601971587809320n,
      //   owner
      // );
      // //buy again
      // //pid 5
      // console.log("buy 5 ======================");
      // await buyPosition(
      //   predictMarket,
      //   otherAccount,
      //   461168601971587809320n,
      //   10000000n, //10
      //   owner
      // );
      // //buy again
      // //pid 6
      // console.log("buy 6 ======================");
      // await buyPosition(
      //   predictMarket,
      //   otherAccount1,
      //   461168601971587809320n,
      //   100000000000n, //100.000
      //   owner
      // );
      // const ticketData = await getTicketData(
      //   predictMarket,
      //   461168601971587809320n,
      //   otherAccount
      // );
      // const eventVolume1 = await predictMarket.getEventVolume(eventId);
      // const outcomeVolume1 = await predictMarket.getOutcomeVolume(
      //   461168601971587809320n
      // );
      // console.log("eventVolume: ", eventVolume1);
      // console.log("outcomeVolume: ", outcomeVolume1);
      // console.log("ticketData: ", ticketData);
      // //sell again
      // console.log("sell 6 ======================");
      // await sellPosition(
      //   predictMarket,
      //   otherAccount,
      //   20999246n,
      //   461168601971587809320n,
      //   owner
      // );
    });
  });
});
