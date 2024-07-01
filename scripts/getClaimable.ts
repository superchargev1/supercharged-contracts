import { ethers, network } from "hardhat";
import { getContracts } from "../utils/utils";

const main = async () => {
  try {
    const [deployer] = await ethers.getSigners();
    const provider = deployer.provider;
    const networkName = network.name;
    const contracts = getContracts();
    const USDB = new ethers.Contract(
      contracts[networkName]["USDB"],
      [
        {
          inputs: [
            {
              internalType: "address",
              name: "account",
              type: "address",
            },
          ],
          name: "getClaimableAmount",
          outputs: [
            {
              internalType: "uint256",
              name: "",
              type: "uint256",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
      ],
      provider
    );
    const claimable = await USDB.getClaimableAmount(
      contracts[networkName]["OrderbookBlast"]
    );
    console.log("Claimable: ", claimable.toString());
  } catch (error) {
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
