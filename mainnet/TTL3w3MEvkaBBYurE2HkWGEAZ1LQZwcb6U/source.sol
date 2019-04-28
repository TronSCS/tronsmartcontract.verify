pragma solidity ^0.4.23;

contract TronMultiplier {

    // deposit structure
    struct Deposit {
        address member;
        uint amount;
    }

    Deposit[] public deposits; // keeps a history of all deposits

    uint volume; // total tron volume
    uint currentIndex; // current deposit index

    address support; // project support address
    address promotion; // project promotion address

    // This function called every time anyone sends a transaction to this contract
    constructor(address _support, address _promotion) public {
        support = _support;
        promotion = _promotion;
    }

    // This function creates a new deposit for the player
    function deposit() public payable {
        // deposit check
        require(msg.value >= 1e8);

        // update variables in storage
        deposits.push( Deposit(msg.sender, msg.value * 12 / 10) );
        volume += msg.value;

        // address where TRON will be sent to support the project (3%)
        send(support, msg.value * 3 / 100);

        // address where TRON will be sent for project promotion (5%)
        send(promotion, msg.value * 5 / 100);

        // send payouts
        pay();
    }

    // This function sends amounts to players who are in the current queue
    function pay() internal {
        uint balance = address(this).balance;
        uint completedDeposits;

        for (uint i = currentIndex; i < deposits.length; i++) {
            Deposit storage dep = deposits[i];

            if (balance >= dep.amount) {
                send(dep.member, dep.amount);
                balance -= dep.amount;
                delete deposits[currentIndex];
                completedDeposits++;
                // Maximum of one request can send no more than 15 payments
                if (completedDeposits >= 15) break;
            } else {
                dep.amount -= balance;
                send(dep.member, balance);
                break;
            }
        }

        currentIndex += completedDeposits;
    }

    // This function safely sends TRON by the passed parameters
    function send(address _receiver, uint _amount) internal returns(bool success) {
        if (_amount > 0 && _receiver != address(0)) {
            success = _receiver.send(_amount);
        }
    }


    /** View Functions **/

    // Returns all active deposits of player
    function depositsOf(address _member) public view returns(uint[] amounts,uint[] queue) {
        if (deposits.length == 0) return;

        uint count;
        for (uint i = currentIndex; i < deposits.length; i++) {
            if (deposits[i].member == _member) count++;
        }

        amounts = new uint[](count);
        queue = new uint[](count);

        uint id;
        for (i = currentIndex; i < deposits.length; i++) {
            if (deposits[i].member == _member) {
                amounts[id] = deposits[i].amount;
                queue[id] = i - currentIndex + 1;
                id++;
            }
        }
    }

    // Returns full statistics
    function stats(address _member) public view returns(
        uint totalVolume,
        uint index,
        uint queueLength,
        uint firstAmount,
        uint memberTotalAmount,
        uint memberDeposits,
        uint memberQueue
    ) {
        if (deposits.length == 0) return;

        totalVolume = volume;
        index = currentIndex;
        queueLength = deposits.length - currentIndex;
        firstAmount = deposits[currentIndex].amount;

        for (uint i = currentIndex; i < deposits.length; i++) {
            if (deposits[i].member == _member) {
                if (memberQueue == 0) memberQueue = i - currentIndex + 1;
                memberTotalAmount += deposits[i].amount;
                memberDeposits++;
            }
        }
    }
}