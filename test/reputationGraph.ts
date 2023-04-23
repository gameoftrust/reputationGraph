import { deployReputationGraph } from "../scripts/deployers";
import { ReputationGraph, ReputationGraph__factory } from "../typechain-types";
import { expect } from "chai";
import { BigNumber, TypedDataDomain } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { signTypedData_v4, TypedData } from "eth-sig-util";
import { bufferToHex } from "ethereumjs-util";
import { ethers, network } from "hardhat";

describe("ReputationGraph", async () => {
  let reputationGraph: ReputationGraph;
  let graphId: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let admin: SignerWithAddress;
  let endorser: SignerWithAddress;
  const domain: TypedDataDomain = {
    name: "Game of Trust",
    version: "1",
  };
  
  const types = {
    RawScore: [
      { name: "topicId", type: "uint256" },
      { name: "score", type: "int8" },
      { name: "confidence", type: "uint8" },
    ],
    Endorsement: [
      { name: "timestamp", type: "uint256" },
      { name: "from", type: "address" },
      { name: "to", type: "address" },
      { name: "graphId", type: "address" },
      { name: "scores", type: "RawScore[]" },
    ],
  };

  type Score = {
    timestamp: BigNumber;
    from: string;
    to: string;
    topicId: BigNumber;
    score: Number;
    confidence: Number;
  };

  before(async () => {
    [graphId, admin, endorser, user1, user2, user3] = await ethers.getSigners();
    reputationGraph = await deployReputationGraph(admin.address, endorser.address, graphId.address, false);
  });

  it("should no be able to endorse, if not endorser", async () => {
    const e1 = {
      timestamp: 1,
      from: user1.address,
      to: user2.address,
      graphId: graphId.address,
      scores: [
        { topicId: 1, score: 10, confidence: 5 },
        { topicId: 2, score: 6, confidence: 2 },
      ],
    };
    const tx = reputationGraph.endorse(e1, user1._signTypedData(domain, types, e1));
    await expect(tx).to.be.reverted;
  });

  it("should be able to endorse, if endorser", async () => {
    const e = {
      timestamp: BigNumber.from(1),
      from: user1.address,
      to: user2.address,
      graphId: graphId.address,
      scores: [
        { topicId: BigNumber.from(1), score: 10, confidence: 5 },
        { topicId: BigNumber.from(2), score: 6, confidence: 2 },
      ],
    };

    const signature = await user1._signTypedData(domain, types, e);

    await reputationGraph.connect(endorser).endorse(e, signature);

    const score = await reputationGraph.getScores(0, 1);

    score.forEach((s, i) => {
      expect(s.timestamp).eq(e.timestamp);
      expect(s.from).eq(e.from);
      expect(s.to).eq(e.to);
      expect(s.topicId).eq(e.scores[i].topicId);
      expect(s.score).eq(e.scores[i].score);
      expect(s.confidence).eq(e.scores[i].confidence);
    });
  });

  it("should not be able to endorse with timestamp less than last", async () => {
    const e = {
      timestamp: BigNumber.from(1),
      from: user1.address,
      to: user2.address,
      graphId: graphId.address,
      scores: [
        { topicId: BigNumber.from(1), score: 10, confidence: 5 },
        { topicId: BigNumber.from(2), score: 6, confidence: 2 },
      ],
    };

    const signature = await user1._signTypedData(domain, types, e);

    const tx = reputationGraph.connect(endorser).endorse(e, signature);

    await expect(tx).to.be.revertedWithCustomError(
      reputationGraph,
      "InvalidTimestamp"
    );
  });

  it("should not be able to endorse with invalid graphId", async () => {
    const e = {
      timestamp: BigNumber.from(1),
      from: user1.address,
      to: user2.address,
      graphId: user3.address,
      scores: [
        { topicId: BigNumber.from(1), score: 10, confidence: 5 },
        { topicId: BigNumber.from(2), score: 6, confidence: 2 },
      ],
    };

    const signature = await user1._signTypedData(domain, types, e);

    const tx = reputationGraph.connect(endorser).endorse(e, signature);

    await expect(tx).to.be.revertedWithCustomError(
      reputationGraph,
      "InvalidGraphId"
    );
  });

  it("should be able to endorse with grater timestamp", async () => {
    const e = {
      timestamp: BigNumber.from(2),
      from: user1.address,
      to: user2.address,
      graphId: graphId.address,
      scores: [
        { topicId: BigNumber.from(5), score: 3, confidence: 6 },
        { topicId: BigNumber.from(9), score: 5, confidence: 8 },
      ],
    };

    const signature = await user1._signTypedData(domain, types, e);

    await reputationGraph.connect(endorser).endorse(e, signature);

    const score = await reputationGraph.getScores(2, 3);

    score.forEach((s, i) => {
      expect(s.timestamp).eq(e.timestamp);
      expect(s.from).eq(e.from);
      expect(s.to).eq(e.to);
      expect(s.topicId).eq(e.scores[i].topicId);
      expect(s.score).eq(e.scores[i].score);
      expect(s.confidence).eq(e.scores[i].confidence);
    });
  });
  it("should allow user 2 endorse", async () => {
    const e = {
      timestamp: BigNumber.from(1),
      from: user2.address,
      to: user3.address,
      graphId: graphId.address,
      scores: [
        { topicId: BigNumber.from(5), score: 3, confidence: 6 },
        { topicId: BigNumber.from(9), score: 5, confidence: 8 },
      ],
    };

    const signature = await user2._signTypedData(domain, types, e);

    await reputationGraph.connect(endorser).endorse(e, signature);

    const score = await reputationGraph.getScores(4, 5);

    score.forEach((s, i) => {
      expect(s.timestamp).eq(e.timestamp);
      expect(s.from).eq(e.from);
      expect(s.to).eq(e.to);
      expect(s.topicId).eq(e.scores[i].topicId);
      expect(s.score).eq(e.scores[i].score);
      expect(s.confidence).eq(e.scores[i].confidence);
    });
  });

  it("should not be able to update uri if not admin", async () => {
    const tx = reputationGraph.connect(endorser).setMetadataURI("test");
    await expect(tx).to.be.reverted;
  });

  it("should be able to set if admin", async () => {
    await reputationGraph.connect(admin).setMetadataURI("test");
    const uri = await reputationGraph.metadataURI();

    expect(uri).eq("test");
  });
});
