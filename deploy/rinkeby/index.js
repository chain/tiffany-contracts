const { web3 } = require("hardhat");

const deployed = {
  nftiff: "0x023547324c04a59E968B1Db9de3AD5C9bF6a3b7C",
  cryptopunks: "0x0ece5312f66002b4103FBb6A0ff4ad90aF52f91a",
};

const func = async function (hre) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { get, deploy, read, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  // /////////////////////// deploy starts

  // deploy MockCryptoPunks
  const cryptopunks = deployed.cryptopunks
    ? { address: deployed.cryptopunks }
    : await deploy("MockCryptoPunks", { from: deployer, log: true, args: [] });

  // deploy NFTiff
  const nftiff = deployed.nftiff
    ? { address: deployed.nftiff }
    : await deploy("NFTiff", { from: deployer, log: true, args: ["", cryptopunks.address] });
};

func.tags = ["nft"];
module.exports = func;
