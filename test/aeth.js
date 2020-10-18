const AETH = artifacts.require("AETH");
const {expectRevert, expectEvent} = require('@openzeppelin/test-helpers')

contract("AETH", function (accounts) {
    let aeth
    let owner
    before(async () => {
        aeth = await AETH.deployed()
        owner = accounts[0]
    })

    it("should mint aeth when eth sent", async () => {
        await aeth.send(1)
        assert.equal(await aeth.balanceOf(owner), 1)
        assert.equal(await web3.eth.getBalance(aeth.address), 1)
    });

    it('should not allow swap aeth when not claimable', async () => {
        await expectRevert(aeth.swap(), "Not claimable")
    })

    it('should allow swap aeth when claimable', async () => {
        await aeth.toggleClaimable()
        const aethBalance = Number(await aeth.balanceOf(owner))
        const ethereumBalance = Number(await web3.eth.getBalance(owner));

        await aeth.swap({gasPrice: 0})

        assert.equal(ethereumBalance + aethBalance, Number(await web3.eth.getBalance(owner)))
    })
});
