const Token = artifacts.require("Token");
const truffleCost = require('truffle-cost');
const routerContract = artifacts.require('IUniswapV2Router02');
const pairContract = artifacts.require('IUniswapV2Pair');
const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";

const BN = require('bn.js');
require('chai').use(require('chai-bn')(BN)).should();

contract("LP and taxes", accounts => {

  const to_send = 1260000;
  const pool_balance = 10**8;

  before(async function() {
    const x = await Token.new(routerAddress);
  });

  describe("Adding Liq", () => {

    it("Adding liquidity: 10^8 token & 4BNB", async () => {
      const amount_BNB = 4*10**18;
      const amount_token = pool_balance;
      const sender = accounts[0];

      const x = await Token.deployed();
      const router = await routerContract.at(routerAddress);
      let _ = await x.approve(routerAddress, amount_token);
      await router.addLiquidityETH(x.address, amount_token, 0, 0, accounts[0], 1907352278, {value: amount_BNB}); //9y from now. Are you from the future? Did we make it?

      const pairAdr = await x.pair.call();
      const pair = await pairContract.at(pairAdr);
      const LPBalance = await pair.balanceOf.call(accounts[0]);

      assert.notEqual(LPBalance.toNumber(), 0, "No LP token received");
    });
  });

  describe("Regular transfers", () => {

    it("Transfer standard: single -- 1.26m", async () => {
      const x = await Token.deployed();
      const to_receive = to_send - (to_send * 0.09); // 9% taxes total
      const sender = accounts[1];
      const receiver = accounts[2];
      await x.transfer(sender, to_send, { from: accounts[0] });
      await truffleCost.log(x.transfer(receiver, to_send, { from: sender }), 'USD');
      const newBal = await x.balanceOf.call(receiver);
      assert.equal(newBal.toNumber(), to_receive, "incorrect amount transfered");
    });
  });

  describe("swap - tax on selling", () => {
    it("Sell", async () => {
      const x = await Token.deployed();
      const router = await routerContract.at(routerAddress);
      const to_receive = new BN(to_send * 0.09); //9% taxes for dev
      const old_bal = await x.balanceOf.call("0xA938375053B1DCc520006503c411d136c2dCA101");
      const seller = accounts[2];
      const route = [x.address, await router.WETH()]

      await x.transfer(seller, to_send, { from: accounts[0] }); //0 is excluded
      let _ = await x.approve(routerAddress, to_send, {from: seller});
      await router.swapExactTokensForETHSupportingFeeOnTransferTokens(to_send, 0, route, seller, 1907352278, {from: seller});
      const newBal = await x.balanceOf.call("0xA938375053B1DCc520006503c411d136c2dCA101");
      newBal.should.be.a.bignumber.that.equals(old_bal.add(to_receive));
    });

  })

})
