pragma solidity ^0.4.25;

/**
 * CCBank TRON v0.2.0
 *
 * This product is protected under license.  Any unauthorized copy, modification, or use without
 * express written consent from the creators is prohibited.
 *
 * CCBank Team © 2019
 */
contract CCBank_TRX_Fund {

    using SafeMath for uint256;

    uint8   constant public GAME_ID = 3;

    uint256 constant public PERCENT_DECIMIL = 10000; // 0.0001
    uint256 constant public GAME_POT_PERCENT = 7000;
    uint256 constant public INVESTOR_POT_PERCENT = 1000;
    uint256 constant public REFERRAL_POT_PERCENT = 500;

    uint256 public gameBalance_;

    address public owner_;
    address public ccbankAddress_;

    mapping(address => Objects.Investor) address2Investor_;
    mapping(address => address) address2Referral_;

    constructor() public {
        owner_ = msg.sender;
    }

    function() external payable {
        // ignore
    }

    function getInvestorInfo(address _address)
        external view returns(uint256, uint256, uint256, uint256, uint256){
        require(msg.sender == _address || msg.sender == owner_, "Only owner or self can check the investor info.");
        Objects.Investor storage inv = address2Investor_[_address];
        return (inv.recordCount_, inv.totalInvestment_, inv.referralCount_, inv.referralAwarded_, inv.referralTotalReward_);
    }

    function getInvestorRecords(address _address)
        external view returns(uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory){
        require(msg.sender == _address || msg.sender == owner_, "Only owner or self can check the investor info.");
        Objects.Investor storage inv = address2Investor_[_address];
        uint256[] memory amountArr = new uint256[](inv.recordCount_);
        uint256[] memory dailyROIArr = new uint256[](inv.recordCount_);
        uint256[] memory dataTimeArr = new uint256[](inv.recordCount_);
        uint256[] memory withdrawalsArr = new uint256[](inv.recordCount_);
        uint256[] memory withdrawableArr = new uint256[](inv.recordCount_);

        for (uint256 i = 0; i < inv.recordCount_; i++) {
            Objects.Investment storage invtmt = inv.records_[i + 1];
            if (invtmt.dataTime_ == 0) {
                continue;
            }
            amountArr[i] = invtmt.amount_;
            dailyROIArr[i] = invtmt.dailyROI_;
            dataTimeArr[i] = invtmt.dataTime_;
            withdrawalsArr[i] = invtmt.withdrawalsAmount_;
            withdrawableArr[i] = calculateDividends__(invtmt.amount_, invtmt.dailyROI_, block.timestamp, invtmt.lastWithdrawTime_, invtmt.dataTime_);
        }

        return (amountArr, dailyROIArr, dataTimeArr, withdrawalsArr, withdrawableArr);
    }


    function play(address _sender, uint256 _value, uint8 _vipLevel, string _data) isCCBank() external returns(bool){
        if (bytes(_data).length != 0) { // noop
        }

        Objects.Investor storage investor = address2Investor_[_sender];
        investor.address_         = _sender;
        investor.totalInvestment_ = investor.totalInvestment_.add(_value);
        investor.recordCount_     = investor.recordCount_ + 1;
        investor.records_[investor.recordCount_] = Objects.Investment(_value, vip2DailyROI__(_vipLevel), block.timestamp, block.timestamp, 0, 0);
        gameBalance_ = gameBalance_.add(_value.mul(GAME_POT_PERCENT).div(PERCENT_DECIMIL));
        return true;
    }

    // withdraw
    function changeBalance(address _sender, uint256 _value, bool _isAdd) isCCBank() external returns(bool, uint256){
        require(!_isAdd, "Unsupport operation.");
        if (_value == 0) {
            // Unsupport value. Unused value.
        }
        uint256 availableBalance = checkAvailableBalance__(_sender, true);
        require(availableBalance <= gameBalance_, "Insufficient game balance.");
        gameBalance_ = gameBalance_.sub(availableBalance);
        return (true, availableBalance);
    }

    function referralReward(address _sender, address _referralAddress, uint256 _value) external returns(bool){
        if (_referralAddress != address(0)) {
            if (address2Referral_[_sender] == address(0)) {
                address2Referral_[_sender] = _referralAddress;
                address2Investor_[_referralAddress].referralCount_ = address2Investor_[_referralAddress].referralCount_ + 1;
            }

            address2Investor_[_referralAddress].referralTotalReward_ = address2Investor_[_referralAddress].referralTotalReward_.add(_value);
        }
    }

    function adminWithdraw(address _toAddress, uint256 _value) isCCBank() external returns(bool) {
        // Administrators can not withdraw from this game balance
        if (_toAddress != address(0)) {}
        if (_value > 0) {}
        gameBalance_ = gameBalance_.sub(_value);
        return false;
    }

    function recharge(uint256 _value) isCCBank() external returns(bool){
        gameBalance_ = gameBalance_.add(_value);
        return true;
    }

    function getBalanceValue() external view returns(uint256){
        return gameBalance_;
    }

    function getAddressBalanceValue(address _address) external returns(uint256){
        require(msg.sender == ccbankAddress_ || msg.sender == _address || msg.sender == owner_, "Only owner or self can check the investor info.");
        return checkAvailableBalance__(_address, false);
    }

    function check(uint8 _gameId) external pure returns(bool){
        return (GAME_ID == _gameId);
    }

    function setCCBankAddress(address _address) isAdmin() external {
        require(_address != address(0), "Invalid address.");
        require(ccbankAddress_ == address(0), "CCBank address inited.");
        ccbankAddress_ = _address;
    }

    function withdrawTRX(uint256 _value) isAdmin() external {
        msg.sender.transfer(_value);
    }

    function withdrawTRC10Token(uint256 _trc10TokenId, uint256 _value) isAdmin() external {
        msg.sender.transferToken(_value, _trc10TokenId);
    }

    function withdrawTRC20Token(address _trc20TokenAddress, uint256 _value) isAdmin() external {
        TRC20TokenInterface(_trc20TokenAddress).transfer(msg.sender, _value);
    }

    function vip2DailyROI__(uint8 _vipLevel) private pure returns(uint256){
        uint256 dailyROI = 50;
        if (_vipLevel == 1) {
            dailyROI = 80;
        } else if (_vipLevel == 2){
            dailyROI = 100;
        } else if (_vipLevel >= 3){
            dailyROI = 120;
        }
        return dailyROI;
    }

    function calculateDividends__(uint256 _amount, uint256 _dailyROI, uint256 _now, uint256 _lastWithdrawTime, uint256 _investTime) private pure returns (uint256) {
        uint256 investOnceAward = (_lastWithdrawTime == _investTime) ? _amount.mul(INVESTOR_POT_PERCENT).div(PERCENT_DECIMIL) : 0;
        return (_amount * _dailyROI / 1000 * (_now - _lastWithdrawTime)) / (60 * 60 * 24) + investOnceAward;
    }

    function checkAvailableBalance__(address _address, bool isWithdraw) private returns (uint256) {
        uint256 total = 0;
        Objects.Investor storage inv = address2Investor_[_address];
        for (uint i = 0; i < inv.recordCount_; i++) {
            Objects.Investment storage invtmt = inv.records_[i + 1];
            if (invtmt.dataTime_ == 0) {
                continue;
            }
            uint256 amount = calculateDividends__(invtmt.amount_, invtmt.dailyROI_, block.timestamp, invtmt.lastWithdrawTime_, invtmt.dataTime_);
            total = total.add(amount);
            if (isWithdraw) {
                invtmt.withdrawalsAmount_ = invtmt.withdrawalsAmount_.add(amount);
                invtmt.lastWithdrawTime_ = block.timestamp;
            }
        }
        uint256 availableReward = inv.referralTotalReward_.sub(inv.referralAwarded_);
        total = total.add(availableReward);
        if (isWithdraw) {
            inv.referralAwarded_ = inv.referralAwarded_.add(availableReward);
        }
        return total;
    }


    //^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // MODIFIERS
    //^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    modifier isCCBank() {
        require(msg.sender == ccbankAddress_, "Only CCBank.");
        _;
    }

    modifier isAdmin() {
        require(msg.sender == owner_, "Sorry admins only");
        _;
    }

}

library Objects{

    struct Investor {
        address address_;
        uint256 recordCount_;
        mapping(uint256 => Investment) records_;
        uint256 totalInvestment_;
        uint256 referralCount_;
        uint256 referralAwarded_;
        uint256 referralTotalReward_;
    }

    struct Investment {
        uint256 amount_;
        uint256 dailyROI_;
        uint256 dataTime_;
        uint256 lastWithdrawTime_;
        uint256 withdrawableAmount_;
        uint256 withdrawalsAmount_;
    }
}


interface TRC20TokenInterface {
    function balanceOf(address _owner) external returns (uint256 );
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
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
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
