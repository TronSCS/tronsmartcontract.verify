pragma solidity ^0.4.24;

/*
* [?] 20%	Total Buy-in fee
* [?] 5%	Total Sell-out fee
*/

contract BlockVest {

	modifier onlyBagholders {
		require(myTokens() > 0);
		_;
	}

	modifier onlyStronghands {
		require(myDividends(true) > 0);
		_;
	}

	event onTokenPurchase(
		address indexed customerAddress,
		uint256 incomingBTT,
		uint256 tokensMinted,
		address indexed referredBy,
		uint timestamp,
		uint256 price
		);

	event onReferrerOneSet(
		address indexed user,
		address indexed referrer
		);

	event onReferrerTwoSet(
		address indexed user,
		address indexed referrer
		);

	event onReferrerThreeSet(
		address indexed user,
		address indexed referrer
		);

	event onTokenSell(
		address indexed customerAddress,
		uint256 tokensBurned,
		uint256 bttEarned,
		uint timestamp,
		uint256 price
		);

	event onReinvestment(
		address indexed customerAddress,
		uint256 bttReinvested,
		uint256 tokensMinted
		);

	event onWithdraw(
		address indexed customerAddress,
		uint256 bttWithdrawn
		);

	event Transfer(
		address indexed from,
		address indexed to,
		uint256 tokens
		);

	string public name = "BlockVest";
	string public symbol = "BVT";
	uint8 constant public decimals = 18;

    uint8 constant internal buyFee_ = 10;			// 10% Divis (on buy or reinvest)
    uint8 constant internal referralFeeOne_ = 5;	//  5% Ref1 Fee (on buy or reinvest)
    uint8 constant internal referralFeeTwo_ = 3;	//  3% Ref2 Fee (on buy or reinvest)
    uint8 constant internal referralFeeThree_ = 2;	//  2% Ref3 Fee (on buy or reinvest)
    uint8 constant internal sellFee_ = 5;			//  5% Divis
    uint8 constant internal transferFee_ = 1;		//  1% Divis

    uint256 constant internal tokenPriceInitial_ = 10000;
    uint256 constant internal tokenPriceIncremental_ = 100;
    uint256 constant internal magnitude = 2 ** 64;
    uint256 public stakingRequirement = 50e18;		// 50 tokens required for masternodes

    mapping(address => address) internal userToReferrerOne_;
    mapping(address => address) internal userToReferrerTwo_;
    mapping(address => address) internal userToReferrerThree_;

    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => int256) internal payoutsTo_;

	address internal marketing_;
	address internal dev_;
    uint256 internal tokenSupply_;
    uint256 internal profitPerShare_;

    constructor(address _marketing, address _dev) public {
        marketing_ = _marketing;
        dev_ = _dev;
    }

    function () public payable {
    	require(msg.tokenid==1002000);
        buy(address(0));
    }

    function buy(address _referredBy) public payable returns (uint256) {
    	require(msg.tokenid==1002000);
    	purchaseTokens(msg.tokenvalue, _referredBy);
    }

    function reinvest() onlyStronghands public {
    	uint256 _dividends = myDividends(false);
    	address _user = msg.sender;
    	payoutsTo_[_user] +=  (int256) (_dividends * magnitude);
    	_dividends += referralBalance_[_user];
    	referralBalance_[_user] = 0;
    	uint256 _tokens = purchaseTokens(_dividends, 0x0);
    	emit onReinvestment(_user, _dividends, _tokens);
    }

    function exit() public {
    	address _user = msg.sender;
    	uint256 _tokens = tokenBalanceLedger_[_user];
    	if (_tokens > 0) sell(_tokens);
    	withdraw();
    }

    function withdraw() onlyStronghands public {
    	address _user = msg.sender;
    	uint256 _dividends = myDividends(false);
    	payoutsTo_[_user] += (int256) (_dividends * magnitude);
    	_dividends += referralBalance_[_user];
    	referralBalance_[_user] = 0;
    	transferDivis(_user, _dividends);
    	emit onWithdraw(_user, _dividends);
    }

    function sell(uint256 _amountOfTokens) onlyBagholders public {
    	address _user = msg.sender;
    	require(_amountOfTokens <= tokenBalanceLedger_[_user]);
    	uint256 _tokens = _amountOfTokens;
    	uint256 _btt = tokensToBTT_(_tokens);
    	uint256 _dividends = SafeMath.div(SafeMath.mul(_btt, sellFee_), 100);
    	uint256 _taxedBTT = SafeMath.sub(_btt, _dividends);

    	tokenSupply_ = SafeMath.sub(tokenSupply_, _tokens);
    	tokenBalanceLedger_[_user] = SafeMath.sub(tokenBalanceLedger_[_user], _tokens);

    	int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_taxedBTT * magnitude));
    	payoutsTo_[_user] -= _updatedPayouts;

    	if (tokenSupply_ > 0) {
    		profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
    	}
    	emit onTokenSell(_user, _tokens, _taxedBTT, now, buyPrice());
    }

    function transfer(address _toAddress, uint256 _amountOfTokens) onlyBagholders public returns (bool) {
    	address _user = msg.sender;
    	require(_amountOfTokens <= tokenBalanceLedger_[_user]);

    	if (myDividends(true) > 0) {
    		withdraw();
    	}

    	uint256 _tokenFee = SafeMath.div(SafeMath.mul(_amountOfTokens, transferFee_), 100);
    	uint256 _taxedTokens = SafeMath.sub(_amountOfTokens, _tokenFee);
    	uint256 _dividends = tokensToBTT_(_tokenFee);

    	tokenSupply_ = SafeMath.sub(tokenSupply_, _tokenFee);
    	tokenBalanceLedger_[_user] = SafeMath.sub(tokenBalanceLedger_[_user], _amountOfTokens);
    	tokenBalanceLedger_[_toAddress] = SafeMath.add(tokenBalanceLedger_[_toAddress], _taxedTokens);
    	payoutsTo_[_user] -= (int256) (profitPerShare_ * _amountOfTokens);
    	payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _taxedTokens);
    	profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
    	emit Transfer(_user, _toAddress, _taxedTokens);
    	return true;
    }

    function donate() public payable {
    	require(msg.tokenid==1002000);
    	profitPerShare_ += (msg.tokenvalue * magnitude / tokenSupply_);
    }

    function getTokenBalance(address accountAddress) public view returns (uint256){
        return address(accountAddress).tokenBalance(1002000);
    }

    // depricated
    function totalTronBalance() public view returns (uint256) {
    	return address(this).tokenBalance(1002000);
    }

    function totalSupply() public view returns (uint256) {
    	return tokenSupply_;
    }

    function myTokens() public view returns (uint256) {
    	address _user = msg.sender;
    	return balanceOf(_user);
    }

    function myDividends(bool _includeReferralBonus) public view returns (uint256) {
        address _user = msg.sender;
        return _includeReferralBonus ? dividendsOf(_user) + referralBalance_[_user] : dividendsOf(_user);
    }

    function myReferralBalance() public view returns (uint256) {
        address _user = msg.sender;
        return referralBalance_[_user];
    }

    function balanceOf(address _user) public view returns (uint256) {
    	return tokenBalanceLedger_[_user];
    }

    function dividendsOf(address _user) public view returns (uint256) {
    	return (uint256) ((int256) (profitPerShare_ * tokenBalanceLedger_[_user]) - payoutsTo_[_user]) / magnitude;
    }

    function levelOneRefOf(address _user) public view returns (address){
    	return userToReferrerOne_[_user];
    }

    function levelTwoRefOf(address _user) public view returns (address){
    	return userToReferrerTwo_[_user];
    }

    function levelThreeRefOf(address _user) public view returns (address){
    	return userToReferrerThree_[_user];
    }

    function sellPrice() public view returns (uint256) {
        if (tokenSupply_ == 0) {
        	return tokenPriceInitial_ - tokenPriceIncremental_;
        } else {
        	uint256 _btt = tokensToBTT_(1e18);
        	uint256 _dividends = SafeMath.div(SafeMath.mul(_btt, sellFee_), 100);
        	uint256 _taxedBTT = SafeMath.sub(_btt, _dividends);
        	return _taxedBTT;
        }
    }

    function buyPrice() public view returns (uint256) {
    	if (tokenSupply_ == 0) {
    		return tokenPriceInitial_ + tokenPriceIncremental_;
    	} else {
    		uint256 _btt = tokensToBTT_(1e18);
    		uint256 _dividends = SafeMath.div(SafeMath.mul(_btt, buyFee_), 100);
    		uint256 _taxedBTT = SafeMath.add(_btt, _dividends);
    		return _taxedBTT;
    	}
    }

    function calculateTokensReceived(uint256 _bttToSpend) public view returns (uint256) {
    	uint256 _dividends = SafeMath.div(SafeMath.mul(_bttToSpend, buyFee_), 100);
    	uint256 _taxedBTT = SafeMath.sub(_bttToSpend, _dividends);
    	uint256 _amountOfTokens = bttToTokens_(_taxedBTT);

    	return _amountOfTokens;
    }

    function calculateTronReceived(uint256 _tokensToSell) public view returns (uint256) {
    	require(_tokensToSell <= tokenSupply_);
    	uint256 _btt = tokensToBTT_(_tokensToSell);
    	uint256 _dividends = SafeMath.div(SafeMath.mul(_btt, sellFee_), 100);
    	uint256 _taxedBTT = SafeMath.sub(_btt, _dividends);
    	return _taxedBTT;
    }

	function referrerAllowed(address _user, address _currentReferrer, address _newReferrer) internal view returns(bool) {
    	return (
    		addressNotSet(_currentReferrer) &&
    		isAddress(_newReferrer) &&
    		isNotSelf(_user, _newReferrer) &&
    		hasEnoughBags(_newReferrer)
		);
    }

    function addressNotSet(address _address) internal pure returns(bool) {
    	return (_address == 0x0);
    }

    function isAddress(address _address) internal pure returns(bool) {
    	return (_address != 0x0);
    }

    function isNotSelf(address _user, address _compare) internal pure returns(bool) {
    	return (_user != _compare);
    }

    function hasEnoughBags(address _address) internal view returns(bool) {
        return (tokenBalanceLedger_[_address] >= stakingRequirement);
    }

    function purchaseTokens(uint256 _incomingBTT, address _referredBy) internal returns (uint256) {
        address _user = msg.sender;

    	uint256 _buyInDividends = SafeMath.div(SafeMath.mul(_incomingBTT, buyFee_), 100);
    	uint256 _referralBonusOne = SafeMath.div(SafeMath.mul(_incomingBTT, referralFeeOne_), 100);
    	uint256 _referralBonusTwo = SafeMath.div(SafeMath.mul(_incomingBTT, referralFeeTwo_), 100);
    	uint256 _referralBonusThree = SafeMath.div(SafeMath.mul(_incomingBTT, referralFeeThree_), 100);

    	uint256 _taxedBTT = SafeMath.sub(_incomingBTT, (_buyInDividends + _referralBonusOne + _referralBonusTwo + _referralBonusThree));
    	uint256 _amountOfTokens = bttToTokens_(_taxedBTT);
    	uint256 _fee = _buyInDividends * magnitude;

    	require(_amountOfTokens > 0 && SafeMath.add(_amountOfTokens, tokenSupply_) > tokenSupply_);

        // REFERRAL distribution
        referrerUpdate(_user, _referredBy);
        // Level 1
        if (addressNotSet(userToReferrerOne_[_user])){
    		transferDivis(marketing_, _referralBonusOne);
    	} else {
    		referralBalance_[userToReferrerOne_[_user]] = SafeMath.add(referralBalance_[userToReferrerOne_[_user]], _referralBonusOne);
    	}
    	// Level 2
        if (addressNotSet(userToReferrerTwo_[_user])){
    		transferDivis(marketing_, _referralBonusTwo);
    	} else {
    		referralBalance_[userToReferrerTwo_[_user]] = SafeMath.add(referralBalance_[userToReferrerTwo_[_user]], _referralBonusTwo);
    	}
    	// Level 3
        if (addressNotSet(userToReferrerThree_[_user])){
    		transferDivis(marketing_, _referralBonusThree);
    	} else {
    		referralBalance_[userToReferrerThree_[_user]] = SafeMath.add(referralBalance_[userToReferrerThree_[_user]], _referralBonusThree);
    	}

        // PROFIT distribution
        if (tokenSupply_ > 0) {
        	tokenSupply_ = SafeMath.add(tokenSupply_, _amountOfTokens);
        	profitPerShare_ += (_buyInDividends * magnitude / tokenSupply_);
        	_fee = _fee - (_fee - (_amountOfTokens * (_buyInDividends * magnitude / tokenSupply_)));
        } else {
        	tokenSupply_ = _amountOfTokens;
        }

        tokenBalanceLedger_[_user] = SafeMath.add(tokenBalanceLedger_[_user], _amountOfTokens);
        int256 _updatedPayouts = (int256) (profitPerShare_ * _amountOfTokens - _fee);
        payoutsTo_[_user] += _updatedPayouts;
        emit onTokenPurchase(_user, _incomingBTT, _amountOfTokens, _referredBy, now, buyPrice());

        return _amountOfTokens;
    }

    // 3-level referral system
    function referrerUpdate(address _user, address _levelOneRef) internal{
    	// level 1
    	if (referrerAllowed(_user, userToReferrerOne_[_user], _levelOneRef)){
    		userToReferrerOne_[_user] = _levelOneRef;
    		emit onReferrerOneSet(_user, _levelOneRef);
        }
		// level 2
		address _levelTwoRef = userToReferrerOne_[_levelOneRef];
		if (referrerAllowed(_user, userToReferrerTwo_[_user], _levelTwoRef)){
			userToReferrerTwo_[_user] = _levelTwoRef;
			emit onReferrerTwoSet(_user, _levelTwoRef);
        }
		// level 3
		address _levelThreeRef = userToReferrerOne_[_levelTwoRef];
		if (referrerAllowed(_user, userToReferrerThree_[_user], _levelThreeRef)){
			userToReferrerThree_[_user] = _levelThreeRef;
			emit onReferrerThreeSet(_user, _levelThreeRef);
		}
    }

    function transferDivis(address _receiver, uint256 _payout) internal {
    	trcToken id = 1002000;
    	if (_receiver == marketing_){
    		uint256 _value = SafeMath.div(SafeMath.mul(_payout, 50), 100);
    		marketing_.transferToken(_value, id);
    		dev_.transferToken(_value, id);
    	} else {
    		_receiver.transferToken(_payout, id);
    	}
    }

    function bttToTokens_(uint256 _btt) internal view returns (uint256) {
    	uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
    	uint256 _tokensReceived =
    	(
    		(
    			SafeMath.sub(
    				(sqrt
    					(
    						(_tokenPriceInitial ** 2)
    						+
    						(2 * (tokenPriceIncremental_ * 1e18) * (_btt * 1e18))
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

    function tokensToBTT_(uint256 _tokens) internal view returns (uint256) {
    	uint256 tokens_ = (_tokens + 1e18);
    	uint256 _tokenSupply = (tokenSupply_ + 1e18);
    	uint256 _bttReceived =
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

    	return _bttReceived;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
    	uint256 z = (x + 1) / 2;
    	y = x;

    	while (z < y) {
    		y = z;
    		z = (x / z + z) / 2;
    	}
    }
}

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