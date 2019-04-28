pragma solidity ^0.4.25;

contract MagicButton {
    address support = msg.sender;
    uint public initialPrice = 10000000;
    uint public price = initialPrice;
    uint public lastPrice;
    address public lastInvestor;
    uint public stage;
    
    mapping (address => bool) internal users;
    mapping (address => address) public referrers;
    
    event PriceChanged(uint price);

    function getCurrentStage() public view returns (uint) {
        return uint(now - 18 hours) / 1 days;
    }
    
    function restart() internal {
        price = initialPrice;
        delete lastPrice;
        delete lastInvestor;
    }
    
    function button(address referrerAddress) external payable {
        uint currentStage = getCurrentStage();
        if (currentStage > stage) {
            stage = currentStage;
            restart();
        }
        
        require(msg.value >= price);
        if (msg.value > price) {
            msg.sender.transfer(msg.value - price);
        }
        
        users[msg.sender] = true;
        
        require(referrerAddress != msg.sender);     
        if (users[referrerAddress] && referrers[msg.sender] == 0x0) {
            referrers[msg.sender] = referrerAddress;
        }
        
        uint diff = price - lastPrice;
        
        lastPrice = price;
        price = price * 6 / 5; // 120%
        price /= 1000;
        price *= 1000;
        
        if (lastInvestor != 0x0) {
            uint fee = diff / 2;
            if (referrers[msg.sender] != 0x0) {
                uint refAmount = diff / 4;
                referrers[msg.sender].transfer(refAmount);
                fee -= refAmount;
            }
            support.transfer(fee);
            lastInvestor.transfer(address(this).balance);
        }
        
        lastInvestor = msg.sender;
        
        emit PriceChanged(price);
    }
}