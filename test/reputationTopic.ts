import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { ReputationTopic } from "../typechain-types";
import { expect } from "chai";

describe("ReputationTopic", async () => {
  let reputationTopic: ReputationTopic;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;

  async function deployReputationTopic() {
    const Factory = await ethers.getContractFactory("ReputationTopic");
    reputationTopic = await Factory.deploy();
    await reputationTopic.deployed();
  }

  before(async () => {
    [user1, user2, user3] = await ethers.getSigners();
    await deployReputationTopic();
  });

  it("should create a new topic", async () => {
    await reputationTopic.safeMint(user1.address, "Topic 1", "uri");
    const title = await reputationTopic.tokenTitle(0);
    const uri = await reputationTopic.tokenURI(0);

    expect(title).eq("Topic 1");
    expect(uri).eq("uri");
  });
  it("should not allow non-owner to change uri", async () => {
    const tx = reputationTopic.connect(user2).setTokenURI(0, "uri2");
    await expect(tx).to.be.revertedWith(
      "ReputationTopic: Only Owner Or Approved"
    );
  });
  it("should allow to owner to change uri", async () => {
    await reputationTopic.setTokenURI(0, "uri2");
    const uri = await reputationTopic.tokenURI(0);
    expect(uri).eq("uri2");
  });
  it("should be able to change title if not finalized", async () => {
    await reputationTopic.setTitle(0, "new title");
    const newTitle = await reputationTopic.tokenTitle(0);

    expect(newTitle).eq("new title");
  });
  it("should now allow non-owner to set title", async () => {
    const tx = reputationTopic.connect(user2).setTitle(0, "new2");
    await expect(tx).to.be.reverted;
  });
  it("should not allow non-owner to finalize token", async () => {
    const tx = reputationTopic.connect(user2).finalize(0);
    await expect(tx).to.be.reverted;
  });
  it("should allow owner to finalize token", async () => {
    await reputationTopic.finalize(0);
    const isFinalized = await reputationTopic.isFinalized(0);

    expect(isFinalized).to.be.true;
  });
  it("should not be able to finalized already finalized token", async () => {
    const tx = reputationTopic.finalize(0);
    await expect(tx).to.be.reverted;
  });
  it("should not be able to change title if finalized", async () => {
    const tx = reputationTopic.setTitle(0, "new3");

    await expect(tx).to.be.reverted;
  });
});
