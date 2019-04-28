pragma solidity ^0.4.23;

/***
 *
 ****************************
 ****** Temple Of Tron ******
 ****************************
 *
 * https://templeoftron.rocks
 *
 * Welcome to the first wealth generation contract built on Tron.
 *
 * Entry Fee: 15%
 * Exit Fee: 15%
 * Masternode Reward: 5%
 *
 * Temple Warning: Do not play with more than you can afford to lose.
 *
***/

contract TempleOfTron {

    /*=================================
    =            MODIFIERS            =
    =================================*/

    /// @dev Only people with tokens
    modifier onlyBagholders {
      require(myTokens() > 0);
      _;
    }

    /// @dev Only people with profits
    modifier onlyStronghands {
      require(myDividends(true) > 0);
      _;
    }

    /// @dev Make sure the temple is active
    modifier templeIsActive {
      require(templeActive);
      _;
    }

    /*==============================
    =            EVENTS            =
    ==============================*/

    event onTokenPurchase(
      address indexed customerAddress,
      uint256 incomingTron,
      uint256 tokensMinted,
      address indexed referredBy,
      uint timestamp,
      uint256 price
    );

    event onTokenSell(
      address indexed customerAddress,
      uint256 tokensBurned,
      uint256 tronEarned,
      uint timestamp,
      uint256 price
    );

    event onReinvestment(
      address indexed customerAddress,
      uint256 tronReinvested,
      uint256 tokensMinted
    );

    event onWithdraw(
      address indexed customerAddress,
      uint256 tronWithdrawn
    );

    // TRC-20
    event Transfer(
      address indexed from,
      address indexed to,
      uint256 tokens
    );


    /*=====================================
    =            CONFIGURABLES            =
    =====================================*/

    string public name = "TempleOfTron";
    string public symbol = "TMPL";
    uint8 constant public decimals = 6;

    /// @dev 15% dividends for token buying
    uint8 constant internal entryFee_ = 15;

    /// @dev 15% dividends for token selling
    uint8 constant internal exitFee_ = 15;

    /// @dev 5% masternode fee
    uint8 constant internal referralFee_ = 5;

    /// @dev P3D pricing
    uint256 constant internal tokenPriceInitial_ = 1000;
    uint256 constant internal tokenPriceIncremental_ = 10;

    uint256 constant internal magnitude = 2 ** 64;

    /// @dev 100 tokens needed for masternode activation
    uint256 public stakingRequirement = 100e6;

    /// @dev Set the admin
    address public admin;

    /// @dev Set to true to open the temple
    bool public templeActive = false;


   /*=================================
    =            DATASETS            =
    ================================*/

    // amount of shares for each address (scaled number)
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => int256) internal payoutsTo_;
    uint256 internal tokenSupply_;
    uint256 internal profitPerShare_;
    uint256 public depositCount;

    /*=======================================
    =            CONSTRUCTOR                =
    =======================================*/

   constructor () public {

    admin = msg.sender;

   }

    /*=======================================
    =            PUBLIC FUNCTIONS           =
    =======================================*/

    // @dev Function that opens the temple
    function setTempleActive() public {
      require(msg.sender == admin && !templeActive);
      templeActive = true;
    }

    /// @dev Converts all incoming Tron to tokens for the caller, and passes down the referral addy (if any)
    function buy(address _referredBy) templeIsActive public payable returns (uint256) {
      purchaseTokens(msg.value, _referredBy , msg.sender);
    }

    /// @dev Converts to tokens on behalf of the customer - this allows gifting and integration with other systems
    function purchaseFor(address _referredBy, address _customerAddress) templeIsActive public payable returns (uint256) {
      purchaseTokens(msg.value, _referredBy , _customerAddress);
    }

    /**
     * @dev Fallback function to handle Tron that was sent straight to the contract
     *  Unfortunately we cannot use a referral address this way.
     */
    function() templeIsActive payable public {
        purchaseTokens(msg.value, 0x0, msg.sender);
    }

    /// @dev Converts all of caller's dividends to tokens.
    function reinvest() onlyStronghands public {
        // fetch dividends
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false); // retrieve ref. bonus later in the code

        // pay out the dividends virtually
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);

        // retrieve ref. bonus
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;

        // dispatch a buy order with the virtualized "withdrawn dividends"
        uint256 _tokens = purchaseTokens(_dividends, 0x0 , _customerAddress);

        // fire event
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }

    /// @dev Alias of sell() and withdraw().
    function exit() public {
        // get token count for caller & sell them all
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if (_tokens > 0) sell(_tokens);

        // capitulation
        withdraw();
    }

    /// @dev Withdraws all of the callers earnings.
    function withdraw() onlyStronghands public {
        // setup data
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false); // get ref. bonus later in the code

        // update dividend tracker
        payoutsTo_[_customerAddress] += (int256) (_dividends * magnitude);

        // add ref. bonus
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;

        // lambo delivery service
        _customerAddress.transfer(_dividends);

        // fire event
        emit onWithdraw(_customerAddress, _dividends);
    }

    /// @dev Liquifies tokens to Tron.
    function sell(uint256 _amountOfTokens) onlyBagholders public {
        // setup data
        address _customerAddress = msg.sender;
        // russian hackers BTFO
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        uint256 _tokens = _amountOfTokens;
        uint256 _tron = tokensToTron_(_tokens);
        uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, exitFee_), 100);
        uint256 _remainingTron = SafeMath.sub(_tron, _dividends);

        // burn the sold tokens
        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokens);
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _tokens);

        // update dividends tracker
        int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_remainingTron * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;

        // dividing by zero is a bad idea
        if (tokenSupply_ > 0) {
            // update the amount of dividends per token
            profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        }

        // fire event
        emit onTokenSell(_customerAddress, _tokens, _remainingTron, now, buyPrice());
    }


    /**
     * @dev Transfer tokens from the caller to a new holder.
     */
    function transfer(address _toAddress, uint256 _amountOfTokens) onlyBagholders public returns (bool) {
        // setup
        address _customerAddress = msg.sender;

        // make sure we have the requested tokens
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);

        // withdraw all outstanding dividends first
        if (myDividends(true) > 0) {
          withdraw();
        }

        return transferInternal(_toAddress, _amountOfTokens, _customerAddress);
    }

    function transferInternal(address _toAddress, uint256 _amountOfTokens , address _fromAddress) internal returns (bool) {
        // setup
        address _customerAddress = _fromAddress;

        // exchange tokens
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        tokenBalanceLedger_[_toAddress] = SafeMath.add(tokenBalanceLedger_[_toAddress], _amountOfTokens);

        // update dividend trackers
        payoutsTo_[_customerAddress] -= (int256) (profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _amountOfTokens);

        // fire event
        emit Transfer(_customerAddress, _toAddress, _amountOfTokens);

        // TRC-20
        return true;
    }


    /*=====================================
    =      HELPERS AND CALCULATORS        =
    =====================================*/

    /// @dev Method to view the current Tron stored in the contract
    function tronBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /// @dev Retrieve the total token supply.
    function tokenBalance() public view returns (uint256) {
        return tokenSupply_;
    }

    /// @dev Retrieve the tokens owned by the caller.
    function myTokens() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }

    /**
     * @dev Retrieve the dividends owned by the caller.
     *  If `_includeReferralBonus` is to to 1/true, the referral bonus will be included in the calculations.
     *  The reason for this, is that in the frontend, we will want to get the total divs (global + ref)
     *  But in the internal calculations, we want them separate.
     */
    function myDividends(bool _includeReferralBonus) public view returns (uint256) {
        address _customerAddress = msg.sender;
        return _includeReferralBonus ? dividendsOf(_customerAddress) + referralBalance_[_customerAddress] : dividendsOf(_customerAddress);
    }

    /// @dev Retrieve the callers dividend earnings
    function myDividendEarnings() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return dividendsOf(_customerAddress);
    }

    /// @dev Retrieve the callers referral earnings
    function myReferralEarnings() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return referralBalance_[_customerAddress];
    }

    /// @dev Retrieve the token balance of any single address.
    function balanceOf(address _customerAddress) public view returns (uint256) {
        return tokenBalanceLedger_[_customerAddress];
    }

    /// @dev Retrieve the dividend balance of any single address.
    function dividendsOf(address _customerAddress) public view returns (uint256) {
        return (uint256) ((int256) (profitPerShare_ * tokenBalanceLedger_[_customerAddress]) - payoutsTo_[_customerAddress]) / magnitude;
    }

    /// @dev Return the sell price of 1 individual token.
    function sellPrice() public view returns (uint256) {
        // our calculation relies on the token supply, so we need supply. Doh.
        if (tokenSupply_ == 0) {
            return tokenPriceInitial_ - tokenPriceIncremental_;
        } else {
            uint256 _tron = tokensToTron_(1e6);
            uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, exitFee_), 100);
            uint256 _sellPrice = SafeMath.sub(_tron, _dividends);

            return _sellPrice;
        }
    }

    /// @dev Return the buy price of 1 individual token.
    function buyPrice() public view returns (uint256) {
        // our calculation relies on the token supply, so we need supply. Doh.
        if (tokenSupply_ == 0) {
            return tokenPriceInitial_ + tokenPriceIncremental_;
        } else {
            uint256 _tron = tokensToTron_(1e6);
            uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, entryFee_), 100);
            uint256 _buyPrice = SafeMath.add(_tron, _dividends);

            return _buyPrice;
        }
    }

    /// @dev Function for the frontend to dynamically retrieve the price scaling of buy orders.
    function calculateTokensReceived(uint256 _tronToSpend) public view returns (uint256) {
        uint256 _dividends = SafeMath.div(SafeMath.mul(_tronToSpend, entryFee_), 100);
        uint256 _remainingTron = SafeMath.sub(_tronToSpend, _dividends);
        uint256 _amountOfTokens = tronToTokens_(_remainingTron);
        return _amountOfTokens;
    }

    /// @dev Function for the frontend to dynamically retrieve the price scaling of sell orders.
    function calculateTronReceived(uint256 _tokensToSell) public view returns (uint256) {
        require(_tokensToSell <= tokenSupply_);
        uint256 _tron = tokensToTron_(_tokensToSell);
        uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, exitFee_), 100);
        uint256 _remainingTron = SafeMath.sub(_tron, _dividends);
        return _remainingTron;
    }

    /// @dev Function for the frontend to get untaxed receivable Tron.
    function calculateUntaxedTronReceived(uint256 _tokensToSell) public view returns (uint256) {
        require(_tokensToSell <= tokenSupply_);
        uint256 _tron = tokensToTron_(_tokensToSell);
        return _tron;
    }

    /*==========================================
    =            INTERNAL FUNCTIONS            =
    ==========================================*/

    /// @dev Internal function to actually purchase the tokens.
    function purchaseTokens(uint256 _incomingTron, address _referredBy, address _customerAddress) internal returns (uint256) {
        // data setup
        uint256 _undividedDividends = SafeMath.div(SafeMath.mul(_incomingTron, entryFee_), 100);
        uint256 _referralFee = SafeMath.div(SafeMath.mul(_incomingTron, referralFee_), 100);
        uint256 _dividends = SafeMath.sub(_undividedDividends, _referralFee);
        uint256 _remainingTron = SafeMath.sub(_incomingTron, _undividedDividends);
        uint256 _amountOfTokens = tronToTokens_(_remainingTron);
        uint256 _fee = _dividends * magnitude;

        // no point in continuing execution if OP is a poorfag russian hacker
        // prevents overflow in the case that the pyramid somehow magically starts being used by everyone in the world
        // (or hackers)
        // and yes we know that the safemath function automatically rules out the "greater then" equation.
        require(_amountOfTokens > 0 && SafeMath.add(_amountOfTokens, tokenSupply_) > tokenSupply_);

        // is the user referred by a masternode?
        if (
            // is this a referred purchase?
            _referredBy != 0x0000000000000000000000000000000000000000 &&

            // no cheating!
            _referredBy != _customerAddress &&

            // does the referrer have at least X whole tokens?
            // i.e is the referrer a godly chad masternode
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ) {
            // wealth redistribution
            referralBalance_[_referredBy] = SafeMath.add(referralBalance_[_referredBy], _referralFee);
        } else {
            // no ref purchase - add the referral bonus back to the global dividends
            _dividends = SafeMath.add(_dividends, _referralFee);
            _fee = _dividends * magnitude;
        }

        // we can't give people infinite Tron
        if (tokenSupply_ > 0) {

            // add tokens to the pool
            tokenSupply_ = SafeMath.add(tokenSupply_, _amountOfTokens);

            // take the amount of dividends gained through this transaction, and allocates them evenly to each token holder
            profitPerShare_ += (_dividends * magnitude / tokenSupply_);

            // calculate the amount of tokens the customer receives over his purchase
            _fee = _fee - (_fee - (_amountOfTokens * (_dividends * magnitude / tokenSupply_)));

        } else {
            // add tokens to the pool
            tokenSupply_ = _amountOfTokens;
        }

        // Update circulating supply & the ledger address for the customer
        tokenBalanceLedger_[_customerAddress] = SafeMath.add(tokenBalanceLedger_[_customerAddress], _amountOfTokens);

        // Tells the contract that the buyer doesn't deserve dividends for the tokens before they owned them;
        // really i know you think you do but you don't
        int256 _updatedPayouts = (int256) (profitPerShare_ * _amountOfTokens - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;

        // fire event
        emit onTokenPurchase(_customerAddress, _incomingTron, _amountOfTokens, _referredBy, now, buyPrice());

        // Keep track
        depositCount++;
        return _amountOfTokens;
    }

    /**
     * @dev Calculate Token price based on an amount of incoming tron
     *  It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     *  Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function tronToTokens_(uint256 _tron) internal view returns (uint256) {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e6;
        uint256 _tokensReceived =
         (
            (
                // underflow attempts BTFO
                SafeMath.sub(
                    (sqrt
                        (
                            (_tokenPriceInitial ** 2)
                            +
                            (2 * (tokenPriceIncremental_ * 1e6) * (_tron * 1e6))
                            +
                            ((tokenPriceIncremental_ ** 2) * (tokenSupply_ ** 2))
                            +
                            (2 * tokenPriceIncremental_ * _tokenPriceInitial*tokenSupply_)
                        )
                    ), _tokenPriceInitial
                )
            ) / (tokenPriceIncremental_)
        ) - (tokenSupply_);

        return _tokensReceived;
    }

    /**
     * @dev Calculate token sell value.
     *  It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     *  Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function tokensToTron_(uint256 _tokens) internal view returns (uint256) {
        uint256 tokens_ = (_tokens + 1e6);
        uint256 _tokenSupply = (tokenSupply_ + 1e6);
        uint256 _tronReceived =
        (
            // underflow attempts BTFO
            SafeMath.sub(
                (
                    (
                        (
                            tokenPriceInitial_ + (tokenPriceIncremental_ * (_tokenSupply / 1e6))
                        ) - tokenPriceIncremental_
                    ) * (tokens_ - 1e6)
                ), (tokenPriceIncremental_ * ((tokens_ ** 2 - tokens_) / 1e6)) / 2
            )
        / 1e6);

        return _tronReceived;
    }

    /// @dev This is where all your gas goes.
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
      // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
      // benefit is lost if 'b' is also tested.
      // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
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

}