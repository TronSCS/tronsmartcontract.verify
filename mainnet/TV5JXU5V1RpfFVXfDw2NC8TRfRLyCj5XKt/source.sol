pragma solidity ^0.4.25;

contract TronCountry {
    address creator = msg.sender;
    
    mapping (address => uint) public invested;
    mapping (address => uint) public blockProfit;
    mapping (address => uint) public atBlock;
    mapping (address => address) public referrers;
    
    address[] public userList;
    uint public userCount;
    uint public buildingCount;
    uint[] public buildings;
    mapping (address => uint) public userBuildingCount;
    mapping (address => uint[]) public userBuildings;

    mapping (uint => uint) public percents;

    event Build(address user, uint id, uint price);

    constructor() public {
        percents[100000000] = 104;
        percents[400000000] = 430;
        percents[1600000000] = 1778;
        percents[6400000000] = 7334;
        percents[25600000000] = 30222;
        percents[102400000000] = 124444;
    }

    function _withdraw() internal {
        uint amount = blockProfit[msg.sender] * (block.number - atBlock[msg.sender]);
        if (blockProfit[msg.sender] > 0 && address(this).balance >= amount) {
            msg.sender.transfer(amount);
        }
    }

    function buyBuilding(address referer) external payable {
        require(percents[msg.value] > 0);
        
        if (blockProfit[msg.sender] == 0) {
            require(referer != msg.sender);     
            if (blockProfit[referer] > 0) {
                referrers[msg.sender] = referer;
            }

            userList.push(msg.sender);
            userCount++;
        }

        creator.transfer(msg.value / 10);
        if (referrers[msg.sender] != 0x0) {
            referrers[msg.sender].transfer(msg.value / 10);
        }

        _withdraw();

        invested[msg.sender] += msg.value;
        blockProfit[msg.sender] += percents[msg.value];
        atBlock[msg.sender] = block.number;

        buildings.push(msg.value);
        userBuildings[msg.sender].push(buildingCount);

        emit Build(msg.sender, buildingCount, msg.value);

        buildingCount++;
        userBuildingCount[msg.sender]++;
    }

    function getProfit() external {
        _withdraw();
        atBlock[msg.sender] = block.number;
    }
}