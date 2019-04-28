pragma solidity ^0.4.23;

interface ITRC20 {

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library SafeMath {

    /**
     * @dev Multiplies two numbers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two numbers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

contract TRC20 is ITRC20 {

    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowed;
    uint256 private _totalSupply;

    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(
        address owner,
        address spender
    )
    public
    view
    returns (uint256)
    {
        return _allowed[owner][spender];
    }

    /**
     * @dev Transfer token for a specified address
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    )
    public
    returns (bool)
    {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(
        address spender,
        uint256 addedValue
    )
    public
    returns (bool)
    {
        require(spender != address(0));

        _allowed[msg.sender][spender] = (
        _allowed[msg.sender][spender].add(addedValue));
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    )
    public
    returns (bool)
    {
        require(spender != address(0));

        _allowed[msg.sender][spender] = (
        _allowed[msg.sender][spender].sub(subtractedValue));
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Transfer token for a specified addresses
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        // Should https://github.com/OpenZeppelin/zeppelin-solidity/issues/707 be accepted,
        // this function needs to emit an event with the updated approval.
        _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(value);
        _burn(account, value);
    }
}

contract TRC20Detailed is TRC20 {

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string name, string symbol, uint8 decimals) public {
      _name = name;
      _symbol = symbol;
      _decimals = decimals;
    }

    /**
     * @return the name of the token.
     */
    function tokenName() public view returns (string) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function tokenSymbol() public view returns (string) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function tokenDecimals() public view returns (uint8) {
        return _decimals;
    }
}

contract TronFomoToken is TRC20Detailed {

  using SafeMath for uint;

  uint public constant  PRICE_INCREASE_PCT = 111; // 1.11 ie. 11%
  uint public constant SUPPLY_INCREASE_PCT = 125; // 1.25 ie. 25%
  uint public constant MINIMAL_TRX_FOR_BUY = 1e6; // 1 TRX min
  uint public constant SUPPLY_1ST_LEVEL = 100 * 1e6;
  uint public constant PRICE_1ST_LEVEL  = 1e4; // 0.01 TRX is initial price

  uint public constant DEV_FEE      = 1; // if no referral then 3% dev fee
  uint public constant REFERRAL_FEE = 2;
  uint public constant REFERRAL_THRESHOLD = 500 * 1e6; // After >500 TRX buy unlock referral privilege

  uint public level = 1;
  uint public pricePerToken   = PRICE_1ST_LEVEL;
  uint public supplyLevelLeft = SUPPLY_1ST_LEVEL;   // current supply
  uint public supplyLevel     = SUPPLY_1ST_LEVEL;   // total supply for level

  uint public trxBalance = 0;
  uint public boughtTotal = 0;
  uint public soldTotal = 0;
  uint public referralTotal = 0;

  mapping (address => uint) public address2Divs;
  mapping (address => uint) public address2Bought;
  address private DA;

  mapping (uint => uint) public supplyLevels;
  uint public soldAtLevel = 0;
  uint public levelViaSupply = 1;
  uint public maxLevelViaSupply = 1;

  constructor() TRC20Detailed("TronFomoToken", "TFT", 6) public {
    DA = msg.sender;
    supplyLevels[1] = SUPPLY_1ST_LEVEL;
  }

  event NewLevel(uint level, uint price, uint supply);

  event TokenPurchase(address buyerAddress, uint msgValue, uint valueAmt, uint devFee, uint referralFee, uint price, address referralAddress, uint tokenAmt, bool newLevel);

  event ChangeTransfer(address changeAddress, uint msgValue, uint change, uint valueAmt, uint devFee, uint referralFee);

  event TokenSold(address msgSender, address referralAddress, uint tokenAmt, uint sellPrice, uint sellValue, uint devFee, uint referralFee, uint sellValueNoFees, uint totSupplyBeforeSell, uint trxBalanceBeforeSell);

  event Withdraw(address msgSender, uint amt);

  function withdraw() public {
    uint amt = address2Divs[msg.sender];
    address2Divs[msg.sender] = 0;
    msg.sender.transfer(amt);
    emit Withdraw(msg.sender, amt);
  }

  function reinvest() public returns(uint tokenAmt, bool newLevel, uint devFee, uint referralFee, uint valueAmt) {
    (tokenAmt, newLevel, devFee, referralFee, valueAmt) = reinvestWithReferral(address(0));
  }

  function reinvestWithReferral(address referralAddress) public returns(uint tokenAmt, bool newLevel, uint devFee, uint referralFee, uint valueAmt) {
    uint amt = address2Divs[msg.sender];
    address2Divs[msg.sender] = 0;
    (tokenAmt, newLevel, devFee, referralFee, valueAmt) = buyWithReferralInternal(referralAddress, amt);
  }

  function buy() public payable returns(uint tokenAmt, bool newLevel, uint devFee, uint referralFee, uint valueAmt) {
    (tokenAmt, newLevel, devFee, referralFee, valueAmt) = buyWithReferralInternal(address(0), msg.value);
  }

  function buyWithReferral(address referralAddress) public payable returns(uint tokenAmt, bool newLevel, uint devFee, uint referralFee, uint valueAmt) {
    (tokenAmt, newLevel, devFee, referralFee, valueAmt) = buyWithReferralInternal(referralAddress, msg.value);
  }

  function buyWithReferralInternal(address referralAddress, uint msgValue) internal returns(uint tokenAmt, bool newLevel, uint devFee, uint referralFee, uint valueAmt) {

    require(msgValue >= MINIMAL_TRX_FOR_BUY, "Not enough TRX sent.");
    bool noReferral = checkReferral(referralAddress);

    devFee = noReferral ? (msgValue.mul(REFERRAL_FEE.add(DEV_FEE))).div(100) : msgValue.div(100);
    referralFee = noReferral ? 0 : (msgValue.mul(REFERRAL_FEE)).div(100);
    valueAmt = msgValue.sub(devFee.add(referralFee));
    tokenAmt = (valueAmt.mul(1e6)).div(pricePerToken);

    if (tokenAmt >= supplyLevelLeft) {

      valueAmt = (supplyLevelLeft.mul(pricePerToken)).div(1e6);
      devFee = noReferral ? (valueAmt.mul(REFERRAL_FEE.add(DEV_FEE))).div(100) : valueAmt.div(100);
      referralFee = noReferral ? 0 : (valueAmt.mul(REFERRAL_FEE)).div(100);

      uint change = msgValue.sub(valueAmt.add(devFee.add(referralFee)));
      if (change > 0 && change < msgValue) {
        msg.sender.transfer(change);
        emit ChangeTransfer(msg.sender, msgValue, change, valueAmt, devFee, referralFee);
      }

      tokenAmt = supplyLevelLeft;
      pricePerToken   = (pricePerToken.mul(PRICE_INCREASE_PCT)).div(100);
      calculateNewSupplyLevel(levelViaSupply);

      level += 1;
      newLevel = true;
      emit NewLevel(level, pricePerToken, supplyLevel);
    } else {
      supplyLevelLeft = supplyLevelLeft.sub(tokenAmt);
    }

    emit TokenPurchase(msg.sender, msgValue, valueAmt, devFee, referralFee, pricePerToken, referralAddress, tokenAmt, newLevel);
    trxBalance = trxBalance.add(valueAmt);
    boughtTotal = boughtTotal.add(valueAmt);
    address2Bought[msg.sender] = address2Bought[msg.sender].add(valueAmt);
    addCommissions(referralAddress, devFee, referralFee, noReferral);
    _mint(msg.sender, tokenAmt);
  }

  function sell(uint tokenAmt) public returns(uint devFee, uint referralFee, uint sellPrice, uint sellValue, uint sellValueNoFees) {
    (devFee, referralFee, sellPrice, sellValue, sellValueNoFees) = sellWithReferral(address(0), tokenAmt);
  }

  function sellWithReferral(address referralAddress, uint tokenAmt) public returns(uint devFee, uint referralFee, uint sellPrice, uint sellValue, uint sellValueNoFees) {

    uint balance = balanceOf(msg.sender);
    require(balance >= tokenAmt, "Not enough tokens.");
    bool noReferral = checkReferral(referralAddress);

    uint totSupply = totalSupply();
    _burn(msg.sender, tokenAmt);
    soldAtLevel = soldAtLevel.add(tokenAmt);
    sellPrice = (trxBalance.mul(1e6)).div(totSupply);
    sellValue = (tokenAmt.mul(sellPrice)).div(1e6);

    devFee = noReferral ? (sellValue.mul(REFERRAL_FEE.add(DEV_FEE))).div(100) : sellValue.div(100);
    referralFee = noReferral ? 0 : (sellValue.mul(REFERRAL_FEE)).div(100);
    sellValueNoFees = sellValue.sub(devFee.add(referralFee));

    emit TokenSold(msg.sender, referralAddress, tokenAmt, sellPrice, sellValue, devFee, referralFee, sellValueNoFees, totSupply, trxBalance);
    trxBalance = trxBalance.sub(sellValue);
    msg.sender.transfer(sellValueNoFees);

    soldTotal = soldTotal.add(sellValueNoFees);
    addCommissions(referralAddress, devFee, referralFee, noReferral);
  }

  function addCommissions(address referralAddress, uint devFee, uint referralFee, bool noReferral) internal {
    if (!noReferral) {
      address2Divs[referralAddress] = address2Divs[referralAddress].add(referralFee);
      referralTotal = referralTotal.add(referralFee);
    }
    address2Divs[DA] = address2Divs[DA].add(devFee);
  }

  function calculateNewSupplyLevel(uint lvl) internal {
    if (soldAtLevel >= supplyLevel) {
      soldAtLevel = soldAtLevel.sub(supplyLevel);
      levelViaSupply = lvl.sub(1);
      supplyLevel = supplyLevels[levelViaSupply];
      calculateNewSupplyLevel(levelViaSupply);
    } else {
      supplyLevel = (supplyLevel.mul(SUPPLY_INCREASE_PCT)).div(100);
      supplyLevelLeft = supplyLevel;

      soldAtLevel = 0;
      if (supplyLevel > supplyLevels[levelViaSupply])
        supplyLevels[++levelViaSupply] = supplyLevel;
    }
  }

  function checkReferral(address referralAddress) internal view returns(bool noReferral) {
    require(msg.sender != referralAddress, "Cannot refer to sender address.");
    noReferral = referralAddress == address(0);
    if (!noReferral && address2Bought[referralAddress] < REFERRAL_THRESHOLD)
      revert("Referral threshold isn't met.");
  }
}