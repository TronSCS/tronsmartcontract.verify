pragma solidity ^0.4.25;

contract Token {
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
}

contract DEMS {
    address public XIO;
    address public creator;

    mapping (address => uint) public balances;
    
    event SendMessage(bytes iv, bytes epk, bytes ct, bytes mac, address sender);

    constructor(address _XIO) public {
        XIO = _XIO;
        creator = msg.sender;
    }

    function deposit(uint amount) external {
        Token(XIO).transferFrom(msg.sender, creator, amount);
        balances[msg.sender] += amount;
    }
    
    function sendMessage(bytes iv, bytes epk, bytes ct, bytes mac) external {
        require(balances[msg.sender] >= 1000000);
        balances[msg.sender] -= 1000000;
        emit SendMessage(iv, epk, ct, mac, msg.sender);
    }
}