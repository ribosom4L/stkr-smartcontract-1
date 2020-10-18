const fs = require('fs')
const path = require('path')
const helpers = require('./helpers/helpers')
const {expectRevert} = require('@openzeppelin/test-helpers')

const MicroPool = artifacts.require('MicroPool')
const Staking = artifacts.require('Staking')
const Ankr = artifacts.require('Ankr')
const SystemParameters = artifacts.require('SystemParameters')

contract('MicroPool Rewarding', function (accounts) {

})
