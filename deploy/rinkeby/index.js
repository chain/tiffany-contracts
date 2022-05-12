const { web3 } = require("hardhat");

const deployed = {
  nftiff: "",
  cryptopunks: "",
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
