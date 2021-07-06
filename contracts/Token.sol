// SPDX-License-Identifier: GPL - @DrGorilla_md (Tg/Twtr)

pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/*
18 decimals
9%buy tax: 6% to wallet address and 3%to LP
12% sell tax: 9% dev 3% LP
*/

contract Token is Ownable, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private excluded;

    uint8 _decimals = 9;
    uint8 LP_tax = 3; //in %
    uint8 dev_tax = 6; //in %
    uint8 dev_tax_sell = 9;
    uint256 _totalSupply = 10**18 * 10**_decimals;
    uint256 public swap_for_liquidity_threshold = 10**16 * 10**_decimals; //1%
    
    bool liq_swap_reentrancy_guard;

    string _name = "Token";
    string _symbol = "XXXXXXXXXXXXXXXXXXXXXXXXXX";

    address public LP_recipient;
    address public dev_wallet;

    IUniswapV2Pair public pair;
    IUniswapV2Router02 public router;

    event TaxRatesChanged();
    event SwapForBNB(string);
    event AddLiq(string);

    constructor (address _router) {
         //create pair to get the pair address
         router = IUniswapV2Router02(_router);
         IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
         pair = IUniswapV2Pair(factory.createPair(address(this), router.WETH()));

         LP_recipient = address(0x000000000000000000000000000000000000dEaD);
         dev_wallet = address(0xA938375053B1DCc520006503c411d136c2dCA101);

         excluded[msg.sender] = true;
         excluded[address(this)] = true;
         excluded[dev_wallet] = true;         
         _balances[msg.sender] = _totalSupply;
         emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function decimals() public view returns (uint256) {
         return _decimals;
    }
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        uint256 LP_tax_amount;
        uint256 dev_tax_amount;
        
        if(excluded[sender] == false && excluded[recipient] == false) {
          dev_tax_amount = recipient == address(pair) ? amount.mul(dev_tax_sell).div(100) : dev_tax_amount = amount.mul(dev_tax).div(100);
          LP_tax_amount = amount.mul(LP_tax).div(100);
        } //else (excluded) : stay at 0 and 0


        _balances[sender] = senderBalance.sub(amount);
        _balances[address(this)] += LP_tax_amount;
        _balances[dev_wallet] += dev_tax_amount;
        _balances[recipient] += amount.sub(dev_tax_amount).sub(LP_tax_amount);

        if(balanceOf(address(this)) >= swap_for_liquidity_threshold && !liq_swap_reentrancy_guard) {
          liq_swap_reentrancy_guard = true;
          addLiquidity(balanceOf(address(this)));
          liq_swap_reentrancy_guard = false;
        }
        

        emit Transfer(sender, recipient, amount.sub(dev_tax_amount).sub(LP_tax_amount));
        emit Transfer(sender, address(this), LP_tax_amount);
        emit Transfer(sender, dev_wallet, dev_tax_amount);
    }

    //@dev when triggered, will swap and provide liquidity
    //    BNBfromSwap being the difference between and after the swap, slippage
    //    will result in extra-BNB for the reward pool (free money for the guys:)
    function addLiquidity(uint256 token_amount) internal returns (uint256) {
      address[] memory route = new address[](2);
      route[0] = address(this);
      route[1] = router.WETH();

      if(allowance(address(this), address(router)) < token_amount) {
        _allowances[address(this)][address(router)] = ~uint256(0);
        emit Approval(address(this), address(router), ~uint256(0));
      }
      
      uint256 half = token_amount.div(2);
      uint256 half_2 = token_amount.sub(half);
      
      try router.swapExactTokensForETHSupportingFeeOnTransferTokens(half, 0, route, address(this), block.timestamp) {
        router.addLiquidityETH{value: address(this).balance}(address(this), half_2, 0, 0, LP_recipient, block.timestamp); //will not be catched
        emit AddLiq("addLiq: ok");
        return token_amount;
      }
      catch {
        emit AddLiq("addLiq: fail");
        return 0;
      }
    }

    function retrieveBNB() external onlyOwner {
      address to = payable(address(this));
      (bool success,) = to.call{value:address(this).balance}(new bytes(0));
      require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }

    function excludeFromTaxes(address adr) external onlyOwner {
      require(!excluded[adr], "already excluded");
      excluded[adr] = true;
    }

    function includeInTaxes(address adr) external onlyOwner {
      require(excluded[adr], "already taxed");
      excluded[adr] = false;
    }

    function isExcluded(address adr) external view returns (bool){
      return excluded[adr];
    }

    //@dev default = burn
    function setLPRecipient(address _LP_recipient) external onlyOwner {
      LP_recipient = _LP_recipient;
    }

    function setDevWallet(address _devWallet) external onlyOwner {
      dev_wallet = _devWallet;
    }

    function setSwapFor_Liq_Threshold(uint128 threshold_in_token) external onlyOwner {
      swap_for_liquidity_threshold = threshold_in_token * 10**_decimals;
    }

    receive () external payable {}
}
