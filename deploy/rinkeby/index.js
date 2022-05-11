const { web3 } = require("hardhat");

const deployed = {
  nftiff: "",
};

const func = async function (hre) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { get, deploy, read, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  // /////////////////////// deploy starts

  // deploy NFTiff
  const nftiff = deployed.nftiff
    ? { address: deployed.nftiff }
    : await deploy("NFTiff", { from: deployer, log: true, args: [""] });
};

func.tags = ["nft"];
module.exports = func;
