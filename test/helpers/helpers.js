advanceTime = (time) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: "2.0",
      method:  "evm_increaseTime",
      params:  [time],
      id:      new Date().getTime()
    }, (err, result) => {
      if (err) {
        return reject(err);
      }
      return resolve(result);
    });
  });
};

advanceBlock = () => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: "2.0",
      method:  "evm_mine",
      id:      new Date().getTime()
    }, (err, result) => {
      if (err) {
        return reject(err);
      }
      const newBlockHash = web3.eth.getBlock("latest").hash;

      return resolve(newBlockHash);
    });
  });
};

takeSnapshot = () => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: "2.0",
      method:  "evm_snapshot",
      id:      new Date().getTime()
    }, (err, snapshotId) => {
      if (err) {
        return reject(err);
      }
      return resolve(snapshotId);
    });
  });
};

revertToSnapshot = (id) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: "2.0",
      method:  "evm_revert",
      params:  [id],
      id:      new Date().getTime()
    }, (err, result) => {
      if (err) {
        return reject(err);
      }
      return resolve(result);
    });
  });
};

advanceTimeAndBlock = async (time) => {
  await advanceTime(time);
  await advanceBlock();
  return Promise.resolve(web3.eth.getBlock("latest"));
};

makeHex = data => {
  return web3.utils.padRight(web3.utils.asciiToHex(data), 64);
};

amount = data => {
  return String(web3.utils.toWei(String(data)));
};

gwei = data => {
  return String(web3.utils.toWei(String(data), 'gwei'));
};

module.exports = {
  advanceTime,
  advanceBlock,
  advanceTimeAndBlock,
  takeSnapshot,
  revertToSnapshot,
  makeHex,
  amount,
  gwei
};