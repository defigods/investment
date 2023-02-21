import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer, Contract } from "ethers";
describe("Investment", function () {
  let owner: Signer;
  let alice, bob: Signer;
  let investContract, token: Contract;

  const uri = "https://mikelin-api.vercel.app/api/";
  const _uri = "https://mikelin-api.vercel.app/apis/";

  const ZERO = "0x0000000000000000000000000000000000000000";
  const testPool = {
    name: "Test",
    _paymentToken: ZERO,
    best_price: "1",
  };

  const purcaseInfo = { pid: "1", amount: "5", data: "0x" };
  let INITIAL = 10000;
  beforeEach(async function () {
    [owner, alice, bob] = await ethers.getSigners();

    //Mock Token Contract

    const tokenFactory = await ethers.getContractFactory("Token");
    token = await tokenFactory.deploy();

    testPool._paymentToken = token.address;

    // await token.mint(owner.getAddress(), INITIAL);
    await token.mint(alice.getAddress(), INITIAL);

    const Investment = await ethers.getContractFactory("Investment");
    investContract = await Investment.deploy(uri);
  });
  describe("constructor", () => {
    it("should set uri correctly", async () => {
      expect(await investContract._uri()).equal(uri);
    });
  });
  describe("setURI", () => {
    it("should update uri correctly", async () => {
      await investContract.setURI(_uri);
      expect(await investContract._uri()).equal(_uri);
    });
  });
  describe("createPool", () => {
    it("should create Pool correctly", async () => {
      await investContract.createPool(
        testPool.name,
        testPool._paymentToken,
        testPool.best_price
      );

      expect((await investContract._currentPoolId()).toString()).equal("1");
      expect((await investContract._pools(1))[0]).equals(testPool.name);
      expect((await investContract._pools(1))[1].toString()).equals(
        (await investContract._currentPoolId()).toString()
      );
      expect((await investContract._pools(1))[2].toString()).equals(
        testPool.best_price
      );
      expect((await investContract._pools(1))[3]).equals(
        testPool._paymentToken
      );
    });
  });
  describe("purchaseNFT", () => {
    it("should purchase NFT correctly", async () => {
      await investContract.createPool(
        testPool.name,
        testPool._paymentToken,
        testPool.best_price
      );

      console.log("pools", await investContract._pools(1));
      expect((await token.balanceOf(investContract.address)).toString()).equal(
        "0"
      );

      await token.connect(alice).approve(investContract.address, "5");

      await investContract
        .connect(alice)
        .purchaseNFT(purcaseInfo.pid, purcaseInfo.amount, purcaseInfo.data);
      expect((await token.balanceOf(investContract.address)).toString()).equal(
        "5"
      );
      expect(
        (
          await investContract.balanceOf(
            await alice.getAddress(),
            purcaseInfo.pid
          )
        ).toString()
      ).equal(purcaseInfo.amount);

      // Test Withdraw

      await investContract.withdraw(token.address, await bob.getAddress(), "1");
      expect((await token.balanceOf(investContract.address)).toString()).equal(
        "4"
      );
      expect((await token.balanceOf(await bob.getAddress())).toString()).equal(
        "1"
      );

      //ETH_WITHDRAW TEST
      await investContract.withdraw(ZERO, await bob.getAddress(), "0");
    });
  });
});
