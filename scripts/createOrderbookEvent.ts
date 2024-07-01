import { ethers, network } from "hardhat";
import { getContracts } from "../utils/utils";

async function main(
  eventId: number,
  outcomeIds: Array<BigInt>,
  startTime: number,
  endTime: number
) {
  const [deployer] = await ethers.getSigners();
  const networkName = network.name;
  const contracts = getContracts();
  const EventArtifact = await ethers.getContractFactory("Events");
  const event = new ethers.Contract(
    contracts[networkName]["Events"],
    EventArtifact.interface,
    deployer
  );
  const tx = await (
    await event.createEvent(
      eventId,
      outcomeIds,
      BigInt(startTime),
      BigInt(endTime)
    )
  ).wait();
}

main(
  1,
  [BigInt(1), BigInt(2)],
  Math.floor(new Date().getTime() / 1000),
  Math.floor(new Date("2024-03-30").getTime() / 1000)
)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
