import { expect, assert } from "chai";
import { ethers } from "hardhat";
import { Signer, Contract } from "ethers";
describe("Investment", function () {
  let owner: Signer;
  let alice, bob: Signer;
  let otcMarket, token, erc721Mock, erc1155Mock: Contract;

  const ZERO = "0x0000000000000000000000000000000000000000";
  const testOffer = {
    nftAddress: "",
    currency: "",
    tokenId: 1,
    price: 10000,
  };

  const testOffer1 = {
    nftAddress: "",
    currency: "",
    tokenId: 1,
    price: 10000,
  };

  let INITIAL = 10000;
  const taxFee = 1000;

  beforeEach(async function () {
    [owner, alice, bob] = await ethers.getSigners();

    //Mock Token Contract

    const tokenFactory = await ethers.getContractFactory("Token");
    token = await tokenFactory.deploy();

    //Mock NFT Contract

    const nftFactory = await ethers.getContractFactory("ERC1155Mock");
    erc1155Mock = await nftFactory.deploy("Name", "Symbol", "URI");

    await erc1155Mock.mint(owner.getAddress(), 1, 1, "0x");
    testOffer.currency = token.address;
    testOffer.nftAddress = erc1155Mock.address;

    const erc721Factory = await ethers.getContractFactory("ERC721Mock");
    erc721Mock = await erc721Factory.deploy("Name", "Symbol");
    await erc721Mock.mint(owner.getAddress(), 1);

    testOffer1.currency = token.address;
    testOffer1.nftAddress = erc721Mock.address;

    await token.mint(owner.getAddress(), INITIAL);
    await token.mint(alice.getAddress(), INITIAL);

    const OTCMarket = await ethers.getContractFactory("OTCMarket");
    otcMarket = await OTCMarket.deploy();
    await otcMarket.connect(owner).initialize(taxFee, bob.getAddress());
  });
  describe("constructor", () => {
    it("should set taxFee correctly", async () => {
      expect((await otcMarket.taxFee()).toString()).equal(taxFee.toString());
    });
    it("should set beneficiary address correctly", async () => {
      expect(await otcMarket.beneficiary()).equal(await bob.getAddress());
    });
  });
  describe("create Offer", () => {
    it("should create an offer correctly", async () => {
      await erc1155Mock.setApprovalForAll(otcMarket.address, true);
      await otcMarket.createOffer(
        testOffer.nftAddress,
        testOffer.currency,
        testOffer.tokenId,
        testOffer.price
      );
      expect((await otcMarket.lastOfferId()).toString()).equal("1");
    });

    it("should create an offer correctly with erc721 nft", async () => {
      await erc721Mock.approve(otcMarket.address, 1);
      await otcMarket.createOffer(
        testOffer1.nftAddress,
        testOffer1.currency,
        testOffer1.tokenId,
        testOffer1.price
      );
      expect((await otcMarket.lastOfferId()).toString()).equal("1");
    });

    it("should tranfser the nft correctly", async () => {
      expect(
        (await erc1155Mock.balanceOf(owner.getAddress(), 1)).toString()
      ).equal("1");

      await erc1155Mock.setApprovalForAll(otcMarket.address, true);
      await otcMarket.createOffer(
        testOffer.nftAddress,
        testOffer.currency,
        testOffer.tokenId,
        testOffer.price
      );
      expect(
        (await erc1155Mock.balanceOf(owner.getAddress(), 1)).toString()
      ).equal("0");
    });
  });

  describe("accept Offer", () => {
    it("should accept an offer correctly", async () => {
      await erc1155Mock.setApprovalForAll(otcMarket.address, true);
      await otcMarket.createOffer(
        testOffer.nftAddress,
        testOffer.currency,
        testOffer.tokenId,
        testOffer.price
      );

      await token
        .connect(alice)
        .approve(await otcMarket.address, testOffer.price);
      await otcMarket.connect(alice).acceptOffer(0);
    });

    it("should accept an offer correctly", async () => {
      await erc721Mock.setApprovalForAll(otcMarket.address, true);
      await otcMarket.createOffer(
        testOffer1.nftAddress,
        testOffer1.currency,
        testOffer1.tokenId,
        testOffer1.price
      );

      await token
        .connect(alice)
        .approve(await otcMarket.address, testOffer.price);
      await otcMarket.connect(alice).acceptOffer(0);
    });
  });
  describe("cancel an offer", () => {
    it("seller should cancel an offer correctly", async () => {
      await erc1155Mock.setApprovalForAll(otcMarket.address, true);
      await otcMarket.createOffer(
        testOffer.nftAddress,
        testOffer.currency,
        testOffer.tokenId,
        testOffer.price
      );
      await otcMarket.cancelOffer(0);
      expect((await otcMarket.offers(0))[0].toString()).equal("0");
      expect((await otcMarket.offers(0))[1].toString()).equal(ZERO);
    });
    it("should revert if not a seller", async () => {
      await erc1155Mock.setApprovalForAll(otcMarket.address, true);
      await otcMarket.createOffer(
        testOffer.nftAddress,
        testOffer.currency,
        testOffer.tokenId,
        testOffer.price
      );
      await expect(otcMarket.connect(bob).cancelOffer(0)).to.be.revertedWith(
        "NOT_A_SELLER"
      );
    });
  });
  describe("set beneficiary ", () => {
    it("should set beneficiary address correctly", async () => {
      expect(await otcMarket.beneficiary()).equal(await bob.getAddress());

      await otcMarket.connect(bob).setBeneficiary(await alice.getAddress());

      expect(await otcMarket.beneficiary()).equal(await alice.getAddress());
    });
  });
  describe("set fee", () => {
    it("should set new fee value correctly", async () => {
      expect((await otcMarket.taxFee()).toString()).equal(taxFee.toString());

      await otcMarket.connect(owner).setFee(taxFee * 2);

      // expect((await otcMarket.taxFee()).toString()).equal(
      //   (taxFee * 2).toString()
      // );
    });
    it("should revert if not an owner", async () => {
      await expect(otcMarket.connect(bob).setFee(0)).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
  });

  describe("withdraw", () => {
    it("should withdraw to beneficiary address correctly", async () => {
      // Create Offer
      await erc1155Mock.setApprovalForAll(otcMarket.address, true);
      await otcMarket.createOffer(
        testOffer.nftAddress,
        testOffer.currency,
        testOffer.tokenId,
        testOffer.price
      );

      // Accept Offer
      await token
        .connect(alice)
        .approve(await otcMarket.address, testOffer.price);
      await otcMarket.connect(alice).acceptOffer(0);

      expect((await token.balanceOf(otcMarket.address)).toString()).equal(
        "1000"
      );
      expect((await token.balanceOf(await bob.getAddress())).toString()).equal(
        "0"
      );

      await otcMarket.connect(bob).withdraw(token.address);
      expect((await token.balanceOf(await bob.getAddress())).toString()).equal(
        "1000"
      );
      expect((await token.balanceOf(otcMarket.address)).toString()).equal("0");
    });
  });
});
