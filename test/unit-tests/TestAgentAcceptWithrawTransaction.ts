import { expect } from "chai";
import {
  convertToNashTransactionObj,
  deployNashEscrowContract,
} from "../utils/testutils";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "ethers";
import { PAYMENT_INFO } from "../utils/test-constants";

describe("Transaction Agent Accept/Fulfill Withdraw Transaction.", function () {
  it("Check if all transaction fields have the correct value...", async function () {
    const { owner, address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    let clientBalance = await USDc.balanceOf(owner.address);
    expect(clientBalance).to.equal(BigNumber.from("100"));
    await USDc.approve(nashEscrow.address, 10);

    await expect(
      nashEscrow.initializeWithdrawalTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    clientBalance = await USDc.balanceOf(owner.address);
    expect(clientBalance).to.equal(BigNumber.from("95"));

    await expect(
      nashEscrow
        .connect(address2)
        .agentAcceptWithdrawalTransaction(0, PAYMENT_INFO)
    ).to.emit(nashEscrow, "AgentPairingEvent");

    const tx = await nashEscrow.getTransactionByIndex(0);
    const nashTx = convertToNashTransactionObj(tx);

    expect(nashTx.txType).to.equal(
      1,
      "The transaction type should be withdraw"
    );
    expect(nashTx.clientAddress).equal(
      owner.address,
      "Should have the correct client address"
    );
    expect(nashTx.agentAddress).to.equal(
      address2.address,
      "Should have an agent address"
    );
    expect(nashTx.status).to.equal(1, "The transaction status should be 1");
    expect(nashTx.amount).to.equal(5, "The amount should be 5 units");
    expect(nashTx.agentApproval, "Agent approval should be false").to.be.false;
    expect(nashTx.clientApproval, "Client approval should be false").to.be
      .false;
    expect(
      nashTx.clientPaymentDetails,
      "Should not have client`s payment information."
    ).to.equal("");

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

  it("Test with clients address...", async function () {
    const { tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    await USDc.approve(nashEscrow.address, 10);
    await expect(
      nashEscrow.initializeWithdrawalTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.agentAcceptWithdrawalTransaction(0, PAYMENT_INFO)
    ).to.revertedWith("Action can not be performed by the client!!");
  });

  it("Test on deposit transaction.", async function () {
    const { address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    await USDc.approve(nashEscrow.address, 10);

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow
        .connect(address2)
        .agentAcceptWithdrawalTransaction(0, PAYMENT_INFO)
    ).to.revertedWith(
      "Action can only be performed for withdraw transactions only!!"
    );
  });

  it("Test with already paired transaction...", async function () {
    const { address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    await USDc.approve(nashEscrow.address, 10);
    await expect(
      nashEscrow.initializeWithdrawalTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow
        .connect(address2)
        .agentAcceptWithdrawalTransaction(0, PAYMENT_INFO)
    ).to.emit(nashEscrow, "AgentPairingEvent");

    await expect(
      nashEscrow
        .connect(address2)
        .agentAcceptWithdrawalTransaction(0, PAYMENT_INFO)
    ).to.revertedWith("Transaction already paired to an agent!!");
  });
});
