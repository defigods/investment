import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer, Contract } from "ethers";
describe("Claiming", function () {
  let owner: Signer;
  let alice, bob: Signer;
  let claimContract, investContract, token: Contract;

  const testPool = {
    name: "Test",
    contractAddress: "0x0000000000000000000000000000000000000000",
    tokenId: "1",
    totalAmount: "10",
    rewardToken: "0x0000000000000000000000000000000000000000",
    rewardAmount: "2000",
  };

  const testInvestmentPool = {
    name: "Test Pool",
    _paymentToken: "0x0000000000000000000000000000000000000000",
    best_price: 1,
  };

  const purcaseInfo = { pid: "1", amount: "5", data: "0x" };
  const uri = "https://mikelin-api.vercel.app/api/";

  let INITIAL = 10000;
  beforeEach(async function () {
    [owner, alice, bob] = await ethers.getSigners();

    //Mock Token Contract

    const tokenFactory = await ethers.getContractFactory("Token");
    token = await tokenFactory.deploy();

    testPool.rewardToken = token.address;
    testInvestmentPool._paymentToken = token.address;

    // Investment
    const Investment = await ethers.getContractFactory("Investment");
    investContract = await Investment.deploy(uri);

    await investContract.createPool(
      testInvestmentPool.name,
      testInvestmentPool._paymentToken,
      testInvestmentPool.best_price
    );

    await token.mint(owner.getAddress(), INITIAL);
    await token.mint(alice.getAddress(), INITIAL);

    // Invest
    await token
      .connect(alice)
      .approve(investContract.address, testInvestmentPool.best_price * 5);
    await investContract.connect(alice).purchaseNFT(1, 5, "0x");

    //

    const Claiming = await ethers.getContractFactory("Claiming");
    claimContract = await Claiming.deploy();

    testPool.contractAddress = investContract.address;

    console.log("aaa", testPool.contractAddress);
  });
  describe("constructor", () => {
    it("should set owner correctly", async () => {
      expect(await claimContract.owner()).equal(await owner.getAddress());
    });
  });

  describe("createPool", () => {
    it("should create Pool correctly", async () => {
      await token
        .connect(owner)
        .approve(claimContract.address, testPool.rewardAmount);

      await claimContract.createPool(
        testPool.name,
        testPool.contractAddress,
        testPool.tokenId,
        testPool.totalAmount,
        testPool.rewardToken,
        testPool.rewardAmount
      );

      console.log("claim", await claimContract._pools(1));
      expect((await claimContract._currentPoolId()).toString()).equal("1");
      expect((await claimContract._pools(1))[0]).equals(testPool.name);
      expect((await claimContract._pools(1))[1]).equals(
        testPool.contractAddress
      );

      expect((await claimContract._pools(1))[2].toString()).equals(
        testPool.tokenId
      );
      expect((await claimContract._pools(1))[3].toString()).equals(
        testPool.totalAmount
      );

      expect((await claimContract._pools(1))[4].toString()).equals(
        testPool.rewardToken
      );
      expect((await claimContract._pools(1))[5].toString()).equals(
        testPool.rewardAmount
      );
    });
  });
  describe("createPool", () => {
    it("should claim correct amount", async () => {
      // Approve
      await token
        .connect(owner)
        .approve(claimContract.address, testPool.rewardAmount);

      //Create Pool for claim
      await claimContract.createPool(
        testPool.name,
        testPool.contractAddress,
        testPool.tokenId,
        testPool.totalAmount,
        testPool.rewardToken,
        testPool.rewardAmount
      );

      expect(
        (
          await investContract.balanceOf(
            await alice.getAddress(),
            purcaseInfo.pid
          )
        ).toString()
      ).equal("5");

      await investContract
        .connect(alice)
        .setApprovalForAll(claimContract.address, true);

      // Claim
      await claimContract.connect(alice).claim("1");
      expect(
        (
          await investContract.balanceOf(
            await alice.getAddress(),
            purcaseInfo.pid
          )
        ).toString()
      ).equal("0");
    });
  });
});
