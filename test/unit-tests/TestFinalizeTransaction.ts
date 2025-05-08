import { expect } from "chai";
import {
  convertToNashTransactionObj,
  deployNashEscrowContract,
} from "../utils/testutils";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { PAYMENT_INFO } from "../utils/test-constants";

describe("Agent confirm/approve transaction.", function () {
  it("Call finalizing method from agent confirmation method...", async function () {
    const { owner, address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    const clientSigner = address2;
    const agentSigner = owner;
    await USDc.connect(agentSigner).approve(nashEscrow.address, 10);

    await expect(
      nashEscrow
        .connect(clientSigner)
        .initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow
        .connect(agentSigner)
        .agentAcceptDepositTransaction(0, PAYMENT_INFO)
    ).to.emit(nashEscrow, "AgentPairingEvent");

    await expect(
      nashEscrow
        .connect(clientSigner)
        .clientWritePaymentInformation(0, PAYMENT_INFO)
    ).to.emit(nashEscrow, "SavedClientCommentEvent");

    await expect(
      nashEscrow.connect(clientSigner).clientConfirmPayment(0)
    ).to.emit(nashEscrow, "ClientConfirmationEvent");

    await expect(
        nashEscrow.connect(agentSigner).agentConfirmPayment(0)
      ).to.emit(nashEscrow, "TransactionCompletionEvent");

    const tx = await nashEscrow.getTransactionByIndex(0);
    const nashTx = convertToNashTransactionObj(tx);

    expect(nashTx.txType).to.equal(
      0,
      "The transaction type should be deposit."
    );
    expect(nashTx.clientAddress).equal(
      clientSigner.address,
      "Should have the correct client address"
    );
    expect(nashTx.agentAddress).to.equal(
      agentSigner.address,
      "Should have an agent address"
    );
    expect(nashTx.status).to.equal(4, "The transaction status should be 4");
    expect(nashTx.amount).to.equal(5, "The amount should be 5 units");
    expect(nashTx.agentApproval, "Agent approval should be true").to.be.true;
    expect(nashTx.clientApproval, "Client approval should be true").to.be.true;
    expect(nashTx.clientPaymentDetails).to.equal(
      PAYMENT_INFO,
      "Should have client`s payment information."
    );

    expect(nashTx.agentPaymentDetails).to.equal(
      PAYMENT_INFO,
      "Should have agent`s payment information."
    );
    expect(nashTx.exchangeToken).to.equal(
      USDc.address,
      "Should have the correct exchange token address"
    );
    expect(nashTx.exchangeTokenLabel).to.equal(
      "USDc",
      "Should have the correct exchange token label"
    );

    // Assert autoincrement of next transaction id.
    const nextTxIndex = await nashEscrow.nextTransactionID();
    expect(nextTxIndex).to.equal(
      1,
      "Next transaction index has been updated properly"
    );
  });

  it("Call finalizing method from client confirmation method...", async function () {
    const { owner, address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    const clientSigner = address2;
    const agentSigner = owner;
    await USDc.connect(agentSigner).approve(nashEscrow.address, 10);

    await expect(
      nashEscrow
        .connect(clientSigner)
        .initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow
        .connect(agentSigner)
        .agentAcceptDepositTransaction(0, PAYMENT_INFO)
    ).to.emit(nashEscrow, "AgentPairingEvent");

    await expect(
      nashEscrow
        .connect(clientSigner)
        .clientWritePaymentInformation(0, PAYMENT_INFO)
    ).to.emit(nashEscrow, "SavedClientCommentEvent");

    await expect(
        nashEscrow.connect(agentSigner).agentConfirmPayment(0)
      ).to.emit(nashEscrow, "AgentConfirmationEvent");
      
    await expect(
      nashEscrow.connect(clientSigner).clientConfirmPayment(0)
    ).to.emit(nashEscrow, "TransactionCompletionEvent");

    const tx = await nashEscrow.getTransactionByIndex(0);
    const nashTx = convertToNashTransactionObj(tx);

    expect(nashTx.txType).to.equal(
      0,
      "The transaction type should be deposit."
    );
    expect(nashTx.clientAddress).equal(
      clientSigner.address,
      "Should have the correct client address"
    );
    expect(nashTx.agentAddress).to.equal(
      agentSigner.address,
      "Should have an agent address"
    );
    expect(nashTx.status).to.equal(4, "The transaction status should be 4");
    expect(nashTx.amount).to.equal(5, "The amount should be 5 units");
    expect(nashTx.agentApproval, "Agent approval should be true").to.be.true;
    expect(nashTx.clientApproval, "Client approval should be true").to.be.true;
    expect(nashTx.clientPaymentDetails).to.equal(
      PAYMENT_INFO,
      "Should have client`s payment information."
    );

    expect(nashTx.agentPaymentDetails).to.equal(
      PAYMENT_INFO,
      "Should have agent`s payment information."
    );
    expect(nashTx.exchangeToken).to.equal(
      USDc.address,
      "Should have the correct exchange token address"
    );
    expect(nashTx.exchangeTokenLabel).to.equal(
      "USDc",
      "Should have the correct exchange token label"
    );

    // Assert autoincrement of next transaction id.
    const nextTxIndex = await nashEscrow.nextTransactionID();
    expect(nextTxIndex).to.equal(
      1,
      "Next transaction index has been updated properly"
    );
  });
});
