// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract MultsigWallet {
    // first we start with events, these events are fired when a function is called

    // when an amount is deposited to the contract
    event Deposit(address indexed sender, uint amount);
    // emit the event when a user approve a transaction
    event Approve(address indexed owner, uint indexed txId);
    // we emit tghe event when a user decides to revoke their approval
    event Revoke(address indexed owner, uint indexed txId);
    // we emit the event when the required appoval has been met
    event Execute(uint indexed txId);
    // when a transaction is submitted and pending approval from other owners
    event Submit(uint indexed txId);

    error MultsigWallet_OwnersRequired();

    // storing the owners of the wallet in an array of addresses
    address[] public owners;
    //mapping the owners to bool, this will help us check that msg.sender is owner, if the address is an owner, it returns true else false
    mapping(address => bool) public isOwners;
    // a predefined number of approval before the transaction is authorized/executed
    uint public required;

    struct Transactions {
        //the adddress the value is being sent to
        address to;
        //the amount to be sent
        uint value;
        //the data
        bytes data;
        //if its been executed or not
        bool executed;
    }
    //storing an instance of transactjon
    Transactions[] public transactions;
    //storing each transaction instance with an index, this is to aid approval.
    mapping(uint => mapping(address => bool)) public approved;

    //making sure only the owners can access the submit
    modifier onlyOwner() {
        require(isOwners[msg.sender], "Not owner");
        _;
    }
    modifier txExists(uint _txId) {
        // we check if the txId is less than the length
        require(_txId < transactions.length, "invalid transactions ID");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!approved[_txId][msg.sender], "not approved");
        _;
    }
    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "tx  already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        if (_owners.length <= 0) {
            revert MultsigWallet_OwnersRequired();
        }

        require(
            _required > 0 && _required <= _owners.length,
            "Invalid required number of owners"
        );
        // we pushing all owners inside the owners state variable
        for (uint i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwners[owner], "Owner isnt unique");

            //we inset the new owners inside the owners mapping and the owners array
            isOwners[owner] = true;
            owners.push(owner);
        }
        //setting the required to the required from the input.
        required = _required;
    }

    //we setting the wallet to be able to recieve ether
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // function to submit, only owners can submit
    function submit(
        address _to,
        uint _value,
        bytes calldata _data
    ) external onlyOwner {
        // we push the submitted transactions to the Transaction struct
        transactions.push(
            Transactions({to: _to, value: _value, data: _data, executed: false})
        );
        // the first transactions stored as index 0, thehn index 1 and so on
        emit Submit(transactions.length - 1);
    }

    function approve(
        uint _txId
    ) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId) {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint _txId) private view returns (uint count) {
        // we loop through the approvals in the approved mapping, then increment if any returns true
        for (uint i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

    function execute(uint _txId) external txExists(_txId) notExecuted(_txId) {
        require(
            _getApprovalCount(_txId) >= required,
            "appproval count is less than required"
        );
        //we storing the transactions in a storage because we ll be updating it
        Transactions storage transaction = transactions[_txId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "transaction failed");
        emit Execute(_txId);
    }

    function revoke(
        uint _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "tx not apporved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}
