pragma solidity ^0.4.25;

contract F3Token {
    /*=================================
    =            MODIFIERS            =
    =================================*/
    // only people with tokens
    modifier onlyBagholders() {
        require(myTokens() > 0);
        _;
    }

    // only people with profits
    modifier onlyStronghands() {
        require(myDividends(true) > 0);
        _;
    }

    modifier onlyInitial(){
        if(initialState) {
            require(reserveAddress_ == msg.sender, "only allowed address, reserve token for roi early bird bonus!");
            _;
        } else {
            _;
        }
    }
    // There is no OnlyOwner function
    // owner CANNOT:
    // -> take funds
    // -> disable withdrawals
    // -> kill the contract
    // -> change the price of tokens

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

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 tokens
    );


    /*=====================================
    =            CONFIGURABLES            =
    =====================================*/
    string public name = "Fomo3 token";
    string public symbol = "F3T";
    uint8 constant public decimals = 18;
    uint8 constant internal entryFee_ = 10;
    uint8 constant internal roiFee_ = 2;
    uint8 constant internal fomoFee_ = 8;
    uint8 constant internal transferFee_ = 1;
    uint8 constant internal exitFee_ = 4;
    uint8 constant internal refferalFee_ = 20;
    uint256 constant internal tokenPriceInitial_ = 10000;
    uint256 constant internal tokenPriceIncremental_ = 100;
    uint256 constant internal magnitude = 2 ** 64;
    uint256 constant internal fomoCountDown_ = 10 minutes;
    //min invest amount to get referral bonus
    uint256 public stakingRequirement = 5e18;
    uint256 public minRequirement = 10000000;
    uint256 public undividedRemain_;
    uint256 public fomoPool_ = 0;
    uint256 public lastPurchase_;
    uint256 public fomoRound_ = 1;
    address public ownerAddr_;
    //current fomo holder
    address public holderAddr_;

   /*================================
    =            DATASETS            =
    ================================*/
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => uint256) public totalBenefits_;
    mapping(address => int256) internal payoutsTo_;
    mapping(uint => address) public fomoWinner_;
    mapping(uint => uint) public fomoWinAmount_;

    uint256 internal tokenSupply_;
    uint256 internal profitPerShare_;

    address internal reserveAddress_;
    address internal botROIAddress_;
    uint256 internal WaitROIAmount_ = 0;
    uint256 internal lastRemainDistribute_;

    // when this is set to true, only allow admin to reserve tokens for dailyROI early bird bonus.
    bool public initialState = true;

    /*=======================================
    =            PUBLIC FUNCTIONS            =
    =======================================*/
    constructor(address _botROIAddress, address _reserveAddress) public {
        botROIAddress_ = _botROIAddress;
        reserveAddress_ = _reserveAddress;
        ownerAddr_ = msg.sender;
    }

    function buy(address _referredBy) public onlyInitial payable returns (uint256) {
        purchaseTokens(msg.value, _referredBy);
        if (initialState) {
            lastRemainDistribute_ = now;
            initialState = false;
        } else if (now > lastRemainDistribute_ + 7 days) {
            lastRemainDistribute_ = now;
            distributeRemain(undividedRemain_);
        }
    }

    function () payable public {
        //too much gas
        undividedRemain_ = SafeMath.add(undividedRemain_, msg.value);
    }

    function reinvest() onlyStronghands public {
        uint256 _dividends = myDividends(true);
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        referralBalance_[_customerAddress] = 0;
        totalBenefits_[_customerAddress] += _dividends;
        uint256 _tokens = purchaseTokens(_dividends, 0x0);
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }

    function referralBalanceOf(address _addr) public view returns (uint){
        return referralBalance_[_addr];
    }

    function exit() public {
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if (_tokens > 0) sell(_tokens);
        withdraw();
    }

    function withdraw() onlyStronghands public {
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false);
        payoutsTo_[_customerAddress] += (int256) (_dividends * magnitude);
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;
        totalBenefits_[_customerAddress] += _dividends;
        _customerAddress.transfer(_dividends);
        emit onWithdraw(_customerAddress, _dividends);
    }

    function sell(uint256 _amountOfTokens) onlyBagholders public {
        address _customerAddress = msg.sender;
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        uint256 _tokens = _amountOfTokens;
        uint256 _tron = tokensToTron_(_tokens);
        uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, exitFee_), 100);
        uint256 _taxedTron = SafeMath.sub(_tron, _dividends);

        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokens);
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _tokens);

        int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_taxedTron * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;

        if (tokenSupply_ > 0) {
            profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        }
        emit onTokenSell(_customerAddress, _tokens, _taxedTron, now, buyPrice());
    }

    function transfer(address _toAddress, uint256 _amountOfTokens) onlyBagholders public returns (bool) {
        address _customerAddress = msg.sender;
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);

        if (myDividends(true) > 0) {
            withdraw();
        }

        uint256 _dividends = 0;
        uint256 _tokenFee = 0;

        _tokenFee = SafeMath.div(SafeMath.mul(transferFee_, _amountOfTokens), 100);
        _dividends = tokensToTron_(_tokenFee);

        uint256 _taxedTokens = SafeMath.sub(_amountOfTokens, _tokenFee);
        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokenFee);
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        tokenBalanceLedger_[_toAddress] = SafeMath.add(tokenBalanceLedger_[_toAddress], _taxedTokens);
        payoutsTo_[_customerAddress] -= (int256) (profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _taxedTokens);
        if (tokenSupply_ > 0) {
            profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        }
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);
        return true;
    }

    /*----------  HELPERS AND CALCULATORS  ----------*/
    /**
     */

    function totalSupply() public view returns (uint256) {
        return tokenSupply_;
    }

    function myTokens() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }

    function myDividends(bool _includeReferralBonus) public view returns (uint256) {
        address _customerAddress = msg.sender;
        return _includeReferralBonus ? dividendsOf(_customerAddress) + referralBalance_[_customerAddress] : dividendsOf(_customerAddress) ;
    }

    function balanceOf(address _customerAddress) public view returns (uint256) {
        return tokenBalanceLedger_[_customerAddress];
    }

    function dividendsOf(address _customerAddress) public view returns (uint256) {
        return (uint256) ((int256) (profitPerShare_ * tokenBalanceLedger_[_customerAddress]) - payoutsTo_[_customerAddress]) / magnitude;
    }

    function sellPrice() public view returns (uint256) {
        // our calculation relies on the token supply, so we need supply. Doh.
        if (tokenSupply_ == 0) {
            return tokenPriceInitial_ - tokenPriceIncremental_;
        } else {
            uint256 _tron = tokensToTron_(1e18);
            uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, exitFee_), 100);
            uint256 _taxedTron = SafeMath.sub(_tron, _dividends);

            return _taxedTron;
        }
    }

    function buyPrice() public view returns (uint256) {
        if (tokenSupply_ == 0) {
            return tokenPriceInitial_ + tokenPriceIncremental_;
        } else {
            uint256 _tron = tokensToTron_(1e18);
            uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, entryFee_+roiFee_+fomoFee_), 100);
            uint256 _taxedTron = SafeMath.add(_tron, _dividends);

            return _taxedTron;

        }
    }


    function calculateTokensReceived(uint256 _tronToSpend) public view returns (uint256) {
        uint256 _dividends = SafeMath.div(SafeMath.mul(_tronToSpend, entryFee_+roiFee_+fomoFee_), 100);
        uint256 _taxedTron = SafeMath.sub(_tronToSpend, _dividends);
        uint256 _amountOfTokens = tronToTokens_(_taxedTron);
        return _amountOfTokens;
    }

    function calculateTronReceived(uint256 _tokensToSell) public view returns (uint256) {
        require(_tokensToSell <= tokenSupply_);
        uint256 _tron = tokensToTron_(_tokensToSell);
        uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, exitFee_), 100);
        uint256 _taxedTron = SafeMath.sub(_tron, _dividends);
        return _taxedTron;
    }

    /*==========================================
    =            INTERNAL FUNCTIONS            =
    ==========================================*/
    function purchaseTokens(uint256 _incomingTron, address _referredBy) internal returns (uint256) {
        require(_incomingTron >= minRequirement);
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = SafeMath.div(SafeMath.mul(_incomingTron, entryFee_), 100);
        uint256 _referralBonus = SafeMath.div(SafeMath.mul(_undividedDividends, refferalFee_), 100);
        uint256 _roiBonus = SafeMath.div(SafeMath.mul(_incomingTron, roiFee_), 100);
        uint256 _fomoBonus = SafeMath.div(SafeMath.mul(_incomingTron, fomoFee_), 100);

        uint256 _dividends = SafeMath.sub(_undividedDividends, _referralBonus);
        uint256 _taxedTron = SafeMath.sub(_incomingTron, _undividedDividends);
        _taxedTron = SafeMath.sub(_taxedTron, _roiBonus+_fomoBonus);

        uint256 _amountOfTokens = tronToTokens_(_taxedTron);
        uint256 _fee = _dividends * magnitude;

        require(_amountOfTokens > 0 && SafeMath.add(_amountOfTokens, tokenSupply_) > tokenSupply_);

        if (
            _referredBy != address(0) &&
            _referredBy != _customerAddress &&
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ) {
            referralBalance_[_referredBy] = SafeMath.add(referralBalance_[_referredBy], _referralBonus);
        } else {
            referralBalance_[ownerAddr_] = SafeMath.add(referralBalance_[ownerAddr_], _referralBonus);
        }

        if (tokenSupply_ > 0) {
            tokenSupply_ = SafeMath.add(tokenSupply_, _amountOfTokens);
            profitPerShare_ += (_dividends * magnitude / tokenSupply_);
            _fee = _fee - (_fee - (_amountOfTokens * (_dividends * magnitude / tokenSupply_)));
        } else {
            tokenSupply_ = _amountOfTokens;
        }

        tokenBalanceLedger_[_customerAddress] = SafeMath.add(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        int256 _updatedPayouts = (int256) (profitPerShare_ * _amountOfTokens - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;

        //feed roi
        WaitROIAmount_ = SafeMath.add(WaitROIAmount_, _roiBonus);
        if (WaitROIAmount_ >= 10000000) {
            botROIAddress_.transfer(WaitROIAmount_);
            WaitROIAmount_ = 0;
        }

        if (!initialState && now > lastPurchase_ + fomoCountDown_) {
            fomoWinAmount_[fomoRound_] = fomoPool_;
            fomoWinner_[fomoRound_] = holderAddr_;
            holderAddr_.transfer(fomoPool_);
            fomoPool_ = 0;
            fomoRound_ = SafeMath.add(fomoRound_, 1);
        }
        holderAddr_ = _customerAddress;
        lastPurchase_ = now;
        fomoPool_ = SafeMath.add(fomoPool_, _fomoBonus);
        emit onTokenPurchase(_customerAddress, _incomingTron, _amountOfTokens, _referredBy, now, buyPrice());

        return _amountOfTokens;
    }

    function distributeToAll(address _referredBy) public payable returns (bool){
        uint256 _incomingTron = msg.value;
        uint256 _undividedDividends = SafeMath.div(SafeMath.mul(_incomingTron, entryFee_), 100);
        uint256 _referralBonus = SafeMath.div(SafeMath.mul(_undividedDividends, refferalFee_), 100);
        uint256 _dividends = SafeMath.sub(_incomingTron, _referralBonus);
        if (
            _referredBy != address(0) &&
            _referredBy != msg.sender &&
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ) {
            referralBalance_[_referredBy] = SafeMath.add(referralBalance_[_referredBy], _referralBonus);
        } else {
            referralBalance_[ownerAddr_] = SafeMath.add(referralBalance_[ownerAddr_], _referralBonus);
        }

        if (tokenSupply_ > 0 && (!initialState)) {
            profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        } else {
            undividedRemain_ = SafeMath.add(undividedRemain_, msg.value);
        }
        return true;
    }

    function distributeRemain(uint256 _undividedRemain) internal returns (bool) {
        if (tokenSupply_ > 0 && (!initialState)) {
            undividedRemain_ = 0;
            profitPerShare_ = SafeMath.add(profitPerShare_, (_undividedRemain * magnitude) / tokenSupply_);
        }
        return true;
    }
    /**
     * Calculate Token price based on an amount of incoming tron
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function tronToTokens_(uint256 _tron) internal view returns (uint256) {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        uint256 _tokensReceived =
            (
                (
                    SafeMath.sub(
                        (sqrt
                            (
                                (_tokenPriceInitial ** 2)
                                +
                                (2 * (tokenPriceIncremental_ * 1e18) * (_tron * 1e18))
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
     * Calculate token sell value.
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function tokensToTron_(uint256 _tokens) internal view returns (uint256) {
        uint256 tokens_ = (_tokens + 1e18);
        uint256 _tokenSupply = (tokenSupply_ + 1e18);
        uint256 _tronReceived =
            (
                SafeMath.sub(
                    (
                        (
                            (
                                tokenPriceInitial_ + (tokenPriceIncremental_ * (_tokenSupply / 1e18))
                            ) - tokenPriceIncremental_
                        ) * (tokens_ - 1e18)
                    ), (tokenPriceIncremental_ * ((tokens_ ** 2 - tokens_) / 1e18)) / 2
                )
                / 1e18);

        return _tronReceived;
    }

    //This is where all your gas goes...
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
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}