const Token = artifacts.require("Token");
const truffleCost = require('truffle-cost');
const truffleAssert = require('truffle-assertions');
const BN = require('bn.js');
require('chai').use(require('chai-bn')(BN)).should();

const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";


contract("Basic tests", accounts => {

  before(async function() {
    const x = await Token.new(routerAddress);
  });

  describe("Init state", () => {
    it("Initialized - return proper name()", async () => {
      const x = await Token.deployed();
      const obs_name = await x.name();
      assert.equal(obs_name, "Token", "incorrect name returned")
    });

    it("deployer = owner", async () => {
      const x = await Token.deployed();
      const owned_by = await x.owner.call();
      assert.equal(accounts[0], owned_by, "Owner is not account[0]");
    });

    it("deployer has total supply", async () => {
      const x = await Token.deployed();
      const tot_supp = await x.totalSupply.call();
      const deployer_balance = await x.balanceOf(accounts[0]);
      deployer_balance.should.be.a.bignumber.that.equals(tot_supp);
    });
  });
});
