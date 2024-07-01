import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { Contract, MaxUint256 } from "ethers";
import { ethers, upgrades } from "hardhat";

describe("OrderBook", () => {
  enum OrderType {
    BuyYes = 0,
    SellYes = 1,
    BuyNo = 2,
    SellNo = 3,
  }
  async function deployOrderBook() {
    const [owner, otherAccount, otherAccount1, otherAccount2] =
      await ethers.getSigners();
    const Bookie = await ethers.getContractFactory("Bookie", owner);
    const bookie = await upgrades.deployProxy(Bookie, [], {
      initializer: "initialize",
    });
    const USDB = await ethers.getContractFactory("MockUSDC");
    const initialSupply = 10000000000000000000000000000n;
    const usdb = await USDB.deploy(initialSupply);
    await usdb.waitForDeployment();
    const Events = await ethers.getContractFactory("Events");
    const events = await upgrades.deployProxy(
      Events,
      [await bookie.getAddress()],
      {}
    );
    const SignatureValiator = await ethers.getContractFactory(
      "SignatureValidator"
    );
    const signatureValiator = await upgrades.deployProxy(
      SignatureValiator,
      [await bookie.getAddress()],
      { initializer: "initialize" }
    );
    const OrderBook = await ethers.getContractFactory("OrderbookBlast");
    const orderBook = await upgrades.deployProxy(
      OrderBook,
      [
        await bookie.getAddress(),
        await events.getAddress(),
        await signatureValiator.getAddress(),
        await usdb.getAddress(),
      ],
      { initializer: "initialize" }
    );
    const Batching = await ethers.getContractFactory("Batching");
    const batching = await upgrades.deployProxy(
      Batching,
      [await bookie.getAddress(), await orderBook.getAddress()],
      {
        initializer: "initialize",
      }
    );
    await grantRole(bookie, owner, batching, orderBook, events);
    return {
      events,
      orderBook,
      bookie,
      owner,
      otherAccount,
      otherAccount1,
      otherAccount2,
      batching,
      usdb,
    };
  }

  async function grantRole(
    bookie: Contract,
    owner: HardhatEthersSigner,
    batching: Contract,
    orderBook: Contract,
    events: Contract
  ) {
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
    const ORDERBOOK_BATCHER_ROLE = ethers.solidityPackedKeccak256(
      ["string"],
      ["ORDERBOOK_BATCHER_ROLE"]
    );
    const BLAST_POINT_OPERATOR_ROLE = ethers.solidityPackedKeccak256(
      ["string"],
      ["BLAST_POINT_OPERATOR_ROLE"]
    );
    const EVENT_CONTRACT = ethers.solidityPackedKeccak256(
      ["string"],
      ["EVENT_CONTRACT"]
    );
    const BATCHING = ethers.solidityPackedKeccak256(["string"], ["BATCHING"]);
    const ORDERBOOK = ethers.solidityPackedKeccak256(["string"], ["ORDERBOOK"]);
    await (await bookie.grantRole(RESOLVER_ROLE, owner.address)).wait();
    await (await bookie.grantRole(BOOKER_ROLE, owner.address)).wait();
    await (
      await bookie.grantRole(ORDERBOOK_BATCHER_ROLE, owner.address)
    ).wait();
    await (
      await bookie.setAddress(BATCHING, await batching.getAddress())
    ).wait();
    await (
      await bookie.setAddress(ORDERBOOK, await orderBook.getAddress())
    ).wait();
    await (
      await bookie.setAddress(EVENT_CONTRACT, await events.getAddress())
    ).wait();
    await (await bookie.grantRole(BLAST_POINT_OPERATOR_ROLE, owner)).wait();
    // await (await orderBook.connect(owner).configurePointsOperator()).wait();
  }

  async function signatureOrderBuyTrx(
    booker: HardhatEthersSigner,
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

  async function signatureMarketBuyTrx(
    booker: HardhatEthersSigner,
    address: string,
    orderType: OrderType,
    outcomeId: BigInt,
    amount: number,
    expireTime: number,
    matchingOrderIds: Array<number>,
    contract: Contract
  ) {
    try {
      const message = ethers.getBytes(
        ethers.keccak256(
          ethers.solidityPacked(
            [
              "address",
              "address",
              "uint8",
              "uint256",
              "uint256",
              "uint256",
              "uint256[]",
            ],
            [
              await contract.getAddress(),
              address,
              orderType,
              outcomeId,
              amount,
              expireTime,
              matchingOrderIds,
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

  async function signatureOrderSellTrx(
    booker: HardhatEthersSigner,
    address: string,
    orderType: OrderType,
    outcomeId: BigInt,
    price: number,
    amount: number,
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
              amount,
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

  async function signatureClaim(
    booker: HardhatEthersSigner,
    address: string,
    eventId: number,
    contract: Contract
  ) {
    try {
      const message = ethers.getBytes(
        ethers.keccak256(
          ethers.solidityPacked(
            ["address", "address", "uint32"],
            [await contract.getAddress(), address, eventId]
          )
        )
      );
      return await booker.signMessage(message);
    } catch (error) {
      console.log("🚀 ~ OrderbookContract ~ error:", error);
      throw error;
    }
  }

  async function fundUser(
    owner: HardhatEthersSigner,
    usdb: any,
    amount: number,
    address: string
  ) {
    await (await usdb.connect(owner).transfer(address, BigInt(amount))).wait();
  }

  it.only("Should deploy OrderBook success", async () => {
    const {
      events,
      orderBook,
      bookie,
      owner,
      otherAccount,
      otherAccount1,
      otherAccount2,
    } = await deployOrderBook();
  });
  it("Should create event success", async () => {
    const {
      events,
      orderBook,
      bookie,
      owner,
      otherAccount,
      otherAccount1,
      otherAccount2,
    } = await deployOrderBook();
    const startTime = Math.floor(new Date().getTime() / 1000);
    const endTime = Math.floor(new Date("2024-03-30").getTime() / 1000);
    await (
      await events.createEvent(2, BigInt(startTime), BigInt(endTime))
    ).wait();
  });
  it.only("Should full flow success", async () => {
    const {
      events,
      orderBook,
      bookie,
      owner,
      otherAccount,
      otherAccount1,
      otherAccount2,
      batching,
      usdb,
    } = await deployOrderBook();
    console.log("Create event ....");
    const startTime = Math.floor(new Date().getTime() / 1000);
    const endTime = Math.floor(new Date("2024-06-30").getTime() / 1000);
    const eventId = 26;
    const outcomeIds = [479615346028117491743n];
    await (
      await events.createEvent(
        eventId,
        outcomeIds,
        BigInt(startTime),
        BigInt(endTime)
      )
    ).wait();
    console.log("Fund user ...");
    await fundUser(owner, usdb, 1000 * 10 ** 18, otherAccount.address);
    await fundUser(owner, usdb, 1000 * 10 ** 18, otherAccount1.address);
    await fundUser(owner, usdb, 1000 * 10 ** 18, otherAccount2.address);

    console.log("approve value ...");
    await (
      await usdb
        .connect(otherAccount)
        .approve(await orderBook.getAddress(), MaxUint256)
    ).wait();
    await (
      await usdb
        .connect(otherAccount1)
        .approve(await orderBook.getAddress(), MaxUint256)
    ).wait();
    await (
      await usdb
        .connect(otherAccount2)
        .approve(await orderBook.getAddress(), MaxUint256)
    ).wait();
    console.log("Create order buy yes...");
    let orderType = OrderType.BuyYes;
    let olId = 1;
    let outcomeId = 479615346028117491743n;
    let price = 0.2 * 10 ** 6;
    let shares = 5;
    let bfee = 0;
    let value = price * shares + (price * shares * bfee) / 1000;
    console.log("value ...", value);
    let signature = await signatureOrderBuyTrx(
      owner,
      otherAccount.address,
      orderType,
      BigInt(outcomeId),
      price,
      BigInt(value),
      orderBook
    );
    const tx = await (
      await orderBook
        .connect(otherAccount)
        .limitBuy(
          orderType,
          BigInt(outcomeId),
          BigInt(price),
          BigInt(value),
          BigInt(olId),
          signature
        )
    ).wait();
    console.log("Create order buy no...");
    orderType = OrderType.BuyNo;
    olId = 2;
    outcomeId = 479615346028117491743n;
    price = 0.8 * 10 ** 6;
    shares = 5;
    value = price * shares + (price * shares * bfee) / 1000;

    signature = await signatureOrderBuyTrx(
      owner,
      otherAccount1.address,
      orderType,
      BigInt(outcomeId),
      price,
      BigInt(value),
      orderBook
    );
    await (
      await orderBook
        .connect(otherAccount1)
        .limitBuy(
          orderType,
          BigInt(outcomeId),
          BigInt(price),
          BigInt(value),
          BigInt(olId),
          signature
        )
    ).wait();
    console.log("Matching order ...");
    await (await batching.matchingLimit([1], [OrderType.BuyYes], [[2]])).wait();
    console.log("Resolve event ...");
    await (await events.settleOutcomes(eventId, outcomeIds, [2], 3)).wait();
    console.log("get claim event ...");
    const claimable = await orderBook
      .connect(otherAccount)
      .getClaimEvent(eventId, [1], otherAccount.address);
    console.log("claimable ...", claimable);
    signature = await signatureClaim(
      owner,
      otherAccount.address,
      eventId,
      orderBook
    );
    const claimable1 = await orderBook
      .connect(otherAccount)
      .getClaimEvent(eventId, [1], otherAccount.address);
    console.log("claimable1 ...", claimable1);
  });
  it.only("Should marketBuy success", async () => {
    const {
      events,
      orderBook,
      bookie,
      owner,
      otherAccount,
      otherAccount1,
      otherAccount2,
      batching,
      usdb,
    } = await deployOrderBook();
    console.log("Create event ....");
    const startTime = Math.floor(new Date().getTime() / 1000);
    const endTime = Math.floor(new Date("2024-06-30").getTime() / 1000);
    const eventId = 26;
    const outcomeIds = [479615346028117491743n];
    await (
      await events.createEvent(
        eventId,
        outcomeIds,
        BigInt(startTime),
        BigInt(endTime)
      )
    ).wait();
    console.log("Fund user ...");
    await fundUser(owner, usdb, 1000 * 10 ** 18, otherAccount.address);
    await fundUser(owner, usdb, 1000 * 10 ** 18, otherAccount1.address);
    await fundUser(owner, usdb, 1000 * 10 ** 18, otherAccount2.address);

    console.log("approve value ...");
    await (
      await usdb
        .connect(otherAccount)
        .approve(await orderBook.getAddress(), MaxUint256)
    ).wait();
    await (
      await usdb
        .connect(otherAccount1)
        .approve(await orderBook.getAddress(), MaxUint256)
    ).wait();
    await (
      await usdb
        .connect(otherAccount2)
        .approve(await orderBook.getAddress(), MaxUint256)
    ).wait();
    console.log("Create order buy yes...");
    let orderType = OrderType.BuyYes;
    let olId = 1;
    let outcomeId = 479615346028117491743n;
    let price = 0.2 * 10 ** 6;
    let shares = 5;
    let bfee = 0;
    let value = price * shares + (price * shares * bfee) / 1000;
    console.log("value ...", value);
    let signature = await signatureOrderBuyTrx(
      owner,
      otherAccount.address,
      orderType,
      BigInt(outcomeId),
      price,
      BigInt(value),
      orderBook
    );
    const tx = await (
      await orderBook
        .connect(otherAccount)
        .limitBuy(
          orderType,
          BigInt(outcomeId),
          BigInt(price),
          BigInt(value),
          BigInt(olId),
          signature
        )
    ).wait();
    console.log("Create order buy no...");
    orderType = OrderType.BuyNo;
    olId = 2;
    outcomeId = 479615346028117491743n;
    price = 0.8 * 10 ** 6;
    shares = 5;
    value = price * shares + (price * shares * bfee) / 1000;

    signature = await signatureOrderBuyTrx(
      owner,
      otherAccount1.address,
      orderType,
      BigInt(outcomeId),
      price,
      BigInt(value),
      orderBook
    );
    await (
      await orderBook
        .connect(otherAccount1)
        .limitBuy(
          orderType,
          BigInt(outcomeId),
          BigInt(price),
          BigInt(value),
          BigInt(olId),
          signature
        )
    ).wait();
    console.log("Matching order ...");
    await (await batching.matchingLimit([1], [OrderType.BuyYes], [[2]])).wait();
    const position = await orderBook.getCurOutcomePosition(
      outcomeId,
      otherAccount.address
    );
    const position1 = await orderBook.getCurOutcomePosition(
      outcomeId,
      otherAccount1.address
    );
    console.log("otherAccount position ...", position);
    console.log("otherAccount1 position ...", position1);
    console.log("OtherAccount sell the share ....");
    orderType = OrderType.SellYes;
    olId = 3;
    price = 0.6 * 10 ** 6;
    shares = 5 * 10 ** 6;
    signature = await signatureOrderSellTrx(
      owner,
      otherAccount.address,
      orderType,
      BigInt(outcomeId),
      price,
      shares,
      orderBook
    );
    await (
      await orderBook
        .connect(otherAccount)
        .limitSell(
          orderType,
          BigInt(outcomeId),
          BigInt(price),
          BigInt(shares),
          BigInt(olId),
          signature
        )
    ).wait();
    console.log("Limit sell done ...");
    console.log("Market buy ...");
    let amount = 5 * 10 ** 6;
    orderType = OrderType.BuyYes;
    olId = 4;
    let currentTime = new Date();
    currentTime.setSeconds(currentTime.getSeconds() + 120);
    let expireTime = Math.floor(currentTime.getTime() / 1000);
    signature = await signatureMarketBuyTrx(
      owner,
      otherAccount2.address,
      orderType,
      BigInt(outcomeId),
      amount,
      expireTime,
      [3],
      orderBook
    );
    await (
      await orderBook
        .connect(otherAccount2)
        .marketBuy(
          orderType,
          olId,
          BigInt(outcomeId),
          BigInt(amount),
          BigInt(expireTime),
          [3],
          signature
        )
    ).wait();
    console.log("market buy done ...");

    const position2 = await orderBook.getCurOutcomePosition(
      outcomeId,
      otherAccount2.address
    );
    console.log("otherAccount2 outcome position ...", position2);
  });
});
