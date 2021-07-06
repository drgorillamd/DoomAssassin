'use strict';
const Token = artifacts.require("Token");
const truffleCost = require('truffle-cost');
const truffleAssert = require('truffle-assertions');
const routerContract = artifacts.require('IUniswapV2Router02');
const pairContract = artifacts.require('IUniswapV2Pair');
const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";

//const chai = require('chai');
const BN = require('bn.js');

require('chai').use(require('chai-bn')(BN)).should();

contract("LP", accounts => {

  const to_send = 10**7;
  const amount_BNB = 98 * 10**18;
  const pool_balance = '98' + '0'.repeat(19);

  before(async function() {
    const x = await Token.new(routerAddress);
  });

  describe("Setting the Scene", () => {

    it("Adding Liq", async () => {
      const x = await Token.deployed();
      const router = await routerContract.at(routerAddress);
      const amount_token = pool_balance;
      const sender = accounts[0];

      let _ = await x.approve(routerAddress, amount_token);
      await router.addLiquidityETH(x.address, amount_token, 0, 0, accounts[0], 1907352278, {value: amount_BNB});

      const pairAdr = await x.pair.call();
      const pair = await pairContract.at(pairAdr);
      const LPBalance = await pair.balanceOf.call(accounts[0]);

      assert.notEqual(LPBalance, 0, "No LP token received / check Uni pool");
    });

    it("Lowering swap_for_liquidity_threshold", async () => {
      const x = await Token.deployed();
      await x.setSwapFor_Liq_Threshold(2);
      const expected = new BN(2*10**9);
      const val = await x.swap_for_liquidity_threshold.call();
      val.should.be.a.bignumber.that.equals(expected);
    });


  });

  //tricking the contact to trigger a swap
  describe("Contract balance setting", () => {

    it("Transfer to contract > 2 * swap - 100", async () => {
      const x = await Token.deployed();
      await x.transfer(x.address, (1*10**9), { from: accounts[0] });
      const newBal = await x.balanceOf.call(x.address);
      const expected = new BN((1*10**9));
      newBal.should.be.a.bignumber.that.equals(expected);
    });

    it("set new LP recipient", async () => {
      const x = await Token.deployed();
      await x.setLPRecipient(accounts[5], {from: accounts[0]});
      const new_recipient = await x.LP_recipient.call({from: accounts[0]});
      assert.equal(new_recipient, accounts[5], "LP Recipient not set");
    });

  });

  describe("Liq Mechanics: Swap + addLiq", () => {
    it("Transfers to trigger swap", async () => {
      const x = await Token.deployed();
      const pairAdr = await x.pair.call();
      const pair = await pairContract.at(pairAdr);

      await x.transfer(accounts[1], 100*10**9, { from: accounts[0] });
      const old_LPBalance = await pair.balanceOf.call(accounts[5]);
      await truffleCost.log(x.transfer(accounts[2], 100*10**9, { from: accounts[1] }));
      const new_LPBalance = await pair.balanceOf.call(accounts[5]);
      new_LPBalance.should.be.a.bignumber.that.is.greaterThan(old_LPBalance);
    });
  });

});
