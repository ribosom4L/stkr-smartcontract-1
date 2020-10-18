const Ankr = artifacts.require('Ankr')
const helpers = require('./helpers/helpers')

contract('Ankr', async function (accounts) {
    let ankr
    let owner

    before(async () => {
        ankr = await Ankr.deployed()
        owner = accounts[0]
    })

    it('faucet should give 100k ankr', async () => {
        await ankr.faucet()
        const balance = await ankr.balanceOf(owner);
        assert.equal(Number(balance), helpers.amount(100000))
    })
})
