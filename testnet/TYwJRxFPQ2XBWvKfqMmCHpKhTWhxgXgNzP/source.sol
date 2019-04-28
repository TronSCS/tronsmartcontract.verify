pragma solidity ^0.5.2;


contract Test{

    address public administrationWallet;
   function f() public view returns (string memory){
       return "method f()";
   }
   function g() public view  returns (string memory){
       return "method g()";
   }

       constructor(address _administrationWallet) public {
        require(_administrationWallet != address(0));
        administrationWallet = _administrationWallet;
    }

}