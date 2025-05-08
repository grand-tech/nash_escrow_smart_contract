import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  convertToNashTransactionObj,
  deployNashEscrowContract,
} from "../utils/testutils";

describe("Test Get Next un-paired transaction.", function () {
  it("Get unpaired transaction.", async function () {
    const { owner, address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    await USDc.approve(nashEscrow.address, 10);

    expect(await nashEscrow.nextTransactionID()).to.equal(0);

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeWithdrawalTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow
        .connect(address2)
        .agentAcceptWithdrawalTransaction(3, "test phone number")
    ).to.emit(nashEscrow, "AgentPairingEvent");

    // Exact value.
    const tx = await nashEscrow.connect(address2).getNextUnpairedTransaction(2);

    expect(tx.id).equal(2);

    // Value above next tx index
    const tx2 = await nashEscrow
      .connect(address2)
      .getNextUnpairedTransaction(10);

    expect(tx2.id).equal(2);
  });
});

describe("Test Get transactions.", function () {
  it("Get unpaired transaction.", async function () {
    const { owner, address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    await USDc.approve(nashEscrow.address, 10);

    expect(await nashEscrow.nextTransactionID()).to.equal(0);

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeWithdrawalTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow
        .connect(address2)
        .agentAcceptWithdrawalTransaction(3, "test phone number")
    ).to.emit(nashEscrow, "AgentPairingEvent");

    // Exact value.
    const tx = await nashEscrow.connect(address2).getTransactions(5, 0);
    for (let index = 0; index < tx.length; index++) {
      const nashTx = convertToNashTransactionObj(
        Array.from(tx[index], (x) => `${x}`)
      );
      expect(nashTx.status, "Status should be 0 " + nashTx.status).equal(0);
    }
    expect(tx.length).equal(3);
  });
});

describe("Test Get My transactions.", function () {
  it("Get My transaction.", async function () {
    const { owner, address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    await USDc.approve(nashEscrow.address, 10);

    expect(await nashEscrow.nextTransactionID()).to.equal(0);

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeDepositTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow.initializeWithdrawalTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow
        .connect(address2)
        .agentAcceptWithdrawalTransaction(3, "test phone number")
    ).to.emit(nashEscrow, "AgentPairingEvent");

    // Test get my transactions
    await expect(
      nashEscrow.initializeWithdrawalTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    await expect(
      nashEscrow
        .connect(address2)
        .agentAcceptWithdrawalTransaction(4, "test phone number")
    ).to.emit(nashEscrow, "AgentPairingEvent");

    expect(await nashEscrow.connect(owner).clientConfirmPayment(4)).to.emit(
      nashEscrow,
      "ClientConfirmationEvent"
    );

    expect(await nashEscrow.connect(address2).agentConfirmPayment(4)).to.emit(
      nashEscrow,
      "AgentConfirmationEvent"
    );

    const txs = await nashEscrow
      .connect(address2)
      .getMyTransactions(5, [1, 3, 2], address2.getAddress());
    expect(txs.length).equal(1);

    const nashTx = convertToNashTransactionObj(
      Array.from(txs[0], (x) => `${x}`)
    );
    expect(nashTx.status, "Status should be 1").equal(1);
  });
});
