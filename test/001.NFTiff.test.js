require("dotenv").config();
const helpers = require("./helpers/helpers");

const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers, getNamedAccounts, web3 } = require("hardhat");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const signerKey = process.env.PRIVATE_KEY;
const signerAddress = web3.eth.accounts.privateKeyToAccount(signerKey).address;
const notRevealedUri = "https://ipfs.io/ipfs/notrevealed.png";
const baseUri = "https://ipfs.io/base/";

async function getKycSignature(userAddress) {
  const message = web3.utils.soliditySha3("kyc-approved", userAddress);
  const signatureObject = await web3.eth.accounts.sign(message, signerKey);
  return signatureObject.signature;
}

async function getClaimSignature(punkId, nftiffId, userAddress) {
  const message = web3.utils.soliditySha3("shipping-verified", punkId, nftiffId, userAddress);
  const signatureObject = await web3.eth.accounts.sign(message, signerKey);
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

    // Deploy mock cryptopunks
    const MockCryptoPunksFactory = await ethers.getContractFactory("MockCryptoPunks");
    info.cryptopunks = await MockCryptoPunksFactory.deploy();

    // NFTiff factory
    const NFTiffFactory = await ethers.getContractFactory("NFTiff");
    info.nftiff = await NFTiffFactory.deploy(notRevealedUri, info.cryptopunks.address);
  });

  it("Check configs", async function () {
    expect(await info.nftiff.notRevealedUri()).to.equal(notRevealedUri);
    await info.nftiff.connect(info.deployerSigner).setSigner(signerAddress);
    expect(await info.nftiff.getSigner()).to.equal(signerAddress);
    expect(await info.nftiff.revealed()).to.equal(false);
    expect(await info.nftiff.isKycRequired()).to.equal(true);
    expect(await info.nftiff.presaleActive()).to.equal(false);
  });

  it("Mint test", async function () {

    // generate kyc signature
    const signature = await getKycSignature(info.member1);
    const signature2 = await getKycSignature(info.member2);

    // presale not active
    await info.nftiff.connect(info.deployerSigner).setPresaleStatus(false);
    await expect(
      info.nftiff
      .connect(info.member1Signer, { value: info.mintFee(2) })
      .mint1(2, signature)
    ).to.be.revertedWith("Sale has not started yet");

    await info.nftiff.connect(info.deployerSigner).setPresaleStatus(true);
    expect(await info.nftiff.presaleActive()).to.equal(true);
    await expect(
      info.nftiff
      .connect(info.member1Signer, { value: info.mintFee(2) })
      .mint1(2, signature)
    ).to.be.revertedWith("Presale ended");

    const curTimestamp = await helpers.getBlockTimestamp();
    await info.nftiff.connect(info.deployerSigner).setPresaleEndTimestamp(curTimestamp + 86400);
    expect(await info.nftiff.presaleEndTimestamp()).to.equal(curTimestamp + 86400);

    // not whitelisted user
    expect(await info.nftiff.whitelistedAddresses(info.member1)).to.equal(false);
    await expect(
      info.nftiff
      .connect(info.member1Signer)
      .mint1(2, signature, { value: info.mintFee(2) })
    ).to.be.revertedWith("Not whitelisted user");

    await info.nftiff.connect(info.deployerSigner).whitelistUsers([info.member1, info.member2]);
    expect(await info.nftiff.whitelistedAddresses(info.member1)).to.equal(true);

    // invalid kyc signature
    await expect(
      info.nftiff
      .connect(info.member2Signer)
      .mint1(2, signature, { value: info.mintFee(2) })
    ).to.be.revertedWith("Kyc not approved");

    // presale mint success
    await expect(
        info.nftiff
        .connect(info.member1Signer)
        .mint1(2, signature, { value: info.mintFee(2) })
      ).to.be.emit(info.nftiff, "Transfer");
    expect(await info.nftiff.whitelistMinted(info.member1)).to.equal(2);

    // user1 should have 2 tokens (id: [1,2])
    expect(await info.nftiff.balanceOf(info.member1)).to.equal(2);
    expect(await info.nftiff.totalSupply()).to.equal(2);
    expect(await info.nftiff.ownerOf(1)).to.equal(info.member1);
    // expect(await info.nftiff.walletOfOwner(info.member1)).to.equal([1,2]);

    // blacklist mint
    await info.nftiff.connect(info.deployerSigner).blacklistUsers([info.member1]);
    expect(await info.nftiff.blacklistedAddresses(info.member1)).to.equal(true);
    await expect(
        info.nftiff
        .connect(info.member1Signer)
        .mint1(2, signature, { value: info.mintFee(2) })
      ).to.be.revertedWith("Blacklisted user");

    // token uri
    expect(await info.nftiff.tokenURI(1)).to.equal(notRevealedUri);
    await info.nftiff.connect(info.deployerSigner).reveal();
    expect(await info.nftiff.tokenURI(1)).to.equal("");
    await info.nftiff.connect(info.deployerSigner).setTokenURI(1, `${baseUri}1.json`);
    expect(await info.nftiff.tokenURI(1)).to.equal(`${baseUri}1.json`);
    await expect(
      info.nftiff.connect(info.deployerSigner).setTokenURI(1, `${baseUri}1-new.json`)
    ).to.be.emit(info.nftiff, "TokenURIUpdated");
    expect(await info.nftiff.tokenURI(1)).to.equal(`${baseUri}1-new.json`);

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
        .mintPublic(2, signature2, { value: info.mintFee(2) })
      ).to.be.emit(info.nftiff, "Transfer");
    // can't mint blacklisted user
    await expect(
        info.nftiff
        .connect(info.member1Signer)
        .mintPublic(2, signature, { value: info.mintFee(2) })
      ).to.be.revertedWith("Blacklisted user");
  });


  it("Claim test", async function () {

    /**
     * nftiff holders
     *    user1: [1,2,3,4]
     *    user2: [5,6]
     * 
     * blacklisted: user1
     * 
     * punks holders
     *    user1: 1
     *    user2: 2, 3
     */

    // set mock punks holders
    await info.cryptopunks.connect(info.deployerSigner).setTokenOwner(1, info.member1);
    await info.cryptopunks.connect(info.deployerSigner).setTokenOwner(2, info.member2);
    await info.cryptopunks.connect(info.deployerSigner).setTokenOwner(3, info.member2);

    // fail: wrong nftiff holder
    let signature = await getClaimSignature(2, 1, info.member2);
    await expect(
      info.nftiff
      .connect(info.member2Signer)
      .claim(2, 1, signature)
    ).to.be.reverted;

    // fail: wrong punks holder
    signature = await getClaimSignature(1, 5, info.member2);
    await expect(
      info.nftiff
      .connect(info.member2Signer)
      .claim(1, 5, signature)
    ).to.be.reverted;

    // fail: blacklisted user
    signature = await getClaimSignature(1, 1, info.member1);
    await expect(
      info.nftiff
      .connect(info.member1Signer)
      .claim(1, 1, signature)
    ).to.be.reverted;

    // failure: invalid signature
    signature = await getClaimSignature(1, 5, info.member2);
    await expect(
      info.nftiff
      .connect(info.member2Signer)
      .claim(2, 5, signature)
    ).to.be.reverted;

    // success
    expect(await info.nftiff.punkClaims(2)).to.equal(0);
    expect(await info.nftiff.nftiffClaims(5)).to.equal(0);
    expect(await info.nftiff.totalClaimed()).to.equal(0);
    signature = await getClaimSignature(2, 5, info.member2);
    await expect(
      info.nftiff
      .connect(info.member2Signer)
      .claim(2, 5, signature)
    ).to.be.emit(info.nftiff, "Claimed");
    expect(await info.nftiff.punkClaims(2)).to.gt(0);
    expect(await info.nftiff.nftiffClaims(5)).to.gt(0);
    expect(await info.nftiff.totalClaimed()).to.equal(1);

    let claimInfo = await info.nftiff.claimInfo(1);
    expect(claimInfo.punkId).to.equal(2);
    expect(claimInfo.nftiffId).to.equal(5);
    expect(claimInfo.claimer).to.equal(info.member2);

    // can't claim with used-punk
    signature = await getClaimSignature(2, 6, info.member2);
    await expect(
      info.nftiff
      .connect(info.member2Signer)
      .claim(2, 6, signature)
    ).to.be.reverted;

    // can't claim with used-nftiff
    signature = await getClaimSignature(3, 5, info.member2);
    await expect(
      info.nftiff
      .connect(info.member2Signer)
      .claim(3, 5, signature)
    ).to.be.reverted;
  });
});
