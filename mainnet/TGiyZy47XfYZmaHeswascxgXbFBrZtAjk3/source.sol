pragma solidity ^0.4.25;

contract Town {
    struct Position {
        int x;
        int y;
    }
    
    uint public movePrice = 100000;
    uint public attackPrice = 500000;
    uint public spawnPrice = 1000000;
    uint fee = 20;
    uint refFee = 10;
    
    mapping (address => bool) internal users;
    mapping (address => bool) public ingame;
    mapping (address => address) public referrers;
    mapping (int => mapping (int => address)) public field;
    mapping (address => Position) public positions;
    address[] public userList;
    uint public userCount;
    address support = msg.sender;
    
    uint private seed;
    
    event UserPlaced(address user, int x, int y);
    event UserAttacked(address user, address by);
    event UserRemoved(address user);
    
    /* Converts uint256 to bytes32 */
    function toBytes(uint256 x) internal pure returns (bytes b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), x)
        }
    }
    
    function random(uint lessThan) internal returns (uint) {
        seed += block.timestamp + uint(msg.sender);
        return uint(sha256(toBytes(uint(blockhash(block.number - 1)) + seed))) % lessThan;
    }
    
    function requireEmptyCell(int x, int y) internal view {
        require(field[x][y] == 0x0);
    }
    
    function moveTo(int diffX, int diffY) internal {
        Position storage p = positions[msg.sender];
        int _x = p.x + diffX;
        int _y = p.y + diffY;
        requireEmptyCell(_x, _y);
        delete field[p.x][p.y];
        field[_x][_y] = msg.sender;
        positions[msg.sender] = Position(_x, _y);
    }
    
    function removeUserFrom(address user, int x, int y) internal {
        delete ingame[user];
        delete field[x][y];
        delete positions[user];
    }
    
    function tryAttack(int diffX, int diffY) internal returns (address) {
        Position storage p = positions[msg.sender];
        int _x = p.x + diffX;
        int _y = p.y + diffY;
        address enemy = field[_x][_y];
        if (enemy != 0x0) {
            removeUserFrom(enemy, _x, _y);
            msg.sender.transfer(address(this).balance / 2);
            return enemy;
        } else {
            return 0x0;
        }
    }
    
    function fees() internal {
        support.transfer(msg.value * fee / 100);
        if (referrers[msg.sender] != 0x0) {
            referrers[msg.sender].transfer(msg.value * refFee / 100);
        }
    }

    function move(uint8 dir) external payable {
        require(ingame[msg.sender]);
        require(msg.value == movePrice);
        require(dir < 4);
        fees();
        if (dir == 0) {
            moveTo(0, -1);
        } else if (dir == 1) {
            moveTo(1, 0);
        } else if (dir == 2) {
            moveTo(0, 1);
        } else {
            moveTo(-1, 0);
        }
        emit UserPlaced(msg.sender, positions[msg.sender].x, positions[msg.sender].y);
    }
    
    function attack(uint8 dir) external payable {
        require(ingame[msg.sender]);
        require(msg.value == attackPrice);
        require(dir < 4);
        fees();
        address enemy;
        if (dir == 0) {
            enemy = tryAttack(0, -1);
        } else if (dir == 1) {
            enemy = tryAttack(1, 0);
        } else if (dir == 2) {
            enemy = tryAttack(0, 1);
        } else {
            enemy = tryAttack(-1, 0);
        }
        emit UserAttacked(enemy, msg.sender);
        emit UserRemoved(enemy);
    }
    
    function spawn(address referer) external payable {
        require(!ingame[msg.sender]);
        require(msg.value == spawnPrice);
        ingame[msg.sender] = true;
        if (!users[msg.sender]) {
            users[msg.sender] = true;
            require(referer != msg.sender);     
            if (users[referer]) {
                referrers[msg.sender] = referer;
            }

            userList.push(msg.sender);
            userCount++;
        }
        
        fees();
        
        int x = int(random(21)) - 10;
        int y = int(random(21)) - 10;
        
        while (field[x][y] != 0x0) {
            x += int(random(3));
            y += int(random(3));
        }
        
        field[x][y] = msg.sender;
        positions[msg.sender] = Position(x, y);
        
        emit UserPlaced(msg.sender, x, y);
    }

    function () external payable {

    }
}