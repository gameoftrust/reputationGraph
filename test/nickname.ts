import { expect } from "chai";
import { ethers, network } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Nickname", function () {
  let nicknameContract: Contract;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  const domain = {
    name: "Game of Trust Nickname",
    version: "1",
  };

  before(async function () {
    const Nickname = await ethers.getContractFactory("Nickname");
    [user1, user2, user3] = await ethers.getSigners();
    nicknameContract = await Nickname.deploy();
  });

  function getNicknameTypedData(account: string, nickname: string, timestamp: number) {
    const types = {
      EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
      ],
      NicknameObject: [
        { name: "account", type: "address" },
        { name: "nickname", type: "string" },
        { name: "timestamp", type: "uint256" }
      ]
    };
    const message = {
      account,
      nickname,
      timestamp
    };
    const typedData = {
      domain,
      message,
      types,
      primaryType: "NicknameObject",
    }
    return typedData
  }

  async function getNicknameSignature(account: string, nickname: string, timestamp: number) {
    return network.provider.send("eth_signTypedData_v4", [
      account,
      JSON.stringify(getNicknameTypedData(account, nickname, timestamp)),
    ]);
  }

  it("sets a nickname with signed data", async function () {
    const nickname = "TestNick";
    const account = user1.address;
    const timestamp = Math.floor(Date.now() / 1000) - 1000;
    const signature = await getNicknameSignature(account, nickname, timestamp);
    await expect(nicknameContract.connect(user3).setNicknameWithSignedData([account, nickname, timestamp], signature))
      .to.emit(nicknameContract, "NicknameChanged")
      .withArgs(account, nickname);

    const storedNickname = await nicknameContract.addressNicknames(account);
    expect(storedNickname).to.equal(nickname);
  });

  it("should not let user 2 set the same nickname", async function () {
    const nickname = "TestNick";
    const account = user2.address;
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = await getNicknameSignature(account, nickname, timestamp);
    
    await expect(nicknameContract.setNicknameWithSignedData([account, nickname, timestamp], signature))
      .to.revertedWithCustomError(nicknameContract, "NicknameAlreadyTakenError");
  });

  it("should not let user 3 set the nickname for user 2", async function () {
    const nickname = "TestNick2";
    const account = user2.address;
    
    await expect(nicknameContract.connect(user3).setNickname(account, nickname))
      .to.revertedWithCustomError(nicknameContract, "NotWalletOwnerError");
  });

  it("should let user 2 set their nickname", async function () {
    const nickname = "TestNick2";
    const account = user2.address;
    
    await expect(nicknameContract.connect(user2).setNickname(account, nickname))
      .to.emit(nicknameContract, "NicknameChanged")
      .withArgs(account, nickname);

    const storedNickname = await nicknameContract.addressNicknames(account);
    expect(storedNickname).to.equal(nickname);
  });

  it("should not set a nickname with an invalid signature", async function () {
    const nickname = "InvalidSignature";
    const account = user1.address;
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = await getNicknameSignature(account, nickname, timestamp);
  
    await expect(nicknameContract.setNicknameWithSignedData([account, nickname, timestamp], signature.replace("a", "b")))
      .to.revertedWithCustomError(nicknameContract, "InvalidSignatureError");
  });
  
  it("prevents replay attack", async function () {
    const account = user1.address;

    const nickname1 = "TestNick3";
    const timestamp1 = Math.floor(Date.now() / 1000) - 1000;
    const sig1 = await getNicknameSignature(account, nickname1, timestamp1);

    const nickname2 = "TestNick4";
    const timestamp2 = Math.floor(Date.now() / 1000);
    const sig2 = await getNicknameSignature(account, nickname2, timestamp2);
    
    await nicknameContract.setNicknameWithSignedData([account, nickname1, timestamp1], sig1)
    await nicknameContract.setNicknameWithSignedData([account, nickname2, timestamp2], sig2)
    await expect(nicknameContract.setNicknameWithSignedData([account, nickname1, timestamp1], sig1))
      .to.revertedWithCustomError(nicknameContract, "TimestampMustBeGreaterThanTheLastUsedTimestamp");
  });

  it("can get nicknames from array", async function () {
    expect(await nicknameContract.getNicknamesArrayLength()).to.eq(4)
    expect((await nicknameContract.getNicknamesArray(1,3))[1].nickname).to.eq("TestNick3")
    expect((await nicknameContract.getNicknamesArray(1,3))[1].account).to.eq(user1.address)
  })
});
