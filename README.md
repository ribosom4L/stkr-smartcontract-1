# Stkr - Staking. Simplified.

Stkr is a decentralized protocol and platform that combines staking and DeFi, implementing elements from traditional staking with non-custodial management, Micropools, instant liquidity and decentralized governance.

![Build Status](https://circleci.com/gh/Ankr-network/stkr-smartcontract.svg?style=svg)

<p align="center">
<img src="./image/stkr.png">
</p>

### Requirements

- Node.js v12.0 or higher
- Truffle v5.1.44 or higher


### Installation
```
git clone git@github.com:Ankr-network/stkr-smartcontract.git
cd stkr-smartcontract
```

If you are using npm;

```
npm install
```

If you are using yarn;

```
yarn install
```

## Running

### Compile contracts

```
yarn compile
```

### Running tests

```
yarn test
```

### Deploying Contracts

##### To Goerli Network 
```
yarn migrate --network goerli
```

##### To a Local Network 

> Make sure you have configured ganache cli correctly and make sure configuration fits with turffle-config file.
```
yarn migrate
```
