pragma solidity ^0.4.25;

/**
 * CCBank TRON v0.2.0
 *
 * This product is protected under license.  Any unauthorized copy, modification, or use without
 * express written consent from the creators is prohibited.
 *
 * CCBank Team © 2019
 */
contract CCBank {

    using SafeMath for uint256;

    string constant public name = "CCBank TRON Network Edition";
    uint8   public constant DEFAULT_GAME_ID = 3; // default
    uint256 public constant DEFAULT_USER_ID = 3466; // default
    uint256 public constant DECIMIL_6 = 1000000;
    uint256 public constant PERCENT_DECIMIL = 10000; // 0.0001
    uint256 public constant CHECK_IN_INTERVAL_TIME = 12 * 60 * 60; // 12 hours
    uint256 public constant CHECK_IN_MAX_TIME = 36 * 60 * 60; // 36 hours
    uint256 public constant CCB_TOKEN_ID = 1002315;
    uint256 public constant VIP_0_AMOUNT = 0;
    uint256 public constant VIP_1_AMOUNT = 1000;
    uint256 public constant VIP_2_AMOUNT = 10000;
    uint256 public constant VIP_3_AMOUNT = 1000000;
    uint256 public constant VIP_4_AMOUNT = 100000000;
    uint256 public constant VIP_5_AMOUNT = 500000000;

    address public ownerAccount_;
    address public referenceAccount_;

    uint8 public nextGameId_;
    uint256 public nextUserId_;

    uint256 public checkInMinBalanceCCB_;
    uint256 public checkInMinBalanceTRX_;
    uint256 public checkInRewardTRX_;
    uint256 public checkInRewardCCB_;

    uint256 private ccbPotBalance_;
    mapping(uint256 => uint256) private trc10Token2CcbPotBalance_;
    mapping(address => uint256) private trc20Token2CcbPotBalance_;

    mapping(address => uint8) private   gameAddress2Id_;
    mapping(uint8 => Objects.Game) private   gameId2Game_;
    mapping(uint8 => GameInterface) private  gameId2Interface_;
    mapping(address => TRC20TokenInterface) private  tokenAddress2Interface_;
    mapping(address => uint8[]) private      address2GameIds_;
    mapping(uint256 => address) private      uid2Address_;
    mapping(address => Objects.User) private address2User_;

    mapping(address => uint8) private whiteList_;

    event onCheckIn(address _address, uint256 _ccbAmount, uint256 _trxAmount);
    event onPlay(uint8 _gameId, address _address, uint256 _amount);
    event onWithdraw(uint8 _gameId, address _address, uint256 _amount, bool isAdmin);
    event onWithdrawTRXMain(address _address, uint256 _amount);
    event onWithdrawTRC10Main(uint256 _tokenId, address _address, uint256 _amount);
    event onWithdrawTRC20Main(address _tokenAddress, address _address, uint256 _amount);
    event onBonusTRX(address _address, uint256 _amount);
    event onBonusTRC10Token(uint256 _tokenId, address _address, uint256 _amount);
    event onBonusTRC20Token(address _tokenAddress, address _address, uint256 _amount);
    event onProfit(uint8 _gameId, address _address, uint256 _amount, uint8 _flag);
    event onTransferCallback(uint8 _gameId, address _address, uint256 _amount);

    constructor() public {
        ownerAccount_ = msg.sender;
        referenceAccount_ = msg.sender;

        nextGameId_ = DEFAULT_GAME_ID;
        nextUserId_ = DEFAULT_USER_ID;

        checkInMinBalanceCCB_ = 0;
        checkInMinBalanceTRX_ = 1000 * DECIMIL_6;
        checkInRewardTRX_     = 10 * DECIMIL_6;
        checkInRewardCCB_     = 100 * DECIMIL_6;

        addUser__(msg.sender, 0, DEFAULT_GAME_ID);
    }

    function() external payable {
        // noop
    }

    function getGameBaseInfo(uint8 _gameId) isAdmin() public view returns (uint8, address, uint256, address, address, address) {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        Objects.Game storage game = gameId2Game_[_gameId];
        return (game.id_,
            game.contractAddress_,
            game.trc10TokenId_,
            game.trc20TokenAddress_,
            game.developerAccount_,
            game.marketingAccount_);
    }

    function getGameExtendedInfo(uint8 _gameId) isAdmin() public view returns (uint8, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool) {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        Objects.Game memory game = gameId2Game_[_gameId];
        return (game.id_,
            game.developerPotPercent_,
            game.marketingPotPercent_,
            game.ccbPotPercent_,
            game.referralPotPercent_,
            game.withdrawMinAmount_,
            game.withdrawFeePotPercent_,
            game.withdrawFeePotMax_,
            game.playMinAmount_,
            game.playMaxAmount_,
            game.playAmountProportion_,
            game.allowTransferCallback_);
    }

    function getUserInfoByAddress(address _address) public view returns (uint256, uint8, uint256, uint8, uint256, uint256, uint256, uint8[] memory) {
        require(msg.sender == _address || msg.sender == ownerAccount_ || inWhiteList__(msg.sender), "Only owner or self can check.");
        Objects.User memory user = address2User_[_address];
        uint8[] memory gameIds = address2GameIds_[_address];
        return (user.id_, user.vipLevel_, user.referralId_, user.fromGameId_, user.lastCheckInTime_, user.seriesCheckInCount_, user.totalCheckInCount_, gameIds);
    }

    function playGame(uint8 _gameId, uint256 _trc20TokenValue, uint256 _referralId, string _data) isHuman() public payable {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");

        addUser__(msg.sender, _referralId, _gameId);

        addUserInGame__(_gameId, msg.sender);

        uint256 trc10TokenId = gameId2Game_[_gameId].trc10TokenId_;
        address trc20TokenAddress = gameId2Game_[_gameId].trc20TokenAddress_;
        uint256 minAmount = gameId2Game_[_gameId].playMinAmount_;
        uint256 maxAmount = gameId2Game_[_gameId].playMaxAmount_;
        uint256 amount = 0;
        if (trc10TokenId > 0) {
            require(trc10TokenId == msg.tokenid, "Token ID mismatching.");
            require(msg.tokenvalue > 0, "Token value must be greater than zero.");
            require(msg.value == 0, "Value must be zero.");
            require(_trc20TokenValue == 0, "TRC20 token value must be zero.");
            amount = msg.tokenvalue;
        } else if (trc20TokenAddress != address(0)) {
            require(_trc20TokenValue > 0, "TRC20 token value must be greater than zero.");
            require(msg.tokenvalue == 0, "TRC10 token value must be zero.");
            require(msg.value == 0, "Value must be zero.");
            // Get TRC20 token from sender to this contract
            tokenAddress2Interface_[trc20TokenAddress].transferFrom(msg.sender, address(this), _trc20TokenValue);
            amount = _trc20TokenValue;
        } else {
            require(msg.value > 0, "Value must be greater than zero.");
            require(msg.tokenvalue == 0, "TRC10 token value must be zero.");
            require(_trc20TokenValue == 0, "TRC20 token value must be zero.");
            amount = msg.value;
        }

        if (minAmount != 0) {
            require(amount >= minAmount, "Value must be greater than min amount.");
        }

        if (maxAmount != 0) {
            require(amount <= maxAmount, "Value must be less than max amount.");
        }

        play__(_gameId, msg.sender, amount, _data);
    }

    function playGameWithBalance(uint8 _gameId, uint256 _value, string _data) isHuman()  public payable {
        require(msg.value == 0, "Transfer value must be zero.");
        require(_value > 0, "Value must be greater than zero.");
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");

        bool success;
        uint256 playAmount;
        (success, playAmount) = gameId2Interface_[_gameId].changeBalance(msg.sender, _value, false);
        require(success, "Change balance failed.");

        play__(_gameId, msg.sender, playAmount, _data);
    }

    function withdrawByGame(uint8 _gameId, uint256 _value) isHuman() public payable {
        require(msg.value == 0, "Transfer value must be zero.");
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        bool success;
        uint256 withdrawAmount;
        (success, withdrawAmount) = gameId2Interface_[_gameId].changeBalance(msg.sender, _value, false);
        require(success, "Withdraw game failed.");

        withdraw__(_gameId, msg.sender, withdrawAmount);
    }

    // returns(CCB, TRX, lastCheckInTime)
    function checkIn() isHuman() public payable returns(uint256, uint256, uint256){
        bool canCheckIn = ((address2User_[msg.sender].lastCheckInTime_ + CHECK_IN_INTERVAL_TIME) < block.timestamp);
        require(canCheckIn, "Time is not yet available.");
        address2User_[msg.sender].lastCheckInTime_ = block.timestamp;
        address2User_[msg.sender].totalCheckInCount_ = address2User_[msg.sender].totalCheckInCount_.add(1);
        if ((address2User_[msg.sender].lastCheckInTime_ + CHECK_IN_MAX_TIME) < block.timestamp) {
            address2User_[msg.sender].seriesCheckInCount_ = 0;
        }
        address2User_[msg.sender].seriesCheckInCount_ = address2User_[msg.sender].seriesCheckInCount_.add(1);

        uint256 addressBalance = 0;
        if (checkInMinBalanceCCB_ > 0 || checkInMinBalanceTRX_ > 0) {
            uint8[] memory gameIds = address2GameIds_[msg.sender];
            for (uint256 i = 0; i < gameIds.length; i++) {
                if(gameId2Game_[gameIds[i]].trc10TokenId_ != 0
                    || gameId2Game_[gameIds[i]].trc20TokenAddress_ != address(0)){
                    continue;
                }
                addressBalance = addressBalance.add(gameId2Interface_[gameIds[i]].getAddressBalanceValue(msg.sender));
            }
        }

        uint256 ccbAmount = 0;
        if (checkInRewardCCB_ > 0 && addressBalance >= checkInMinBalanceCCB_) {
            ccbAmount = checkInRewardCCB_;
            if (address2User_[msg.sender].totalCheckInCount_ == 10) {
                ccbAmount = ccbAmount + 500;
            } else if (address2User_[msg.sender].totalCheckInCount_ == 100) {
                ccbAmount = ccbAmount + 5000;
            } else if (address2User_[msg.sender].totalCheckInCount_ == 1000) {
                ccbAmount = ccbAmount + 50000;
            }

            if (address2User_[msg.sender].seriesCheckInCount_ == 10) {
                ccbAmount = ccbAmount + 1000;
            } else if (address2User_[msg.sender].seriesCheckInCount_ == 100) {
                ccbAmount = ccbAmount + 10000;
            } else if (address2User_[msg.sender].seriesCheckInCount_ == 1000) {
                ccbAmount = ccbAmount + 100000;
            }
        }

        uint256 trxAmount = 0;
        if (checkInRewardTRX_ > 0 && addressBalance >= checkInMinBalanceTRX_) {
            trxAmount = checkInRewardTRX_;
        }

        if (ccbAmount > 0) {
            transferCCB__(msg.sender, ccbAmount);
        }

        if (trxAmount > 0) {
            transfer__(msg.sender, trxAmount);
        }

        emit onCheckIn(msg.sender, ccbAmount, trxAmount);

        return (ccbAmount, trxAmount, address2User_[msg.sender].lastCheckInTime_);
    }

    function withdraw__(uint8 _gameId, address _toAddress, uint256 _value) private {
        Objects.Game storage game = gameId2Game_[_gameId];
        if (game.withdrawMinAmount_ > 0) {
            require(_value >= game.withdrawMinAmount_, "Withdraw amount must be greater than min amount.");
        }

        uint256 withdrawFee = _value.mul(game.withdrawFeePotPercent_).div(PERCENT_DECIMIL);
        if (game.withdrawFeePotMax_ != 0 && withdrawFee > game.withdrawFeePotMax_) {
            withdrawFee = game.withdrawFeePotMax_;
        }

        uint256 amount = _value.sub(withdrawFee);

        transfer__(game, _toAddress, amount);
        emit onWithdraw(_gameId, _toAddress, amount, false);

        uint256 tokenId = game.trc10TokenId_;
        address tokenAddress = game.trc20TokenAddress_;

        if (tokenId > 0) {
            if (withdrawFee > 0) {
                trc10Token2CcbPotBalance_[tokenId] = trc10Token2CcbPotBalance_[tokenId].add(withdrawFee);
            }
        } else if (tokenAddress != address(0)) {
            if (withdrawFee > 0) {
                trc20Token2CcbPotBalance_[tokenAddress] = trc20Token2CcbPotBalance_[tokenAddress].add(withdrawFee);
            }
        } else {
            if (withdrawFee > 0) {
                ccbPotBalance_ = ccbPotBalance_.add(withdrawFee);
            }
        }
    }

    function transferCallbackForGame(address _toAddress, uint256 _value, bool needChangeBalance) public payable {
        uint8 gameId = gameAddress2Id_[msg.sender]; // Must be game contract address callback.
        require(gameId != 0, "Game is not exist.");
        Objects.Game storage game = gameId2Game_[gameId];
        require(game.allowTransferCallback_, "Permission denied.");
        bool success;
        uint256 amount = _value;
        if (needChangeBalance) {
            (success, amount) = gameId2Interface_[gameId].changeBalance(msg.sender, _value, false);
            require(success, "Transfer callback change balance failed.");
        }

        transfer__(game, _toAddress, amount);
        emit onTransferCallback(gameId, _toAddress, amount);
    }

    function rechargeToGame(uint8 _gameId) public payable {
        if (gameId2Game_[_gameId].id_ != 0) {
            uint256 amount = 0;
            if(gameId2Game_[_gameId].trc10TokenId_ > 0
                && gameId2Game_[_gameId].trc10TokenId_ == _gameId){
                require(msg.tokenvalue > 0, "Transfer token value must be greater than zero.");
                amount = msg.tokenvalue;
            } else if (gameId2Game_[_gameId].trc10TokenId_ == 0
                && gameId2Game_[_gameId].trc20TokenAddress_ == address(0)) {
                require(msg.value > 0, "Transfer value must be greater than zero.");
                amount = msg.value;
            }

            if (amount > 0) {
                gameId2Interface_[_gameId].recharge(amount);
            }
        }
    }

    function getGameBalance(uint8 _gameId) public view returns(uint256)  {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        return gameId2Interface_[_gameId].getBalanceValue();
    }

    function getAddressBalance(uint8 _gameId, address _address) public view returns(uint256) {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        require(msg.sender == _address || msg.sender == ownerAccount_ || inWhiteList__(msg.sender), "Only owner or self can call.");
        return gameId2Interface_[_gameId].getAddressBalanceValue(_address);
    }

    function getCCBBonusPot() public view returns (uint256) { return ccbPotBalance_; }

    function getTRC10TokenCCBBonusPot(uint256 _tokenId) public view returns (uint256) { return trc10Token2CcbPotBalance_[_tokenId]; }

    function getTRC20TokenCCBBonusPot(address _tokenAddress) public view returns (uint256) { return trc20Token2CcbPotBalance_[_tokenAddress]; }

    function play__(uint8 _gameId, address _sender, uint256 _value, string data) private {
        Objects.Game storage game = gameId2Game_[_gameId];
        vipLevelUpdate__(_sender, _value, game.playAmountProportion_);

        bool success = gameId2Interface_[_gameId].play(_sender, _value, address2User_[_sender].vipLevel_, data);
        require(success, "Play game failed.");

        uint256 developerAmount = _value.mul(game.developerPotPercent_).div(PERCENT_DECIMIL);
        if (developerAmount > 0) {
            transfer__(game, game.developerAccount_, developerAmount);
            emit onProfit(_gameId, game.developerAccount_, developerAmount, 1);
        }

        uint256 marketingAmount = _value.mul(game.marketingPotPercent_).div(PERCENT_DECIMIL);
        if (marketingAmount > 0) {
            transfer__(game, game.marketingAccount_, marketingAmount);
            emit onProfit(_gameId, game.marketingAccount_, marketingAmount, 2);
        }

        uint256 bonusAmount = _value.mul(game.ccbPotPercent_).div(PERCENT_DECIMIL);
        if (bonusAmount > 0) {
            bonusPotUpdate__(game, bonusAmount);
        }

        uint256 referralAmount = _value.mul(game.referralPotPercent_).div(PERCENT_DECIMIL);
        if (referralAmount > 0) {
            if (address2User_[_sender].referralAddress_ != address(0)) {
                gameId2Interface_[_gameId].referralReward(_sender, address2User_[_sender].referralAddress_, referralAmount);
            } else {
                transfer__(game, referenceAccount_, referralAmount);
                emit onProfit(_gameId, referenceAccount_, referralAmount, 3);
            }
        }

        emit onPlay(_gameId, _sender, _value);
    }

    function bonusPotUpdate__(Objects.Game storage _game, uint256 _value) private {
        uint256 tokenId = _game.trc10TokenId_;
        address tokenAddress = _game.trc20TokenAddress_;
        if (tokenId > 0) {
            trc10Token2CcbPotBalance_[tokenId] = trc10Token2CcbPotBalance_[tokenId].add(_value);
        } else if (tokenAddress != address(0)) {
            trc20Token2CcbPotBalance_[tokenAddress] = trc20Token2CcbPotBalance_[tokenAddress].add(_value);
        } else {
            ccbPotBalance_ = ccbPotBalance_.add(_value);
        }
    }

    function transfer__(Objects.Game storage _game, address _toAddress, uint256 _value) private {
        uint256 tokenId = _game.trc10TokenId_;
        address tokenAddress = _game.trc20TokenAddress_;
        if (tokenId > 0) {
            _toAddress.transferToken(_value, tokenId);
        } else if (tokenAddress != address(0)) {
            tokenAddress2Interface_[tokenAddress].transfer(_toAddress, _value);
        } else {
            _toAddress.transfer(_value);
        }
    }

    function transfer__(address _toAddress, uint256 _value) private {
        _toAddress.transfer(_value);
    }

    function transferCCB__(address _toAddress, uint256 _value) private {
        transfer10Token__(CCB_TOKEN_ID, _toAddress, _value);
    }

    function transfer10Token__(uint256 _tokenId, address _toAddress, uint256 _value) private {
        _toAddress.transferToken(_value, _tokenId);
    }

    function transfer20Token__(address _tokenAddress, address _toAddress, uint256 _value) private {
        TRC20TokenInterface(_tokenAddress).transfer(_toAddress, _value);
    }

    function addUserInGame__(uint8 _gameId, address _sender) private {
        uint8[] storage gameIds = address2GameIds_[_sender];
        bool inGame = false;
        for (uint256 i = 0; i < gameIds.length; i++) {
            if (gameIds[i] == _gameId) {
                inGame = true;
                break;
            }
        }

        if (!inGame) {
            gameIds.push(_gameId);
        }
    }

    function addUser__(address _userAddress, uint256 _referralId, uint8 _gameId) private returns(bool) {
        bool isNew = false;
        if (address2User_[_userAddress].id_ == 0){ // a new user
            address2User_[_userAddress].id_      = nextUserId_;
            address2User_[_userAddress].address_ = _userAddress;

            if (_referralId != 0 && uid2Address_[_referralId] != address(0)) {
                address2User_[_userAddress].referralId_      = _referralId;
                address2User_[_userAddress].referralAddress_ = uid2Address_[_referralId];
            }

            address2User_[_userAddress].fromGameId_ = _gameId;

            uid2Address_[nextUserId_] = _userAddress;

            nextUserId_ = nextUserId_ + 1;

            isNew = true;
        }
        return isNew;
    }

    function vipLevelUpdate__(address _userAddress, uint256 _amount, uint256 _playAmountProportion) private {
        uint256 fairAmount = _amount.mul(_playAmountProportion).div(PERCENT_DECIMIL);
        address2User_[_userAddress].totalPlayAmount_ = address2User_[_userAddress].totalPlayAmount_.add(fairAmount);
        uint8 vipLevel = 0;
        if (address2User_[_userAddress].totalPlayAmount_ >= (DECIMIL_6.mul(VIP_1_AMOUNT))
            && address2User_[_userAddress].totalPlayAmount_ < (DECIMIL_6.mul(VIP_2_AMOUNT))) {
            vipLevel = 1;
        } else if (address2User_[_userAddress].totalPlayAmount_ >= (DECIMIL_6.mul(VIP_2_AMOUNT))
            && address2User_[_userAddress].totalPlayAmount_ < (DECIMIL_6.mul(VIP_3_AMOUNT))) {
            vipLevel = 2;
        } else if (address2User_[_userAddress].totalPlayAmount_ >= (DECIMIL_6.mul(VIP_3_AMOUNT))
            && address2User_[_userAddress].totalPlayAmount_ < (DECIMIL_6.mul(VIP_4_AMOUNT))) {
            vipLevel = 3;
        } else if (address2User_[_userAddress].totalPlayAmount_ >= (DECIMIL_6.mul(VIP_4_AMOUNT))
            && address2User_[_userAddress].totalPlayAmount_ < (DECIMIL_6.mul(VIP_5_AMOUNT))) {
            vipLevel = 4;
        } else if (address2User_[_userAddress].totalPlayAmount_ >= (DECIMIL_6.mul(VIP_5_AMOUNT))) {
            vipLevel = 5;
        }
        address2User_[_userAddress].vipLevel_ = vipLevel;
    }


    function inWhiteList__(address _address) private view returns (bool) {
        return (whiteList_[_address] == 1);
    }

    //^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // Only ADMIN
    //^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

    function addGame(address _contractAddress) isAdmin() public returns (uint8) {
        require(gameAddress2Id_[_contractAddress] == 0, "Game exist.");
        uint8 gameId = nextGameId_;
        gameId2Game_[gameId].id_                    = gameId;
        gameId2Game_[gameId].contractAddress_       = _contractAddress;
        gameId2Game_[gameId].trc10TokenId_          = 0;
        gameId2Game_[gameId].trc20TokenAddress_     = address(0);
        gameId2Game_[gameId].developerAccount_      = msg.sender;
        gameId2Game_[gameId].marketingAccount_      = msg.sender;
        gameId2Game_[gameId].developerPotPercent_   = 300; // default 3%
        gameId2Game_[gameId].marketingPotPercent_   = 700; // default 7%
        gameId2Game_[gameId].ccbPotPercent_         = 500; // default 5%
        gameId2Game_[gameId].referralPotPercent_    = 500; // default 5%
        gameId2Game_[gameId].withdrawMinAmount_     = 10 * DECIMIL_6; // default 10
        gameId2Game_[gameId].withdrawFeePotPercent_ = 500; // default 5%
        gameId2Game_[gameId].withdrawFeePotMax_     = 1000 * DECIMIL_6; // default 1000
        gameId2Game_[gameId].playMinAmount_         = 10 * DECIMIL_6; //  default 10
        gameId2Game_[gameId].playMaxAmount_         = 0; // default unlimited
        gameId2Game_[gameId].playAmountProportion_  = 10000; // Equivalent to 1 TRX
        gameId2Game_[gameId].allowTransferCallback_ = false;
        gameAddress2Id_[_contractAddress] = gameId;
        gameId2Interface_[gameId] = GameInterface(_contractAddress);
        require(gameId2Interface_[gameId].check(gameId), "Game is not alive.");
        nextGameId_++;
        return gameId2Game_[gameId].id_;
    }

    function addToWhiteList(address _address) isAdmin() public returns (uint8) {
        whiteList_[_address] = 1;
        return whiteList_[_address];
    }

    function removeFromWhiteList(address _address) isAdmin() public returns (uint8) {
        whiteList_[_address] = 0;
        return whiteList_[_address];
    }

    function adminWithdrawByGame(uint8 _gameId, address _toAddress, uint256 _value) isAdmin() public payable {
        require(msg.value == 0, "Transfer value must be zero.");
        require(_value > 0, "Value must be greater than zero.");
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");

        bool success = gameId2Interface_[_gameId].adminWithdraw(_toAddress, _value);
        require(success, "Admin withdraw game failed.");

        transfer__(gameId2Game_[_gameId], _toAddress, _value);
        emit onWithdraw(_gameId, _toAddress, _value, true);
    }

    function adminWithdrawTRX(address _toAddress, uint256 _value) isAdmin() public payable {
        require(msg.value == 0, "Transfer value must be zero.");
        require(_value > 0, "Value must be greater than zero.");
        uint256 allGameBalance = 0;
        for (uint8 i = DEFAULT_GAME_ID; i < nextGameId_; i++) {
            if (gameId2Game_[i].trc10TokenId_ == 0 && gameId2Game_[i].trc20TokenAddress_ == address(0)) {
                allGameBalance = allGameBalance.add(gameId2Interface_[i].getBalanceValue());
            }
        }

        uint256 leftBalance = address(this).balance.sub(_value).sub(ccbPotBalance_);
        require(leftBalance >= allGameBalance, "Insufficient withdrawable balance.");

        transfer__(_toAddress, _value);
        emit onWithdrawTRXMain(_toAddress, _value);
    }

    function adminWithdrawTRC10Token(uint256 _tokenId, address _toAddress, uint256 _value) isAdmin() public payable {
        require(msg.value == 0, "Transfer value must be zero.");
        require(_value > 0, "Value must be greater than zero.");
        uint256 allGameBalance = 0;
        for (uint8 i = DEFAULT_GAME_ID; i < nextGameId_; i++) {
            if (gameId2Game_[i].trc10TokenId_ > 0 && _tokenId == gameId2Game_[i].trc10TokenId_) {
                allGameBalance = allGameBalance.add(gameId2Interface_[i].getBalanceValue());
            }
        }

        uint256 leftBalance = address(this).tokenBalance(_tokenId).sub(_value).sub(trc10Token2CcbPotBalance_[_tokenId]);
        require(leftBalance >= allGameBalance, "Insufficient withdrawable balance.");

        transfer10Token__(_tokenId, _toAddress, _value);
        emit onWithdrawTRC10Main(_tokenId, _toAddress, _value);
    }

    function adminWithdrawTRC20Token(address _tokenAddress, address _toAddress, uint256 _value) isAdmin() public payable {
        require(msg.value == 0, "Transfer value must be zero.");
        require(_value > 0, "Value must be greater than zero.");
        uint256 allGameBalance = 0;
        for (uint8 i = DEFAULT_GAME_ID; i < nextGameId_; i++) {
            if (gameId2Game_[i].trc10TokenId_ == 0
                && gameId2Game_[i].trc20TokenAddress_ != address(0)
                && gameId2Game_[i].trc20TokenAddress_ == _tokenAddress) {
                allGameBalance = allGameBalance.add(gameId2Interface_[i].getBalanceValue());
            }
        }

        uint256 balance = TRC20TokenInterface(_tokenAddress).balanceOf(address(this));
        uint256 leftBalance = balance.sub(_value).sub(trc20Token2CcbPotBalance_[_tokenAddress]);
        require(leftBalance >= allGameBalance, "Insufficient withdrawable balance.");

        transfer20Token__(_tokenAddress, _toAddress, _value);
        emit onWithdrawTRC20Main(_tokenAddress, _toAddress, _value);
    }

    function adminTRXBonus(address _toAddress, uint256 _value) isAdmin() public {
        require(ccbPotBalance_ >= _value, "Insufficient pot balance.");
        ccbPotBalance_ = ccbPotBalance_.sub(_value);
        transfer__(_toAddress, _value);
        emit onBonusTRX(_toAddress, _value);
    }

    function adminTRC10TokenBonus(address _toAddress, uint256 _value, uint256 _tokenId) isAdmin() public {
        require(trc10Token2CcbPotBalance_[_tokenId] >= _value, "Insufficient pot balance.");
        trc10Token2CcbPotBalance_[_tokenId] = trc10Token2CcbPotBalance_[_tokenId].sub(_value);
        transfer10Token__(_tokenId, _toAddress, _value);
        emit onBonusTRC10Token(_tokenId, _toAddress, _value);
    }

    function adminTRC20TokenBonus(address _toAddress, uint256 _value, address _tokenAddress) isAdmin() public {
        require(trc20Token2CcbPotBalance_[_tokenAddress] >= _value, "Insufficient pot balance.");
        trc20Token2CcbPotBalance_[_tokenAddress] = trc20Token2CcbPotBalance_[_tokenAddress].sub(_value);
        transfer20Token__(_tokenAddress, _toAddress, _value);
        emit onBonusTRC20Token(_tokenAddress, _toAddress, _value);
    }
    function setReferenceAccount(address _address) isAdmin() public {
        require(_address != address(0), "Invalid address.");
        referenceAccount_ = _address;
    }

    function setCheckInMinBalance(uint256 _minBalanceCCB, uint256 _minBalanceTRX) isAdmin() public {
        checkInMinBalanceCCB_ = _minBalanceCCB;
        checkInMinBalanceTRX_ = _minBalanceTRX;
    }

    function setCheckInRewardTRX(uint256 _checkInRewardTRX) isAdmin() public {
        checkInRewardTRX_ = _checkInRewardTRX;
    }

    function setCheckInRewardCCB(uint256 _checkInRewardCCB) isAdmin() public {
        checkInRewardCCB_ = _checkInRewardCCB;
    }

    function setGameTRC20TokenAddress(uint8 _gameId, address _address) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        require(_address != address(0), "Invalid address.");
        gameId2Game_[_gameId].trc20TokenAddress_ = _address;
        tokenAddress2Interface_[_address] = TRC20TokenInterface(_address);
    }

    function setGameDeveloperAccount(uint8 _gameId, address _account) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        require(_account != address(0), "Invalid address.");
        gameId2Game_[_gameId].developerAccount_ = _account;
    }

    function setGameMarketingAccount(uint8 _gameId, address _account) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        require(_account != address(0), "Invalid address.");
        gameId2Game_[_gameId].marketingAccount_ = _account;
    }

    function setGameDeveloperPotPercent(uint8 _gameId, uint256 _percent) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].developerPotPercent_ = _percent;
    }

    function setGameMarketingPotPercent(uint8 _gameId, uint256 _percent) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].marketingPotPercent_ = _percent;
    }

    function setGameCcbPotPercent(uint8 _gameId, uint256 _percent) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].ccbPotPercent_ = _percent;
    }

    function setGameReferralPotPercent(uint8 _gameId, uint256 _percent) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].referralPotPercent_ = _percent;
    }

    function setGameWithdrawMinAmount(uint8 _gameId, uint256 _amount) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].withdrawMinAmount_ = _amount;
    }

    function setGameWithdrawFeePotPercent(uint8 _gameId, uint256 _percent) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].withdrawFeePotPercent_ = _percent;
    }

    function setGameWithdrawFeePotMax(uint8 _gameId, uint256 _amount) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].withdrawFeePotMax_ = _amount;
    }

    function setGamePlayMinAmount(uint8 _gameId, uint256 _amount) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].playMinAmount_ = _amount;
    }

    function setGamePlayMaxAmount(uint8 _gameId, uint256 _amount) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].playMaxAmount_ = _amount;
    }

    function setGamePlayAmountProportion(uint8 _gameId, uint256 _amount) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].playAmountProportion_ = _amount;
    }

    function setGameAllowTransferCallback(uint8 _gameId, bool allow) isAdmin() public {
        require(gameId2Game_[_gameId].id_ != 0, "Game not exist.");
        gameId2Game_[_gameId].allowTransferCallback_ = allow;
    }


    //^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // MODIFIERS
    //^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    modifier isAdmin() {
        require(msg.sender == ownerAccount_, "Sorry admins only");
        _;
    }

    modifier isHuman() {
        address addr = msg.sender;
        uint256 codeLength;

        assembly {codeLength := extcodesize(addr)}
        require(codeLength == 0, "Sorry humans only");
        _;
    }
}

library Objects {

    struct Game {
        uint8   id_;
        address contractAddress_;
        uint256 trc10TokenId_;
        address trc20TokenAddress_;
        address developerAccount_;
        address marketingAccount_;
        uint256 developerPotPercent_;
        uint256 marketingPotPercent_;
        uint256 ccbPotPercent_;
        uint256 referralPotPercent_;
        uint256 withdrawMinAmount_;
        uint256 withdrawFeePotPercent_;
        uint256 withdrawFeePotMax_;
        uint256 playMinAmount_;
        uint256 playMaxAmount_;
        uint256 playAmountProportion_; // For TRX
        bool allowTransferCallback_;
    }

    struct User {
        uint256 id_;
        address address_;
        uint8 vipLevel_;
        uint256 totalPlayAmount_;
        uint256 referralId_;
        address referralAddress_;
        uint8 fromGameId_;
        uint256 lastCheckInTime_;
        uint256 seriesCheckInCount_;
        uint256 totalCheckInCount_;
    }

}

interface GameInterface {
    function play(address _sender, uint256 _value, uint8 _vipLevel, string data) external returns(bool);
    function changeBalance(address _sender, uint256 _value, bool _isAdd) external returns(bool, uint256);
    function referralReward(address _sender, address _referralAddress, uint256 _value) external returns(bool);
    function adminWithdraw(address _toAddress, uint256 _value) external returns(bool);

    function recharge(uint256 _value) external returns(bool);
    function getBalanceValue() external view returns(uint256);
    function getAddressBalanceValue(address _address) external view returns(uint256);
    function check(uint8 _gameId) external view returns(bool);
}

interface TRC20TokenInterface {
    function balanceOf(address _owner) external returns (uint256);
    function transfer(address _to, uint256 _value) external;
    function transferFrom(address _from, address _to, uint256 _value) external;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
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
