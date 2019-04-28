pragma solidity ^0.4.25;

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

library Objects {
    struct Investment {
        uint256 planId;
        uint256 investmentDate;
        uint256 investment;
        uint256 lastWithdrawalDate;
        uint256 currentDividends;
        bool isExpired;
    }

    struct Plan {
        uint256 dailyInterest;
        uint256 term; //0 means unlimited
    }

    struct Investor {
        address addr;
        uint256 referrerEarnings;
        uint256 availableReferrerEarnings;
        uint256 referrer;
        uint256 planCount;
        mapping(uint256 => Investment) plans;
        uint256 level1RefCount;
        uint256 level2RefCount;
        uint256 level3RefCount;
        uint256 lastWithdrawalDate;
    }
}

contract Ownable {
    address public owner;

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }

}

contract TronOne is Ownable {
    using SafeMath for uint256;
    uint256 public constant VAULT_RATE = 5; 
    uint256 public constant REFERENCE_RATE = 80;
    uint256 public constant REFERENCE_LEVEL1_RATE = 50;
    uint256 public constant REFERENCE_LEVEL2_RATE = 20;
    uint256 public constant REFERENCE_LEVEL3_RATE = 5;
    uint256 public constant REFERENCE_SELF_RATE = 5;
    uint256 public constant MINIMUM = 10000000; //minimum investment needed
    uint256 public constant REFERRER_CODE = 6666; //default

    uint256 public latestReferrerCode;

    address private vaultAccount_;

    mapping(address => uint256) public address2UID;
    mapping(uint256 => Objects.Investor) public uid2Investor;
    Objects.Plan[] private investmentPlans_;

    event onInvest(address investor, uint256 amount);
    event onWithdraw(address investor, uint256 amount);

    uint256 private ti_;
    uint256 private tw_;

    /**
     * @dev Constructor Sets the original roles of the contract
     */

    constructor(address v) public {
        vaultAccount_ = v;
        _init();
    }

    function() external payable {
        if (msg.value == 0) {
            withdraw();
        } else {
            invest(0, 0); //default to buy plan 0, no referrer
        }
    }

    function _init() private {
        latestReferrerCode = REFERRER_CODE;
        address2UID[msg.sender] = latestReferrerCode;
        uid2Investor[latestReferrerCode].addr = msg.sender;
        uid2Investor[latestReferrerCode].referrer = 0;
        uid2Investor[latestReferrerCode].planCount = 0;
        investmentPlans_.push(Objects.Plan(36, 0)); //unlimited
    }

    function getCurrentPlans() public view returns (uint256[] memory, uint256[] memory, uint256[] memory) {
        uint256[] memory ids = new uint256[](investmentPlans_.length);
        uint256[] memory interests = new uint256[](investmentPlans_.length);
        uint256[] memory terms = new uint256[](investmentPlans_.length);
        for (uint256 i = 0; i < investmentPlans_.length; i++) {
            Objects.Plan storage plan = investmentPlans_[i];
            ids[i] = i;
            interests[i] = plan.dailyInterest;
            terms[i] = plan.term;
        }
        return
        (
        ids,
        interests,
        terms
        );
    }

    function getLatestReferrerCode() public view returns (uint256){
        return latestReferrerCode;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUIDByAddress(address _addr) public view returns (uint256) {
        return address2UID[_addr];
    }

    function getInvestorInfoByUID(uint256 _uid) public view returns (uint256 referrerEarnings, uint256 availableReferrerEarnings, uint256 referrer, uint256 level1RefCount, uint256 level2RefCount, uint256 level3RefCount, uint256 planCount,uint256[] memory currentDividends, uint256[] memory newDividends) {
        if (msg.sender != owner) {
            require(address2UID[msg.sender] == _uid, "only owner or self can check the investor info.");
        }
        Objects.Investor storage investor = uid2Investor[_uid];
        newDividends = new uint256[](investor.planCount);
        currentDividends = new  uint256[](investor.planCount);
        for (uint256 i = 0; i < investor.planCount; i++) {
            require(investor.plans[i].investmentDate != 0, "wrong investment date");
            currentDividends[i] = investor.plans[i].currentDividends;
            if (investor.plans[i].isExpired) {
                newDividends[i] = 0;
            } else {

                if (investmentPlans_[investor.plans[i].planId].term > 0) {
                    if (block.timestamp >= investor.plans[i].investmentDate.add(investmentPlans_[investor.plans[i].planId].term)) {
                        newDividends[i] = _calculateDividends(investor.plans[i].investment, (investmentPlans_[investor.plans[i].planId].dailyInterest).add(_calculateBonusRates(block.timestamp, investor.plans[i].lastWithdrawalDate)), investor.plans[i].investmentDate.add(investmentPlans_[investor.plans[i].planId].term), investor.plans[i].lastWithdrawalDate);
                        
                     } else {
                        newDividends[i] = _calculateDividends(investor.plans[i].investment, (investmentPlans_[investor.plans[i].planId].dailyInterest).add(_calculateBonusRates(block.timestamp, investor.plans[i].lastWithdrawalDate)), block.timestamp, investor.plans[i].lastWithdrawalDate);
                     }
                } else {
                    newDividends[i] = _calculateDividends(investor.plans[i].investment, (investmentPlans_[investor.plans[i].planId].dailyInterest).add(_calculateBonusRates(block.timestamp, investor.plans[i].lastWithdrawalDate)), block.timestamp, investor.plans[i].lastWithdrawalDate);
                }
                
            }
        }

        referrerEarnings= investor.referrerEarnings;
        availableReferrerEarnings= investor.availableReferrerEarnings;
        referrer= investor.referrer;
        level1RefCount= investor.level1RefCount;
        level2RefCount= investor.level2RefCount;
        level3RefCount= investor.level3RefCount;
        planCount= investor.planCount;

    }

    function getInvestorBonusInfoByUID(uint256 _uid) public view returns (uint256 lastWithdrawalDate, uint256 bonusLevel, uint256 daysToNextBonusLevel,uint256 nextBonusRate) {
        if (msg.sender != owner) {
            require(address2UID[msg.sender] == _uid, "only owner or self can check the investor info.");
        }
        Objects.Investor storage investor = uid2Investor[_uid];
        lastWithdrawalDate= investor.lastWithdrawalDate;
        (bonusLevel,daysToNextBonusLevel,nextBonusRate) = _calculateBonusLevel(block.timestamp, lastWithdrawalDate);
    }

    function getInvestmentPlanByUID(uint256 _uid) public view returns (uint256[] memory planIds, uint256[] memory investmentDates, uint256[] memory investments, uint256[] memory currentDividends, uint256[] memory bonusRates,uint256[] memory bonusDividends,bool[] memory isExpireds) {
        if (msg.sender != owner) {
            require(address2UID[msg.sender] == _uid, "only owner or self can check the investment plan info.");
        }
        Objects.Investor storage investor = uid2Investor[_uid];
        planIds = new  uint256[](investor.planCount);
        investmentDates = new  uint256[](investor.planCount);
        investments = new  uint256[](investor.planCount);
        currentDividends = new  uint256[](investor.planCount);
        bonusRates = new  uint256[](investor.planCount);
        bonusDividends = new  uint256[](investor.planCount);
        isExpireds = new  bool[](investor.planCount);

        for (uint256 i = 0; i < investor.planCount; i++) {
            require(investor.plans[i].investmentDate!=0,"wrong investment date");
            planIds[i] = investor.plans[i].planId;
            currentDividends[i] = investor.plans[i].currentDividends;
            investmentDates[i] = investor.plans[i].investmentDate;
            investments[i] = investor.plans[i].investment;
            if (investor.plans[i].isExpired) {
                isExpireds[i] = true;
                bonusRates[i]=0;
                bonusDividends[i]=0;
            } else {
                isExpireds[i] = false;
                if (investmentPlans_[investor.plans[i].planId].term > 0) {
                    if (block.timestamp >= investor.plans[i].investmentDate.add(investmentPlans_[investor.plans[i].planId].term)) {
                        isExpireds[i] = true;
                    }
                }
                if(!isExpireds[i])
                {
                    bonusRates[i] = _calculateBonusRates(block.timestamp, investor.plans[i].lastWithdrawalDate);
                    bonusDividends[i] = _calculateDividends(investor.plans[i].investment, bonusRates[i], block.timestamp, investor.plans[i].lastWithdrawalDate);

                }else{
                    bonusRates[i] = 0;
                    bonusDividends[i] = 0;

                }
                
            }
        }
    }

    function _addInvestor(address _addr, uint256 _referrerCode) private returns (uint256) {
        if (_referrerCode >= REFERRER_CODE) {
            //require(uid2Investor[_referrerCode].addr != address(0), "Wrong referrer code");
            if (uid2Investor[_referrerCode].addr == address(0)) {
                _referrerCode = 0;
            }
        } else {
            _referrerCode = 0;
        }
        address addr = _addr;
        latestReferrerCode = latestReferrerCode.add(1);
        address2UID[addr] = latestReferrerCode;
        uid2Investor[latestReferrerCode].addr = addr;
        uid2Investor[latestReferrerCode].referrer = _referrerCode;
        uid2Investor[latestReferrerCode].planCount = 0;
        uid2Investor[latestReferrerCode].lastWithdrawalDate = block.timestamp;
        if (_referrerCode >= REFERRER_CODE) {
            uint256 _ref1 = _referrerCode;
            uint256 _ref2 = uid2Investor[_ref1].referrer;
            uint256 _ref3 = uid2Investor[_ref2].referrer;
            uid2Investor[_ref1].level1RefCount = uid2Investor[_ref1].level1RefCount.add(1);
            if (_ref2 >= REFERRER_CODE) {
                uid2Investor[_ref2].level2RefCount = uid2Investor[_ref2].level2RefCount.add(1);
            }
            if (_ref3 >= REFERRER_CODE) {
                uid2Investor[_ref3].level3RefCount = uid2Investor[_ref3].level3RefCount.add(1);
            }
        }
        return (latestReferrerCode);
    }

    function _invest(address _addr, uint256 _planId, uint256 _referrerCode, uint256 _amount) private returns (bool) {
        require(_planId >= 0 && _planId < investmentPlans_.length, "Wrong investment plan id");
        require(_amount >= MINIMUM, "Less than the minimum amount of deposit requirement");
        uint256 uid = address2UID[_addr];
        if (uid == 0) {
            uid = _addInvestor(_addr, _referrerCode);
            //new user
        } else {//old user
            //do nothing, referrer is permenant
        }
        uint256 planCount = uid2Investor[uid].planCount;
        Objects.Investor storage investor = uid2Investor[uid];
        investor.plans[planCount].planId = _planId;
        investor.plans[planCount].investmentDate = block.timestamp;
        investor.plans[planCount].lastWithdrawalDate = block.timestamp;
        investor.plans[planCount].investment = _amount;
        investor.plans[planCount].currentDividends = 0;
        investor.plans[planCount].isExpired = false;

        investor.planCount = investor.planCount.add(1);

        _calculateReferrerReward(uid, _amount, investor.referrer);

        ti_ = ti_.add(_amount);

        return true;
    }

    function invest(uint256 _referrerCode, uint256 _planId) public payable {
        if (_invest(msg.sender, _planId, _referrerCode, msg.value)) {
            emit onInvest(msg.sender, msg.value);
        }
    }

    function withdraw() public payable {
        require(msg.value == 0, "withdrawal doesn't allow to transfer trx simultaneously");
        uint256 uid = address2UID[msg.sender];
        require(uid != 0, "Can not withdraw because no any investments");
        uint256 withdrawalAmount = 0;
        uid2Investor[uid].lastWithdrawalDate = block.timestamp;

        for (uint256 i = 0; i < uid2Investor[uid].planCount; i++) {
            if (uid2Investor[uid].plans[i].isExpired) {
                continue;
            }

            Objects.Plan storage plan = investmentPlans_[uid2Investor[uid].plans[i].planId];

            bool isExpired = false;
            uint256 withdrawalDate = block.timestamp;
            if (plan.term > 0) {
                uint256 endTime = uid2Investor[uid].plans[i].investmentDate.add(plan.term);
                if (withdrawalDate >= endTime) {
                    withdrawalDate = endTime;
                    isExpired = true;
                }
            }

            uint256 amount = _calculateDividends(uid2Investor[uid].plans[i].investment , plan.dailyInterest , withdrawalDate , uid2Investor[uid].plans[i].lastWithdrawalDate);

            uint256 _bonusDailyInterestRate = _calculateBonusRates(block.timestamp, uid2Investor[uid].plans[i].lastWithdrawalDate);
                
            if(_bonusDailyInterestRate > 0) 
            {
                uint256 bonus = _calculateDividends(uid2Investor[uid].plans[i].investment, _bonusDailyInterestRate, withdrawalDate, uid2Investor[uid].plans[i].lastWithdrawalDate);
           
                amount = amount.add(bonus);

            }
            
            withdrawalAmount += amount;

            msg.sender.transfer(amount);

            uid2Investor[uid].plans[i].lastWithdrawalDate = withdrawalDate;
            uid2Investor[uid].plans[i].isExpired = isExpired;
            uid2Investor[uid].plans[i].currentDividends += amount;
        }
        tw_ = tw_.add(withdrawalAmount);

        if (uid2Investor[uid].availableReferrerEarnings>0) {
            withdrawalAmount = withdrawalAmount.add(uid2Investor[uid].availableReferrerEarnings);
            tw_ = tw_.add(uid2Investor[uid].availableReferrerEarnings);
            msg.sender.transfer(uid2Investor[uid].availableReferrerEarnings);
            uid2Investor[uid].referrerEarnings = uid2Investor[uid].availableReferrerEarnings.add(uid2Investor[uid].referrerEarnings);
            uid2Investor[uid].availableReferrerEarnings = 0;     
        }

        _allocateVault(withdrawalAmount);

        emit onWithdraw(msg.sender, withdrawalAmount);
    }

    function _allocateVault(uint256 withdrawalAmount) private returns (bool) {
        if(withdrawalAmount > 0)
        {
            uint256 vaultFee= (((withdrawalAmount.mul(VAULT_RATE)).mul(tw_)).div(ti_)).div(6);

            if(address(this).balance >= vaultFee && vaultFee>0)
            {
                vaultAccount_.transfer(vaultFee);
                tw_ = tw_.add(vaultFee);
            }
        }

        return true;
    }

    function _calculateDividends(uint256 _amount, uint256 _dailyInterestRate, uint256 _now, uint256 _start) private pure returns (uint256) {
       
        return (_amount * _dailyInterestRate / 1000 * (_now - _start)) / (60*60*24);

    }
    function _calculateBonusLevel(uint256 _now, uint256 _start) private pure returns (uint256,uint256,uint256) {
        

        if(_start>0)
        {
            uint256 dayCount = 0;
            if(_now > _start)
            {
                dayCount = (_now - _start) / (60*60*24);
            }

            if (dayCount < 5) {
              return (0,(5-dayCount),5);
            } else if (dayCount < 10) {
              return (1,(10-dayCount),10);
            } else if (dayCount < 20) {
              return (2,(20-dayCount),20);
            } else if (dayCount < 30) {
              return (3,(30-dayCount),30);
            } else {
              return (4,0,0);
            }
        }else{
            return (0,0,0);
        }
        
    }

    function _calculateBonusRates(uint256 _now, uint256 _start) private pure returns (uint256) {
        if(_start>0)
        {
            uint256 dayCount = 0;
            if(_now > _start)
            {
                dayCount = (_now - _start) / (60*60*24);
            }

            if (dayCount < 5) {
              return 0;
            } else if (dayCount < 10) {
              return 5; // extra 0.5%
            } else if (dayCount < 20) {
              return 10; // extra 1%
            } else if (dayCount < 30) {
              return 20; // extra 2%
            } else {
              return 30; // extra 3%
            }

        }else{
            return 0;
        }
    }

    function _calculateReferrerReward(uint256 _uid, uint256 _investment, uint256 _referrerCode) private {

        uint256 _allReferrerAmount = (_investment.mul(REFERENCE_RATE)).div(1000);
        if (_referrerCode != 0) {
            uint256 _ref1 = _referrerCode;
            uint256 _ref2 = uid2Investor[_ref1].referrer;
            uint256 _ref3 = uid2Investor[_ref2].referrer;
            uint256 _refAmount = 0;

            if (_ref1 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL1_RATE)).div(1000);
                _allReferrerAmount = _allReferrerAmount.sub(_refAmount);
                uid2Investor[_ref1].availableReferrerEarnings = _refAmount.add(uid2Investor[_ref1].availableReferrerEarnings);
               
            
                _refAmount = (_investment.mul(REFERENCE_SELF_RATE)).div(1000);
                uid2Investor[_uid].availableReferrerEarnings =  _refAmount.add(uid2Investor[_uid].availableReferrerEarnings);

            }

            if (_ref2 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL2_RATE)).div(1000);
                _allReferrerAmount = _allReferrerAmount.sub(_refAmount);
                uid2Investor[_ref2].availableReferrerEarnings = _refAmount.add(uid2Investor[_ref2].availableReferrerEarnings);

            }

            if (_ref3 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL3_RATE)).div(1000);
                _allReferrerAmount = _allReferrerAmount.sub(_refAmount);
                uid2Investor[_ref3].availableReferrerEarnings = _refAmount.add(uid2Investor[_ref3].availableReferrerEarnings);

            }
        }

        if (_allReferrerAmount > 0) {
            uid2Investor[REFERRER_CODE].availableReferrerEarnings = _allReferrerAmount.add(uid2Investor[REFERRER_CODE].availableReferrerEarnings);
        }
    }

}
