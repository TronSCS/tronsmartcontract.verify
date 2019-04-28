pragma solidity ^0.4.25;

/*
* Transfer TRX Contract
* Author: P3T Team
* Website: https://p3t.network/tools/transfertrx
* Hide your sender with a Smart Contract
* No fee
*/

contract TransferTrx {
	uint256 trxTransferMin = 1 * 1000000; 
	event eventOnTransfer(address _transferPerson, address _receiverPerson, uint256 _trx);
	function () public payable {
	}

	function actionTranfer(address _receiver) public payable {
		tranfer(msg.sender,_receiver,msg.value);
	}
	function tranfer(address _transferPerson , address _receiverPerson, uint256 _trx) private {
		require(_trx >= trxTransferMin);
		if (_receiverPerson != address(0)) {
			address receiverPerson = _receiverPerson;
			receiverPerson.transfer(_trx);
			emit eventOnTransfer(_transferPerson, _receiverPerson, _trx);
		}
		else {
			revert();
		}
	}
}