pragma solidity ^0.4.23;

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

contract Ownable {
    address public owner;
    event onOwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0));
        emit onOwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    modifier isNotContract {
        require(tx.origin == msg.sender);
        _;
    }    
}

contract BatBank is Ownable {
    // Account details
    // referrer, visitTime, refCount, lockPeriod, unfreezeTime, balance, frozenBalance, resuceAddr, referrerBonus, createTime
    struct Account {
        uint256  referrer;   // referrer UID
        uint64  visitTime;   // last check in time
        uint64  createTime;  // creation time
        uint32  refCount;    // invited friends
        uint32  lockPeriod;  // unit is a day, rescue account cannot empty this account during this period after visitTime
        uint64  unfreezeTime;  // unfreeze time of fronzenBalance
        uint256 balance;       // amount of money you can use now
        uint256 frozenBalance; // frozen money
        address rescueAddr;    // address of rescue account
        uint256 referrerBonus; // accumulated referrer bonus
    }

    using SafeMath for uint256;
    uint256 constant WITHDRAW_FEE = 0; // fixed withdraw fee
    uint256 constant MIN_FEE = 1 trx; // minimum wire fee
    uint256 constant MIN_WIRE_AMOUNT = 10 trx; // minimum wire amount
    uint256 constant MIN_WITHDRAW_AMOUNT = 1 trx; // minimum withdraw amount
    uint256 constant MIN_LEND_AMOUNT = 1000 trx;   // minimum lend amount
    uint256 constant MAX_LEND_AMOUNT = 99999999999 trx;   // max lend amount
    uint256 constant MIN_LEND_RATE   = 5; // minimum lending interest rate, N/1000
    uint256 constant MAX_LEND_RATE   = 50000; // maximum lending interest rate, N/1000
    uint256 constant WIRE_FEE_RATE = 2; // wire fee rate, N/1000
    uint256 constant RESCUE_FEE_RATE = 50; // rescue fee rate, N/1000
    uint256 constant REFERRER_RATE = 100;   // referrer bonus rate, N/1000
    uint256 constant LOAN_INTEREST_FEE  = 200;   // lending interest fee rate, N/1000
    uint256 constant INIT_UID = 1111; // UID of first user/the developer
    uint256 constant SECONDS_PER_DAY = 86400; // total seconds of one day
    uint256 constant MAX_FREEZE_DAYS = 3650;  // maximum lock period
    uint32 constant DEFAULT_LOCK_DAYS = 30;   // default lock period of a new account

    uint256 private  latestUID; // latest UID
    address private  developerAccount_;
    uint256 private  nMaintainMode; // 0-normal, 1-maintain mode, user can only deposit/withdraw/rescue/unfreeze his amount.

    mapping(address => uint256) private address2UID;
    mapping(uint256 => Account) private uid2Account;

    event onWire(address indexed user, uint256 receiverUID, uint256 amount);
    event onFreeze(address indexed user, uint256 amount);
    event onUnfreeze(address indexed user, uint256 amount);
    event onWithdraw(address indexed user, address receiver, uint256 amount);
    event onDeposit(address indexed user, uint256 amount);
    event onLend(address indexed user, uint256 receiverUID, uint256 amount, uint256 interest);
    event onCheckIn(address indexed user, uint256 visitTime);
    event onRescueResult(address indexed user, address addr, uint256 unfreezeTime, uint256 amount);
    event onSetRescueAccount(address indexed user, address addr, uint256 lockPeriod);

    /**
     * @dev Constructor Sets the original roles of the contract
     */

    constructor() public {
        developerAccount_ = msg.sender;
        _init();
    }

    function() external payable {
        if (msg.value > 0) {
            deposit(0);
        }
    }

    function _init() private {
        latestUID = INIT_UID;
        address2UID[msg.sender] = latestUID;
        uid2Account[latestUID].visitTime  = uint64(now)+1;
        uid2Account[latestUID].createTime = uint64(now);
    }

    function checkIn() public {
        if(nMaintainMode==0) return;
        uint256 uid = getUIDByAddress(msg.sender);
        require(uid>0, "Account not found");
        if(uid2Account[uid].visitTime == uid2Account[uid].createTime && uid2Account[uid].rescueAddr != address(0)) {
            // for accounts created by other user, reset the rescue account at first time check in
            uid2Account[uid].rescueAddr = address(0);
        }
        // to reduce enery cost, limit check in once in 12 hours
        if(uid2Account[uid].visitTime + 43200 < now || uid2Account[uid].visitTime == uid2Account[uid].createTime) {
            uid2Account[uid].visitTime = uint64(now);
            emit onCheckIn(msg.sender, now);
        }
    }

    function setDeveloperAccount(address _newDeveloperAccount) public onlyOwner {
        require(_newDeveloperAccount != address(0));
        developerAccount_ = _newDeveloperAccount;
    }

    function getDeveloperAccount() public view onlyOwner returns (address) {
        return developerAccount_;
    }

    function setMaintainMode(uint256 mode) public onlyOwner {
        if(mode!=nMaintainMode) nMaintainMode = mode;
    }

    function getMaintainMode() public view returns(uint256) {
        return nMaintainMode;
    }

    function _addDeveloperCost(uint256 fee, uint256 referrer) private {
        if(referrer > 0) {
            uint256 bonus = fee.mul(REFERRER_RATE) / 1000;
            uid2Account[referrer].balance = uid2Account[referrer].balance.add(bonus);
            uid2Account[referrer].referrerBonus = uid2Account[referrer].referrerBonus.add(bonus);
            fee = fee.sub(bonus);
        }
        uint256 uid = address2UID[developerAccount_];
        if(uid==0) uid = INIT_UID;
        uid2Account[uid].balance = uid2Account[uid].balance.add(fee);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUIDByAddress(address _addr) public view returns (uint256) {
        return address2UID[_addr];
    }

    // referrer, visitTime, refCount, lockPeriod, unfreezeTime, balance, frozenBalance, resuceAddr, referrerBonus, createTime
    function getAccountInfoByUID(uint256 _uid) public view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, address, uint256, uint256) {
        require(address2UID[msg.sender] == _uid, "only the owner can check his account info.");
        Account storage account = uid2Account[_uid];
        return
        (
        account.referrer,
        account.visitTime,
        account.refCount,
        account.lockPeriod,
        account.unfreezeTime,
        account.balance,
        account.frozenBalance,
        account.rescueAddr,
        account.referrerBonus,
        account.createTime
        );
    }
    function getAccountRescueInfo(uint256 _uid) public view returns(uint256,uint256) {
        Account storage account = uid2Account[_uid];
        if(account.rescueAddr != msg.sender) {
            return (0,0);
        }
        return (account.balance + account.frozenBalance, account.visitTime + account.lockPeriod * SECONDS_PER_DAY);
    }

    function _addAccount(address addr, uint256 _referrerCode) private returns (uint256) {
        require(addr != address(0));
        require(address2UID[addr]==0, "This account already exists.");
        if (_referrerCode >= INIT_UID) {
            // reset invalid referrer code
            if (uid2Account[_referrerCode].visitTime == 0) {
                _referrerCode = 0;
            }
        } else {
            _referrerCode = 0;
        }
        // address addr = _addr;
        latestUID = latestUID + 1;
        address2UID[addr] = latestUID;
        Account storage account = uid2Account[latestUID];
        account.createTime = uint64(now);
        if(addr != msg.sender) {
            // set rescue address to the sender for new account
            account.rescueAddr = msg.sender;
            account.lockPeriod = DEFAULT_LOCK_DAYS;
            account.visitTime  = uint64(now);
        } else {
            // increase visitTime to avoid check in again
            account.visitTime = uint64(now)+1;
        }
        if(_referrerCode >= INIT_UID) {
            account.referrer = _referrerCode;
            uid2Account[_referrerCode].refCount += 1;
        }
        return (latestUID);
    }

    // send money to my own account
    function deposit(uint256 _referrerCode) public payable {
        // require(nMaintainMode==0, "This contract is in maintenance mode.");
        require(msg.value > 0, "deposit amount must be greater than 0.");
        uint256 uid = address2UID[msg.sender];
        if(uid==0) {
            uid = _addAccount(msg.sender, _referrerCode);
        } else {
            checkIn();
        }
        uid2Account[uid].balance = uid2Account[uid].balance.add(msg.value);
        emit onDeposit(msg.sender,msg.value);
    }

    function withdraw(address addr, uint256 amount) public  payable {
        require(addr != address(0));
        require(amount>=MIN_WITHDRAW_AMOUNT,"Amount is too low.");
        uint256 uid = address2UID[msg.sender];
        require(uid > 0, "No account is found");
        require(uid2Account[uid].balance + msg.value >= amount, "Not enough balance");
        uint256 fee = WITHDRAW_FEE;
        if (addr != msg.sender) {
            // withdraw to other address is a kind of wire
            fee = amount.mul(WIRE_FEE_RATE) / 1000;
            if(fee<MIN_FEE) fee = MIN_FEE;
        }
        require(fee<=amount, "Invalid amount");
        checkIn();
        Account storage account = uid2Account[uid];
        if(msg.value>0) account.balance = account.balance.add(msg.value);
        account.balance = account.balance.sub(amount);
        if(fee>0) {
            _addDeveloperCost(fee, account.referrer);
            amount = amount.sub(fee);
        }
        if (!addr.send(amount)) {
            account.balance = account.balance.add(amount);
            return;
        }
        emit onWithdraw(msg.sender, addr, amount+fee);
    }

    function wireToAddress(address addr, uint256 amount, uint256 _referrerCode) public payable {
        require(nMaintainMode==0, "This contract is in maintenance mode.");
        require(addr != address(0));
        require(addr != msg.sender,"You cannot wire to yourself");
        uint256 uid = address2UID[msg.sender];
        if(uid==0) {
            uid = _addAccount(msg.sender,_referrerCode);
        } else {
            checkIn();
        }
        require(uid>0,"Invalid account");
        require(uid2Account[uid].balance + msg.value >= amount, "Not enough balance");
        uint256 receiverUID = address2UID[addr];
        if(receiverUID==0) {
            receiverUID = _addAccount(addr, uid);
        }
        wireToUser(receiverUID,amount,0);
    }
    function wireToUser(uint256 receiverUID, uint256 amount, uint256 _referrerCode) public payable {
        require(nMaintainMode==0, "This contract is in maintenance mode.");
        require(amount>=MIN_WIRE_AMOUNT, "Amount is too small");
        uint256 uid = address2UID[msg.sender];
        if(uid==0) {
            uid = _addAccount(msg.sender,_referrerCode);
        } else {
            checkIn();
        }
        require(uid>0,"Invalid account");
        require(uid!=receiverUID,"You cannot wire to yourself");
        require(receiverUID > 0, "Invalid receiver");
        require(uid2Account[uid].balance + msg.value >= amount, "Not enough balance");
        Account storage account1 = uid2Account[uid];
        Account storage account2 = uid2Account[receiverUID];
        uint256 fee = amount.mul(WIRE_FEE_RATE) / 1000;
        if(fee < MIN_FEE) fee = MIN_FEE;
        require(fee<amount, "Invalid amount");
        if(msg.value>0) account1.balance = account1.balance.add(msg.value);
        account1.balance = account1.balance.sub(amount);
        _addDeveloperCost(fee, account1.referrer);
        amount = amount.sub(fee);
        account2.balance = account2.balance.add(amount);
        emit onWire(msg.sender,receiverUID,amount);
    }

    function freeze(uint256 amount, uint256 period, uint256 _referrerCode) public payable {
        require(nMaintainMode==0, "This contract is in maintenance mode.");
        require(amount > 0, "Invalid amount");
        uint256 uid = address2UID[msg.sender];
        if(uid==0) {
            uid = _addAccount(msg.sender,_referrerCode);
        } else {
            checkIn();
        }
        Account storage account = uid2Account[uid];
        require(account.balance + msg.value >= amount, "Not enough balance");
        if(period>MAX_FREEZE_DAYS) period = MAX_FREEZE_DAYS;
        // cannot reduce existing unfreezeTime
        uint256 endTime = now + period * SECONDS_PER_DAY;
        if(endTime > account.unfreezeTime) account.unfreezeTime = uint64(endTime);
        if(msg.value>0) account.balance = account.balance.add(msg.value);
        account.balance = account.balance.sub(amount);
        account.frozenBalance = account.frozenBalance.add(amount);
        emit onFreeze(msg.sender, amount);
    }
    function unfreeze(uint256 amount) public {
        uint256 uid = address2UID[msg.sender];
        require(uid > 0, "No account is found");
        checkIn();
        Account storage account = uid2Account[uid];
        require(account.frozenBalance > amount, "Invalid amount");
        if(nMaintainMode==0) {
            require(account.unfreezeTime <= now, "It is not time yet");
        }
        account.frozenBalance = account.frozenBalance.sub(amount);
        account.balance = account.balance.add(amount);
        emit onUnfreeze(msg.sender, amount);
    }
    function lendToAddress(address addr, uint256 amount, uint256 rate,uint256 _referrerCode) public payable {
        require(nMaintainMode==0, "This contract is in maintenance mode.");
        require(addr != address(0));
        uint256 uid = address2UID[msg.sender];
        if(uid==0) {
            uid = _addAccount(msg.sender,_referrerCode);
        } else {
            checkIn();
        }
        uint256 uid2 = address2UID[addr];
        if(uid2==0) {
            uid2 = _addAccount(addr,uid);
        }
        lendToUID(uid2,amount,rate,_referrerCode);
    }
    function lendToUID(uint256 receiverUID, uint256 amount, uint256 rate,uint256 _referrerCode) public payable {
        require(nMaintainMode==0, "This contract is in maintenance mode.");
        require(amount >= MIN_LEND_AMOUNT, "Lending amount is too small");
        require(amount < MAX_LEND_AMOUNT, "Lending amount is too big");
        require(rate >= MIN_LEND_RATE, "Lending rate is too low");
        require(rate < MAX_LEND_RATE, "Lending rate is too high");
        require(receiverUID > 0, "Invalid receiver");
        uint256 uid = address2UID[msg.sender];
        if(uid==0) {
            uid = _addAccount(msg.sender,_referrerCode);
        } else {
            checkIn();
        }
        Account storage account = uid2Account[uid];
        Account storage account2 = uid2Account[receiverUID];
        uint256 interest = amount.mul(rate) / 1000;
        uint256 total = amount.add(interest);
        require(account.frozenBalance + account.balance + msg.value >= total, "Balance is not enough");
        if(msg.value > 0) account.balance = account.balance.add(msg.value);
        if(account.frozenBalance > 0) {
            if(account.frozenBalance <= total) {
                total = total.sub(account.frozenBalance);
                account.frozenBalance = 0;
                account.unfreezeTime = 0;
            } else {
                account.frozenBalance = account.frozenBalance.sub(total);
                total = 0;
            }
        }
        if(total>0) account.balance = account.balance.sub(total);
        uint256 fee = interest.mul(LOAN_INTEREST_FEE) / 1000;
        _addDeveloperCost(fee,0);
        account.balance = account.balance.add(interest.sub(fee));
        account2.balance = account2.balance.add(amount);
        emit onLend(msg.sender, receiverUID, amount, interest);
    }
    // rescue money in another account
    function rescue(address addr) public returns(uint256) {
        require(addr != address(0));
        require(addr != msg.sender, "You cannot rescue yourself");
        uint256 uid = address2UID[msg.sender];
        require(uid > 0, "No account is found");
        uint256 uid2 = address2UID[addr];
        require(uid2 > 0, "Invalid account");
        checkIn();
        Account storage account2 = uid2Account[uid2];
        require(account2.rescueAddr == msg.sender, "You are not authorized to rescue this account.");
        uint256 lockTime = account2.visitTime + account2.lockPeriod * SECONDS_PER_DAY;
        if(lockTime > now) {
            emit onRescueResult(msg.sender,addr,lockTime,account2.balance+account2.frozenBalance);
            return lockTime;
        }
        uint256 amount = 0;
        if(account2.balance > 0) {
            amount = account2.balance; account2.balance = 0;
        }
        if(account2.frozenBalance>0) {
            amount = amount.add(account2.frozenBalance); account2.frozenBalance = 0;
        }
        if(amount==0) {
            emit onRescueResult(msg.sender,addr,0,amount);
            return lockTime;
        }
        uint256 fee = amount.mul(RESCUE_FEE_RATE) / 1000;
        _addDeveloperCost(fee,0);
        amount = amount.sub(fee);
        uid2Account[uid].balance = uid2Account[uid].balance.add(amount);
        emit onRescueResult(msg.sender, addr, 1, amount);
        return 1;
    }
    function setRescueAccount(address addr, uint256 lockPeriod) public {
        require(addr != address(0), "Invalid rescue account");
        // require(lockPeriod>=7, "Lock period must be no less than 1 week");
        require(lockPeriod<2000, "Lock period must be no more than 5 years");
        require(addr != msg.sender, "Rescue account must be different from current account.");
        uint256 uid = address2UID[msg.sender];
        require(uid > 0, "No account is found");
        Account storage account = uid2Account[uid];
        checkIn();
        if(account.rescueAddr != addr) account.rescueAddr = addr;
        if(account.lockPeriod != lockPeriod) account.lockPeriod = uint32(lockPeriod);
        emit onSetRescueAccount(msg.sender, addr, lockPeriod);
    }
}

