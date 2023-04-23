import hre, { ethers, upgrades } from "hardhat";
import { ReputationGraph } from "../typechain-types";
export async function deployReputationGraph(
  admin: string,
  endorser: string,
  graphId: string,
  verify: boolean = true
): Promise<ReputationGraph> {
  const ReputationGraphFactory = await ethers.getContractFactory("ReputationGraph");
  const args = [admin, endorser];

  // Set the deployer's address as the graphId
  const deployer = await ethers.getSigner(graphId);

  //@ts-ignore
  const reputationGraph = await ReputationGraphFactory.connect(deployer).deploy(...args);
  console.log("Reputation Graph Deployed To: ", reputationGraph.address);

  if (verify) {
    await hre.run("verify:verify", {
      address: reputationGraph.address,
      constructorArguments: args,
    });
  }

  return reputationGraph as ReputationGraph;
}
