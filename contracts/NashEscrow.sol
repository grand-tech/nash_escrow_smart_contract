// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract NashEscrow {
    /**
     * Encription keys used to enxcrypt phone numbers.
     **/
    string private encryptionKey;

    uint256 private nextTransactionID = 0;

    uint256 private agentFee = 50000000000000000;

    uint256 private nashFee = 40000000000000000;

    uint256 private successfulTransactionsCounter = 0;

    event AgentPairingEvent(NashTransaction wtx);

    event TransactionInitEvent(NashTransaction wtx);

    event ClientConfirmationEvent(NashTransaction wtx);

    event AgentConfirmationEvent(NashTransaction wtx);

    event ConfirmationCompletedEvent(NashTransaction wtx);

    event TransactionCompletionEvent(NashTransaction wtx);

    /**
     * Holds the nash treasury address funds. Default account for alfajores test net.
     */
    address internal nashTreasuryAddress =
        0xfF096016A3B65cdDa688a8f7237Ac94f3EFBa245;

    /**
     * Address of the cUSD (default token on Alfajores).
     */
    address internal cUsdTokenAddress =
        0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

    // Maps unique payment IDs to escrowed payments.
    // These payment IDs are the temporary wallet addresses created with the escrowed payments.
    mapping(uint256 => NashTransaction) private escrowedPayments;

    /**
     * An enum of the transaction types. either deposit or withdrawal.
     */
    enum TransactionType {
        DEPOSIT,
        WITHDRAWAL
    }

    /**
     * An enum of all the states of a transaction.
     * AWAITING_AGENT :- transaction initialized and waitning for agent pairing.
     * AWAITING_CONFIRMATIONS :- agent paired awaiting for approval by the agent and client.
     * CONFIRMED :- transactions confirmed by both client and aagent.
     * DONE :- transaction completed, currency moved from escrow to destination addess.
     */
    enum Status {
        AWAITING_AGENT,
        AWAITING_CONFIRMATIONS,
        CONFIRMED,
        CANCELED,
        DONE
    }

    /**
     * Object of escrow transactions.
     **/
    struct NashTransaction {
        uint256 id;
        TransactionType txType;
        address clientAddress;
        address agentAddress;
        Status status;
        uint256 netAmount;
        uint256 agentFee;
        uint256 nashFee;
        uint256 grossAmount;
        bool agentApproval;
        bool clientApproval;
        string agentPhoneNumber;
        string clientPhoneNumber;
    }

    /**
     * Constructor.
     */
    constructor(
        address _cUSDTokenAddress,
        uint256 _agentFee,
        uint256 _nashFee,
        address _nashTreasuryAddress
    ) {
        // Allow for default value.
        if (_cUSDTokenAddress != address(0)) {
            cUsdTokenAddress = _cUSDTokenAddress;
        }

        // Allow for default value.
        if (_nashTreasuryAddress != address(0)) {
            nashTreasuryAddress = _nashTreasuryAddress;
        }

        // Allow for default value.
        if (_agentFee > 0) {
            agentFee = _agentFee;
        }

        // Allow for default value.
        if (_nashFee > 0) {
            nashFee = _nashFee;
        }
    }

    /**
     * Get the nash fees from the smart contract.
     */
    function getNashFee() public view returns (uint256) {
        return nashFee;
    }

    /**
     * Get the agent fees from the smart contract.
     */
    function getAgentFee() public view returns (uint256) {
        return agentFee;
    }

    /**
     * Get the number of transactions in the smart contract.
     */
    function getNextTransactionIndex() public view returns (uint256) {
        return nextTransactionID;
    }

    /**
     * Get the number of successful transactions within the smart contract.
     */
    function countSuccessfulTransactions() public view returns (uint256) {
        return successfulTransactionsCounter;
    }

    /**
     * Client initialize withdrawal transaction.
     * @param _amount the amount to be withdrawn.
     * @param _phoneNumber the client`s phone number.
     **/
    function initializeWithdrawalTransaction(
        uint256 _amount,
        string calldata _phoneNumber
    ) public payable {
        require(_amount > 0, "Amount to deposit must be greater than 0.");

        uint256 wtxID = nextTransactionID;
        nextTransactionID++;

        uint256 grossAmount = _amount;
        NashTransaction storage newPayment = escrowedPayments[wtxID];

        newPayment.clientAddress = msg.sender;
        newPayment.id = wtxID;
        newPayment.txType = TransactionType.WITHDRAWAL;
        newPayment.netAmount = grossAmount - (nashFee + agentFee);
        newPayment.agentFee = agentFee;
        newPayment.nashFee = nashFee;
        newPayment.grossAmount = grossAmount;
        newPayment.status = Status.AWAITING_AGENT;
        newPayment.clientPhoneNumber = _phoneNumber;

        // newPayment.clientPhoneNo = keccak256(abi.encodePacked(_phoneNumber, encryptionKey));
        newPayment.agentApproval = false;
        newPayment.clientApproval = false;

        ERC20(cUsdTokenAddress).transferFrom(
            msg.sender,
            address(this),
            grossAmount
        );

        emit TransactionInitEvent(newPayment);
    }

    /**
     * Client initialize deposit transaction.
     * @param _amount the amount to be deposited.
     * @param _phoneNumber the client`s phone number.
     **/
    function initializeDepositTransaction(
        uint256 _amount,
        string calldata _phoneNumber
    ) public {
        require(_amount > 0, "Amount to deposit must be greater than 0.");

        uint256 wtxID = nextTransactionID;
        nextTransactionID++;

        NashTransaction storage newPayment = escrowedPayments[wtxID];

        uint256 grossAmount = _amount;

        newPayment.clientAddress = msg.sender;
        newPayment.id = wtxID;
        newPayment.txType = TransactionType.DEPOSIT;
        newPayment.netAmount = grossAmount - (nashFee + agentFee);
        newPayment.agentFee = agentFee;
        newPayment.nashFee = nashFee;
        newPayment.grossAmount = grossAmount;
        newPayment.status = Status.AWAITING_AGENT;
        newPayment.clientPhoneNumber = _phoneNumber;

        // newPayment.clientPhoneNo = keccak256(abi.encodePacked(_phoneNumber, encryptionKey));
        newPayment.agentApproval = false;
        newPayment.clientApproval = false;

        emit TransactionInitEvent(newPayment);
    }

    /**
     * Marks pairs the client to an agent to attent to the transaction.
     * @param _transactionid the identifire of the transaction.
     * @param _phoneNumber the agents phone number.
     */
    function agentAcceptWithdrawalTransaction(
        uint256 _transactionid,
        string calldata _phoneNumber
    )
        public
        awaitAgent(_transactionid)
        withdrawalsOnly(_transactionid)
        nonClientOnly(_transactionid)
    {
        NashTransaction storage wtx = escrowedPayments[_transactionid];

        wtx.agentAddress = msg.sender;
        wtx.status = Status.AWAITING_CONFIRMATIONS;
        wtx.agentPhoneNumber = _phoneNumber;

        emit AgentPairingEvent(wtx);
    }

    /**
     * Marks pairs the client to an agent to attent to the transaction.
     * @param _transactionid the identifire of the transaction.
     * @param _phoneNumber the agents phone number.
     */
    function agentAcceptDepositTransaction(
        uint256 _transactionid,
        string calldata _phoneNumber
    )
        public
        payable
        awaitAgent(_transactionid)
        depositsOnly(_transactionid)
        nonClientOnly(_transactionid)
        balanceGreaterThanAmount(_transactionid)
    {
        NashTransaction storage wtx = escrowedPayments[_transactionid];

        wtx.agentAddress = msg.sender;
        wtx.status = Status.AWAITING_CONFIRMATIONS;

        require(
            ERC20(cUsdTokenAddress).transferFrom(
                msg.sender,
                address(this),
                wtx.grossAmount
            ),
            "You don't have enough cUSD to accept this request."
        );
        wtx.agentPhoneNumber = _phoneNumber;
        emit AgentPairingEvent(wtx);
    }

    /**
     * Client confirms that s/he has sent money to the agent.
     */
    function clientConfirmPayment(uint256 _transactionid)
        public
        awaitConfirmation(_transactionid)
        clientOnly(_transactionid)
    {
        NashTransaction storage wtx = escrowedPayments[_transactionid];

        require(!wtx.clientApproval, "Client already confirmed payment!!");
        wtx.clientApproval = true;

        emit ClientConfirmationEvent(wtx);

        if (wtx.agentApproval) {
            wtx.status = Status.CONFIRMED;
            emit ConfirmationCompletedEvent(wtx);
            finalizeTransaction(_transactionid);
        }
    }

    /**
     * Agent comnfirms that the payment  has been made.
     */
    function agentConfirmPayment(uint256 _transactionid)
        public
        awaitConfirmation(_transactionid)
        agentOnly(_transactionid)
    {
        NashTransaction storage wtx = escrowedPayments[_transactionid];

        require(!wtx.agentApproval, "Agent already confirmed payment!!");
        wtx.agentApproval = true;

        emit AgentConfirmationEvent(wtx);

        if (wtx.clientApproval) {
            wtx.status = Status.CONFIRMED;
            emit ConfirmationCompletedEvent(wtx);
            finalizeTransaction(_transactionid);
        }
    }

    /**
     * Can be automated in the frontend by use of event listeners. eg on confirmation event.
     **/
    function finalizeTransaction(uint256 _transactionid) public {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            wtx.clientAddress == msg.sender || wtx.agentAddress == msg.sender,
            "Only the involved parties can finalize the transaction.!!"
        );

        require(
            wtx.status == Status.CONFIRMED,
            "Transaction not yet confirmed by both parties!!"
        );

        if (wtx.txType == TransactionType.DEPOSIT) {
            ERC20(cUsdTokenAddress).transfer(wtx.clientAddress, wtx.netAmount);
        } else {
            // Transafer the amount to the agent address.
            require(
                ERC20(cUsdTokenAddress).transfer(
                    wtx.agentAddress,
                    wtx.netAmount
                ),
                "Transaction failed."
            );
        }

        // Transafer the agents fees to the agents address.
        require(
            ERC20(cUsdTokenAddress).transfer(wtx.agentAddress, wtx.agentFee),
            "Agent fee transfer failed."
        );

        // Transafer the agents total (amount + agent fees)
        require(
            ERC20(cUsdTokenAddress).transfer(nashTreasuryAddress, wtx.nashFee),
            "Transaction fee transfer failed."
        );

        successfulTransactionsCounter++;

        wtx.status = Status.DONE;

        emit TransactionCompletionEvent(wtx);
    }

    /**
     * Gets transactions by index.
     * @param _transactionID the transaction id.
     * @return the transaction in questsion.
     */
    function getTransactionByIndex(uint256 _transactionID)
        public
        view
        returns (NashTransaction memory)
    {
        NashTransaction memory wtx = escrowedPayments[_transactionID];
        return wtx;
    }

    /**
     * Gets the next unpaired transaction from the map.
     * @param _transactionID the transaction id.
     * @return the transaction in questsion.
     */
    function getNextUnpairedTransaction(uint256 _transactionID)
        public
        view
        returns (NashTransaction memory)
    {
        uint256 transactionID = _transactionID;
        NashTransaction storage wtx;

        // prevent an extravagant loop.
        if (_transactionID > nextTransactionID) {
            transactionID = nextTransactionID;
        }

        // Loop through the transactions map by index.
        for (int256 index = int256(transactionID); index >= 0; index--) {
            wtx = escrowedPayments[uint256(index)];

            if (
                wtx.clientAddress != address(0) &&
                wtx.agentAddress == address(0)
            ) {
                // the next unparied transaction.
                return wtx;
            }
        }
        // return empty wtx object.
        wtx = escrowedPayments[nextTransactionID];
        return wtx;
    }

    /**
     * Gets the next unpaired transaction from the map.
     * @return the transaction in questsion.
     */
    function getTransactions(
        uint256 _paginationCount,
        uint256 _startingPoint,
        Status _status
    ) public view returns (NashTransaction[] memory) {
        uint256 startingPoint = _startingPoint;
        uint256 paginationCount = _paginationCount;

        // prevent an extravagant loop.
        if (startingPoint > nextTransactionID) {
            startingPoint = nextTransactionID;
        }

        // prevent an extravagant loop.
        if (_paginationCount > nextTransactionID) {
            paginationCount = nextTransactionID;
        }

        if (_paginationCount > 15) {
            paginationCount = 15;
        }

        NashTransaction[] memory transactions = new NashTransaction[](
            paginationCount
        );

        uint256 transactionCounter = 0;
        for (uint256 i = 0; i < paginationCount; i++) {
            NashTransaction memory wtx;
            // Loop through the transactions map by index.
            bool updated = false;
            for (int256 index = int256(startingPoint); index >= 0; index--) {
                wtx = escrowedPayments[uint256(index)];

                if (wtx.status == _status && wtx.clientAddress != address(0)) {
                    transactions[uint256(i)] = wtx;
                    if (index > 0) {
                        startingPoint = uint256(index) - 1;
                    }
                    // prevent another parent loop after zero
                    updated = index != 0;
                    transactionCounter++;
                    break;
                }
            }
            if (!updated) {
                break;
            }
        }

        NashTransaction[] memory ts = new NashTransaction[](transactionCounter);

        for (uint256 i = 0; i < transactions.length; i++) {
            NashTransaction memory wtx = transactions[i];
            if (wtx.clientAddress != address(0)) {
                ts[i] = wtx;
            }
        }
        return ts;
    }

    /**
     * Gets the next unpaired transaction from the map.
     * @return the transaction in questsion.
     */
    function getMyTransactions(
        uint256 _paginationCount,
        uint256 _startingPoint,
        Status[] memory _status
    ) public view returns (NashTransaction[] memory) {
        uint256 startingPoint = _startingPoint;
        uint256 paginationCount = _paginationCount;

        // prevent an extravagant loop.
        if (startingPoint > nextTransactionID) {
            startingPoint = nextTransactionID;
        }

        // prevent an extravagant loop.
        if (_paginationCount > nextTransactionID) {
            paginationCount = nextTransactionID;
        }

        if (_paginationCount > 15) {
            paginationCount = 15;
        }
        NashTransaction[] memory transactions = new NashTransaction[](
            paginationCount
        );

        uint256 transactionCounter = 0;
        for (uint256 i = 0; i < paginationCount; i++) {
            NashTransaction memory wtx;
            // Loop through the transactions map by index.
            bool updated = false;
            for (int256 index = int256(startingPoint); index >= 0; index--) {
                wtx = escrowedPayments[uint256(index)];
                if (
                    isTxInStatus(wtx, _status) &&
                    (wtx.clientAddress == msg.sender ||
                        wtx.agentAddress == msg.sender)
                ) {
                    transactions[uint256(i)] = wtx;
                    if (index > 0) {
                        startingPoint = uint256(index) - 1;
                    }
                    // prevent another parent loop after zero
                    updated = index != 0;
                    transactionCounter++;
                    break;
                }
            }
            if (!updated) {
                break;
            }
        }

        NashTransaction[] memory ts = new NashTransaction[](transactionCounter);

        for (uint256 i = 0; i < transactions.length; i++) {
            NashTransaction memory wtx = transactions[i];
            if (wtx.clientAddress != address(0)) {
                ts[i] = wtx;
            }
        }

        return ts;
    }

    function isTxInStatus(NashTransaction memory wtx, Status[] memory _status)
        public
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < _status.length; i++) {
            if (wtx.status == _status[i]) {
                return true;
            }
        }
        return false;
    }

    /**
     * Prevents users othe than the agent from running the logic.
     * @param _transactionid the transaction being processed.
     */
    modifier agentOnly(uint256 _transactionid) {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            msg.sender == wtx.agentAddress,
            "Action can only be performed by the agent"
        );
        _;
    }

    /**
     * Run the method for deposit transactions only.
     */
    modifier depositsOnly(uint256 _transactionid) {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            wtx.txType == TransactionType.DEPOSIT,
            "Action can only be performed for deposit transactions only!!"
        );
        _;
    }

    /**
     * Run the method for withdrawal transactions only.
     * @param _transactionid the transaction being processed.
     */
    modifier withdrawalsOnly(uint256 _transactionid) {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            wtx.txType == TransactionType.WITHDRAWAL,
            "Action can only be performed for withdrawal transactions only!!"
        );
        _;
    }

    /**
     * Prevents users othe than the client from running the logic.
     * @param _transactionid the transaction being processed.
     */
    modifier clientOnly(uint256 _transactionid) {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            msg.sender == wtx.clientAddress,
            "Action can only be performed by the client!!"
        );
        _;
    }

    /**
     * Prevents the client from running the logic.
     * @param _transactionid the transaction being processed.
     */
    modifier nonClientOnly(uint256 _transactionid) {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            msg.sender != wtx.clientAddress,
            "Action can not be performed by the client!!"
        );
        _;
    }

    /**
     * Only alows method to be excecuted in tx in question is waiting confirmation.
     * @param _transactionid the transaction being processed.
     */
    modifier awaitConfirmation(uint256 _transactionid) {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            wtx.status == Status.AWAITING_CONFIRMATIONS,
            "Transaction is not awaiting confirmation from anyone."
        );
        _;
    }

    /**
     * Prevents prevents double pairing of agents to transactions.
     * @param _transactionid the transaction being processed.
     */
    modifier awaitAgent(uint256 _transactionid) {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            wtx.status == Status.AWAITING_AGENT,
            "Transaction already paired to an agent!!"
        );
        _;
    }

    /**
     * Prevents users othe than the client from running the logic
     * @param _transactionid the transaction being processed.
     */
    modifier balanceGreaterThanAmount(uint256 _transactionid) {
        NashTransaction storage wtx = escrowedPayments[_transactionid];
        require(
            ERC20(cUsdTokenAddress).balanceOf(address(msg.sender)) >
                wtx.grossAmount,
            "Your balance must be greater than the transaction gross amount."
        );
        _;
    }
}
