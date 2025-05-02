// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";



contract NashEscrow is Initializable, OwnableUpgradeable {
    uint256 public nextTransactionID;

    uint256 public successfulTransactionsCounter;

    event AgentPairingEvent(NashTransaction wtx);

    event TransactionInitEvent(NashTransaction wtx);

    event ClientConfirmationEvent(NashTransaction wtx);

    event AgentConfirmationEvent(NashTransaction wtx);

    event ConfirmationCompletedEvent(NashTransaction wtx);

    event TransactionCompletionEvent(NashTransaction wtx);

    event SavedClientCommentEvent(NashTransaction wtx);

    event TransactionCanceledEvent(NashTransaction wtx);

    uint256 private constant NON_REENTRANT_SLOT = 0xDEADBEEF;

    uint16 constant private PAGINATION_COUNT = 15;

    modifier nonReentrant() {
        assembly {
            if eq(tload(NON_REENTRANT_SLOT), 1) {
                revert(0, 0)
            }
            tstore(NON_REENTRANT_SLOT, 1)
        }
        _;
    }

    // Maps unique payment IDs to escrowed payments.
    // These payment IDs are the temporary wallet addresses created with the escrowed payments.
    mapping(uint256 => NashTransaction) private escrowTransactions;

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
        uint256 amount;
        address clientAddress;
        address agentAddress;
        address exchangeToken;
        TransactionType txType;
        Status status;
        bool agentApproval;
        bool clientApproval;
        string agentPaymentDetails;
        string clientPaymentDetails;
        string exchangeTokenLabel;
    }

    /**
     * Constructor.
     */
    function initialize() external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    /**
     * Client initialize withdrawal transaction.
     * @param _amount the amount to be withdrawn.
     **/
    function initializeWithdrawalTransaction(
        uint256 _amount,
        address _exchangeToken,
        string calldata _exchangeTokenLabel
    ) external nonReentrant {
        require(_amount > 0, "Amount to withdraw must be greater than 0.");

        uint256 wtxID = nextTransactionID;
        nextTransactionID++;

        NashTransaction storage newPayment = escrowTransactions[wtxID];

        newPayment.clientAddress = msg.sender;
        newPayment.id = wtxID;
        newPayment.txType = TransactionType.WITHDRAWAL;
        newPayment.amount = _amount;
        newPayment.status = Status.AWAITING_AGENT;

        newPayment.agentApproval = false;
        newPayment.clientApproval = false;
        newPayment.exchangeToken = _exchangeToken;
        newPayment.exchangeTokenLabel = _exchangeTokenLabel;

        require(
            IERC20(_exchangeToken).transferFrom(
                msg.sender,
                address(this),
                newPayment.amount
            ), "Failed to send tokens!!!"
        );

        emit TransactionInitEvent(newPayment);
    }

    /**
     * Client initialize deposit transaction.
     * @param _amount the amount to be deposited.
     * @param _exchangeToken the token to be exchanged through the escrow.
     **/
    function initializeDepositTransaction(
        uint256 _amount,
        address _exchangeToken,
        string calldata _exchangeTokenLabel
    ) external {
        require(_amount > 0, "Amount to deposit must be greater than 0.");

        uint256 wtxID = nextTransactionID;
        nextTransactionID++;

        NashTransaction storage newPayment = escrowTransactions[wtxID];

        newPayment.clientAddress = msg.sender;
        newPayment.id = wtxID;
        newPayment.txType = TransactionType.DEPOSIT;
        newPayment.amount = _amount;
        newPayment.status = Status.AWAITING_AGENT;
        newPayment.agentApproval = false;
        newPayment.clientApproval = false;
        newPayment.exchangeToken = _exchangeToken;
        newPayment.exchangeTokenLabel = _exchangeTokenLabel;

        emit TransactionInitEvent(newPayment);
    }

    /**
     * Marks pairs the client to an agent to attent to the transaction.
     * @param _transactionid the identifire of the transaction.
     * @param _paymentDetails the agents phone number.
     */
    function agentAcceptWithdrawalTransaction(
        uint256 _transactionid,
        string calldata _paymentDetails
    )
        external
        awaitAgentOnly(_transactionid)
        withdrawalsOnly(_transactionid)
        nonClientOnly(_transactionid)
    {
        NashTransaction storage wtx = escrowTransactions[_transactionid];
        wtx.agentAddress = msg.sender;
        wtx.status = Status.AWAITING_CONFIRMATIONS;
        wtx.agentPaymentDetails = _paymentDetails;
        emit AgentPairingEvent(wtx);
    }

    /**
     * Marks pairs the client to an agent to attent to the transaction.
     * @param _transactionid the identifire of the transaction.
     * @param _paymentDetails the agents phone number.
     */
    function agentAcceptDepositTransaction(
        uint256 _transactionid,
        string calldata _paymentDetails
    )
        external
        nonReentrant
        awaitAgentOnly(_transactionid)
        depositsOnly(_transactionid)
        nonClientOnly(_transactionid)
        balanceGreaterThanAmount(_transactionid)
    {
        NashTransaction storage wtx = escrowTransactions[_transactionid];

        wtx.agentAddress = msg.sender;
        wtx.status = Status.AWAITING_CONFIRMATIONS;
        wtx.agentPaymentDetails = _paymentDetails;

        require(
            IERC20(wtx.exchangeToken).transferFrom(
                msg.sender,
                address(this),
                wtx.amount
            ), "Failed to send tokens!!"
        );

        emit AgentPairingEvent(wtx);
    }

    /**
     * Writes the encrypted client information inot the smart contract.
     * @param _transactionid the transaction id.
     * @param _comment the encrypted comment.
     */
    function clientWritePaymentInformation(
        uint256 _transactionid,
        string calldata _comment
    ) external clientOnly(_transactionid) awaitConfirmation(_transactionid) {
        NashTransaction storage wtx = escrowTransactions[_transactionid];
        wtx.clientPaymentDetails = _comment;
        emit SavedClientCommentEvent(wtx);
    }

    /**
     * Client confirms that s/he has sent money to the agent.
     */
    function clientConfirmPayment(
        uint256 _transactionid
    ) external awaitConfirmation(_transactionid) clientOnly(_transactionid) {
        NashTransaction storage wtx = escrowTransactions[_transactionid];

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
    function agentConfirmPayment(
        uint256 _transactionid
    ) external awaitConfirmation(_transactionid) agentOnly(_transactionid) {
        NashTransaction storage wtx = escrowTransactions[_transactionid];

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
    function finalizeTransaction(
        uint256 _transactionid
    )
        private
        nonReentrant
        confirmationComplete(_transactionid)
        agentOrClientOnly(_transactionid)
    {
        NashTransaction storage wtx = escrowTransactions[_transactionid];
        address targetAddress;
        if (wtx.txType == TransactionType.DEPOSIT) {
            targetAddress = wtx.clientAddress;
        } else {
            // Transafer the amount to the agent address.
            targetAddress = wtx.agentAddress;
        }

        successfulTransactionsCounter++;
        wtx.status = Status.DONE;

        require(
            IERC20(wtx.exchangeToken).transfer(targetAddress, wtx.amount),
            "Transaction failed."
        );

        emit TransactionCompletionEvent(wtx);
    }

    /**
     * Allows a client to cancel a transaction before an agent
     * has agreed to fullfil it.
     * @param _transactionid the transaction id.
     */
    function cancelTransaction(
        uint256 _transactionid
    )
        external
        nonReentrant
        clientOnly(_transactionid)
        awaitAgentOnly(_transactionid)
    {
        NashTransaction storage wtx = escrowTransactions[_transactionid];
        wtx.status = Status.CANCELED; // update the state before external calls. Should revert state if fails.
        if (wtx.txType == TransactionType.WITHDRAWAL) {
            // require(
            //     ERC20(wtx.exchangeToken).balanceOf(address(this)) > wtx.amount,
            //     "Escrows balance is less than the required amount!!!. Try agin later."
            // );
            require(
                IERC20(wtx.exchangeToken).transfer(
                    wtx.clientAddress,
                    wtx.amount
                ),
                "Transaction failed."
            );
        }
        emit TransactionCanceledEvent(wtx);
    }

    /**
     * Gets transactions by index.
     * @param _transactionid the transaction id.
     * @return the transaction in questsion.
     */
    function getTransactionByIndex(
        uint256 _transactionid
    ) external view returns (NashTransaction memory) {
        NashTransaction memory wtx = escrowTransactions[_transactionid];
        return wtx;
    }

    /**
     * Gets the next unpaired transaction from the map.
     * @param _transactionid the transaction id.
     * @return the transaction in questsion.
     */
    function getNextUnpairedTransaction(
        uint256 _transactionid
    ) external view returns (NashTransaction memory) {
        uint256 transactionid = _transactionid;
        NashTransaction memory wtx;

        // prevent an extravagant loop.
        if (_transactionid > nextTransactionID) {
            transactionid = nextTransactionID;
        }

        // Loop through the transactions map by index.
        for (int256 index = int256(transactionid); index >= 0; index--) {
            wtx = escrowTransactions[uint256(index)];

            if (
                wtx.clientAddress != address(0) &&
                wtx.agentAddress == address(0)
            ) {
                // the next unparied transaction.
                return wtx;
            }
        }
        // return empty wtx object.
        wtx = escrowTransactions[nextTransactionID];
        return wtx;
    }

    /**
     * Gets the next unpaired transaction from the map.
     * @return the transaction in questsion.
     */
    function getTransactions(
        uint256 _startingPoint,
        Status _status
    ) external view returns (NashTransaction[] memory) {
        uint256 startingPoint = _startingPoint;
        uint256 paginationCount = PAGINATION_COUNT;

        // prevent an extravagant loop.
        if (startingPoint > nextTransactionID) {
            startingPoint = nextTransactionID;
        }

        // prevent an extravagant loop.
        if (PAGINATION_COUNT > nextTransactionID) {
            paginationCount = nextTransactionID;
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
                wtx = escrowTransactions[uint256(index)];

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
     * Returns the amount of locked tocken.
     * @param tokenAddress the address of the locked token.
     * @return the amount of locked token.
     */
    function checkLockedTokenAmount(
        address tokenAddress
    ) external view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /**
     * Withdraw/recover a certain amount of tokens by admin/owner.
     * @param tokenAddress the token to be recovered.
     * @param amount the amount of tokens to be recovered.
     */
    function withdrawLockedTokens(
        address tokenAddress,
        uint256 amount
    ) external onlyOwner {
        require(
            IERC20(tokenAddress).transfer(msg.sender, amount),
            "Error recovering tokens."
        );
    }

    /**
     * Gets the next unpaired transaction from the map.
     * @return the transaction in questsion.
     */
    function getMyTransactions(
        uint256 _startingPoint,
        Status[] memory _status,
        address myAddress
    ) external view returns (NashTransaction[] memory) {
        uint256 startingPoint = _startingPoint;
        uint256 paginationCount = PAGINATION_COUNT;

        // prevent an extravagant loop.
        if (startingPoint > nextTransactionID) {
            startingPoint = nextTransactionID;
        }

        // prevent an extravagant loop.
        if (PAGINATION_COUNT > nextTransactionID) {
            paginationCount = nextTransactionID;
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
                wtx = escrowTransactions[uint256(index)];
                if (
                    isTxInStatus(wtx, _status) &&
                    (wtx.clientAddress == myAddress ||
                        wtx.agentAddress == myAddress)
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

    function isTxInStatus(
        NashTransaction memory wtx,
        Status[] memory _status
    ) public pure returns (bool) {
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
        NashTransaction memory wtx = escrowTransactions[_transactionid];
        require(
            msg.sender == wtx.agentAddress,
            "Action can only be performed by the agent!!"
        );
        _;
    }

    /**
     * Run the method for deposit transactions only.
     */
    modifier depositsOnly(uint256 _transactionid) {
        NashTransaction memory wtx = escrowTransactions[_transactionid];
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
        NashTransaction memory wtx = escrowTransactions[_transactionid];
        require(
            wtx.txType == TransactionType.WITHDRAWAL,
            "Action can only be performed for withdraw transactions only!!"
        );
        _;
    }

    /**
     * Prevents users othe than the client from running the logic.
     * @param _transactionid the transaction being processed.
     */
    modifier clientOnly(uint256 _transactionid) {
        NashTransaction memory wtx = escrowTransactions[_transactionid];
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
        NashTransaction memory wtx = escrowTransactions[_transactionid];
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
        NashTransaction memory wtx = escrowTransactions[_transactionid];
        require(
            wtx.status == Status.AWAITING_CONFIRMATIONS,
            "Action can only be performed on transactions awaiting approval!!"
        );
        _;
    }

    /**
     * Prevents prevents double pairing of agents to transactions.
     * @param _transactionid the transaction being processed.
     */
    modifier awaitAgentOnly(uint256 _transactionid) {
        NashTransaction memory wtx = escrowTransactions[_transactionid];
        require(
            wtx.status == Status.AWAITING_AGENT,
            "Transaction already paired to an agent!!"
        );
        _;
    }

    /**
     * Prevents methods to be excecuted if both parties of the
     *  transactions have not confirmed payment.
     * @param _transactionid the transaction being processed.
     */
    modifier confirmationComplete(uint256 _transactionid) {
        NashTransaction memory wtx = escrowTransactions[_transactionid];
        require(wtx.agentApproval, "Awaiting agent approval!!");
        require(wtx.clientApproval, "Awaiting client approval!!");
        require(
            wtx.status == Status.CONFIRMED,
            "Transaction not yet confirmed by both parties!!"
        );
        _;
    }

    /**
     * Prevents users othe than the client from running the logic
     * @param _transactionid the transaction being processed.
     */
    modifier balanceGreaterThanAmount(uint256 _transactionid) {
        NashTransaction storage wtx = escrowTransactions[_transactionid];
        require(
            IERC20(wtx.exchangeToken).balanceOf(address(msg.sender)) >
                wtx.amount,
            "Your balance must be greater than the transaction amount."
        );
        _;
    }

    /**
     * Prevents users othe than the client from running the logic
     * @param _transactionid the transaction being processed.
     */
    modifier agentOrClientOnly(uint256 _transactionid) {
        NashTransaction storage wtx = escrowTransactions[_transactionid];
        require(
            wtx.clientAddress == msg.sender || wtx.agentAddress == msg.sender,
            "Only the involved parties can finalize the transaction.!!"
        );
        _;
    }
}
