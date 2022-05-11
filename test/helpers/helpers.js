
const abi = require('ethereumjs-abi');
const { web3 } = require('hardhat');

// Function to check expected failure cases
async function assertFailure (promise) {
  try {
    await promise;
  } catch (error) {
    return error;
  }
  expect.fail("Expected an exception but none was received");
}

// Function to advance time and block 
async function advanceTimeAndBlock (time){
  await advanceTime(time);
  await advanceBlock();

  return Promise.resolve(web3.eth.getBlock('latest'));
}

// Function to advance time
function advanceTime (time) {
  return new Promise((resolve, reject) => {
      web3.currentProvider.send({
          jsonrpc: "2.0",
          method: "evm_increaseTime",
          params: [time],
          id: new Date().getTime()
      }, (err, result) => {
          if (err) { return reject(err); }
          return resolve(result);
      });
  });
}

// Function to advance block
function advanceBlock () {
  return new Promise((resolve, reject) => {
      web3.currentProvider.send({
          jsonrpc: "2.0",
          method: "evm_mine",
          id: new Date().getTime()
      }, (err, result) => {
          if (err) { return reject(err); }
          const newBlockHash = web3.eth.getBlock('latest').hash;

          return resolve(newBlockHash)
      });
  });
}

function encodeCall(name, arguments, values) {
  const methodId = abi.methodID(name, arguments).toString('hex');
  const params = abi.rawEncode(arguments, values).toString('hex');
  return '0x' + methodId + params;
}

// Function to get block number
async function getBlockNumber() {
  return (await web3.eth.getBlock('latest')).number;
}

async function getBlockTimestamp() {
  return (await web3.eth.getBlock('latest')).timestamp;
}

module.exports = { assertFailure, advanceTimeAndBlock, advanceTime, advanceBlock, getBlockNumber, encodeCall, getBlockTimestamp };
