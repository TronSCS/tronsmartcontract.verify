pragma solidity ^0.4.25;

contract Token {
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function transfer(address to, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
}

contract XIOSwap {
    uint public XIO10 = 1002342;
    address public XIO20;

    mapping (address => uint) public balances;
    
    event SendMessage(bytes iv, bytes epk, bytes ct, bytes mac, address sender);

    constructor(address _XIO20) public {
        XIO20 = _XIO20;
    }

    function x20to10(uint amount) external {
        require(amount > 0);
        Token(XIO20).transferFrom(msg.sender, this, amount);
        msg.sender.transferToken(amount, XIO10);
    }
    
    function x10to20() external payable {
        require(msg.tokenid == XIO10);
        require(msg.tokenvalue > 0);
        Token(XIO20).transfer(msg.sender, msg.tokenvalue);
    }
}