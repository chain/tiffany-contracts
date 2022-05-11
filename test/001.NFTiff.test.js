require("dotenv").config();
const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers, getNamedAccounts, web3 } = require("hardhat");
const { getBlockTimestamp, advanceTimeAndBlock }= require('./helpers/helpers');

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const signerKey = process.env.PRIVATE_KEY;
const signerAddress = web3.eth.accounts.privateKeyToAccount(signerKey).address;
const notRevealedUri = "https://ipfs.io/ipfs/notrevealed.png";
const baseUri = "https://ipfs.io/base/";

// function fromWei(number, decimals = 18) {
//   return web3.utils.fromWei(
//     number.toString() + new Array(18 - decimals).fill(0).join("")
//   );
// }

// function decodeBase64toJson(encBody) {
//   const decodedRequestBodyString = Buffer.from(encBody, "base64");
//   return JSON.parse(decodedRequestBodyString.toString());
// }

async function getKycSignature(userAddress) {
  const message = web3.utils.soliditySha3("kyc approved", userAddress);
  const signatureObject = await web3.eth.accounts.sign(message, signerKey);
  // console.log('--- signature:', userAddress, signerAddress, signatureObject.signature);
  return signatureObject.signature;
}

describe("NFTiff Test", function () {
  const info = {
    mintPrice: web3.utils.toWei("30"),
    mintFee: (amount = 1) => web3.utils.toWei((30 * amount).toString()),
  };
  
  before(async function () {
    const namedAccounts = await getNamedAccounts();
    info.deployer = namedAccounts.deployer;
    info.deployerSigner = await ethers.provider.getSigner(info.deployer);
    info.member1 = namedAccounts.member1;
    info.member1Signer = await ethers.provider.getSigner(info.member1);
    info.member2 = namedAccounts.member2;
    info.member2Signer = await ethers.provider.getSigner(info.member2);
    info.minter1 = namedAccounts.minter1;
    info.minter1Signer = await ethers.provider.getSigner(info.minter1);
    info.minter2 = namedAccounts.minter2;
    info.minter2Signer = await ethers.provider.getSigner(info.minter2);
  });

  it("Contract Deploy", async function () {

    // NFTiff factory
    const NFTiffFactory = await ethers.getContractFactory("NFTiff");
    info.nftiff = await NFTiffFactory.deploy(notRevealedUri);
  });

  it("Check configs", async function () {
    expect(await info.nftiff.notRevealedUri()).to.equal(notRevealedUri);
    await info.nftiff.connect(info.deployerSigner).setSigner(signerAddress);
    expect(await info.nftiff.getSigner()).to.equal(signerAddress);
    expect(await info.nftiff.revealed()).to.equal(false);
    expect(await info.nftiff.isKycRequired()).to.equal(true);
    expect(await info.nftiff.presaleActive()).to.equal(false);
  });

  it("Sale test", async function () {

    // generate kyc signature
    const signature = await getKycSignature(info.member1);

    // presale not active
    await info.nftiff.connect(info.deployerSigner).setPresaleStatus(false);
    await expect(
      info.nftiff
      .connect(info.member1Signer, { value: info.mintFee(2) })
      .mint1(2, signature)
    ).to.be.reverted;

    await info.nftiff.connect(info.deployerSigner).setPresaleStatus(true);
    expect(await info.nftiff.presaleActive()).to.equal(true);

    // not added to whitelist
    expect(await info.nftiff.isWhitelisted(info.member1)).to.equal(false);
    await expect(
        info.nftiff
        .connect(info.member1Signer)
        .mint1(2, signature, { value: info.mintFee(2) })
      ).to.be.reverted;
  
    await info.nftiff.connect(info.deployerSigner).whitelistUsers([info.member1, info.member2]);
    expect(await info.nftiff.isWhitelisted(info.member1)).to.equal(true);

    // invalid kyc signature
    await expect(
        info.nftiff
        .connect(info.member2Signer)
        .mint1(2, signature, { value: info.mintFee(2) })
      ).to.be.reverted;

    // presale mint success
    await expect(
        info.nftiff
        .connect(info.member1Signer)
        .mint1(2, signature, { value: info.mintFee(2) })
      ).to.be.emit(info.nftiff, "Transfer");

    // user1 should have 2 tokens (id: [1,2])
    expect(await info.nftiff.balanceOf(info.member1)).to.equal(2);
    expect(await info.nftiff.totalSupply()).to.equal(2);
    expect(await info.nftiff.ownerOf(1)).to.equal(info.member1);
    // expect(await info.nftiff.walletOfOwner(info.member1)).to.equal([1,2]);

    // blacklist mint
    await info.nftiff.connect(info.deployerSigner).blacklistUsers([info.member1]);
    expect(await info.nftiff.isBlacklisted(info.member1)).to.equal(true);
    await expect(
        info.nftiff
        .connect(info.member1Signer)
        .mint1(2, signature, { value: info.mintFee(2) })
      ).to.be.reverted;

    // token uri
    expect(await info.nftiff.tokenURI(1)).to.equal(notRevealedUri);
    await info.nftiff.connect(info.deployerSigner).reveal();
    await info.nftiff.connect(info.deployerSigner).setBaseURI(baseUri);
    expect(await info.nftiff.tokenURI(1)).to.equal(`${baseUri}1.json`);

    // gift mint success
    await expect(
        info.nftiff
        .connect(info.deployerSigner)
        .gift(2, info.member1)
      ).to.be.emit(info.nftiff, "Transfer");

    // public sale mint
    expect(await info.nftiff.publicSaleActive()).to.equal(false);
    await expect(
        info.nftiff
        .connect(info.member2Signer)
        .mintPublic(2, { value: info.mintFee(2) })
      ).to.be.reverted;
    await info.nftiff.connect(info.deployerSigner).setPublicSaleStatus(true);
    expect(await info.nftiff.publicSaleActive()).to.equal(true);
    await expect(
        info.nftiff
        .connect(info.member2Signer)
        .mintPublic(2, { value: info.mintFee(2) })
      ).to.be.emit(info.nftiff, "Transfer");
    // can't mint blacklisted user
    await expect(
        info.nftiff
        .connect(info.member1Signer)
        .mintPublic(2, { value: info.mintFee(2) })
      ).to.be.reverted;
  });
});
