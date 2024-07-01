import { ethers, network } from "hardhat";
import axios from "axios";

const main = async () => {
  const challenge = await axios.post(
    "https://waitlist-api.develop.testblast.io/v1/dapp-auth/challenge",
    {
      contractAddress: "0x310c7DdC2dFcee87028bB96c7e4f4B2B0F1D6BF2",
      operatorAddress: "0xAF2D96d3FE6bA02a508aa136fA73216755D7e750",
    }
  );
  const operatorPk = process.env.BLAST_OPERATOR_ADDRESS_PK;
  const operator = new ethers.Wallet(operatorPk ?? "", ethers.provider);
  const signature = await operator.signMessage(challenge.data.message);
  console.log("challenge ========", challenge.data.challengeData);
  console.log("signature ========", signature);
  // solve the challenge data
  const solve = await axios.post(
    "https://waitlist-api.develop.testblast.io/v1/dapp-auth/solve",
    {
      challengeData: challenge.data.challengeData,
      signature: signature,
    }
  );
  console.log("solve ========", solve.data);
  // get the contract point balance
  const balance = await axios.get(
    "https://waitlist-api.develop.testblast.io/v1/contracts/0x310c7DdC2dFcee87028bB96c7e4f4B2B0F1D6BF2/point-balances",
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${solve.data.bearerToken}`,
      },
    }
  );
  console.log("balance ========", balance.data);
  return signature;
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.log("error ========", error);
    process.exit(1);
  });
