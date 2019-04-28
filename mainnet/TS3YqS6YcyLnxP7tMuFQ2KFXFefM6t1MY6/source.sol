pragma solidity ^0.4.0;


contract blabla {
    string public name = "Blablabla";
    string public symbol = "blcoin";
    uint8 constant public decimals = 18;
    uint8 constant internal entryFee_ = 8;
    uint8 constant internal transferFee_ = 1;
    uint8 constant internal exitFee_ = 2;
    uint8 constant internal refferalFee_ = 1;
    uint256 constant internal tokenPriceInitial_ = 21;
    uint256 constant internal tokenPriceIncremental_ = 13;
    uint256 constant internal magnitude = 2 ** 64;
    uint256 public stakingRequirement = 0e18;
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => int256) internal payoutsTo_;
    uint256 internal tokenSupply_;
    uint256 internal profitPerShare_;
    address owner = msg.sender;
   
    }