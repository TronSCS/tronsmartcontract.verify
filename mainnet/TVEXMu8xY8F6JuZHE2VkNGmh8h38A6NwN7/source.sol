pragma solidity ^0.4.25;

contract bankofhodl {
    address support1;
    address support2;
    address support3;
    uint minimumAmount = 100000000;
    uint restartAmount = 50000000;
    uint supportFee_1 = 5;
    uint supportFee_2 = 5;
    uint refFee = 3;
    uint public stage;
    uint public investorCount;
    
    // records amounts invested
    mapping (uint => mapping(address => uint)) public invested;
    // records amounts paid
    mapping (uint => mapping(address => uint)) public paid;
    // records blocks at which investments were made
    mapping (uint => mapping(address => uint)) public atBlock;

    mapping (uint => mapping(address => address)) public referrers;
    mapping (uint => mapping(address => address[])) public referrals;

    constructor(address _support1, address _support2, address _support3) public {
        support1 = _support1;
        support2 = _support2;
        support3 = _support3;
    }

    function getProfit(address user) public view returns (uint) {
        uint hh = (block.number - atBlock[stage][user]) / 1200;
        uint profit = invested[stage][user] * hh * 125 / 100000;
        uint max = invested[stage][user] * 2 - paid[stage][user];
        return profit > max ? max : profit;
    }

    function isActiveUser(address user) internal view returns (bool) {
        return invested[stage][user] > 0;
    }

    function restartIfNeeded() internal returns (bool) {
        if (address(this).balance < restartAmount) {
            stage++;
            return true;
        } else {
            return false;
        }
    }

    function payToUser() internal returns (bool) {
        if (!isActiveUser(msg.sender)) {
            return false;
        }

        uint amount = getProfit(msg.sender);
        uint balance = address(this).balance - msg.value;

        if (amount > balance) {
            amount = balance;
        }
        msg.sender.transfer(amount);
        paid[stage][msg.sender] += amount;
        
        return true;
    }

    function withdraw() external {
        require(payToUser());
        if (!restartIfNeeded()) {
            atBlock[stage][msg.sender] = block.number;
        }
    }

    function invest(address referrerAddress) external payable {
        require(msg.value >= minimumAmount);
        if (!isActiveUser(msg.sender)) {
            investorCount++;
        }

        payToUser();

        require(referrerAddress != msg.sender);     
        if (isActiveUser(referrerAddress) && referrers[stage][msg.sender] == 0x0) {
            referrers[stage][msg.sender] = referrerAddress;
            referrals[stage][referrerAddress].push(msg.sender);
        }

        if (referrers[stage][msg.sender] != 0x0) {
            referrers[stage][msg.sender].transfer(msg.value * refFee / 100);
        }

        support1.transfer(msg.value * supportFee_1 / 100);
        support2.transfer(msg.value * supportFee_1 / 100);
        support3.transfer(msg.value * supportFee_2 / 100);

        atBlock[stage][msg.sender] = block.number;
        invested[stage][msg.sender] += msg.value;
    }

    function reinvest() external {
        require(isActiveUser(msg.sender));
        uint amount = getProfit(msg.sender);
        if (amount > 0) {
            atBlock[stage][msg.sender] = block.number;
            invested[stage][msg.sender] += amount;
        }
    }
}