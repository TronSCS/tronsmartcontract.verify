pragma solidity ^0.4.23;

/*
* 10% buy or sell fee, including 3.3% Referral fee when buying, and 3.3% dev fee when buy or sell.
* 1% transfer fee
* Admin can only set dev vault address
*/

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract OrcaTest{

    modifier onlyBagholders {
        require(myTokens() > 0);
        _;
    }

    modifier onlyStronghands {
        require(myDividends() > 0);
        _;
    }

    modifier onlyAdmin(){
        require(_admin== msg.sender);
        _;
    }
    

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

    event eventDepositDividends(uint256 value);

    string public name = "Orca";
    string public symbol = "ORCA";
    uint8 constant public decimals = 18;
    uint8 constant internal entryFee_ = 10;
    uint8 constant internal transferFee_ = 1;
    uint8 constant internal exitFee_ = 10;
    uint8 constant internal referralRate_ = 33;
    uint8 constant internal vaultRate_ = 33;
    uint256 constant internal tokenPriceInitial_ = 10000;
    uint256 constant internal tokenPriceIncremental_ = 100;
    uint256 constant internal magnitude = 2 ** 64;
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => int256) internal payoutsTo_;
    mapping(address => uint256) internal referralReceived_;
    mapping(address => uint256) internal dividendWithdrawn_;
    uint256 internal tokenSupply_;
    uint256 internal profitPerShare_;

    //global stats
    uint256 public globalDividends_;
    uint256 public globalReferrals_;

    // administrator
    address public _vault; 
    address public _admin;

     constructor()
        public
    {
        _admin = msg.sender;
        _vault = msg.sender;
    }

    function buy(address _referredBy) public payable returns (uint256) {
        purchaseTokens(msg.value, _referredBy);
    }

    function() payable public {
        purchaseTokens(msg.value, 0x0);
    }

    function reinvest() onlyStronghands public {
        uint256 _dividends = myDividends();
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        uint256 _tokens = purchaseTokens(_dividends, 0x0);
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }

    function exit() public {
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if (_tokens > 0) sell(_tokens);
        withdraw();
    }

    function withdraw() onlyStronghands public {
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends();
        payoutsTo_[_customerAddress] += (int256) (_dividends * magnitude);
        dividendWithdrawn_[_customerAddress] = SafeMath.add(dividendWithdrawn_[_customerAddress],_dividends);
    
        if(address(this).balance >= _dividends)
        {
            _customerAddress.transfer(_dividends);
        }
        emit onWithdraw(_customerAddress, _dividends);
    }

    function sell(uint256 _amountOfTokens) onlyBagholders public {
        address _customerAddress = msg.sender;
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        uint256 _tokens = _amountOfTokens;
        uint256 _tron = tokensToTron_(_tokens);
        uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, exitFee_), 100);
        uint256 _taxedTron = SafeMath.sub(_tron, _dividends);

        uint256 _vaultBonus = SafeMath.div(SafeMath.mul(_dividends,vaultRate_),100);
        if(address(this).balance >= _vaultBonus)
        {
            _dividends = SafeMath.sub(_dividends, _vaultBonus);
            address(_vault).transfer(_vaultBonus);
        }

        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokens);
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _tokens);

        int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_taxedTron * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;

        if (tokenSupply_ > 0) {
            profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
            globalDividends_ = SafeMath.add(globalDividends_,_dividends);
        }
        emit onTokenSell(_customerAddress, _tokens, _taxedTron, now, buyPrice());
    }

    function transfer(address _toAddress, uint256 _amountOfTokens) onlyBagholders public returns (bool) {
        address _customerAddress = msg.sender;
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);

        if (myDividends() > 0) {
            withdraw();
        }

        uint256 _tokenFee = SafeMath.div(SafeMath.mul(_amountOfTokens, transferFee_), 100);
        uint256 _taxedTokens = SafeMath.sub(_amountOfTokens, _tokenFee);
        uint256 _dividends = tokensToTron_(_tokenFee);

        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokenFee);
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        tokenBalanceLedger_[_toAddress] = SafeMath.add(tokenBalanceLedger_[_toAddress], _taxedTokens);
        payoutsTo_[_customerAddress] -= (int256) (profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _taxedTokens);
        profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        globalDividends_ = SafeMath.add(globalDividends_,_dividends);
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);
        return true;
    }


    function buyProxy() public payable returns (uint256) {
        purchaseTokens(msg.value, 0x0);
    }

    function depositDividends() public payable returns(bool)
    {
        uint256 _dividends = msg.value;

         // dividing by zero is a bad idea
        if (tokenSupply_ > 0 && _dividends>0) {
            // update the amount of dividends per token
            profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
            globalDividends_ = SafeMath.add(globalDividends_,_dividends);
        }

        emit eventDepositDividends(_dividends);
        return true;
    }

    function totalTronBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function totalSupply() public view returns (uint256) {
        return tokenSupply_;
    }

    function globalDividends() public view returns (uint256) {
        return globalDividends_;
    }

    function globalReferrals() public view returns (uint256) {
        return globalReferrals_;
    }

    function myTokens() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }

    function myDividends() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return dividendsOf(_customerAddress) ;
    }

    function myReferralReceived() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return referralReceived_[_customerAddress];
    }

    function myDividendWithdrawn() public view returns (uint256) {
        address _customerAddress = msg.sender;
        return dividendWithdrawn_[_customerAddress];
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
            uint256 _dividends = SafeMath.div(SafeMath.mul(_tron, entryFee_), 100);
            uint256 _taxedTron = SafeMath.add(_tron, _dividends);

            return _taxedTron;
        }
    }

    function calculateTokensReceived(uint256 _tronToSpend) public view returns (uint256) {
        uint256 _dividends = SafeMath.div(SafeMath.mul(_tronToSpend, entryFee_), 100);
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


    function purchaseTokens(uint256 _incomingTron, address _referredBy) internal returns (uint256) {
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = SafeMath.div(SafeMath.mul(_incomingTron, entryFee_), 100);
        
        uint256 _vaultBonus = SafeMath.div(SafeMath.mul(_undividedDividends,vaultRate_),100);
        if(address(this).balance >= _vaultBonus)
        {
            address(_vault).transfer(_vaultBonus);
        }
        uint256 _referralBonus = SafeMath.div(SafeMath.mul(_undividedDividends,referralRate_),100);
        uint256 _dividends = SafeMath.sub(_undividedDividends, _referralBonus);
        uint256 _taxedTron = SafeMath.sub(_incomingTron, _undividedDividends);
        uint256 _amountOfTokens = tronToTokens_(_taxedTron);
        uint256 _fee = _dividends * magnitude;

        require(_amountOfTokens > 0 && SafeMath.add(_amountOfTokens, tokenSupply_) > tokenSupply_);

        if (
            _referredBy != address(0) &&
            _referredBy != _customerAddress
        ) {
            if(address(this).balance >= _referralBonus)
            {
                _referredBy.transfer(_referralBonus);
            }
            referralReceived_[_referredBy] = SafeMath.add(referralReceived_[_referredBy],_referralBonus);
            globalReferrals_ = SafeMath.add(globalReferrals_,_dividends);
        } else {
            _dividends = SafeMath.add(_dividends, _referralBonus);
            _fee = _dividends * magnitude;
        }

        if (tokenSupply_ > 0) {
            tokenSupply_ = SafeMath.add(tokenSupply_, _amountOfTokens);
            profitPerShare_ += (_dividends * magnitude / tokenSupply_);
            _fee = _fee - (_fee - (_amountOfTokens * (_dividends * magnitude / tokenSupply_)));
            globalDividends_ = SafeMath.add(globalDividends_,_dividends);
        } else {
            tokenSupply_ = _amountOfTokens;
        }

        tokenBalanceLedger_[_customerAddress] = SafeMath.add(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        int256 _updatedPayouts = (int256) (profitPerShare_ * _amountOfTokens - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;
        emit onTokenPurchase(_customerAddress, _incomingTron, _amountOfTokens, _referredBy, now, buyPrice());

        return _amountOfTokens;
    }

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

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // administrator only

    function setVault(address a) 
        onlyAdmin() 
        public
    {
        _vault = a;
    }
}