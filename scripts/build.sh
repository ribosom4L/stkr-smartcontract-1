#!/bin/bash
yarn install
npx truffle compile --all
npx truffle migrate --network goerli
node scripts/build_abi.js